# CLAUDE.md

This file provides guidance when working with code in this repository.

---

## Part 1 — Xojo MVVM Web Framework

### Project Overview

This is a **Xojo Web 2 application** implementing a server-side rendered (SSR) MVVM architecture — similar to Flask/Django — using JinjaX as the template engine. It bypasses Xojo's built-in WebPage GUI controls entirely, routing all HTTP requests through `WebApplication.HandleURL` and rendering HTML via JinjaX templates.

**Xojo version:** 2025r3.1 (project version 2025.031)
**App type:** Web (`IsWebProject=True`)
**Debug port:** 8080
**Bundle ID:** `com.worajedt.mvvm`

### Architecture

The architecture follows a strict layered pattern:

```
Browser → HandleURL → Router → ViewModel → Model → Database
                                    ↓
                          JinjaX Template → HTML Response
```

#### Key architectural rules:
1. **Dictionary Data Contract** (most critical rule): JinjaX dot-notation (`{{ user.name }}`) only works with `Dictionary` objects. Models must return `Dictionary` or `Variant()` of `Dictionary` — never custom class instances. ViewModels build `Dictionary` contexts for templates.
2. **No WebPage controls**: All rendering goes through JinjaX HTML templates in `templates/`. The existing `WebPage1` is a placeholder to be deleted.
3. **SSR has no Session** (CRITICAL): `Self.Session` is **always Nil** in HandleURL — there is no WebSocket session in SSR mode. Never call `SetFlash()`, `Session.LogIn()`, or any session method from ViewModels. Auth uses HMAC-signed cookies instead (see Authentication Pattern below).
4. **Dependency direction**: View → ViewModel → Model (never reverse). ViewModels never reference HTML/template structure; Models never reference ViewModels.
5. **Post/Redirect/Get**: All form submissions follow POST → process → Redirect(302) → GET pattern to prevent duplicate submissions.

#### Singletons on App (shared, read-only after Opening):
- `mRouter As Router` — route registration and dispatch
- `mJinja As JinjaEnvironment` — template compilation (thread-safe after setup)
- `mAuthSecret As String` — HMAC signing key for auth cookies (generated at startup)

#### Per-request objects (created fresh, thread-safe):
- `ViewModel` instances, `CompiledTemplate`, `JinjaContext`

### Project Structure

```
Framework/       → Router, BaseViewModel, BaseModel, DBAdapter, FormParser,
                   QueryParser, RouteDefinition, JSONSerializer
Models/          → NoteModel, TagModel, UserModel (all inherit BaseModel)
ViewModels/
  Notes/         → 7 VMs (List, Detail, New, Create, Edit, Update, Delete)
  Tags/          → 7 VMs (full CRUD)
  Auth/          → LoginVM, LogoutVM, SignupVM
  API/           → NotesAPIList/Detail/Create, TagsAPIList/Detail
Tests/           → 9 XojoUnit TestGroups
JinjaXLib/       → Full JinjaX source (Jinja2-compatible engine, pure Xojo)
templates/       → layouts/, notes/, tags/, auth/, errors/
data/            → SQLite database (auto-created at startup)
developer-guide/ → Static site documentation (see Part 2)
model-toolkit/   → Research docs for future Model Toolkit app
```

### Current State

**v0.9.3** — Phase 4 complete. User-scoped notes, protected routes, cookie-based auth.

