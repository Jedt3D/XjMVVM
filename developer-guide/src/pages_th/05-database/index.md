---
title: SQLite และสัญญา Dictionary
description: วิธีการทำงานกับ SQLite แปลง RowSet เป็น Dictionary และเขียนคลาส Model ที่ปลอดภัยจากเธรด
---

# SQLite และสัญญา Dictionary

## รูปแบบหลัก

ทุกเมธอด Model ปฏิบัติตามรูปแบบเดียวกัน: เปิดการเชื่อมต่อฐานข้อมูลใหม่ เรียกใช้การค้นหา แปลงแต่ละแถว `RowSet` เป็น `Dictionary` ปิดทุกสิ่ง คืนค่า

รูปแบบนี้มีจงใจ — มันรับประกันความปลอดภัยเธรดและบังคับใช้สัญญาข้อมูล Dictionary ที่ JinjaX ต้องการ

```xojo
Function GetAll() As Variant()
  Var results() As Variant
  Var db As SQLiteDatabase = OpenDB()

  Var rs As RowSet = db.SelectSQL(
    "SELECT id, title, body, created_at, updated_at FROM notes ORDER BY updated_at DESC"
  )

  While Not rs.AfterLastRow
    Var row As New Dictionary()
    row.Value("id")         = rs.Column("id").IntegerValue
    row.Value("title")      = rs.Column("title").StringValue
    row.Value("body")       = rs.Column("body").StringValue
    row.Value("created_at") = rs.Column("created_at").StringValue
    row.Value("updated_at") = rs.Column("updated_at").StringValue
    results.Add(row)
    rs.MoveToNextRow()
  Wend

  rs.Close()
  db.Close()
  Return results
End Function
```

ประเภทการคืน `Variant()` ที่มีอ็อบเจ็กต์ `Dictionary` เป็นรูปแบบเพียงอย่างเดียวที่ JinjaX สามารถวนซ้ำได้ในลูป `{% for %}`

## ประเภทการคืน

| การดำเนินการ | ประเภทการคืน | กรณี Nil |
|---|---|---|
| แถวหลายแถว | `Variant()` (ของ `Dictionary`) | อาร์เรย์ว่าง `()` |
| แถวเดียว | `Dictionary` | `Nil` |
| สร้าง | `Integer` (ID แถวใหม่) | — |
| อัปเดต / ลบ | `Sub` (ไม่มี) | — |

เสมอตรวจสอบ `Nil` เมื่อดึงแถวเดียว:

```xojo
// ใน ViewModel
Var note As Dictionary = NoteModel.GetByID(id)
If note = Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

## การเชื่อมต่อฐานข้อมูลต่อคำขอ

เมธอด `OpenDB()` ส่วนตัวเปิด **ใหม่** การเชื่อมต่อในการเรียกแต่ละครั้ง ไม่มีการเชื่อมต่อฐานข้อมูลแบบใช้ร่วมกันที่มีอายุยาวนาน ใน `App`

```xojo
Private Function OpenDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile
  db.Connect()
  Return db
End Function
```

**ทำไมต่อคำขอ?** Xojo จัดการคำขอพร้อมกันในหลายเธรด อ็อบเจ็กต์ `SQLiteDatabase` ที่ใช้ร่วมกันจะต้องใช้ mutex การเปิดการเชื่อมต่อใหม่ต่อคำขอนั้นง่ายกว่าและหลีกเลี่ยงความซับซ้อนในการล็อกทั้งหมด — SQLite จัดการการเชื่อมต่อการอ่านพร้อมกันจากกระบวนการหลายตัวโดยเนื้อแท้

**ทำไมไม่ pool การเชื่อมต่อ?** สำหรับปริมาณการจราจรที่เฟรมเวิร์กนี้ลำเป้า (ทีมเล็ก ๆ เครื่องมือภายใน) ค่าใช้จ่ายในการเปิดการเชื่อมต่อไม่มีนัยสำคัญ pool เพิ่มความซับซ้อนโดยไม่มีประโยชน์ที่วัดได้ในขนาดนี้

## การเตรียมฐานข้อมูล

วิธีแรกที่เรียกใช้เมื่อแอปเริ่มต้นคือ `NoteModel.InitDB()` (จาก `App.Opening()`) มันสร้างไฟล์ฐานข้อมูลและเรียก `CREATE TABLE IF NOT EXISTS`:

```xojo
Shared Function InitDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile

  If Not dbFile.Exists Then
    db.CreateDatabase()   // สร้างไฟล์
  Else
    db.Connect()
  End If

  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS notes (" + _
    "id          INTEGER PRIMARY KEY AUTOINCREMENT, " + _
    "title       TEXT NOT NULL, " + _
    "body        TEXT, " + _
    "created_at  TEXT DEFAULT (datetime('now')), " + _
    "updated_at  TEXT DEFAULT (datetime('now')))")

  Return db
