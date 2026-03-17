# Xojo MVVM — Multi-Agent Implementation Plan

> **Project:** mvvm (Xojo Web Application)
> **Framework:** JinjaX templates + Xojo Web non-GUI classes
> **Date:** 2026-03-11

---

## Overview

This document defines **how Claude agents collaborate to implement the MVVM framework**, including agent roles, sprint plan, build loop protocol, and file registration rules.

For architecture decisions, see `MVVM_Architecture_Proposal.md`.
For Xojo coding rules and gotchas, see `JinjaX_Implementation/CLAUDE.md`.

---

## 1. Multi-Agent Architecture

Each sprint uses **specialized sub-agents** launched in parallel where possible, then an **orchestrating agent** that validates, registers files in `.xojo_project`, and manages the build loop.

```
┌─────────────────────────────────────────────────────────┐
│                  ORCHESTRATOR (Main Agent)               │
│  - Reads errors.txt, decides what to fix                 │
│  - Registers new files in mvvm.xojo_project              │
│  - Manages build loop: Write → Analyze → Fix → Repeat    │
└────────┬──────────────┬──────────────┬───────────────────┘
         │              │              │
         ▼              ▼              ▼
  ┌─────────────┐ ┌──────────────┐ ┌───────────────────┐
  │  Framework  │ │   Template   │ │   Feature Coder   │
  │    Agent    │ │    Agent     │ │      Agent        │
  │             │ │              │ │                   │
  │ Router      │ │ HTML Jinja   │ │ Models +          │
  │ BaseVM      │ │ templates    │ │ ViewModels        │
  │ FormParser  │ │ (pure HTML,  │ │ (per feature)     │
  │ QueryParser │ │ no Xojo)     │ │                   │
  └─────────────┘ └──────────────┘ └───────────────────┘
         │
         ▼
  ┌─────────────┐
  │  QA / Fix   │
  │    Agent    │
  │             │
  │ Reads       │
  │ errors.txt, │
  │ applies fix │
  └─────────────┘
```

### Agent Responsibilities

| Agent | Reads | Writes | Can Parallelize? |
|---|---|---|---|
| **Orchestrator** | All files, errors.txt | mvvm.xojo_project | No — coordinates others |
| **Framework Agent** | CLAUDE.md, Architecture Proposal | Router, BaseViewModel, FormParser, QueryParser | Yes — with Template Agent |
| **Template Agent** | Architecture Proposal, Template feature reference | `templates/**/*.html` | Yes — with Framework Agent |
| **Feature Agent** | CLAUDE.md, BaseViewModel impl | Model classes, ViewModel classes | Yes — multiple features in parallel |
| **QA/Fix Agent** | CLAUDE.md, errors.txt, failing .xojo_code files | Fixed .xojo_code files | No — sequential per error batch |

---

## 2. Build Loop Protocol

This is the core iteration cycle for the entire project.

```
┌─────────────────────────────────────────────────────────┐
│                    BUILD LOOP                            │
│                                                          │
│  1. Agent writes/edits .xojo_code files                  │
│  2. Agent updates mvvm.xojo_project (registers files)    │
│                                                          │
│  3. USER runs on macOS terminal:                         │
│       cd /path/to/mvvm                                   │
│       ./analyze.sh                                       │
│                                                          │
│  4. Xojo IDE runs Analyze Project (Cmd+Shift+K)          │
│                                                          │
│  5. IF errors appear in Issues panel:                    │
│       Right-click Issues → Copy All                      │
│       ./analyze.sh save       ← saves to errors.txt      │
│                                                          │
│  6. IF zero errors:                                      │
│       ./analyze.sh clear      ← clears errors.txt        │
│                                                          │
│  7. Agent reads errors.txt from mounted folder           │
│       → QA/Fix Agent applies corrections                 │
│       → Orchestrator re-registers any renamed files      │
│       → Return to step 1                                 │
│                                                          │
│  When errors.txt is empty: sprint is DONE ✅             │
└─────────────────────────────────────────────────────────┘
```

