---
title: ข้อมูลอ้างอิง Tag และ Filter
description: ข้อมูลอ้างอิงที่ครบถ้วนสำหรับ Jinja2 tag และ filter ทั้งหมดที่ JinjaX รองรับ พร้อมหมายเหตุสำหรับ Xojo
---

# ข้อมูลอ้างอิง Tag และ Filter

## Tag

Tag ใช้ delimiter `{% %}` และควบคุมตรรกะของ template นั่นเอง tag ของ Jinja2 block มาตรฐานทั้งหมดได้รับการสนับสนุนจาก JinjaX

### `{% extends %}`

สืบทอดมาจาก parent template สิ่งสำคัญคือ tag นี้ต้องเป็น **tag แรก** ในไฟล์

```html
{% extends "layouts/base.html" %}
```

Template สามารถสืบทอดจาก parent เพียงตัวเดียวเท่านั้น Child template สามารถกำหนดเนื้อหาได้เฉพาะภายใน `{% block %}` tag เท่านั้น

### `{% block %}`

กำหนดพื้นที่ที่สามารถแทนที่ได้ ใน parent จะตั้งเนื้อหาเริ่มต้น ใน child จะแทนที่เนื้อหาเดิม

```html
{# In parent (base.html) #}
{% block title %}Default Title{% endblock %}

{# In child — overrides #}
{% block title %}Notes List{% endblock %}
```

เรียก `{{ super() }}` ภายใน child block เพื่อรวมเนื้อหาของ parent ด้วย

```html
{% block title %}{{ super() }} — Notes{% endblock %}
{# Renders: "Default Title — Notes" #}
```

### `{% include %}`

แทรก template อื่นในตำแหน่งนี้ ไฟล์ที่รวมไว้จะแบ่ง context ปัจจุบัน

```html
{% include "partials/pagination.html" %}
{% include "partials/nav.html" %}
```

ใช้ `ignore missing` เพื่อข้ามไปโดยเงียบเมื่อไฟล์ไม่มีอยู่

```html
{% include "partials/optional.html" ignore missing %}
```

### `{% if %} / {% elif %} / {% else %} / {% endif %}`

เอาต์พุตแบบมีเงื่อนไข

```html
{% if user %}
  Hello, {{ user.name }}
{% elif guest %}
  Hello, guest
{% else %}
  Please log in
{% endif %}
```

ตัวดำเนินการที่รองรับ: `==`, `!=`, `<`, `>`, `<=`, `>=`, `and`, `or`, `not`, `in`, `is`

```html
{% if notes | length > 0 and is_admin %}
{% if note.title is not none %}
{% if "admin" in user.roles %}
```

### `{% for %} / {% else %} / {% endfor %}`

วนซ้ำผ่าน array `Variant()` Block `{% else %}` จะแสดงผลเมื่อลำดับว่างเปล่า

```html
{% for note in notes %}
  <p>{{ note.title }}</p>
{% else %}
  <p>No notes.</p>
{% endfor %}
```

ตัวแปร loop ที่พร้อมใช้งานภายใน block

| Variable | Type | Description |
|---|---|---|
| `loop.index` | Integer | จำนวนการวนซ้ำโดยเริ่มจาก 1 |
| `loop.index0` | Integer | จำนวนการวนซ้ำโดยเริ่มจาก 0 |
| `loop.first` | Boolean | True ในการวนซ้ำครั้งแรก |
| `loop.last` | Boolean | True ในการวนซ้ำครั้งสุดท้าย |
| `loop.length` | Integer | จำนวนรายการทั้งหมดในลำดับ |

### `{% set %}`

กำหนดตัวแปรภายใน template

```html
{% set count = notes | length %}
<p>{{ count }} note{{ "s" if count != 1 else "" }}</p>

{% set full_name = user.first_name + " " + user.last_name %}
```

### `{% macro %} / {% endmacro %}`

กำหนดฟังก์ชัน template ที่นำกลับมาใช้ได้

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

สร้าง scope ชั่วคราวพร้อมตัวแปรท้องถิ่น

