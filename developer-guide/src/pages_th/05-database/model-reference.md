---
title: "อ้างอิงชั้นฐานข้อมูล"
description: สถาปัตยกรรมสามชั้นของ DBAdapter / BaseModel / NoteModel — เหตุผลในการออกแบบ วงจรชีวิตการเชื่อมต่อ API CRUD ที่สมบูรณ์ และวิธีการเพิ่มทรัพยากรใหม่
---

# อ้างอิงชั้นฐานข้อมูล

## สถาปัตยกรรมสามชั้น

ชั้นฐานข้อมูลแยกความรับผิดชอบที่แตกต่างกันสามประการ แต่ละชั้นรู้เพียงเกี่ยวกับชั้นด้านล่าง

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

- **ไม่มี boilerplate ในรูปแบบทรัพยากร** — `NoteModel` ประมาณ 20 บรรทัด ประกาศตารางและคอลัมน์ มอบหมายการดำเนินการทั่วไปให้ `BaseModel` และเขียนเฉพาะ SQL แบบกำหนดเองเมื่อจำเป็น
- **สถานที่เดียวเพื่อเปลี่ยนลอจิกการเชื่อมต่อ** — การย้ายจาก SQLite ไปยัง PostgreSQL สัมผัสเพียง `DBAdapter.Connect()` เท่านั้น
- **หลัก escape ที่ชัดเจน** — `BaseModel.OpenDB()` ให้ subclasses การเข้าถึง DB ดิบโดยไม่ทำลายชั้นทั่วไป

---

## การตัดสินใจในการออกแบบ

### เหตุใดจึงส่งคืน `Dictionary` แทนอินสแตนซ์โมเดล?

เทมเพลต JinjaX ใช้สัญกรณ์จุด: `{{ note.title }}` เครื่องยนต์ JinjaX แก้ไขนี้โดยเรียก `dict.Value("title")` บน Xojo `Dictionary` อินสแตนซ์คลาสกำหนดเองไม่มีกลไกการ introspection ที่เทียบเท่า

```xojo
// Template: {{ note.title }}

// ✅ Works — Dictionary satisfies dot-notation
ctx.Value("note") = myDictionary        // .Value("title") → "Hello"

// ❌ Does NOT work — NoteModel has no JinjaX introspection
ctx.Value("note") = myNoteInstance
```

!!! warning
    ทุกวิธี model ต้องส่งคืน `Dictionary` หรือ `Variant()` ของ `Dictionary` นี่คือกฎสถาปัตยกรรมที่สำคัญที่สุดในชั้นข้อมูล อินสแตนซ์คลาสกำหนดเองไม่สามารถใช้ในเทมเพลต JinjaX ได้

### เหตุใดการเชื่อมต่อครั้งเดียวต่อคำขอ?

Xojo Web จัดการคำขอ HTTP พร้อมกันบนเธรดแยกต่างหาก `SQLiteDatabase` ที่ใช้ร่วมกันข้ามเธรดต้องการการล็อกและความเสี่ยงจากการล็อค

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

การเปิดการเชื่อมต่อใหม่ต่อการเรียกนั้นปลอดภัย การหยุด SQLite สำหรับการเปิดการเชื่อมต่อไฟล์ท้องถิ่นนั้นไม่สำคัญที่ปริมาณการจราจร interna

l ทั่วไป

---

## วงจรชีวิตการเชื่อมต่อ

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
    ทุกเส้นโค้ดที่เรียก `Connect()` ต้องเรียก `db.Close()` ก่อนการส่งคืน — รวมถึงเส้นทางข้อผิดพลาด ทั้งหมด `BaseModel` วิธีปิดการเชื่อมต่อในทุกสาขา return

---

## DBAdapter (โมดูล)

**ไฟล์:** `Framework/DBAdapter.xojo_code`

โมดูล — ไม่จำเป็นต้องสร้างอินสแตนซ์ — ที่เป็นเจ้าของโรงงานการเชื่อมต่อและการตั้งค่าสคีมา

### `Connect() As SQLiteDatabase`

เปิดและส่งคืนการเชื่อมต่อใหม่ ผู้โทรรับผิดชอบในการ `db.Close()`

ไฟล์ฐานข้อมูลอาศัยอยู่ในโฟลเดอร์ `data/` **ถัดจากไฟล์ที่ดำเนินการ** — แก้ไขผ่าน `App.ExecutableFile.Parent` นี่ทำงานเหมือนกันในตัวดีบั๊ก Xojo และในไฟล์ฐานข้อมูลที่สร้าง โดยไฟล์ฐานข้อมูล โฟลเดอร์ `data/` ถูกสร้างขึ้นโดยอัตโนมัติหากไม่มีอยู่

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
    `App.ExecutableFile` คือไฟล์ที่ดำเนินการ — ในตัวดีบั๊ก Xojo นี่คือ stub ดีบั๊ก ในการผลิตมันคือแอปพลิเคชันที่รวบรวมแล้ว ทั้งสองกรณีแก้ไข `Parent` ไปยังโฟลเดอร์เดียวกัน ดังนั้นเส้นทางจึงเสถียรข้ามสภาพแวดล้อม