End Function
```

มันปลอดภัยในการโทรทุกครั้งที่เริ่มต้น — `IF NOT EXISTS` เป็นแบบฉันทามติ

## การค้นหาแบบพารามีเตอร์

เสมอใช้ตัวยึดตำแหน่ง `?` สำหรับค่า ไม่เคยต่อเนื่องสตริง SQL ด้วยข้อมูลป้อนผู้ใช้ — สิ่งนี้ป้องกันการฉีด SQL:

```xojo
// ✅ ถูก — มีพารามิเตอร์
db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
db.SelectSQL("SELECT * FROM notes WHERE id = ?", id)

// ❌ ผิด — ความเสี่ยงการฉีด SQL
db.ExecuteSQL("INSERT INTO notes (title) VALUES ('" + title + "')")
```

`SelectSQL()` และ `ExecuteSQL()` ยอมรับพารามิเตอร์ `Variant` variadic หลังสตริง SQL

## การได้รับ ID แถวที่แทรกสุดท้าย

หลังจาก `INSERT` ดึง ID ของแถวใหม่โดยใช้ `db.LastRowID`:

```xojo
Function Create(title As String, body As String) As Integer
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function
```

ViewModel ใช้ ID นี้เพื่อเปลี่ยนเส้นทางไปยังหน้ารายละเอียดบันทึกใหม่:

```xojo
// ใน NotesCreateVM.OnPost()
Var newID As Integer = NoteModel.Create(title, body)
SetFlash("Note created.", "success")
Redirect("/notes/" + Str(newID))
```

## ประเภทคอลัมน์

SQLite ที่พิมพ์แบบไดนามิก ตัวเข้าถึงคอลัมน์ `RowSet` ของ Xojo แปลงค่าเมื่ออ่าน:

| ตัวเข้าถึง | ใช้สำหรับ |
|---|---|
| `.StringValue` | คอลัมน์ `TEXT` ID (ค่าเริ่มต้นที่ปลอดภัย) |
| `.IntegerValue` | คอลัมน์ `INTEGER` |
| `.DoubleValue` | คอลัมน์ `REAL` |
| `.BooleanValue` | `INTEGER` 0/1 เก็บเป็นบูลีน |

เก็บวันที่ทั้งหมดเป็น `TEXT` โดยใช้ฟังก์ชัน `datetime()` ของ SQLite ดึงและแสดงเป็นสตริง — จัดรูปแบบในเทมเพลตหรือ ViewModel ตามต้องการ

## เส้นทางฐานข้อมูลสำหรับการผลิต

การใช้งานปัจจุบันเข้ารหัสเส้นทางสำหรับการพัฒนา สำหรับบิลด์โปรดักชัน ให้ใช้ `SpecialFolder.ApplicationData`:

```xojo
// การพัฒนา (เข้ารหัส — ดีสำหรับการรันดีบัต IDE)
Const DB_PATH = "/Users/worajedt/Xojo Projects/mvvm/data/notes.sqlite"

// โปรดักชัน (วิธีการที่ถูกต้อง)
Function ProductionDBPath() As String
  Var appData As FolderItem = SpecialFolder.ApplicationData
  Var appDir As FolderItem = appData.Child("mvvm")
  If Not appDir.Exists Then appDir.CreateDirectory()
  Return appDir.Child("notes.sqlite").NativePath
End Function
```

ใช้ค่าคงที่ build หรือค่ากำหนดเพื่อสลับระหว่างเส้นทางการพัฒนาและการผลิต
