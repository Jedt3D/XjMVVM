---
title: "การอ้างอิงเลเยอร์ฐานข้อมูล"
description: สถาปัตยกรรม DBAdapter / BaseModel / NoteModel สามชั้น — เหตุผลการออกแบบ วงจรชีวิตของการเชื่อมต่อ API CRUD ที่สมบูรณ์ และวิธีการเพิ่มทรัพยากรใหม่
---

# การอ้างอิงเลเยอร์ฐานข้อมูล

## สถาปัตยกรรมสามชั้น

เลเยอร์ฐานข้อมูลแบ่งความรับผิดชอบออกเป็นสามส่วน แต่ละชั้นรู้เฉพาะชั้นที่อยู่ด้านล่างเท่านั้น

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

การแบ่งนี้มีความหมายดังนี้:

- **ไม่มี boilerplate ในรูปแบบทรัพยากร** — `NoteModel` มีเพียงประมาณ 20 บรรทัด โดยประกาศตารางและคอลัมน์ มอบหมายการดำเนินการทั่วไปให้กับ `BaseModel` และเขียน SQL แบบกำหนดเองเมื่อจำเป็นเท่านั้น
- **ที่เดียวในการเปลี่ยนตรรกะการเชื่อมต่อ** — การย้ายจาก SQLite ไปยัง PostgreSQL จะสัมผัส `DBAdapter.Connect()` เท่านั้น
- **ทางออกที่ชัดเจน** — `BaseModel.OpenDB()` ให้สิทธิ์ในการเข้าถึง DB ดิบแก่คลาสย่อยโดยไม่ทำลายเลเยอร์ทั่วไป

---

## การตัดสินใจออกแบบ

### ทำไมต้องส่งคืน `Dictionary` แทนอินสแตนซ์ของโมเดล?

เทมเพลต JinjaX ใช้สัญกรณ์จุด: `{{ note.title }}` เอนจิน JinjaX แก้ไขสิ่งนี้โดยเรียก `dict.Value("title")` บน `Dictionary` ของ Xojo อินสแตนซ์คลาสที่กำหนดเองไม่มีกลไกการสอบเทียบที่เทียบเท่า

```xojo
// Template: {{ note.title }}

// ✅ ทำงาน — Dictionary ตอบสนองสัญกรณ์จุด
ctx.Value("note") = myDictionary        // .Value("title") → "Hello"

// ❌ ไม่ทำงาน — NoteModel ไม่มีการสอบเทียบ JinjaX
ctx.Value("note") = myNoteInstance
```

!!! warning
    เมธอดของโมเดลทั้งหมดต้องคืนค่า `Dictionary` หรือ `Variant()` ของ `Dictionary` นี่คือกฎสถาปัตยกรรมที่สำคัญที่สุดในเลเยอร์ข้อมูล ไม่สามารถใช้อินสแตนซ์คลาสที่กำหนดเองในเทมเพลต JinjaX ได้

### ทำไมต้องมีการเชื่อมต่อหนึ่งครั้งต่อคำขอ?

Xojo Web จัดการคำขอ HTTP ที่เกิดขึ้นพร้อมกันบนเธรดแยกต่างหาก `SQLiteDatabase` ที่ใช้ร่วมกันในหลายเธรดต้องมีการล็อกและมีความเสี่ยงต่อการติดตัว

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

การเปิดการเชื่อมต่อใหม่ต่อครั้งถือว่าปลอดภัย ค่าใช้จ่าย SQLite สำหรับการเปิดการเชื่อมต่อไฟล์ภายในเครื่องนั้นน้อยมากเมื่อเทียบกับปริมาณการรับส่งข้อมูลเทียบกับเครื่องมือภายในทั่วไป

---

## วงจรชีวิตของการเชื่อมต่อ

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
    เส้นโค้ดทุกเส้นที่เรียก `Connect()` ต้องเรียก `db.Close()` ก่อนที่จะส่งกลับ — รวมถึงเส้นทางข้อผิดพลาด เมธอด `BaseModel` ทั้งหมดปิดการเชื่อมต่อในทุกสาขาผลตอบแทน

---

## DBAdapter (Module)