**Key file:** `mvvm/errors.txt`
- Non-empty = compilation errors, Claude must fix
- Empty = project compiles cleanly

**IMPORTANT — Never edit `.xojo_code` files while Xojo IDE is actively saving.** See CLAUDE.md "File Editing Safety" rule.

---

## 3. File Registration Rules (`.xojo_project`)

Every new `.xojo_code` file MUST be added to `mvvm.xojo_project`. Forgetting this is the most common mistake.

### Format

```
Type=Name;RelativePath;UniqueHexID;ParentHexID;false
```

### Type Keywords

| Xojo type | Keyword in .xojo_project |
|---|---|
| Class | `Class` |
| Module | `Module` |
| Interface | `Interface` |
| Folder (group) | `Folder` |
| WebPage | `WebView` |
| WebSession subclass | `WebSession` |
| App subclass | `Class` |

### ID Generation

Each entry needs a unique 8-byte hex ID. Use this pattern:
`&h` + 8 hex characters + `FF`
Example: `&h0000000056A9AFFF`

Generate incrementally — just make sure no two IDs collide within the project.

### Parent IDs in This Project

| Location | Parent ID |
|---|---|
| Root level | `&h0000000000000000` |
| Inside `Framework/` folder | folder's own hex ID |
| Inside `ViewModels/` folder | folder's own hex ID |
| Inside `Models/` folder | folder's own hex ID |

### Planned IDs

```
Root level:
  App.xojo_code               &h0000000056A9AFFF  (exists)
  Session.xojo_code           &h00000000215EB7FF  (exists)
  WebPage1.xojo_code          &h0000000060CB57FF  (exists — keep as fallback)
  Build Automation.xojo_code  &h0000000005B007FF  (exists)

JinjaXLib module (imported/copied from JinjaX project):
  Folder=JinjaXLib             &h0000000076F100FF  parent=root
  ... (all JinjaX classes inside, registered with JinjaXLib as parent)

Framework folder:
  Folder=Framework             &h00000000AB1200FF  parent=root
  Class=Router                 &h00000000AB1201FF  parent=Framework
  Class=BaseViewModel          &h00000000AB1202FF  parent=Framework
  Class=FormParser             &h00000000AB1203FF  parent=Framework
  Class=QueryParser            &h00000000AB1204FF  parent=Framework

ViewModels folder:
  Folder=ViewModels            &h00000000AB1300FF  parent=root
  Class=HomeViewModel          &h00000000AB1301FF  parent=ViewModels
  Class=LoginViewModel         &h00000000AB1302FF  parent=ViewModels
  Class=ProductListViewModel   &h00000000AB1303FF  parent=ViewModels
  Class=ProductDetailViewModel &h00000000AB1304FF  parent=ViewModels
  Class=ProductCreateViewModel &h00000000AB1305FF  parent=ViewModels
  Class=StaticFileViewModel    &h00000000AB1306FF  parent=ViewModels

Models folder:
  Folder=Models                &h00000000AB1400FF  parent=root
  Class=UserModel              &h00000000AB1401FF  parent=Models
  Class=ProductModel           &h00000000AB1402FF  parent=Models
  Class=Database               &h00000000AB1403FF  parent=Models
```

---

## 4. Project File Structure (Final State)

