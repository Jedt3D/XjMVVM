---
title: "Auth System"
description: How XjMVVM handles user registration, login, logout, password hashing, and cookie-based authentication for SSR mode.
---

# Auth System

Authentication in XjMVVM is built across three layers: the **`UserModel`** stores and verifies credentials, **`BaseViewModel`** provides cookie-based auth helpers that protect routes and expose the current user to templates, and **browser-side JavaScript** bridges the SSR session gap for nav state and flash messages.

!!! warning
    **`Self.Session` is always Nil in SSR mode.** Xojo Web 2's `WebSession` requires a persistent WebSocket connection. In pure SSR — where `HandleURL` always returns `True` — there is no WebSocket and no session. All auth uses HMAC-signed cookies instead.

## Overview

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 10
#lineWidth: 1.5
[POST /login or /signup] -> [LoginVM / SignupVM]
[LoginVM / SignupVM] verify -> [UserModel|FindByUsername()\nVerifyPassword()\nCreate()]
[UserModel] result -> [LoginVM / SignupVM]
[LoginVM / SignupVM] RedirectWithAuth() -> [Set-Cookie: mvvm_auth=...|JS intermediate page:\nlocalStorage + sessionStorage]
[Set-Cookie: mvvm_auth=...|JS intermediate page:\nlocalStorage + sessionStorage] -> [Redirect to /notes]
[GET any protected route] -> [BaseViewModel.RequireLogin()]
[BaseViewModel.RequireLogin()] ParseAuthCookie() -> [Cookie valid?]
[Cookie valid?] no -> [Redirect /login?next=url]
[Cookie valid?] yes -> [OnGet() / OnPost()]
-->
<!-- ascii
POST /login or /signup
  +-- LoginVM / SignupVM
        +-- UserModel.VerifyPassword() or .Create()
        +-- RedirectWithAuth()
              +-- Set-Cookie: mvvm_auth=userID:username:HMAC
              +-- JS intermediate page sets localStorage + sessionStorage
              +-- Redirect to /notes

GET protected route
  +-- BaseViewModel.RequireLogin()
        +-- ParseAuthCookie() reads + verifies cookie
              +-- invalid -> Redirect /login?next=url
              +-- valid   -> OnGet() / OnPost()
-->
<!-- /diagram -->

---

## UserModel

**File:** `Models/UserModel.xojo_code`

`UserModel` inherits `BaseModel`. Its table is `users(id, username, password_hash, created_at)`. The `password_hash` column stores a single string in the format `hash:salt`.

### Client-side SHA-256 hashing

Before the login or signup form is submitted, the browser hashes the password using the [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest) so the plaintext password never crosses the network:

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0')).join('');
}
</script>
```

Alpine.js intercepts the form submit, hashes the password, then submits:

```html
<form method="post" action="/login"
      x-data="{
        hashed: false,
        async handleSubmit(e) {
          if (this.hashed) return;
          const pwEl = document.getElementById('password');
          pwEl.value = await sha256hex(pwEl.value);
          this.hashed = true;
          e.target.submit();
        }
      }"
      @submit.prevent="handleSubmit($event)">
```

The `hashed` flag prevents re-processing if `e.target.submit()` somehow re-fires the event.

!!! note
    `crypto.subtle` is available in all modern browsers and does not require any library. It is only available on secure contexts (HTTPS or localhost).

### Server-side password storage

The server receives the client-side SHA-256 hash (`SHA256(plaintext)`) as the password field. It then applies a second hash with a random per-user salt before storing:

```xojo
Private Function HashPassword(password As String, salt As String) As String
  // password is already SHA256(plaintext) from the browser
  Return EncodeHex(Crypto.SHA256(password + salt))
