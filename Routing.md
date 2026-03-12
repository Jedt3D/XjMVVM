# Routing Architecture

How HTTP requests flow through this Xojo Web 2 SSR application, how Xojo's own WebSocket UI framework is bypassed, and how to cross between the two worlds.

---

## Two Worlds Inside One App

A Xojo Web 2 application hosts two fundamentally different request-handling systems simultaneously:

| World | Mechanism | Response type |
|-------|-----------|---------------|
| **MVVM (SSR)** | `HandleURL` → Router → ViewModel → JinjaX | Plain HTTP, stateless HTML |
| **Xojo WebPage** | Bootstrap HTML → WebSocket → Session → WebPage controls | Stateful, event-driven UI |

Every HTTP request enters through `HandleURL`. The return value of `HandleURL` is the fork:

- `Return True` — we handled it, Xojo does nothing further
- `Return False` — Xojo handles it (serves bootstrap HTML, JS framework files, or WebSocket messages)

```
              ┌─────────────────────────────────────────┐
Browser GET   │           HandleURL (App)                │
─────────────>│                                         │
              │  normalize path                         │
              │  check route table                      │
              │       │                                 │
              │    matched?                             │
              │   Yes │    No                           │
              │       ▼        ▼                        │
              │  Return True  Return False              │
              └──────┬──────────────┬──────────────────┘
                     │              │
                     ▼              ▼
               Our ViewModel   Xojo framework
               → JinjaX HTML   → Bootstrap HTML
               → HTTP 200       → Xojo.js + WebSocket
```

---

## The MVVM World (SSR)

All SSR routes return `True` from `HandleURL`. Xojo never touches them.

```
Browser
  │
  │  HTTP GET /notes
  ▼
HandleURL
  │  normalize path, check /?_xojo=1 passthrough
  │  p = "/notes"  →  not a bypass path
  ▼
Router.Route()
  │  iterate mRoutes, match method + pattern
  │  ParsePath("/notes/:id", "/notes")  →  Nil (no match)
  │  ParsePath("/notes", "/notes")      →  {} (match!)
  ▼
route.Factory.Invoke()  →  New NotesListVM
  │  vm.Request, vm.Response, vm.Session, vm.Jinja, vm.PathParams
  ▼
vm.Handle()
  │  request.Method = "GET"  →  OnGet()
  ▼
OnGet()
  │  NoteModel.GetAll()  →  Variant() of Dictionary
  │  ctx.Value("notes") = results
  ▼
Render("notes/list.html")
  │  jinja.GetTemplate() → CompiledTemplate
  │  tmpl.Render(ctx)    → HTML string
  ▼
response.Status = 200
response.Write(html)
  │
  ▼
Browser receives plain HTML (no WebSocket, stateless)
```

### Why SSR / Why bypass Xojo WebPage?

| Reason | Detail |
|--------|--------|
| Standard HTTP | Every response is a plain HTML page. No WebSocket handshake overhead. |
| Stateless | Each request is independent. Scales simply; no session leakage between requests. |
| Familiar pattern | Flask/Django/Rails developers understand this model immediately. |
| Jinja2 templates | Full template inheritance, filters, blocks — richer than Xojo's WebLabel/WebContainer. |
| SEO-friendly | Content is in the initial HTTP response, not injected by JS after page load. |

### Consequence of bypassing Xojo

Because SSR routes return `True`, Xojo never establishes a WebSocket session for them. This means:

- Xojo WebPage controls (`WebLabel`, `WebListBox`, etc.) cannot be used from within a ViewModel
- Flash messages must be stored in `WebSession` (our `Session` class), not in Xojo controls
- No real-time push from server to browser (add Server-Sent Events or JS polling separately if needed)
- The `/tests` URL cannot simply `Return False` and expect bootstrap HTML — see below

---

## HandleURL Decision Tree

```
Browser GET path
       │
       ▼
  normalize p:
  prepend "/" if missing,
  strip trailing "/"
       │
       ├─── p = "/" AND QueryString = "_xojo=1"
       │         │
       │         └──► Return False  ──► Xojo serves bootstrap HTML
       │                                 (Xojo.js + WebSocket bootstrap)
       │
       ├─── p = "/tests"
       │         │
       │         └──► 302 redirect to /?_xojo=1  ──► Return True
       │
       └─── all other paths
                 │
                 └──► Router.Route(...)
                           │
                      route matched?
                      Yes │      No
                          │       │
                          ▼       ▼
                     Return True  Return False
                     (ViewModel   (Xojo serves
                      handled)     its own JS/CSS
                                   framework files)
```

