---
title: ภาพรวม JinjaX
description: JinjaX คืออะไร วิธีการที่มันพอดีกับเฟรมเวิร์ก และวิธีการตั้งค่าใน App.Opening()
---

# JinjaX และเทมเพลต

JinjaX เป็นการใช้งานเอนจิน Jinja2 ของ Python ที่เขียนด้วย Xojo แบบบริสุทธิ์ ทำให้คุณสามารถเขียนเทมเพลต HTML ด้วยไวยากรณ์ที่เข้ากันได้กับ Jinja2 ของ Python — เอนจินเดียวกันที่ใช้โดย Flask และ Django

## JinjaX มอบให้สิ่งใด

- **การสืบทอดเทมเพลต** — `{% extends "layouts/base.html" %}` ด้วย `{% block %}` overrides
- **รวมเทมเพลต** — `{% include "partials/nav.html" %}`
- **เอาต์พุตตัวแปร** — `{{ variable }}` ด้วยการหลีกเลี่ยง HTML อัตโนมัติ
- **โฟลว์ควบคุม** — `{% if %}`, `{% for %}`, `{% else %}`, `{% elif %}`
- **ตัวกรอง** — `{{ value | upper }}`, `{{ value | length }}`, ตัวกรองแบบกำหนดเอง
- **Autoescape** — การป้องกัน XSS เปิดใช้งานโดยค่าเริ่มต้น

## ต้นไม้ต้นฉบับโครงการ

JinjaX อาศัยอยู่ใต้ `JinjaXLib/` ในรูตของโครงการ มีรวมอยู่เป็นต้นฉบับ Xojo เต็มรูปแบบแทนไลบรารีที่รวบรวม ดังนั้นจึงใช้งานได้กับไฟล์โครงการรูปแบบข้อความ `.xojo_code` และสามารถตรวจสอบหรือดีบัตได้หากจำเป็น

อย่าแก้ไข `JinjaXLib/` เว้นแต่จะตั้งใจอัปเกรดหรือแพทช์ JinjaX

## การตั้งค่าใน App.Opening()

`JinjaEnvironment` ถูกเริ่มต้นเพียงครั้งเดียวเมื่อแอปพลิเคชันเริ่มต้นและเก็บไว้บน `App` เป็นซิงเกิลตันที่ใช้ร่วมกัน มันเป็นแบบอ่านเท่านั้นหลังจาก `Opening()` เสร็จสิ้น ซึ่งทำให้มันปลอดภัยเธรด:

```xojo
// ใน App.Opening()

// 1. สร้างสภาพแวดล้อม
mJinja = New JinjaX.JinjaEnvironment()

// 2. ชี้ไปที่โฟลเดอร์เทมเพลตของคุณ
//    ใช้เส้นทางสัมบูรณ์เพื่อให้มันใช้งานได้จากตำแหน่งเอาต์พุตดีบัต IDE
Var projectDir As New FolderItem("/path/to/mvvm", FolderItem.PathModes.Native)
Var templatesDir As FolderItem = projectDir.Child("templates")
mJinja.Loader = New JinjaX.FileSystemLoader(templatesDir)

// 3. เปิด autoescape (ป้องกัน XSS — เสมออยู่)
mJinja.Autoescape = True

// 4. ลงทะเบียนตัวกรองแบบกำหนดเอง
mJinja.RegisterFilter("truncate80", AddressOf TruncateFilter)
```

## การลงทะเบียนตัวกรองแบบกำหนดเอง

ตัวกรองคือเมธอด Xojo ที่ใช้ `Variant` และส่งคืน `Variant` ลงทะเบียนด้วยชื่อสตริงที่เทมเพลตใช้กับตัวดำเนินการ pipe `|`:

```xojo
// ใน App.xojo_code (หรือโมดูล Filters)
Function TruncateFilter(value As Variant) As Variant
  Var s As String = value.StringValue
  If s.Length > 80 Then
    Return s.Left(77) + "..."
  End If
  Return s
End Function

// ลงทะเบียนใน Opening():
mJinja.RegisterFilter("truncate80", AddressOf TruncateFilter)
```

ในเทมเพลต:

```html
{{ note.body | truncate80 }}
```

## การเข้าถึงสภาพแวดล้อมจาก ViewModel

`JinjaEnvironment` ถูกส่งผ่านจาก Router ไปยัง ViewModel แต่ละอันก่อนที่ `Handle()` จะถูกเรียก `BaseViewModel` เก็บไว้เป็นคุณสมบัติ `Jinja` คุณไม่เคยเข้าถึงมันโดยตรง — เพียงเรียก `Render()`:

```xojo
// ใน ViewModel ใด ๆ — Render() ใช้ Self.Jinja ภายใน
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

## ความปลอดภัยเธรด

`JinjaEnvironment` ปลอดภัยในการใช้ร่วมกันในเธรด **หลังจาก** `Opening()` เสร็จสิ้น เพราะ:

- `RegisterFilter` ถูกเรียกเฉพาะในช่วง `Opening()` — ไม่มีช่วงคำขอ
- `GetTemplate()` และ `Render()` เฉพาะการอ่านจากสภาพแวดล้อม
- `CompiledTemplate` และ `JinjaContext` ถูกสร้างใหม่ต่อคำขอ (stackalloc ไม่ใช่ร่วมกัน)

แต่ละคำขอได้รับ `CompiledTemplate` และ `JinjaContext` ของตัวเอง — สิ่งเหล่านี้ไม่ใช่ร่วมกัน
