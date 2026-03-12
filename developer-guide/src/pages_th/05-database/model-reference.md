---
title: "Database Layer Reference"
description: สถาปัตยกรรม DBAdapter / BaseModel / NoteModel แบบสามชั้น — การออกแบบที่มีเหตุผล วงจรชีวิตของการเชื่อมต่อ API CRUD ทั้งหมด และวิธีการเพิ่มทรัพยากรใหม่
---

# Database Layer Reference

## Three-Layer Architecture

ชั้นฐานข้อมูลแยกความรับผิดชอบที่แตกต่างกันสามประการ แต่ละชั้นรู้เพียงเกี่ยวกับชั้นด้านล่างเท่านั้น

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 48
#padding: 10
#lineWidth: 1.5
[DBAdapter: Module|connection factory\nschema init] -> [BaseModel: Class|generic CRUD\nFindAll / FindByID\nInsert / UpdateByID\nDeleteByID]
[BaseModel: Class|generic CRUD\nFindAll / FindByID\nInsert / UpdateByID\nDeleteByID] -> [NoteModel: Class|TableName()\nColumns()\nthin wrappers]
[NoteModel: Class|TableName()\nColumns()\nthin wrappers] -> [<database> SQLite]
-->
<!-- ascii
DBAdapter (Module)
  └─ connection factory, schema init
      │
      ▼
BaseModel (Class)
  └─ generic CRUD: FindAll, FindByID, Insert, UpdateByID, DeleteByID
      │
      ▼
NoteModel (Class)
  └─ TableName(), Columns(), thin wrappers, escape hatch for timestamps
      │
      ▼
SQLite database file
-->
<!-- /diagram -->

การแยกนี้หมายความว่า:

- **ไม่มี boilerplate ในแบบจำลองทรัพยากร** — `NoteModel` มีประมาณ 20 บรรทัด มันประกาศตารางและคอลัมน์ มอบหมายการดำเนินการทั่วไปให้กับ `BaseModel` และเขียน SQL ที่กำหนดเองเมื่อจำเป็นเท่านั้น
- **สถานที่เดียวในการเปลี่ยนตรรกะการเชื่อมต่อ** — การย้ายจาก SQLite ไปยัง PostgreSQL สัมผัส `DBAdapter.Connect()` เท่านั้น
- **ช่องทางหลีกเลี่ยงที่ชัดเจน** — `BaseModel.OpenDB()` ให้การเข้าถึง DB แบบดิบแก่คลาสย่อยโดยไม่ทำลายชั้นทั่วไป

---

## Design Decisions

### เหตุใดจึงส่งคืน `Dictionary` แทนอินสแตนซ์ของแบบจำลอง?

เทมเพลต JinjaX ใช้สัญกรณ์จุด: `{{ note.title }}` เอ็นจิน JinjaX แก้ไขนี้โดยเรียก `dict.Value("title")` บน Xojo `Dictionary` คลาสที่กำหนดเองไม่มีกลไกการประเมินว่าเท่ากัน

```xojo
// Template: {{ note.title }}

// ✅ ทำงาน — Dictionary พอใจสัญกรณ์จุด
ctx.Value("note") = myDictionary        // .Value("title") → "Hello"

// ❌ ไม่ทำงาน — NoteModel ไม่มีการประเมินว่า JinjaX
ctx.Value("note") = myNoteInstance
```

!!! warning
    ทุกวิธีแบบจำลองต้องส่งคืน `Dictionary` หรือ `Variant()` ของ `Dictionary` นี่คือกฎสถาปัตยกรรมที่สำคัญที่สุดในชั้นข้อมูล ไม่สามารถใช้อินสแตนซ์คลาสที่กำหนดเองในเทมเพลต JinjaX ได้

### เหตุใดจึงต้องเชื่อมต่อต่อคำขอ?

Xojo Web จัดการคำขอ HTTP พร้อมกันบนเธรดแยกต่างหาก `SQLiteDatabase` ที่ใช้ร่วมกันทั่วเธรดต้องการการล็อค และมีความเสี่ยงต่อการตายของเธรด

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 40
#padding: 8
#lineWidth: 1.5
[Thread A: GET /notes|DBAdapter.Connect()\nSELECT *\ndb.Close()] -- no conflict -- [Thread B: POST /notes|DBAdapter.Connect()\nINSERT INTO notes\ndb.Close()]
-->
<!-- ascii
Thread A (GET /notes)         Thread B (POST /notes)
  DBAdapter.Connect()           DBAdapter.Connect()
  SELECT * FROM notes           INSERT INTO notes ...
  db.Close()                    db.Close()
       ↑ independent, no conflict ↑
