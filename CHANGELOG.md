# Changelog

## [0.4.2] — 2026-03-12

### Fixed
- **Hardcoded Mac paths removed** — `DBAdapter.Connect()` and `App.Opening` both had absolute paths baked into the binary (`/Users/worajedt/Xojo Projects/mvvm/...`) causing 500 errors on the Linux production server. Both now use `App.ExecutableFile.Parent` to resolve paths relative to wherever the binary is deployed.
  - `DBAdapter.Connect()` — DB file is now `<binary_dir>/data/notes.sqlite`; the `data/` folder is auto-created on first run if it does not exist.
  - `App.Opening` — templates are now loaded from `<binary_dir>/templates/`.
- **Deploy layout** — copy the compiled binary + `templates/` folder to the server. The `data/` folder is created automatically.

---

## [0.4.1] — 2026-03-12

### Added
- **`Routing.md`** — comprehensive architecture document covering: SSR vs Xojo WebSocket world, `HandleURL` decision tree, the `request.Path` leading-slash quirk, the `/tests` redirect dance, and how to navigate between the two worlds.
- **XjMVVM toolbar button** on `XojoUnitTestPage` — calls `Session.GoToURL("/")` to navigate back to the MVVM home page from the XojoUnit test runner.

### Fixed
- **`/tests` URL now correctly loads `XojoUnitTestPage`** via a redirect dance: `/tests` → 302 → `/?_xojo=1` → Xojo serves bootstrap HTML → `Default.Shown` trampolines to `XojoUnitTestPage`. Previous attempts all silently failed due to the `request.Path` normalization bug below.
- **`request.Path` normalization** — Xojo Web 2 omits the leading `/` from `request.Path` (`"tests"` not `"/tests"`). All path checks in `HandleURL` now normalize first (`If p.Left(1) <> "/" Then p = "/" + p`). This was the root cause of every failed `/tests` route attempt.
- **`Router.Route()` converted from `Sub` to `Function As Boolean`** — returns `True` if a route matched, `False` if not. `HandleURL` propagates `False` to Xojo so Xojo can serve its own JS/CSS framework files during the bootstrap sequence. Without this, `/framework/Xojo.js` was blocked and the WebSocket session could never establish.
- **`mvvm.xojo_project` `DefaultWindow`** changed from `XojoUnitTestPage` to `Default` — `XojoUnitTestPage` crashed when set as `DefaultWindow` because `Opening` runs toolbar setup before the WebSocket session is fully established.
- **`Default.xojo_code` `Shown` event** added as trampoline — after the session is established, navigates to `XojoUnitTestPage` via `(New XojoUnitTestPage).Show()`.

---

## [0.4.0] — 2026-03-12

### Added
- **`DBAdapter` module** (`Framework/DBAdapter.xojo_code`) — SQLite connection factory with `Connect()` (per-request, thread-safe) and `InitDB()` (schema bootstrap). Schema ownership moved out of `NoteModel` into this shared module.
- **`BaseModel` class** (`Framework/BaseModel.xojo_code`) — repository base class with generic CRUD: `FindAll(orderBy)`, `FindByID(id)`, `Insert(data)`, `UpdateByID(id, data)`, `DeleteByID(id)`. Subclasses override `TableName()` and `Columns()` only. `OpenDB()` and `RowToDict()` protected for escape-hatch custom SQL.
- **`Tests/` folder** with three XojoUnit TestGroup classes:
  - `DBAdapterTests` — `ConnectReturnsValidConnectionTest`
  - `BaseModelTests` — `FindAllReturnsArrayTest`, `InsertAndFindByIDTest`, `UpdateByIDChangesValuesTest`, `DeleteByIDRemovesRowTest`, `FindByIDReturnsNilForMissingTest`
  - `NoteModelTests` — `CreateReturnsIDTest`, `GetAllIncludesNewNoteTest`, `GetByIDMatchesTitleTest`, `UpdateChangesTitleTest`, `DeleteRemovesNoteTest`
