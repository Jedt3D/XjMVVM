---
title: "Routing Architecture"
description: How HTTP requests flow through HandleURL, when Xojo takes over, and how to safely cross between the SSR world and Xojo WebPage controls.
---

# Routing Architecture

## Two Worlds Inside One App

A Xojo Web 2 application hosts two fundamentally different request-handling systems simultaneously. Every HTTP request enters through `HandleURL`, and its return value decides which world handles it.

| World | Entry point | Response |
|-------|-------------|----------|
| **MVVM (SSR)** | `HandleURL` → Router → ViewModel → JinjaX | Plain HTTP, stateless HTML |
| **Xojo WebPage** | Bootstrap HTML → WebSocket → Session → controls | Stateful, event-driven UI |

- `Return True` — this app handled it; Xojo does nothing further
- `Return False` — Xojo handles it (serves bootstrap HTML, JS framework files, or WebSocket messages)

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 40
#padding: 10
#lineWidth: 1.5
[Browser] -> [HandleURL: App.HandleURL]
[HandleURL: App.HandleURL] Return True -> [MVVM SSR]
[HandleURL: App.HandleURL] Return False -> [Xojo Framework]
[MVVM SSR] -> [ViewModel]
[ViewModel] HTML -> [Browser]
[Xojo Framework] -> [WebSocket Session]
[WebSocket Session] UI events -> [Browser]
-->
<!-- ascii
Browser
  │
  ▼
App.HandleURL
  ├─ Return True  →  MVVM SSR  →  ViewModel  →  HTML  →  Browser
  └─ Return False →  Xojo Framework  →  WebSocket Session  →  Browser
-->
<!-- /diagram -->

---

## HandleURL Decision Tree

`HandleURL` applies a fixed order of checks before dispatching any request. Path normalization comes first — every comparison depends on it.

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 32
#padding: 8
#lineWidth: 1.5
[Browser GET path] -> [Normalize path]
[Normalize path] -> [p = "/" AND _xojo=1?]
[p = "/" AND _xojo=1?] Yes -> [Return False: Xojo bootstrap]
[p = "/" AND _xojo=1?] No -> [p = "/tests"?]
[p = "/tests"?] Yes -> [302 redirect to /?_xojo=1]
[302 redirect to /?_xojo=1] -> [Return True]
[p = "/tests"?] No -> [Router.Route(...)]
[Router.Route(...)] matched -> [ViewModel handles request]
[ViewModel handles request] -> [Return True]
[Router.Route(...)] no match -> [Return False: Xojo serves file]
-->
<!-- ascii
Browser GET path
  │
  ▼
Normalize: prepend "/" if missing, strip trailing "/"
  │
  ├─ p = "/" AND QueryString = "_xojo=1"
  │     └── Return False  →  Xojo serves bootstrap HTML
  │
  ├─ p = "/tests"
  │     └── 302 redirect to /?_xojo=1  →  Return True
  │
  └─ all other paths
        └── Router.Route(...)
              ├─ matched  →  ViewModel.Handle()  →  Return True
              └─ no match →  Return False  →  Xojo serves JS/CSS/WebSocket
-->
<!-- /diagram -->

### The `request.Path` Quirk

!!! warning
    Xojo Web 2 omits the leading `/` from `request.Path`. A request to `/notes` arrives with `request.Path = "notes"`, not `"/notes"`. Every path comparison silently fails without normalization.

Always normalize before any path check:

```xojo
Var p As String = request.Path
If p.Left(1) <> "/" Then p = "/" + p
If p.Length > 1 And p.Right(1) = "/" Then p = p.Left(p.Length - 1)
```

Without this, `"notes" <> "/notes"` evaluates `True` with no error — every route match fails silently.

---

## The MVVM Request Pipeline

For any matched SSR route, the full pipeline from `HandleURL` to HTML response:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 28
#padding: 8
#lineWidth: 1.5
[HandleURL] normalize + match -> [Router]
[Router] factory.Invoke() -> [ViewModel]
[ViewModel] OnGet / OnPost -> [Model]
[<database> Model] Dictionary -> [ViewModel]
[ViewModel] context -> [JinjaX Template]
[JinjaX Template] HTML string -> [response.Write]
[response.Write] Return True -> [Browser]
-->
<!-- ascii
HandleURL  →  normalize path, match route
Router     →  factory.Invoke()  →  new ViewModel
ViewModel  →  OnGet() / OnPost()
Model      →  returns Dictionary / Variant() of Dictionary
ViewModel  →  builds context Dictionary
JinjaX     →  CompiledTemplate.Render(context)  →  HTML string
response.Write(html)  →  Return True  →  Browser
-->
<!-- /diagram -->

Because SSR routes return `True`, Xojo never establishes a WebSocket session for them. This means Xojo WebPage controls (`WebLabel`, `WebListBox`, etc.) cannot be used from a ViewModel, and there is no real-time push from server to browser without adding Server-Sent Events or JS polling separately.

---

## The `/tests` Redirect Dance

The test runner (`XojoUnitTestPage`) is a Xojo WebPage — it needs a live WebSocket session. Getting there from an MVVM link requires a three-step dance.

### Why you can't just `Return False` at `/tests`