-->
<!-- /diagram -->

การเปิดการเชื่อมต่อใหม่สำหรับแต่ละการโทรนั้นปลอดภัย SQLite overhead สำหรับการเปิดการเชื่อมต่อไฟล์ท้องถิ่นนั้นไม่สำคัญในปริมาณการจราจรของเครื่องมือภายในโดยทั่วไป

---

## Connection Lifecycle

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 30
#padding: 8
#lineWidth: 1.5
[App.Opening|resolve paths\nExecutableFile.Parent] InitDB() -> [DBAdapter.Connect()]
[DBAdapter.Connect()] CREATE TABLE IF NOT EXISTS -> [db.Close()]
[db.Close()] app ready -> [Per-request]
[Per-request] -> [DBAdapter.Connect(): open]
[DBAdapter.Connect(): open] -> [SQL: SELECT / INSERT / UPDATE / DELETE]
[SQL: SELECT / INSERT / UPDATE / DELETE] -> [RowSet → RowToDict()]
[RowSet → RowToDict()] -> [db.Close(): close]
[db.Close(): close] Dictionary -> [ViewModel]
-->
<!-- ascii
App.Opening (once)
  ├── Resolve paths: ExecutableFile.Parent / "data" and / "templates"
  ├── DBAdapter.InitDB()
  │     └── Connect() → CREATE TABLE IF NOT EXISTS ... → db.Close()
  └── JinjaEnvironment(FileSystemLoader(tplDir))

Per-request (concurrent, independent)
  HandleURL → Router → ViewModel → Model method
    └── DBAdapter.Connect()       ← open
    └── SELECT / INSERT / ...     ← execute
    └── RowSet → RowToDict()      ← map to Dictionary
    └── db.Close()                ← close
    └── Return Dictionary         ← to ViewModel → JinjaX → HTML
-->
<!-- /diagram -->

!!! warning
    ทุกเส้นทางของรหัสที่เรียก `Connect()` ต้องเรียก `db.Close()` ก่อนการส่งคืน — รวมถึงเส้นทางข้อผิดพลาด ทุกวิธี `BaseModel` ปิดการเชื่อมต่อในทุกสาขากลับมา

---

## DBAdapter (Module)

**ไฟล์:** `Framework/DBAdapter.xojo_code`

โมดูล — ไม่จำเป็นต้องเป็นอินสแตนซ์ — ที่เป็นเจ้าของโรงงานการเชื่อมต่อและการตั้งค่าสคีมา

### `Connect() As SQLiteDatabase`

เปิดและส่งคืนการเชื่อมต่อใหม่ ผู้เรียกรับผิดชอบต่อ `db.Close()`

ไฟล์ฐานข้อมูลอยู่ในโฟลเดอร์ `data/` **ข้าง ๆ ตัวอักษร** — แก้ไขผ่าน `App.ExecutableFile.Parent` สิ่งนี้ใช้งานเหมือนกันในตัวแก้ไข Xojo และในไบนารีการผลิตที่สร้างขึ้น ไดเรกทอรี `data/` ถูกสร้างขึ้นโดยอัตโนมัติหากไม่มีอยู่

```xojo
Function Connect() As SQLiteDatabase
  // Resolve data/ next to the executable (works in debug and production)
  Var dataDir As FolderItem = App.ExecutableFile.Parent.Child("data")
  If Not dataDir.Exists Then dataDir.CreateAsFolder()

  Var db As New SQLiteDatabase
  db.DatabaseFile = dataDir.Child("notes.sqlite")
  db.Connect()
  Return db
End Function
```

!!! note
    `App.ExecutableFile` คือไบนารีที่ทำงาน — ในตัวแก้ไข Xojo นี่คือสตั บการดีบัก ในการผลิตเป็นแอปที่รวบรวมแล้ว ทั้งสองกรณีแก้ไข `Parent` ไปยังโฟลเดอร์เดียวกัน ดังนั้นเส้นทางจึงมั่นคงในทั่ว ทั้งสภาพแวดล้อม

### `InitDB()`

สร้างตารางทั้งหมดหากไม่มีอยู่ เรียกครั้งหนึ่งจาก `App.Opening` ปลอดภัยในการโทรทุกการเริ่มต้น — `CREATE TABLE IF NOT EXISTS` มีลักษณะเป็นวิธี

