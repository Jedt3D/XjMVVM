# Changelog

All notable changes to the MVVM project are documented here. Versions follow [Semantic Versioning](https://semver.org).

## [1.0.0] — 2026-03-17

### Summary

**Production-ready release.** All core features completed through Phase 4. User-scoped notes, protected routes, cookie-based authentication, JSON API, full test coverage, and comprehensive 60-page developer guide (English + Thai + Japanese).

### Added

- **README.md complete rewrite** — quick start guide, feature matrix, architecture diagrams, all routes documented, production deployment guide, troubleshooting section
- **MIT License** added — open source with clear terms

### Changed

- **Version bump** → v1.0.0 (from v0.9.3)
- **Documentation** — README now a comprehensive onboarding document; legacy architecture docs (Routing.md, DatabaseModel.md) noted as archived in favor of developer guide

### Status

| Subsystem | Version | Status |
|-----------|---------|--------|
| **Xojo Framework** | v1.0.0 | ✓ Complete |
| **JinjaX Engine** | Full source | ✓ Included |
| **Database** | v1.0.0 schema | ✓ 4 tables, user-scoped notes |
| **Authentication** | Cookie-based SSR | ✓ HMAC-signed, SHA-256 passwords |
| **API** | 5 endpoints | ✓ Full CRUD JSON |
| **Tests** | 9 test groups | ✓ 40+ assertions |
| **Documentation** | 60 pages | ✓ EN/TH/JP |

---

## [0.9.3-tooling] — 2026-03-13

### Added

- **`test_api.py`** — Python API smoke-test script (no dependencies beyond stdlib)
  - Handles SHA-256 client-side password hashing before login POST (mirrors browser Web Crypto API)
  - Extracts `mvvm_auth` cookie from `Set-Cookie` response header automatically
  - `--signup` flag auto-creates the test user if login fails
  - 9 test scenarios: unauthenticated 401, list notes, create note (validation 422 + success 201), note detail with embedded tags, notes 404, list tags, tag detail, tags 404
  - Coloured pass/fail summary table with elapsed time; exits 0/1 for CI use

### Changed

- **Debug port** changed `8080 → 9090` in `mvvm.xojo_project` (conflict avoidance)

---

## [0.9.3-editorial] — 2026-03-13

### Changed

- **Thai (TH) translation — full editorial pass** across all 20 pages (60 fixes total)
  - **Major fixes** in 5 priority files: Japanese characters leaked into TH text (`リダイレクト` removed), catastrophic mistranslation "ประเทศไทยมีสองวิธีการยาม" → "มีสองเมธอด guard", garbled "อะแซงก์ก" → "Async", garbled "ตัวฟังชายตัวสนับสนุน" → rewritten, "จะไฟ" (fire) → "fire ขึ้นมาอีกครั้ง", missing verb in security warning fixed
  - **Terminology standardized**: "authentication" → "การยืนยันตัวตน" throughout, "กุญแจ" → "key", "ลวดลาย" → "รูปแบบ", "เบราวเซอร์" → "เบราว์เซอร์", "ท่อ" → "pipeline", "โครงการ" → "ตาราง", "ถูกไม่สนใจ" → "ถูกละเว้น", "นำเสนอ Jinja2" → "port ของ Jinja2"
  - **Headings**: 8 English headings in `05-database` translated; 3 English headings in `02-conventions/directory-structure` translated; routing headings fixed
  - **Tone**: Added senior→junior programmer tone guidance to `build.py` translate prompt
- **Japanese (JP) translation — full editorial pass** across all 20 pages
  - **Critical**: Untranslated headings `## Philosophy` → `## 設計思想`, `## Installation` → `## インストール`; meaning reversal in templates/examples fixed; "SRRモード" → "SSRモード"; `description` frontmatter wrong kanji fixed
  - **Systematic**: "決に〜" → "決して〜" (5+ files); "フォルシー" → "偽値（falsy）"; "ディフェレンシエート" → "差分比較"; "コンテキスト辞書" → "コンテキスト Dictionary"; garbled byte-mismatch sentence fixed; full-width/half-width parentheses normalized

### Added

- `developer-guide/th_observation.md` — detailed Thai editorial review report (Major/Moderate/Minor per file, 20-term terminology glossary)
- `developer-guide/jp_observation.md` — detailed Japanese editorial review report (per-file observations, unified terminology glossary)

---

## [0.9.3-docs] — 2026-03-13

### Changed
- **Developer guide updated for v0.9.3** — all Phase 3+4 features now documented across EN/TH/JP (60 pages total)
  - **Auth System** (`09-authentication`) — fully rewritten: session-based auth replaced with cookie-based auth (HMAC-signed `mvvm_auth` cookie, `ParseAuthCookie()`, `RedirectWithAuth/Logout()`, inline error rendering)
  - **JSON API** (`10-api`) — all 5 endpoints now show `RequireLoginJSON()` guards and user-scoped NoteModel calls
  - **DB Layer Reference** (`05-database/model-reference`) — NoteModel rewritten with `user_id` column, all methods take `userID`, CRUD mapping updated
  - **Introduction** (`index`) — version bumped to v0.9.3, added Alpine.js and Protected Routes to section table
- **nav.yaml** — version updated to v0.9.3, added "Security" section

### Added
- **New page: "Protected Routes & User Scoping"** (`12-protected-routes`) — route guards (`RequireLogin`/`RequireLoginJSON`), user-scoped data pattern, DB migration, ownership enforcement, testing patterns
- 10 new translations (5 TH + 5 JP) via Claude Haiku 4.5

---

## [0.9.3] — 2026-03-13

### Added
- **User-scoped notes** (Phase 4): notes are now isolated per user via `user_id` column
  - DB migration auto-adds `user_id INTEGER NOT NULL DEFAULT 0` + index to existing `notes` table
  - `NoteModel` methods all require `userID` parameter: `Create`, `GetAll`, `GetByID`, `Update`, `Delete`
  - New methods: `CountForUser(userID)`, `FindPaginatedForUser(userID, limit, offset, orderBy)`
- **Protected routes**: all 19 ViewModel routes (7 Notes, 7 Tags, 5 API) require authentication
  - `RequireLogin()` — redirects to `/login?next=<encoded-url>` with post-login return
  - `RequireLoginJSON()` — returns 401 JSON `{"error":"Authentication required"}` for API endpoints
- **Cookie-based authentication** — replaces session-based auth (SSR has no WebSocket session)
  - HMAC-signed `mvvm_auth` cookie: `userID:username:SHA256(payload:secret)`
  - `App.mAuthSecret` — random 32-byte key generated at startup
  - `RedirectWithAuth()` — HTTP `Set-Cookie` header + JS intermediate page for localStorage
  - `RedirectWithLogout()` — `Set-Cookie: Max-Age=0` + JS clears localStorage
  - `ParseAuthCookie()` — reads/verifies cookie from `Request.Header("Cookie")`
- **NoteOwnershipTests** — 2 tests verifying cross-user isolation (wrong user can't read/delete)
- **Inline error rendering** on login/signup — `error_message` template variable replaces broken `SetFlash`

### Changed
- `BaseViewModel.CurrentUserID()` / `CurrentUsername()` now read from cookie, not session
- `BaseViewModel.Render()` injects `current_user` from cookie
- Login/signup error handling: re-renders form with error instead of redirect+flash (SetFlash is Nil in SSR)
- Signup template no longer sets localStorage optimistically — `RedirectWithAuth` handles it
- All 5 existing test files updated with `kTestUserID = 999` for user-scoped model calls

### Fixed
- **`Self.Session` is always Nil in SSR** — discovered that Xojo Web 2 HandleURL has no WebSocket session. Session-based auth (`Session.LogIn`, `SetFlash`) silently failed. Replaced with cookie-based auth.
- **Login failures were invisible** — `SetFlash()` + `Redirect()` showed no error because session was Nil. Now renders login page with inline error message.

---

## [0.9.2] — 2026-03-12

### Changed
- **Alpine.js replaces all custom JavaScript** — Alpine.js 3.14.3 added via CDN (`defer`, no build step). Total custom JS reduced from 93 lines to 16.
  - `base.html`: IIFE replaced with `x-data` on nav (auth state) and flash div; logout handler moved to `@submit` attribute
  - `login.html`: `addEventListener` replaced with `x-data` + `@submit.prevent`
  - `signup.html`: password validation driven by `x-show`/`x-text`; added `minlength="6"` HTML attribute
  - `notes/form.html`: JS tag-checkbox collector removed entirely; checkboxes use native `name="tag_ids"` multi-value (FormParser already handles it)
- **Developer guide**: Alpine.js page added under new "Frontend" section (EN/TH/JP)

---

## [0.9.1] — 2026-03-12

### Added
- **Client-side SHA-256 hashing** — Web Crypto API hashes password in login/signup forms before submit; plaintext password never crosses the network
- **Password strength validation** — signup form requires ≥6 characters, confirms match, shown inline before submit
- **SSR session workaround** — flash messages stored in `sessionStorage` survive the POST→redirect→GET cycle without a WebSocket session
- **Nav auth state** — `localStorage` stores username on login/signup, cleared on logout; `base.html` shows appropriate nav links
- **Developer guide pages** — auth (09), tags (08), API (10) pages added; all 54 EN/TH/JP pages rebuilt

### Changed
- Auth redirects changed from `/` to `/notes` (root `/` serves Xojo bootstrap in SSR mode)
- `BaseViewModel.Render()` always injects `flash` and `current_user` with safe defaults so templates never throw `UndefinedVariableException`

---

## [0.9.0] — 2026-03-12

### Added
- **JSONSerializer module** — `EscapeString`, `DictToJSON`, `ArrayToJSON` for building JSON responses
- **JSON API endpoints**:
  - `GET /api/notes` — notes list as JSON array
  - `POST /api/notes` — create note, returns 201 + JSON (form-encoded body)
  - `GET /api/notes/:id` — note with embedded tags array
  - `GET /api/tags` — tags list as JSON array
  - `GET /api/tags/:id` — single tag as JSON
- **APITests** — 3 tests covering DictToJSON key inclusion and array format

---

## [0.8.0] — 2026-03-12

### Added
- **Authentication system** (Phase 3.4):
  - `UserModel` — Create, FindByUsername, VerifyPassword (SHA-256 + random salt via `EncodeHex`)
  - `Session` — `CurrentUserID`, `CurrentUsername`, `LogIn()`, `LogOut()`, `IsLoggedIn()`
  - `BaseViewModel` — `RequireLogin()` guard, `CurrentUserID()`, `CurrentUsername()` helpers
  - `LoginVM` — `GET /login` (form), `POST /login` (verify + session)
  - `LogoutVM` — `POST /logout` (clear session)
  - `SignupVM` — `GET /signup` (form), `POST /signup` (validate + create + auto-login)
  - Templates: `auth/login.html`, `auth/signup.html`
  - Nav: shows username + logout when logged in, login/signup links when not
- **DB**: `CREATE TABLE users (id, username UNIQUE, password_hash, created_at)`
- **UserModelTests** — 5 tests (Create, FindByUsername, FindUnknown, VerifyCorrect, VerifyWrong)

---

## [0.7.0] — 2026-03-12

### Added
- **Notes ↔ Tags associations** (Phase 3.3):
  - `note_tags` junction table (`note_id`, `tag_id`, `PRIMARY KEY`)
  - `NoteModel.GetTagsForNote()` and `SetTagsForNote()`
  - Notes detail shows tag badges with links; form shows tag checkboxes
  - JS collector gathers checked values into hidden `tag_ids` field
- **FormParser multi-value support** — duplicate keys append with comma (for multi-value checkboxes)
- **NoteTagAssociationTests** — 3 tests (SetAndGet, Overwrite, Clear)

---

## [0.6.0] — 2026-03-12

### Added
- **Tags resource — full CRUD** (Phase 3.2):
  - `TagModel` — extends BaseModel
  - 7 Tags ViewModels: List, Detail, New, Create, Edit, Update, Delete
  - Templates: `tags/list.html`, `tags/form.html`, `tags/detail.html`
  - Tags link added to nav in `base.html`
- **DB**: `CREATE TABLE tags (id, name, created_at)`
- **TagModelTests** — 5 tests (Create, GetAll, GetByID, Update, Delete)

---

## [0.5.0] — 2026-03-12

### Added
- **Pagination** (Phase 3.1):
  - `BaseModel.Count()` and `FindPaginated(limit, offset, orderBy)`
  - `NotesListVM` reads `?page=N`, computes offset, passes pagination context
  - `list.html` prev/next controls with page X of Y indicator
- **NotesPaginationTests** — 5 tests covering Count and FindPaginated

### Fixed
- `Math.Ceiling()` does not exist in Xojo — replaced with integer arithmetic: `(total + perPage - 1) \ perPage`
- `Assert.AreEqual(0, someInt)` is ambiguous in Xojo — replaced with `Assert.IsTrue(someInt = 0)`

---

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