```
mvvm/
├── mvvm.xojo_project          ← Master project file (updated each sprint)
├── mvvm.xojo_resources        ← App icon etc (untouched)
├── App.xojo_code              ← Sprint 1: Add HandleURL + Opening()
├── Session.xojo_code          ← Sprint 2: Add auth properties
├── WebPage1.xojo_code         ← Keep as empty fallback (never navigated to)
├── Build Automation.xojo_code ← Untouched
│
├── Framework/
│   ├── Router.xojo_code       ← Sprint 1
│   ├── BaseViewModel.xojo_code ← Sprint 1
│   ├── FormParser.xojo_code   ← Sprint 1
│   └── QueryParser.xojo_code  ← Sprint 1
│
├── ViewModels/
│   ├── HomeViewModel.xojo_code     ← Sprint 3
│   ├── LoginViewModel.xojo_code    ← Sprint 2
│   ├── ProductListViewModel.xojo_code   ← Sprint 3
│   ├── ProductDetailViewModel.xojo_code ← Sprint 3
│   ├── ProductCreateViewModel.xojo_code ← Sprint 4
│   └── StaticFileViewModel.xojo_code    ← Sprint 3
│
├── Models/
│   ├── AppDatabase.xojo_code   ← Sprint 3 (DB connection + helpers)
│   ├── UserModel.xojo_code     ← Sprint 2
│   └── ProductModel.xojo_code  ← Sprint 3
│
├── JinjaXLib/                  ← Copied from JinjaX_Implementation
│   ├── JinjaX.xojo_code
│   ├── MarkupSafe.xojo_code
│   ├── TokenType.xojo_code
│   ├── JinjaX/
│   │   ├── (all 30+ class files)
│   └── MarkupSafe/
│       └── MarkupString.xojo_code
│
├── templates/                  ← HTML templates (NOT registered in .xojo_project)
│   ├── layouts/
│   │   └── base.html
│   ├── home/
│   │   └── index.html
│   ├── auth/
│   │   └── login.html
│   ├── products/
│   │   ├── list.html
│   │   ├── detail.html
│   │   └── form.html
│   └── errors/
│       ├── 404.html
│       └── 500.html
│
├── analyze.sh                  ← Build loop helper (macOS, runs on host)
├── errors.txt                  ← Xojo compilation errors (Claude reads this)
├── MVVM_Knowledge_Base.md
├── MVVM_Architecture_Proposal.md
└── IMPLEMENTATION_PLAN.md     ← This file
```

**Note:** The `templates/` folder is NOT registered in `.xojo_project`. It is copied to the app bundle via a **CopyFiles Build Step** (Destination = Resources, pointing to the templates folder). The `FileSystemLoader` finds it at `App.ExecutableFile.Parent/templates/` at runtime.

---

## 5. Sprint Plan

### Sprint 0 — Project Setup (Orchestrator only, ~30 min)

**Goal:** Clean project that compiles, with JinjaXLib referenced.

**Tasks:**
1. Copy JinjaXLib folder from `JinjaX_Implementation/JinjaX_Project/JinjaX/JinjaXLib/` into `mvvm/JinjaXLib/`
2. Register ALL JinjaXLib files in `mvvm.xojo_project`
3. Clear `DefaultWindow=WebPage1` (keep WebPage1 but make it truly empty)
4. Run analyze — confirm JinjaXLib compiles cleanly in web project context
5. Create `templates/` folder with placeholder `layouts/base.html`
6. Create CopyFiles build step for templates folder

**Deliverable:** Project compiles with JinjaXLib, zero errors. `errors.txt` is empty.

---

### Sprint 1 — Core Framework (parallel agents)

**Goal:** `Router`, `BaseViewModel`, `FormParser`, `QueryParser` compile. App wires HandleURL.

**Agent A — Framework Agent (writes 4 classes):**

```
Framework/Router.xojo_code
  Class Router
    - Inner type RouteEntry: Method(String), Pattern(String), FactoryClass(String)
    - mRoutes() As RouteEntry
    - Sub Get(pattern, handlerClassName)
    - Sub Post(pattern, handlerClassName)
    - Sub Route(request, response, jinja, sess)
    - Function ParsePath(pattern, actual) As Dictionary  ← returns Nil if no match
    - Sub Serve404(response)
    - Sub Serve500(response, errorMsg)
    - Private Function SplitPath(path) As String()

Framework/BaseViewModel.xojo_code
  Class BaseViewModel
    - Property Request As WebRequest
    - Property Response As WebResponse
    - Property UserSession As Session
    - Property Jinja As JinjaX.JinjaEnvironment
    - Property PathParams As Dictionary
    - Sub Handle()  ← dispatches to OnGet/OnPost
    - Protected Sub OnGet()   ← override in subclass
    - Protected Sub OnPost()  ← override: default sends 405
    - Sub Render(templateName As String, context As Dictionary)
    - Sub Redirect(url As String, code As Integer = 302)
    - Sub RenderError(statusCode As Integer, message As String)
    - Sub WriteJSON(json As String)
    - Function GetParam(key As String) As String
    - Function GetFormValue(key As String) As String
    - Function IsAuthenticated() As Boolean
    - Function CurrentUser() As Dictionary

Framework/FormParser.xojo_code
  Class FormParser
    - Shared Function Parse(body As String) As Dictionary
    - Shared Function URLDecode(s As String) As String

Framework/QueryParser.xojo_code
  Class QueryParser
    - Shared Function Parse(queryString As String) As Dictionary
```

