# MVVM — Xojo Web 2 SSR Framework

A production-ready server-side rendered (SSR) MVVM web framework built on Xojo Web 2, inspired by Flask/Django. Routes all HTTP requests through `WebApplication.HandleURL` and renders responses via the **JinjaX template engine**. Xojo's built-in WebPage GUI system is bypassed entirely in favor of pure HTML+CSS rendering.

[![GitHub License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![Xojo](https://img.shields.io/badge/Xojo-2025r3.1-blue)](https://www.xojo.com)
[![Version](https://img.shields.io/badge/version-v1.0.0-green)](CHANGELOG.md)

## Quick Start

```bash
# Clone & enter the project
git clone https://github.com/Jedt3D/XjMVVM.git
cd XjMVVM

# Open in Xojo IDE (2025r3.1+)
open mvvm.xojo_project

# Or run from command line (after building)
./Builds/mvvm

# Visit http://localhost:9090
```

**Default**

- username : admin
- password : password

**Documentation:** Full [developer guide](https://github.com/Jedt3D/XjMVVM/tree/main/developer-guide) with 60 pages in English, Thai, and Japanese.

---

## Features

| Feature | Status | Details |
|---------|--------|---------|
| **Full CRUD** | ✓ | Notes and tags with real-time pagination |
| **User authentication** | ✓ | Cookie-based SSR auth, SHA-256 password hashing, client-side crypto |
| **User-scoped data** | ✓ | Notes isolated per user via `user_id` column |
| **Protected routes** | ✓ | Login redirects, 401 JSON for API endpoints |
| **RESTful JSON API** | ✓ | 5 endpoints (list, detail, create) for notes and tags |
| **Multi-language** | ✓ | English, Thai (ไทย), Japanese (日本語) in docs and UI |
| **Unicode support** | ✓ | Full Thai, emoji, and UTF-8 everywhere |
| **Form validation** | ✓ | Inline error rendering, POST/Redirect/GET pattern |
| **Testing framework** | ✓ | XojoUnit test runner built-in at `/tests` |
| **Alpine.js** | ✓ | Minimal JS for interactivity (auth state, tag selection) |
| **Responsive design** | ✓ | Mobile-first HTML templates |

---

## Project Details

**Xojo version:** 2025r3.1
**App type:** Web 2 (`IsWebProject=True`)
**Debug port:** 9090
**Bundle ID:** `com.worajedt.mvvm`
**License:** MIT

### Database

SQLite with 4 tables:
```sql
notes      (id, title, body, created_at, updated_at, user_id)
tags       (id, name, created_at)
note_tags  (note_id, tag_id)  -- junction table
users      (id, username UNIQUE, password_hash, created_at)
```

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
| **Router** | `Framework/Router.xojo_code` | HTTP method + path pattern matching with named segments |
| **BaseViewModel** | `Framework/BaseViewModel.xojo_code` | Request lifecycle, auth checks, response rendering |
| **ViewModels** | `ViewModels/` | One class per route; `OnGet()` / `OnPost()` handlers |
| **Models** | `Models/` | Data layer; all methods return `Dictionary` (for JinjaX compatibility) |
| **Templates** | `templates/` | Jinja2-compatible HTML files (via JinjaX engine) |
| **JinjaX Engine** | `JinjaXLib/` | Full Jinja2 port to Xojo: `{{ }}`, `{% %}`, `extends`, `block`, filters, autoescape |

### Key Rules (CRITICAL)

1. **Dictionary Data Contract** — JinjaX dot-notation (`{{ user.name }}`) **requires** `Dictionary` objects. Models always return `Dictionary` or `Variant()` of `Dictionary` — never custom class instances.
2. **No WebPage GUI** — All rendering is HTML via JinjaX templates. The `Default` page is a Xojo requirement only.
3. **SSR has no Session** — `Self.Session` is always `Nil` in HandleURL. Use HMAC-signed cookies for auth, never `Session.LogIn()`.
4. **POST/Redirect/Get** — All form submissions POST → validate → Redirect(302) → GET to prevent duplicate submissions.
5. **User-scoped data** — `NoteModel` methods require `userID` param; all queries include `WHERE user_id = ?`.

---

## Project Structure

```
📁 Framework/
   ├─ Router.xojo_code              Route registration & HTTP dispatch
   ├─ BaseViewModel.xojo_code       Request lifecycle, auth guards, rendering
   ├─ BaseModel.xojo_code           Generic repository CRUD
   ├─ DBAdapter.xojo_code           SQLite connection factory
   ├─ FormParser.xojo_code          application/x-www-form-urlencoded
   ├─ QueryParser.xojo_code         Query string parsing
   ├─ RouteDefinition.xojo_code     Route data class
   └─ JSONSerializer.xojo_code      JSON response builder

📁 Models/
   ├─ NoteModel.xojo_code           User-scoped notes CRUD
   ├─ TagModel.xojo_code            Shared tags CRUD
   └─ UserModel.xojo_code           Password storage & verification

📁 ViewModels/
   ├─ HomeViewModel.xojo_code       GET /
   ├─ Auth/
   │  ├─ LoginVM                    Login form & auth
   │  ├─ LogoutVM                   Session cleanup
   │  └─ SignupVM                   User registration
   ├─ Notes/                        (7 ViewModels — full CRUD)
   │  ├─ NotesListVM               GET /notes
   │  ├─ NotesNewVM                GET /notes/new
   │  ├─ NotesCreateVM             POST /notes
   │  ├─ NotesDetailVM             GET /notes/:id
   │  ├─ NotesEditVM               GET /notes/:id/edit
   │  ├─ NotesUpdateVM             POST /notes/:id
   │  └─ NotesDeleteVM             POST /notes/:id/delete
   ├─ Tags/                         (7 ViewModels — full CRUD)
   │  └─ [similar structure to Notes]
   └─ API/                          (5 JSON endpoints)
      ├─ NotesAPIList
      ├─ NotesAPIDetail
      ├─ NotesAPICreate
      ├─ TagsAPIList
      └─ TagsAPIDetail

📁 Tests/
   ├─ DBAdapterTests                Connect() validation
   ├─ BaseModelTests                Generic CRUD
   ├─ NoteModelTests                Notes-specific
   ├─ NotesPaginationTests          Pagination logic
   ├─ TagModelTests                 Tags CRUD
   ├─ NoteTagAssociationTests       Junction table
   ├─ UserModelTests                Password hashing
   ├─ APITests                      JSON endpoint validation
   └─ NoteOwnershipTests            Cross-user isolation

📁 JinjaXLib/                       Full Jinja2 engine in Xojo
   └─ [50+ classes for lexing, parsing, rendering templates]

📁 templates/
   ├─ layouts/
   │  └─ base.html                  Navigation, flash, content block
   ├─ home.html                     Homepage
   ├─ auth/
   │  ├─ login.html
   │  └─ signup.html
   ├─ notes/
   │  ├─ list.html
   │  ├─ detail.html
   │  └─ form.html                  (shared create/edit)
   ├─ tags/
   │  ├─ list.html
   │  ├─ detail.html
   │  └─ form.html
   ├─ api/                          (JSON response bodies)
   └─ errors/
      ├─ 404.html
      └─ 500.html

📁 developer-guide/
   ├─ build.py                      Python static site generator
   ├─ xojo_lexer.py                 Pygments syntax highlighter for Xojo
   ├─ nav.yaml                      Documentation structure
   ├─ src/
   │  ├─ _layout/
   │  │  └─ page.html              Shared Jinja2 template (all languages)
   │  ├─ _assets/
   │  │  ├─ style.css              Theming (light/dark mode)
   │  │  └─ docs.js                Client-side behavior
   │  ├─ pages/                    20 English pages
   │  ├─ pages_th/                 Thai translations
   │  └─ pages_jp/                 Japanese translations
   └─ dist/                         Built static site (gitignored)

📁 data/
   └─ notes.sqlite                  SQLite database (auto-created)

📁 Shared Resources/                Xojo test framework & utilities
   ├─ XojoUnit/
   │  └─ [Test runner UI components]
   ├─ OptionParser/
   └─ [other utilities]

CHANGELOG.md                         Full version history
CLAUDE.md                           Architecture & gotchas (for Claude Code)
Routing.md                          HandleURL deep dive (deprecated — see docs)
```

---

## Running the App

### In the Xojo IDE

1. **Install Xojo 2025r3.1+** from [xojo.com](https://www.xojo.com)
2. **Open** `mvvm.xojo_project` in the IDE
3. **Click Run** (or press ⌘R)
4. **Visit** `http://localhost:9090` in your browser
5. **Create an account** — sign up with any username/password
6. **Create notes** — add titles and bodies; optionally tag them

The SQLite database is auto-created on first run at `data/notes.sqlite`.

### Running Tests

1. In the app, navigate to **`/tests`** in the top nav (if logged in)
2. Or visit **`http://localhost:9090/tests`** directly
3. The XojoUnit test runner loads in a Xojo WebPage
4. Click **Run All Tests** to validate the entire framework

### Building for Production

```bash
# Build in Xojo IDE: Project > Build > Linux Console
# Or on macOS: Build > macOS Arm64 Console

# Deploy:
# 1. Copy the compiled binary to your server
# 2. Copy the entire 'templates/' folder alongside it
# 3. The 'data/' folder is auto-created on first run
# 4. Point a reverse proxy (nginx/apache) to localhost:9090
```

---

## Routes

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| **Public** |
| GET | `/` | HomeViewModel | Landing page |
| GET | `/login` | LoginVM | Login form |
| POST | `/login` | LoginVM | Authenticate & set cookie |
| GET | `/signup` | SignupVM | Registration form |
| POST | `/signup` | SignupVM | Create user & auto-login |
| POST | `/logout` | LogoutVM | Clear auth cookie |
| **Protected — Notes** |
| GET | `/notes` | NotesListVM | List user's notes (paginated) |
| GET | `/notes/new` | NotesNewVM | Create form |
| POST | `/notes` | NotesCreateVM | Save new note → redirect |
| GET | `/notes/:id` | NotesDetailVM | View single note |
| GET | `/notes/:id/edit` | NotesEditVM | Edit form |
| POST | `/notes/:id` | NotesUpdateVM | Save updates → redirect |
| POST | `/notes/:id/delete` | NotesDeleteVM | Delete → redirect to list |
| **Protected — Tags** |
| GET | `/tags` | TagsListVM | List all tags |
| GET | `/tags/new` | TagsNewVM | Create form |
| POST | `/tags` | TagsCreateVM | Save tag → redirect |
| GET | `/tags/:id` | TagsDetailVM | View tag + linked notes |
| GET | `/tags/:id/edit` | TagsEditVM | Edit form |
| POST | `/tags/:id` | TagsUpdateVM | Save updates → redirect |
| POST | `/tags/:id/delete` | TagsDeleteVM | Delete → redirect to list |
| **Protected — JSON API** |
| GET | `/api/notes` | NotesAPIList | Notes as JSON array |
| POST | `/api/notes` | NotesAPICreate | Create note, return 201 + JSON |
| GET | `/api/notes/:id` | NotesAPIDetail | Note with embedded tags |
| GET | `/api/tags` | TagsAPIList | Tags as JSON array |
| GET | `/api/tags/:id` | TagsAPIDetail | Single tag as JSON |
| **Development** |
| GET | `/tests` | XojoUnitTestPage | Test runner (redirect dance) |

---

## Authentication

**Pattern:** HMAC-signed cookies (no WebSocket session in SSR mode)

```xojo
// Login: password verified via SHA-256 + stored salt
If UserModel.VerifyPassword(username, password) Then
  // Set secure cookie
  Var token = EncodeHex(Crypto.SHA256(userID + ":" + username + ":" + App.mAuthSecret))
  Var cookie = userID + ":" + username + ":" + token
  Response.Header("Set-Cookie") = "mvvm_auth=" + cookie + "; Path=/; SameSite=Strict; HttpOnly"
End If

// Later: extract from Request.Header("Cookie")
Function ParseAuthCookie() As Dictionary
  ' Returns {user_id, username} or Nil if invalid HMAC
End Function
```

- **Password storage:** `SHA256(clientHash + salt):salt` in one TEXT column
- **Client-side:** Web Crypto API hashes before form submit (plaintext never sent)
- **Protected routes:** `RequireLogin()` redirects to `/login?next=<url>` with post-login return
- **API auth:** `RequireLoginJSON()` returns 401 `{"error":"Authentication required"}`

---

## Development Guide

The `developer-guide/` directory is a **Python static site generator** that builds the official documentation website.

### Building the Docs

```bash
cd developer-guide/

# Install Python dependencies
pip install -r requirements.txt

# Build all languages (EN + TH + JP)
python3 build.py

# Build English only
python3 build.py --lang en

# Regenerate translations (requires ANTHROPIC_API_KEY)
export ANTHROPIC_API_KEY=sk-...
python3 build.py --translate
```

Output lands in `developer-guide/dist/` — fully static, ready to serve.

### Documentation Topics (20 pages)

1. **Getting Started** — installation, quick start, first note
2. **Architecture** — MVVM pattern, separation of concerns, data contracts
3. **Conventions** — file structure, naming, directory layout
4. **Routing** — HandleURL, request dispatch, path parameters
5. **Forms & Validation** — FormParser, POST/Redirect/GET, flash messages
6. **Database** — SQLite, schema, migrations, BaseModel patterns
7. **Models** — Repository pattern, user-scoped data, associations
8. **Templating** — Jinja2 syntax, autoescape, custom filters
9. **Authentication** — password hashing, cookie-based auth, protected routes
10. **APIs** — RESTful JSON endpoints, CORS, error responses
11. **Frontend** — Alpine.js for interactivity, form validation, state
12. **Protected Routes & User Scoping** — guards, ownership enforcement, testing
13. **Testing** — XojoUnit framework, test patterns, assertions
14. **Xojo Gotchas** — string indexing, UTF-8 decoding, session nil
15–20. **Appendices** — style guide, glossary, troubleshooting, further reading

**All 20 pages translated to Thai and Japanese.** View online at [mvvm-docs.example.com](https://example.com).

---

## Key Technical Decisions

| Decision | Reason |
|----------|--------|
| SSR over WebSocket | No framework-level session in SSR; cookies work everywhere |
| Cookies not sessions | `Self.Session` is `Nil` in HandleURL; session only available in WebPages |
| JinjaX for templates | Jinja2-compatible, pure Xojo, supports all Unicode, macOS/Linux/Windows |
| BaseModel generics | Reduce boilerplate; DRY principle for CRUD |
| Post/Redirect/Get | Prevent duplicate submissions; idempotent GET requests |
| User-scoped notes | Most real apps need data isolation; simple to test |
| Minimal JS | Alpine.js only; no build step, no npm bloat |
| Static site docs | Fully portable, zero hosting costs, version-controlled |

---

## Limitations & Known Issues

- **Xojo requirement:** Must be built in the Xojo IDE (no CLI build system)
- **Linux/ARM:** Xojo console builds work; Web builds need `.so` libs matching server arch
- **Sessions in SSR:** `WebSocket` sessions don't exist; use cookies + tokens
- **File paths:** Relative to binary (production) vs. project dir (debug) — handle both

---

## Contributing

This is a reference implementation. Feel free to fork and extend:

1. **New resources:** Follow the `Models` → `ViewModels` → `templates` pattern
2. **New filters:** Register in `App.Opening` via `mJinja.RegisterFilter()`
3. **New tests:** Add to `Tests/` folder, register in `WebTestController`
4. **Docs:** Edit `.md` files in `developer-guide/src/pages/`, rebuild with `build.py`

---

## Performance Notes

- **Template caching:** `JinjaEnvironment` caches compiled templates after first use
- **Database pooling:** `DBAdapter.Connect()` creates fresh SQLite connections per request (file-based, not network)
- **Pagination:** Default 10 items/page; configurable per route
- **Autoescape:** JinjaX escapes HTML by default; use `|safe` filter for trusted content

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Port already in use** | Change `Debug port` in `mvvm.xojo_project` (9090) or kill existing process |
| **Database locked** | Restart the app; SQLite allows one writer at a time |
| **Thai/emoji displays as ?** | Ensure UTF-8 encoding throughout; check `FormParser` percent-decode |
| **Form data missing** | Check `Request.Header("Content-Type")`; must be `application/x-www-form-urlencoded` |
| **Redirect loop** | Verify `RequireLogin()` logic in ViewModel; check redirect URL |
| **Templates not found** | Build in Xojo IDE first; debug vs. production paths differ |

---

## License

MIT License — see [LICENSE](LICENSE) file. Use freely, commercially and otherwise.

---

## Resources

- **[Xojo Documentation](https://docs.xojo.com)** — Language reference, Web 2 guide
- **[JinjaX Repository](https://github.com/jedt3d/jinjax)** — Full JinjaX source (included in this project)
- **[Jinja2 Documentation](https://jinja.palletsprojects.com/)** — Template syntax reference
- **[Alpine.js Docs](https://alpinejs.dev)** — Lightweight JavaScript framework
- **[SQLite Reference](https://www.sqlite.org/docs.html)** — Database documentation

---

**Built with ❤️ using Xojo Web 2, JinjaX, and Alpine.js**