หากต้องการเพิ่มตารางใหม่ ให้เพิ่ม `ExecuteSQL` อีกตารางหนึ่งที่นี่ก่อน `db.Close()`

### App.Opening — Startup Paths

`App.Opening` คือสถานที่เดียวที่เชื่อมต่อเส้นทางรันไทม์ทั้งสองก่อนการให้บริการคำขอ:

```xojo
Sub Opening()
  // Templates — resolved relative to executable, same as DB
  Var tplDir As FolderItem = App.ExecutableFile.Parent.Child("templates")
  mJinja = New JinjaEnvironment(New JinjaX.FileSystemLoader(tplDir.NativePath))

  // Database — create schema on first launch
  DBAdapter.InitDB()

  // Router — register all routes
  mRouter = New Router()
  RegisterRoutes()
End Sub
```

ทั้ง `templates/` และ `data/` นั่งข้าง ๆ ตัวอักษร สิ่งนี้หมายความว่าคุณสามารถปรับใช้แอปได้โดยคัดลอกไบนารี่ร่วมกับโฟลเดอร์ทั้งสองนั้น — ไม่มีเส้นทางแบบสัมบูรณ์ ไม่มีตัวแปรสภาพแวดล้อม

---

## BaseModel (Class)

**ไฟล์:** `Framework/BaseModel.xojo_code`

คลาสฐาน CRUD ทั่วไป คลาสย่อยแทนที่วิธีการสองวิธีและสืบทอดการดำเนินการทั้งหมด

### Subclass Contract

| Method | Required | Returns | Purpose |
|--------|----------|---------|---------|
| `TableName() As String` | Yes | `"notes"` | ชื่อตาราง SQL |
| `Columns() As String` | Yes | `"id, title, body, ..."` | รายชื่อคอลัมน์ที่คั่นด้วยจุลภาค สำหรับ `SELECT` |

### CRUD Methods

#### `FindAll(orderBy As String = "") As Variant()`

ส่งคืนแถวทั้งหมดที่เรียงลำดับตาม `orderBy` แต่ละองค์ประกอบเป็น `Dictionary`

```xojo
Var rows() As Variant = model.FindAll("updated_at DESC")
// rows(0) → Dictionary: {"id": "1", "title": "Hello", ...}
```

#### `FindByID(id As Integer) As Dictionary`

ส่งคืนแถวที่ตรงกัน หรือ `Nil` หากไม่พบ ตรวจสอบเสมอก่อนใช้:

```xojo
Var row As Dictionary = model.FindByID(42)
If row Is Nil Then
  RenderError(404, "Not found")
  Return
End If
```

#### `Insert(data As Dictionary) As Integer`

สร้าง `INSERT` ที่มีพารามิเตอร์จากคีย์พจนานุกรม ส่งคืน `ROWID` ใหม่ ปลอดภัยจากการฉีดยาพื้นฐาน SQL — ใช้ `SQLitePreparedStatement`

```xojo
Var data As New Dictionary
data.Value("title") = "My Note"
data.Value("body")  = "Content"
Var newID As Integer = model.Insert(data)
```

!!! note
    `Insert` ไม่สามารถแสดงนิพจน์ SQLite-side เช่น `datetime('now')` — สิ่งเหล่านั้นต้องผ่านช่องทางหลีกเลี่ยง ดูที่ NoteModel ด้านล่าง

#### `UpdateByID(id As Integer, data As Dictionary)`

`UPDATE` ที่มีพารามิเตอร์ `... WHERE id = ?` มีเพียงคีย์ที่อยู่ในพจนานุกรมที่ได้รับการอัปเดต

```xojo
Var data As New Dictionary
data.Value("title") = "New Title"
model.UpdateByID(42, data)
```

#### `DeleteByID(id As Integer)`

```xojo
model.DeleteByID(42)
```

### Protected Escape Hatch Methods

#### `OpenDB() As SQLiteDatabase`

ส่งคืนการเชื่อมต่อแบบดิบสำหรับคลาสย่อยที่ต้องการ SQL ที่กำหนดเอง คลาสย่อยมีหน้าที่ในการ `db.Close()`

ใช้เมื่อ:
- นิพจน์ SQLite (`datetime('now')`, `strftime(...)`) จำเป็นใน SQL — ไม่สามารถเป็นพารามิเตอร์ `?`
- คำค้นหาที่ซับซ้อนด้วย `JOIN`, `GROUP BY`, `HAVING`, หรือแบบสอบถาม
- `db.LastRowID` จำเป็นหลังจาก `INSERT`
- คำสั่งหลายรายการต้องแชร์การเชื่อมต่อหนึ่งรายการ

