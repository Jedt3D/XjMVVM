---
title: JinjaX Overview
description: JinjaX คืออะไร วิธีที่มันทำงานกับเฟรมเวิร์ก และวิธีการตั้งค่าใน App.Opening()
---

# JinjaX & Templates

JinjaX เป็นการนำเสนอ Jinja2 template engine ที่เขียนด้วย Xojo แบบบริสุทธิ์ มันให้คุณเขียน HTML templates ด้วยไวยากรณ์ที่เข้ากันได้กับ Jinja2 ของ Python — เอนจิ้นเดียวกับที่ใช้โดย Flask และ Django

## JinjaX มอบอะไรให้

- **Template inheritance** — `{% extends "layouts/base.html" %}` พร้อม `{% block %}` overrides
- **Template includes** — `{% include "partials/nav.html" %}`
- **Variable output** — `{{ variable }}` พร้อม HTML escaping อัตโนมัติ
- **Control flow** — `{% if %}`, `{% for %}`, `{% else %}`, `{% elif %}`
- **Filters** — `{{ value | upper }}`, `{{ value | length }}`, custom filters
- **Autoescape** — ป้องกัน XSS โดยเปิดใช้งานตามค่าเริ่มต้น

## ที่มาของโปรเจกต์

JinjaX อยู่ใต้ `JinjaXLib/` ในรากโปรเจกต์ มันรวมอยู่เป็นซอร์สโค้ด Xojo เต็มรูปแบบแทนที่จะเป็นไลบรารีที่คอมไพล์แล้ว ดังนั้นจึงทำงานได้กับไฟล์โปรเจกต์ `.xojo_code` รูปแบบข้อความและสามารถตรวจสอบหรือดีบักได้หากจำเป็น

อย่าแก้ไข `JinjaXLib/` เว้นแต่ว่าคุณต้องการปรับปรุงหรือแพตช์ JinjaX

## การตั้งค่าใน App.Opening()

`JinjaEnvironment` ถูกเตรียมใช้งานเพียงครั้งเดียวเมื่อแอปพลิเคชันเริ่มต้นและเก็บไว้บน `App` เป็น singleton ที่แชร์กันได้ มันเป็นแบบอ่านเท่านั้นหลังจาก `Opening()` เสร็จสิ้น ซึ่งทำให้มันปลอดภัยสำหรับการใช้งานหลายเธรด:

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

## การลงทะเบียน custom filter

filter คือเมธอด Xojo ที่รับ `Variant` และคืนค่า `Variant` ลงทะเบียนด้วยชื่อสตริงที่ templates ใช้กับตัวดำเนิน pipe `|`:

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

ในเทมเพลต:

```html
{{ note.body | truncate80 }}
```

## การเข้าถึง environment จาก ViewModel

`JinjaEnvironment` ถูกส่งผ่านจาก Router ไปยัง ViewModel แต่ละตัวก่อนที่จะเรียก `Handle()` `BaseViewModel` เก็บมันเป็นพร็อพเพอร์ตี `Jinja` คุณไม่เคยเข้าถึงมันโดยตรง — เพียงแค่เรียก `Render()`:

```xojo
// In any ViewModel — Render() uses Self.Jinja internally
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

## ความปลอดภัยของการใช้งานหลายเธรด

`JinjaEnvironment` ปลอดภัยที่จะแชร์ข้ามเธรด **หลังจาก** `Opening()` เสร็จสิ้น เพราะว่า:

- `RegisterFilter` ถูกเรียกใช้เพียงระหว่าง `Opening()` — ไม่เคยระหว่างคำขอ
- `GetTemplate()` และ `Render()` อ่านเพียงจาก environment เท่านั้น
- `CompiledTemplate` และ `JinjaContext` ถูกสร้างใหม่ต่อคำขอ (stack-allocated ไม่ใช่ shared)

แต่ละคำขอได้รับ `CompiledTemplate` และ `JinjaContext` ของตัวเอง — สิ่งเหล่านี้ไม่ได้แชร์กันใช้