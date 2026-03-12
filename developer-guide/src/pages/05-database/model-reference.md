---
title: "Database Layer Reference"
description: The three-layer DBAdapter / BaseModel / NoteModel architecture — design rationale, connection lifecycle, full CRUD API, and how to add a new resource.
---

# Database Layer Reference

## Three-Layer Architecture

The database layer separates three distinct responsibilities. Each layer knows only about the one below it.

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

This separation means:

- **No boilerplate in resource models** — `NoteModel` is ~20 lines. It declares the table and columns, delegates generic operations to `BaseModel`, and only writes custom SQL when needed.
- **Single place to change connection logic** — moving from SQLite to PostgreSQL touches only `DBAdapter.Connect()`.
- **Clear escape hatch** — `BaseModel.OpenDB()` gives subclasses raw DB access without breaking the generic layer.

---

## Design Decisions

### Why return `Dictionary` instead of model instances?

JinjaX templates use dot-notation: `{{ note.title }}`. The JinjaX engine resolves this by calling `dict.Value("title")` on a Xojo `Dictionary`. Custom class instances have no equivalent introspection mechanism.

```xojo
// Template: {{ note.title }}

// ✅ Works — Dictionary satisfies dot-notation
ctx.Value("note") = myDictionary        // .Value("title") → "Hello"

// ❌ Does NOT work — NoteModel has no JinjaX introspection
ctx.Value("note") = myNoteInstance
```

!!! warning
    All model methods must return `Dictionary` or `Variant()` of `Dictionary`. This is the most critical architectural rule in the data layer. Custom class instances cannot be used in JinjaX templates.

### Why one connection per request?

Xojo Web handles concurrent HTTP requests on separate threads. A shared `SQLiteDatabase` across threads requires locking and risks deadlock.

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

Opening a fresh connection per call is safe. SQLite's overhead for opening a local file connection is negligible at typical internal-tool traffic volumes.

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
    Every code path that calls `Connect()` must call `db.Close()` before returning — including error paths. All `BaseModel` methods close the connection on every return branch.

---

## DBAdapter (Module)

**File:** `Framework/DBAdapter.xojo_code`

A module — no instantiation needed — that owns the connection factory and schema setup.

### `Connect() As SQLiteDatabase`

Opens and returns a fresh connection. The caller is responsible for `db.Close()`.

The database file lives in a `data/` folder **next to the executable** — resolved via `App.ExecutableFile.Parent`. This works identically in the Xojo debugger and in a built production binary. The `data/` directory is created automatically if it does not exist.

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
    `App.ExecutableFile` is the running binary — in the Xojo debugger this is the debug stub, in production it is the compiled app. Both cases resolve `Parent` to the same folder, so the path is stable across environments.

### `InitDB()`

Creates all tables if they do not exist. Called once from `App.Opening`. Safe to call on every startup — `CREATE TABLE IF NOT EXISTS` is idempotent.

To add a new table, add another `ExecuteSQL` here before `db.Close()`.

### App.Opening — Startup Paths

`App.Opening` is the single place that wires up both runtime paths before any request is served:

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

Both `templates/` and `data/` sit alongside the executable. This means you can deploy the app by copying the binary together with those two folders — no absolute paths, no environment variables needed.

---

## BaseModel (Class)

**File:** `Framework/BaseModel.xojo_code`

The generic CRUD base class. Subclasses override two methods and inherit all operations.

### Subclass Contract

| Method | Required | Returns | Purpose |
|--------|----------|---------|---------|
| `TableName() As String` | Yes | `"notes"` | SQL table name |
| `Columns() As String` | Yes | `"id, title, body, ..."` | Comma-separated column list for `SELECT` |

### CRUD Methods

#### `FindAll(orderBy As String = "") As Variant()`

Returns all rows ordered by `orderBy`. Each element is a `Dictionary`.

```xojo
Var rows() As Variant = model.FindAll("updated_at DESC")
// rows(0) → Dictionary: {"id": "1", "title": "Hello", ...}
```

#### `FindByID(id As Integer) As Dictionary`

Returns the matching row, or `Nil` if not found. Always check before using:

```xojo
Var row As Dictionary = model.FindByID(42)
If row Is Nil Then
  RenderError(404, "Not found")
  Return
End If
```

#### `Insert(data As Dictionary) As Integer`

Builds a parameterized `INSERT` from the dictionary keys. Returns the new `ROWID`. SQL injection safe — uses `SQLitePreparedStatement`.

```xojo
Var data As New Dictionary
data.Value("title") = "My Note"
data.Value("body")  = "Content"
Var newID As Integer = model.Insert(data)
```

