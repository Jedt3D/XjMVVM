# Changelog

## [Unreleased]

### Fixed
- **Router path parameter extraction bug**: `ParsePath` used `pp.Mid(2)` to strip the `:` prefix from named segments (e.g., `:id`). Due to Xojo's 1-based `Mid`, `Mid(2)` returns everything from position 2 onward — which is correct for a 2-char string like `":id"` but wrong for the mental model. Replaced with `pp.Right(pp.Length - 1)` which is index-agnostic. This caused all path-param-dependent routes to silently fail:
  - `GET /notes/:id` — showed 404 for all notes
  - `GET /notes/:id/edit` — edit form never loaded
  - `POST /notes/:id` — `UPDATE WHERE id = 0` matched nothing
  - `POST /notes/:id/delete` — `DELETE WHERE id = 0` matched nothing

- **FormParser mixed-indexing bugs** (caused Create and Edit to silently discard form data):
  - `pair.Mid(eqPos + 1)` used `IndexOf`'s 0-based result with `Mid`'s 1-based position, causing the extracted value to include the leading `=` character. Fixed to `pair.Mid(eqPos + 2)`.
  - `DecodeURIComponent` loop `While i < s.Length` with 0-based counter `i` and 1-based `Mid` caused the last character of every key and value to be dropped (e.g., `"title"` → `"titl"`), so `HasKey("title")` always returned `False`. Fixed to `While i <= s.Length`.
  - Same loop's percent-decode guard `i + 2 < s.Length` prevented decoding `%XX` sequences at the end of a string. Fixed to `i + 2 <= s.Length`.

- **FormParser UTF-8 multi-byte decoding bug** (Thai and other non-ASCII characters saved as mojibake): `DecodeURIComponent` called `Chr(code)` on each decoded byte individually. `Chr()` maps integers to Unicode code points, so UTF-8 multi-byte sequences like `%E0%B8%97` (Thai `ท`) were converted to three separate wrong characters instead of one. Fixed by collecting all decoded bytes into a `MemoryBlock` and calling `DefineEncoding(..., Encodings.UTF8)` at the end, so the entire byte sequence is interpreted as UTF-8 correctly.

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
