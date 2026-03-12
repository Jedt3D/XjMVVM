---
title: Why XjMVVM?
description: The architectural decisions behind XjMVVM — why we bypass Xojo's WebPage system and why the MVVM pattern with JinjaX.
---

# Why XjMVVM?

This page explains the key decisions behind the framework design. Understanding the *why* makes every convention elsewhere in this guide make sense.

## Why bypass Xojo's WebPage system?

Xojo Web 2 provides a full GUI widget system: `WebPage`, `WebButton`, `WebTextField`, `WebListBox`, and so on. These controls communicate over WebSockets and manage state automatically. For simple internal tools that closely mirror Xojo's widget model, they work well.

This project bypasses that system entirely. Here's why:

**Full HTML/CSS control.** WebControls render their own HTML with their own class names and structure. You cannot easily apply a custom design system or integrate a CSS framework like Tailwind without fighting the control output. With JinjaX templates you write the HTML yourself — every tag, every class, every data attribute is yours.

**Standard HTTP semantics.** WebControl pages are stateful WebSocket sessions. They don't behave like standard HTTP apps: bookmarking is unreliable, browser history is awkward, REST APIs are harder to add. An SSR approach means every URL is a proper HTTP endpoint — predictable, cacheable, linkable.

**Designer-friendly templates.** HTML templates live in the `templates/` folder. A designer or front-end developer can edit them using any text editor with full IDE support (syntax highlighting, Emmet, Prettier). They never touch Xojo code.

**No session state in the UI layer.** Xojo WebControls carry implicit session state. Our ViewModels are stateless per-request — they receive a request, do work, and write a response. The only persistent state is in `Session` (the `WebSession` class) and the database.

## Why MVVM over MVC?

Classic MVC (Model-View-Controller) has the Controller responsible for both routing logic and orchestrating Models. In Xojo, this would mean one large controller class handling every route.

XjMVVM uses MVVM to separate concerns more cleanly for a per-route architecture:

| Layer | Class | Responsibility |
|---|---|---|
| **View** | Jinja2 `.html` files | Presentation only — no business logic |
| **ViewModel** | One class per route | Orchestrates Models, builds template context |
| **Model** | Data access classes | Database queries, returns `Dictionary` objects |

One ViewModel per route (e.g. `NotesListVM`, `NotesCreateVM`) keeps each class small and focused. Adding a new feature means adding new files, not modifying existing ones.

The dependency direction is strictly one-way:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 40
#padding: 8
#lineWidth: 1.5
[View] -> [ViewModel]
[ViewModel] -> [Model]
[Model] SQL -> [<database> Database]
[<database> Database] rows -> [Model]
[Model] Dictionary -> [ViewModel]
[ViewModel] context -> [View]
-->
<!-- ascii
View  →  ViewModel  →  Model  →  Database
-->
<!-- /diagram -->

ViewModels never reference template names in business logic. Models never reference ViewModels. This makes each layer independently testable and replaceable.

## Why JinjaX?

JinjaX is a port of Python's Jinja2 template engine written in pure Xojo. It was chosen because:

**Jinja2 is the de-facto standard.** Developers familiar with Flask, Django, Ansible, or Saltstack already know the syntax. The learning curve is minimal.

**It's pure Xojo source.** The full JinjaX source tree lives under `JinjaXLib/`. There's no binary `.xojo_library` dependency, which means it works with Xojo's text project format (`.xojo_code` files) and is fully inspectable and debuggable.

**It's thread-safe after setup.** The `JinjaEnvironment` is initialized once in `App.Opening()` and then read-only. Each request creates a fresh `CompiledTemplate` and `JinjaContext` — these are per-request objects, never shared.

**Template inheritance works.** `{% extends %}`, `{% block %}`, and `{% include %}` let you build a base layout once and compose all pages from it.

## The Dictionary data contract

This is the single most important rule in the entire system.

JinjaX resolves dot-notation (`{{ note.title }}`) by calling `EvaluateGetAttr` on the object. In Xojo, `EvaluateGetAttr` is only implemented for `Dictionary` — it looks up the key by name. Custom Xojo class instances do not support `EvaluateGetAttr`, so dot-access silently renders as empty.

**The rule:** every piece of data passed to a template must be a `Dictionary` or a `Variant()` array of `Dictionary` objects. Models always return one of these two types — never a custom class instance.

```xojo
// ✅ Correct — Dictionary keys work with dot-notation in templates
Var row As New Dictionary()
row.Value("title") = rs.Column("title").StringValue
row.Value("body")  = rs.Column("body").StringValue
results.Add(row)   // Variant() array of Dictionary

// ❌ Wrong — custom class instance, dot-access silently fails in templates
Var note As New NoteClass()
note.Title = rs.Column("title").StringValue
results.Add(note)  // {{ note.title }} renders as empty string
```

In templates, arrays must be `Variant()` containing `Dictionary` objects:

```html
{% for note in notes %}
  <h2>{{ note.title }}</h2>   {# works — Dictionary key lookup #}
  <p>{{ note.body }}</p>
{% endfor %}
```

## Post/Redirect/Get

All form submissions follow the **Post/Redirect/Get (PRG)** pattern:

1. Browser submits form → `POST /notes` (handled by `NotesCreateVM`)
2. ViewModel validates and creates the note
3. ViewModel calls `Redirect("/notes")` — HTTP 302
4. Browser follows redirect → `GET /notes` (handled by `NotesListVM`)
5. Browser renders the list page

This prevents the browser from re-submitting the form on refresh (the "Reload this page?" dialog). It also means every page the user sees was produced by a GET request — browser history, bookmarking, and the back button all work correctly.

If validation fails, the ViewModel does **not** redirect — it re-renders the form with an error flash message using the same GET template:

```xojo
// Validation failure — re-render, no redirect
If title.Trim = "" Then
  SetFlash("Title is required", "error")
  Redirect("/notes/new")
  Return
End If
```

## Session isolation

`App` is a shared singleton — every user's request runs in the same `App` instance. Never store user-specific data on `App` properties.

Per-user state goes in the `Session` class (which inherits from `WebSession`). Each browser session gets its own `Session` instance automatically by Xojo's runtime:

```
App.mRouter      → shared, read-only after Opening()  ✅ safe
App.mJinja       → shared, read-only after Opening()  ✅ safe
Session.userID   → per-user, one instance per browser  ✅ safe
App.currentUser  → shared across ALL users             ❌ never do this
```