**Agent B — Template Agent (parallel, writes HTML):**

```
templates/layouts/base.html   ← full Bootstrap 5 CDN layout with nav block, content block
templates/errors/404.html     ← extends base, 404 message
templates/errors/500.html     ← extends base, 500 message
templates/home/index.html     ← extends base, welcome message
```

**Agent C — App Wiring (depends on Framework Agent completing):**

```
App.xojo_code  ← Update:
  Property mRouter As Router
  Property mJinja As JinjaX.JinjaEnvironment
  Event Opening():
    → create JinjaEnvironment, set TemplatePath
    → register custom filters
    → create Router, register routes
  Event HandleURL(request, response) As Boolean:
    → mRouter.Route(request, response, mJinja, Session(request.Session))
    → Return True

Session.xojo_code  ← Add properties:
  Property IsLoggedIn As Boolean
  Property CurrentUserID As Integer
  Property CurrentUserName As String
  Property FlashMessage As String
  Property FlashType As String  ' "success" | "error" | "info"
```

**Build loop:** Analyze → fix until 0 errors.

**Deliverable:** `GET /` returns 404 HTML page (router found no route). App compiles and runs.

---

### Sprint 2 — Authentication (sequential after Sprint 1)

**Goal:** Login/logout flow works end-to-end in browser.

**Feature Agent writes:**

```
Models/UserModel.xojo_code
  Class UserModel
    - Function Authenticate(username, password) As Dictionary  ← returns user dict or Nil
    - Function GetByID(id As Integer) As Dictionary

ViewModels/LoginViewModel.xojo_code
  Class LoginViewModel extends BaseViewModel
    - OnGet(): render login form, pass flash message from session
    - OnPost(): read username/password from form, call UserModel.Authenticate
               → success: set session, Redirect("/")
               → failure: set flash, Redirect("/login")

ViewModels/HomeViewModel.xojo_code
  Class HomeViewModel extends BaseViewModel
    - OnGet(): render home/index.html with user context
```

**Template Agent writes:**
```
templates/auth/login.html     ← login form, CSRF field, flash message display
```

**App.xojo_code** — register routes:
```
mRouter.Get("/", "HomeViewModel")
mRouter.Get("/login", "LoginViewModel")
mRouter.Post("/login", "LoginViewModel")
mRouter.Get("/logout", "LogoutViewModel")
```

**Deliverable:** Login form works, session persists across pages.

---

### Sprint 3 — Database + First CRUD Feature (parallel agents)

**Goal:** Product list/detail pages backed by SQLite database.

**Agent A — Database + Model:**

```
Models/AppDatabase.xojo_code
  Module AppDatabase
    - Shared Function Connection() As SQLiteDatabase
    - Shared Sub Initialize()   ← create tables if not exist, seed data
    - Private Shared mDB As SQLiteDatabase

Models/ProductModel.xojo_code
  Class ProductModel
    - Function GetAll() As Variant()       ← Variant() of Dictionary
    - Function GetByID(id As Integer) As Dictionary
    - Function Create(name, price, stock) As Integer  ← returns new ID
    - Function Update(id, name, price, stock) As Boolean
    - Function Delete(id As Integer) As Boolean
```

**Agent B — ViewModels (parallel with Agent A):**

