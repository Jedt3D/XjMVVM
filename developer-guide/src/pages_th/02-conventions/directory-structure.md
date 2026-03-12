---
title: โครงสร้างไดเรกทอรี่
description: แผนที่อธิบายรายละเอียดของทุกโฟลเดอร์และไฟล์ในโปรเจกต์
---

# โครงสร้างไดเรกทอรี่

```
mvvm/
├── mvvm.xojo_project           # Xojo project file (open this in the IDE)
├── mvvm.xojo_resources         # Static resources bundled with the app
│
├── App.xojo_code               # WebApplication — Opening(), HandleURL()
├── Session.xojo_code           # WebSession subclass — per-user state, flash messages
├── Default.xojo_code           # Required placeholder WebPage (never served)
│
├── Framework/                  # Reusable infrastructure — rarely modified
│   ├── Router.xojo_code        # Route registration and dispatch
│   ├── BaseViewModel.xojo_code # Base class: Handle(), Render(), Redirect(), flash
│   ├── FormParser.xojo_code    # Parses application/x-www-form-urlencoded POST bodies
│   ├── QueryParser.xojo_code   # Parses URL query strings (?key=val&...)
│   └── RouteDefinition.xojo_code  # Data class: method, pattern, factory
│
├── ViewModels/                 # One class per route
│   ├── HomeViewModel.xojo_code # GET /
│   └── Notes/                  # Feature folder — all note-related ViewModels
│       ├── NotesListVM.xojo_code   # GET  /notes
│       ├── NotesNewVM.xojo_code    # GET  /notes/new
│       ├── NotesCreateVM.xojo_code # POST /notes
│       ├── NotesDetailVM.xojo_code # GET  /notes/:id
│       ├── NotesEditVM.xojo_code   # GET  /notes/:id/edit
│       ├── NotesUpdateVM.xojo_code # POST /notes/:id
│       └── NotesDeleteVM.xojo_code # POST /notes/:id/delete
│
├── Models/                     # Data access — returns Dictionary objects only
│   └── NoteModel.xojo_code     # SQLite CRUD for the notes table
│
├── JinjaXLib/                  # Full JinjaX source tree (Jinja2 engine in Xojo)
│   └── ...                     # Do not modify unless upgrading JinjaX
│
├── templates/                  # HTML templates (Jinja2 syntax)
│   ├── layouts/
│   │   └── base.html           # Site layout — nav, flash messages, content block
│   ├── home.html               # GET /
│   ├── notes/
│   │   ├── list.html           # GET /notes
│   │   ├── detail.html         # GET /notes/:id
│   │   └── form.html           # GET /notes/new and GET /notes/:id/edit (shared)
│   └── errors/
│       ├── 404.html
│       └── 500.html
│
├── data/
│   └── notes.sqlite            # SQLite database (auto-created on first run)
│
└── developer-guide/            # This documentation
    ├── build.py
    ├── nav.yaml
    ├── src/
    └── dist/
```

## Framework vs. ViewModels

โฟลเดอร์ `Framework/` ประกอบด้วยโค้ดที่เราเขียนครั้งเดียวและแทบไม่ต้องแก้ไขอีก มันคือ "เครื่องยนต์" — routing, base ViewModel lifecycle, และ helper สำหรับ request/response สิ่งสำคัญคือเมื่อเพิ่มฟีเจอร์ใหม่ เราจะไม่ต้องแก้ไขไฟล์ใดๆ ใน `Framework/` เลย

`ViewModels/` คือตำแหน่งที่ทำงานเฉพาะของแอปพลิเคชัน ทุกเส้นทาง (route) ใหม่จะได้ไฟล์ ViewModel ใหม่อยู่ในโฟลเดอร์ฟีเจอร์ที่เกี่ยวข้อง

## Feature folders ใน ViewModels

จัดกลุ่ม ViewModels ตามฟีเจอร์ ไม่ใช่ตามเมธอด HTTP:

```
ViewModels/
  Notes/         ← all seven note-related ViewModels live here
  Users/         ← all user-related ViewModels (future)
  Admin/         ← all admin-related ViewModels (future)
```

วิธีนี้ช่วยให้ไฟล์ที่เกี่ยวข้องอยู่ด้วยกัน และทำให้ค้นหาทุกอย่างเกี่ยวกับฟีเจอร์ในที่เดียวได้ง่าย

## Template mirroring

โครงสร้าง `templates/` สะท้อนให้เห็นลำดับชั้นของ URL:

| URL | Template |
|---|---|
| `/notes` | `templates/notes/list.html` |
| `/notes/new` | `templates/notes/form.html` |
| `/notes/:id` | `templates/notes/detail.html` |
| `/notes/:id/edit` | `templates/notes/form.html` |
| Error 404 | `templates/errors/404.html` |

เทมเพลต `form.html` ใช้ร่วมกันระหว่างเส้นทาง create และ edit โดยตรวจสอบตัวแปร context `note`: ถ้ามีอยู่ ฟอร์มจะอยู่ในโหมด edit; ถ้าเป็น `Nil` ฟอร์มจะอยู่ในโหมด create

## ไดเรกทอรี่ `data/`

ในปัจจุบัน path ของฐานข้อมูลถูกเขียนแบบ hardcode สำหรับการพัฒนา สำหรับ production builds ให้ใช้ `SpecialFolder.ApplicationData` เพื่อวางฐานข้อมูลในตำแหน่งที่ถูกต้องตามระบบปฏิบัติการ:

```xojo
// Development (hardcoded for IDE debug runs)
Var dbFile As New FolderItem("/path/to/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)

// Production (correct approach)
Var appData As FolderItem = SpecialFolder.ApplicationData
Var dbFile As FolderItem = appData.Child("mvvm").Child("notes.sqlite")
```