Xojo only serves its bootstrap HTML at the **root path** `/`. For any other path, returning `False` produces a bare browser 404 — not the MVVM 404 template, just a browser error page.

### Why `DefaultWindow=XojoUnitTestPage` crashes

Setting `DefaultWindow=XojoUnitTestPage` in the project makes Xojo instantiate it as the first WebPage when a session connects. But `XojoUnitTestPage.Opening` runs toolbar setup and test registration — code that requires the page and session to be fully wired. At bootstrap time they are not. Result: runtime crash.

### What actually works

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 32
#padding: 8
#lineWidth: 1.5
[Browser: GET /tests] -> [HandleURL]
[HandleURL] 302 /?_xojo=1 -> [Browser: follows redirect]
[Browser: follows redirect] -> [HandleURL: GET /?_xojo=1]
[HandleURL: GET /?_xojo=1] Return False -> [Xojo Bootstrap]
[Xojo Bootstrap] WebSocket established -> [Default: Shown event]
[Default: Shown event] testPage.Show() -> [XojoUnitTestPage]
[XojoUnitTestPage] Opening + Shown -> [Browser: Test Runner UI]
-->
<!-- ascii
Browser GET /tests
  │
HandleURL: 302 redirect to /?_xojo=1  →  Return True
  │
Browser follows redirect → GET /?_xojo=1
  │
HandleURL: Return False  (bypasses Router)
  │
Xojo serves bootstrap HTML → Xojo.js → WebSocket opens
  │
Session established → DefaultWindow = Default (empty WebPage)
  │
Default.Shown fires → New XojoUnitTestPage → testPage.Show()
  │
XojoUnitTestPage.Opening + Shown → test groups loaded ✓
  │
Browser: XojoUnit test runner UI (via WebSocket)
-->
<!-- /diagram -->

The `Default` page is a trivially empty `WebPage`. Its `Shown` event fires after the session is fully established — the safe earliest point to show `XojoUnitTestPage`:

```xojo
// Default.xojo_code — Shown event
Sub Shown()
  Var testPage As New XojoUnitTestPage
  testPage.Show()
End Sub
```

`XojoUnitTestPage` has `ImplicitInstance=False`, so `New XojoUnitTestPage` is required — `XojoUnitTestPage.Show()` directly would be a compile error.

### Why `/?_xojo=1` and not just `/`?

`/` is a registered MVVM route. The Router would match it and return `True`, serving the MVVM home page — never reaching `Return False`. The `_xojo=1` query parameter is the sentinel that tells `HandleURL` to skip the Router. Normal browsers visiting `/` never send `_xojo=1`, so the home page is unaffected.

---

## Linking Back: Xojo WebPage → MVVM

To navigate from a Xojo WebPage back to an MVVM route, use `Session.GoToURL()`. This sends a browser-level navigation instruction, breaking out of the WebSocket session entirely.

```xojo
// XojoUnitTestPage — WebToolbar Pressed event
Sub Pressed(item As WebToolbarButton)
  Select Case item.Caption
  Case "XjMVVM"
    Session.GoToURL("/")   // browser navigates to MVVM home
  End Select
End Sub
```

!!! warning
    Inside a `WebToolbar.Pressed` event, `Me` refers to the `WebToolbar` itself, not the page. `Me.Session` does not exist on `WebToolbar`. Use the thread-local global `Session` directly.

### Navigation API

| From | To | Method | Notes |
|------|----|--------|-------|
| MVVM template | MVVM route | `<a href="/notes">` | Standard HTML anchor |
| MVVM template | Xojo WebPage | `<a href="/tests">` | Triggers redirect dance |
| Xojo WebPage | MVVM route | `Session.GoToURL("/")` | Browser-level navigation, drops WebSocket |
| Xojo WebPage | Xojo WebPage | `page.Show()` | WebSocket-internal, no URL change |

---

## Router Returns Boolean

`Router.Route()` is a `Function As Boolean`, not a `Sub`. When no MVVM route matches (e.g., `/framework/Xojo.js`, `/websocket`), it returns `False`. `HandleURL` propagates that `False` to Xojo's own handler, which serves the file.

```xojo
// HandleURL — simplified
Return mRouter.Route(request, response, session, mJinja)
// If no route matched → Router returns False → HandleURL returns False
// → Xojo serves Xojo.js, WebSocket frames, etc.
```

If `Route()` always returned `True`, Xojo's own JS and CSS files would be blocked, the WebSocket session would never establish, and the `/tests` flow would break entirely.

---

## Files Reference

| File | Role |
|------|------|
| `App.xojo_code` | `HandleURL` — path normalization, `/tests` redirect, `/?_xojo=1` passthrough, Router dispatch |
| `Framework/Router.xojo_code` | Route registration (`Get`, `Post`, `Any`), path matching (`ParsePath`), dispatch, error pages |
| `Default.xojo_code` | Trampoline `WebPage` — `Shown` event instantiates `XojoUnitTestPage` after session is ready |
| `mvvm.xojo_project` | `DefaultWindow=Default` — must be `Default`, not `XojoUnitTestPage` |
| `XojoUnit/XojoUnitTestPage.xojo_code` | Test runner; XjMVVM toolbar button calls `Session.GoToURL("/")` |