### The `request.Path` Quirk (Critical)

**Xojo Web 2 omits the leading `/` from `request.Path`.**

A request to `http://localhost:8080/notes` arrives with `request.Path = "notes"`, not `"/notes"`.

Every path check must normalize first:

```xojo
Var p As String = request.Path
If p.Left(1) <> "/" Then p = "/" + p
If p.Length > 1 And p.Right(1) = "/" Then p = p.Left(p.Length - 1)
```

Without this normalization, every single path comparison silently fails — the bug is invisible because `"notes" <> "/notes"` evaluates to `True` with no error.

This was the root cause of all failed `/tests` routing attempts before the fix.

---

## Linking from MVVM to a Xojo WebPage

The use case: open `XojoUnitTestPage` (the XojoUnit test runner) from a link in the MVVM app.

### Why you can't just `Return False` at `/tests`

When `HandleURL` returns `False` for a path, Xojo attempts to serve its own framework response. But Xojo only serves bootstrap HTML at the **root path** `/`. For any other path, Xojo emits a native HTTP 404 — not our templated 404 page, but a bare browser error.

```
Browser GET /tests
  │
  HandleURL returns False at "/tests"
  │
  Xojo: "I don't know /tests"
  │
  Browser: "404 Not Found" (bare, no HTML)
            ✗ Wrong — not our 404 template, just a browser error page
```

### Why `DefaultWindow=XojoUnitTestPage` crashes

Setting `DefaultWindow=XojoUnitTestPage` in the project file makes Xojo instantiate `XojoUnitTestPage` as the first page when a WebSocket session connects. But `XojoUnitTestPage.Opening` runs toolbar setup and test group registration — code that requires the session and page to be fully wired. At bootstrap time they are not. Result: runtime crash, app quits with no visible error.

### The Redirect Dance (What Actually Works)

```
Browser GET /tests
       │
       ▼
HandleURL — p = "/tests"
  │  302 redirect to /?_xojo=1
  │  Return True  (we handled this request)
       │
       ▼
Browser follows redirect → GET /?_xojo=1
       │
       ▼
HandleURL — p = "/" AND QueryString = "_xojo=1"
  │  Return False  (let Xojo handle this)
       │
       ▼
Xojo serves bootstrap HTML at root path
  │  Xojo.js loaded by browser
  │  Browser opens WebSocket back to server
  │  WebSession fully established
       │
       ▼
DefaultWindow = Default
  │  Simple empty WebPage — cannot crash
  │  Default.Shown event fires
       │
       ▼
Default.Shown:
  Var testPage As New XojoUnitTestPage
  testPage.Show()
       │
       ▼
XojoUnitTestPage.Opening → toolbar setup ✓
XojoUnitTestPage.Shown  → test groups loaded ✓
       │
       ▼
Test runner live in browser ✓
```

#### Sequence diagram

```
Browser          HandleURL         Xojo           Default       XojoUnitTestPage
   │                 │               │               │                 │
   │──GET /tests────>│               │               │                 │
   │                 │               │               │                 │
   │<──302 /?_xojo=1─│               │               │                 │
   │                 │               │               │                 │
   │──GET /?_xojo=1─>│               │               │                 │
   │                 │──Return False─>│               │                 │
   │<──Bootstrap HTML────────────────│               │                 │
   │                                 │               │                 │
   │──WebSocket open────────────────>│               │                 │
   │                                 │──Session OK───>│                 │
   │                                 │               │──Shown()─────>  │
   │                                 │               │  .Show()─────>  │
   │                                 │               │               Opening()
   │                                 │               │               Shown()
   │<──XojoUnit UI (via WebSocket)───────────────────────────────────│
```

#### Why `/?_xojo=1` and not just `/`?

Plain `/` is a registered MVVM route (`GET /` → `HomeViewModel`). The Router would match it and return `True`, serving the MVVM home page — never reaching `Return False`. The `_xojo=1` query parameter is the sentinel that makes `HandleURL` skip the Router and pass control to Xojo. Normal browsers visiting `/` never send `_xojo=1`, so the home page is unaffected.

#### Why the `Default` trampoline?

`Default` is a trivially empty `WebPage`. Its `Shown` event fires after the session is fully established, making it the safe earliest point to instantiate `XojoUnitTestPage`. It acts as a one-step relay:

```xojo
// Default.xojo_code — Shown event
Sub Shown()
  Var testPage As New XojoUnitTestPage
  testPage.Show()
End Sub
```

