---
title: "Alpine.js"
description: How and why XjMVVM uses Alpine.js for minimal client-side interactivity, and when to reach for it versus plain HTML or htmx.
---

# Alpine.js

XjMVVM is a server-rendered framework — HTML comes from Xojo, not a JS framework. Alpine.js fills the small gap where the server cannot manage state: reactive UI elements that must respond to browser-local state (localStorage, sessionStorage) without a full page reload.

## Philosophy

> **Server renders. Alpine reacts. htmx fetches.**

The goal is the minimum JavaScript possible. The decision tree for any interactive element is:

1. **Can a plain HTML form + PRG pattern handle it?** → use that, no JS
2. **Does it react to browser-local state or needs inline DOM updates?** → Alpine
3. **Does it need to fetch from the server and update part of the page?** → htmx (see [htmx adoption plan](#when-to-reach-for-htmx))

Alpine is never used as a replacement for server-side logic. All business rules, data, and validation that can live on the server do.

---

## Installation

Alpine is loaded from CDN with no build step. One line at the bottom of `layouts/base.html`, before `</body>`:

```html
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>
```

The `defer` attribute is required — Alpine must process the DOM after it has been parsed.

!!! note
    Pin to a specific version (e.g. `@3.14.3`) rather than `@3` so builds are reproducible and an upstream CDN update cannot break the app.

---

## Core directives used in XjMVVM

| Directive | Purpose |
|---|---|
| `x-data="{ ... }"` | Declares a reactive component with its state |
| `x-show="expr"` | Toggles `display:none` based on a boolean expression |
| `x-text="expr"` | Sets element text content to the expression value |
| `:class="expr"` | Binds the `class` attribute dynamically |
| `@submit.prevent="fn"` | Intercepts form submit, prevents default, calls a function |
| `@submit="expr"` | Runs an expression on form submit without preventing default |
| `x-cloak` | Hides an element until Alpine initializes (prevents FOUC) |
| `init()` | Lifecycle hook — runs once when the component initializes |

---

## Pattern 1 — Nav auth state

The nav bar must show either Log In / Sign Up (logged-out) or username + Log Out (logged-in), driven by `localStorage`. The server cannot inject this because Xojo Web 2 SSR mode does not persist `WebSession` state between plain HTTP requests.

```html
<nav x-data="{ user: localStorage.getItem('_auth_user') }">

  <!-- Logged-out state: visible by default, hidden by Alpine if user is set -->
  <span class="nav-auth" x-show="!user">
    <a href="/login" class="btn btn-sm">Log In</a>
    <a href="/signup" class="btn btn-primary btn-sm">Sign Up</a>
  </span>

  <!-- Logged-in state: hidden by x-cloak until Alpine confirms user exists -->
  <span class="nav-auth" x-show="user" x-cloak>
    <span x-text="user" style="font-size:0.9em; color:#555;"></span>
    <form method="post" action="/logout"
          @submit="localStorage.removeItem('_auth_user');
                   sessionStorage.setItem('_flash_msg', 'You have been logged out.');
                   sessionStorage.setItem('_flash_type', 'success');">
      <button type="submit" class="btn btn-sm">Log Out</button>
    </form>
  </span>

</nav>
```

`x-cloak` on the logged-in span prevents a flash of both states before Alpine initializes. The CSS rule that makes this work must be in the stylesheet:

```css
[x-cloak] { display: none !important; }
```

`@submit` on the logout form clears localStorage and queues the flash message before the POST is submitted. No separate event listener or script block needed.

---

## Pattern 2 — Client-side flash messages

Flash messages for the POST→redirect→GET cycle cannot use Xojo's session in SSR mode — the session is gone by the time the redirect's GET arrives. The workaround: write to `sessionStorage` before the form submits, read it on the next page load.

Alpine reads and displays the queued message in `init()`, then `x-show` keeps it hidden if there is nothing to show:

```html
<div x-data="{
  msg: '',
  type: 'success',
  init() {
    var m = sessionStorage.getItem('_flash_msg');
    var t = sessionStorage.getItem('_flash_type') || 'success';
    sessionStorage.removeItem('_flash_msg');
    sessionStorage.removeItem('_flash_type');
    if (m && !document.querySelector('.flash')) { this.msg = m; this.type = t; }
  }
}" x-show="msg" :class="'flash flash-' + type" x-text="msg" style="display:none"></div>
```

The `!document.querySelector('.flash')` guard prevents a double-flash if the Xojo server-side session happens to deliver a flash directly (future-proofs for WebSocket mode).

---

## Pattern 3 — Form submit with async pre-processing

Auth forms must hash the password client-side with the Web Crypto API before the POST is sent. This is inherently async and must intercept the submit event. Alpine's `@submit.prevent` + an async method in `x-data` handles this cleanly, with no separate `addEventListener` script block.

The SHA-256 helper is defined in a small `<script>` above the form (it must be in scope when the Alpine method runs):

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2,'0')).join('');
}
</script>