```
ViewModels/ProductListViewModel.xojo_code
  Class ProductListViewModel extends BaseViewModel
    - OnGet(): call ProductModel.GetAll(), render products/list.html

ViewModels/ProductDetailViewModel.xojo_code
  Class ProductDetailViewModel extends BaseViewModel
    - OnGet(): get :id param, call ProductModel.GetByID(), render detail or 404

ViewModels/StaticFileViewModel.xojo_code
  Class StaticFileViewModel extends BaseViewModel
    - OnGet(): read :file param, serve file from resources folder
               (only allow specific extensions: .css, .js, .ico, .png)
```

**Agent C — Templates (parallel):**
```
templates/products/list.html    ← table with loop, "Add New" button, flash message
templates/products/detail.html  ← single product view, Edit/Delete buttons
```

**Deliverable:** `/products` shows real data from SQLite. Full page cycle works.

---

### Sprint 4 — Full CRUD + Polish (parallel agents)

**Goal:** Create, Edit, Delete products. Error handling. Static files.

**Feature Agent:**
```
ViewModels/ProductCreateViewModel.xojo_code  ← GET: show form, POST: insert, redirect
ViewModels/ProductEditViewModel.xojo_code    ← GET: show prefilled form, POST: update
ViewModels/ProductDeleteViewModel.xojo_code  ← POST only: delete, redirect
```

**Template Agent:**
```
templates/products/form.html   ← shared create/edit form ({% if product.id %} for edit)
```

**QA/Fix Agent — final pass:**
- CSRF token implementation (generate on GET, validate on POST)
- Auth guard on all product routes (`IsAuthenticated()` check)
- Template caching (compile once, store `CompiledTemplate` in Dictionary keyed by name)
- Thread-safe DB access (Mutex around connection)

**Deliverable:** Complete working CRUD demo, ready for production hardening.

---

## 6. Agent Prompt Templates

Each sub-agent MUST be given these files as context when launched:

### For any Xojo-writing agent:

```
Context files to read FIRST before writing any code:
1. /mvvm/MVVM_Architecture_Proposal.md  ← architecture decisions
2. /JinjaX_Implementation/CLAUDE.md     ← Xojo coding rules (CRITICAL)

Key rules from CLAUDE.md to remember:
- Module constants are always Double
- Variant nil: use value.Type = Variant.TypeNil (NOT Is Nil)
- Integer literals: use Assert.IsTrue(x = 1) not Assert.AreEqual(1, x)
- String concatenation in loops: use String.FromArray()
- Function return values must use Call if discarding result
- Try/Catch: use separate variables in each Try block
- Catch: always "Catch e As RuntimeException"
- No "Object" as property name (reserved word) — use "Obj"
- Array assignment to Variant(): use .Add() not direct assignment

Architecture rules:
- All template data must be Dictionary objects (not custom classes)
- ViewModels never reference WebPage controls
- Models return Dictionary or Variant() of Dictionary
- Per-user state goes in WebSession (Session class), NEVER in App
```

### For the Template Agent:

```
Context files to read FIRST:
1. /mvvm/MVVM_Architecture_Proposal.md — Section 11: JinjaX Template Feature Reference

You write ONLY .html files. You know nothing about Xojo.
Use Bootstrap 5 via CDN for styling.
All templates extend templates/layouts/base.html.
Template data will be Dictionary objects — use dot notation: {{ user.name }}.
For lists, use: {% for item in items %}...{% endfor %}
Empty lists: {% else %} clause inside for loops.
Flash messages: {% if flash_message %}...{% endif %}
```

### For the QA/Fix Agent:

```
Context files to read FIRST:
1. /mvvm/errors.txt             ← current compilation errors
2. /JinjaX_Implementation/CLAUDE.md ← Xojo coding rules with all known fixes

Process:
1. Read all errors in errors.txt
2. Group by file name
3. For each file with errors: Read the file, understand the errors, apply the fix
4. Do NOT change the fix for file A while fixing file B — apply fixes one file at a time
5. After fixing, note which files were changed so Orchestrator can re-analyze

Common error → fix patterns:
- "Ambiguous method call" on Assert → use Assert.IsTrue(x = expected)
- "You must use the value returned" → add Call prefix
- "TypeMismatchException" on Variant array → use .Add() loop
- "Is Nil" on Variant → use .Type = Variant.TypeNil
- "Object" property name → rename to Obj
- "Nothing" keyword → rename to Nil
```

