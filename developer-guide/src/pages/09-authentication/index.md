---
title: "Auth System"
description: How XjMVVM handles user registration, login, logout, password hashing, and client-side session workarounds for SSR mode.
---

# Auth System

Authentication in XjMVVM is built across three layers: the **`UserModel`** stores and verifies credentials, the **`Session`** class tracks who is logged in, and **`BaseViewModel`** provides helpers that protect routes and expose the current user to templates.

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
[LoginVM / SignupVM] LogIn(id, username) -> [Session|CurrentUserID\nCurrentUsername\nIsLoggedIn()]
[Session] -> [Redirect to /notes]
[GET any protected route] -> [BaseViewModel.RequireLogin()]
[BaseViewModel.RequireLogin()] not logged in -> [Redirect /login]
[BaseViewModel.RequireLogin()] logged in -> [OnGet() / OnPost()]
-->
<!-- ascii
POST /login or /signup
  └── LoginVM / SignupVM
        ├── UserModel.VerifyPassword() or .Create()
        └── Session.LogIn(id, username) → Redirect /notes

GET protected route
  └── BaseViewModel.RequireLogin()
        ├── not logged in → Redirect /login
        └── logged in → OnGet() / OnPost()
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

document.getElementById('login-form').addEventListener('submit', async function(e) {
  if (this.dataset.hashed) return;   // already processed — let it through
  e.preventDefault();
  const pwEl = document.getElementById('password');
  pwEl.value = await sha256hex(pwEl.value);
  this.dataset.hashed = '1';
  this.submit();
});
</script>
```

The `dataset.hashed` flag prevents the `submit` event handler from running again when `form.submit()` is called programmatically (which would re-hash the already-hashed value).

The signup form adds password-match validation before hashing:

```javascript
if (pw.length < 6) { /* show inline error */ return; }
if (pw !== cf)     { /* show inline error */ return; }
const hash = await sha256hex(pw);
pwEl.value = hash;
cfEl.value = hash;   // keep confirm field in sync so server check passes
```

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

Returns the new `id` on success, or `0` if the username was already taken. The uniqueness check is done at the application layer (`FindByUsername`) rather than relying solely on the `UNIQUE` constraint — this gives a clean signal (`0` return) without needing to catch a database exception.

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

## Session

**File:** `Session.xojo_code` (extends `WebSession`)

`Session` stores the authenticated user's identity as **session properties** — not temporary variables. WebSession properties are automatically scoped per user.

```xojo
Protected Class Session
Inherits WebSession

  Sub LogIn(userID As Integer, username As String)
    CurrentUserID = userID
    CurrentUsername = username
  End Sub

  Sub LogOut()
    CurrentUserID = 0
    CurrentUsername = ""
  End Sub

  Function IsLoggedIn() As Boolean
    Return CurrentUserID > 0
  End Function

  CurrentUserID   As Integer   // 0 = not logged in
  CurrentUsername As String
End Class
```

`CurrentUserID = 0` is the sentinel for "not logged in" — zero is never a valid SQLite `AUTOINCREMENT` primary key value.

---

## SSR session limitations & client-side workarounds

In Xojo Web 2, `WebSession` state is tied to a persistent WebSocket connection. In pure SSR mode — where `HandleURL` always returns `True` and no WebSocket is established — each HTTP request may receive a fresh session with no shared state. This means:

- Flash messages stored during a `POST` are **lost** by the time the redirect `GET` arrives.
- The logged-in username is **not available** to the template renderer via `current_user`.

XjMVVM works around both limitations using browser-side storage.

### Flash messages — `sessionStorage`

Before `form.submit()`, the signup and login scripts write the success message to `sessionStorage`:

```javascript
sessionStorage.setItem('_flash_msg',  'Account created! Welcome, ' + username + '!');
sessionStorage.setItem('_flash_type', 'success');
this.submit();
```

`sessionStorage` survives across the redirect within the same tab but is cleared when the tab closes. The base layout (`layouts/base.html`) reads and displays it on every page load:

```javascript
(function () {
  var msg  = sessionStorage.getItem('_flash_msg');
  var type = sessionStorage.getItem('_flash_type') || 'success';
  sessionStorage.removeItem('_flash_msg');
  sessionStorage.removeItem('_flash_type');
  if (msg && !document.querySelector('.flash')) {
    var el = document.getElementById('_client-flash');
    el.className = 'flash flash-' + type;
    el.textContent = msg;
    el.style.display = '';
  }
})();
```

The `!document.querySelector('.flash')` guard prevents a double-flash if the Xojo server-side session happens to work (e.g., in a future WebSocket-enabled mode).

### Nav auth state — `localStorage`

`localStorage` persists across tabs and browser restarts (until the user clears storage). The username is stored on login/signup and cleared on logout:

```javascript
// In signup.html / login.html — before form.submit():
localStorage.setItem('_auth_user', username);