**ไฟล์:** `Framework/DBAdapter.xojo_code`

โมดูล — ไม่ต้องสร้างอินสแตนซ์ — ที่เป็นเจ้าของโรงงานการเชื่อมต่อและการตั้งค่าโครงร่าง

### `Connect() As SQLiteDatabase`

เปิดและส่งคืนการเชื่อมต่อใหม่ ผู้เรียกมีหน้าที่รับผิดชอบสำหรับ `db.Close()`

ไฟล์ฐานข้อมูลอยู่ในโฟลเดอร์ `data/` **ข้างไฟล์ปฏิบัติการ** — แก้ไขผ่าน `App.ExecutableFile.Parent` สิ่งนี้ทำงานเหมือนกันในตัวดีบัก Xojo และในไบนารีผลิตภัณฑ์ที่สร้างไว้ โครงสร้าง `data/` ถูกสร้างขึ้นโดยอัตโนมัติหากไม่มี

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
    `App.ExecutableFile` คือไบนารีที่ทำงาน — ในตัวดีบัก Xojo นี่คือส่วนตั้งจำหน่ายดีบัก ในผลิตภัณฑ์มันคือแอปที่คอมไพล์ทั้งสองกรณีแก้ไข `Parent` ไปยังโฟลเดอร์เดียวกัน ดังนั้นเส้นทางจึงคงที่ในสภาพแวดล้อมต่างๆ

### `InitDB()`

สร้างตารางทั้งหมดหากไม่มี เรียกครั้งเดียวจาก `App.Opening` ปลอดภัยในการเรียกในทุกการเริ่มต้น — `CREATE TABLE IF NOT EXISTS` เป็นไปได้

หากต้องการเพิ่มตารางใหม่ ให้เพิ่ม `ExecuteSQL` อีกอันที่นี่ก่อน `db.Close()`

### App.Opening — เส้นทางการเริ่มต้น

`App.Opening` เป็นสถานที่เดียวที่เชื่อมโยงเส้นทางรันไทม์ทั้งสองก่อนที่จะรับส่งคำขอใด ๆ:

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

ทั้ง `templates/` และ `data/` นั่งข้างไฟล์ปฏิบัติการ ซึ่งหมายความว่าคุณสามารถนำแอปไปใช้งานได้โดยคัดลอกไบนารีพร้อมกับสองโฟลเดอร์เหล่านั้น — ไม่มีเส้นทางสัมบูรณ์ ไม่มีตัวแปรสภาพแวดล้อม

---

## BaseModel (Class)

**ไฟล์:** `Framework/BaseModel.xojo_code`

คลาสพื้นฐาน CRUD ทั่วไป คลาสย่อยแทนที่เมธอดสองอันและสืบทอดการดำเนินการทั้งหมด

### สัญญาของคลาสย่อย

| เมธอด | จำเป็น | ส่งคืน | วัตถุประสงค์ |
|--------|----------|---------|---------|
| `TableName() As String` | ใช่ | `"notes"` | ชื่อตารางของ SQL |
| `Columns() As String` | ใช่ | `"id, title, body, ..."` | รายการคอลัมน์คั่นด้วยจุลภาค สำหรับ `SELECT` |

### เมธอด CRUD

#### `FindAll(orderBy As String = "") As Variant()`

ส่งคืนแถวทั้งหมดที่เรียงลำดับตาม `orderBy` แต่ละองค์ประกอบคือ `Dictionary`

```xojo
Var rows() As Variant = model.FindAll("updated_at DESC")
// rows(0) → Dictionary: {"id": "1", "title": "Hello", ...}
```

#### `FindByID(id As Integer) As Dictionary`

ส่งคืนแถวที่ตรงกัน หรือ `Nil` ถ้าไม่พบ ตรวจสอบเสมอก่อนใช้:

```xojo
Var row As Dictionary = model.FindByID(42)
If row Is Nil Then
  RenderError(404, "Not found")
  Return
End If
```

#### `Insert(data As Dictionary) As Integer`

สร้างพารามิเตอร์ `INSERT` จากคีย์พจนานุกรม ส่งคืน `ROWID` ใหม่ ปลอดภัยจากการฉีด SQL — ใช้ `SQLitePreparedStatement`