!!! note
    `Insert` cannot express SQLite-side expressions like `datetime('now')` — those must go through the escape hatch. See NoteModel below.

#### `UpdateByID(id As Integer, data As Dictionary)`

Parameterized `UPDATE ... WHERE id = ?`. Only keys present in the dictionary are updated.

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

Returns a raw connection for subclasses that need custom SQL. The subclass is responsible for `db.Close()`.

Use when:
- SQLite expressions (`datetime('now')`, `strftime(...)`) are needed in SQL — they cannot be `?` parameters
- Complex queries with `JOIN`, `GROUP BY`, `HAVING`, or subqueries
- `db.LastRowID` is needed after an `INSERT`
- Multiple statements must share one connection

#### `RowToDict(rs As RowSet) As Dictionary`

Maps the current RowSet row to a `Dictionary` using the column names from `Columns()`. All values are stored as `StringValue` — intentional. JinjaX renders everything as strings; ViewModels cast to integers via `Val()` when needed.

---

## NoteModel (Class)

**File:** `Models/NoteModel.xojo_code`

The concrete resource model. Only ~20 lines because `BaseModel` handles everything generic.

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

`Create` and `Update` use the escape hatch because `datetime('now')` is a SQLite-evaluated expression — binding the string `"datetime('now')"` as a `?` parameter would store the literal text, not a timestamp.

---

## CRUD Task Mapping

| User action | HTTP | ViewModel | Model call | SQL |
|-------------|------|-----------|------------|-----|
| View list | `GET /notes` | `NotesListVM` | `NoteModel.GetAll()` | `SELECT … ORDER BY updated_at DESC` |
| View one | `GET /notes/:id` | `NotesDetailVM` | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| New form | `GET /notes/new` | `NotesNewVM` | — | — |
| Create | `POST /notes` | `NotesCreateVM` | `NoteModel.Create(title, body)` | `INSERT INTO notes (title, body) VALUES (?, ?)` |
| Edit form | `GET /notes/:id/edit` | `NotesEditVM` | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| Update | `POST /notes/:id` | `NotesUpdateVM` | `NoteModel.Update(id, title, body)` | `UPDATE notes SET … WHERE id = ?` |
| Delete | `POST /notes/:id/delete` | `NotesDeleteVM` | `NoteModel.Delete(id)` | `DELETE FROM notes WHERE id = ?` |

---

## Benefits and Trade-offs

| Benefit | Why |
|---------|-----|
| No boilerplate | New resource needs only `TableName()` + `Columns()` + thin wrappers |
| SQL injection safe | All user values go through `?` parameter binding |
| Thread-safe | Per-request connections — no shared mutable state |
| JinjaX compatible | All results are `Dictionary` — templates work immediately |
| Testable | XojoUnit tests hit a real SQLite DB; negligible overhead |
| Clear escape hatch | `OpenDB()` is documented and intentional, not a workaround |

| Trade-off | Impact |
|-----------|--------|
| No ORM features | No associations, lazy loading, or change tracking |
| String-only values | `RowToDict` stores everything as `StringValue`; ViewModels must cast via `Val()` |
| No migration system | Schema changes require manual `ALTER TABLE` or recreating the DB in dev |
| `datetime` limitation | `BaseModel.Insert` cannot use `DEFAULT (datetime('now'))` — use escape hatch |

### When to use inherited CRUD vs the escape hatch

Use `BaseModel` inherited methods when the operation is a simple `SELECT`, `INSERT`, `UPDATE`, or `DELETE` with plain bound values.

Use `OpenDB()` when you need SQLite expressions (`datetime('now')`, `strftime(...)`), complex queries (`JOIN`, `GROUP BY`, subqueries), `db.LastRowID` after a custom insert, or multiple statements in one connection.

---

## Adding a New Resource

Adding `TagModel` as a complete example:

**1. Create `Models/TagModel.xojo_code`:**

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

**2. Add the table to `DBAdapter.InitDB()`:**

```xojo
db.ExecuteSQL( _
  "CREATE TABLE IF NOT EXISTS tags (" + _
  "id         INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "name       TEXT NOT NULL, " + _
  "created_at TEXT DEFAULT (datetime('now')))")
```

**3. Register** `Models/TagModel.xojo_code` in `mvvm.xojo_project` under the Models folder (Xojo IDE: drag the file into the project panel).

**4. Create ViewModels** in `ViewModels/Tags/` and **templates** in `templates/tags/` following the same pattern as `Notes`.
