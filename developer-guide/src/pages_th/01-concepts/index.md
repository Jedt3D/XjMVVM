---
title: ทำไมต้อง XjMVVM?
description: การตัดสินใจเชิงสถาปัตยกรรมเบื้องหลัง XjMVVM — เหตุใดเราจึงข้าม Xojo WebPage system และเหตุใด MVVM pattern กับ JinjaX
---

# ทำไมต้อง XjMVVM?

หน้านี้อธิบายการตัดสินใจหลักเบื้องหลังการออกแบบเฟรมเวิร์ก การเข้าใจ *เหตุผล* นั้นทำให้คำแนะนำอื่นๆ ทั้งหมดในคู่มือนี้มีความหมายชัดเจน

## ทำไมจึงข้าม Xojo WebPage system?

Xojo Web 2 มี GUI widget system ที่สมบูรณ์: `WebPage`, `WebButton`, `WebTextField`, `WebListBox` และอื่นๆ อีกมากมาย ตัวควบคุมเหล่านี้สื่อสารผ่าน WebSockets และจัดการสถานะโดยอัตโนมัติ สำหรับเครื่องมือภายในแบบง่ายๆ ที่สะท้อนแบบจำลอง widget ของ Xojo อย่างใกล้ชิด พวกมันทำงานได้ดี

โครงการนี้ข้าม system นั้นไปเลยอย่างสิ้นเชิง นี่คือเหตุผล:

**การควบคุม HTML/CSS แบบเต็มรูปแบบ** WebControls เรนเดอร์ HTML ของตัวเองด้วยชื่อคลาสและโครงสร้างของตัวเอง คุณไม่สามารถใช้ระบบการออกแบบที่กำหนดเองหรือรวมเฟรมเวิร์ก CSS เช่น Tailwind ได้อย่างง่ายดาย ด้วยเทมเพลต JinjaX คุณเขียน HTML เอง — ทุกแท็ก ทุกคลาส ทุกแอตทริบิวต์ข้อมูลเป็นของคุณ

**HTTP semantics มาตรฐาน** หน้า WebControl เป็นเซสชัน WebSocket ที่มีสถานะ พวกมันไม่ทำงานเหมือนแอปพลิเคชัน HTTP มาตรฐาน: บุ๊กมาร์กไม่น่าเชื่อถือ ประวัติเบราว์เซอร์อึดอัด REST APIs ยากขึ้น วิธี SSR หมายความว่า URL ทุกตัวคือ HTTP endpoint ที่เหมาะสม — คาดเดาได้ แคชได้ และเชื่อมโยงได้

**เทมเพลตที่เป็นมิตรกับนักออกแบบ** เทมเพลต HTML อยู่ในโฟลเดอร์ `templates/` นักออกแบบหรือนักพัฒนาส่วนหน้าสามารถแก้ไขโดยใช้ตัวแก้ไขข้อความใด ๆ ที่มีการสนับสนุน IDE แบบเต็มรูปแบบ (ไฮไลต์ไวยากรณ์ Emmet Prettier) พวกเขาไม่ต้องสัมผัสโค้ด Xojo เลย

**ไม่มีสถานะเซสชันในชั้น UI** Xojo WebControls มีสถานะเซสชันโดยปริยาย ViewModels ของเราไม่มีสถานะต่อการร้องขอ — พวกมันรับการร้องขอ ทำงาน และเขียนการตอบสนอง สถานะที่ยั่งยืนเพียงอย่างเดียวอยู่ใน `Session` (คลาส `WebSession`) และฐานข้อมูล

## ทำไม MVVM มากกว่า MVC?

MVC แบบคลาสสิก (Model-View-Controller) มีส่วน Controller ที่รับผิดชอบทั้งตรรกะการกำหนดเส้นทางและการจัดการ Models ใน Xojo นี่จะหมายถึงคลาส controller ขนาดใหญ่เดียวที่จัดการทุกเส้นทาง

XjMVVM ใช้ MVVM เพื่อแยกความกังวลให้สะอาดขึ้นสำหรับสถาปัตยกรรมต่อเส้นทาง:

