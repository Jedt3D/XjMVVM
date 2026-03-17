# Database Getting Started

A step-by-step tutorial for adding a new database-backed resource to this Xojo MVVM project, from existing SQLite table to fully working CRUD.

This tutorial creates a `Tag` resource as the example.

---

## Prerequisites

- The project runs successfully (`http://localhost:8080/notes` works).
- You understand the MVVM architecture (see `README.md`).
- The `DBAdapter` and `BaseModel` framework classes are in place.

---

## Step 1: Define the Schema

Open `Framework/DBAdapter.xojo_code` and add a `CREATE TABLE` statement in `InitDB()`:

```vb
Sub InitDB()
  Var db As SQLiteDatabase = Connect()

  // Existing notes table
  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS notes (...)")

  // New tags table
  db.ExecuteSQL("CREATE TABLE IF NOT EXISTS tags (" + _
    "id INTEGER PRIMARY KEY AUTOINCREMENT, " + _
    "name TEXT NOT NULL, " + _
    "created_at TEXT DEFAULT (datetime('now')))")

  db.Close()
End Sub
```

`InitDB()` is called from `App.Opening` each time the app starts. `CREATE TABLE IF NOT EXISTS` is safe to run repeatedly.

---

## Step 2: Create the Model

Create `Models/TagModel.xojo_code`. Inherit `BaseModel` and override the two required methods. Use `OpenDB()` for any SQL that can't be expressed as a generic Dictionary operation.

```vb
#tag Class
Protected Class TagModel
Inherits BaseModel
  #tag Method, Flags = &h1
    Protected Function TableName() As String
      Return "tags"
    End Function
  #tag EndMethod

  #tag Method, Flags = &h1
    Protected Function Columns() As String
      Return "id, name, created_at"
    End Function
  #tag EndMethod

  #tag Method, Flags = &h0
    Function GetAll() As Variant()
      Return FindAll("name ASC")
    End Function
  #tag EndMethod

  #tag Method, Flags = &h0
    Function GetByID(id As Integer) As Dictionary
      Return FindByID(id)
    End Function
  #tag EndMethod

  #tag Method, Flags = &h0
    Function Create(name As String) As Integer
      Var db As SQLiteDatabase = OpenDB()
      db.ExecuteSQL("INSERT INTO tags (name) VALUES (?)", name)
      Var newID As Integer = db.LastRowID
      db.Close()
      Return newID
    End Function
  #tag EndMethod

  #tag Method, Flags = &h0
    Sub Update(id As Integer, name As String)
      Var db As SQLiteDatabase = OpenDB()
      db.ExecuteSQL("UPDATE tags SET name = ? WHERE id = ?", name, id)
      db.Close()
    End Sub
  #tag EndMethod

  #tag Method, Flags = &h0
    Sub Delete(id As Integer)
      DeleteByID(id)
    End Sub
  #tag EndMethod

End Class
#tag EndClass
```

**Design decisions:**
- `GetAll` and `GetByID` are thin wrappers — they exist to give callers a domain-specific API (`model.GetAll()`) without exposing BaseModel's generic naming.
- `Create` and `Update` use the `OpenDB()` escape hatch because they need specific SQL (e.g. not setting `created_at` so the SQLite `DEFAULT` applies).
- `Delete` delegates to `DeleteByID` directly.

---

## Step 3: Register the Model File

Edit `mvvm.xojo_project` and add the new class entry inside the Models folder block. Find the line for `NoteModel` and add after it:

```
Class=TagModel;Models/TagModel.xojo_code;&hFFFFFFFFABC12FFF;&hFFFFFFFF840D1FFF;false
```

The hex ID must be unique. You can generate one by taking an unused hex value (check existing IDs). The parent ID (`&hFFFFFFFF840D1FFF`) is the Models folder ID.

**Alternatively:** Reload the project in Xojo IDE and drag `Models/TagModel.xojo_code` into the Models group — the IDE assigns a proper ID automatically.

---

## Step 4: Create the ViewModels

One ViewModel per route. For Tags CRUD:

