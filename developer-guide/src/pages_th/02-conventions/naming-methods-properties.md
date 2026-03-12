---
title: เมธอดและพร็อพเพอร์ตี้
description: รูปแบบการตั้งชื่อสำหรับเมธอด พร็อพเพอร์ตี้ และคีย์ Dictionary ใน Xojo
---

# เมธอดและพร็อพเพอร์ตี้

## เมธอด ViewModel

ViewModel ทุกตัวสืบทอดมาจาก `BaseViewModel` และแทนที่เมธอดใดเมธอดหนึ่งหรือทั้งสองตัวนี้:

```xojo
Sub OnGet()   // Handles GET requests
Sub OnPost()  // Handles POST requests
```

เมธอดเหล่านี้ตั้งชื่อเจตนาให้เหมือนกับตัวจัดการเหตุการณ์ — เมธอดเหล่านี้ **ตอบสนอง** ต่อเมธอด HTTP ไม่ใช่เพื่อเริ่มการทำงาน หากคุณแทนที่เพียง `OnGet()` เท่านั้น การร้องขอ `POST` ใดๆ ที่เข้ามายังเส้นทางนั้นจะได้รับการตอบกลับ 405 โดยอัตโนมัติจากคลาสพื้นฐาน

เมธอดตัวช่วยเอกชนภายในVM ใช้ชื่อที่ขึ้นต้นด้วยกริยาที่มีความหมาย:

```xojo
// ✅ ดี — อ่านเหมือนภาษาอังกฤษ บรรยายว่าเมธอดทำอะไร
Private Function FindNoteOrRedirect(id As Integer) As Dictionary
Private Sub ValidateTitle(title As String)

// ❌ หลีกเลี่ยง — ไม่ชัดเจน อ่านเหมือนเป็นตัวรับค่า
Private Function GetData() As Dictionary
Private Sub Process()
```

## พร็อพเพอร์ตี้

รูปแบบ Xojo: พร็อพเพอร์ตี้เอกชน (ระดับโมดูล) ใช้คำนำหน้า `m` และ `camelCase`:

```xojo
Private mFormData As Dictionary   // cached parsed POST body
Private mRawBody  As String       // raw POST body bytes
```

พร็อพเพอร์ตี้สาธารณะ (พร็อพเพอร์ตี้ที่สืบทอดมาจาก `BaseViewModel` หรือตั้งค่าโดย `BaseViewModel`) ไม่มีคำนำหน้า:

```xojo
// These are set by the Router before Handle() is called
Request    As WebRequest
Response   As WebResponse
Session    As WebSession
Jinja      As JinjaX.JinjaEnvironment
PathParams As Dictionary
```

## เมธอด Model

เมธอด Model บรรยายการดำเนินการกับข้อมูลอย่างชัดเจน ใช้กริยา CRUD มาตรฐาน:

| การดำเนินการ | ชื่อเมธอด | ประเภทที่ส่งกลับ |
|---|---|---|
| ดึงข้อมูลทั้งหมด | `GetAll()` | `Variant()` ของ `Dictionary` |
| ดึงข้อมูลหนึ่งแถว | `GetByID(id As Integer)` | `Dictionary` หรือ `Nil` |
| สร้าง | `Create(...)` | `Integer` (ID แถวใหม่) |
| อัปเดต | `Update(id, ...)` | `Sub` (ไม่มีค่าส่งกลับ) |
| ลบ | `Delete(id As Integer)` | `Sub` (ไม่มีค่าส่งกลับ) |

เมธอด Model เป็น `Shared` — คุณไม่ต้องสร้างอินสแตนซ์ของคลาส Model:

```xojo
// ✅ เรียกใช้ที่คลาสโดยตรง
Var notes As Variant() = NoteModel.GetAll()
Var note As Dictionary = NoteModel.GetByID(42)
NoteModel.Delete(42)

// ❌ อย่าสร้างอินสแตนซ์ของ Model
Var model As New NoteModel()
model.GetAll()
```

## คีย์ Dictionary

คีย์ในออบเจกต์ `Dictionary` — ทั้งในดิกชันนารีบริบทสำหรับเทมเพลตและในค่าส่งกลับของ Model — ใช้สตริง `snake_case` ซึ่งสอดคล้องกับชื่อคอลัมน์ใน SQLite และชื่อตัวแปรที่ใช้ในเทมเพลต Jinja2:

```xojo
// Model → Dictionary
row.Value("id")         = rs.Column("id").IntegerValue
row.Value("title")      = rs.Column("title").StringValue
row.Value("created_at") = rs.Column("created_at").StringValue

// ViewModel → context Dictionary for template
Var ctx As New Dictionary()
ctx.Value("notes")      = NoteModel.GetAll()    // Variant() of Dictionary
ctx.Value("page_title") = "All Notes"
ctx.Value("flash")      = ...                   // injected by Render() automatically
```

ในเทมเพลต ชื่อคีย์ `snake_case` เดียวกันจะเข้าถึงได้โดยใช้สัญกรณ์จุด:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

## เมธอดตัวช่วยของ BaseViewModel

เมธอดเหล่านี้พร้อมใช้งานได้เสมอภายในViewModel ใดๆ:

`GetFormValue(key)` — อ่านฟิลด์จากเนื้อหา POST ที่เข้ารหัส URL ทำการแยกวิเคราะห์เนื้อหาแบบเกียจคร่านในครั้งแรกและแคชผลลัพธ์

```xojo
Var title As String = GetFormValue("title")
Var body  As String = GetFormValue("body")
```

`GetParam(key)` — อ่านพารามิเตอร์เส้นทาง URL หรือพารามิเตอร์สตริงการค้นหา พารามิเตอร์เส้นทางมีลำดับความสำคัญเหนือพารามิเตอร์สตริงการค้นหา

```xojo
// For route /notes/:id with URL /notes/42
Var id As Integer = GetParam("id").ToInteger()

// For URL /notes?sort=asc
Var sort As String = GetParam("sort")
```

`Render(templateName, context)` — คอมไพล์และเรนเดอร์เทมเพลต ฉีดข้อความแฟลชโดยอัตโนมัติ และเขียนการตอบสนอง HTML

```xojo
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

`Redirect(url, statusCode)` — ส่งการเปลี่ยนเส้นทาง HTTP สถานะเริ่มต้นคือ 302 ปลอดภัยดูแลให้เรียก `Return` ทันทีหลังจากนี้เพื่อหยุดการเรียกใช้

```xojo
Redirect("/notes")
Return
```

`SetFlash(message, type)` — จัดเก็บข้อความแฟลชในเซสชัน การเรียก `Render()` ครั้งต่อไปบน ViewModel ใดๆ จะฉีดข้อความแฟลชลงในบริบทเทมเพลตโดยอัตโนมัติ ประเภทคือ `"success"`, `"error"`, หรือ `"info"`

```xojo
SetFlash("Note created.", "success")
Redirect("/notes")
Return
```