```xojo
Var data As New Dictionary
data.Value("title") = "My Note"
data.Value("body")  = "Content"
Var newID As Integer = model.Insert(data)
```

!!! note
    `Insert` ไม่สามารถแสดงนิพจน์ด้านฐานข้อมูล SQLite เช่น `datetime('now')` — สิ่งเหล่านี้ต้องไปผ่านทางออก ดูเพิ่มเติมที่ NoteModel ด้านล่าง

#### `UpdateByID(id As Integer, data As Dictionary)`

พารามิเตอร์ `UPDATE ... WHERE id = ?` มีเพียงคีย์ที่มีอยู่ในพจนานุกรมเท่านั้นที่จะได้รับการอัพเดต

```xojo
Var data As New Dictionary
data.Value("title") = "New Title"
model.UpdateByID(42, data)
```

#### `DeleteByID(id As Integer)`

```xojo
model.DeleteByID(42)
```

### เมธอดทางออกที่มีการป้องกัน

#### `OpenDB() As SQLiteDatabase`

ส่งคืนการเชื่อมต่อดิบสำหรับคลาสย่อยที่ต้องการ SQL แบบกำหนดเอง คลาสย่อยมีหน้าที่รับผิดชอบสำหรับ `db.Close()`

ใช้เมื่อ:
- จำเป็นต้องใช้นิพจน์ SQLite (`datetime('now')`, `strftime(...)`) ใน SQL — ไม่สามารถเป็น `?` พารามิเตอร์ได้
- คำขอที่ซับซ้อนพร้อม `JOIN`, `GROUP BY`, `HAVING` หรือคำขออย่างย่อย
- `db.LastRowID` จำเป็นหลังจากการ `INSERT` ที่กำหนดเอง
- จำเป็นต้องแชร์การเชื่อมต่อหลายคำสั่ง

#### `RowToDict(rs As RowSet) As Dictionary`

แมปแถว RowSet ปัจจุบันไปยัง `Dictionary` โดยใช้ชื่อคอลัมน์จาก `Columns()` ค่าทั้งหมดจะถูกเก็บไว้เป็น `StringValue` — โดยจงใจ JinjaX แสดงผลทุกอย่างเป็นสตริง ViewModels จะแปลงเป็นจำนวนเต็มผ่าน `Val()` เมื่อจำเป็น

---

## NoteModel (Class)

**ไฟล์:** `Models/NoteModel.xojo_code`

โมเดลทรัพยากรที่เป็นรูปธรรม เมธอดทั้งหมดต้องใช้พารามิเตอร์ `userID` เพื่อจำกัดบันทึกต่อผู้ใช้ — ผู้ใช้แต่ละคนสามารถเห็นและแก้ไขบันทึกของตนเองได้เท่านั้น

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

`Create` และ `Update` ใช้ทางออกเพราะ `datetime('now')` เป็นนิพจน์ที่ประเมินโดย SQLite — การผูกสตริง `"datetime('now')"` เป็น `?` พารามิเตอร์จะเก็บข้อความตามตัวอักษรแทนที่จะเป็นเวลาประทับ

ทุกแบบสอบถามจะรวม `WHERE user_id = ?` เพื่อบังคับใช้ความเป็นเจ้าของในระดับ SQL ดูข้อมูลเพิ่มเติมได้ที่ [เส้นทางที่มีการป้องกันและการกำหนดขอบเขตผู้ใช้](../protected-routes/index.html)

---

## การแมป CRUD Task

เส้นทางหมายเหตุทั้งหมดต้องมีการตรวจสอบสิทธิ์ โดยทั่วไปแต่ละการเรียกโมเดลจะรวม `userID` เพื่อกำหนดขอบเขตข้อมูลต่อผู้ใช้

