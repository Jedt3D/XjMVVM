---
title: "แท็ก & Many-to-Many"
description: วิธีการเพิ่มทรัพยากรที่สอง (แท็ก) เชื่อมต่อตารางฟังก์ชันที่เชื่อมต่อหลายต่อหลาย และสอบถาม across the relationship
---

# แท็ก & Many-to-Many

การเพิ่มแท็กแนะนำสองสิ่งพร้อมกัน: **ทรัพยากรที่สมบูรณ์ที่สอง** (พิสูจน์ว่ารูปแบบ CRUD ทั่วไปหลายทั่ว Notes) และ **ความสัมพันธ์แบบหลายต่อหลาย** ระหว่าง Notes และ Tags ผ่านตารางฟังก์ชัน

## ทรัพยากร Tag

`TagModel` ตามรูปแบบสามชั้นเดียวกับ `NoteModel`

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 48
#padding: 10
#lineWidth: 1.5
[DBAdapter] -> [BaseModel]
[BaseModel] -> [TagModel|TableName(): "tags"\nColumns(): id, name, created_at\nGetAll() / GetByID()\nCreate() / Update() / Delete()]
[TagModel] -> [<database> tags]
-->
<!-- ascii
DBAdapter → BaseModel → TagModel → tags table
TagModel declares: TableName="tags", Columns="id, name, created_at"
Methods: GetAll(), GetByID(), Create(), Update(), Delete()
-->
<!-- /diagram -->

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

  Sub Update(id As Integer, name As String)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("UPDATE tags SET name = ? WHERE id = ?", name, id)
    db.Close()
  End Sub

  Sub Delete(id As Integer)
    DeleteByID(id)
  End Sub

End Class
```

สคีมาลงทะเบียนใน `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (" + _
  "id          INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name        TEXT NOT NULL, " + _
  "created_at  TEXT DEFAULT (datetime('now')))")
```

---

## เส้นทาง Tags

เจ็ดเส้นทางลงทะเบียนใน `App.Opening` โดยสะท้อนรูปแบบ Notes:

| วิธี | เส้นทาง | ViewModel | การกระทำ |
|--------|------|-----------|--------|
| `GET` | `/tags` | `TagsListVM` | รายการแท็กทั้งหมด |
| `GET` | `/tags/new` | `TagsNewVM` | ฟอร์มแท็กใหม่ |
| `POST` | `/tags` | `TagsCreateVM` | สร้างแท็ก |
| `GET` | `/tags/:id` | `TagsDetailVM` | ดูแท็ก |
| `GET` | `/tags/:id/edit` | `TagsEditVM` | แก้ไขฟอร์ม |
| `POST` | `/tags/:id` | `TagsUpdateVM` | อัพเดตแท็ก |
| `POST` | `/tags/:id/delete` | `TagsDeleteVM` | ลบแท็ก |

---

## Many-to-many: note_tags

Notes และ Tags มีความสัมพันธ์แบบหลายต่อหลาย โน้ตหนึ่งสามารถมีแท็กจำนวนมาก แท็กหนึ่งสามารถปรากฏในหลายโน้ต สิ่งนี้มีโมเดลด้วย **ตารางฟังก์ชัน** — ไม่มีคอลัมน์ foreign key ในตาราง notes หรือ tags

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[<database> notes|id\ntitle\nbody\ncreated_at\nupdated_at] -- [note_tags|note_id (FK)\ntag_id (FK)\nPRIMARY KEY (note_id, tag_id)]
[note_tags] -- [<database> tags|id\nname\ncreated_at]
-->
<!-- ascii
notes (id, title, body, ...)
  │
  │  note_tags (note_id, tag_id)  ← junction / bridge table
  │
tags (id, name, created_at)

A note can have zero or many tags.
A tag can appear on zero or many notes.
-->
<!-- /diagram -->

สคีมา:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_tags (" + _
  "note_id  INTEGER NOT NULL, " + _
  "tag_id   INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, tag_id))")
```

