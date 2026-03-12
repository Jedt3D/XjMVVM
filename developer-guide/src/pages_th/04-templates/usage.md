---
title: คู่มือการใช้
description: วิธีใช้ไวยากรณ์เทมเพลต Jinja2 — ตัวแปร บล็อก ลูป เงื่อนไข ตัวกรอง และการสืบทอดเทมเพลต
---

# คู่มือการใช้

## การสืบทอดเทมเพลต

เทมเพลตหน้าทุกเทมเพลตเริ่มต้นโดยขยายเลเยต์ฐาน:

```html
{# templates/notes/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Notes{% endblock %}

{% block content %}
  <h1>All Notes</h1>
  {# เนื้อหาหน้าที่นี่ #}
{% endblock %}
```

เลเยต์ฐานกำหนดบล็อกที่ชื่อว่าเทมเพลตย่อยกรอก:

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

เทมเพลตย่อยสามารถเฉพาะแทนที่บล็อกที่กำหนดไว้ในพาเรนต์ เนื้อหาภายนอกแท็ก `{% block %}` ในเทมเพลตย่อยจะถูกละเว้น

## ตัวแปร

เอาต์พุตตัวแปรด้วยวงเล็บปีกกาคู่ HTML จะถูกหลีกเลี่ยงโดยอัตโนมัติ — `<script>` กลายเป็น `&lt;script&gt;`:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

ตัวแปรมาจากพจนานุกรมบริบท `Dictionary` ที่คุณส่งไปยัง `Render()` กุญแจ Dictionary กลายเป็นชื่อตัวแปรในเทมเพลต

### สัญกรณ์จุด Dictionary

JinjaX แก้ไข `{{ note.title }}` โดยเรียก `note.Value("title")` บน `Dictionary` นี่คือเหตุผลหลักที่ข้อมูลทั้งหมดต้องเป็นอ็อบเจ็กต์ `Dictionary` — เฉพาะ `Dictionary` ที่รองรับการค้นหาสัญกรณ์จุดผ่าน `EvaluateGetAttr`

### เอาต์พุตดิบ (ไม่มีการหลีกเลี่ยง)

ถ้าคุณต้องการเอาต์พุต HTML ที่เรนเดอร์ล่วงหน้า (เนื้อหาที่เชื่อถือได้เท่านั้น):

```html
{{ content | safe }}
```

ไม่เคยใช้ `| safe` ในเนื้อหาที่ผู้ใช้จัดเตรียม

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

ค่าเท็จใน Jinja2: `False`, `0`, `""` (สตริงว่าง), `[]` (อาร์เรย์ว่าง), `None`/`Nil` กุญแจที่ขาดหายไปถูกมองว่าเป็นเท็จ

## ลูป

วนซ้ำบนอาร์เรย์ `Variant()` ของอ็อบเจ็กต์ `Dictionary`:

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

บล็อก `{% else %}` เรนเดอร์เมื่ออาร์เรย์ว่าง

### ตัวแปรลูป

ภายในบล็อก `{% for %}` ตัวแปร `loop` พิเศษจะพร้อมใช้งาน:

| ตัวแปร | ค่า |
|---|---|
| `loop.index` | การวนซ้ำปัจจุบัน 1-based |
| `loop.index0` | การวนซ้ำปัจจุบัน 0-based |
| `loop.first` | `True` ในการวนซ้ำครั้งแรก |
| `loop.last` | `True` ในการวนซ้ำสุดท้าย |
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

ตัวกรองแปลงค่าโดยใช้ตัวดำเนินการ pipe `|`:

```html
{{ note.title | upper }}
{{ note.title | lower }}
{{ note.body  | truncate(100) }}
{{ notes      | length }}
{{ note.title | default("Untitled") }}
{{ note.title | replace("foo", "bar") }}
```

ตัวกรองสามารถเชื่อมโยงได้:

```html
{{ note.title | upper | truncate(50) }}
```

## รวมเทมเพลต

รวมเทมเพลตบางส่วน:

```html
{% include "partials/pagination.html" %}
```

เทมเพลตที่รวมใช้บริบทเดียวกันกับพาเรนต์ — สามารถเข้าถึงตัวแปรเดียวกันได้ทั้งหมด

## ความเห็น

ความเห็นเทมเพลตไม่ได้ถูกส่งไปยังเบราว์เซอร์:

```html
{# ความเห็นนี้ถูกลบออกจากเอาต์พุต #}
```

ความเห็น HTML ถูกส่งไปยังเบราว์เซอร์:

```html
<!-- ความเห็นนี้ปรากฏในแหล่งหน้า -->
```

## การควบคุมช่องว่าง

ใช้ `-` เพื่อลบช่องว่างรอบแท็ก:

```html
{%- for note in notes -%}
  {{ note.title }}
{%- endfor -%}
```

มีประโยชน์เมื่อสร้าง JSON หรือ CSV ขนาดกะทัดรัดจากเทมเพลต

## ส่งบริบทจาก ViewModel

ทุกอย่างในพจนานุกรมบริบท `Dictionary` กลายเป็นตัวแปรเทมเพลต:

```xojo
Sub OnGet()
  Var ctx As New Dictionary()
  ctx.Value("notes")      = NoteModel.GetAll()   // Variant() ของ Dictionary
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

ข้อความแฟลชถูกฉีดโดยอัตโนมัติโดย `BaseViewModel.Render()` — คุณไม่ต้องเพิ่มลงในบริบทด้วยตนเอง
