---
title: "Protected Routes & User Scoping"
description: How to protect routes behind authentication and scope data per user so each user only sees their own records.
---

# Protected Routes & User Scoping

XjMVVM v0.9.3 introduced two related features: **protected routes** that require authentication, and **user-scoped data** that isolates records per user. Together they ensure that users must log in to access the app and can only see their own notes.

## Protected Routes

Every ViewModel that should require authentication calls a guard method at the top of `OnGet()` or `OnPost()`. There are two guards — one for HTML routes, one for API routes.

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 10
#lineWidth: 1.5
[Incoming Request] -> [ViewModel.OnGet() / OnPost()]
[ViewModel.OnGet() / OnPost()] -> [HTML route?]
[HTML route?] yes -> [RequireLogin()|ParseAuthCookie()\nRedirect /login?next=url]
[HTML route?] no -> [RequireLoginJSON()|ParseAuthCookie()\n401 JSON error]
[RequireLogin()] authenticated -> [Handler continues]
[RequireLogin()] not authenticated -> [302 Redirect to /login]
[RequireLoginJSON()] authenticated -> [Handler continues]
[RequireLoginJSON()] not authenticated -> [401 JSON response]
-->
<!-- ascii
Incoming Request
  +-- ViewModel.OnGet() / OnPost()
        +-- HTML route? -> RequireLogin()
        |     +-- authenticated -> handler continues
        |     +-- not authenticated -> 302 /login?next=url
        +-- API route? -> RequireLoginJSON()
              +-- authenticated -> handler continues
              +-- not authenticated -> 401 {"error":"Authentication required"}
-->
<!-- /diagram -->

### HTML route guard — `RequireLogin()`

```xojo
Sub OnGet()
  If RequireLogin() Then Return
  // ... handler logic (only runs if authenticated)
End Sub
```

`RequireLogin()` calls `ParseAuthCookie()` to verify the HMAC-signed `mvvm_auth` cookie. If invalid or missing, it redirects to `/login?next=<encoded-current-path>` so the user returns to their original destination after logging in.

### API route guard — `RequireLoginJSON()`

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... handler logic
End Sub
```

API clients (JavaScript `fetch`, mobile apps, CLI tools) cannot follow HTML redirects. `RequireLoginJSON()` returns a 401 status with a JSON error body instead:

```json
{"error":"Authentication required"}
```

### Which routes are protected?

All 19 ViewModel routes require authentication:

| Resource | Routes | Guard |
|----------|--------|-------|
| Notes (7) | `/notes`, `/notes/new`, `/notes/:id`, `/notes/:id/edit`, `POST /notes`, `POST /notes/:id`, `POST /notes/:id/delete` | `RequireLogin()` |
| Tags (7) | `/tags`, `/tags/new`, `/tags/:id`, `/tags/:id/edit`, `POST /tags`, `POST /tags/:id`, `POST /tags/:id/delete` | `RequireLogin()` |
| API (5) | `/api/notes`, `/api/notes/:id`, `POST /api/notes`, `/api/tags`, `/api/tags/:id` | `RequireLoginJSON()` |

Auth routes (`/login`, `/signup`, `/logout`) are **not** protected — users must be able to reach them without being logged in.

### Post-login redirect with `next` parameter

When `RequireLogin()` redirects to `/login`, it appends the current URL as a query parameter:

```
/login?next=%2Fnotes%2F42%2Fedit
```

`LoginVM` reads this `next` parameter and passes it to `RedirectWithAuth()` after successful login, sending the user back to where they were trying to go:

```xojo
// In LoginVM.OnPost() — after successful verification:
Var nextURL As String = GetFormValue("next")
If nextURL.Length = 0 Then nextURL = "/notes"
RedirectWithAuth(nextURL, userID, username)
```

---

## User-Scoped Data

Notes are scoped per user — each user has their own set of notes. Tags remain global (shared across all users) but still require login to access.

### Database schema change

The `notes` table includes a `user_id` column:

```sql
notes (id, title, body, created_at, updated_at, user_id)
```

The migration in `DBAdapter.InitDB()` adds the column to existing tables:

```xojo
// Add user_id column if it doesn't exist (migration for existing databases)
Var rs As RowSet = db.SelectSQL( _
  "SELECT COUNT(*) AS cnt FROM pragma_table_info('notes') WHERE name='user_id'")
