# Xojo MVVM Framework — Architecture Proposal
## JinjaX-Powered, No WebPage GUI Controls

> **Project:** mvvm (Xojo Web Application)
> **Date:** 2026-03-11
> **Status:** ✅ FEASIBLE — Fully verified against JinjaX source code

---

## 1. Feasibility Verdict

**Yes — this is 100% feasible.** The complete request-to-response pipeline can be built using only non-GUI Xojo Web classes. Every piece of the puzzle is confirmed to exist and work:

| Requirement | Mechanism | Confirmed |
|---|---|---|
| Intercept HTTP without WebPage | `WebApplication.HandleURL` event | ✅ |
| Render HTML templates | `JinjaX.CompiledTemplate.Render(dict)` → `String` | ✅ |
| Write response to browser | `WebResponse.Write(html)` | ✅ |
| Per-user session state | `WebSession` (one per browser session) | ✅ |
| Template dot-notation `user.name` | JinjaX `EvaluateGetAttr` → reads `Dictionary` keys | ✅ |
| Template loops over DB rows | JinjaX `RenderFor` → accepts `Variant()` arrays | ✅ |
| Template inheritance/layout | `{% extends %}`, `{% block %}` | ✅ |
| Template includes (partials) | `{% include %}` | ✅ |
| XSS protection | `Autoescape = True` (JinjaX default) | ✅ |
| Custom template filters | `env.RegisterFilter(name, func)` | ✅ |
| Filesystem template loading | `JinjaX.FileSystemLoader` | ✅ |
| Database access | Xojo `SQLiteDatabase`, `DatabaseRecord`, etc. | ✅ |

---

## 2. How It Works — The Full Picture

This is a **server-side rendered (SSR)** architecture, similar to how Flask or Django work in Python. Every page request goes through a full cycle:

```
Browser
  │  HTTP Request (GET /products or POST /products)
  ▼
Xojo WebApplication.HandleURL
  │  Parses path, returns True (takes ownership of ALL requests)
  ▼
Router
  │  Matches path pattern → finds ViewModel class
  │  Extracts URL params (e.g., /products/42 → id = 42)
  ▼
ViewModel.Handle(request, response, session)
  │  Dispatches to OnGet() or OnPost()
  ▼
Model (Database Query)
  │  Returns Dictionary / Variant() arrays
  ▼
ViewModel builds context Dictionary
  │  { "products": [...], "user": {...}, "page_title": "..." }
  ▼
JinjaX.CompiledTemplate.Render(context) → HTML String
  │  Template: templates/products/list.html
  ▼
WebResponse.Write(html)  +  SetHeader("Content-Type", "text/html")
  ▼
Browser renders the page
```

No WebPage class is used anywhere in this flow. The WebPage in the current project file can be deleted.

---

## 3. Layer Definitions

### 3.1 View Layer → Jinja HTML Templates (`.html` files)

- Pure HTML files with Jinja2 syntax
- Live in a `templates/` folder (copied to app bundle at build time)
- Web designers work here independently — they never touch Xojo code
- Inherit from a base layout, use partials for navbars, footers, components

```html
{# templates/products/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Products{% endblock %}

{% block content %}
<h1>Products ({{ products | length }} total)</h1>
<ul>
  {% for product in products %}
  <li>
    <a href="/products/{{ product.id }}">{{ product.name }}</a>
    — ${{ product.price }}
    {% if product.stock == 0 %}
      <span class="badge">Out of Stock</span>
    {% endif %}
  </li>
  {% else %}
  <p>No products found.</p>
  {% endfor %}
</ul>
{% endblock %}
```

**Key constraint:** Because JinjaX's dot-notation (`product.name`) resolves via `Dictionary` key lookup, all data passed to templates must be Xojo `Dictionary` objects, not custom Xojo class instances. Arrays must be `Variant()` arrays containing `Dictionary` objects.

### 3.2 ViewModel Layer → Xojo Classes

One ViewModel class per route/feature. Receives the request, orchestrates Models, builds the template context Dictionary, and calls JinjaX to render.

