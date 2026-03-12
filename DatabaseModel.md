# Database Layer Reference

Detailed reference for `DBAdapter`, `BaseModel`, and `NoteModel` — the three-layer database architecture used in this project. Covers the design decisions, connection lifecycle, CRUD patterns, and trade-offs.

---

## Design Decisions

### Why three layers?

The database layer is split into three distinct responsibilities:

```
DBAdapter (Module)
  └── owns the connection factory and schema
      │
      ▼
BaseModel (Class)
  └── owns generic CRUD: FindAll, FindByID, Insert, UpdateByID, DeleteByID
      │
      ▼
NoteModel (Class)  ← your actual resource
  └── owns table name, column list, and any custom SQL
```

This separation means:

1. **No boilerplate in resource models** — `NoteModel` is ~20 lines. It declares the table and columns, delegates generic operations to `BaseModel`, and only writes custom SQL for things that need it (timestamp expressions).
2. **Single place to change connection logic** — if you move from SQLite to PostgreSQL, only `DBAdapter.Connect()` changes.
3. **Clear escape hatch** — `BaseModel.OpenDB()` gives subclasses raw DB access without breaking the generic layer.

### Why return `Dictionary` instead of model instances?

JinjaX templates use dot-notation: `{{ note.title }}`. This syntax is resolved by the JinjaX engine against Xojo `Dictionary` objects — it calls `dict.Value("title")`. Custom Xojo class instances have no mechanism to satisfy this lookup.

```
// Template: {{ note.title }}
//
// Works:
ctx.Value("note") = myDictionary      // Dictionary.Value("title") → "Hello"
//
// Does NOT work:
ctx.Value("note") = myNoteInstance    // NoteModel has no JinjaX introspection
```

**All model methods must return `Dictionary` or `Variant()` of `Dictionary`.** This is the most critical architectural rule in the data layer.

### Why one connection per request?

Xojo Web runs each HTTP request on its own thread. A single shared `SQLiteDatabase` connection across threads requires locking and risks data corruption or deadlock under concurrent load.

Opening a fresh connection per call is safe, and SQLite's overhead for opening a local file connection is negligible for typical web loads. The connection is always closed before the method returns.

```
Thread A (GET /notes)         Thread B (POST /notes)
  DBAdapter.Connect()           DBAdapter.Connect()
  SELECT * FROM notes           INSERT INTO notes ...
  db.Close()                    db.Close()
      ↑ independent, no conflict ↑
```

---

## Connection Lifecycle

```
App.Opening (startup, single call)
  │
  DBAdapter.InitDB()
  │  Connect() → CREATE TABLE IF NOT EXISTS ... → Close()
  │
  (app is now ready to serve requests)

Per-request (each HTTP request, concurrent)
  │
  HandleURL → Router → ViewModel → Model method
    │
    DBAdapter.Connect()      ← open connection
    │
    SELECT / INSERT / ...    ← execute SQL
    │
    RowSet → RowToDict()     ← map to Dictionary
    │
    db.Close()               ← close connection
    │
  Return Dictionary to ViewModel
    │
  JinjaX renders template
    │
  response.Write(html)       ← connection already closed
```

**Rule:** Every code path that calls `Connect()` must call `db.Close()` before returning, including error paths. The `BaseModel` methods all close the connection on every return branch.

---

## DBAdapter (Module)

**File:** `Framework/DBAdapter.xojo_code`

A module (not a class — no instantiation needed) that owns the SQLite connection factory and schema initialization.

### `Connect() As SQLiteDatabase`

Opens and returns a fresh `SQLiteDatabase` connection. The caller is responsible for calling `db.Close()` when done.

```xojo
Function Connect() As SQLiteDatabase
  Var dbFile As New FolderItem("/Users/worajedt/Xojo Projects/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)
  Var db As New SQLiteDatabase
  db.DatabaseFile = dbFile
  db.Connect()
  Return db
End Function
```

### `InitDB()`

Creates all tables if they do not exist. Called once from `App.Opening`. Safe to call repeatedly (`CREATE TABLE IF NOT EXISTS` is idempotent).

To add a new table, add another `db.ExecuteSQL("CREATE TABLE IF NOT EXISTS ...")` here before `db.Close()`.

---

## BaseModel (Class)

**File:** `Framework/BaseModel.xojo_code`