คีย์หลักแบบ composite `(note_id, tag_id)` บังคับความเป็นเอกลักษณ์ที่ระดับฐานข้อมูล — โน้ตไม่สามารถเชื่อมโยงกับแท็กเดียวกันได้สองครั้ง

---

## การอ่านแท็กสำหรับโน้ต

`NoteModel.GetTagsForNote()` ค้นหาตารางฟังก์ชันด้วย `JOIN`:

```xojo
Function GetTagsForNote(noteID As Integer) As Variant()
  Var results() As Variant
  Var db As SQLiteDatabase = OpenDB()
  Var sql As String = "SELECT t.id, t.name, t.created_at FROM tags t " + _
    "JOIN note_tags nt ON nt.tag_id = t.id " + _
    "WHERE nt.note_id = ? ORDER BY t.name ASC"
  Var rs As RowSet = db.SelectSQL(sql, noteID)
  While Not rs.AfterLastRow
    Var row As New Dictionary()
    row.Value("id") = rs.Column("id").StringValue
    row.Value("name") = rs.Column("name").StringValue
    row.Value("created_at") = rs.Column("created_at").StringValue
    results.Add(row)
    rs.MoveToNextRow()
  Wend
  rs.Close()
  db.Close()
  Return results
End Function
```

ค่าที่ส่งคืนคือ `Variant()` ของ `Dictionary` — เข้ากันได้อย่างเต็มที่กับเทมเพลต JinjaX และ JSON API

---

## การเขียนแท็กสำหรับโน้ต

`NoteModel.SetTagsForNote()` ใช้รูปแบบ **delete-then-insert** เพื่อแทนที่ชุดแท็กทั้งหมดแบบอะตอมิก:

```xojo
Sub SetTagsForNote(noteID As Integer, tagIDs() As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("DELETE FROM note_tags WHERE note_id = ?", noteID)
  For Each tagID As Integer In tagIDs
    db.ExecuteSQL("INSERT OR IGNORE INTO note_tags (note_id, tag_id) VALUES (?, ?)", noteID, tagID)
  Next
  db.Close()
End Sub
```

!!! warning
    `INSERT OR IGNORE` ได้ตั้งใจแล้ว คีย์หลักแบบ composite ป้องกันซ้ำที่ระดับฐานข้อมูล หาก `tagID` เดียวกันปรากฏในอาร์เรย์มากกว่าหนึ่งครั้ง `INSERT OR IGNORE` ข้ามบันทึกซ้ำเงียบ ๆ แทนที่จะเพิ่มข้อผิดพลาดข้อ จำกัด

!!! note
    รูปแบบ delete-then-insert ปฏิบัติต่อชุดแท็กทั้งหมด — มันไม่ได้ diff ชุดเก่าเทียบกับชุดใหม่ นี่ง่ายกว่าและถูกต้องสำหรับกรณีการใช้งานส่วนใหญ่ หากคุณต้องการรักษาข้อมูลเมตาในการเชื่อมโยงแต่ละรายการ (เช่น timestamps ต่อมอบหมายแท็ก) วิธี diff จะต้องแทนที่

---

## การเพิ่มความสัมพันธ์แบบหลายต่อหลายใหม่

เพื่อเพิ่ม junction ที่สอง (เช่น Note ↔ Category):

**1.** เพิ่มตารางฟังก์ชันใน `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_categories (" + _
  "note_id      INTEGER NOT NULL, " + _
  "category_id  INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, category_id))")
```

**2.** เพิ่ม `GetCategoriesForNote()` และ `SetCategoriesForNote()` ให้กับรูปแบบที่เกี่ยวข้องโดยใช้รูปแบบ JOIN และ delete-then-insert เดียวกัน

**3.** ใน ViewModel ที่แสดงรายละเอียดโน้ตหรือแก้ไขฟอร์ม ให้เรียกใช้วิธีทั้งสองและรวมผลลัพธ์เข้าในดิกชันนารีบริบท
