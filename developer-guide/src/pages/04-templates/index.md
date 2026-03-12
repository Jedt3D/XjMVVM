---
title: JinjaX Overview
description: What JinjaX is, how it fits into the framework, and how it's set up in App.Opening().
---

# JinjaX & Templates

JinjaX is a pure-Xojo implementation of the Jinja2 template engine. It lets you write HTML templates with a syntax that's compatible with Python's Jinja2 — the same engine used by Flask and Django.

## What JinjaX provides

- **Template inheritance** — `{% extends "layouts/base.html" %}` with `{% block %}` overrides
- **Template includes** — `{% include "partials/nav.html" %}`
- **Variable output** — `{{ variable }}` with automatic HTML escaping
- **Control flow** — `{% if %}`, `{% for %}`, `{% else %}`, `{% elif %}`
- **Filters** — `{{ value | upper }}`, `{{ value | length }}`, custom filters
- **Autoescape** — XSS protection enabled by default

## Project source

JinjaX lives under `JinjaXLib/` in the project root. It's included as full Xojo source rather than a compiled library, so it works with the text-format `.xojo_code` project files and can be inspected or debugged if needed.

Do not modify `JinjaXLib/` unless you're intentionally upgrading or patching JinjaX.

## Setup in App.Opening()

The `JinjaEnvironment` is initialized once when the application starts and stored on `App` as a shared singleton. It is read-only after `Opening()` completes, which makes it thread-safe:

```xojo
// In App.Opening()

// 1. Create the environment
mJinja = New JinjaX.JinjaEnvironment()

// 2. Point it at your templates folder
//    Use an absolute path so it works from any IDE debug output location
Var projectDir As New FolderItem("/path/to/mvvm", FolderItem.PathModes.Native)
Var templatesDir As FolderItem = projectDir.Child("templates")
mJinja.Loader = New JinjaX.FileSystemLoader(templatesDir)

// 3. Enable autoescape (protects against XSS — always on)
mJinja.Autoescape = True

// 4. Register custom filters
mJinja.RegisterFilter("truncate80", AddressOf TruncateFilter)
```

## Registering a custom filter

A filter is a Xojo method that takes a `Variant` and returns a `Variant`. Register it with a string name that templates use with the pipe `|` operator:

```xojo
// In App.xojo_code (or a Filters module)
Function TruncateFilter(value As Variant) As Variant
  Var s As String = value.StringValue
  If s.Length > 80 Then
    Return s.Left(77) + "..."
  End If
  Return s
End Function

// Register in Opening():
mJinja.RegisterFilter("truncate80", AddressOf TruncateFilter)
```

In a template:

```html
{{ note.body | truncate80 }}
```

## Accessing the environment from a ViewModel

The `JinjaEnvironment` is passed from the Router to each ViewModel before `Handle()` is called. `BaseViewModel` stores it as the `Jinja` property. You never access it directly — just call `Render()`:

```xojo
// In any ViewModel — Render() uses Self.Jinja internally
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

## Thread safety

`JinjaEnvironment` is safe to share across threads **after** `Opening()` completes, because:

- `RegisterFilter` is only called during `Opening()` — never during a request
- `GetTemplate()` and `Render()` only read from the environment
- `CompiledTemplate` and `JinjaContext` are created fresh per-request (stack-allocated, not shared)

Each request gets its own `CompiledTemplate` and `JinjaContext` — these are not shared.
