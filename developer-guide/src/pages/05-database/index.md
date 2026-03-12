---
title: SQLite & Dictionary Contract
description: How to work with SQLite, convert RowSet to Dictionary, and write thread-safe Model classes.
---

# SQLite & Dictionary Contract

## The core pattern

Every Model method follows the same pattern: open a fresh database connection, run the query, convert each `RowSet` row into a `Dictionary`, close everything, return.

This pattern is deliberate — it ensures thread safety and enforces the Dictionary data contract that JinjaX requires.

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

The return type `Variant()` containing `Dictionary` objects is the only format JinjaX can iterate over in a `{% for %}` loop.

## Return types

| Operation | Return type | Nil case |
|---|---|---|
| Multiple rows | `Variant()` (of `Dictionary`) | Empty array `()` |
| Single row | `Dictionary` | `Nil` |
| Create | `Integer` (new row ID) | — |
| Update / Delete | `Sub` (nothing) | — |

Always check for `Nil` when fetching a single row:

```xojo
// In the ViewModel
Var note As Dictionary = NoteModel.GetByID(id)
If note = Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

## Per-request database connections

The `OpenDB()` private method opens a **fresh** connection on every call. There is no shared, long-lived database connection on `App`.

```xojo
Private Function OpenDB() As SQLiteDatabase
  Var dbFile As New FolderItem(DB_PATH, FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile
  db.Connect()
  Return db
End Function
```

**Why per-request?** Xojo handles concurrent requests on multiple threads. A shared `SQLiteDatabase` instance would require a mutex. Opening a new connection per request is simpler and avoids all locking complexity — SQLite handles concurrent read connections from multiple processes natively.

**Why not a connection pool?** For the traffic volumes this framework targets (small team, internal tools), the overhead of opening a connection is negligible. A pool adds complexity without measurable benefit at this scale.

## Database initialization

The first method called when the app starts is `NoteModel.InitDB()` (from `App.Opening()`). It creates the database file and runs `CREATE TABLE IF NOT EXISTS`:

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

This is safe to call every startup — `IF NOT EXISTS` is idempotent.

## Parameterized queries

Always use `?` placeholders for values. Never concatenate user input into SQL strings — this prevents SQL injection:

```xojo
// ✅ Correct — parameterized
db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
db.SelectSQL("SELECT * FROM notes WHERE id = ?", id)

// ❌ Wrong — SQL injection risk
db.ExecuteSQL("INSERT INTO notes (title) VALUES ('" + title + "')")
```

`SelectSQL()` and `ExecuteSQL()` accept variadic `Variant` parameters after the SQL string.

## Getting the last inserted row ID

After an `INSERT`, retrieve the new row's ID using `db.LastRowID`:

```xojo
Function Create(title As String, body As String) As Integer
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function
```

The ViewModel uses this ID to redirect to the new note's detail page:

```xojo
// In NotesCreateVM.OnPost()
Var newID As Integer = NoteModel.Create(title, body)
SetFlash("Note created.", "success")
Redirect("/notes/" + Str(newID))
```

## Column types

SQLite is dynamically typed. Xojo's `RowSet` column accessors convert values on read:

| Accessor | Use for |
|---|---|
| `.StringValue` | `TEXT` columns, IDs (safe default) |
| `.IntegerValue` | `INTEGER` columns |
| `.DoubleValue` | `REAL` columns |
| `.BooleanValue` | `INTEGER` 0/1 stored as boolean |

Store all dates as `TEXT` using SQLite's `datetime()` function. Retrieve and display them as strings — format in the template or ViewModel as needed.

## Database path for production

The current implementation hardcodes the path for development. For production builds, use `SpecialFolder.ApplicationData`:

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

Use a build constant or preference to switch between development and production paths.
