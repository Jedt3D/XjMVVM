# MVVM — Xojo Web 2 SSR Framework

A server-side rendered (SSR) MVVM web framework built on Xojo Web 2, inspired by Flask/Django. Routes all HTTP requests through `WebApplication.HandleURL` and renders responses via the JinjaX template engine. Xojo's built-in WebPage GUI system is bypassed entirely.

**Xojo version:** 2025r3.1
**App type:** Web 2 (`IsWebProject=True`)
**Debug port:** 8080
**Bundle ID:** `com.worajedt.mvvm`

---

## Architecture

```
Browser → HandleURL → Router → ViewModel → Model → Database
                                    ↓
                          JinjaX Template → HTML Response
```

### Layers

| Layer | Location | Responsibility |
|---|---|---|
| Router | `Framework/Router.xojo_code` | Pattern matching, dispatch |
| BaseViewModel | `Framework/BaseViewModel.xojo_code` | Request/response lifecycle, flash, render |
| ViewModels | `ViewModels/` | One class per route; `OnGet()` / `OnPost()` |
| Models | `Models/` | Data access; return `Dictionary` or `Variant()` of `Dictionary` |
| Templates | `templates/` | JinjaX/Jinja2 HTML files |

### Key Rules

1. **Dictionary Data Contract** — JinjaX dot-notation (`{{ user.name }}`) requires `Dictionary` objects. Models always return `Dictionary` or `Variant()`, never custom class instances.
2. **No WebPage controls** — All rendering is via JinjaX templates. The `Default` page is a required placeholder only.
3. **Session isolation** — User-specific data lives in `Session` (per-request); `App` holds only shared, read-only singletons.
4. **Post/Redirect/Get** — All form submissions follow POST → process → `Redirect(302)` → GET.
5. **Dependency direction** — View → ViewModel → Model (never reversed).

---

## Project Structure

```
Framework/
  Router.xojo_code          # Route registration & dispatch; path param parsing
  BaseViewModel.xojo_code   # Base class: Handle(), Render(), Redirect(), GetFormValue(), SetFlash()
  FormParser.xojo_code      # URL-decode application/x-www-form-urlencoded POST bodies
  QueryParser.xojo_code     # URL-decode query strings
  RouteDefinition.xojo_code # Route data class

Models/
  NoteModel.xojo_code       # SQLite CRUD for notes table; all methods return Dictionary

ViewModels/
  HomeViewModel.xojo_code   # GET /
  Notes/
    NotesListVM.xojo_code   # GET  /notes
    NotesNewVM.xojo_code    # GET  /notes/new
    NotesCreateVM.xojo_code # POST /notes
    NotesDetailVM.xojo_code # GET  /notes/:id
    NotesEditVM.xojo_code   # GET  /notes/:id/edit
    NotesUpdateVM.xojo_code # POST /notes/:id
    NotesDeleteVM.xojo_code # POST /notes/:id/delete

JinjaXLib/                  # Full JinjaX source (Jinja2-compatible template engine in Xojo)

templates/
  layouts/base.html         # Site layout: nav, flash messages, content block
  home.html                 # Home page
  notes/
    list.html               # Notes list with Edit/Delete actions
    detail.html             # Single note view with Edit/Delete
    form.html               # Shared Create/Edit form (action switches on {{ note }})
  errors/
    404.html
    500.html

data/
  notes.sqlite              # SQLite database (auto-created on first run)
```

---

## Running the App

1. Open `mvvm.xojo_project` in the **Xojo 2025r3.1 IDE**.
2. Click **Run** (or press ⌘R).
3. The app starts on `http://localhost:8080`.
4. The `data/notes.sqlite` database is created automatically on first launch.

> There is no CLI build system. Testing requires the Xojo IDE.

---

## Routes

| Method | Path | ViewModel | Description |
|---|---|---|---|
| GET | `/` | HomeViewModel | Home page |
| GET | `/notes` | NotesListVM | List all notes |
| GET | `/notes/new` | NotesNewVM | New note form |
| POST | `/notes` | NotesCreateVM | Create note → redirect to list |
| GET | `/notes/:id` | NotesDetailVM | View note |
| GET | `/notes/:id/edit` | NotesEditVM | Edit form |
| POST | `/notes/:id` | NotesUpdateVM | Update note → redirect to detail |
| POST | `/notes/:id/delete` | NotesDeleteVM | Delete note → redirect to list |

---

## Current Status

**Phase 2 complete** — Full Notes CRUD is implemented and working.

- Core framework (Router, BaseViewModel, FormParser, QueryParser)
- JinjaX template engine integrated (full source under `JinjaXLib/`)
- SQLite-backed NoteModel with GetAll, GetByID, Create, Update, Delete
- Flash message system via Session
- POST/Redirect/GET pattern throughout
- Error pages (404, 500)

**Next:** Phase 3 — additional models, authentication, more resource types.

---

## Technical Notes

- **JinjaX as source**: The `.xojo_library` binary format cannot be referenced in Xojo text project format. The full JinjaX source tree is included under `JinjaXLib/` instead.
- **Template path**: `FileSystemLoader(FolderItem)` with an absolute path to `templates/` is used for debug runs, since the debug build output directory differs from the project directory.
- **DB path**: Currently hardcoded to the project `data/` directory for development. Production builds should use `SpecialFolder.ApplicationData`.
- **String indexing mismatch**: `String.IndexOf()` is **0-based** but `String.Mid()` is **1-based** — they cannot be used together without an offset correction. `Left(n)` and `Right(n)` are count-based (index-agnostic) and are safer when possible.
- **UTF-8 percent-decoding**: Use `MemoryBlock` + `DefineEncoding(..., Encodings.UTF8)` to decode URL-encoded bodies. `Chr(code)` per byte corrupts any multi-byte character (Thai, emoji, etc.).