End Function
```

Stored value: `SHA256(SHA256(plaintext) + salt) : salt`

This double-hash model means the database never sees the user's original password even if an attacker has the server source. `EncodeHex(Crypto.SHA256(...))` returns a 64-character hex string — not a string with a `.Hex` property. The `EncodeHex()` global function is required.

!!! warning
    Using SHA-256 + per-user random salt is adequate for most internal or low-risk applications. For high-security or public-facing apps, a bcrypt or Argon2 binding should be used if available for your platform.

### Creating a user

```xojo
Function Create(username As String, password As String) As Integer
  // Reject duplicate usernames before hashing
  If FindByUsername(username) <> Nil Then Return 0

  Var salt As String = GenerateSalt()
  Var hash As String = HashPassword(password, salt)
  Var stored As String = hash + ":" + salt

  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO users (username, password_hash) VALUES (?, ?)", username, stored)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function
```

Returns the new `id` on success, or `0` if the username was already taken.

### Verifying a password

```xojo
Function VerifyPassword(username As String, password As String) As Boolean
  Var row As Dictionary = FindByUsername(username)
  If row = Nil Then Return False

  Var stored As String = row.Value("password_hash").StringValue
  Var colonPos As Integer = stored.IndexOf(":")
  If colonPos < 0 Then Return False

  Var hash As String = stored.Left(colonPos)
  Var salt As String = stored.Middle(colonPos + 1)
  Return HashPassword(password, salt) = hash
End Function
```

!!! warning
    `stored.Middle(colonPos + 1)` is 0-based (`String.Middle` aligns with `IndexOf`). Never use `Mid()` here — the 1-based legacy function would produce an off-by-one and corrupt the salt extraction.

---

## Cookie-Based Authentication

Since `Self.Session` is always Nil in SSR mode, XjMVVM uses HMAC-signed HTTP cookies for authentication. The cookie is set via the `Set-Cookie` HTTP header and verified on every request.

### Cookie format

```
mvvm_auth=<userID>:<username>:<HMAC>
```

The HMAC is computed as:

```
SHA256(userID + ":" + username + ":" + App.mAuthSecret)
```

`App.mAuthSecret` is a random 32-byte hex string generated once at startup via `Crypto.GenerateRandomBytes(32)`. It changes on every restart, effectively invalidating all existing auth cookies.

### AuthCookieValue — generating the cookie

```xojo
Function AuthCookieValue(userID As Integer, username As String) As String
  Var payload As String = Str(userID) + ":" + username
  Var hmac As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
  Return payload + ":" + hmac
End Function
```

### ParseAuthCookie — verifying the cookie

Called on every request to extract and verify the authenticated user. Results are cached per request via `mAuthParsed` / `mAuthCache` properties so multiple calls (from `RequireLogin`, `CurrentUserID`, `Render`) do not re-parse.

```xojo
Private Function ParseAuthCookie() As Dictionary
  If mAuthParsed Then Return mAuthCache

  mAuthParsed = True
  mAuthCache = Nil

  // Read the Cookie header
  Var cookieHeader As String = Request.Header("Cookie")
  If cookieHeader.Length = 0 Then Return Nil

  // Find mvvm_auth=... value
  Var value As String = ""  // ... extract from cookie header ...

  // Parse userID:username:hmac
  Var firstColon As Integer = value.IndexOf(":")
  Var lastColon As Integer = value.Length - 65  // HMAC is always 64 hex chars
  If firstColon < 0 Or lastColon < 0 Then Return Nil

  Var userID As String = value.Left(firstColon)
  Var username As String = value.Middle(firstColon + 1, lastColon - firstColon - 2)
  Var receivedHMAC As String = value.Middle(lastColon)

  // Verify HMAC
  Var payload As String = userID + ":" + username
  Var expectedHMAC As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
  If receivedHMAC <> expectedHMAC Then Return Nil

  // Valid — cache and return
  Var result As New Dictionary
  result.Value("user_id") = userID
  result.Value("username") = username
  mAuthCache = result
  Return result
