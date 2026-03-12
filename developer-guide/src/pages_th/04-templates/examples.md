---
title: ตัวอย่าง
description: ตัวอย่างเทมเพลตจริงที่นำมาจากฟีเจอร์บันทึกย่อ — เลย์เอาต์พื้นฐาน, รายการ, รายละเอียด, และแบบฟอร์มที่ใช้ร่วมกัน
---

# ตัวอย่าง

นี่คือเทมเพลตที่ใช้จริงโดยฟีเจอร์บันทึกย่อ พร้อมกับคำอธิบายประกอบ

## เลย์เอาต์พื้นฐาน

เลย์เอาต์พื้นฐานกำหนดโครงสร้างของเว็บไซต์ เทมเพลตหน้าทุกหน้าสืบทอดจากเลย์เอาต์นี้:

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

ตัวแปร `flash` เป็น `Dictionary` ที่มี key สองตัว: `type` (`"success"`, `"error"`, `"info"`) และ `message` (สตริงข้อความ) ตัวแปรนี้ถูกฉีดเข้าโดยอัตโนมัติ — ViewModel ใดๆ สามารถเรียก `SetFlash()` และข้อความจะปรากฏบนหน้าที่แสดงผลครั้งต่อไป

## รายการบันทึกย่อ

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

จุดสำคัญคือ `note.id`, `note.title`, `note.body`, `note.updated_at` เป็น key ของ Dictionary การลบทำผ่าน `POST` form เพราะแบบฟอร์ม HTML รองรับเพียง GET และ POST เท่านั้น — ไม่มี HTTP DELETE ในแบบฟอร์มบราวเซอร์

## แบบฟอร์มที่ใช้ร่วมกันสำหรับการสร้างและแก้ไข

เทมเพลตเดียวสามารถใช้สำหรับทั้งแบบฟอร์มสร้างบันทึกใหม่และแบบฟอร์มแก้ไข การมีอยู่ของตัวแปร `note` จะกำหนดว่าโหมดใดเป็นโหมดที่ใช้งาน:

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

`NotesNewVM` ไม่ส่ง key `note` (หรือส่ง `Nil`) — เทมเพลตแสดงผลในโหมดสร้าง `NotesEditVM` ส่ง Dictionary `note` ที่โหลดแล้ว — เทมเพลตจะเติมค่าที่มีอยู่แล้วล่วงหน้า

## รายละเอียดบันทึกย่อ

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

`white-space:pre-wrap` จะรักษาการขึ้นบรรทัดในข้อความเนื้อหาโดยไม่จำเป็นต้องแปลง `\n` เป็น `<br>` — มีประโยชน์สำหรับเนื้อหาที่เป็นข้อความธรรมชาติ

## หน้าข้อผิดพลาด

เทมเพลตข้อผิดพลาดจะได้รับ `status_code` และ `message` จากเมธอด `Serve404()` และ `Serve500()` ของ Router:

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

เทมเพลตข้อผิดพลาดไม่จำเป็นต้องกังวลเกี่ยวกับข้อความ flash — เทมเพลตนี้แสดงผลโดย Router โดยตรง ก่อนที่ ViewModel ใดๆ จะมีโอกาสทำงาน