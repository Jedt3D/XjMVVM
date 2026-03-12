---
title: SQLite & Dictionary Contract
description: วิธีการทำงานกับ SQLite แปลง RowSet เป็น Dictionary และเขียน Model classes ที่ปลอดภัยสำหรับหลายเธรด
---

# SQLite & Dictionary Contract

## The core pattern

ทุก Model method ยึดตามรูปแบบเดียวกัน: เปิด database connection ใหม่ รันคำสั่ง query แปลง `RowSet` แต่ละแถวเป็น `Dictionary` ปิดทุกอย่าง คืนค่า

รูปแบบนี้ตั้งใจออกแบบเพื่อให้มั่นใจว่าปลอดภัยสำหรับหลายเธรด และบังคับใช้ Dictionary data contract ที่ JinjaX ต้องการ

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

Return type `Variant()` ที่บรรจุ `Dictionary` objects เป็นรูปแบบเดียวที่ JinjaX สามารถวนลูปใน `{% for %}` ได้

## Return types

| Operation | Return type | Nil case |
|---|---|---|
| Multiple rows | `Variant()` (of `Dictionary`) | Empty array `()` |
| Single row | `Dictionary` | `Nil` |
| Create | `Integer` (new row ID) | — |
| Update / Delete | `Sub` (nothing) | — |

ตรวจสอบ `Nil` เสมอเมื่อดึงแถวเดียว:

```xojo
// In the ViewModel
Var note As Dictionary = NoteModel.GetByID(id)
If note = Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

## Per-request database connections

Method `OpenDB()` private เปิด connection **ใหม่** ทุกครั้งที่เรียก ไม่มี database connection ร่วมกันแบบยาวนาน บน `App`

```xojo
Private Function OpenDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile
  db.Connect()
  Return db
End Function
```

**ทำไม per-request?** Xojo จัดการคำขอพร้อมกันบนหลายเธรด SQLiteDatabase instance ร่วมกันต้องใช้ mutex การเปิด connection ใหม่ต่อคำขอนั้นง่ายกว่าและหลีกเลี่ยงความซับซ้อนในการล็อค — SQLite จัดการการเชื่อมต่อแบบอ่านพร้อมกันจากหลายกระบวนการเองได้

**ทำไมไม่ connection pool?** สำหรับปริมาณการใช้งานที่ framework นี้เป้าหมาย (ทีมเล็ก internal tools) overhead ของการเปิด connection นั้นน้อยมาก pool เพิ่มความซับซ้อนโดยไม่มีประโยชน์ที่สังเกตเห็นได้ในระดับนี้

## Database initialization

Method แรกที่เรียกเมื่อแอปเริ่มต้นคือ `NoteModel.InitDB()` (จาก `App.Opening()`) มันสร้างไฟล์ database และรัน `CREATE TABLE IF NOT EXISTS`:

```xojo
Shared Function InitDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile

  If Not dbFile.Exists Then
    db.CreateDatabase()   // Creates the file
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

ปลอดภัยที่จะเรียกทุกครั้งเริ่มต้น — `IF NOT EXISTS` นั้น idempotent

## Parameterized queries

ใช้ `?` placeholders สำหรับค่าเสมอ ห้ามต่อ user input เข้าไปใน SQL strings — สิ่งนี้ป้องกัน SQL injection:

```xojo
// ✅ Correct — parameterized
db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
db.SelectSQL("SELECT * FROM notes WHERE id = ?", id)

// ❌ Wrong — SQL injection risk
db.ExecuteSQL("INSERT INTO notes (title) VALUES ('" + title + "')")
```

`SelectSQL()` และ `ExecuteSQL()` ยอมรับ variadic `Variant` parameters หลังจาก SQL string

## Getting the last inserted row ID

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

ViewModel ใช้ ID นี้เพื่อ redirect ไปยังหน้ารายละเอียดของ note ใหม่:

```xojo
// In NotesCreateVM.OnPost()
Var newID As Integer = NoteModel.Create(title, body)
SetFlash("Note created.", "success")
Redirect("/notes/" + Str(newID))
```

## Column types

SQLite เป็น dynamically typed Xojo's `RowSet` column accessors แปลงค่าเมื่ออ่าน:

| Accessor | Use for |
|---|---|
| `.StringValue` | `TEXT` columns, IDs (safe default) |
| `.IntegerValue` | `INTEGER` columns |
| `.DoubleValue` | `REAL` columns |
| `.BooleanValue` | `INTEGER` 0/1 stored as boolean |

เก็บวันที่ทั้งหมดเป็น `TEXT` โดยใช้ SQLite's `datetime()` function ดึงและแสดงผลเป็นสตริง — format ในเทมเพลตหรือ ViewModel ตามความต้องการ

## Database path for production

Implementation ปัจจุบัน hardcode path สำหรับ development ในสำหรับ production builds ใช้ `SpecialFolder.ApplicationData`:

```xojo
// Development (hardcoded — fine for IDE debug runs)
Const DB_PATH = "/Users/worajedt/Xojo Projects/mvvm/data/notes.sqlite"

// Production (correct approach)
Function ProductionDBPath() As String
  Var appData As FolderItem = SpecialFolder.ApplicationData
  Var appDir As FolderItem = appData.Child("mvvm")
  If Not appDir.Exists Then appDir.CreateDirectory()
  Return appDir.Child("notes.sqlite").NativePath
End Function
```

ใช้ build constant หรือ preference เพื่อสลับระหว่าง development และ production paths