End Function
```

!!! note
    The HMAC verification ensures cookies cannot be forged. An attacker would need `App.mAuthSecret` to generate a valid cookie for any user.

### RedirectWithAuth — setting the cookie on login/signup

After successful authentication, `RedirectWithAuth` does three things in one response:

1. Sets the `mvvm_auth` cookie via HTTP `Set-Cookie` header
2. Sends a JS intermediate page that stores username in `localStorage` and flash message in `sessionStorage`
3. Redirects the browser to the target URL

```xojo
Sub RedirectWithAuth(targetURL As String, userID As Integer, username As String)
  Var cookieVal As String = AuthCookieValue(userID, username)
  Response.Header("Set-Cookie") = "mvvm_auth=" + cookieVal + "; Path=/; SameSite=Lax"
  Response.Header("Content-Type") = "text/html; charset=utf-8"
  Response.Write("<html><body><script>" + _
    "localStorage.setItem('_auth_user','" + username + "');" + _
    "sessionStorage.setItem('_flash_msg','Welcome, " + username + "!');" + _
    "sessionStorage.setItem('_flash_type','success');" + _
    "window.location.href='" + targetURL + "';" + _
    "</script></body></html>")
End Sub
```

The JS intermediate page is necessary because:

- `Set-Cookie` sets the HTTP cookie (for server-side auth on subsequent requests)
- `localStorage` stores the username (for client-side nav state display via Alpine.js)
- `sessionStorage` stores the flash message (for one-time display after redirect)

These three storage mechanisms serve different purposes and cannot replace each other.

### RedirectWithLogout — clearing the cookie

```xojo
Sub RedirectWithLogout(targetURL As String)
  Response.Header("Set-Cookie") = "mvvm_auth=; Path=/; Max-Age=0; SameSite=Lax"
  Response.Header("Content-Type") = "text/html; charset=utf-8"
  Response.Write("<html><body><script>" + _
    "localStorage.removeItem('_auth_user');" + _
    "window.location.href='" + targetURL + "';" + _
    "</script></body></html>")
End Sub
```

`Max-Age=0` tells the browser to delete the cookie immediately.

---

## BaseViewModel Auth Helpers

Four methods on `BaseViewModel` make auth accessible from any ViewModel without directly handling cookies:

### `CurrentUserID() As Integer`

```xojo
Function CurrentUserID() As Integer
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return Val(auth.Value("user_id").StringValue)
  Return 0
End Function
```

Returns `0` when not authenticated — zero is never a valid SQLite `AUTOINCREMENT` primary key.

### `CurrentUsername() As String`

```xojo
Function CurrentUsername() As String
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return auth.Value("username").StringValue
  Return ""
End Function
```

### `RequireLogin() As Boolean`

Guards HTML routes. Redirects unauthenticated users to the login page with a `next` parameter so they return to the original URL after login.

```xojo
Function RequireLogin() As Boolean
  If CurrentUserID() > 0 Then Return False
  Redirect("/login?next=" + EncodeURLComponent(Request.Path))
  Return True
End Function
```

Usage pattern in any protected ViewModel:

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard -- stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()` issues the redirect but **cannot stop execution** — it returns `True` to signal the caller. Always pair it with `If RequireLogin() Then Return`. Forgetting the `Return` will cause the handler to continue executing after the redirect is already sent.

### `RequireLoginJSON() As Boolean`

Guards API routes. Returns a 401 JSON error instead of redirecting (API clients cannot follow HTML redirects).

```xojo
Function RequireLoginJSON() As Boolean
  If CurrentUserID() > 0 Then Return False
  Response.Status = 401
  WriteJSON("{""error"":""Authentication required""}")
  Return True
End Function
```

Usage:

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... rest of API handler
End Sub
```

### Auto-injected context — `current_user`

`BaseViewModel.Render()` always injects a `current_user` dictionary into every template context with safe defaults, so templates never throw `UndefinedVariableException`:

```xojo
Var userCtx As New Dictionary()
userCtx.Value("id") = "0"
userCtx.Value("username") = ""
userCtx.Value("logged_in") = "0"

Var auth As Dictionary = ParseAuthCookie()
If auth <> Nil Then
  userCtx.Value("id") = auth.Value("user_id").StringValue
  userCtx.Value("username") = auth.Value("username").StringValue
  userCtx.Value("logged_in") = "1"