```html
{% with error = "Title is required" %}
  <p class="error">{{ error }}</p>
{% endwith %}
```

### `{% raw %} / {% endraw %}`

เอาต์พุตไวยากรณ์ Jinja2 ตามตัวอักษร — มีประโยชน์เมื่อรวมสตริง template ของ JavaScript

```html
{% raw %}
  <script>
    const template = `Hello {{ name }}`; // not processed by Jinja
  </script>
{% endraw %}
```

### `{% comment %}` / `{# #}`

ความเห็นของ template — ไม่ส่งไปยังเบราว์เซอร์

```html
{# This is a comment — stripped from output #}
```

---

## Filter

Filter เปลี่ยนแปลงค่าโดยใช้ตัวดำเนินการ pipe `|` สามารถต่อ filter หลายตัวได้

### String filter

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

### Sequence filter

| Filter | Example | Result |
|---|---|---|
| `length` | `{{ notes \| length }}` | จำนวนรายการ |
| `first` | `{{ notes \| first }}` | รายการแรก |
| `last` | `{{ notes \| last }}` | รายการสุดท้าย |
| `reverse` | `{% for n in notes \| reverse %}` | การวนซ้ำแบบกลับด้าน |
| `sort` | `{% for n in notes \| sort(attribute="title") %}` | การวนซ้ำแบบเรียงลำดับ |
| `join(sep)` | `{{ tags \| join(", ") }}` | `"a, b, c"` |

### Type/safety filter

| Filter | Description |
|---|---|
| `safe` | ทำเครื่องหมาย HTML เป็นที่เชื่อถือได้ — บายพาส autoescape ไม่ควรใช้กับข้อมูลป้อนข้อมูลของผู้ใช้ |
| `int` | แปลงเป็นจำนวนเต็ม |
| `float` | แปลงเป็นทศนิยม |
| `string` | แปลงเป็นสตริง |
| `default(val)` | ใช้ `val` หากตัวแปรไม่ได้กำหนดหรือว่างเปล่า |

### Custom filter (โครงการนี้)

ลงทะเบียน custom filter ใน `App.Opening()` ด้วย `mJinja.RegisterFilter(name, AddressOf func)`

ลายเซ็นฟังก์ชัน filter

```xojo
Function MyFilter(value As Variant) As Variant
  // transform value, return result
End Function
```

---

## ข้อจำกัดเฉพาะ Xojo

นี่คือข้อจำกัดเมื่อเทียบกับ Jinja2 Python เต็มรูปแบบ — รู้จักพวกเขาเพื่อหลีกเลี่ยงข้อผิดพลาดที่เงียบ

**Dictionary เท่านั้นสำหรับการใช้ dot-notation** `{{ obj.key }}` ใช้ได้เฉพาะเมื่อ `obj` เป็น `Dictionary` เท่านั้น ไม่รองรับ instance ของคลาสที่กำหนดเอง — คุณสมบัติของคลาสเหล่านั้นไม่สามารถเข้าถึงได้ผ่าน dot-notation ใน template

**ไม่มีการเรียกเมธอดกับ object** `{{ note.title.upper() }}` ไม่ทำงาน ใช้ filter แทนนั้น: `{{ note.title | upper }}`

**ไม่มี Python built-in** `range()`, `enumerate()`, `zip()` และ Python built-in ที่คล้ายกันไม่พร้อมใช้งาน สร้างข้อมูลที่คุณต้องการใน ViewModel ก่อนส่งไปยัง template

**Array ต้องเป็น `Variant()`** ส่ง array เป็น `Variant()` (ไม่ใช่ array ที่มีประเภทเช่น `String()` หรือ `Integer()`) `RenderFor` ของ JinjaX คาดหวัง `Variant()`

**`Nil` เป็นค่า falsy** Key ของ `Dictionary` ที่มีค่าเป็น `Nil` ประเมินผลเป็น falsy ในการทดสอบ `{% if %}` Key ที่ขาดหายไปจะประเมินผลเป็น falsy ด้วย (ไม่ใช่ข้อผิดพลาด)