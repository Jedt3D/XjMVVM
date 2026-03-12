---
title: คู่มือการใช้งาน
description: วิธีใช้ไวยากรณ์ Jinja2 — ตัวแปร บล็อก ลูป เงื่อนไข ตัวกรอง และการสืบทอดเทมเพลต
---

# คู่มือการใช้งาน

## การสืบทอดเทมเพลต

เทมเพลตแต่ละหน้าเริ่มต้นด้วยการขยาย (extend) เลย์เอาต์ฐาน:

```html
{# templates/notes/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Notes{% endblock %}

{% block content %}
  <h1>All Notes</h1>
  {# page content here #}
{% endblock %}
```

เลย์เอาต์ฐานกำหนด named blocks ที่เทมเพลตลูกสามารถเติมข้อมูลเข้าไป:

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

เทมเพลตลูกสามารถเขียนทับ (override) เฉพาะบล็อก (blocks) ที่ถูกกำหนดไว้ในพาเรนต์เท่านั้น เนื้อหาที่อยู่นอก `{% block %}` tags ในเทมเพลตลูกจะถูกละเว้น

## ตัวแปร

แสดงผลตัวแปรด้วยวงเล็บปีกกาคู่ (double curly braces) HTML จะถูกหลีกเลี่ยงอัตโนมัติ — `<script>` จะกลายเป็น `&lt;script&gt;`:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

ตัวแปรมาจาก context `Dictionary` ที่คุณส่งไปยัง `Render()` คีย์ของ Dictionary จะกลายเป็นชื่อตัวแปรในเทมเพลต

### Dot-notation ของ Dictionary

JinjaX แก้ไข `{{ note.title }}` โดยเรียก `note.Value("title")` บน `Dictionary` นี่คือเหตุผลหลักว่าทำไมข้อมูลทั้งหมดต้องเป็น Dictionary objects — เพียงแต่ Dictionary เท่านั้นที่รองรับ dot-notation lookup ผ่าน `EvaluateGetAttr`

### ผลลัพธ์แบบดิบ (ไม่ escape)

หากคุณต้องการแสดงผล HTML ที่ render ไว้ก่อนแล้ว (เฉพาะเนื้อหาที่เชื่อถือได้):

```html
{{ content | safe }}
```

อย่าใช้ `| safe` กับเนื้อหาที่มาจากผู้ใช้

## เงื่อนไข

```html
{% if note %}
  <h1>Edit: {{ note.title }}</h1>
{% elif draft %}
  <h1>Draft</h1>
{% else %}
  <h1>New Note</h1>
{% endif %}
```

ค่าที่ falsy ใน Jinja2: `False`, `0`, `""` (สตริงว่าง), `[]` (อาเรย์ว่าง), `None`/`Nil` คีย์ที่หายไปถือว่า falsy

## ลูป

ทำซ้ำบนอาเรย์ `Variant()` ของ Dictionary objects:

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

บล็อก `{% else %}` จะแสดงผลเมื่ออาเรย์ว่าง

### ตัวแปร loop

ภายในบล็อก `{% for %}` จะมี special `loop` variables ให้ใช้:

| ตัวแปร | ค่า |
|---|---|
| `loop.index` | การทำซ้ำปัจจุบัน, นับจาก 1 |
| `loop.index0` | การทำซ้ำปัจจุบัน, นับจาก 0 |
| `loop.first` | `True` ในการทำซ้ำแรก |
| `loop.last` | `True` ในการทำซ้ำสุดท้าย |
| `loop.length` | จำนวนรายการทั้งหมด |

```html
{% for note in notes %}
  {% if loop.first %}<ul>{% endif %}
  <li class="{% if loop.last %}last{% endif %}">
    {{ loop.index }}. {{ note.title }}
  </li>
  {% if loop.last %}</ul>{% endif %}
{% endfor %}
```

## ตัวกรอง

ตัวกรองแปลงค่าโดยใช้ pipe `|` operator:

```html
{{ note.title | upper }}
{{ note.title | lower }}
{{ note.body  | truncate(100) }}
{{ notes      | length }}
{{ note.title | default("Untitled") }}
{{ note.title | replace("foo", "bar") }}
```

ตัวกรองสามารถทำต่อเนื่องกันได้:

```html
{{ note.title | upper | truncate(50) }}
```

## การรวม (include) เทมเพลต

รวมเทมเพลต partial:

```html
{% include "partials/pagination.html" %}
```

เทมเพลตที่รวมเข้า (included template) ร่วมใช้ context เดียวกับพาเรนต์ — มันสามารถเข้าถึงตัวแปรเดียวกันทั้งหมด

## ความเห็น (Comments)

ความเห็นในเทมเพลตไม่ถูกส่งไปยังเบราว์เซอร์:

```html
{# This comment is stripped from the output #}
```

ความเห็น HTML ถูกส่งไปยังเบราว์เซอร์:

```html
<!-- This comment appears in the page source -->
```

## การควบคุม whitespace

ใช้ `-` เพื่อตัด (strip) whitespace รอบ tag:

```html
{%- for note in notes -%}
  {{ note.title }}
{%- endfor -%}
```

มีประโยชน์เมื่อสร้าง JSON หรือ CSV ที่กระชับจากเทมเพลต

## การส่ง context จาก ViewModel

ทุกอย่างใน context `Dictionary` จะกลายเป็นตัวแปรเทมเพลต:

```xojo
Sub OnGet()
  Var ctx As New Dictionary()
  ctx.Value("notes")      = NoteModel.GetAll()   // Variant() of Dictionary
  ctx.Value("page_title") = "All Notes"
  ctx.Value("is_admin")   = False
  Render("notes/list.html", ctx)
End Sub
```

ในเทมเพลต:

```html
<title>{{ page_title }}</title>
{% if is_admin %}<a href="/admin">Admin</a>{% endif %}
{% for note in notes %}...{% endfor %}
```

Flash messages ถูกฉีด (inject) โดยอัตโนมัติโดย `BaseViewModel.Render()` — คุณไม่ต้องเพิ่มมันลงใน context ด้วยตัวเอง