#### `RowToDict(rs As RowSet) As Dictionary`

แมปแถว RowSet ปัจจุบันไปยัง `Dictionary` โดยใช้ชื่อคอลัมน์จาก `Columns()` ค่าทั้งหมดจะเก็บเป็น `StringValue` — ตั้งใจ JinjaX แสดงผลทุกอย่างเป็นสตริง ViewModels หล่อให้เป็นจำนวนเต็มผ่าน `Val()` เมื่อจำเป็น

---

## NoteModel (Class)

**ไฟล์:** `Models/NoteModel.xojo_code`

แบบจำลองทรัพยากรที่เป็นรูปธรรม วิธีทั้งหมดต้องการพารามิเตอร์ `userID` เพื่อสโคป notes ต่อผู้ใช้ — แต่ละผู้ใช้สามารถดูและแก้ไขบันทึกของตนเองเท่านั้น

```xojo
Protected Class NoteModel
Inherits BaseModel

  Protected Function TableName() As String
    Return "notes"
  End Function

  Protected Function Columns() As String
    Return "id, title, body, created_at, updated_at, user_id"
  End Function

  // All methods require userID for per-user scoping
  Function GetAll(userID As Integer) As Variant()
    Var results() As Variant
    Var db As SQLiteDatabase = OpenDB()
    Var rs As RowSet = db.SelectSQL( _
      "SELECT " + Columns() + " FROM notes WHERE user_id = ? ORDER BY updated_at DESC", userID)
    While Not rs.AfterLastRow
      results.Add(RowToDict(rs))
      rs.MoveToNextRow()
    Wend
    rs.Close()
    db.Close()
    Return results
  End Function

  Function GetByID(id As Integer, userID As Integer) As Dictionary
    Var db As SQLiteDatabase = OpenDB()
    Var rs As RowSet = db.SelectSQL( _
      "SELECT " + Columns() + " FROM notes WHERE id = ? AND user_id = ?", id, userID)
    If rs.AfterLastRow Then
      rs.Close()
      db.Close()
      Return Nil
    End If
    Var row As Dictionary = RowToDict(rs)
    rs.Close()
    db.Close()
    Return row
  End Function

  Function Create(title As String, body As String, userID As Integer) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)", title, body, userID)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Update(id As Integer, title As String, body As String, userID As Integer)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL( _
      "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') " + _
      "WHERE id = ? AND user_id = ?", title, body, id, userID)
    db.Close()
  End Sub

  Sub Delete(id As Integer, userID As Integer)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("DELETE FROM notes WHERE id = ? AND user_id = ?", id, userID)
    db.Close()
  End Sub

  Function CountForUser(userID As Integer) As Integer
    Var db As SQLiteDatabase = OpenDB()
    Var rs As RowSet = db.SelectSQL( _
      "SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ?", userID)
    Var count As Integer = rs.Column("cnt").IntegerValue
    rs.Close()
    db.Close()
    Return count
  End Function

End Class
```

`Create` และ `Update` ใช้ช่องทางหลีกเลี่ยงเนื่องจาก `datetime('now')` เป็นนิพจน์ที่ประเมินโดย SQLite — การผูกมัดสตริง `"datetime('now')"` เป็นพารามิเตอร์ `?` จะเก็บข้อความตามตัวอักษร ไม่ใช่ timestamp

ทุกแบบสอบถามรวม `WHERE user_id = ?` เพื่อบังคับให้เป็นเจ้าของที่ระดับ SQL ดูสถานที่ [Protected Routes & User Scoping](../protected-routes/index.html) สำหรับรูปแบบเต็ม

---

## CRUD Task Mapping

เส้นทางหมายเหตุทั้งหมดต้องการการรับรองความถูกต้อง ทุกการเรียก model รวม `userID` เพื่อสโคปข้อมูลต่อผู้ใช้