**ViewModel responsibilities:**
- Receive `WebRequest`, `WebResponse`, `WebSession`, and URL path params
- Call Model classes to fetch/modify data
- Handle both GET and POST for the same route
- Build a `Dictionary` to pass to the template
- Call `Render(templateName, context)` to write the HTML response
- Handle redirects after POST (Post/Redirect/Get pattern)
- Never reference HTML or template structure

**ViewModel must NOT do:**
- Write raw HTML itself
- Access the database directly (delegate to Model)
- Know which template engine is being used internally

### 3.3 Model Layer → Xojo Classes

Pure data and business logic. No UI awareness.

**Model responsibilities:**
- All database queries (SELECT, INSERT, UPDATE, DELETE)
- Business rules and validation
- Return data as `Dictionary` objects or `Variant()` arrays
- Can raise exceptions for error handling

**Critical rule: Data must be Dictionary-shaped for JinjaX**

```
✅ Correct:   Model returns Dictionary → ViewModel passes to JinjaX → {{ row.name }} works
❌ Wrong:     Model returns custom class → JinjaX cannot do dot-access → renders empty
```

---

## 4. Class Design

### 4.1 `App` (WebApplication)

The top-level entry point. Owns the singleton `Router` and `JinjaEnvironment`.

```
App (inherits WebApplication)
  Properties:
    - mRouter As Router           ' Singleton
    - mJinja As JinjaEnvironment  ' Singleton, shared read-only

  Events:
    - Opening()
        → set up JinjaEnvironment (template path, filters)
        → set up Router (register all routes)

    - HandleURL(request As WebRequest, response As WebResponse) As Boolean
        → call mRouter.Route(request, response, mJinja)
        → always return True (we handle all requests)
```

**Why `JinjaEnvironment` is safe to share:** After `Opening()`, the environment is read-only (no more `RegisterFilter` calls). `CompiledTemplate` and `JinjaContext` are created fresh per request (per-request objects, not shared). This is thread-safe.

### 4.2 `Router`

Pattern-based HTTP router. Holds a list of route definitions and dispatches to the right ViewModel.

```
Router
  Inner type: RouteDefinition
    - Method As String        ' "GET", "POST", "*"
    - Pattern As String       ' "/products/:id"
    - Handler As VMFactory    ' Delegate that creates the ViewModel

  Methods:
    - Get(pattern, handler)       ' Register GET route
    - Post(pattern, handler)      ' Register POST route
    - Route(request, response, jinja, session) ' Match and dispatch
    - ParsePath(pattern, actual)  ' Returns Dictionary of params or Nil if no match
    - Serve404(response)
    - Serve500(response, error)

  Notes:
    - Routes are matched in order of registration
    - Exact paths beat pattern paths (no ambiguity)
    - :param segments match any single path component
    - Route "/static/:file" can serve static files from disk
```

**Route Registration Example (in App.Opening):**
```
mRouter.Get("/",               New HomeVM_Factory)
mRouter.Get("/products",       New ProductListVM_Factory)
mRouter.Get("/products/:id",   New ProductDetailVM_Factory)
mRouter.Post("/products",      New ProductCreateVM_Factory)
mRouter.Get("/login",          New LoginVM_Factory)
mRouter.Post("/login",         New LoginVM_Factory)
mRouter.Get("/static/:file",   New StaticFileVM_Factory)
```

### 4.3 `BaseViewModel` (Abstract)

The base class all ViewModels inherit from. Provides helpers so subclasses stay clean.