- **`/tests` route** — `App.HandleURL` intercepts `/tests` and shows `XojoUnitTestPage` in-session. Link added to nav (`target="_blank"`).
- **`DatabaseModel.md`** — detailed reference for DBAdapter, BaseModel, NoteModel with code walkthrough.
- **`DatabaseGettingStarted.md`** — step-by-step tutorial for adding a new database-backed resource.

### Changed
- **`NoteModel`** now inherits `BaseModel`. `GetAll()` → `FindAll()`, `GetByID()` → `FindByID()`, `Delete()` → `DeleteByID()`. `Create()` and `Update()` keep custom SQL via `OpenDB()` escape hatch (for `datetime('now')` expressions that can't be bound as parameters). `InitDB()` removed — moved to `DBAdapter.InitDB()`.
- **`App.Opening`** calls `DBAdapter.InitDB()` instead of `NoteModel.InitDB()`. `mDB` property removed (connections created per-request via `DBAdapter.Connect()`).
- **`WebTestController.InitializeTestGroups()`** registers `DBAdapterTests`, `BaseModelTests`, `NoteModelTests`.

---

## [0.3.0] — 2026-03-12

### Changed
- **Migrate `Mid()` → `String.Middle()` in Framework parsers**: `Mid()` is a legacy 1-based VB function. The modern Xojo API (`String.Middle`) is 0-based and aligns directly with `IndexOf`, arrays, and all other Xojo 2025 indexing. Updated `FormParser` and `QueryParser` to use `String.Middle` throughout; loop bounds simplified to `i = 0` / `While i < s.Length`.

### Fixed
- **Router path parameter extraction bug**: `ParsePath` used `pp.Mid(2)` to strip the `:` prefix from named segments (e.g., `:id`). Due to Xojo's 1-based `Mid`, `Mid(2)` returns everything from position 2 onward — which is correct for a 2-char string like `":id"` but wrong for the mental model. Replaced with `pp.Right(pp.Length - 1)` which is index-agnostic. This caused all path-param-dependent routes to silently fail:
  - `GET /notes/:id` — showed 404 for all notes
  - `GET /notes/:id/edit` — edit form never loaded
  - `POST /notes/:id` — `UPDATE WHERE id = 0` matched nothing
  - `POST /notes/:id/delete` — `DELETE WHERE id = 0` matched nothing

- **QueryParser `?` stripping bug**: `qs.Mid(1)` (1-based) returned the full string including the leading `?`, so it was never stripped. Fixed to `qs.Middle(1)` (0-based index 1 = second character).

- **FormParser mixed-indexing bugs** (caused Create and Edit to silently discard form data):
  - `pair.Mid(eqPos + 1)` used `IndexOf`'s 0-based result with `Mid`'s 1-based position, causing the extracted value to include the leading `=` character.
  - `DecodeURIComponent` loop `While i < s.Length` with 0-based counter and 1-based `Mid` dropped the last character of every key/value (e.g., `"title"` → `"titl"`), so `HasKey("title")` always returned `False`.
  - Same loop's percent-decode guard `i + 2 < s.Length` prevented decoding `%XX` sequences at the end of a string.

- **FormParser UTF-8 multi-byte decoding bug** (Thai and other non-ASCII characters saved as mojibake): `DecodeURIComponent` called `Chr(code)` on each decoded byte individually. `Chr()` maps integers to Unicode code points, so UTF-8 multi-byte sequences like `%E0%B8%97` (Thai `ท`) were converted to three separate wrong characters. Fixed by collecting all decoded bytes into a `MemoryBlock` and calling `DefineEncoding(..., Encodings.UTF8)` at the end.

### Confirmed working (after parser fixes)
- Full Notes CRUD: List, New/Create, View, Edit/Update, Delete
- Required field validation: empty title redirects back with flash error message
- Thai, emoji, and all Unicode input stored and displayed correctly

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