If rs.Column("cnt").IntegerValue = 0 Then
  db.ExecuteSQL("ALTER TABLE notes ADD COLUMN user_id INTEGER NOT NULL DEFAULT 0")
  db.ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id)")
End If
```

`DEFAULT 0` ensures existing notes (created before auth existed) remain accessible. New notes get the authenticated user's ID.

### NoteModel — user-scoped methods

Every `NoteModel` method requires a `userID` parameter. Every SQL query includes `WHERE user_id = ?`:

```xojo
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
  // ...
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
    "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?", _
    title, body, id, userID)
  db.Close()
End Sub

Sub Delete(id As Integer, userID As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("DELETE FROM notes WHERE id = ? AND user_id = ?", id, userID)
  db.Close()
End Sub
```

Additional user-scoped methods for pagination:

```xojo
Function CountForUser(userID As Integer) As Integer
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL("SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ?", userID)
  Var count As Integer = rs.Column("cnt").IntegerValue
  rs.Close()
  db.Close()
  Return count
End Function

Function FindPaginatedForUser(userID As Integer, limit As Integer, offset As Integer, _
    orderBy As String) As Variant()
  // SELECT ... FROM notes WHERE user_id = ? ORDER BY ... LIMIT ? OFFSET ?
End Function
```

### ViewModel pattern — passing userID

Every Notes ViewModel reads `CurrentUserID()` (from the auth cookie) and passes it to the model:

```xojo
Sub OnGet()
  If RequireLogin() Then Return

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll(userID)

  Var ctx As New Dictionary
  ctx.Value("notes") = notes
  Render("notes/list.html", ctx)
End Sub
```

This pattern ensures:

1. The user must be authenticated (`RequireLogin`)
2. The user can only see their own notes (`GetAll(userID)`)
3. The model enforces scoping at the SQL level (`WHERE user_id = ?`)

### Ownership enforcement

`GetByID`, `Update`, and `Delete` all include `AND user_id = ?` in their WHERE clause. If user A tries to access user B's note by guessing the ID, the query returns `Nil` (or affects 0 rows), and the ViewModel returns a 404:

```xojo
// In NotesDetailVM.OnGet():
Var note As Dictionary = model.GetByID(id, userID)
If note Is Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

There is no separate "you don't own this" error — the note simply does not exist from the current user's perspective.

### Tags — global but protected

Tags are shared across all users. They require login but are not scoped by user:

```xojo
// In TagsListVM.OnGet():
Sub OnGet()
  If RequireLogin() Then Return    // must be logged in
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()  // no userID — tags are global
  // ...
End Sub
```

This design means all users share the same tag vocabulary. A tag created by one user is available to all users.

---

## Testing Ownership

`NoteOwnershipTests` verifies that user scoping works correctly:

```xojo
Sub WrongUserCannotReadTest()
  Var model As New NoteModel()
  Var id As Integer = model.Create("Secret", "body", 999)

  // User 888 should NOT see user 999's note
  Var note As Dictionary = model.GetByID(id, 888)
  Assert.IsNil(note)
End Sub

Sub WrongUserCannotDeleteTest()
  Var model As New NoteModel()
  Var id As Integer = model.Create("Secret", "body", 999)

  // User 888 tries to delete user 999's note — should have no effect
  model.Delete(id, 888)

  // Note should still exist for user 999
  Var note As Dictionary = model.GetByID(id, 999)
  Assert.IsNotNil(note)
End Sub
```

These tests use different `userID` values (999 vs 888) to prove that SQL-level scoping prevents cross-user access.