```
BaseViewModel
  Properties:
    - Request As WebRequest
    - Response As WebResponse
    - Session As Session       ' Cast from WebRequest.Session
    - Jinja As JinjaEnvironment
    - PathParams As Dictionary ' URL params like {:id: "42"}

  Abstract Methods:
    - OnGet()     ' Subclass handles GET
    - OnPost()    ' Subclass handles POST (default: 405 Method Not Allowed)

  Concrete Methods:
    - Handle()
        → dispatches to OnGet() or OnPost() based on Request.Method

    - Render(templateName As String, context As Dictionary)
        → tmpl = Jinja.GetTemplate(templateName)
        → html = tmpl.Render(context)
        → Response.SetHeader("Content-Type", "text/html; charset=utf-8")
        → Response.Write(html)

    - Redirect(url As String, statusCode As Integer = 302)
        → Response.SetHeader("Location", url)
        → Response.Status = statusCode

    - RenderError(statusCode As Integer, message As String)
        → Response.Status = statusCode
        → Render("errors/" + statusCode + ".html", context)

    - WriteJSON(jsonString As String)
        → Response.SetHeader("Content-Type", "application/json")
        → Response.Write(jsonString)

    - GetParam(key As String) As String
        → reads from PathParams, then QueryString

    - GetFormValue(key As String) As String
        → parses Request.Body (URL-encoded form)

    - IsAuthenticated() As Boolean
        → checks Session for login state

    - CurrentUser() As Dictionary
        → returns user Dictionary from Session
```

### 4.4 ViewModel Example

```
' ProductListViewModel
Class ProductListViewModel
  Inherits BaseViewModel

  Sub OnGet()
    Var model As New ProductModel()
    Var products() As Variant = model.GetAll()   ' Returns Variant() of Dictionaries

    Var context As New Dictionary()
    context.Value("products") = products
    context.Value("page_title") = "Product List"
    context.Value("user") = CurrentUser()

    Render("products/list.html", context)
  End Sub

End Class
```

### 4.5 Model Example

```
' ProductModel
Class ProductModel
  ' Returns all products as Variant() of Dictionary
  Function GetAll() As Variant()
    Var db As SQLiteDatabase = App.DB   ' App holds shared DB connection
    Var rs As RowSet = db.SelectSQL("SELECT id, name, price, stock FROM products ORDER BY name")

    Var results() As Variant
    Do Until rs.AfterLastRow
      Var row As New Dictionary()
      row.Value("id")    = rs.Column("id").IntegerValue
      row.Value("name")  = rs.Column("name").StringValue
      row.Value("price") = rs.Column("price").DoubleValue
      row.Value("stock") = rs.Column("stock").IntegerValue
      results.Add(row)
      rs.MoveToNextRow()
    Loop
    rs.Close()

    Return results
  End Function

  ' Returns a single product Dictionary or Nil
  Function GetByID(id As Integer) As Dictionary
    Var db As SQLiteDatabase = App.DB
    Var rs As RowSet = db.SelectSQL("SELECT * FROM products WHERE id = ?", id)
    If rs.AfterLastRow Then Return Nil

    Var row As New Dictionary()
    row.Value("id")    = rs.Column("id").IntegerValue
    row.Value("name")  = rs.Column("name").StringValue
    row.Value("price") = rs.Column("price").DoubleValue
    row.Value("stock") = rs.Column("stock").IntegerValue
    rs.Close()
    Return row
  End Function

End Class
```

---

## 5. Project Folder Structure

```
mvvm.xojo_project
│
├── App.xojo_code              ← WebApplication: Router + JinjaEnvironment setup
├── Session.xojo_code          ← WebSession: user auth state, flash messages
│
├── Framework/
│   ├── Router.xojo_code
│   ├── BaseViewModel.xojo_code
│   ├── FormParser.xojo_code   ← URL-encoded POST body parser
│   └── QueryParser.xojo_code  ← Query string parser
│
├── ViewModels/
│   ├── HomeViewModel.xojo_code
│   ├── ProductListViewModel.xojo_code
│   ├── ProductDetailViewModel.xojo_code
│   └── LoginViewModel.xojo_code
│
├── Models/
│   ├── ProductModel.xojo_code
│   └── UserModel.xojo_code
│
└── templates/                 ← HTML files (web designer's territory)
    ├── layouts/
    │   └── base.html          ← Master layout with nav, footer
    ├── products/
    │   ├── list.html
    │   └── detail.html
    ├── auth/
    │   └── login.html
    └── errors/
        ├── 404.html
        └── 500.html
```

---

## 6. Template Setup (JinjaEnvironment)

### In `App.Opening()`:

