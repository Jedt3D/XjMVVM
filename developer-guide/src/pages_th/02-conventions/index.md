---
title: ภาพรวมของข้อตกลง
description: ข้อตกลงในการตั้งชื่อและโครงสร้างที่ใช้ในเฟรมเวิร์ก XjMVVM
---

# ข้อตกลง

ข้อตกลงที่สม่ำเสมอทำให้โค้ดเบสคาดเดาได้ เมื่อนักพัฒนาทุกคนปฏิบัติตามรูปแบบเดียวกันสำหรับชื่อไฟล์ ชื่อคลาส และชื่อเมธอด คุณสามารถนำทางฟีเจอร์ที่ไม่คุ้นเคยได้โดยไม่ต้องเปิดทุกไฟล์

ส่วนนี้ครอบคลุมสามพื้นที่:

- **[โครงสร้างไดเรกทอรี](directory-structure.html)** — ที่ตั้งของทุกอย่างและเหตุผล
- **[การตั้งชื่อไฟล์](file-naming.html)** — วิธีการตั้งชื่อ ViewModels Models และเทมเพลต
- **[เมธอดและคุณสมบัติ](naming-methods-properties.html)** — กฎการตั้งชื่อสำหรับโค้ด Xojo

## ข้อมูลอ้างอิงด่วน

| สิ่งที่ | ข้อตกลง | ตัวอย่าง |
|---|---|---|
| ไฟล์ ViewModel | `{Feature}{Action}VM.xojo_code` | `NotesCreateVM.xojo_code` |
| ไฟล์ Model | `{Feature}Model.xojo_code` | `NoteModel.xojo_code` |
| โฟลเดอร์เทมเพลต | `templates/{feature}/` | `templates/notes/` |
| ไฟล์เทมเพลต | `{action}.html` | `form.html`, `list.html` |
| คุณสมบัติส่วนตัว | `mCamelCase` | `mFormData`, `mRawBody` |
| เมธอด ViewModel (GET) | `OnGet()` | แทนที่ `BaseViewModel.OnGet()` |
| เมธอด ViewModel (POST) | `OnPost()` | แทนที่ `BaseViewModel.OnPost()` |
| คีย์ Dictionary | สตริง `snake_case` | `"page_title"`, `"created_at"` |
| พารามิเตอร์เส้นทาง URL | `:snake_case` | `/notes/:id` |