- `Framework/` — Router, BaseViewModel, BaseModel, DBAdapter, FormParser, QueryParser, RouteDefinition, JSONSerializer
- `Models/` — NoteModel (user-scoped), TagModel (global), UserModel (all return Dictionary, inherit BaseModel)
- `ViewModels/Notes/` — 7 ViewModels, full CRUD, pagination, tag associations, **all require login + user-scoped**
- `ViewModels/Tags/` — 7 ViewModels, full CRUD, **all require login** (tags remain global)
- `ViewModels/Auth/` — LoginVM, LogoutVM, SignupVM (SHA-256 + salt password storage, inline error rendering)
- `ViewModels/API/` — 5 JSON API endpoints, **all require auth** (401 JSON if not logged in)
- `Tests/` — 9 XojoUnit TestGroups: DBAdapter, BaseModel, NoteModel, NotesPagination, TagModel, NoteTagAssociation, UserModel, API, **NoteOwnership**
- `templates/` — layouts/base.html, notes/*, tags/*, auth/*, errors/*
- **Alpine.js** (via CDN) replaces custom JS — 93 → 16 lines
- **Client-side SHA-256** — plaintext passwords never cross the network
- **Cookie-based auth** — HMAC-signed `mvvm_auth` cookie via HTTP `Set-Cookie` header (SSR has no WebSocket session)
- **Protected routes** — `RequireLogin()` redirects to `/login?next=<url>`, `RequireLoginJSON()` returns 401
- Thai, emoji, all Unicode input/storage works correctly
- `/tests` URL loads XojoUnit test runner via redirect dance (see `Routing.md`)

#### DB Schema (v0.9.3)
```sql
notes      (id, title, body, created_at, updated_at, user_id)  -- user_id scopes notes per user
tags       (id, name, created_at)
note_tags  (note_id, tag_id)  -- junction, PRIMARY KEY (note_id, tag_id)
users      (id, username UNIQUE, password_hash, created_at)
```

**Developer guide:** All 20 pages updated for v0.9.3, built for EN/TH/JP (60 pages total). New "Protected Routes & User Scoping" page. Auth docs rewritten for cookie-based auth.

**Next:** Version bump to v1.0.0.

### HandleURL / Routing (Critical)

`HandleURL` is the single entry point for all HTTP requests. Its return value controls everything:

- `Return True` — this app handled the request (SSR route, or `/tests` redirect)
- `Return False` — Xojo handles it (serves bootstrap HTML, JS/CSS framework files, WebSocket)

**`request.Path` lacks the leading `/`** in Xojo Web 2. A request to `/notes` arrives with `request.Path = "notes"`. Always normalize before any path comparison:

```xojo
Var p As String = request.Path
If p.Left(1) <> "/" Then p = "/" + p
```

**The `/tests` redirect dance** — you cannot `Return False` at an arbitrary path and get bootstrap HTML (only the root `/` path gets it). Instead: `/tests` → 302 → `/?_xojo=1` → `Return False` at root → Xojo bootstrap → `Default.Shown` trampolines to `XojoUnitTestPage`. Full details in `Routing.md`.

**Navigating from a Xojo WebPage back to MVVM:** use `Session.GoToURL("/")`. `Me.Session` does not exist on `WebToolbar` — use the global `Session` directly.

### Development

This is a Xojo project — it must be opened and built in the **Xojo IDE**. There is no CLI build system. The `.xojo_code` files use Xojo's text project format and can be edited directly, but testing requires running through the IDE.

When editing `.xojo_code` files directly:
- Classes use `#tag Class` / `#tag EndClass` delimiters
- Methods use `#tag Method` / `#tag EndMethod` with metadata attributes
- Events use `#tag Event` / `#tag EndEvent`
- WebPages have a layout section (`Begin WebPage ... End`) followed by `#tag WindowCode`

### String Indexing (CRITICAL)

Xojo 2025 strings and arrays are **fully 0-based** with the modern API. `Mid()` is a legacy 1-based VB function — never use it. Use `String.Middle()`.

| Method | Base | Notes |
|--------|------|-------|
| `String.IndexOf("x")` | **0-based** | Returns `0` for first character |
| `String.Middle(index, len)` | **0-based** | Aligns with `IndexOf` naturally |
| `String.Left(n)` / `Right(n)` | count-based | Index-agnostic — always safe |

```xojo
// WRONG: Mid() is 1-based legacy — silently wrong when used with IndexOf
Var value As String = pair.Mid(eqPos + 1)

// CORRECT: Middle() is 0-based — eqPos+1 skips past the '=' cleanly
Var value As String = pair.Middle(eqPos + 1)
```

Counter loops use 0-based `Middle` with `i < s.Length`:

```xojo
Var i As Integer = 0
While i < s.Length
  Var ch As String = s.Middle(i, 1)
  i = i + 1
Wend
```

### UTF-8 / Percent-Decoding

**Never use `Chr(code)` per decoded byte.** `Chr()` maps integers to Unicode code points — `Chr(0xE0)` is `à`, not the UTF-8 byte `0xE0`. This corrupts any multi-byte character (Thai, emoji, etc.).

Correct pattern — collect raw bytes in a `MemoryBlock`, then `DefineEncoding(..., Encodings.UTF8)`:

```xojo
mb.Byte(byteCount) = Integer.FromHex(hex)
byteCount = byteCount + 1
// after loop:
Return DefineEncoding(mb.StringValue(0, byteCount), Encodings.UTF8)
```

### JinjaX Template Reference

Templates use Jinja2 syntax: `{{ var }}`, `{% if %}`, `{% for %}`, `{% extends %}`, `{% include %}`, `{% block %}`. Autoescape is on by default. Custom filters registered via `env.RegisterFilter()`. Templates loaded from filesystem via `JinjaX.FileSystemLoader`.

---

## Part 2 — Developer Guide (Static Site Generator)

The `developer-guide/` directory is a self-contained Python static site generator that produces the framework's documentation website. **This system is the canonical template for all future Xojo MVVM documentation.** Every feature described below must be preserved when adding new pages or expanding the docs.

### Quick Reference

```bash
cd developer-guide/
python3 build.py              # build EN + TH + JP
python3 build.py --lang en    # build English only
python3 build.py --translate  # regenerate TH + JP via Claude Haiku (needs ANTHROPIC_API_KEY)
```

Output goes to `developer-guide/dist/`. The site is fully static — serve any directory with any web server.

### Stack

| Layer | Tool | Notes |
|-------|------|-------|
| Build | Python 3, `build.py` | Single script, no framework |
| Markdown | `python-markdown` | Fenced code, TOC, tables, admonitions |
| Layout | Jinja2 (`page.html`) | One shared template for all languages |
| Syntax highlight | Pygments (class-based) | `noclasses=False`; CSS handles theming |
| Xojo lexer | `xojo_lexer.py` | Custom Pygments `RegexLexer` for Xojo |
| Diagrams | nomnoml via Node.js | Server-side SVG at build time |
| Translations | Claude Haiku 4.5 | Auto-translate EN → TH, JP |
| Nav | `nav.yaml` | Defines structure, titles, slugs |

Python dependencies (`requirements.txt`): `markdown`, `jinja2`, `pygments`, `pyyaml`
Node dependency (`package.json`): `nomnoml`

### Directory Structure

```
developer-guide/
├── build.py              ← Static site generator (single entry point)
├── xojo_lexer.py         ← Pygments Xojo language lexer
├── nav.yaml              ← Navigation structure (sections → pages)
├── requirements.txt      ← Python deps
├── package.json          ← Node dep (nomnoml)
├── src/
│   ├── _layout/
│   │   └── page.html     ← Shared Jinja2 layout (ALL languages use this)
│   ├── _assets/
│   │   ├── style.css     ← All CSS including both light+dark token colors
│   │   └── docs.js       ← All interactive JS (theme toggle, TOC, diagrams)
│   ├── pages/            ← English source Markdown
│   │   └── 01-concepts/index.md  (example)
│   ├── pages_th/         ← Thai translations (auto-generated, committed)
│   └── pages_jp/         ← Japanese translations (auto-generated, committed)
└── dist/                 ← Built output (gitignored)
    ├── assets/           ← Copied from src/_assets/
    ├── en/               ← English site
    ├── th/               ← Thai site
    └── jp/               ← Japanese site
```

### nav.yaml Structure

`nav.yaml` is the single source of truth for navigation. Every page that should appear in the sidebar must be listed here.

```yaml
title: "MVVM Docs"
version: "v0.3.0"
repo: "https://github.com/worajedt/mvvm"

sections:
  - title: "Getting Started"
    pages:
      - title: "Introduction"
        slug: "index"
        src: "pages/index.md"
  - title: "Architecture"
    pages:
      - title: "Why MVVM?"
        slug: "concepts/index"
        src: "pages/01-concepts/index.md"
```

- `slug` determines the output path under `dist/{lang}/`
- `src` is relative to `developer-guide/src/`
- The corresponding TH/JP files are at `pages_th/` and `pages_jp/` mirroring the same path

### Page Frontmatter

Every Markdown source file starts with YAML frontmatter:

```markdown
---
title: "Page Title"
description: "One-sentence description shown under the title."
---

Content here...
```

### Theming System (CRITICAL — do not break)

The site has a **full Day/Night theme toggle** that:
- Persists selection in `localStorage` under the key `theme` (`"light"` or `"dark"`)
- Shares state **across all language versions** (EN/TH/JP) automatically via `localStorage` on the same domain
- Applies **instantly on page load** with zero flash (FOUC prevention) via an inline `<script>` in `<head>` that reads `localStorage` before the browser paints
- Toggles with a moon/sun button in the topbar

#### Theme implementation rules:
1. **Never add inline `style=` color attributes to HTML.** All colors come from CSS custom properties (`var(--...)`) or Pygments CSS classes (`.k`, `.kt`, etc.).
2. **All color tokens are scoped** — `[data-theme="light"] .prose .highlight .k { ... }` and `[data-theme="dark"] .prose .highlight .k { ... }`. There are no unscoped token color rules.
3. **Pygments must use `noclasses=False`** in `build.py`. Never switch back to `noclasses=True` (inline styles) — that breaks theming.
4. The `<html>` element carries `data-theme="light"` as the default. The inline `<script>` in `<head>` overrides it from `localStorage` before paint.
5. **All new CSS** that references colors must use CSS custom properties from the theme blocks in `style.css`, not hardcoded hex values.

#### CSS custom property blocks in `style.css`:
- `:root, [data-theme="light"]` — Day theme (white page, GitHub-light code, B&W diagrams)
- `[data-theme="dark"]` — Night theme (GitHub dark page, atom-one-dark code, inverted diagrams)

#### Theme toggle variables:
```css
/* Controls icon visibility via CSS, no JS needed */
--icon-moon-display: block;   /* Day: show moon (click to go dark) */
--icon-sun-display:  none;
```

### Xojo Syntax Highlighting

The Xojo lexer (`xojo_lexer.py`) is a Pygments `RegexLexer` registered at build time. It is called automatically by `CodeHiliteExtension` when a fenced code block uses ` ```xojo `.

