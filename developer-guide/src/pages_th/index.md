---
title: บทนำ
description: เฟรมเวิร์ก Xojo MVVM Web (XjMVVM) ที่ใช้การเรนเดอร์ฝั่งเซิร์ฟเวอร์ สร้างบน Xojo Web 2 โดยใช้เอนจิน JinjaX
---

# บทนำ

นี่คือ **XjMVVM** (Xojo MVVM Web Framework) — เฟรมเวิร์กเว็บแอปพลิเคชันที่ใช้การเรนเดอร์ฝั่งเซิร์ฟเวอร์ (SSR) สร้างบน Xojo Web 2 แทนที่จะใช้ระบบ WebPage และ WebControl GUI ของ Xojo ทำนองเดียวกัน คำขอ HTTP ทุกรายการจะถูกดักจับใน `HandleURL` และถูกส่งไปยัง ViewModel ซึ่งเรนเดอร์การตอบสนอง HTML โดยใช้เอนจิน **JinjaX template**

สถาปัตยกรรมจงใจออกแบบให้คล้ายกับ **Flask** หรือ **Django** — คุ้นเคยสำหรับใครก็ตามที่สร้างแอป SSR ในภาษา Python หากคุณไม่เคยใช้ Flask ให้นึกถึงมันในลักษณะนี้: เบราว์เซอร์ขอหน้า เซิร์ฟเวอร์เรียกใช้โค้ด สร้างสตริง HTML และส่งกลับไป ไม่มีเฟรมเวิร์ก JavaScript ไม่มี WebSockets สำหรับการเรนเดอร์ เพียงคำขอ/การตอบสนองที่สะอาด

## วงจรชีวิตของคำขอ

คำขอทุกรายการ — โดยไม่คำนึงถึง URL — ไหลผ่านไปป์ไลน์เดียวกัน:

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

ไม่มีอะไรในไปป์ไลน์นี้ใช้ `WebPage`, `WebButton`, `WebTextField` หรือ WebControl ของ Xojo อื่น ๆ `Default` WebPage ในไฟล์โครงการเป็นเพียงตัวยึดตำแหน่งที่จำเป็นสำหรับโครงสร้างโครงการของ Xojo — ไม่เคยถูกเสิร์ฟจริง ๆ

## การเรียกใช้แอป

1. เปิด `mvvm.xojo_project` ใน **Xojo 2025r3.1**
2. คลิก **Run** (⌘R) แอปจะเริ่มต้นที่ `http://localhost:8080`
3. ฐานข้อมูล SQLite `data/notes.sqlite` ถูกสร้างโดยอัตโนมัติในการเปิดตัวครั้งแรก

ไม่มีระบบการสร้างจาก CLI การทดสอบและการสร้างทั้งหมดเกิดขึ้นภายใน Xojo IDE

## สิ่งที่รวมอยู่ในคู่มือนี้

| ส่วน | สิ่งที่คุณจะเรียนรู้ |
|---|---|
| [ทำไมถึง MVVM?](concepts/index.html) | การตัดสินใจทางสถาปัตยกรรมและข้อแลกเปลี่ยนเบื้องหลังการออกแบบนี้ |
| [อนุสัญญา](conventions/index.html) | โครงสร้างไดเรกทอรี การตั้งชื่อไฟล์ การตั้งชื่อเมธอดและคุณสมบัติ |
| [ไฟล์คงที่](static-files/index.html) | วิธีการเสิร์ฟ CSS, JS และรูปภาพ |
| [เทมเพลต](templates/index.html) | การตั้งค่า JinjaX ไวยากรณ์ Jinja2 ตัวอย่างจริง อ้างอิงแท็กแบบเต็ม |
| [ฐานข้อมูล](database/index.html) | รูปแบบ SQLite สัญญา Dictionary ความปลอดภัยเธรด |
| [การเข้ารหัส](encoding/index.html) | การแยกวิเคราะห์แบบฟอร์ม ประเภท MIME UTF-8 และเปอร์เซ็นต์การเข้ารหัส |

## เวอร์ชั่นปัจจุบัน

**v0.3.0** — CRUD ที่สมบูรณ์พร้อม Unicode (ไทย emoji) การตรวจสอบแบบฟอร์ม ข้อความแฟลช หน้าข้อผิดพลาด 404/500 และรูปแบบ POST/Redirect/GET เฟส 3 (การรับรองความถูกต้อง โมเดลหลายตัว) จะเป็นไปตามนั้น
