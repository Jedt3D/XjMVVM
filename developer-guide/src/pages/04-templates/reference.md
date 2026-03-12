---
title: Tag & Filter Reference
description: Complete reference for every Jinja2 tag and filter supported by JinjaX, with Xojo-specific notes.
---

# Tag & Filter Reference

## Tags

Tags use `{% %}` delimiters and control template logic. All standard Jinja2 block tags are supported by JinjaX.

### `{% extends %}`

Inherit from a parent template. Must be the **first** tag in the file.

```html
{% extends "layouts/base.html" %}
```

A template can only extend one parent. The child template can only define content inside `{% block %}` tags.

### `{% block %}`

Define an overridable region. In the parent, sets the default content. In the child, replaces it.

```html
{# In parent (base.html) #}
{% block title %}Default Title{% endblock %}

{# In child — overrides #}
{% block title %}Notes List{% endblock %}
```

Call `{{ super() }}` inside a child block to include the parent's content:

```html
{% block title %}{{ super() }} — Notes{% endblock %}
{# Renders: "Default Title — Notes" #}
```

### `{% include %}`

Insert another template at this point. The included file shares the current context.

```html
{% include "partials/pagination.html" %}
{% include "partials/nav.html" %}
```

Use `ignore missing` to silently skip if the file doesn't exist:

```html
{% include "partials/optional.html" ignore missing %}
```

### `{% if %} / {% elif %} / {% else %} / {% endif %}`

Conditional output.

```html
{% if user %}
  Hello, {{ user.name }}
{% elif guest %}
  Hello, guest
{% else %}
  Please log in
{% endif %}
```

Supported operators: `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`, `in`, `is`.

```html
{% if notes | length > 0 and is_admin %}
{% if note.title is not none %}
{% if "admin" in user.roles %}
```

### `{% for %} / {% else %} / {% endfor %}`

Iterate over a `Variant()` array. The `{% else %}` block renders when the sequence is empty.

```html
{% for note in notes %}
  <p>{{ note.title }}</p>
{% else %}
  <p>No notes.</p>
{% endfor %}
```

Loop variables available inside the block:

| Variable | Type | Description |
|---|---|---|
| `loop.index` | Integer | 1-based iteration count |
| `loop.index0` | Integer | 0-based iteration count |
| `loop.first` | Boolean | True on first iteration |
| `loop.last` | Boolean | True on last iteration |
| `loop.length` | Integer | Total items in sequence |

### `{% set %}`

Assign a variable within the template:

```html
{% set count = notes | length %}
<p>{{ count }} note{{ "s" if count != 1 else "" }}</p>

{% set full_name = user.first_name + " " + user.last_name %}
```

### `{% macro %} / {% endmacro %}`

Define a reusable template function:

```html
{% macro render_note(note, show_edit=True) %}
  <div class="note">
    <h3>{{ note.title }}</h3>
    {% if show_edit %}
      <a href="/notes/{{ note.id }}/edit">Edit</a>
    {% endif %}
  </div>
{% endmacro %}

{# Call it: #}
{{ render_note(note) }}
{{ render_note(note, show_edit=False) }}
```

### `{% with %} / {% endwith %}`

Create a temporary scope with local variables:

```html
{% with error = "Title is required" %}
  <p class="error">{{ error }}</p>
{% endwith %}
```

### `{% raw %} / {% endraw %}`

Output Jinja2 syntax literally — useful when including JavaScript template strings:

```html
{% raw %}
  <script>
    const template = `Hello {{ name }}`; // not processed by Jinja
  </script>
{% endraw %}
```

### `{% comment %}` / `{# #}`

Template comments — not sent to the browser:

```html
{# This is a comment — stripped from output #}
```

---

## Filters

Filters transform a value using the `|` pipe operator. Multiple filters can be chained.

### String filters

| Filter | Example | Output |
|---|---|---|
| `upper` | `{{ "hello" \| upper }}` | `HELLO` |
| `lower` | `{{ "HELLO" \| lower }}` | `hello` |
| `title` | `{{ "hello world" \| title }}` | `Hello World` |
| `capitalize` | `{{ "hello world" \| capitalize }}` | `Hello world` |
| `trim` | `{{ "  hi  " \| trim }}` | `hi` |
| `replace(a,b)` | `{{ "foo" \| replace("o","0") }}` | `f00` |
| `truncate(n)` | `{{ "long text" \| truncate(5) }}` | `lo...` |
| `wordcount` | `{{ "hi there" \| wordcount }}` | `2` |

### Sequence filters

| Filter | Example | Result |
|---|---|---|
| `length` | `{{ notes \| length }}` | Number of items |
| `first` | `{{ notes \| first }}` | First item |
| `last` | `{{ notes \| last }}` | Last item |
| `reverse` | `{% for n in notes \| reverse %}` | Reversed iteration |
| `sort` | `{% for n in notes \| sort(attribute="title") %}` | Sorted iteration |
| `join(sep)` | `{{ tags \| join(", ") }}` | `"a, b, c"` |

### Type/safety filters

| Filter | Description |
|---|---|
| `safe` | Mark HTML as trusted — bypass autoescape. Never use on user input. |
| `int` | Convert to integer |
| `float` | Convert to float |
| `string` | Convert to string |
| `default(val)` | Use `val` if the variable is undefined or empty |

### Custom filters (this project)

Register custom filters in `App.Opening()` with `mJinja.RegisterFilter(name, AddressOf func)`.

A filter function signature:

```xojo
Function MyFilter(value As Variant) As Variant
  // transform value, return result
End Function
```

---

## Xojo-specific constraints

These are limitations compared to full Python Jinja2 — know them to avoid silent errors.

**Dictionary-only dot-notation.** `{{ obj.key }}` only works when `obj` is a `Dictionary`. Custom class instances are not supported — their properties are inaccessible via dot-notation in templates.

**No method calls on objects.** `{{ note.title.upper() }}` does not work. Use filters instead: `{{ note.title | upper }}`.

**No Python built-ins.** `range()`, `enumerate()`, `zip()` and similar Python built-ins are not available. Build the data you need in the ViewModel before passing it to the template.

**Arrays must be `Variant()`.** Pass arrays as `Variant()` (not typed arrays like `String()` or `Integer()`). JinjaX's `RenderFor` expects `Variant()`.

**`Nil` is falsy.** A `Dictionary` key whose value is `Nil` evaluates as falsy in `{% if %}` tests. A missing key also evaluates as falsy (not an error).
