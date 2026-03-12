---
title: Examples
description: Real template examples taken from the notes feature — base layout, list, detail, shared form.
---

# Examples

These are the actual templates used by the notes feature, with annotations.

## Base layout

The base layout defines the site structure. Every page template extends this:

```html
{# templates/layouts/base.html #}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% block title %}App{% endblock %} | XjMVVM</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 800px;
           margin: 0 auto; padding: 20px; }
    /* ... */
  </style>
</head>
<body>
  <nav>
    <a href="/">Home</a>
    <a href="/notes">Notes</a>
  </nav>

  {# Flash messages are injected by BaseViewModel.Render() automatically #}
  {% if flash %}
  <div class="flash flash-{{ flash.type }}">{{ flash.message }}</div>
  {% endif %}

  <main>
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

The `flash` variable is a `Dictionary` with two keys: `type` (`"success"`, `"error"`, `"info"`) and `message` (the string). It's injected automatically — any ViewModel can call `SetFlash()` and the message appears on the next rendered page.

## Notes list

```html
{# templates/notes/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Notes{% endblock %}

{% block content %}
<div style="display:flex; justify-content:space-between; align-items:center;">
  <h1>Notes</h1>
  <a href="/notes/new" class="btn btn-primary">New Note</a>
</div>

{% if notes %}
  {% for note in notes %}
  <div style="border:1px solid #ddd; padding:15px; margin:10px 0; border-radius:4px;">
    <h3 style="margin:0 0 8px">
      <a href="/notes/{{ note.id }}">{{ note.title }}</a>
    </h3>
    <p style="color:#666; margin:0 0 10px">{{ note.body }}</p>
    <small style="color:#999">Updated: {{ note.updated_at }}</small>
    <div style="margin-top:10px;">
      <a href="/notes/{{ note.id }}/edit" class="btn btn-sm">Edit</a>
      {# Delete via a POST form — no DELETE method in HTML #}
      <form method="post" action="/notes/{{ note.id }}/delete"
            style="display:inline"
            onsubmit="return confirm('Delete this note?')">
        <button type="submit" class="btn btn-danger btn-sm">Delete</button>
      </form>
    </div>
  </div>
  {% endfor %}
{% else %}
  <p>No notes yet. <a href="/notes/new">Create your first note.</a></p>
{% endif %}
{% endblock %}
```

Key points: `note.id`, `note.title`, `note.body`, `note.updated_at` are Dictionary keys. The delete action is a `POST` form because HTML forms only support GET and POST — there's no HTTP DELETE in a browser form.

## Shared create/edit form

One template serves both the new note form and the edit form. The presence of the `note` variable determines which mode is active:

```html
{# templates/notes/form.html #}
{% extends "layouts/base.html" %}

{% block title %}{% if note %}Edit Note{% else %}New Note{% endif %}{% endblock %}

{% block content %}
<h1>{% if note %}Edit Note{% else %}New Note{% endif %}</h1>

{# Switch form action and populate values based on mode #}
<form method="post" action="{% if note %}/notes/{{ note.id }}{% else %}/notes{% endif %}">
  <div>
    <label for="title">Title <span style="color:red">*</span></label>
    <input type="text" id="title" name="title"
           value="{{ note.title if note else '' }}"
           required>
  </div>
  <div>
    <label for="body">Body</label>
    <textarea id="body" name="body">{{ note.body if note else '' }}</textarea>
  </div>
  <button type="submit" class="btn btn-primary">
    {% if note %}Save Changes{% else %}Create Note{% endif %}
  </button>
  <a href="{% if note %}/notes/{{ note.id }}{% else %}/notes{% endif %}"
     class="btn">Cancel</a>
</form>
{% endblock %}
```

The `NotesNewVM` passes no `note` key (or passes `Nil`) — the form renders in create mode. `NotesEditVM` passes the loaded `note` Dictionary — the form pre-populates with existing values.

## Note detail

```html
{# templates/notes/detail.html #}
{% extends "layouts/base.html" %}

{% block title %}{{ note.title }}{% endblock %}

{% block content %}
<div style="display:flex; justify-content:space-between; align-items:center;">
  <h1>{{ note.title }}</h1>
  <div>
    <a href="/notes/{{ note.id }}/edit" class="btn">Edit</a>
    <form method="post" action="/notes/{{ note.id }}/delete"
          style="display:inline"
          onsubmit="return confirm('Delete this note?')">
      <button type="submit" class="btn btn-danger">Delete</button>
    </form>
  </div>
</div>

<div style="white-space:pre-wrap; margin:20px 0;">{{ note.body }}</div>
<small style="color:#999">
  Created: {{ note.created_at }} · Updated: {{ note.updated_at }}
</small>

<div style="margin-top:20px;">
  <a href="/notes">← Back to Notes</a>
</div>
{% endblock %}
```

`white-space:pre-wrap` preserves line breaks in the body text without needing to convert `\n` to `<br>` — useful for plain-text body content.

## Error pages

Error templates are passed `status_code` and `message` by the Router's `Serve404()` and `Serve500()` methods:

```html
{# templates/errors/404.html #}
{% extends "layouts/base.html" %}
{% block title %}404 Not Found{% endblock %}
{% block content %}
<h1>404 — Page Not Found</h1>
<p>{{ message }}</p>
<a href="/">Go home</a>
{% endblock %}
```

Error templates do not need to worry about flash messages — they're rendered by the Router directly, before any ViewModel has a chance to run.
