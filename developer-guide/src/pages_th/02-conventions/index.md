---
title: ภาพรวมอนุสัญญา
description: อนุสัญญาการตั้งชื่อและโครงสร้างที่ใช้ตลอดทั้งเฟรมเวิร์ก XjMVVM
---

# อนุสัญญา

อนุสัญญาที่สอดคล้องกันทำให้ฐานรหัสคาดเดาได้ เมื่อนักพัฒนาทุกคนปฏิบัติตามรูปแบบเดียวกันสำหรับชื่อไฟล์ ชื่อคลาส และชื่อเมธอด คุณสามารถนำทางไปยังฟีเจอร์ที่ไม่คุ้นเคยโดยไม่ต้องเปิดไฟล์ทุกไฟล์

ส่วนนี้ครอบคลุมสามพื้นที่:

- **[โครงสร้างไดเรกทอรี](directory-structure.html)** — ที่ที่สิ่งต่างๆ อาศัยอยู่และเหตุผล
- **[การตั้งชื่อไฟล์](file-naming.html)** — วิธีการตั้งชื่อ ViewModels Models และเทมเพลต
- **[เมธอดและคุณสมบัติ](naming-methods-properties.html)** — กฎการตั้งชื่อสำหรับโค้ด Xojo

## ข้อมูลอ้างอิงอย่างรวดเร็ว

| สิ่ง | อนุสัญญา | ตัวอย่าง |
|---|---|---|
| ไฟล์ ViewModel | `{Feature}{Action}VM.xojo_code` | `NotesCreateVM.xojo_code` |
| ไฟล์ Model | `{Feature}Model.xojo_code` | `NoteModel.xojo_code` |
| โฟลเดอร์เทมเพลต | `templates/{feature}/` | `templates/notes/` |
| ไฟล์เทมเพลต | `{action}.html` | `form.html`, `list.html` |
| คุณสมบัติส่วนตัว | `mCamelCase` | `mFormData`, `mRawBody` |
| เมธอด ViewModel (GET) | `OnGet()` | แทนที่ `BaseViewModel.OnGet()` |
| เมธอด ViewModel (POST) | `OnPost()` | แทนที่ `BaseViewModel.OnPost()` |
| กุญแจ Dictionary | สตริง `snake_case` | `"page_title"`, `"created_at"` |
| พารามิเตอร์เส้นทาง URL | `:snake_case` | `/notes/:id` |
