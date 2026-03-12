---
title: การตั้งชื่อไฟล์
description: อนุสัญญาการตั้งชื่อสำหรับไฟล์ ViewModel ไฟล์ Model และไฟล์เทมเพลต
---

# การตั้งชื่อไฟล์

## ViewModels

ไฟล์ ViewModel ปฏิบัติตามรูปแบบ `{Feature}{Action}VM.xojo_code` โดยที่:

- **Feature** คือคำนาม (พหูพจน์สำหรับการดำเนินการของคอลเลกชัน เอกพจน์สำหรับการดำเนินการของรายการ)
- **Action** คือกริยาที่อธิบายว่า ViewModel นี้ทำอะไร
- คำนำหน้า **VM** ทำให้ชัดเจนทันทีว่านี่คือ ViewModel

การดำเนินการมาตรฐานทั้งเจ็ดสำหรับทรัพยากรต่อไปนี้จะตามหลักเกณฑ์ RESTful:

| การดำเนินการ | HTTP | URL | ไฟล์ |
|---|---|---|---|
| แสดงรายการทั้งหมด | `GET` | `/notes` | `NotesListVM.xojo_code` |
| แสดงแบบฟอร์มใหม่ | `GET` | `/notes/new` | `NotesNewVM.xojo_code` |
| สร้าง | `POST` | `/notes` | `NotesCreateVM.xojo_code` |
| แสดงรายละเอียด | `GET` | `/notes/:id` | `NotesDetailVM.xojo_code` |
| แสดงแบบฟอร์มแก้ไข | `GET` | `/notes/:id/edit` | `NotesEditVM.xojo_code` |
| อัปเดต | `POST` | `/notes/:id` | `NotesUpdateVM.xojo_code` |
| ลบ | `POST` | `/notes/:id/delete` | `NotesDeleteVM.xojo_code` |

ไม่ใช่ทุกทรัพยากรที่ต้องการทั้งเจ็ด ทรัพยากรอ่านเท่านั้นอาจมี `ListVM` และ `DetailVM` เท่านั้น หน้าที่ไม่ใช่ REST (เช่นหน้าแรมหรือแดชบอร์ด) ได้รับชื่อเรียบง่ายแบบอธิบาย: `HomeViewModel.xojo_code`

### ชื่อคลาสตรงกับชื่อไฟล์

ชื่อคลาสภายในไฟล์ต้องตรงกับชื่อไฟล์อย่างแน่นอน:

```
NotesCreateVM.xojo_code  →  Class NotesCreateVM
NoteModel.xojo_code      →  Class NoteModel
```

Xojo ใช้ชื่อคลาส — ไม่ใช่ชื่อไฟล์ — ในเวลาการรัน แต่การให้พวกมันเหมือนกันจะป้องกันความสับสน

## Models

ไฟล์ Model ปฏิบัติตามรูปแบบ `{Feature}Model.xojo_code`:

```
NoteModel.xojo_code     # เอกพจน์ — "โมเดลสำหรับบันทึก"
UserModel.xojo_code     # อนาคต
ProductModel.xojo_code  # อนาคต
```

ใช้ **รูปแบบเอกพจน์** ของคำนาม — Model แทนเอนทิตี้เอง ไม่ใช่คอลเลกชัน

## เทมเพลต

ไฟล์เทมเพลตใช้ชื่อ `snake_case` ตัวพิมพ์เล็กและนามสกุล `.html`

ชื่อโฟลเดอร์ตรงกับฟีเจอร์ (พหูพจน์ตัวพิมพ์เล็ก):

```
templates/
  notes/
    list.html     ← มุมมองคอลเลกชัน
    detail.html   ← มุมมองรายการเดียว
    form.html     ← สร้าง + แก้ไข (ใช้ร่วมกัน)
  users/
    list.html
    detail.html
    form.html
  layouts/
    base.html     ← เลเยต์ไซต์ ไม่เรนเดอร์โดยตรง
  errors/
    404.html
    500.html
```

### เทมเพลตแบบฟอร์มใช้ร่วมกัน

เมื่อแบบฟอร์มสร้างและแบบฟอร์มแก้ไขเกือบเหมือนกัน ให้ใช้ `form.html` เดียวและสลับบนตัวแปรบริบท:

```html
{# templates/notes/form.html #}
{% if note %}
  {# โหมดแก้ไข — note.id มีอยู่ #}
  <form method="post" action="/notes/{{ note.id }}">
  <h1>Edit Note</h1>
{% else %}
  {# โหมดสร้าง — ไม่มีบันทึก #}
  <form method="post" action="/notes">
  <h1>New Note</h1>
{% endif %}
```

ViewModel ควบคุมโหมดโดยส่งหรือละเว้น `note` ในพจนานุกรมบริบท

## การลงทะเบียนเส้นทางตั้งชื่อ

เมื่อลงทะเบียนเส้นทางใน `App.Opening()` ให้ตรงกับลำดับ: GET ก่อน POST รายการก่อนรายละเอียด:

```xojo
// ใน App.Opening() — ลงทะเบียนเส้นทางตามลำดับตรรกะ
mRouter.Get("/",                 New HomeViewModelFactory())
mRouter.Get("/notes",            New NotesListVMFactory())
mRouter.Get("/notes/new",        New NotesNewVMFactory())    // ← ต้องมาก่อน :id
mRouter.Post("/notes",           New NotesCreateVMFactory())
mRouter.Get("/notes/:id",        New NotesDetailVMFactory())
mRouter.Get("/notes/:id/edit",   New NotesEditVMFactory())
mRouter.Post("/notes/:id",       New NotesUpdateVMFactory())
mRouter.Post("/notes/:id/delete",New NotesDeleteVMFactory())
```

!!! warning "ลำดับสำคัญ"
    `/notes/new` ต้องลงทะเบียน **ก่อน** `/notes/:id` Router จับคู่เส้นทางตามลำดับการลงทะเบียน — ถ้า `:id` มาก่อน ส่วนตัวอักษร `new` จะถูกจับเป็นค่า ID