### `InitDB()`

สร้างตารางทั้งหมดหากไม่มี เรียกครั้งเดียวจาก `App.Opening` ปลอดภัยเรียกในทุกการเริ่มต้น — `CREATE TABLE IF NOT EXISTS` คือ idempotent

เพื่อเพิ่มตารางใหม่ ให้เพิ่ม `ExecuteSQL` อื่น ๆ ที่นี่ก่อน `db.Close()`

### App.Opening — เส้นทางการเริ่มต้น

`App.Opening` คือสถานที่เดียวที่ทำงาน runtime paths ทั้งสองก่อนเสิร์ฟคำขอใด ๆ:

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

ทั้ง `templates/` และ `data/` นั่งข้างเคียงไฟล์ที่ดำเนินการ ซึ่งหมายความว่าคุณสามารถปรับใช้แอปพลิเคชันโดยการคัดลอกไฟล์ฐานข้อมูลพร้อมกับโฟลเดอร์สองโฟลเดอร์เหล่านั้น — ไม่มีเส้นทางแบบสัมบูรณ์ ไม่มีตัวแปรสภาพแวดล้อมที่ต้องการ

---

## BaseModel (คลาส)

**ไฟล์:** `Framework/BaseModel.xojo_code`

คลาส CRUD ทั่วไป Subclasses แทนวิธีสองวิธีและสืบทอดการดำเนินการทั้งหมด

### สัญญา Subclass

| วิธี | ต้องการ | ส่งคืน | วัตถุประสงค์ |
|--------|----------|---------|---------|
| `TableName() As String` | ใช่ | `"notes"` | ชื่อตาราง SQL |
| `Columns() As String` | ใช่ | `"id, title, body, ..."` | รายการคอลัมน์คั่นด้วยเครื่องหมายจุลภาคสำหรับ `SELECT` |

### วิธี CRUD

#### `FindAll(orderBy As String = "") As Variant()`

ส่งคืนทุกแถวเรียงลำดับตาม `orderBy` แต่ละองค์ประกอบคือ `Dictionary`

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

สร้าง parameterized `INSERT` จากคีย์ Dictionary ส่งคืน `ROWID` ใหม่ SQL injection safe — ใช้ `SQLitePreparedStatement`

```xojo
Var data As New Dictionary
data.Value("title") = "My Note"
data.Value("body")  = "Content"
Var newID As Integer = model.Insert(data)
```

!!! note
    `Insert` ไม่สามารถแสดง SQLite-side expression เช่น `datetime('now')` — สิ่งเหล่านั้นต้องผ่าน escape hatch ดูที่ NoteModel ด้านล่าง

#### `UpdateByID(id As Integer, data As Dictionary)`

Parameterized `UPDATE ... WHERE id = ?` เฉพาะคีย์ที่มีอยู่ใน Dictionary จะถูกอัพเดต

```xojo
Var data As New Dictionary
data.Value("title") = "New Title"
model.UpdateByID(42, data)
```

#### `DeleteByID(id As Integer)`

```xojo
model.DeleteByID(42)
```

### วิธี Escape Hatch ที่ป้องกัน

#### `OpenDB() As SQLiteDatabase`

ส่งคืนการเชื่อมต่อดิบสำหรับ subclasses ที่ต้องการ SQL ที่กำหนดเอง Subclass รับผิดชอบ `db.Close()`

ใช้เมื่อ:
- SQLite expressions (`datetime('now')` `strftime(...)`) จำเป็นใน SQL — พวกเขาไม่สามารถเป็นพารามิเตอร์ `?` ได้
- คำค้นหาที่ซับซ้อนด้วย `JOIN` `GROUP BY` `HAVING` หรือ subqueries
- `db.LastRowID` จำเป็นหลังจาก `INSERT`
- หลายคำสั่งต้องแบ่งการเชื่อมต่อเดียว

#### `RowToDict(rs As RowSet) As Dictionary`

แม็ป RowSet row ปัจจุบันไป `Dictionary` โดยใช้ชื่อคอลัมน์จาก `Columns()` ค่าทั้งหมดถูกเก็บเป็น `StringValue` — เจตนา JinjaX ให้อปัญหาทุกอย่างเป็นสตริง ViewModels แปลงเป็นจำนวนเต็มผ่าน `Val()` เมื่อจำเป็น

---

## NoteModel (คลาส)

**ไฟล์:** `Models/NoteModel.xojo_code`

รูปแบบทรัพยากรที่เป็นรูปธรรม เพียง ~20 บรรทัดเพราะ `BaseModel` จัดการทุกอย่างแบบทั่วไป