#### Token categories and CSS classes:

| Token | Pygments class | Day color | Night color |
|-------|---------------|-----------|-------------|
| Keywords (`Var`, `Sub`, `If`, …) | `.k .kd .kn` | `#cf222e` red | `#c678dd` purple |
| Operator keywords (`And`, `Or`, `Not`, …) | `.ow` | `#cf222e` red | `#56b6c2` cyan |
| Types (`Integer`, `String`, …) | `.kt` | `#0550ae` blue | `#56b6c2` cyan |
| Constants (`True`, `False`, `Nil`) | `.kc` | `#0550ae` blue | `#d19a66` orange |
| Builtins (`Self`, `Super`, `Me`) | `.bp` | `#953800` brown | `#e06c75` red |
| Strings (`"..."`) | `.s2` | `#0a3069` navy | `#98c379` green |
| Numbers (`42`, `&hFF`, `&b1010`) | `.m .mh .mb` | `#0550ae` blue | `#d19a66` orange |
| Preprocessor (`#tag`, `#if`, …) | `.cp` | `#953800` brown | `#e5c07b` yellow |
| Comments (`//`, `'`) | `.c1` | `#6e7781` grey | `#6a737d` grey |
| Identifiers | `.n` | `#1f2328` dark | `#abb2bf` light |

