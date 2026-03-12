---
title: "แท็ก & ความสัมพันธ์แบบ Many-to-Many"
description: วิธีการเพิ่มทรัพยากร (Tags) ที่สอง สร้างตารางจุดเชื่อม many-to-many และสอบถามข้อมูลข้ามความสัมพันธ์
---

# แท็ก & ความสัมพันธ์แบบ Many-to-Many

การเพิ่ม Tags นำเสนออสองสิ่งไปพร้อมกัน: **ทรัพยากรเต็มตัวอันที่สอง** (พิสูจน์ว่ารูปแบบ CRUD ขยายไปไกลกว่า Notes) และ **ความสัมพันธ์แบบ many-to-many** ระหว่าง Notes และ Tags ผ่านตารางจุดเชื่อม

## ทรัพยากร Tag

`TagModel` ปฏิบัติตามรูปแบบสามชั้นเดียวกับ `NoteModel` อย่างแม่นยำ

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

โครงการถูกลงทะเบียนใน `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (" + _
  "id          INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name        TEXT NOT NULL, " + _
  "created_at  TEXT DEFAULT (datetime('now')))")
```

---

## เส้นทาง Tags

เจ็ดเส้นทางลงทะเบียนใน `App.Opening` สะท้อนรูปแบบ Notes:

| Method | Path | ViewModel | Action |
|--------|------|-----------|--------|
| `GET` | `/tags` | `TagsListVM` | แสดงรายชื่อแท็กทั้งหมด |
| `GET` | `/tags/new` | `TagsNewVM` | แบบฟอร์มแท็กใหม่ |
| `POST` | `/tags` | `TagsCreateVM` | สร้างแท็ก |
| `GET` | `/tags/:id` | `TagsDetailVM` | ดูแท็ก |
| `GET` | `/tags/:id/edit` | `TagsEditVM` | แบบฟอร์มแก้ไข |
| `POST` | `/tags/:id` | `TagsUpdateVM` | อัปเดตแท็ก |
| `POST` | `/tags/:id/delete` | `TagsDeleteVM` | ลบแท็ก |

---

## Many-to-Many: note_tags

Notes และ Tags มีความสัมพันธ์แบบ many-to-many ไปมา บันทึกหนึ่งสามารถมีแท็กจำนวนมากได้ แท็กหนึ่งสามารถปรากฏบนบันทึกจำนวนมากได้ โดยแสดงผลด้วย **ตารางจุดเชื่อม** — ไม่มีคอลัมน์กุญแจต่างประเทศใน notes หรือ tags table

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

โครงการ:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_tags (" + _
  "note_id  INTEGER NOT NULL, " + _
  "tag_id   INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, tag_id))")
```

คีย์หลักแบบประสม `(note_id, tag_id)` บังคับใช้ความไม่ซ้ำกันในระดับฐานข้อมูล — บันทึกไม่สามารถเชื่อมโยงกับแท็กเดียวกันสองครั้งได้

---

## การอ่านแท็กสำหรับบันทึก

`NoteModel.GetTagsForNote()` สอบถามตารางจุดเชื่อมด้วย `JOIN`:

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

ค่าที่ส่งคืนคือ `Variant()` ของ `Dictionary` — สอดคล้องเต็มที่กับเทมเพลต JinjaX และ JSON API

---

## การเขียนแท็กสำหรับบันทึก

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
    `INSERT OR IGNORE` มีจุดประสงค์ คีย์หลักแบบประสมป้องกันการซ้ำกันในระดับฐานข้อมูล หากเกิด `tagID` เดียวกันปรากฏในอาร์เรย์มากกว่าหนึ่งครั้ง `INSERT OR IGNORE` จะข้ามการซ้ำกันแบบเงียบ ๆ แทนการยกเว้นข้อผิดพลาดข้อจำกัด

!!! note
    รูปแบบ delete-then-insert ถือว่าชุดแท็กเป็นทั้งหมด — ไม่เปรียบเทียบชุดเก่ากับชุดใหม่ วิธีนี้ง่ายกว่าและถูกต้องสำหรับกรณีการใช้งานส่วนใหญ่ หากคุณต้องการเก็บรักษาข้อมูลเมตาบนการเชื่อมโยงแต่ละรายการ (เช่น เวลาต่อการกำหนดแท็ก) จะต้องใช้วิธี diff แทน

---

## การเพิ่มความสัมพันธ์แบบ many-to-many ใหม่

เพื่อเพิ่มจุดเชื่อมอื่น (เช่น Note ↔ Category):

**1.** เพิ่มตารางจุดเชื่อมใน `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_categories (" + _
  "note_id      INTEGER NOT NULL, " + _
  "category_id  INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, category_id))")
```

**2.** เพิ่ม `GetCategoriesForNote()` และ `SetCategoriesForNote()` ไปยังโมเดลที่เกี่ยวข้องโดยใช้รูปแบบ JOIN และ delete-then-insert เดียวกัน

**3.** ใน ViewModel ที่แสดงรายละเอียดบันทึกหรือแบบฟอร์มแก้ไข ให้เรียกใช้ทั้งสองวิธี และรวมผลลัพธ์เข้าในพจนานุกรมบริบท