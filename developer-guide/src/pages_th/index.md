---
title: บทนำ
description: เฟรมเวิร์ก Xojo MVVM Web ที่렌เดอร์ฝั่งเซิร์ฟเวอร์ (XjMVVM) สร้างบน Xojo Web 2 ขับเคลื่อนด้วยเทมเพลต JinjaX
---

# บทนำ

นี่คือ **XjMVVM** (Xojo MVVM Web Framework) — เฟรมเวิร์กเว็บแอปพลิเคชันที่렌เดอร์ฝั่งเซิร์ฟเวอร์ (SSR) สร้างบน Xojo Web 2 แทนที่จะใช้ระบบ GUI WebPage และ WebControl ที่สร้างไว้ของ Xojo ทุก HTTP request จะถูกสกัดกั้นใน `HandleURL` และถูกส่งไปยัง ViewModel ซึ่งจะรenderHTML response โดยใช้เอนจิน **JinjaX template**

สถาปัตยกรรมมีลักษณะคล้ายกับ **Flask** หรือ **Django** โดยเจตนา — คุ้นเคยกับใครที่ได้สร้าง SSR web apps ใน Python มาแล้ว หากคุณไม่เคยใช้ Flask ลองคิดดูแบบนี้: เบราว์เซอร์ขอหน้าเว็บ เซิร์ฟเวอร์เรียกใช้โค้ดบางส่วน สร้างสตริง HTML และส่งกลับ ไม่มี JavaScript framework ไม่มี WebSockets สำหรับการแสดงผล แค่ request/response ที่สะอาดเรียบร้อย

## วงจรชีวิตของคำขอ

ทุก request — ไม่ว่า URL จะเป็นอะไร — ไหลผ่านท่อเดียวกัน:

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

ไม่มีอะไรในท่อนี้ใช้ `WebPage` `WebButton` `WebTextField` หรือ Xojo web control อื่น ๆ WebPage `Default` ในไฟล์โครงการเป็นตัวยึดตำแหน่งที่จำเป็นสำหรับโครงสร้างโครงการของ Xojo — มันไม่เคยถูกให้บริการจริง ๆ

## การรันแอปพลิเคชัน

1. เปิด `mvvm.xojo_project` ใน **Xojo 2025r3.1**
2. คลิก **Run** (⌘R) แอปจะเริ่มที่ `http://localhost:8080`
3. ฐานข้อมูล SQLite `data/notes.sqlite` จะถูกสร้างโดยอัตโนมัติเมื่อเปิดใช้ครั้งแรก

ไม่มีระบบ CLI build ทั้งหมดการทดสอบและการสร้างเกิดขึ้นภายใน Xojo IDE

## สิ่งที่อยู่ในคำแนะนำนี้

| ส่วน | สิ่งที่คุณจะเรียนรู้ |
|---|---|
| [ทำไม MVVM?](concepts/index.html) | การตัดสินใจสถาปัตยกรรมและการแลกเปลี่ยนเสีย ๆ หลัง ๆ ของการออกแบบนี้ |
| [Routing](routing/index.html) | HandleURL ต้นไม้การตัดสินใจ การเปลี่ยนเส้นทาง `/tests` การข้ามระหว่าง SSR และ Xojo WebPage |
| [การใช้งาน](conventions/index.html) | โครงสร้างไดเรกทอรี่ การตั้งชื่อไฟล์ การตั้งชื่อวิธีการและคุณสมบัติ |
| [ไฟล์คงที่](static-files/index.html) | วิธีการให้บริการ CSS JS และรูปภาพ |
| [เทมเพลต](templates/index.html) | การตั้งค่า JinjaX ไวยากรณ์ Jinja2 ตัวอย่างจริง ข้อมูลอ้างอิงแท็กทั้งหมด |
| [ฐานข้อมูล](database/index.html) | รูปแบบ SQLite สัญญา Dictionary ความปลอดภัยของเธรด |
| [อ้างอิง DB Layer](database/model-reference.html) | สถาปัตยกรรมสามชั้น (DBAdapter / BaseModel / NoteModel) CRUD API ที่สมบูรณ์ การแลกเปลี่ยน |
| [แท็ก & ความสัมพันธ์แบบหลายต่อหลาย](tags/index.html) | ทรัพยากรที่สอง ตารางเชื่อมต่อ GetTagsForNote SetTagsForNote |
| [ระบบการรับรองความถูกต้อง](auth/index.html) | UserModel การแฮช SHA-256 + salt รหัสผ่าน Session RequireLogin guard |
| [JSON API & การให้บริการคงที่](api/index.html) | JSONSerializer API ViewModels สถานะ 201/422 ServeStatic path-traversal guard |
| [การเข้ารหัส](encoding/index.html) | การแยกวิเคราะห์แบบฟอร์ม ประเภท MIME UTF-8 และการเข้ารหัสเปอร์เซ็นต์ |

## เวอร์ชันปัจจุบัน

**v0.9.0** — JSON API layer การรับรองความถูกต้อง (SHA-256 + salt session login/logout) ทรัพยากรแท็กพร้อมจำนวนมากถึงจำนวนมากหลายตาราง note_tags และเซิร์ฟเวอร์ไฟล์คงที่ที่สร้างขึ้นสำหรับเอกสารนักพัฒนาที่ `/dist/*` การแก้ไขเส้นทางการผลิต (v0.4.2) ช่วยให้แน่ใจว่า DB และเทมเพลตแก้ไขสัมพันธ์กับไฟล์เรียกใช้ได้ในสภาพแวดล้อมทั้งหมด