```xojo
Protected Class NoteModel
Inherits BaseModel

  Protected Function TableName() As String
    Return "notes"
  End Function

  Protected Function Columns() As String
    Return "id, title, body, created_at, updated_at"
  End Function

  // Delegation — zero boilerplate
  Function GetAll() As Variant()
    Return FindAll("updated_at DESC")
  End Function

  Function GetByID(id As Integer) As Dictionary
    Return FindByID(id)
  End Function

  Sub Delete(id As Integer)
    DeleteByID(id)
  End Sub

  // Escape hatch — SQLite expressions required for timestamps
  Function Create(title As String, body As String) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Update(id As Integer, title As String, body As String)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL( _
      "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?", _
      title, body, id)
    db.Close()
  End Sub

End Class
```

`Create` และ `Update` ใช้ escape hatch เพราะ `datetime('now')` คือนิพจน์ SQLite-evaluated — binding สตริง `"datetime('now')"` เป็นพารามิเตอร์ `?` จะเก็บข้อความตามตัวอักษร ไม่ใช่ timestamp

---

## การแมป CRUD Task

| การกระทำของผู้ใช้ | HTTP | ViewModel | การเรียก Model | SQL |
|-------------|------|-----------|------------|-----|
| ดูรายการ | `GET /notes` | `NotesListVM` | `NoteModel.GetAll()` | `SELECT … ORDER BY updated_at DESC` |
| ดูหนึ่ง | `GET /notes/:id` | `NotesDetailVM` | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| ฟอร์มใหม่ | `GET /notes/new` | `NotesNewVM` | — | — |
| สร้าง | `POST /notes` | `NotesCreateVM` | `NoteModel.Create(title, body)` | `INSERT INTO notes (title, body) VALUES (?, ?)` |
| ฟอร์มแก้ไข | `GET /notes/:id/edit` | `NotesEditVM` | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| อัพเดต | `POST /notes/:id` | `NotesUpdateVM` | `NoteModel.Update(id, title, body)` | `UPDATE notes SET … WHERE id = ?` |
| ลบ | `POST /notes/:id/delete` | `NotesDeleteVM` | `NoteModel.Delete(id)` | `DELETE FROM notes WHERE id = ?` |

---

## ประโยชน์และข้อแลกเปลี่ยน

| ประโยชน์ | เหตุผล |
|---------|-----|
| ไม่มี boilerplate | ทรัพยากรใหม่ต้องเพียง `TableName()` + `Columns()` + thin wrappers เท่านั้น |
| SQL injection safe | ค่าผู้ใช้ทั้งหมดผ่าน `?` parameter binding |
| Thread-safe | การเชื่อมต่อต่อ request — ไม่มี shared mutable state |
| JinjaX compatible | ผลลัพธ์ทั้งหมดคือ `Dictionary` — เทมเพลตใช้งานได้ทันที |
| Testable | XojoUnit tests ชน SQLite DB ที่แท้จริง negligible overhead |
| Clear escape hatch | `OpenDB()` ถูกบันทึกและเจตนา ไม่ใช่ workaround |

| ข้อแลกเปลี่ยน | ผลกระทบ |
|-----------|--------|
| ไม่มี ORM features | ไม่มี associations lazy loading หรือ change tracking |
| String-only values | `RowToDict` เก็บทุกอย่างเป็น `StringValue` ViewModels ต้องแปลงผ่าน `Val()` |
| ไม่มีระบบการย้ายข้อมูล | การเปลี่ยนสคีมาต้องใช้ `ALTER TABLE` ด้วยตนเองหรือสร้างโครงฐานข้อมูลใหม่ใน dev |
| `datetime` limitation | `BaseModel.Insert` ไม่สามารถใช้ `DEFAULT (datetime('now'))` — ใช้ escape hatch |

### เมื่อใดที่จะใช้ CRUD สืบทอดเทียบกับ escape hatch

ใช้วิธี `BaseModel` สืบทอดเมื่อการดำเนินการเป็นเพียง `SELECT` `INSERT` `UPDATE` หรือ `DELETE` ธรรมดาด้วยค่าที่ผูก

ใช้ `OpenDB()` เมื่อคุณต้องการ SQLite expressions (`datetime('now')` `strftime(...)`) คำค้นหาที่ซับซ้อนด้วย (`JOIN` `GROUP BY` subqueries) `db.LastRowID` หลังจากการแทรกแบบกำหนดเอง หรือหลายคำสั่งต้องแบ่งการเชื่อมต่อเดียว

---

## การเพิ่มทรัพยากรใหม่

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

**3. ลงทะเบียน** `Models/TagModel.xojo_code` ใน `mvvm.xojo_project` ภายใต้โฟลเดอร์ Models (Xojo IDE: ลากไฟล์เข้าไปในแผงโครงการ)

**4. สร้าง ViewModels** ใน `ViewModels/Tags/` และ **เทมเพลต** ใน `templates/tags/` ตามรูปแบบเดียวกันกับ `Notes`
