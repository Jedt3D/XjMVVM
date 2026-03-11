# Changelog

## [Unreleased]

### Fixed
- **Router path parameter extraction bug**: `ParsePath` used `pp.Mid(2)` (0-based) to strip the `:` prefix from named segments (e.g., `:id`), which extracted only the last character (`"d"` from `":id"`) instead of the full name (`"id"`). Changed to `pp.Mid(1)`. This caused all path-param-dependent routes to silently fail:
  - `GET /notes/:id` — showed 404 for all notes (id resolved to 0)
  - `GET /notes/:id/edit` — same; edit form never loaded
  - `POST /notes/:id` — `UPDATE WHERE id = 0` matched nothing; data never updated
  - `POST /notes/:id/delete` — `DELETE WHERE id = 0` matched nothing; note never deleted

---

## [0.2.0] — 2026-03-12

### Added
- **Notes CRUD** — full Create/Read/Update/Delete for notes resource
  - `NoteModel` — SQLite-backed data layer; all methods return `Dictionary` / `Variant()` of `Dictionary`
  - `NotesListVM` — `GET /notes`; lists all notes ordered by `updated_at DESC`
  - `NotesNewVM` — `GET /notes/new`; renders blank note form
  - `NotesCreateVM` — `POST /notes`; validates, inserts, redirects to list
  - `NotesDetailVM` — `GET /notes/:id`; shows single note
  - `NotesEditVM` — `GET /notes/:id/edit`; renders pre-filled edit form
  - `NotesUpdateVM` — `POST /notes/:id`; validates, updates, redirects to detail
  - `NotesDeleteVM` — `POST /notes/:id/delete`; deletes, redirects to list
- **Notes templates** — `notes/list.html`, `notes/detail.html`, `notes/form.html` (shared create/edit)
- **SQLite database** — auto-created at `data/notes.sqlite` on first run via `NoteModel.InitDB()`
- **Flash messages** — `SetFlash()` / `GetFlash()` on `Session`; auto-injected by `BaseViewModel.Render()`
- **Error pages** — `errors/404.html`, `errors/500.html`; rendered by `Router.Serve404` / `Serve500`

### Changed
- `App.Opening` — registers all 8 Notes CRUD routes; calls `NoteModel.InitDB()` at startup
- `BaseViewModel.Redirect()` — now correctly uses its `statusCode` parameter (was already correct; confirmed no regression)

---

## [0.1.0] — 2026-03-12

### Added
- **Core framework**
  - `Router` — HTTP method + path pattern matching with named segments (`:param`); dispatches to ViewModel factories
  - `BaseViewModel` — request lifecycle (`Handle` → `OnGet`/`OnPost`), `Render`, `Redirect`, `GetFormValue`, `GetParam`, `SetFlash`, `WriteJSON`, `RenderError`
  - `FormParser` — URL-decodes `application/x-www-form-urlencoded` POST bodies into `Dictionary`
  - `QueryParser` — URL-decodes query strings into `Dictionary`
  - `RouteDefinition` — data class for method, pattern, factory
- **JinjaX template engine** — full source under `JinjaXLib/` (Jinja2-compatible: `{{ }}`, `{% %}`, `extends`, `block`, `include`, `for`, `if`, filters, autoescape)
- **Session** — extends `WebSession` with `SetFlash` / `GetFlash` for one-shot flash messages
- **Home page** — `HomeViewModel` + `templates/home.html`
- **Base layout** — `templates/layouts/base.html` with nav, flash display, content block
- **Default WebPage** — required Xojo Web 2 placeholder