The repository base class. Subclasses override two methods and inherit all CRUD for free.

### Subclass Contract

| Method | Required | Returns | Purpose |
|--------|----------|---------|---------|
| `TableName() As String` | Yes | `"notes"` | SQL table name |
| `Columns() As String` | Yes | `"id, title, body, ..."` | Comma-separated column list for SELECT |

### Generic CRUD Methods

#### `FindAll(orderBy As String = "") As Variant()`

```
SELECT {Columns()} FROM {TableName()} [ORDER BY orderBy]
```

Returns all rows as `Variant()` of `Dictionary`. Each element is one row.

```xojo
Var rows() As Variant = model.FindAll("updated_at DESC")
// rows(0) is a Dictionary: {"id": "1", "title": "Hello", ...}
```

#### `FindByID(id As Integer) As Dictionary`

```
SELECT {Columns()} FROM {TableName()} WHERE id = ?
```

Returns the matching row as `Dictionary`, or `Nil` if not found. Always check for `Nil` before using the result.

```xojo
Var row As Dictionary = model.FindByID(42)
If row Is Nil Then
  // handle not found
End If
```

#### `Insert(data As Dictionary) As Integer`

Builds a parameterized `INSERT` from the dictionary keys. Returns the new `ROWID`. Uses `SQLitePreparedStatement` for safe parameter binding (SQL injection safe).

```xojo
Var data As New Dictionary()
data.Value("title") = "My Note"
data.Value("body") = "Content"
Var newID As Integer = model.Insert(data)
```

**Limitation:** `Insert` cannot express SQLite-side expressions like `datetime('now')`. For timestamp columns, use the escape hatch (see NoteModel below).

#### `UpdateByID(id As Integer, data As Dictionary)`

Builds a parameterized `UPDATE ... WHERE id = ?`. Only the keys present in the dictionary are updated.

```xojo
Var data As New Dictionary()
data.Value("title") = "New Title"
model.UpdateByID(42, data)
```

#### `DeleteByID(id As Integer)`

```
DELETE FROM {TableName()} WHERE id = ?
```

```xojo
model.DeleteByID(42)
```

### Protected Escape Hatch Methods

#### `OpenDB() As SQLiteDatabase`

Returns a raw DB connection for subclasses that need custom SQL. The subclass is responsible for `db.Close()`.

Use when:
- You need SQLite expressions like `datetime('now')` that can't be a bound `?` parameter
- You need `JOIN`, `GROUP BY`, aggregates, or complex `WHERE` clauses
- You need `db.LastRowID` after an insert

#### `RowToDict(rs As RowSet) As Dictionary`

Maps the current RowSet row to a `Dictionary` using the column names from `Columns()`. All values are stored as `StringValue` — this is intentional. JinjaX renders everything as strings, and ViewModels cast to integers via `Val()` when needed.

---

## NoteModel (Class)

**File:** `Models/NoteModel.xojo_code`

The concrete resource model for notes. Inherits `BaseModel`.

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

  // Escape hatch — SQLite expressions in SQL
  Function Create(title As String, body As String) As Integer
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
    Var newID As Integer = db.LastRowID
    db.Close()
    Return newID
  End Function

  Sub Update(id As Integer, title As String, body As String)
    Var db As SQLiteDatabase = OpenDB()
    db.ExecuteSQL("UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ?", title, body, id)
    db.Close()
  End Sub