```
' Create the shared Jinja environment
mJinja = New JinjaX.JinjaEnvironment()
mJinja.Autoescape = True       ' XSS protection on by default
mJinja.TrimBlocks = True       ' Clean whitespace after tags
mJinja.LStripBlocks = True

' Set template folder (resolved relative to App.ExecutableFile.Parent)
' In Xojo IDE: this is the IDE's temp run folder. Use CopyFiles build step.
mJinja.TemplatePath = "templates"

' Register custom filters
mJinja.RegisterFilter("currency", AddressOf CurrencyFilter)
mJinja.RegisterFilter("date_format", AddressOf DateFormatFilter)
```

### Static template filters example:

```
' CurrencyFilter: formats numbers as "$1,234.56"
Function CurrencyFilter(value As Variant, args() As Variant) As Variant
  #Pragma Unused args
  Return "$" + Format(CDbl(value), "#,##0.00")
End Function
```

### Base layout template (`templates/layouts/base.html`):

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{% block title %}My App{% endblock %} | MySite</title>
  <link rel="stylesheet" href="/static/app.css">
</head>
<body>
  <nav>
    {% if user %}
      <span>Hello, {{ user.name }}</span> | <a href="/logout">Logout</a>
    {% else %}
      <a href="/login">Login</a>
    {% endif %}
  </nav>

  <main>
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

---

## 7. Key Design Decisions

### 7.1 The Dictionary Data Contract
**This is the most important rule in the whole architecture.**

JinjaX's `EvaluateGetAttr` resolves `user.name` by doing `Dictionary(obj).Value("name")`. It only works with `Dictionary` objects — **not** with custom Xojo class instances.

This means:
- Models return `Dictionary` or `Variant()` of `Dictionary` (never custom class instances)
- ViewModels build `Dictionary` contexts to pass to `Render()`
- Nested objects are nested `Dictionary` objects
- Lists are `Variant()` arrays where each element is a `Dictionary`

This is a clean constraint, not a limitation — it forces a natural separation between data transfer objects and behavior.

### 7.2 Session Scope (Critical for Web Apps)
- **Never store user-specific data in `App`** — it's shared across all users
- **`WebSession`** (our `Session` class) is the right place for: current user ID, login state, flash messages, CSRF tokens
- One `Session` instance per browser session — Xojo creates and manages these automatically
- ViewModels access the session via `WebRequest.Session` (cast to our `Session` class)

### 7.3 Post/Redirect/Get Pattern
For all form submissions:
1. Browser sends `POST /products` with form data
2. ViewModel processes the POST (create/update/delete)
3. ViewModel calls `Redirect("/products")` (302 redirect)
4. Browser follows redirect with `GET /products`
5. GET handler renders the updated list

This prevents duplicate submissions on browser refresh.

### 7.4 Static File Serving
Options (pick one):
- **Option A (Simplest):** Reference CDN URLs in templates (Bootstrap, Alpine.js, etc.) — no static serving needed
- **Option B:** A `/static/:file` route reads from disk and writes bytes to response
- **Option C:** Put static files in Xojo's "Copy Files" resources and let Xojo serve them (check Xojo Web docs for `HandleSpecialURL`)