`XojoUnitTestPage` has `ImplicitInstance=False` (explicit instantiation required), so `New XojoUnitTestPage` is necessary — calling `XojoUnitTestPage.Show()` directly would be a compile error.

---

## Linking Back from a Xojo WebPage to MVVM

The use case: a button on `XojoUnitTestPage` that takes the user back to the MVVM home page.

### Why an HTML `<a href>` anchor doesn't apply

`XojoUnitTestPage` is a Xojo WebPage rendered through the WebSocket UI system. There are no raw HTML anchors to set — controls are Xojo objects (`WebToolbarButton`, `WebLabel`, etc.) that communicate back to the server via the WebSocket, not via plain HTTP.

### The correct API: `Session.GoToURL(url)`

`WebSession.GoToURL` sends a navigation instruction to the browser, telling it to load a new URL as a top-level navigation. This breaks out of the WebSocket session entirely and loads a fresh plain HTTP request, which `HandleURL` will route normally.

```xojo
// XojoUnitTestPage.Toolbar1.Pressed event
Sub Pressed(item As WebToolbarButton)
  Select Case item.Caption
  Case "XjMVVM"
    Session.GoToURL("/")   // browser navigates to MVVM home
  End Select
End Sub
```

**Important:** Inside a `WebToolbar.Pressed` event, `Me` refers to the `WebToolbar` itself, not to the page. `Me.Session` does not exist on `WebToolbar`. Use the thread-local global `Session` directly.

### Navigation API comparison

| From | To | Method | Notes |
|------|----|--------|-------|
| MVVM template (HTML) | MVVM route | `<a href="/notes">` | Standard HTML anchor |
| MVVM template (HTML) | Xojo WebPage | `<a href="/tests">` | Triggers redirect dance |
| Xojo WebPage | MVVM route | `Session.GoToURL("/")` | WebSession API, browser navigates |
| Xojo WebPage | Xojo WebPage | `page.Show()` | WebSocket-internal, no URL change |

---

## Router.Route() Returns Boolean

`Router.Route()` is a `Function As Boolean`, not a `Sub`. This is required for the `HandleURL` chain to work correctly.

When a request arrives for a Xojo framework resource (e.g., `/framework/Xojo.js`, `/websocket`), no MVVM route matches. `Router.Route()` returns `False`, and `HandleURL` propagates that `False` to Xojo's own handler, which serves the file. If `Route()` were a `Sub` (or always returned `True`), those resources would be blocked and the WebSocket session would never establish — breaking the `/tests` flow entirely.

```
GET /framework/Xojo.js
  │
  HandleURL
  │  Router.Route() → no match → returns False
  │  HandleURL returns False
  │
  Xojo: serves /framework/Xojo.js natively ✓
```

---

## State Summary

```
Request arrives at HandleURL
         │
         ▼
    ┌────────────────────────────────────────────┐
    │              Path States                   │
    ├────────────────────────────────────────────┤
    │  p = "/" + qs = "_xojo=1"                 │
    │    → Return False                          │
    │    → Xojo bootstrap (for /tests redirect)  │
    ├────────────────────────────────────────────┤
    │  p = "/tests"                              │
    │    → 302 to /?_xojo=1                     │
    │    → Return True                           │
    ├────────────────────────────────────────────┤
    │  p matches SSR route (/, /notes, etc.)     │
    │    → ViewModel handles it                  │
    │    → Return True                           │
    ├────────────────────────────────────────────┤
    │  p matches nothing (Xojo JS/CSS/WS)        │
    │    → Router returns False                  │
    │    → HandleURL returns False               │
    │    → Xojo serves its own file              │
    └────────────────────────────────────────────┘
```

---

## Files Reference

| File | Role |
|------|------|
| `App.xojo_code` | `HandleURL` — the entry point; path normalization, `/tests` redirect, `/?_xojo=1` passthrough |
| `Framework/Router.xojo_code` | Route registration (`Get`, `Post`, `Any`), path matching (`ParsePath`), dispatch, error pages |
| `Default.xojo_code` | Trampoline WebPage — `Shown` event shows `XojoUnitTestPage` after session is established |
| `mvvm.xojo_project` | `DefaultWindow=Default` — must be `Default`, not `XojoUnitTestPage` |
| `XojoUnit/XojoUnitTestPage.xojo_code` | Test runner WebPage; XjMVVM toolbar button uses `Session.GoToURL("/")` |