| ชั้น | คลาส | ความรับผิดชอบ |
|---|---|---|
| **View** | ไฟล์ Jinja2 `.html` | การนำเสนอเท่านั้น — ไม่มีตรรกะทางธุรกิจ |
| **ViewModel** | หนึ่งคลาสต่อเส้นทาง | จัดการ Models สร้างบริบทเทมเพลต |
| **Model** | คลาสการเข้าถึงข้อมูล | แบบสอบถามฐานข้อมูล ส่งคืน `Dictionary` objects |

ViewModel หนึ่งตัวต่อเส้นทาง (เช่น `NotesListVM`, `NotesCreateVM`) ทำให้คลาสแต่ละคลาสมีขนาดเล็กและมีโฟกัส การเพิ่มฟีเจอร์ใหม่หมายถึงการเพิ่มไฟล์ใหม่ ไม่ใช่การปรับเปลี่ยนไฟล์ที่มีอยู่

ทิศทางการพึ่งพาเป็นทางเดียวเท่านั้น:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 40
#padding: 8
#lineWidth: 1.5
[View] -> [ViewModel]
[ViewModel] -> [Model]
[Model] SQL -> [<database> Database]
[<database> Database] rows -> [Model]
[Model] Dictionary -> [ViewModel]
[ViewModel] context -> [View]
-->
<!-- ascii
View  →  ViewModel  →  Model  →  Database
-->
<!-- /diagram -->

ViewModels ไม่เคยอ้างอิงชื่อเทมเพลตในตรรกะทางธุรกิจ Models ไม่เคยอ้างอิง ViewModels สิ่งนี้ทำให้ชั้นแต่ละชั้นสามารถทดสอบและแทนที่ได้อย่างอิสระ

## ทำไม JinjaX?

JinjaX คือพอร์ตของ Jinja2 template engine ของ Python ที่เขียนด้วย Xojo บริสุทธิ์ มันถูกเลือกเพราะ:

**Jinja2 เป็นมาตรฐาน de-facto** นักพัฒนาที่คุ้นเคยกับ Flask Django Ansible หรือ Saltstack รู้ไวยากรณ์แล้ว เส้นโค้งการเรียนรู้น้อยที่สุด

**เป็นซอร์ส Xojo บริสุทธิ์** ต้นไม้ต้นฉบับของ JinjaX ทั้งหมดอยู่ภายใต้ `JinjaXLib/` ไม่มีการพึ่งพาไบนารี `.xojo_library` ซึ่งหมายความว่ามันใช้งานได้กับรูปแบบโครงการข้อความของ Xojo (ไฟล์ `.xojo_code`) และสามารถตรวจสอบและแก้จุดบกพร่องได้อย่างสมบูรณ์

**ปลอดภัยสำหรับเธรดหลังจากการตั้งค่า** `JinjaEnvironment` ถูกเริ่มต้นครั้งเดียวใน `App.Opening()` จากนั้นจะเป็นแบบอ่านอย่างเดียว ทุกการร้องขอสร้าง `CompiledTemplate` และ `JinjaContext` ใหม่ — สิ่งเหล่านี้เป็นออบเจกต์ต่อการร้องขอ ไม่เคยแชร์

**การสืบทอดเทมเพลตทำงาน** `{% extends %}`, `{% block %}`, และ `{% include %}` ให้คุณสร้างเค้าโครงฐานครั้งเดียวและเรียบเรียงหน้าทั้งหมดจากนั้น

## Dictionary data contract

นี่คือกฎที่สำคัญที่สุดในระบบทั้งหมด

JinjaX แก้ไข dot-notation (`{{ note.title }}`) โดยการเรียก `EvaluateGetAttr` บนออบเจกต์ ใน Xojo `EvaluateGetAttr` ถูกนำไปใช้เฉพาะสำหรับ `Dictionary` — มันค้นหาคีย์ตามชื่อ instance คลาส Xojo ที่กำหนดเองไม่รองรับ `EvaluateGetAttr` ดังนั้นการเข้าถึง dot จึงแสดงผลเป็นค่าว่างโดยเงียบ