#### Critical lexer rules:
- **Case-insensitive** (`re.IGNORECASE`) — Xojo is case-insensitive
- **`'` is always a comment** — Xojo strings use double-quotes only
- **Preprocessor** (`#tag`, `#pragma`, `#if`, `#elseif`, `#else`, `#endif`, `#region`, `#endregion`) consumes the entire line as `Comment.Preproc` (class `.cp`)
- **Hex** `&hFF` → `Number.Hex` (`.mh`), **Binary** `&b1010` → `Number.Bin` (`.mb`)
- **Lexer registration**: `xojo_lexer.register()` is called in `build.py` before Pygments runs. It inserts into `LEXERS` + `_lexer_cache["Xojo"]` — no `pip install` needed.

### Diagrams (CRITICAL — do not change renderer)

All diagrams use **nomnoml** rendered server-side at build time via a Node.js subprocess. The resulting SVG is embedded inline in the HTML — no client-side JS required.

#### Why nomnoml:
- Natively B&W with `#fill: white` / `#stroke: black` — no post-processing
- ~8 KB SVG (vs. hundreds of KB for D2 which embeds base64 fonts)
- Night mode: CSS `filter: invert(1)` on the SVG inverts to white-on-dark automatically
- Transitions smoothly with `transition: filter .25s ease`

#### Diagram block format — MUST follow exactly:

```
<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#lineWidth: 1.5
[A] -> [B]
[B] -> [C]
-->
<!-- ascii
A → B → C
-->
<!-- /diagram -->
```

The build extracts `<!-- nomnoml ... -->` source, pipes it to `node -e "..."` via stdin, and embeds the returned SVG. The `<!-- ascii ... -->` block is the fallback tab (plain text, accessible).

