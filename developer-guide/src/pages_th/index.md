---
title: บทนำ
description: เฟรมเวิร์ก Xojo MVVM Web ที่เรนเดอร์ฝั่งเซิร์ฟเวอร์ (XjMVVM) สร้างบน Xojo Web 2 ขับเคลื่อนด้วยเทมเพลต JinjaX
---

# บทนำ

นี่คือ **XjMVVM** (Xojo MVVM Web Framework) — เฟรมเวิร์กเว็บแอปพลิเคชันที่เรนเดอร์ฝั่งเซิร์ฟเวอร์ (SSR) สร้างบน Xojo Web 2 แทนที่จะใช้ระบบ GUI WebPage และ WebControl ของ Xojo ทุก HTTP request จะถูกดักจับใน `HandleURL` และส่งไปยัง ViewModel ซึ่งจะเรนเดอร์ HTML response โดยใช้เอนจิน **JinjaX template**

สถาปัตยกรรมนี้ออกแบบให้คล้ายกับ **Flask** หรือ **Django** — คุ้นเคยกับใครก็ตามที่เคยสร้างแอปเว็บ SSR ด้วย Python หากคุณไม่เคยใช้ Flask ลองคิดแบบนี้: เบราว์เซอร์ขอหน้าเว็บ เซิร์ฟเวอร์รันโค้ดบางส่วน สร้างสตริง HTML และส่งกลับ ไม่มี JavaScript framework ไม่มี WebSocket สำหรับเรนเดอร์ แค่คำขอและการตอบสนองที่สะอาด

## วงจรชีวิตของการร้องขอ

ทุก request — ไม่ว่า URL จะเป็นอะไร — จะไหลผ่านไปป์ไลน์เดียวกัน:

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

ไม่มีอะไรในไปป์ไลน์นี้ที่ใช้ `WebPage`, `WebButton`, `WebTextField` หรือ Xojo web control อื่นๆ WebPage `Default` ในไฟล์โปรเจกต์เป็นตัวยึดตำแหน่งที่จำเป็นสำหรับโครงสร้างโปรเจกต์ของ Xojo — ไม่มีการให้บริการจริง

## เรียกใช้แอป

1. เปิด `mvvm.xojo_project` ใน **Xojo 2025r3.1**
2. คลิก **Run** (⌘R) แอปเริ่มต้นใน `http://localhost:8080`
3. ฐานข้อมูล SQLite `data/notes.sqlite` จะถูกสร้างโดยอัตโนมัติเมื่อเปิดครั้งแรก

ไม่มีระบบการสร้าง CLI การทดสอบและการสร้างทั้งหมดเกิดขึ้นภายใน Xojo IDE

## เนื้อหาในคู่มือนี้

| ส่วน | สิ่งที่คุณจะเรียนรู้ |
|---|---|
| [ทำไม MVVM?](concepts/index.html) | การตัดสินใจทางสถาปัตยกรรมและการประนีประนอมเบื้องหลังการออกแบบนี้ |
| [การกำหนดเส้นทาง](routing/index.html) | HandleURL decision tree การเปลี่ยนเส้นทาง `/tests` การข้ามระหว่าง SSR และ Xojo WebPage |
| [ข้อตกลง](conventions/index.html) | โครงสร้างไดเรกทอรี่ การตั้งชื่อไฟล์ การตั้งชื่อเมธอดและพร็อพเพอร์ตี้ |
| [ไฟล์สแตติก](static-files/index.html) | วิธีให้บริการ CSS JS และรูปภาพ |
| [เทมเพลต](templates/index.html) | การตั้งค่า JinjaX ไวยากรณ์ Jinja2 ตัวอย่างจริง อ้างอิงแท็กเต็ม |
| [ฐานข้อมูล](database/index.html) | รูปแบบ SQLite สัญญา Dictionary ความปลอดภัยของเธรด |
| [อ้างอิง DB Layer](database/model-reference.html) | สถาปัตยกรรมสามชั้น (DBAdapter / BaseModel / NoteModel) API CRUD เต็ม การประนีประนอม |
| [แท็กและความสัมพันธ์แบบ Many-to-Many](tags/index.html) | ทรัพยากรที่สอง ตารางแยก GetTagsForNote SetTagsForNote |
| [ระบบตรวจสอบสิทธิ์](auth/index.html) | ตรวจสอบสิทธิ์แบบคุกกี้ คุกกี้ที่ลงนาม HMAC SHA-256 + salt password hashing วิธีแก้ปัญหา WebSession SSR |
| [JSON API และการให้บริการไฟล์สแตติก](api/index.html) | JSONSerializer ViewModel API ที่ตรวจสอบสิทธิ์ สถานะ 201/401/422 ServeStatic path-traversal guard |
| [Alpine.js](alpine/index.html) | ความโต้ตอบฝั่งไคลเอนต์ขั้นต่ำ — สถานะตรวจสอบสิทธิ์ nav ข้อความแสดงปัญหา การตรวจสอบโปรแกรม |
| [เส้นทางที่ปกป้อง และการจัดขอบเขต User](protected-routes/index.html) | Route guards (RequireLogin / RequireLoginJSON) เขตข้อมูลโน้ตของผู้ใช้ การบังคับใช้ความเป็นเจ้าของ |
| [การเข้ารหัส](encoding/index.html) | การแยกวิเคราะห์แบบฟอร์ม ประเภท MIME UTF-8 และ percent-encoding |

## เวอร์ชันปัจจุบัน

**v1.0.0** — เขตข้อมูลโน้ตของผู้ใช้ (ผู้ใช้แต่ละคนเห็นเพียงรายการของตนเอง) ตรวจสอบสิทธิ์แบบคุกกี้ (คุกกี้ `mvvm_auth` ที่ลงนาม HMAC แทนที่การตรวจสอบสิทธิ์ WebSession ที่ขัดข้อง) เส้นทางที่ปกป้อง (ทั้งหมด 19 เส้นทางต้องการการเข้าสู่ระบบ) Alpine.js สำหรับความโต้ตอบฝั่งไคลเอนต์ JSON API ที่มีการตรวจสอบสิทธิ์ และเซิร์ฟเวอร์ไฟล์สแตติกในตัวสำหรับเอกสารผู้พัฒนาที่ `/dist/*`