---

## 7. xojo_run Integration

### `analyze.sh` (project-local script, lives in `mvvm/`)

The `analyze.sh` script at the root of the mvvm project bridges the gap between the macOS IDE and the Linux VM.

```bash
# Full workflow from macOS terminal:
cd "/path/to/mvvm"

# Step 1: Trigger Xojo analysis
./analyze.sh

# Step 2: If errors appeared in Issues panel:
#   Right-click Issues → Copy All
./analyze.sh save    # saves clipboard to errors.txt

# Step 3: Paste 'errors.txt content to Claude' prompt
#   OR Claude reads errors.txt directly from the mounted folder

# Step 4: If zero errors (clean build):
./analyze.sh clear   # signals to Claude the sprint is complete
```

### How Claude reads `errors.txt`

Since the `mvvm/` folder is mounted in the VM at `/sessions/.../mnt/mvvm/`, Claude can directly read `errors.txt`:

```python
# Claude uses Read tool on:
/sessions/youthful-cool-goldberg/mnt/mvvm/errors.txt
```

An empty file = clean build. Non-empty = errors to fix.

### `xojo_run` scripts path

```bash
# Host path:
/Users/worajedt/Xojo Projects/xojo_run/xojo.sh

# analyze.sh calls this automatically if found.
# Commands:
xojo.sh open   /path/to/project.xojo_project
xojo.sh analyze /path/to/project.xojo_project
xojo.sh run     /path/to/project.xojo_project
xojo.sh errors  # reads clipboard → /tmp/xojo_errors.txt
```

---

## 8. Quality Standards

Each sprint must pass ALL of these before moving to the next:

### Compilation
- [ ] `errors.txt` is empty (zero compilation errors)
- [ ] Zero warnings (treat warnings as errors)
- [ ] Project opens cleanly in Xojo IDE

### Architecture
- [ ] No business logic inside `App.xojo_code`
- [ ] No WebPage controls referenced anywhere outside WebPage1
- [ ] All template context variables are `Dictionary` objects
- [ ] No user-specific state stored in App class
- [ ] Every new `.xojo_code` file is registered in `.xojo_project`

### Code Style (from CLAUDE.md)
- [ ] All string concatenation in loops uses `String.FromArray()`
- [ ] All Variant nil checks use `.Type = Variant.TypeNil`
- [ ] All discarded function return values use `Call` prefix
- [ ] No bare integer literals in comparisons
- [ ] No `Object` as property/variable name

### Templates
- [ ] All templates extend `layouts/base.html`
- [ ] All user-generated content goes through auto-escape (default `Autoescape=True`)
- [ ] Trusted HTML uses `MarkupSafe.MarkupString` wrapper
- [ ] Empty states handled with `{% else %}` clause on all loops

---

## 9. Dependency Graph

```
Sprint 0: Project Setup + JinjaXLib copy
    │
    ▼
Sprint 1: Framework Layer (Router + BaseViewModel + App wiring)
    │                           │
    ▼                           ▼
Sprint 2: Auth             Templates (parallel)
    │
    ▼
Sprint 3: Database + Products
    │
    ▼
Sprint 4: Full CRUD + Polish
```

Templates can be developed in parallel with Sprints 1–3 since they have no Xojo dependencies.

---

## 10. Running the App

Once Sprint 1 completes:

```bash
# macOS terminal — run the app:
cd "/path/to/xojo_run"
./xojo.sh run "/path/to/mvvm/mvvm.xojo_project"

# Xojo IDE starts the web server on port 8080 (from .xojo_project: WebDebugPort=8080)
# Open browser: http://localhost:8080/
```

After Sprint 3, the app serves real pages:
- `http://localhost:8080/` → Home page
- `http://localhost:8080/products` → Product list from SQLite
- `http://localhost:8080/login` → Login form
- `http://localhost:8080/static/app.css` → Static file serving