#### Required header for every nomnoml block:

```
#fill: white
#stroke: black
#direction: down   (use "right" for left-to-right diagrams)
#lineWidth: 1.5
```

#### nomnoml syntax reference:

```
[Simple node]                    plain box
[Name: Display Label]            box with internal label
[<database> Name]                cylinder shape (for databases)
[A] -> [B]                       directed arrow
[A] label -> [B]                 arrow with label (label before arrow)
[A] <-> [B]                      bidirectional arrow
[A] -- [B]                       association (no arrowhead)
```

#### Diagram tab widget (auto-generated by build.py):

Each `<!-- diagram -->` block renders as a tabbed widget with two panels:
- **Diagram** tab (default): inline nomnoml SVG
- **ASCII** tab: plain-text fallback from `<!-- ascii ... -->`

The `switchDiagram(uid, panel, btn)` function in `docs.js` handles tab switching. No re-rendering occurs — SVG is already embedded.

### Multilingual System

The site supports three languages: English (`en`), Thai (`th`), Japanese (`jp`).

#### Source files:
- `src/pages/` — English (hand-written, canonical)
- `src/pages_th/` — Thai (auto-translated, committed to repo)
- `src/pages_jp/` — Japanese (auto-translated, committed to repo)

#### Translation workflow:
```bash
ANTHROPIC_API_KEY=sk-... python3 build.py --translate
```

`build.py` calls the Anthropic API (Claude Haiku 4.5) to translate each English Markdown page. Translations are cached on disk — re-running only regenerates missing files. The API key must be set in the environment.

#### Language switcher:
- Appears in the topbar as `EN | TH | JP` flag buttons
- Links are absolute paths (`/en/`, `/th/`, `/jp/`) — works regardless of current page depth
- The active language is highlighted

#### Critical rule: **one layout, all languages**
`src/_layout/page.html` is the **only** layout file. All three language builds use it. Never create per-language layout variants — fix the shared template instead.

### Adding a New Page

1. **Create** the Markdown file in `src/pages/your-section/page-name.md` with frontmatter.
2. **Add** an entry to `nav.yaml` under the appropriate section.
3. **Run** `python3 build.py --lang en` to verify.
4. **Translate** when ready: `python3 build.py --translate` to generate TH + JP.
5. **Rebuild all**: `python3 build.py` to produce the full site.

The TH/JP source files are created at `src/pages_th/` and `src/pages_jp/` mirroring the EN path — do not create them manually.

### Adding a New Documentation Section

1. Create a numbered subdirectory: `src/pages/07-new-topic/`
2. Add an `index.md` with frontmatter
3. Add a section block to `nav.yaml`
4. Follow the same page-addition steps above

### Code Block Usage in Markdown

````markdown
```xojo
Var x As Integer = 42
If x > 10 Then Return "big"
```

```python
result = build.run()
```

```html
<div class="highlight">...</div>
```

```sql
SELECT id, title FROM notes WHERE active = 1
```
````

All fenced code blocks are highlighted by Pygments. Xojo blocks use the custom `xojo_lexer.py`. Other languages use Pygments' built-in lexers. The language name appears as a label above the block.

### Admonitions (Callout Blocks)

```markdown
!!! note
    This is an informational note.

!!! warning
    This is a warning.

!!! tip
    This is a tip.
```

Rendered with themed backgrounds and colored left borders. Both Day and Night themes have distinct admonition colors defined as CSS variables.

### CSS Architecture (Do Not Break)

`src/_assets/style.css` is structured in this order — maintain this order when editing:

1. `:root` — layout + typography variables (never-changing)
2. `:root, [data-theme="light"]` — Day theme CSS variables
3. `[data-theme="dark"]` — Night theme CSS variables
4. Reset & base
5. Topbar, layout grid, sidebar, TOC, prose
6. Code blocks (structural only — no colors)
7. Pygments token colors — **`[data-theme="light"]` rules first, then `[data-theme="dark"]`**
8. Tables, admonitions, definition lists, page navigation
9. Responsive breakpoints
10. Theme toggle button, language switcher
11. Diagram tab widget, nomnoml panel, ASCII panel

### JS Architecture

`src/_assets/docs.js` contains all client-side behaviour in this order:

1. `toggleTheme()` — Day/Night switch (reads/writes `localStorage`, sets `data-theme` on `<html>`)
2. `toggleSidebar()` + click-outside handler — mobile sidebar
3. `switchDiagram(uid, panel, btn)` — diagram tab switching (SVG already embedded, no re-render)
4. DOMContentLoaded: hide ASCII panels by default
5. TOC active link on scroll (IntersectionObserver-style with `scrollY`)
6. Code block language label injection (reads `.language-*` class, sets `data-lang` attribute)
7. Smooth scroll for `<a href="#anchor">` links

**Never add** `document.write`, inline event handlers (except `onclick=` in the layout template), or external script dependencies.

### FOUC Prevention (Theme Flash)

The inline `<script>` in `<head>` of `page.html` runs synchronously before the browser renders anything:

```html
<script>
  (function () {
    var t = localStorage.getItem('theme');
    if (t === 'dark' || t === 'light') {
      document.documentElement.setAttribute('data-theme', t);
    }
  })();
</script>
```

This must remain as the **last element in `<head>`**, after the stylesheet link. Do not move it, do not make it `async` or `defer`, and do not merge it into `docs.js` — that would cause a flash.

### Build Pipeline Detail

`build.py` processes each page in this order:

1. Load `nav.yaml` → navigation structure + flat page list
2. For each language, for each page:
   a. Read Markdown source (EN or translated TH/JP)
   b. Parse YAML frontmatter
   c. `process_diagrams()` — extract `<!-- diagram -->` blocks, render nomnoml → SVG, substitute inline
   d. `markdown.Markdown.convert()` — convert remaining Markdown to HTML (with Pygments, TOC, etc.)
   e. `extract_toc()` — build TOC item list from headings
   f. `find_neighbours()` — prev/next page links
   g. Render `page.html` Jinja2 template with all context variables
   h. Write to `dist/{lang}/{slug}.html`
3. Copy `src/_assets/` → `dist/assets/`

### Version Milestones

| Version | What was completed |
|---------|-------------------|
| v0.1.0 | Basic routing, HandleURL, Router |
| v0.2.0 | Notes CRUD, JinjaX templates, BaseViewModel |
| v0.3.0 | Full CRUD, FormParser, Unicode/UTF-8, flash messages |
| v0.4.0 | BaseModel/DBAdapter, XojoUnit test runner at `/tests` |
| v0.4.2 | Production path fix (relative to executable) |
| v0.5.0 | Pagination (Phase 3.1) |
| v0.6.0 | Tags CRUD (Phase 3.2) |
| v0.7.0 | Notes↔Tags associations (Phase 3.3) |
| v0.8.0 | Authentication — login, signup, session (Phase 3.4) |
| v0.9.0 | JSON API endpoints (Phase 3.5) |
| v0.9.1 | Auth UX — client-side SHA-256, SSR session workarounds |
| v0.9.2 | Alpine.js — 93 → 16 lines of custom JS |
| v0.9.3 | User-scoped notes, protected routes, cookie-based auth (Phase 4) |
| pygment | Xojo Pygments lexer (`xojo_lexer.py`) working |
| dark-light | Day/Night theme toggle, cross-language state sharing |
| docs-0.9.3 | Developer guide updated for Phase 3+4 (cookie auth, protected routes, user scoping) |

---

## Part 3 — Development Notes & Gotchas

### Never Do These Things