// In base.html logout form submit handler:
localStorage.removeItem('_auth_user');
sessionStorage.setItem('_flash_msg',  'You have been logged out.');
sessionStorage.setItem('_flash_type', 'success');
```

The base layout renders two nav spans — one for the logged-out state, one for logged-in — and JavaScript shows the correct one:

```javascript
var user   = localStorage.getItem('_auth_user');
var navOut = document.getElementById('nav-out');
var navIn  = document.getElementById('nav-in');
if (user) {
  document.getElementById('nav-username').textContent = user;
  navOut.style.display = 'none';
  navIn.style.display  = 'flex';
}
```

---

## BaseViewModel auth helpers

Three methods were added to `BaseViewModel` to make auth accessible from any ViewModel without directly casting `Session`:

### `RequireLogin() As Boolean`

```xojo
Function RequireLogin() As Boolean
  Var ws As WebSession = Self.Session
  If ws IsA Session Then
    Var sess As Session = Session(ws)
    If Not sess.IsLoggedIn() Then
      SetFlash("Please log in to continue", "info")
      Redirect("/login")
      Return True  // ← caller must check this and return
    End If
  End If
  Return False
End Function
```

Usage pattern in any protected ViewModel:

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard — stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()` issues the redirect but **cannot stop execution** — it returns `True` to signal the caller. Always pair it with `If RequireLogin() Then Return`. Forgetting the `Return` will cause the handler to continue executing after the redirect is already sent, likely resulting in a double-write error.

### `CurrentUserID()` and `CurrentUsername()`

```xojo
Function CurrentUserID() As Integer
  Var ws As WebSession = Self.Session
  If ws IsA Session Then Return Session(ws).CurrentUserID
  Return 0
End Function

Function CurrentUsername() As String
  Var ws As WebSession = Self.Session
  If ws IsA Session Then Return Session(ws).CurrentUsername
  Return ""
End Function
```

### Auto-injected context — `flash` and `current_user`

`BaseViewModel.Render()` always injects both keys into every template context with safe defaults, so templates never throw `UndefinedVariableException` even when the session is unavailable:

```xojo
// flash — default to empty string (falsy in JinjaX {% if %})
context.Value("flash") = ""
Var ws As WebSession = Self.Session
If ws IsA Session Then
  Var sess As Session = Session(ws)
  Var flash As Dictionary = sess.GetFlash()
  If flash <> Nil Then context.Value("flash") = flash
End If

// current_user — default to logged-out state
Var userCtx As New Dictionary()
userCtx.Value("id")        = "0"
userCtx.Value("username")  = ""
userCtx.Value("logged_in") = "0"
Var ws2 As WebSession = Self.Session
If ws2 IsA Session Then
  Var sess2 As Session = Session(ws2)
  userCtx.Value("id")        = Str(sess2.CurrentUserID)
  userCtx.Value("username")  = sess2.CurrentUsername
  userCtx.Value("logged_in") = If(sess2.IsLoggedIn(), "1", "0")
End If
context.Value("current_user") = userCtx
```

!!! note
    `logged_in` is the string `"1"` or `"0"` — not a boolean — because `Dictionary` values in JinjaX templates are all strings. Compare with `== "1"`, not `== True`.

---

## Auth ViewModels

### LoginVM

`GET /login` — renders the login form. If already logged in, redirects to `/`.

`POST /login` — validates username + password are non-empty, then calls `UserModel.VerifyPassword()`. On success, calls `Session.LogIn()` and redirects to `/notes`. On failure, redirects back to `/login` with an error flash.

### SignupVM

`GET /signup` — renders the signup form. If already logged in, redirects to `/`.

`POST /signup` — validates: username required, ≥3 characters; password ≥6 characters; passwords match. Calls `UserModel.Create()`. If it returns `0` (username taken), redirects back with error. On success, immediately calls `Session.LogIn()` so the user is signed in right after creating their account, then redirects to `/notes`.

### LogoutVM

`POST /logout` only — GET is not supported. Calls `Session.LogOut()` and redirects to `/notes`. Using POST for logout prevents accidental logout via prefetch or link pre-loading.

---

## Auth routes

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

The `UNIQUE` constraint on `username` is a database-level safety net. The application-level check in `UserModel.Create()` provides the cleaner signal (return `0`) used by ViewModels to display the "username already taken" flash.
