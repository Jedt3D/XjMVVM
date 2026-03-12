---
title: การตั้งชื่อไฟล์
description: การตั้งชื่อไฟล์ตามแบบแผนสำหรับไฟล์ ViewModel ไฟล์ Model และไฟล์แม่แบบ
---

# การตั้งชื่อไฟล์

## ViewModels

ไฟล์ ViewModel ปฏิบัติตามรูปแบบ `{Feature}{Action}VM.xojo_code` โดยที่:

- **Feature** คือคำนาม (พหูพจน์สำหรับการดำเนินการกับคอลเลกชัน เอกพจน์สำหรับการดำเนินการกับรายการ)
- **Action** คือกริยาที่อธิบายว่า ViewModel นี้ทำอะไร
- **VM** suffix ทำให้เห็นได้ชัดว่านี่คือ ViewModel

แอคชั่นมาตรฐานเจ็ดประการสำหรับทรัพยากรปฏิบัติตามหลักการ RESTful:

| Action | HTTP | URL | ไฟล์ |
|---|---|---|---|
| แสดงรายการทั้งหมด | `GET` | `/notes` | `NotesListVM.xojo_code` |
| แสดงแบบฟอร์มใหม่ | `GET` | `/notes/new` | `NotesNewVM.xojo_code` |
| สร้าง | `POST` | `/notes` | `NotesCreateVM.xojo_code` |
| แสดงรายละเอียด | `GET` | `/notes/:id` | `NotesDetailVM.xojo_code` |
| แสดงแบบฟอร์มแก้ไข | `GET` | `/notes/:id/edit` | `NotesEditVM.xojo_code` |
| อัปเดต | `POST` | `/notes/:id` | `NotesUpdateVM.xojo_code` |
| ลบ | `POST` | `/notes/:id/delete` | `NotesDeleteVM.xojo_code` |

ไม่ใช่ทรัพยากรทั้งหมดจำเป็นต้องมีทั้งเจ็ด ทรัพยากรแบบอ่านอย่างเดียวอาจมีเพียง `ListVM` และ `DetailVM` เท่านั้น หน้าที่ไม่ใช่ REST (เช่นหน้าแรมหรือแดชบอร์ด) จะได้รับชื่ออธิบายอย่างง่าย: `HomeViewModel.xojo_code`

### ชื่อคลาสตรงกับชื่อไฟล์

ชื่อคลาสในไฟล์จะต้องตรงกับชื่อไฟล์ทุกประการ:

```
NotesCreateVM.xojo_code  →  Class NotesCreateVM
NoteModel.xojo_code      →  Class NoteModel
```

Xojo ใช้ชื่อคลาส — ไม่ใช่ชื่อไฟล์ — ในระหว่างรันไทม์ แต่การทำให้ชื่อทั้งสองเหมือนกันจะช่วยป้องกันความสับสน

## Models

ไฟล์ Model ปฏิบัติตามรูปแบบ `{Feature}Model.xojo_code`:

```
NoteModel.xojo_code     # เอกพจน์ — "โมเดลสำหรับโน้ต"
UserModel.xojo_code     # ในอนาคต
ProductModel.xojo_code  # ในอนาคต
```

ใช้รูปแบบ **เอกพจน์** ของคำนาม — Model แทนเอนทิตีเอง ไม่ใช่คอลเลกชันของมัน

## Templates

ไฟล์แม่แบบใช้ชื่อ lowercase `snake_case` และนามสกุล `.html`

ชื่อโฟลเดอร์ตรงกับฟีเจอร์ (พหูพจน์ lowercase):

```
templates/
  notes/
    list.html     ← มุมมองคอลเลกชัน
    detail.html   ← มุมมองรายการเดี่ยว
    form.html     ← สร้าง + แก้ไข (ใช้ร่วมกัน)
  users/
    list.html
    detail.html
    form.html
  layouts/
    base.html     ← เลเยาต์ไซต์ ไม่เคยแสดงผลโดยตรง
  errors/
    404.html
    500.html
```

### แม่แบบแบบฟอร์มที่ใช้ร่วมกัน

เมื่อแบบฟอร์มสร้างและแบบฟอร์มแก้ไขเกือบเหมือนกัน ให้ใช้ `form.html` ไฟล์เดี่ยวและสลับไปมาตามการมีอยู่ของตัวแปรบริบท:

```html
{# templates/notes/form.html #}
{% if note %}
  {# โหมดแก้ไข — note.id มีอยู่ #}
  <form method="post" action="/notes/{{ note.id }}">
  <h1>Edit Note</h1>
{% else %}
  {# โหมดสร้าง — ไม่มี note #}
  <form method="post" action="/notes">
  <h1>New Note</h1>
{% endif %}
```

ViewModel ควบคุมโหมดโดยการส่ง `note` ในพจนานุกรมบริบทหรือการละเว้นมัน

## การตั้งชื่อการลงทะเบียนเส้นทาง

เมื่อลงทะเบียนเส้นทางใน `App.Opening()` ให้ตรงกับลำดับ: GET ก่อน POST รายการก่อนรายละเอียด:

```xojo
// ใน App.Opening() — ลงทะเบียนเส้นทางตามลำดับตรรกะ
mRouter.Get("/",                 New HomeViewModelFactory())
mRouter.Get("/notes",            New NotesListVMFactory())
mRouter.Get("/notes/new",        New NotesNewVMFactory())    // ← จะต้องมาก่อน :id
mRouter.Post("/notes",           New NotesCreateVMFactory())
mRouter.Get("/notes/:id",        New NotesDetailVMFactory())
mRouter.Get("/notes/:id/edit",   New NotesEditVMFactory())
mRouter.Post("/notes/:id",       New NotesUpdateVMFactory())
mRouter.Post("/notes/:id/delete",New NotesDeleteVMFactory())
```

!!! warning "ลำดับมีความสำคัญ"
    `/notes/new` จะต้องลงทะเบียน **ก่อน** `/notes/:id` Router จะจับคู่เส้นทางตามลำดับการลงทะเบียน — หากมี `:id` มาก่อน ส่วนตัวอักษรเชื่อมต่อ `new` จะถูกจับเป็นค่า ID