| What | Why |
|------|-----|
| Use `noclasses=True` in `CodeHiliteExtension` | Bakes inline styles — breaks theme switching |
| Add hardcoded hex colors in CSS | Must use `var(--...)` for theme switching |
| Add inline `style=` color in HTML templates | Same reason |
| Create per-language `page.html` files | One layout for all — fix the shared template |
| Use `Mid()` in Xojo | 1-based legacy, silently wrong; use `String.Middle()` |
| Use `Chr(byte)` for UTF-8 decoding | Corrupts multi-byte chars; use `MemoryBlock` + `DefineEncoding` |
| Store user data on `App` | App is shared across all sessions; use cookies (not `Session` — it's Nil in SSR) |
| Use `SetFlash()` or `Session.LogIn()` in SSR | `Self.Session` is always Nil in HandleURL; use cookies + inline error rendering |
| Move the inline theme script to `docs.js` | Causes FOUC on every page load |
| Use MermaidJS or D2 for diagrams | MermaidJS bakes inline colors; D2 produces 200KB+ SVGs |

### Xojo Gotchas (Phase 3+4)

| What | Why / Fix |
|------|-----------|
| `Self.Session` is Nil in HandleURL | SSR mode has no WebSocket — no Xojo session. Use cookies for auth, sessionStorage for flash. |
| `SetFlash()` does nothing in SSR | Session is Nil. Render errors inline via template context variable instead. |
| `Response.Header("Set-Cookie")` works in HandleURL | Proven to work — use this for auth cookies, not JS `document.cookie` |
| `Crypto.SHA256(s)` returns MemoryBlock | Use `EncodeHex(Crypto.SHA256(s))` — there is no `.Hex` method |
| No `Math.Ceiling()` in Xojo | Use integer arithmetic: `(total + perPage - 1) \ perPage` |
| `Assert.AreEqual(0, someInt)` is ambiguous | Xojo can't pick overload — use `Assert.IsTrue(someInt = 0)` |
| FormParser was single-value (last-wins) | Changed to comma-append for duplicate keys (multi-value checkboxes) |
| Missing Dictionary key in JinjaX template | Always populate all keys templates expect, even with empty defaults |

### Authentication Pattern (CRITICAL — Cookie-Based, Not Session-Based)

**`Self.Session` is always Nil in SSR HandleURL.** There is no WebSocket session in SSR mode. All auth is cookie-based.

- **Password storage:** `SHA256(clientHash + salt):salt` in a single TEXT column (client sends SHA-256 hash, server adds salt)
- **Salt:** random via `Crypto.GenerateRandomBytes(16)`, hex-encoded
- **Verify:** split stored value on `:`, recompute hash with extracted salt
- **Client-side:** Web Crypto API hashes password before form submit (plaintext never sent)
- **Auth cookie:** HMAC-signed `mvvm_auth=userID:username:SHA256(userID:username:secret)` set via HTTP `Set-Cookie` header
- **`App.mAuthSecret`:** random 32-byte hex string generated at startup for HMAC signing
- **`ParseAuthCookie()`:** reads `Request.Header("Cookie")`, verifies HMAC, returns user Dictionary or Nil
- **`CurrentUserID()` / `CurrentUsername()`:** read from parsed cookie (NOT from session)
- **`RequireLogin()`:** redirects to `/login?next=<encoded-url>` if not authenticated; returns True if redirect issued
- **`RequireLoginJSON()`:** returns 401 JSON `{"error":"Authentication required"}` for API endpoints
- **`RedirectWithAuth()`:** HTTP `Set-Cookie` header + JS intermediate page for localStorage/sessionStorage
- **`RedirectWithLogout()`:** `Set-Cookie: Max-Age=0` + JS clears localStorage
- **Nav auth state:** localStorage stores username (set by JS intermediate page on login/signup)
- **Flash messages:** sessionStorage (set by JS intermediate page), read by Alpine.js on next page load
- **Error display:** login/signup errors rendered inline via `error_message` template variable (NOT SetFlash — that requires session)
- **User-scoped notes:** `NoteModel` methods all require `userID` parameter; `WHERE user_id = ?` in every query
- **Global tags:** Tags are shared across all users — only require login, no user scoping

### JSON API Pattern

- `JSONSerializer` module: `EscapeString`, `DictToJSON`, `ArrayToJSON`
- API ViewModels call `WriteJSON()` instead of `Render()` — no templates needed
- POST endpoints accept `application/x-www-form-urlencoded` (reuses FormParser)
- Embed sub-arrays by string manipulation: strip closing `}`, append `,"key":arrayJSON}`

### Alpine.js Integration

- Loaded via CDN (`defer`, no build step)
- Replaces all custom JS: auth state, flash messages, form validation, tag checkboxes
- Pattern: `x-data` on elements, `@submit.prevent` for forms, `x-show`/`x-text` for reactive UI
- Tag checkboxes use native `name="tag_ids"` multi-value (FormParser handles comma-append)
- Do NOT add htmx until a specific trigger-based feature requires it (see memory)

### Environment Requirements

```bash
# Python
pip install markdown jinja2 pygments pyyaml

# Node (for nomnoml rendering at build time)
cd developer-guide/
npm install

# Optional: translation
export ANTHROPIC_API_KEY=sk-...
```

### File Encoding

All source files are UTF-8. Xojo `.xojo_code` files are also UTF-8. The build reads and writes with `encoding="utf-8"` explicitly. Never add BOM markers.
