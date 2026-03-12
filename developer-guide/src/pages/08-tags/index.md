---
title: "Tags & Many-to-Many"
description: How to add a second resource (Tags), wire up a many-to-many junction table, and query across the relationship.
---

# Tags & Many-to-Many

Adding Tags introduced two things at once: a **second full resource** (proving the CRUD pattern generalises beyond Notes) and a **many-to-many relationship** between Notes and Tags via a junction table.

## The Tag resource

`TagModel` follows exactly the same three-layer pattern as `NoteModel`.

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

The schema is registered in `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (" + _
  "id          INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name        TEXT NOT NULL, " + _
  "created_at  TEXT DEFAULT (datetime('now')))")
```

---

## Tags routes

Seven routes are registered in `App.Opening`, mirroring the Notes pattern:

| Method | Path | ViewModel | Action |
|--------|------|-----------|--------|
| `GET` | `/tags` | `TagsListVM` | List all tags |
| `GET` | `/tags/new` | `TagsNewVM` | New tag form |
| `POST` | `/tags` | `TagsCreateVM` | Create tag |
| `GET` | `/tags/:id` | `TagsDetailVM` | View tag |
| `GET` | `/tags/:id/edit` | `TagsEditVM` | Edit form |
| `POST` | `/tags/:id` | `TagsUpdateVM` | Update tag |
| `POST` | `/tags/:id/delete` | `TagsDeleteVM` | Delete tag |

---

## Many-to-many: note_tags

Notes and Tags have a many-to-many relationship. A note can have many tags; a tag can appear on many notes. This is modelled with a **junction table** — no foreign key column on either the notes or tags table.

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

The schema:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_tags (" + _
  "note_id  INTEGER NOT NULL, " + _
  "tag_id   INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, tag_id))")
```

The composite primary key `(note_id, tag_id)` enforces uniqueness at the database level — a note cannot be associated with the same tag twice.

---

## Reading tags for a note

`NoteModel.GetTagsForNote()` queries the junction table with a `JOIN`:

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

The return value is `Variant()` of `Dictionary` — fully compatible with JinjaX templates and the JSON API.

---

## Writing tags for a note

`NoteModel.SetTagsForNote()` uses a **delete-then-insert** pattern to replace the full tag set atomically:

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
    `INSERT OR IGNORE` is intentional. The composite primary key prevents duplicates at the database level. If the same `tagID` appears in the array more than once, `INSERT OR IGNORE` silently skips the duplicate rather than raising a constraint error.

!!! note
    The delete-then-insert pattern treats the tag set as a whole — it does not diff the old set against the new. This is simpler and correct for most use cases. If you need to preserve metadata on individual associations (e.g., timestamps per tag assignment), a diff approach would be needed instead.

---

## Adding a new many-to-many relationship

To add a second junction (e.g., Note ↔ Category):

**1.** Add the junction table in `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS note_categories (" + _
  "note_id      INTEGER NOT NULL, " + _
  "category_id  INTEGER NOT NULL, " + _
  "PRIMARY KEY (note_id, category_id))")
```

**2.** Add `GetCategoriesForNote()` and `SetCategoriesForNote()` to the relevant model using the same JOIN and delete-then-insert patterns.

**3.** In the ViewModel that renders the note detail or edit form, call both methods and merge results into the context dictionary.