End Class
```

### Why escape hatch for `Create` and `Update`?

`BaseModel.Insert` and `UpdateByID` use `Dictionary` parameter binding. `datetime('now')` is a SQLite-evaluated expression — it is not a value you can bind as a `?` parameter. If you bound the string `"datetime('now')"`, SQLite would store the literal text, not the timestamp.

The `OpenDB()` escape hatch lets `NoteModel` write raw SQL while staying within the three-layer architecture.

---

## CRUD Task Mapping

| User action | HTTP | ViewModel | Model call | SQL |
|-------------|------|-----------|------------|-----|
| View list | GET /notes | NotesListVM | `NoteModel.GetAll()` | `SELECT … ORDER BY updated_at DESC` |
| View one | GET /notes/:id | NotesDetailVM | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| Show new form | GET /notes/new | NotesNewVM | — | — |
| Submit new form | POST /notes | NotesCreateVM | `NoteModel.Create(title, body)` | `INSERT INTO notes (title, body) VALUES (?, ?)` |
| Show edit form | GET /notes/:id/edit | NotesEditVM | `NoteModel.GetByID(id)` | `SELECT … WHERE id = ?` |
| Submit edit form | POST /notes/:id | NotesUpdateVM | `NoteModel.Update(id, title, body)` | `UPDATE notes SET … WHERE id = ?` |
| Delete | POST /notes/:id/delete | NotesDeleteVM | `NoteModel.Delete(id)` | `DELETE FROM notes WHERE id = ?` |

---

## Benefits and Trade-offs

### Benefits

| Benefit | Why |
|---------|-----|
| No boilerplate | New resource model needs only `TableName()` + `Columns()` + thin wrappers |
| SQL injection safe | All user-supplied values go through `?` parameter binding |
| Thread-safe | Per-request connections, no shared mutable state |
| JinjaX compatible | All results are `Dictionary` — templates work immediately |
| Testable | XojoUnit tests hit a real SQLite DB (no mock needed; negligible overhead) |
| Clear escape hatch | `OpenDB()` is documented and intentional, not a workaround |

### Trade-offs

| Trade-off | Impact |
|-----------|--------|
| No ORM features | No associations (`has_many`, `belongs_to`), no lazy loading, no change tracking |
| String-only values | `RowToDict` stores everything as `StringValue`; ViewModels must cast (`Val(row.Value("id"))`) |
| No migration system | Schema changes require manual `ALTER TABLE` or dropping/recreating the DB in dev |
| `datetime` limitation | `BaseModel.Insert` cannot use `DEFAULT (datetime('now'))` — must use escape hatch |
| Hardcoded DB path | `DBAdapter.Connect()` path is hardcoded for development; production needs `SpecialFolder.ApplicationData` |

### When to use `BaseModel` vs escape hatch

Use inherited CRUD when:
- Simple `INSERT`/`UPDATE`/`SELECT` with plain values
- No SQLite expressions needed
- No `JOIN` or aggregate queries

Use `OpenDB()` escape hatch when:
- Timestamps: `datetime('now')`, `strftime(...)` must be in the SQL
- Complex queries: `JOIN`, `GROUP BY`, `HAVING`, subqueries
- You need `db.LastRowID` (after `INSERT`) — `BaseModel.Insert` returns it, but custom queries need direct access
- Batch operations: multiple statements in one connection

---

## Data Flow Walkthrough

### GET /notes (list all)

```
HandleURL → Router → NotesListVM.OnGet()
  │
  New NoteModel
  NoteModel.GetAll()
    │
    BaseModel.FindAll("updated_at DESC")
      │
      DBAdapter.Connect()
      SELECT id, title, body, created_at, updated_at FROM notes ORDER BY updated_at DESC
      │
      While Not rs.AfterLastRow
        RowToDict(rs) → Dictionary {"id": "3", "title": "...", ...}
        results.Add(row)
        rs.MoveToNextRow()
      Wend
      rs.Close()
      db.Close()
      │
      Return Variant() of Dictionary
  │
  ctx.Value("notes") = results
  Render("notes/list.html")
  │
  JinjaX: {% for note in notes %} {{ note.title }} {% endfor %}
  │
  response.Write(html)
```

### POST /notes (create)

```
HandleURL → Router → NotesCreateVM.OnPost()
  │
  GetFormValue("title") → FormParser → URL-decoded title string
  GetFormValue("body")  → FormParser → URL-decoded body string
  │
  validation: title empty?
    Yes → SetFlash("Title is required") → Redirect(302, "/notes/new")
    No  ↓
  │
  New NoteModel
  NoteModel.Create(title, body)
    │
    OpenDB()
    db.ExecuteSQL("INSERT INTO notes (title, body) VALUES (?, ?)", title, body)
    newID = db.LastRowID
    db.Close()
    Return newID
  │
  SetFlash("Note created successfully")
  Redirect(302, "/notes")
```

---

## Adding a New Resource

To add, say, `TagModel`:

1. **Create** `Models/TagModel.xojo_code`:

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

2. **Add** the table to `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT DEFAULT (datetime('now')))")
```

3. **Register** `Models/TagModel.xojo_code` in `mvvm.xojo_project` under the Models folder (Xojo IDE: drag file into project panel).

4. **Create ViewModels** in `ViewModels/Tags/` and **templates** in `templates/tags/`.
