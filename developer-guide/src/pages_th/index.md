---
title: บทนำ
description: เฟรมเวิร์ก Xojo MVVM Web ที่เรนเดอร์ฝั่งเซิร์ฟเวอร์ (XjMVVM) สร้างบน Xojo Web 2 ขับเคลื่อนโดยเทมเพลต JinjaX
---

# บทนำ

นี่คือ **XjMVVM** (Xojo MVVM Web Framework) — เฟรมเวิร์กเว็บแอปพลิเคชันที่เรนเดอร์ฝั่งเซิร์ฟเวอร์ (SSR) สร้างบน Xojo Web 2 แทนที่จะใช้ระบบ GUI WebPage และ WebControl ในตัวของ Xojo ทุก HTTP request จะถูกสกัดกั้นใน `HandleURL` และจัดเส้นทางไปยัง ViewModel ซึ่งเรนเดอร์การตอบสนอง HTML โดยใช้เอนจิน **JinjaX template**

สถาปัตยกรรมนี้ออกแบบให้คล้ายกับ **Flask** หรือ **Django** — คุ้นเคยกับใครก็ตามที่สร้างเว็บแอป SSR ใน Python มาก่อน ถ้าคุณไม่เคยใช้ Flask ลองคิดแบบนี้: เบราว์เซอร์ขออพเพจ เซิร์ฟเวอร์รันโค้ด สร้างสตริง HTML และส่งกลับ ไม่มี JavaScript framework ไม่มี WebSocket สำหรับเรนเดอร์ แค่ request/response ที่ชัดเจน

## วงจรชีวิตของ request

ทุก request — โดยไม่คำนึงถึง URL — ไหลผ่านไปป์ไลน์เดียวกัน:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 8
#lineWidth: 1.5
[Browser] HTTP Request -> [HandleURL: WebApplication.HandleURL]
[HandleURL: WebApplication.HandleURL] -> [Router]
[Router] -> [ViewModel: ViewModel.Handle]
[ViewModel: ViewModel.Handle] queries -> [<database> Model]
[<database> Model] Dictionary -> [ViewModel: ViewModel.Handle]
[ViewModel: ViewModel.Handle] -> [Render: JinjaX.CompiledTemplate.Render]
[Render: JinjaX.CompiledTemplate.Render] HTML -> [Browser]
-->
<!-- ascii
Browser
  │  HTTP Request  (GET /notes  or  POST /notes/42)
  ▼
WebApplication.HandleURL
  │  Returns True (takes ownership of all requests)
  ▼
Router
  │  Matches path pattern → selects ViewModel
  │  Extracts URL params  (e.g. /notes/:id → id = "42")
  ▼
ViewModel.Handle()
  │  Dispatches to OnGet() or OnPost()
  ▼
Model  (database queries)
  │  Returns Dictionary / Variant() of Dictionary
  ▼
ViewModel builds context Dictionary
  │  { "notes": [...], "flash": {...}, "page_title": "Notes" }
  ▼
JinjaX.CompiledTemplate.Render(context) → HTML string
  │  Template: templates/notes/list.html
  ▼
WebResponse.Write(html)
  ▼
Browser renders the page
-->
<!-- /diagram -->

ไม่มีสิ่งใดในไปป์ไลน์นี้ใช้ `WebPage`, `WebButton`, `WebTextField` หรือ Xojo web control อื่นๆ WebPage `Default` ในไฟล์โปรเจกต์เป็นตัวยึดโครงสร้างที่จำเป็นสำหรับโครงสร้างโปรเจกต์ของ Xojo — ไม่เคยถูกให้บริการจริง

## การรันแอป

1. เปิด `mvvm.xojo_project` ใน **Xojo 2025r3.1**
2. คลิก **Run** (⌘R) แอปเริ่มเรียกใช้บน `http://localhost:8080`
3. ฐานข้อมูล SQLite `data/notes.sqlite` จะถูกสร้างโดยอัตโนมัติเมื่อเปิดครั้งแรก

ไม่มีระบบการสร้าง CLI การทดสอบและการสร้างทั้งหมดเกิดขึ้นภายใน Xojo IDE

## สิ่งที่มีในคู่มือนี้

| ส่วน | สิ่งที่คุณจะได้เรียน |
|---|---|
| [ทำไม MVVM?](concepts/index.html) | การตัดสินใจด้านสถาปัตยกรรมและการแลกเปลี่ยนเสียสละเบื้องหลังการออกแบบนี้ |
| [Routing](routing/index.html) | ต้นไม้การตัดสินใจ HandleURL การเปลี่ยนเส้นทาง `/tests` ข้ามระหว่าง SSR และ Xojo WebPage |
| [Conventions](conventions/index.html) | โครงสร้างไดเรกทอรี การตั้งชื่อไฟล์ การตั้งชื่อเมธอดและพรอพเพอร์ตี้ |
| [Static Files](static-files/index.html) | วิธีให้บริการ CSS, JS และภาพ |
| [Templates](templates/index.html) | การตั้งค่า JinjaX ไวยากรณ์ Jinja2 ตัวอย่างจริง ข้อมูลอ้างอิงแท็กเต็ม |
| [Database](database/index.html) | รูปแบบ SQLite สัญญา Dictionary ความปลอดภัยของเธรด |
| [DB Layer Reference](database/model-reference.html) | สถาปัตยกรรมสามชั้น (DBAdapter / BaseModel / NoteModel) CRUD API เต็ม การแลกเปลี่ยนเสียสละ |
| [Tags & Many-to-Many](tags/index.html) | ทรัพยากรที่สอง ตารางสามารถหลาย ๆ ตัวต่อตัว GetTagsForNote, SetTagsForNote |
| [Auth System](auth/index.html) | การรับรองความถูกต้องบน Cookie, Cookie ที่ลงนาม HMAC, SHA-256 + salt password hashing ปัญหา SSR session |
| [JSON API & Static Serving](api/index.html) | JSONSerializer ViewModel API ที่รับรองความถูกต้อง สถานะ 201/401/422 ServeStatic path-traversal guard |
| [Alpine.js](alpine/index.html) | การโต้ตอบฝั่งไคลเอนต์ขั้นต่ำ — สถานะการรับรองความถูกต้อง nav ข้อความแฟลช การตรวจสอบแบบฟอร์ม |
| [Protected Routes & User Scoping](protected-routes/index.html) | ตัวป้องกันเส้นทาง (RequireLogin / RequireLoginJSON) บันทึกที่จำกัดผู้ใช้ การบังคับใช้ความเป็นเจ้าของ |
| [Encoding](encoding/index.html) | การแยกวิเคราะห์แบบฟอร์ม ประเภท MIME UTF-8 และ percent-encoding |

## เวอร์ชันปัจจุบัน

**v0.9.3** — บันทึกที่ใช้ผู้ใช้ (ผู้ใช้แต่ละคนเห็นเฉพาะของตัวเอง) การรับรองความถูกต้องบน Cookie (Cookie `mvvm_auth` ที่ลงนาม HMAC แทนการรับรองความถูกต้อง WebSession ที่ขาด) เส้นทางที่ป้องกัน (เส้นทางทั้ง 19 เส้นต้องการการเข้าสู่ระบบ) Alpine.js สำหรับการโต้ตอบฝั่งไคลเอนต์ JSON API ที่มีการรับรองความถูกต้อง และเซิร์ฟเวอร์ไฟล์คงที่ในตัวสำหรับเอกสาร dev ที่ `/dist/*`