| User action | HTTP | ViewModel | Model call | SQL |
|-------------|------|-----------|------------|-----|
| View list | `GET /notes` | `NotesListVM` | `NoteModel.GetAll(userID)` | `SELECT … WHERE user_id = ? ORDER BY updated_at DESC` |
| View one | `GET /notes/:id` | `NotesDetailVM` | `NoteModel.GetByID(id, userID)` | `SELECT … WHERE id = ? AND user_id = ?` |
| New form | `GET /notes/new` | `NotesNewVM` | — | — |
| Create | `POST /notes` | `NotesCreateVM` | `NoteModel.Create(title, body, userID)` | `INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)` |
| Edit form | `GET /notes/:id/edit` | `NotesEditVM` | `NoteModel.GetByID(id, userID)` | `SELECT … WHERE id = ? AND user_id = ?` |
| Update | `POST /notes/:id` | `NotesUpdateVM` | `NoteModel.Update(id, title, body, userID)` | `UPDATE notes SET … WHERE id = ? AND user_id = ?` |
| Delete | `POST /notes/:id/delete` | `NotesDeleteVM` | `NoteModel.Delete(id, userID)` | `DELETE FROM notes WHERE id = ? AND user_id = ?` |

---

## Benefits and Trade-offs

| Benefit | Why |
|---------|-----|
| No boilerplate | ทรัพยากรใหม่ต้อง `TableName()` + `Columns()` + thin wrappers เท่านั้น |
| SQL injection safe | ค่า user ทั้งหมดไปผ่านการผูกมัดพารามิเตอร์ `?` |
| Thread-safe | การเชื่อมต่อต่อคำขอ — ไม่มีสถานะที่เปลี่ยนแปลงได้ร่วมกัน |
| JinjaX compatible | ผลลัพธ์ทั้งหมดเป็น `Dictionary` — เทมเพลตทำงานทันที |
| Testable | การทดสอบ XojoUnit ตีฐานข้อมูล SQLite จริง overhead ไม่สำคัญ |
| Clear escape hatch | `OpenDB()` ได้รับการจัดทำเอกสารและตั้งใจ ไม่ใช่วิธีแก้ปัญหาชั่วคราว |

| Trade-off | Impact |
|-----------|--------|
| No ORM features | ไม่มีความสัมพันธ์ lazy loading หรือการติดตามการเปลี่ยนแปลง |
| String-only values | `RowToDict` เก็บทุกอย่างเป็น `StringValue` ViewModels ต้องหล่อผ่าน `Val()` |
| No migration system | การเปลี่ยนแปลงสคีมาต้องใช้ `ALTER TABLE` คู่มือหรือสร้างฐานข้อมูลขึ้นใหม่ในเดฟ |
| `datetime` limitation | `BaseModel.Insert` ไม่สามารถใช้ `DEFAULT (datetime('now'))` — ใช้ช่องทางหลีกเลี่ยง |

### When to use inherited CRUD vs the escape hatch

ใช้วิธีการ `BaseModel` ที่สืบทอดมาเมื่อการดำเนินการเป็นเพียง `SELECT`, `INSERT`, `UPDATE`, หรือ `DELETE` ที่มีค่าผูกมัดธรรมชาติ

ใช้ `OpenDB()` เมื่อคุณต้องการนิพจน์ SQLite (`datetime('now')`, `strftime(...)`), คำค้นหาที่ซับซ้อน (`JOIN`, `GROUP BY`, แบบสอบถาม), `db.LastRowID` หลังจากการแทรกที่กำหนดเอง หรือคำสั่งหลายรายการในการเชื่อมต่อหนึ่งรายการ

---

## Adding a New Resource

การเพิ่ม `TagModel` เป็นตัวอย่างที่สมบูรณ์:

**1. สร้าง `Models/TagModel.xojo_code`:**

```xojo
Protected Class TagModel
Inherits BaseModel

  Protected Function TableName() As String
    Return "tags"
  End Function

  Protected Function Columns() As String
    Return "id, name, created_at"
  End Function

  Function GetAll() As Variant()
    Return FindAll("name ASC")
  End Function

  Function GetByID(id As Integer) As Dictionary
    Return FindByID(id)
  End Function

  Function Create(name As String) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO tags (name) VALUES (?)", name)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Delete(id As Integer)
    DeleteByID(id)
  End Sub

End Class
```

**2. เพิ่มตารางไปยัง `DBAdapter.InitDB()`:**

```xojo
db.ExecuteSQL( _
  "CREATE TABLE IF NOT EXISTS tags (" + _
  "id         INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name       TEXT NOT NULL, " + _
  "created_at TEXT DEFAULT (datetime('now')))")
```

**3. ลงทะเบียน** `Models/TagModel.xojo_code` ใน `mvvm.xojo_project` ภายใต้โฟลเดอร์ Models (Xojo IDE: ลากไฟล์ลงในแผง project)

**4. สร้าง ViewModels** ใน `ViewModels/Tags/` และ **templates** ใน `templates/tags/` ตามรูปแบบเดียวกับ `Notes`