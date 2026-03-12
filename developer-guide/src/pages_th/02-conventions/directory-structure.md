---
title: โครงสร้างไดเรกทอรี
description: แผนที่ที่มีคำอธิบายประกอบของโฟลเดอร์และไฟล์ทุกไฟล์ในโครงการ
---

# โครงสร้างไดเรกทอรี

```
mvvm/
├── mvvm.xojo_project           # ไฟล์โครงการ Xojo (เปิดนี้ใน IDE)
├── mvvm.xojo_resources         # ทรัพยากรคงที่ที่มีชุดขึ้นมาพร้อมกับแอป
│
├── App.xojo_code               # WebApplication — Opening(), HandleURL()
├── Session.xojo_code           # WebSession subclass — สถานะต่อผู้ใช้ ข้อความแฟลช
├── Default.xojo_code           # WebPage ตัวยึดตำแหน่งที่จำเป็น (ไม่เสิร์ฟเลย)
│
├── Framework/                  # โครงสร้างพื้นฐานที่นำกลับมาใช้ใหม่ — ไม่ค่อยแก้ไข
│   ├── Router.xojo_code        # การลงทะเบียนเส้นทางและการส่ง
│   ├── BaseViewModel.xojo_code # คลาสฐาน: Handle(), Render(), Redirect(), flash
│   ├── FormParser.xojo_code    # แยกวิเคราะห์ application/x-www-form-urlencoded POST bodies
│   ├── QueryParser.xojo_code   # แยกวิเคราะห์สตริงการค้นหา URL (?key=val&...)
│   └── RouteDefinition.xojo_code  # ชั้นข้อมูล: method, pattern, factory
│
├── ViewModels/                 # คลาสหนึ่งต่อเส้นทาง
│   ├── HomeViewModel.xojo_code # GET /
│   └── Notes/                  # โฟลเดอร์ฟีเจอร์ — ViewModels ที่เกี่ยวข้องกับบันทึกทั้งหมด
│       ├── NotesListVM.xojo_code   # GET  /notes
│       ├── NotesNewVM.xojo_code    # GET  /notes/new
│       ├── NotesCreateVM.xojo_code # POST /notes
│       ├── NotesDetailVM.xojo_code # GET  /notes/:id
│       ├── NotesEditVM.xojo_code   # GET  /notes/:id/edit
│       ├── NotesUpdateVM.xojo_code # POST /notes/:id
│       └── NotesDeleteVM.xojo_code # POST /notes/:id/delete
│
├── Models/                     # การเข้าถึงข้อมูล — คืนค่าอ็อบเจ็กต์ Dictionary เท่านั้น
│   └── NoteModel.xojo_code     # CRUD SQLite สำหรับตาราบันทึก
│
├── JinjaXLib/                  # ต้นไม้ต้นฉบับ JinjaX เต็ม (เอนจิน Jinja2 ใน Xojo)
│   └── ...                     # อย่าแก้ไขเว้นแต่จะอัปเกรด JinjaX
│
├── templates/                  # เทมเพลต HTML (ไวยากรณ์ Jinja2)
│   ├── layouts/
│   │   └── base.html           # เลเยต์ไซต์ — nav ข้อความแฟลช บล็อกเนื้อหา
│   ├── home.html               # GET /
│   ├── notes/
│   │   ├── list.html           # GET /notes
│   │   ├── detail.html         # GET /notes/:id
│   │   └── form.html           # GET /notes/new และ GET /notes/:id/edit (ใช้ร่วมกัน)
│   └── errors/
│       ├── 404.html
│       └── 500.html
│
├── data/
│   └── notes.sqlite            # ฐานข้อมูล SQLite (สร้างโดยอัตโนมัติในการรันครั้งแรก)
│
└── developer-guide/            # เอกสารประกอบนี้
    ├── build.py
    ├── nav.yaml
    ├── src/
    └── dist/
```

## Framework vs. ViewModels

โฟลเดอร์ `Framework/` มีโค้ดที่คุณเขียนครั้งเดียวและไม่ค่อยสัมผัส มันคือ "เอนจิน" — การจัดเส้นทาง ชีวิตฐาน ViewModel ตัวช่วยคำขอ/การตอบสนอง เมื่อคุณเพิ่มฟีเจอร์ใหม่ คุณไม่เคยแก้ไข `Framework/`

`ViewModels/` คือที่ที่งานเฉพาะแอปพลิเคชันทั้งหมดเกิดขึ้น ทุกเส้นทางใหม่ได้รับไฟล์ ViewModel ใหม่ในโฟลเดอร์ฟีเจอร์ที่เกี่ยวข้อง

## โฟลเดอร์ฟีเจอร์ใน ViewModels

จัดกลุ่ม ViewModels ตามฟีเจอร์ ไม่ใช่ตามวิธี HTTP:

```
ViewModels/
  Notes/         ← ViewModels ที่เกี่ยวข้องกับบันทึกทั้งเจ็ดตัวอยู่ที่นี่
  Users/         ← ViewModels ที่เกี่ยวข้องกับผู้ใช้ทั้งหมด (อนาคต)
  Admin/         ← ViewModels ที่เกี่ยวข้องกับผู้ดูแลระบบทั้งหมด (อนาคต)
```

สิ่งนี้ทำให้ไฟล์ที่เกี่ยวข้องอยู่ด้วยกัน และทำให้หาทุกอย่างเกี่ยวกับฟีเจอร์ในที่เดียวได้ง่าย

## การสะท้อนเทมเพลต

โครงสร้าง `templates/` สะท้อนลำดับชั้น URL:

| URL | เทมเพลต |
|---|---|
| `/notes` | `templates/notes/list.html` |
| `/notes/new` | `templates/notes/form.html` |
| `/notes/:id` | `templates/notes/detail.html` |
| `/notes/:id/edit` | `templates/notes/form.html` |
| ข้อผิดพลาด 404 | `templates/errors/404.html` |

เทมเพลต `form.html` ใช้ร่วมกันระหว่างเส้นทางสร้างและแก้ไข มันตรวจสอบตัวแปรบริบท `note`: ถ้ามีอยู่ แบบฟอร์มจะอยู่ในโหมดแก้ไข ถ้าเป็น `Nil` แบบฟอร์มจะอยู่ในโหมดสร้าง

## ไดเรกทอรี `data/`

ปัจจุบัน เส้นทางฐานข้อมูลเป็นรหัสคงที่สำหรับการพัฒนา สำหรับบิลด์โปรดักชัน ให้ใช้ `SpecialFolder.ApplicationData` เพื่อวางฐานข้อมูลในตำแหน่ง OS ที่ถูกต้อง:

```xojo
// การพัฒนา (รหัสคงที่สำหรับการรันดีบัต IDE)
Var dbFile As New FolderItem("/path/to/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)

// โปรดักชัน (วิธีการที่ถูกต้อง)
Var appData As FolderItem = SpecialFolder.ApplicationData
Var dbFile As FolderItem = appData.Child("mvvm").Child("notes.sqlite")
```