End If
context.Value("current_user") = userCtx
```

!!! note
    `logged_in` is the string `"1"` or `"0"` — not a boolean — because `Dictionary` values in JinjaX templates are all strings. Compare with `== "1"`, not `== True`.

---

## SSR Session Limitations & Client-Side Workarounds

In Xojo Web 2, `WebSession` state is tied to a persistent WebSocket connection. In pure SSR mode — where `HandleURL` always returns `True` and no WebSocket is established — each HTTP request gets no session. This means:

- Flash messages stored during a `POST` are **lost** by the time the redirect `GET` arrives.
- The logged-in username is **not available** to the template renderer from session state.
- **`SetFlash()` and `Session.LogIn()` silently do nothing** — they write to a Nil session.

XjMVVM works around these limitations with three mechanisms:

| Mechanism | Storage | Purpose | Lifetime |
|-----------|---------|---------|----------|
| `mvvm_auth` cookie | HTTP cookie | Server-side authentication | Until browser clears or `Max-Age=0` |
| `localStorage._auth_user` | Browser localStorage | Client-side nav display | Persistent across tabs/restarts |
| `sessionStorage._flash_msg` | Browser sessionStorage | One-shot flash messages | Current tab only, survives redirect |

### Flash messages — `sessionStorage`

The JS intermediate page (sent by `RedirectWithAuth`) writes the success message to `sessionStorage`. Alpine.js reads and displays it on the next page load:

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

### Inline error rendering

Login and signup errors cannot use flash messages (the redirect would lose them). Instead, the ViewModel re-renders the form with an `error_message` template variable:

```xojo
// In LoginVM.OnPost() — on failed login:
Var ctx As New Dictionary
ctx.Value("error_message") = "Invalid username or password."
ctx.Value("next_url") = nextURL
Render("auth/login.html", ctx)
```

The template displays it inline:

```html
{% if error_message %}
<div class="flash flash-error">{{ error_message }}</div>
{% endif %}
```

### Nav auth state — `localStorage`

Alpine.js reads `localStorage._auth_user` to show the correct nav state:

```html
<nav x-data="{ user: localStorage.getItem('_auth_user') }">
  <span x-show="!user">
    <a href="/login">Log In</a>
    <a href="/signup">Sign Up</a>
  </span>
  <span x-show="user" x-cloak>
    <span x-text="user"></span>
    <form method="post" action="/logout"
          @submit="localStorage.removeItem('_auth_user')">
      <button type="submit">Log Out</button>
    </form>
  </span>
</nav>
```

---

## Auth ViewModels

### LoginVM

`GET /login` — renders the login form with `error_message = ""` and reads `next` query param for post-login redirect.

`POST /login` — validates username + password are non-empty, calls `UserModel.VerifyPassword()`. On success, calls `RedirectWithAuth(nextURL, userID, username)`. On failure, re-renders the login form with an inline error message (not a flash — `SetFlash` is broken in SSR).

### SignupVM

`GET /signup` — renders the signup form with `error_message = ""`.

`POST /signup` — validates: username required (3+ characters), password (6+ characters), passwords match. Calls `UserModel.Create()`. If it returns `0` (username taken), re-renders with error. On success, calls `RedirectWithAuth("/notes", newID, username)`.

### LogoutVM

`POST /logout` only — GET is not supported. Calls `RedirectWithLogout("/login")`. Using POST for logout prevents accidental logout via prefetch or link pre-loading.

---

## Auth Routes

```xojo
mRouter.Get("/login",   AddressOf CreateLoginVM)
mRouter.Post("/login",  AddressOf CreateLoginVM)
mRouter.Post("/logout", AddressOf CreateLogoutVM)
mRouter.Get("/signup",  AddressOf CreateSignupVM)
mRouter.Post("/signup", AddressOf CreateSignupVM)
```

Both `GET` and `POST` for login and signup share the same ViewModel factory — the ViewModel itself dispatches to `OnGet()` or `OnPost()` based on `Request.Method`.

---

## Schema

The `users` table is created in `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS users (" + _
  "id            INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "username      TEXT NOT NULL UNIQUE, " + _
  "password_hash TEXT NOT NULL, " + _
  "created_at    TEXT DEFAULT (datetime('now')))")
```

The `UNIQUE` constraint on `username` is a database-level safety net. The application-level check in `UserModel.Create()` provides the cleaner signal (`0` return) used by ViewModels to display the error message.
