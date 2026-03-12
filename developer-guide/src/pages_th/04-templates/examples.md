---
title: ตัวอย่าง
description: ตัวอย่างเทมเพลตจริงที่นำมาจากฟีเจอร์บันทึก — เลเยต์ฐาน รายการ รายละเอียด แบบฟอร์มใช้ร่วมกัน
---

# ตัวอย่าง

นี่คือเทมเพลตจริงที่ใช้โดยฟีเจอร์บันทึก พร้อมคำอธิบายประกอบ

## เลเยต์ฐาน

เลเยต์ฐานกำหนดโครงสร้างไซต์ เทมเพลตหน้าทุกเทมเพลตขยายสิ่งนี้:

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

  {# ข้อความแฟลชถูกฉีดโดย BaseViewModel.Render() โดยอัตโนมัติ #}
  {% if flash %}
  <div class="flash flash-{{ flash.type }}">{{ flash.message }}</div>
  {% endif %}

  <main>
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

ตัวแปร `flash` คือ `Dictionary` ที่มีสองกุญแจ: `type` (`"success"`, `"error"`, `"info"`) และ `message` (สตริง) ฉีดโดยอัตโนมัติ — ViewModel ใด ๆ สามารถเรียก `SetFlash()` และข้อความจะปรากฏบนหน้าที่เรนเดอร์ถัดไป

## รายการบันทึก

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
      {# ลบผ่านแบบฟอร์ม POST — ไม่มีวิธี DELETE ใน HTML #}
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

ประเด็นสำคัญ: `note.id`, `note.title`, `note.body`, `note.updated_at` คือกุญแจ Dictionary การลบเป็นแบบฟอร์ม `POST` เพราะแบบฟอร์ม HTML รองรับเฉพาะ GET และ POST — ไม่มี HTTP DELETE ในแบบฟอร์มเบราว์เซอร์

## แบบฟอร์มสร้าง/แก้ไขใช้ร่วมกัน

หนึ่งเทมเพลตให้ทั้งแบบฟอร์มบันทึกใหม่และแบบฟอร์มแก้ไข การมีอยู่ของตัวแปร `note` จะกำหนดโหมดใดที่ใช้งาน:

```html
{# templates/notes/form.html #}
{% extends "layouts/base.html" %}

{% block title %}{% if note %}Edit Note{% else %}New Note{% endif %}{% endblock %}

{% block content %}
<h1>{% if note %}Edit Note{% else %}New Note{% endif %}</h1>

{# สลับการดำเนินการแบบฟอร์มและเติมค่าตามโหมด #}
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

`NotesNewVM` ไม่ส่งกุญแจ `note` (หรือส่ง `Nil`) — แบบฟอร์มเรนเดอร์ในโหมดสร้าง `NotesEditVM` ส่งพจนานุกรม `note` ที่โหลด — แบบฟอร์มเติมล่วงหน้าด้วยค่าที่มีอยู่

## รายละเอียดบันทึก

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

`white-space:pre-wrap` รักษาตัวหยุดบรรทัดในข้อความเนื้อหาโดยไม่จำเป็นต้องแปลง `\n` เป็น `<br>` — มีประโยชน์สำหรับเนื้อหาเนื้อหาข้อความธรรมชาติ

## หน้าข้อผิดพลาด

เทมเพลตข้อผิดพลาดถูกส่ง `status_code` และ `message` โดยวิธี `Serve404()` และ `Serve500()` ของ Router:

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

เทมเพลตข้อผิดพลาดไม่ต้องกังวลเกี่ยวกับข้อความแฟลช — พวกเขาเรนเดอร์โดย Router โดยตรง ก่อนที่ ViewModel ใด ๆ จะมีโอกาสเรียก