### 7.5 Thread Safety
- `JinjaEnvironment` — shared, **read-only after `Opening()`** → safe
- `CompiledTemplate` — created fresh per render or cached (templates don't change at runtime) → safe
- `JinjaContext` — created fresh per `Render()` call → safe
- `ViewModel` — created fresh per request → safe
- `App.DB` (database connection) — **must be protected** if shared. Either:
  - Use a new DB connection per request (safest)
  - Use a connection pool
  - Or use a Mutex around DB access

---

## 8. Identified Constraints & Solutions

| Constraint | Impact | Solution |
|---|---|---|
| JinjaX dot-notation only works with `Dictionary` | Models cannot return custom Xojo classes to templates | All Model output → `Dictionary` objects |
| `FileSystemLoader` resolves from `App.ExecutableFile.Parent` | In IDE dev, templates folder must be accessible from run location | Use absolute `FolderItem` constructor, or copy templates via CopyFiles build step |
| No built-in form body parser | POST data in `WebRequest.Body` is raw URL-encoded string | Write a `FormParser` utility class (`key=val&key2=val2` splitter) |
| No built-in URL query parser | Same as above | Write a `QueryParser` utility class |
| No automatic route param types | `:id` is always `String` from URL | Cast in ViewModel: `CType(GetParam("id"), Integer)` |
| Database thread safety | Shared DB connection in multi-user app | One DB connection per request, or Mutex-protected pool |
| Flash messages (success/error after redirect) | POST → Redirect means data is lost between requests | Store flash messages in `Session`, read and clear on next GET |

---

## 9. What This Is NOT

To set correct expectations:

- **Not a reactive/SPA framework** — each action is a full page load. If you want partial updates without page refresh, pair with HTMX (`htmx.org`) in templates, which sends small HTML fragments back from the server. Xojo + JinjaX + HTMX is a very strong combination.
- **Not a front-end framework** — no JavaScript component model. HTML is generated server-side.
- **Not a REST API only** — this is primarily for HTML rendering. JSON endpoints can be added with `WriteJSON()` but it's not the primary use case.

---

## 10. Implementation Roadmap

### Phase 1 — Core Framework (no features)
- [ ] Delete `WebPage1` from project
- [ ] Add JinjaXLib to project (reference or copy classes)
- [ ] Implement `BaseViewModel` with `Handle()`, `Render()`, `Redirect()`, `GetParam()`
- [ ] Implement `Router` with `Get()`, `Post()`, `Route()`, `ParsePath()`
- [ ] Implement `FormParser` utility
- [ ] Implement `QueryParser` utility
- [ ] Set up `App.Opening()` with JinjaEnvironment and Router
- [ ] Implement `App.HandleURL()` to call Router
- [ ] Create `templates/layouts/base.html`
- [ ] Create `templates/errors/404.html` and `500.html`
- [ ] **Test:** GET `/` returns a rendered HTML page

### Phase 2 — Session & Auth
- [ ] Extend `Session` class: `IsLoggedIn`, `CurrentUserID`, `FlashMessage`
- [ ] Implement `LoginViewModel` (GET shows form, POST validates and redirects)
- [ ] Implement `BaseViewModel.IsAuthenticated()` and `CurrentUser()`
- [ ] Add CSRF token generation and validation
- [ ] **Test:** Login flow, session persistence, logout

### Phase 3 — Database Integration
- [ ] Set up database connection in `App`
- [ ] Implement first `Model` class with full CRUD
- [ ] Implement corresponding ViewModels (List, Detail, Create, Edit, Delete)
- [ ] **Test:** Full CRUD cycle through browser

### Phase 4 — Production Hardening
- [ ] Error handling: try/catch in all ViewModels → 500 page on error
- [ ] Request logging
- [ ] Template caching (compile once, cache `CompiledTemplate`)
- [ ] Static file serving route
- [ ] CopyFiles build step to bundle templates with app

---

## 11. JinjaX Template Feature Reference

Available in all `.html` templates:

| Feature | Syntax | Notes |
|---|---|---|
| Variable | `{{ user.name }}` | Dict key access only |
| Filter | `{{ price \| currency }}` | Chainable: `{{ s \| trim \| upper }}` |
| Conditional | `{% if x %}...{% elif y %}...{% else %}...{% endif %}` | `==`, `!=`, `<`, `>`, `in`, `not in` |
| Loop | `{% for item in items %}...{% else %}...{% endfor %}` | `{% else %}` = empty state |
| Loop vars | `{{ loop.index }}`, `{{ loop.first }}`, `{{ loop.last }}`, `{{ loop.length }}` | Built-in per iteration |
| Layout | `{% extends "layouts/base.html" %}` | Must be first tag |
| Block | `{% block name %}...{% endblock %}` | For child to override |
| Include | `{% include "partials/nav.html" %}` | Shares current context |
| Set var | `{% set x = "value" %}` | Local template variable |
| Auto-escape | On by default | `<script>` → `&lt;script&gt;` |
| Safe HTML | Pass `MarkupSafe.MarkupString(html)` | Skips escaping |
| Built-in filters | `upper`, `lower`, `title`, `trim`, `length`, `default`, `int`, `float`, `replace`, `first`, `last`, `join` | |
