---
title: "JSON API & Static Serving"
description: How XjMVVM exposes a JSON API alongside its SSR routes, and how the built-in static file server works.
---

# JSON API & Static Serving

XjMVVM can serve both server-rendered HTML pages **and** a JSON API from the same application — no separate process or framework needed. The API uses the same Router, the same ViewModels pattern, and the same Models. The only difference is the response format.

---

## JSONSerializer module

**File:** `Framework/JSONSerializer.xojo_code`

A simple module that converts `Dictionary` and `Variant()` of `Dictionary` into JSON strings. It does not depend on any external library — just string manipulation.

```xojo
Module JSONSerializer

  // Escape a value for use inside a JSON string literal
  Function EscapeString(s As String) As String
    s = s.ReplaceAll("\", "\\")
    s = s.ReplaceAll(Chr(34), "\""")  // double-quote
    s = s.ReplaceAll(Chr(10), "\n")   // newline
    s = s.ReplaceAll(Chr(13), "\r")   // carriage return
    s = s.ReplaceAll(Chr(9),  "\t")   // tab
    Return s
  End Function

  // Serialize a Dictionary of string values to a JSON object
  Function DictToJSON(d As Dictionary) As String
    Var parts() As String
    For Each key As Variant In d.Keys
      Var k As String = EscapeString(key.StringValue)
      Var v As String = EscapeString(d.Value(key).StringValue)
      parts.Add("""" + k + """" + ":" + """" + v + """")
    Next
    Return "{" + String.FromArray(parts, ",") + "}"
  End Function

  // Serialize a Variant() of Dictionary to a JSON array
  Function ArrayToJSON(items() As Variant) As String
    Var parts() As String
    For Each item As Variant In items
      Var d As Dictionary = item
      parts.Add(DictToJSON(d))
    Next
    Return "[" + String.FromArray(parts, ",") + "]"
  End Function

End Module
```

!!! note
    All values are serialised as JSON strings — no numeric or boolean types. This is consistent with how `RowToDict` works: all database values are stored as `StringValue`. Consumers of the API should parse numbers from strings as needed.

### `WriteJSON` on BaseViewModel

```xojo
Sub WriteJSON(jsonString As String)
  Response.Header("Content-Type") = "application/json; charset=utf-8"
  Response.Write(jsonString)
End Sub
```

The content-type signals JSON to clients. No ViewModel needs to set headers directly — just call `WriteJSON(...)` with the serialised string.

---

## API ViewModels

All API ViewModels live under `ViewModels/API/`. They follow the same `OnGet()`/`OnPost()` pattern as SSR ViewModels — the only difference is that they call `WriteJSON()` instead of `Render()`.

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[GET /api/notes] -> [NotesAPIListVM|model.GetAll()\nArrayToJSON()]
[GET /api/notes/:id] -> [NotesAPIDetailVM|model.GetByID(id)\nGetTagsForNote(id)\nembed tags in JSON]
[POST /api/notes] -> [NotesAPICreateVM|validate\nmodel.Create()\n201 Created]
[GET /api/tags] -> [TagsAPIListVM|model.GetAll()\nArrayToJSON()]
[GET /api/tags/:id] -> [TagsAPIDetailVM|model.GetByID(id)\nDictToJSON()]
-->
<!-- ascii
GET  /api/notes       → NotesAPIListVM   → ArrayToJSON(notes)
GET  /api/notes/:id   → NotesAPIDetailVM → note + embedded tags array
POST /api/notes       → NotesAPICreateVM → 201 Created + new note JSON
GET  /api/tags        → TagsAPIListVM    → ArrayToJSON(tags)
GET  /api/tags/:id    → TagsAPIDetailVM  → DictToJSON(tag)
-->
<!-- /diagram -->

### NotesAPIListVM — `GET /api/notes`

```xojo
Sub OnGet()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(notes))
End Sub
```

Response: `[{"id":"1","title":"Hello","body":"...","created_at":"...","updated_at":"..."},...]`

### NotesAPIDetailVM — `GET /api/notes/:id`

Returns the note with an embedded `tags` array:

```xojo
Sub OnGet()
  Var id As Integer = Val(GetParam("id"))
  Var model As New NoteModel()
  Var note As Dictionary = model.GetByID(id)

  If note = Nil Then
    Response.Status = 404
    WriteJSON("{""error"":""Note not found""}")
    Return
  End If

  // Embed tags array inside the note JSON object
  Var tags() As Variant = model.GetTagsForNote(id)
  Var noteJSON As String = JSONSerializer.DictToJSON(note)
  Var tagsJSON As String = JSONSerializer.ArrayToJSON(tags)
  noteJSON = noteJSON.Left(noteJSON.Length - 1) + ",""tags"":" + tagsJSON + "}"
  WriteJSON(noteJSON)
End Sub
```

The tags array is injected by string manipulation — removing the closing `}` and appending `,"tags":[...]}`  before closing again. This is intentional: `JSONSerializer.DictToJSON` only handles flat string dictionaries; embedding a nested array requires manual composition.

