---
title: เมธอดและคุณสมบัติ
description: อนุสัญญาการตั้งชื่อสำหรับเมธอด คุณสมบัติ และกุญแจ Dictionary ของ Xojo
---

# เมธอดและคุณสมบัติ

## เมธอด ViewModel

ViewModel ทั้งหมดสืบทอดจาก `BaseViewModel` และแทนที่หนึ่งหรือทั้งสองอย่าง:

```xojo
Sub OnGet()   // จัดการคำขอ GET
Sub OnPost()  // จัดการคำขอ POST
```

สิ่งเหล่านี้จงใจตั้งชื่อเหมือนตัวจัดการเหตุการณ์ — พวกเขา *ตอบสนอง* วิธี HTTP พวกเขาไม่เริ่มอะไร ถ้าคุณแทนที่เฉพาะ `OnGet()` ใด ๆ `POST` ไปยังเส้นทางนั้นจะได้รับการตอบสนอง 405 จากคลาสฐานโดยอัตโนมัติ

วิธีตัวช่วยส่วนตัวภายใน ViewModel ใช้ชื่อที่อธิบายได้กริยาก่อน:

```xojo
// ✅ ดี — อ่านเหมือนภาษาอังกฤษ อธิบายว่ามันทำอะไร
Private Function FindNoteOrRedirect(id As Integer) As Dictionary
Private Sub ValidateTitle(title As String)

// ❌ หลีกเลี่ยง — คลุมเครือ อ่านเหมือนตัวรับ
Private Function GetData() As Dictionary
Private Sub Process()
```

## คุณสมบัติ

อนุสัญญา Xojo: คุณสมบัติส่วนตัว (ระดับโมดูล) ใช้คำนำหน้า `m` และ `camelCase`:

```xojo
Private mFormData As Dictionary   // แคช POST body ที่แยกวิเคราะห์
Private mRawBody  As String       // ไบต์ POST body ดิบ
```

คุณสมบัติสาธารณะ (สิ่งที่สืบทอดจากหรือตั้งไว้โดย `BaseViewModel`) ไม่มีคำนำหน้า:

```xojo
// สิ่งเหล่านี้ถูกตั้งโดย Router ก่อนที่ Handle() จะถูกเรียก
Request    As WebRequest
Response   As WebResponse
Session    As WebSession
Jinja      As JinjaX.JinjaEnvironment
PathParams As Dictionary
```

## เมธอด Model

เมธอด Model อธิบายการดำเนินการข้อมูลอย่างชัดเจน ใช้กริยา CRUD มาตรฐาน:

| การดำเนินการ | ชื่อเมธอด | ประเภทการคืน |
|---|---|---|
| ดึงแถวทั้งหมด | `GetAll()` | `Variant()` ของ `Dictionary` |
| ดึงแถวเดียว | `GetByID(id As Integer)` | `Dictionary` หรือ `Nil` |
| สร้าง | `Create(...)` | `Integer` (ID แถวใหม่) |
| อัปเดต | `Update(id, ...)` | `Sub` (ไม่มีการคืน) |
| ลบ | `Delete(id As Integer)` | `Sub` (ไม่มีการคืน) |

เมธอด Model คือ `Shared` — คุณไม่จำเป็นต้องสร้างอินสแตนซ์คลาส Model:

```xojo
// ✅ เรียกในคลาสโดยตรง
Var notes As Variant() = NoteModel.GetAll()
Var note As Dictionary = NoteModel.GetByID(42)
NoteModel.Delete(42)

// ❌ อย่าสร้างอินสแตนซ์ Models
Var model As New NoteModel()
model.GetAll()
```

## กุญแจ Dictionary

กุญแจในอ็อบเจ็กต์ `Dictionary` — ทั้งในพจนานุกรมบริบทสำหรับเทมเพลตและในค่าการคืน Model — ใช้สตริง `snake_case` สิ่งนี้ตรงกับชื่อคอลัมน์ใน SQLite และชื่อตัวแปรที่ใช้ในเทมเพลต Jinja2:

```xojo
// Model → Dictionary
row.Value("id")         = rs.Column("id").IntegerValue
row.Value("title")      = rs.Column("title").StringValue
row.Value("created_at") = rs.Column("created_at").StringValue

// ViewModel → พจนานุกรมบริบทสำหรับเทมเพลต
Var ctx As New Dictionary()
ctx.Value("notes")      = NoteModel.GetAll()    // Variant() ของ Dictionary
ctx.Value("page_title") = "All Notes"
ctx.Value("flash")      = ...                   // ฉีดโดย Render() โดยอัตโนมัติ
```

ในเทมเพลต ชื่อกุญแจ `snake_case` เดียวกันจะเข้าถึงได้ด้วยสัญกรณ์จุด:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

## เมธอดตัวช่วย BaseViewModel

เมธอดเหล่านี้มีอยู่เสมอภายใน ViewModel ใด ๆ:

`GetFormValue(key)` — อ่านฟิลด์จาก POST body ที่เข้ารหัส URL ค่อยๆ แยกวิเคราะห์ body ในการโทรครั้งแรกและแคชผลลัพธ์

```xojo
Var title As String = GetFormValue("title")
Var body  As String = GetFormValue("body")
```

`GetParam(key)` — อ่านพารามิเตอร์เส้นทาง URL หรือพารามิเตอร์สตริงการค้นหา พารามิเตอร์เส้นทางมีลำดับความสำคัญเหนือพารามิเตอร์สตริงการค้นหา

```xojo
// สำหรับเส้นทาง /notes/:id พร้อม URL /notes/42
Var id As Integer = GetParam("id").ToInteger()

// สำหรับ URL /notes?sort=asc
Var sort As String = GetParam("sort")
```

`Render(templateName, context)` — คอมไพล์และเรนเดอร์เทมเพลต ฉีดข้อความแฟลชโดยอัตโนมัติ และเขียนการตอบสนอง HTML

```xojo
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

`Redirect(url, statusCode)` — ส่งการเปลี่ยนเส้นทาง HTTP สถานะเริ่มต้นคือ 302 เสมอเรียก `Return` ทันทีหลังจากนั้นเพื่อหยุดการดำเนินการ

```xojo
Redirect("/notes")
Return
```

`SetFlash(message, type)` — เก็บข้อความแฟลชในเซสชัน การเรียก `Render()` ครั้งต่อไปใน ViewModel ใด ๆ จะฉีดมันเข้าในบริบทเทมเพลตโดยอัตโนมัติ ประเภท คือ `"success"`, `"error"` หรือ `"info"`

```xojo
SetFlash("Note created.", "success")
Redirect("/notes")
Return
```