| Route | File | Class |
|-------|------|-------|
| `GET /tags` | `ViewModels/Tags/TagsListVM.xojo_code` | `TagsListVM` |
| `GET /tags/new` | `ViewModels/Tags/TagsNewVM.xojo_code` | `TagsNewVM` |
| `POST /tags` | `ViewModels/Tags/TagsCreateVM.xojo_code` | `TagsCreateVM` |
| `GET /tags/:id` | `ViewModels/Tags/TagsDetailVM.xojo_code` | `TagsDetailVM` |
| `POST /tags/:id/delete` | `ViewModels/Tags/TagsDeleteVM.xojo_code` | `TagsDeleteVM` |

Example — `TagsListVM`:

```vb
#tag Class
Protected Class TagsListVM
Inherits BaseViewModel
  #tag Method, Flags = &h0
    Sub OnGet()
      Var model As New TagModel()
      Var ctx As New JinjaX.JinjaContext()
      ctx.Set("tags", model.GetAll())
      Render("tags/list.html", ctx)
    End Sub
  #tag EndMethod
End Class
#tag EndClass
```

Example — `TagsCreateVM` (POST/Redirect/GET):

```vb
#tag Class
Protected Class TagsCreateVM
Inherits BaseViewModel
  #tag Method, Flags = &h0
    Sub OnPost()
      Var name As String = GetFormValue("name")
      If name.Length = 0 Then
        SetFlash("Name is required", "error")
        Redirect("/tags/new")
        Return
      End If
      Var model As New TagModel()
      Call model.Create(name)
      SetFlash("Tag created")
      Redirect("/tags")
    End Sub
  #tag EndMethod
End Class
#tag EndClass
```

---

## Step 5: Register Routes in App.xojo_code

Add factory functions and route registrations to `App.xojo_code`:

```vb
// In Opening event, with the other routes:
mRouter.Get("/tags", AddressOf CreateTagsListVM)
mRouter.Get("/tags/new", AddressOf CreateTagsNewVM)
mRouter.Post("/tags", AddressOf CreateTagsCreateVM)
mRouter.Get("/tags/:id", AddressOf CreateTagsDetailVM)
mRouter.Post("/tags/:id/delete", AddressOf CreateTagsDeleteVM)

// Add private factory functions:
Private Function CreateTagsListVM() As BaseViewModel
  Return New TagsListVM()
End Function
// ... repeat for each route
```

---

## Step 6: Create the Templates

Create `templates/tags/list.html`:

```html
{% extends "layouts/base.html" %}
{% block title %}Tags{% endblock %}
{% block content %}
<h1>Tags</h1>
<a href="/tags/new" class="btn btn-primary">New Tag</a>
<ul>
{% for tag in tags %}
  <li>{{ tag.name }} — <a href="/tags/{{ tag.id }}/delete" ...>delete</a></li>
{% endfor %}
</ul>
{% endblock %}
```

Remember: JinjaX dot-notation (`{{ tag.name }}`) only works because `TagModel.GetAll()` returns `Variant()` of `Dictionary` — not class instances.

---

## Step 7: Add Nav Link (optional)

Edit `templates/layouts/base.html` and add a Tags link in `<nav>`:

```html
<a href="/tags">Tags</a>
```

---

## Step 8: Register ViewModels in the Project File

Add entries to `mvvm.xojo_project` for each new ViewModel file, similar to how Notes ViewModels are registered. Or reload in the Xojo IDE and add via Project > Add Files.

---

## Step 9: Test

1. Run the project in Xojo IDE (⌘R).
2. Visit `http://localhost:8080/tags` — should show an empty list.
3. Create a tag via the form.
4. Open `http://localhost:8080/tests` to run the unit test suite.

---

## Quick Checklist

- [ ] Schema: `CREATE TABLE IF NOT EXISTS` added to `DBAdapter.InitDB()`
- [ ] Model: `Models/TagModel.xojo_code` created, inherits `BaseModel`
- [ ] Model registered in `mvvm.xojo_project`
- [ ] ViewModels created for each route
- [ ] ViewModels registered in `mvvm.xojo_project`
- [ ] Routes registered in `App.Opening`
- [ ] Factory functions added to `App`
- [ ] Templates created under `templates/tags/`
- [ ] Nav link added (optional)
