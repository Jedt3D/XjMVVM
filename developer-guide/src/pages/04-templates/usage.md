---
title: Usage Guide
description: How to use Jinja2 template syntax — variables, blocks, loops, conditions, filters, and template inheritance.
---

# Usage Guide

## Template inheritance

Every page template starts by extending the base layout:

```html
{# templates/notes/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Notes{% endblock %}

{% block content %}
  <h1>All Notes</h1>
  {# page content here #}
{% endblock %}
```

The base layout defines named blocks that child templates fill in:

```html
{# templates/layouts/base.html #}
<!DOCTYPE html>
<html>
<head>
  <title>{% block title %}App{% endblock %} | XjMVVM</title>
</head>
<body>
  <nav>...</nav>

  {% if flash %}
  <div class="flash flash-{{ flash.type }}">{{ flash.message }}</div>
  {% endif %}

  <main>
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

A child template can only override blocks that are defined in the parent. Content outside of `{% block %}` tags in a child template is ignored.

## Variables

Output a variable with double curly braces. HTML is automatically escaped — `<script>` becomes `&lt;script&gt;`:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

Variables come from the context `Dictionary` you pass to `Render()`. Dictionary keys become variable names in the template.

### Dictionary dot-notation

JinjaX resolves `{{ note.title }}` by calling `note.Value("title")` on the `Dictionary`. This is the core reason all data must be `Dictionary` objects — only `Dictionary` supports the dot-notation lookup via `EvaluateGetAttr`.

### Raw output (no escaping)

If you need to output pre-rendered HTML (trusted content only):

```html
{{ content | safe }}
```

Never use `| safe` on user-supplied content.

## Conditions

```html
{% if note %}
  <h1>Edit: {{ note.title }}</h1>
{% elif draft %}
  <h1>Draft</h1>
{% else %}
  <h1>New Note</h1>
{% endif %}
```

Falsy values in Jinja2: `False`, `0`, `""` (empty string), `[]` (empty array), `None`/`Nil`. A missing key is treated as falsy.

## Loops

Iterate over a `Variant()` array of `Dictionary` objects:

```html
{% for note in notes %}
  <div class="note">
    <h2>{{ note.title }}</h2>
    <p>{{ note.body }}</p>
    <time>{{ note.updated_at }}</time>
  </div>
{% else %}
  <p>No notes yet. <a href="/notes/new">Create one.</a></p>
{% endfor %}
```

The `{% else %}` block renders when the array is empty.

### Loop variables

Inside a `{% for %}` block, special `loop` variables are available:

| Variable | Value |
|---|---|
| `loop.index` | Current iteration, 1-based |
| `loop.index0` | Current iteration, 0-based |
| `loop.first` | `True` on the first iteration |
| `loop.last` | `True` on the last iteration |
| `loop.length` | Total number of items |

```html
{% for note in notes %}
  {% if loop.first %}<ul>{% endif %}
  <li class="{% if loop.last %}last{% endif %}">
    {{ loop.index }}. {{ note.title }}
  </li>
  {% if loop.last %}</ul>{% endif %}
{% endfor %}
```

## Filters

Filters transform a value using the pipe `|` operator:

```html
{{ note.title | upper }}
{{ note.title | lower }}
{{ note.body  | truncate(100) }}
{{ notes      | length }}
{{ note.title | default("Untitled") }}
{{ note.title | replace("foo", "bar") }}
```

Filters can be chained:

```html
{{ note.title | upper | truncate(50) }}
```

## Template includes

Include a partial template:

```html
{% include "partials/pagination.html" %}
```

The included template shares the same context as the parent — it can access all the same variables.

## Comments

Template comments are not sent to the browser:

```html
{# This comment is stripped from the output #}
```

HTML comments are sent to the browser:

```html
<!-- This comment appears in the page source -->
```

## Whitespace control

Use `-` to strip whitespace around a tag:

```html
{%- for note in notes -%}
  {{ note.title }}
{%- endfor -%}
```

Useful when generating compact JSON or CSV from a template.

## Passing context from a ViewModel

Everything in the context `Dictionary` becomes a template variable:

```xojo
Sub OnGet()
  Var ctx As New Dictionary()
  ctx.Value("notes")      = NoteModel.GetAll()   // Variant() of Dictionary
  ctx.Value("page_title") = "All Notes"
  ctx.Value("is_admin")   = False
  Render("notes/list.html", ctx)
End Sub
```

In the template:

```html
<title>{{ page_title }}</title>
{% if is_admin %}<a href="/admin">Admin</a>{% endif %}
{% for note in notes %}...{% endfor %}
```

Flash messages are injected automatically by `BaseViewModel.Render()` — you do not add them to the context manually.