| การกระทำของผู้ใช้ | HTTP | ViewModel | การเรียกโมเดล | SQL |
|-------------|------|-----------|------------|-----|
| ดูรายชื่อ | `GET /notes` | `NotesListVM` | `NoteModel.GetAll(userID)` | `SELECT … WHERE user_id = ? ORDER BY updated_at DESC` |
| ดูรายการเดียว | `GET /notes/:id` | `NotesDetailVM` | `NoteModel.GetByID(id, userID)` | `SELECT … WHERE id = ? AND user_id = ?` |
| ฟอร์มใหม่ | `GET /notes/new` | `NotesNewVM` | — | — |
| สร้าง | `POST /notes` | `NotesCreateVM` | `NoteModel.Create(title, body, userID)` | `INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)` |
| ฟอร์มแก้ไข | `GET /notes/:id/edit` | `NotesEditVM` | `NoteModel.GetByID(id, userID)` | `SELECT … WHERE id = ? AND user_id = ?` |
| อัพเดต | `POST /notes/:id` | `NotesUpdateVM` | `NoteModel.Update(id, title, body, userID)` | `UPDATE notes SET … WHERE id = ? AND user_id = ?` |
| ลบ | `POST /notes/:id/delete` | `NotesDeleteVM` | `NoteModel.Delete(id, userID)` | `DELETE FROM notes WHERE id = ? AND user_id = ?` |

---

## ประโยชน์และการแลกเปลี่ยน

| ประโยชน์ | เหตุผล |
|---------|-----|
| ไม่มี boilerplate | ทรัพยากรใหม่ต้องการเพียง `TableName()` + `Columns()` + ตัวห่อหุ้มบาง |
| ปลอดภัยจากการฉีด SQL | ค่าผู้ใช้ทั้งหมดจะไปผ่านพารามิเตอร์ `?` |
| ปลอดภัยจากเธรด | การเชื่อมต่อต่อคำขอ — ไม่มีสถานะที่เปลี่ยนแปลงร่วมกัน |
| เข้ากันได้กับ JinjaX | ผลลัพธ์ทั้งหมดเป็น `Dictionary` — เทมเพลตทำงานได้ทันที |
| ทดสอบได้ | การทดสอบ XojoUnit ของ DB ที่แท้จริง ค่าใช้จ่ายเล็กน้อย |
| ทางออกที่ชัดเจน | `OpenDB()` ถูกบันทึกและมีจุดประสงค์ ไม่ใช่การหลีกเลี่ยง |

| การแลกเปลี่ยน | ผลกระทบ |
|-----------|--------|
| ไม่มีคุณสมบัติของ ORM | ไม่มีการเชื่อมโยง โหลดแบบขี้เกียจ หรือการติดตามการเปลี่ยนแปลง |
| ค่าสตริงเท่านั้น | `RowToDict` เก็บทุกอย่างเป็น `StringValue` ViewModels ต้องแปลงผ่าน `Val()` |
| ไม่มีระบบการย้ายถิ่น | การเปลี่ยนแปลงโครงร่างต้องการ `ALTER TABLE` หรือสร้างใหม่ใน dev |
| ข้อจำกัด `datetime` | `BaseModel.Insert` ไม่สามารถใช้ `DEFAULT (datetime('now'))` — ใช้ทางออก |

### เมื่อใดที่จะใช้ CRUD ที่สืบทอดมา เมื่อใดที่จะใช้ทางออก

ใช้วิธี `BaseModel` ที่สืบทอดมาเมื่อการดำเนินการเป็น `SELECT`, `INSERT`, `UPDATE` หรือ `DELETE` ที่เรียบง่ายพร้อมค่าที่ผูกไว้ธรรมดา

ใช้ `OpenDB()` เมื่อคุณต้องการนิพจน์ SQLite (`datetime('now')`, `strftime(...)`), คำขอที่ซับซ้อน (`JOIN`, `GROUP BY`, คำขออย่างย่อย), `db.LastRowID` หลังจากการแทรกแบบกำหนดเอง หรือหลายคำสั่งในการเชื่อมต่อเดียว

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

**3. ลงทะเบียน** `Models/TagModel.xojo_code` ใน `mvvm.xojo_project` ในโฟลเดอร์ Models (Xojo IDE: ลากไฟล์ไปที่แผง project)

**4. สร้าง ViewModels** ใน `ViewModels/Tags/` และ **เทมเพลต** ใน `templates/tags/` ตามรูปแบบเดียวกับ `Notes`