<form method="post" action="/login"
      x-data="{
        hashed: false,
        async handleSubmit(e) {
          if (this.hashed) return;
          const pwEl = document.getElementById('password');
          pwEl.value = await sha256hex(pwEl.value);
          localStorage.setItem('_auth_user', document.getElementById('username').value);
          sessionStorage.setItem('_flash_msg', 'Welcome back!');
          sessionStorage.setItem('_flash_type', 'success');
          this.hashed = true;
          e.target.submit();
        }
      }"
      @submit.prevent="handleSubmit($event)">
  ...
</form>
```

The `hashed` flag prevents re-processing if `e.target.submit()` somehow re-fires the event. `e.target.submit()` (the DOM method) bypasses the `submit` event entirely, so the flag is mainly a safety guard.

### Adding inline validation

The signup form adds password validation. `pwError` state drives an inline error paragraph with no extra DOM wiring:

```html
<p x-show="pwError" x-text="pwError"
   style="display:none; color:#721c24; background:#f8d7da;
          padding:8px 12px; border-radius:4px; margin:0 0 12px;"></p>
```

Inside `handleSubmit`:

```javascript
if (pw.length < 6) { this.pwError = 'Password must be at least 6 characters.'; return; }
if (pw !== cf)     { this.pwError = 'Passwords do not match.'; return; }
this.pwError = '';
```

No `document.getElementById`, no manual `style.display` toggling. Alpine keeps the element in sync.

---

## Pattern 4 — Multi-value checkboxes (no Alpine needed)

Tag checkboxes on the note form previously required JS to collect checked values into a hidden field. This is unnecessary — native HTML form serialization sends all checked checkboxes with the same `name` as multiple values. Xojo's `FormParser` already handles comma-append for duplicate keys.

The correct pattern requires **no JavaScript at all**:

```html
{% for tag in all_tags %}
<input type="checkbox" name="tag_ids" value="{{ tag.id }}"
       {% if tag.selected == "1" %}checked{% endif %}>
{{ tag.name }}
{% endfor %}
```

The form submits `tag_ids=1&tag_ids=3`, FormParser stores `"1,3"`, and the ViewModel splits on `","` as before. No hidden field, no script block.

!!! tip
    Before reaching for Alpine (or any JS), check whether the browser's native form serialization already does what you need. Multiple checkboxes, radio groups, and `<select multiple>` all work without any JavaScript.

---

## JS footprint comparison

| What | Before Alpine | After Alpine |
|---|---|---|
| base.html IIFE | 30 lines | 0 (replaced by `x-data` attributes) |
| login.html `<script>` | 19 lines | 8 (sha256hex helper only) |
| signup.html `<script>` | 35 lines | 8 (sha256hex helper only) |
| notes/form.html `<script>` | 9 lines | 0 (removed entirely) |
| **Total custom JS** | **93 lines** | **16 lines** |
| Alpine CDN | 0 | 14 KB (minified + gzip: ~5 KB) |

The irreducible 16 lines are the SHA-256 helper function (duplicated across login and signup). This cannot be moved to a shared file without a build step — a deliberate trade-off to keep zero build tooling.

---

## When to reach for htmx

Alpine manages **local browser state**. When an interaction needs to **fetch from the server and update part of the page**, add htmx instead of expanding Alpine.

Trigger features that warrant adding htmx:

- Inline edit (click note → form appears in place, saves without reload)
- Delete without reload (remove row from list)
- Live search / filter (notes or tags update as you type)
- Pagination without reload
- Tag toggle on list view

htmx and Alpine compose cleanly — Alpine owns local state, htmx owns server round-trips. The two libraries do not conflict.

---

## What Alpine will never replace

| JS | Reason |
|---|---|
| `crypto.subtle.digest` (SHA-256) | Browser security API, no Alpine equivalent |
| `localStorage` / `sessionStorage` reads and writes | Still needed; Alpine just organises them in `x-data` |
| Server-side session persistence | Architectural — requires cookie-based auth, unrelated to Alpine |