**กฎ:** ข้อมูลทุกชิ้นที่ผ่านไปยังเทมเพลตต้องเป็น `Dictionary` หรือ `Variant()` array ของ `Dictionary` objects Models จะส่งคืนหนึ่งในสองประเภทนี้เท่านั้น — ไม่เคยเป็น custom class instance

```xojo
// ✅ ถูกต้อง — คีย์ Dictionary ทำงานกับ dot-notation ในเทมเพลต
Var row As New Dictionary()
row.Value("title") = rs.Column("title").StringValue
row.Value("body")  = rs.Column("body").StringValue
results.Add(row)   // Variant() array ของ Dictionary

// ❌ ไม่ถูกต้อง — custom class instance การเข้าถึง dot ทำงานไม่ได้โดยเงียบในเทมเพลต
Var note As New NoteClass()
note.Title = rs.Column("title").StringValue
results.Add(note)  // {{ note.title }} แสดงผลเป็นสตริงว่าง
```

ในเทมเพลต arrays ต้องเป็น `Variant()` ที่ประกอบด้วย `Dictionary` objects:

```html
{% for note in notes %}
  <h2>{{ note.title }}</h2>   {# ทำงาน — Dictionary key lookup #}
  <p>{{ note.body }}</p>
{% endfor %}
```

## Post/Redirect/Get

การส่งแบบฟอร์มทั้งหมดทำตามแบบ **Post/Redirect/Get (PRG)**:

1. เบราว์เซอร์ส่งแบบฟอร์ม → `POST /notes` (จัดการโดย `NotesCreateVM`)
2. ViewModel ตรวจสอบและสร้างบันทึก
3. ViewModel เรียก `Redirect("/notes")` — HTTP 302
4. เบราว์เซอร์ตามเส้นทางการเปลี่ยนเส้นทาง → `GET /notes` (จัดการโดย `NotesListVM`)
5. เบราว์เซอร์เรนเดอร์หน้าลิสต์

สิ่งนี้ป้องกันเบราว์เซอร์จากการส่งแบบฟอร์มซ้ำเมื่อรีเฟรช (กล่องโต้ตอบ "Reload this page?") นอกจากนี้ยังหมายความว่าทุกหน้าที่ผู้ใช้มองเห็นผลิตจากการร้องขอ GET — ประวัติเบราว์เซอร์ บุ๊กมาร์ก และปุ่มย้อนกลับทั้งหมดทำงานอย่างถูกต้อง

หากการตรวจสอบล้มเหลว ViewModel จะ **ไม่** เปลี่ยนเส้นทาง — มันเรนเดอร์แบบฟอร์มอีกครั้งด้วยข้อความแฟลชข้อผิดพลาดโดยใช้เทมเพลต GET เดียวกัน:

```xojo
// ความล้มเหลวของการตรวจสอบ — เรนเดอร์อีกครั้ง ไม่เปลี่ยนเส้นทาง
If title.Trim = "" Then
  SetFlash("Title is required", "error")
  Redirect("/notes/new")
  Return
End If
```

## การแยกข้อมูลระหว่าง Session

`App` เป็น shared singleton — ร้องขอของผู้ใช้ทั้งหมดทำงานในอินสแตนซ์ `App` เดียวกัน ไม่เคยเก็บข้อมูลเฉพาะผู้ใช้ในคุณสมบัติ `App`

สถานะต่อผู้ใช้ไปในคลาส `Session` (ซึ่งสืบทอดจาก `WebSession`) เบราว์เซอร์แต่ละเซสชันจะได้รับอินสแตนซ์ `Session` ของตัวเองโดยอัตโนมัติโดยรันไทม์ของ Xojo:

```
App.mRouter      → shared แบบอ่านอย่างเดียวหลังจาก Opening()  ✅ ปลอดภัย
App.mJinja       → shared แบบอ่านอย่างเดียวหลังจาก Opening()  ✅ ปลอดภัย
Session.userID   → per-user อินสแตนซ์หนึ่งต่อเบราว์เซอร์  ✅ ปลอดภัย
App.currentUser  → shared ในผู้ใช้ทั้งหมด             ❌ ไม่เคยทำเช่นนี้
```