!!! note
    This approach works reliably because `DictToJSON` always produces a valid JSON object ending with `}`. If the serialiser changes, this injection point must be reviewed.

### NotesAPICreateVM — `POST /api/notes`

```xojo
Sub OnPost()
  Var title As String = GetFormValue("title").Trim()
  Var body As String = GetFormValue("body")

  If title.Length = 0 Then
    Response.Status = 422      // Unprocessable Entity — validation error
    WriteJSON("{""error"":""Title is required""}")
    Return
  End If

  Var model As New NoteModel()
  Var newID As Integer = model.Create(title, body)
  Var note As Dictionary = model.GetByID(newID)

  Response.Status = 201        // Created
  WriteJSON(JSONSerializer.DictToJSON(note))
End Sub
```

Status codes used by the API: **200** for successful reads, **201** for successful creation, **404** for not found, **422** for validation failure.

### TagsAPIListVM — `GET /api/tags`

```xojo
Sub OnGet()
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(tags))
End Sub
```

### TagsAPIDetailVM — `GET /api/tags/:id`

```xojo
Sub OnGet()
  Var id As Integer = Val(GetParam("id"))
  Var model As New TagModel()
  Var tag As Dictionary = model.GetByID(id)

  If tag = Nil Then
    Response.Status = 404
    WriteJSON("{""error"":""Tag not found""}")
    Return
  End If

  WriteJSON(JSONSerializer.DictToJSON(tag))
End Sub
```

---

## API routes

Registered in `App.Opening` alongside the SSR routes:

```xojo
// JSON API routes
mRouter.Get("/api/notes",       AddressOf CreateNotesAPIListVM)
mRouter.Post("/api/notes",      AddressOf CreateNotesAPICreateVM)
mRouter.Get("/api/notes/:id",   AddressOf CreateNotesAPIDetailVM)
mRouter.Get("/api/tags",        AddressOf CreateTagsAPIListVM)
mRouter.Get("/api/tags/:id",    AddressOf CreateTagsAPIDetailVM)
```

The `/api/` prefix separates API routes from SSR routes by convention — the Router treats them identically.

---

## Static file server

**File:** `App.xojo_code` (`ServeStatic` method + `HandleURL` dispatch)

The static file server makes the developer docs site accessible directly from the running app at `/dist/*`. Files are served from `templates/dist/` — the same folder the `build.py` script outputs to.

### HandleURL dispatch

```xojo
// Redirect bare /dist to /dist/
If p = "/dist" Then
  response.Status = 302
  response.Header("Location") = "/dist/"
  Return True
End If
// Serve anything under /dist/
If p.Left(6) = "/dist/" Then
  Return ServeStatic(p.Middle(6), response)
End If
```

`p.Middle(6)` strips the `/dist/` prefix (6 characters, 0-based) and passes the remainder to `ServeStatic`.

### ServeStatic — path traversal prevention

```xojo
Private Function ServeStatic(relativePath As String, response As WebResponse) As Boolean
  // Start from the known safe root
  Var f As FolderItem = App.ExecutableFile.Parent.Child("templates").Child("dist")

  // Walk each path segment individually — never concatenate raw user input
  Var parts() As String = relativePath.Split("/")
  For Each part As String In parts
    If part = "" Or part = "." Or part = ".." Then Continue  // skip dangerous segments
    f = f.Child(part)
    If f Is Nil Or Not f.Exists Then
      response.Status = 404
      response.Header("Content-Type") = "text/plain"
      response.Write("Not found")
      Return True
    End If
  Next

  // Directory → try index.html automatically
  If f.IsFolder Then
    f = f.Child("index.html")
    If f Is Nil Or Not f.Exists Then
      response.Status = 404
      response.Write("Not found")
      Return True
    End If
  End If
  // ... content-type + file read ...
End Function
```

!!! warning
    **Never** build a file path by concatenating a raw URL string. A request for `/dist/../data/notes.sqlite` would serve the database file if paths were concatenated directly. Walking each segment via `Child()` and rejecting `..` and `.` prevents path traversal attacks entirely.

### Content-Type mapping

```xojo
Var ext As String = f.Name.Lowercase
Var ct As String = "application/octet-stream"
If ext.EndsWith(".html")  Then ct = "text/html; charset=utf-8"
If ext.EndsWith(".css")   Then ct = "text/css"
If ext.EndsWith(".js")    Then ct = "application/javascript"
If ext.EndsWith(".svg")   Then ct = "image/svg+xml"
If ext.EndsWith(".png")   Then ct = "image/png"
If ext.EndsWith(".ico")   Then ct = "image/x-icon"
If ext.EndsWith(".woff2") Then ct = "font/woff2"
```

Unknown extensions fall back to `application/octet-stream`. Add new entries here if serving additional file types.

### Accessing the docs

With the app running on port 8080, the developer docs are available at:

```
http://localhost:8080/dist/en/index.html
http://localhost:8080/dist/th/index.html
http://localhost:8080/dist/jp/index.html
```

The `/dist/` route is handled before the SSR router so the static server always takes priority for that prefix.
