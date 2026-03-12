---
title: อ้างอิง แท็กและตัวกรอง
description: อ้างอิงฉบับเต็มสำหรับทุกแท็ก Jinja2 และตัวกรองที่รองรับโดย JinjaX พร้อมหมายเหตุเฉพาะ Xojo
---

# อ้างอิง แท็กและตัวกรอง

## แท็ก

แท็กใช้ตัวคั่น `{% %}` และควบคุมตรรกะเทมเพลต แท็กบล็อก Jinja2 มาตรฐานทั้งหมดรองรับโดย JinjaX

### `{% extends %}`

สืบทอดจากเทมเพลตพาเรนต์ ต้องเป็นแท็ก **แรก** ในไฟล์

```html
{% extends "layouts/base.html" %}
```

เทมเพลตสามารถขยายพาเรนต์เดียวเท่านั้น เทมเพลตย่อยสามารถกำหนดเนื้อหาเฉพาะภายในแท็ก `{% block %}`

### `{% block %}`

กำหนดพื้นที่ที่เขียนทับได้ ในพาเรนต์ ตั้งค่าเนื้อหาเริ่มต้น ในลูก ให้แทนที่

```html
{# ในพาเรนต์ (base.html) #}
{% block title %}Default Title{% endblock %}

{# ในลูก — แทนที่ #}
{% block title %}Notes List{% endblock %}
```

เรียก `{{ super() }}` ภายในบล็อกลูกเพื่อรวมเนื้อหาของพาเรนต์:

```html
{% block title %}{{ super() }} — Notes{% endblock %}
{# เรนเดอร์: "Default Title — Notes" #}
```

### `{% include %}`

แทรกเทมเพลตอื่นที่จุดนี้ ไฟล์ที่รวมใช้บริบทปัจจุบัน

```html
{% include "partials/pagination.html" %}
{% include "partials/nav.html" %}
```

ใช้ `ignore missing` เพื่อข้ามโดยเงียบหากไฟล์ไม่มี:

```html
{% include "partials/optional.html" ignore missing %}
```

### `{% if %} / {% elif %} / {% else %} / {% endif %}`

เอาต์พุตตามเงื่อนไข

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

วนซ้ำบนอาร์เรย์ `Variant()` บล็อก `{% else %}` เรนเดอร์เมื่อลำดับว่าง

```html
{% for note in notes %}
  <p>{{ note.title }}</p>
{% else %}
  <p>No notes.</p>
{% endfor %}
```

ตัวแปรลูปที่พร้อมใช้งานภายในบล็อก:

| ตัวแปร | ประเภท | คำอธิบาย |
|---|---|---|
| `loop.index` | Integer | จำนวนการวนซ้ำ 1-based |
| `loop.index0` | Integer | จำนวนการวนซ้ำ 0-based |
| `loop.first` | Boolean | True ในการวนซ้ำครั้งแรก |
| `loop.last` | Boolean | True ในการวนซ้ำสุดท้าย |
| `loop.length` | Integer | รายการทั้งหมดในลำดับ |

### `{% set %}`

กำหนดตัวแปรภายในเทมเพลต:

```html
{% set count = notes | length %}
<p>{{ count }} note{{ "s" if count != 1 else "" }}</p>

{% set full_name = user.first_name + " " + user.last_name %}
```

### `{% macro %} / {% endmacro %}`

กำหนดฟังก์ชันเทมเพลตที่นำกลับมาใช้ใหม่:

```html
{% macro render_note(note, show_edit=True) %}
  <div class="note">
    <h3>{{ note.title }}</h3>
    {% if show_edit %}
      <a href="/notes/{{ note.id }}/edit">Edit</a>
    {% endif %}
  </div>
{% endmacro %}

{# เรียกมัน: #}
{{ render_note(note) }}
{{ render_note(note, show_edit=False) }}
```

### `{% with %} / {% endwith %}`

สร้างขอบเขตชั่วคราวด้วยตัวแปรโลคัล:

```html
{% with error = "Title is required" %}
  <p class="error">{{ error }}</p>
{% endwith %}
```

### `{% raw %} / {% endraw %}`

เอาต์พุตไวยากรณ์ Jinja2 ตามตัวอักษร — มีประโยชน์เมื่อรวมสตริงเทมเพลต JavaScript:

```html
{% raw %}
  <script>
    const template = `Hello {{ name }}`; // ไม่ได้ประมวลผลโดย Jinja
  </script>
{% endraw %}
```

### `{% comment %}` / `{# #}`

ความเห็นเทมเพลต — ไม่ส่งไปยังเบราว์เซอร์:

```html
{# นี่คือความเห็น — ลบออกจากเอาต์พุต #}
```

---

## ตัวกรอง

ตัวกรองแปลงค่าโดยใช้ตัวดำเนินการ `|` pipe ตัวกรองหลายตัวสามารถเชื่อมโยงได้

### ตัวกรองสตริง

| ตัวกรอง | ตัวอย่าง | เอาต์พุต |
|---|---|---|
| `upper` | `{{ "hello" \| upper }}` | `HELLO` |
| `lower` | `{{ "HELLO" \| lower }}` | `hello` |
| `title` | `{{ "hello world" \| title }}` | `Hello World` |
| `capitalize` | `{{ "hello world" \| capitalize }}` | `Hello world` |
| `trim` | `{{ "  hi  " \| trim }}` | `hi` |
| `replace(a,b)` | `{{ "foo" \| replace("o","0") }}` | `f00` |
| `truncate(n)` | `{{ "long text" \| truncate(5) }}` | `lo...` |
| `wordcount` | `{{ "hi there" \| wordcount }}` | `2` |

### ตัวกรองลำดับ

| ตัวกรอง | ตัวอย่าง | ผลลัพธ์ |
|---|---|---|
| `length` | `{{ notes \| length }}` | จำนวนรายการ |
| `first` | `{{ notes \| first }}` | รายการแรก |
| `last` | `{{ notes \| last }}` | รายการสุดท้าย |
| `reverse` | `{% for n in notes \| reverse %}` | การวนซ้ำแบบผกผัน |
| `sort` | `{% for n in notes \| sort(attribute="title") %}` | การวนซ้ำแบบเรียง |
| `join(sep)` | `{{ tags \| join(", ") }}` | `"a, b, c"` |

### ตัวกรองประเภท/ความปลอดภัย

| ตัวกรอง | คำอธิบาย |
|---|---|
| `safe` | ทำเครื่องหมาย HTML ว่าเชื่อถือได้ — ข้ามการเข้ารหัสซ้ำ ไม่เคยใช้ในข้อมูลของผู้ใช้ |
| `int` | แปลงเป็นจำนวนเต็ม |
| `float` | แปลงเป็นทศนิยม |
| `string` | แปลงเป็นสตริง |
| `default(val)` | ใช้ `val` ถ้าตัวแปรไม่ได้กำหนดหรือว่าง |

### ตัวกรองแบบกำหนดเอง (โครงการนี้)

ลงทะเบียนตัวกรองแบบกำหนดเองใน `App.Opening()` ด้วย `mJinja.RegisterFilter(name, AddressOf func)`

ลายเซ็นฟังก์ชันตัวกรอง:

```xojo
Function MyFilter(value As Variant) As Variant
  // แปลงค่า คืนค่าผลลัพธ์
End Function
```

---

## ข้อจำกัดเฉพาะ Xojo

นี่คือข้อ จำกัด เมื่อเทียบกับ Jinja2 Python แบบเต็ม — ให้รู้จักพวกเขาเพื่อหลีกเลี่ยงข้อผิดพลาดเงียบ ๆ

**สัญกรณ์จุด Dictionary เท่านั้น** `{{ obj.key }}` ใช้งานได้เฉพาะเมื่อ `obj` เป็น `Dictionary` อ็อบเจ็กต์คลาสแบบกำหนดเอง — คุณสมบัติของพวกมันไม่สามารถเข้าถึงได้ผ่านสัญกรณ์จุดในเทมเพลต

**ไม่มีเรียกเมธอด** `{{ note.title.upper() }}` ไม่ทำงาน ใช้ตัวกรองแทน: `{{ note.title | upper }}`

**ไม่มีตัวสร้าง Python** `range()`, `enumerate()`, `zip()` และ Python built-ins ที่คล้ายกันไม่พร้อมใช้ สร้างข้อมูลที่คุณต้องการใน ViewModel ก่อนส่งไปยังเทมเพลต

**อาร์เรย์ต้องเป็น `Variant()`** ส่งอาร์เรย์เป็น `Variant()` (ไม่ใช่อาร์เรย์ที่พิมพ์เช่น `String()` หรือ `Integer()`) JinjaX ของ `RenderFor` คาดหวัง `Variant()`

**`Nil` เป็นค่าเท็จ** กุญแจ `Dictionary` ที่มีค่า `Nil` จะหาได้ว่าเป็นค่าเท็จในการทดสอบ `{% if %}` กุญแจที่ขาดหายไปยังหาได้ว่าเป็นค่าเท็จ (ไม่ใช่ข้อผิดพลาด)
