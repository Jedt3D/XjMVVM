---
title: Methods & Properties
description: Naming conventions for Xojo methods, properties, and Dictionary keys.
---

# Methods & Properties

## ViewModel methods

Every ViewModel inherits from `BaseViewModel` and overrides one or both of:

```xojo
Sub OnGet()   // Handles GET requests
Sub OnPost()  // Handles POST requests
```

These are deliberately named like event handlers — they *respond* to an HTTP method, they don't initiate anything. If you only override `OnGet()`, any `POST` to that route gets a 405 response from the base class automatically.

Private helper methods within a ViewModel use descriptive verb-first names:

```xojo
// ✅ Good — reads like English, describes what it does
Private Function FindNoteOrRedirect(id As Integer) As Dictionary
Private Sub ValidateTitle(title As String)

// ❌ Avoid — vague, reads like a getter
Private Function GetData() As Dictionary
Private Sub Process()
```

## Properties

Xojo convention: private (module-level) properties use an `m` prefix and `camelCase`:

```xojo
Private mFormData As Dictionary   // cached parsed POST body
Private mRawBody  As String       // raw POST body bytes
```

Public properties (those inherited from or set by `BaseViewModel`) have no prefix:

```xojo
// These are set by the Router before Handle() is called
Request    As WebRequest
Response   As WebResponse
Session    As WebSession
Jinja      As JinjaX.JinjaEnvironment
PathParams As Dictionary
```

## Model methods

Model methods describe the data operation clearly. Use standard CRUD verbs:

| Operation | Method name | Return type |
|---|---|---|
| Fetch all rows | `GetAll()` | `Variant()` of `Dictionary` |
| Fetch one row | `GetByID(id As Integer)` | `Dictionary` or `Nil` |
| Create | `Create(...)` | `Integer` (new row ID) |
| Update | `Update(id, ...)` | `Sub` (no return) |
| Delete | `Delete(id As Integer)` | `Sub` (no return) |

Model methods are `Shared` — you never need to instantiate a Model class:

```xojo
// ✅ Call on the class directly
Var notes As Variant() = NoteModel.GetAll()
Var note As Dictionary = NoteModel.GetByID(42)
NoteModel.Delete(42)

// ❌ Don't instantiate Models
Var model As New NoteModel()
model.GetAll()
```

## Dictionary keys

Keys in `Dictionary` objects — both in context dictionaries for templates and in Model return values — use `snake_case` strings. This matches the column names in SQLite and the variable names used in Jinja2 templates:

```xojo
// Model → Dictionary
row.Value("id")         = rs.Column("id").IntegerValue
row.Value("title")      = rs.Column("title").StringValue
row.Value("created_at") = rs.Column("created_at").StringValue

// ViewModel → context Dictionary for template
Var ctx As New Dictionary()
ctx.Value("notes")      = NoteModel.GetAll()    // Variant() of Dictionary
ctx.Value("page_title") = "All Notes"
ctx.Value("flash")      = ...                   // injected by Render() automatically
```

In templates, the same `snake_case` key names are accessed with dot-notation:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

## BaseViewModel helper methods

These methods are always available inside any ViewModel:

`GetFormValue(key)` — reads a field from a URL-encoded POST body. Lazily parses the body on first call and caches the result.

```xojo
Var title As String = GetFormValue("title")
Var body  As String = GetFormValue("body")
```

`GetParam(key)` — reads a URL path parameter or query string parameter. Path params take priority over query string params.

```xojo
// For route /notes/:id with URL /notes/42
Var id As Integer = GetParam("id").ToInteger()

// For URL /notes?sort=asc
Var sort As String = GetParam("sort")
```

`Render(templateName, context)` — compiles and renders a template, auto-injects flash messages, and writes the HTML response.

```xojo
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

`Redirect(url, statusCode)` — sends an HTTP redirect. Default status is 302. Always call `Return` immediately after to stop execution.

```xojo
Redirect("/notes")
Return
```

`SetFlash(message, type)` — stores a flash message in the session. The next call to `Render()` on any ViewModel will inject it into the template context automatically. Type is `"success"`, `"error"`, or `"info"`.

```xojo
SetFlash("Note created.", "success")
Redirect("/notes")
Return
```
