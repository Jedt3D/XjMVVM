---
title: "認証システム"
description: XjMVVMがユーザー登録、ログイン、ログアウト、パスワードハッシング、SSRモード用のクッキーベース認証をどのように処理するか。
---

# 認証システム

XjMVVM の認証は 3 つのレイヤーで構築されています: **`UserModel`** が認証情報を保存・検証し、**`BaseViewModel`** がクッキーベースの認証ヘルパーを提供してルートを保護し、テンプレートに現在のユーザーを公開し、**ブラウザ側の JavaScript** が SSR セッションギャップを nav 状態とフラッシュメッセージのために橋渡しします。

!!! warning
    **`Self.Session` は SSR モードでは常に Nil です。** Xojo Web 2 の `WebSession` は永続的な WebSocket 接続を必要とします。純粋な SSR（`HandleURL` が常に `True` を返す）では、WebSocket もセッションも存在しません。認証にはすべて HMAC 署名付きクッキーを使用します。

## 概要

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

**ファイル:** `Models/UserModel.xojo_code`

`UserModel`は`BaseModel`を継承します。そのテーブルは`users(id, username, password_hash, created_at)`です。`password_hash`カラムは`hash:salt`形式の単一文字列を保存します。

### クライアント側のSHA-256ハッシング

ログインまたはサインアップフォームが送信される前に、ブラウザは[Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest)を使用してパスワードをハッシュするため、平文パスワードはネットワークを横切りません：

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0')).join('');
}
</script>
```

Alpine.jsはフォーム送信をインターセプトし、パスワードをハッシュしてから送信します：

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

`hashed` フラグは、`e.target.submit()` が何らかの理由でイベントを再発火した場合の二重処理を防ぎます。

!!! note
    `crypto.subtle`はすべてのモダンブラウザで利用可能で、ライブラリは不要です。セキュアなコンテキスト（HTTPSまたはlocalhost）でのみ利用可能です。

### サーバー側のパスワード保存

サーバーはクライアント側のSHA-256ハッシュ（`SHA256(plaintext)`）をパスワードフィールドとして受け取ります。その後、ランダムなユーザーごとのソルトで2番目のハッシュを適用してから保存します：

```xojo
Private Function HashPassword(password As String, salt As String) As String
  // password is already SHA256(plaintext) from the browser
  Return EncodeHex(Crypto.SHA256(password + salt))
End Function
```

保存値: `SHA256(SHA256(plaintext) + salt) : salt`

このダブルハッシュモデルにより、攻撃者がサーバーソースを入手しても、データベースにはユーザーの元のパスワードが保存されていません。`EncodeHex(Crypto.SHA256(...))` は 64 文字の 16 進数文字列を返します — `.Hex` プロパティを持つ文字列ではありません。`EncodeHex()` グローバル関数が必要です。

!!! warning
    SHA-256 + ユーザーごとのランダムソルトの使用は、ほとんどの内部またはローリスクアプリケーションに対して十分です。高セキュリティまたは一般公開されるアプリケーションの場合は、プラットフォームで利用可能であれば bcrypt または Argon2 バインディングを使用してください。

### ユーザーの作成

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

成功時は新しい `id` を返し、ユーザー名がすでに使用されている場合は `0` を返します。

### パスワードの検証

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
    `stored.Middle(colonPos + 1)` は 0-based です（`String.Middle` は `IndexOf` と整合します）。ここで `Mid()` を決して使用しないでください — 1-based のレガシー関数は 1 つずれ、ソルト抽出を破損します。

---

## クッキーベース認証

SSRモードでは`Self.Session`は常にNilであるため、XjMVVMはHMAC署名付きHTTPクッキーを認証に使用します。クッキーは`Set-Cookie` HTTPヘッダーを介して設定され、すべてのリクエストで検証されます。

### クッキー形式

```
mvvm_auth=<userID>:<username>:<HMAC>
```

HMACは次のように計算されます：

```
SHA256(userID + ":" + username + ":" + App.mAuthSecret)
```

`App.mAuthSecret` は起動時に `Crypto.GenerateRandomBytes(32)` で 1 回生成されるランダムな 32 バイトの 16 進数文字列です。再起動のたびに変わり、既存のすべての認証クッキーを実質的に無効化します。

### AuthCookieValue — クッキーの生成

```xojo
Function AuthCookieValue(userID As Integer, username As String) As String
  Var payload As String = Str(userID) + ":" + username
  Var hmac As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
  Return payload + ":" + hmac
End Function
```

### ParseAuthCookie — クッキーの検証

すべてのリクエストで呼び出され、認証済みユーザーを抽出・検証します。結果は `mAuthParsed` / `mAuthCache` プロパティ経由でリクエスト単位でキャッシュされるため、複数回の呼び出し（`RequireLogin`、`CurrentUserID`、`Render` から）で再解析は不要です。

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
    HMAC検証により、クッキーは偽造されません。攻撃者は任意のユーザーの有効なクッキーを生成するために`App.mAuthSecret`が必要です。

### RedirectWithAuth — ログイン/サインアップ時のクッキー設定

認証に成功した後、`RedirectWithAuth` は 1 つのレスポンスで 3 つのことを行います:

1. HTTP `Set-Cookie` ヘッダー経由で `mvvm_auth` クッキーを設定
2. ユーザー名を `localStorage` に、フラッシュメッセージを `sessionStorage` に保存する JS 中間ページを送信
3. ブラウザをターゲット URL にリダイレクト

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

JS 中間ページが必要な理由:

- `Set-Cookie` は HTTP クッキーを設定します（以降のリクエストでサーバー側認証に使用）
- `localStorage` はユーザー名を保存します（Alpine.js 経由のクライアント側 nav 状態表示用）
- `sessionStorage` はフラッシュメッセージを保存します（リダイレクト後のワンタイム表示用）

この 3 つのストレージメカニズムはそれぞれ異なる目的を果たしており、互いに置き換えることはできません。

### RedirectWithLogout — クッキーのクリア

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

`Max-Age=0`はブラウザにクッキーをすぐに削除するよう指示します。

---

## BaseViewModel認証ヘルパー

`BaseViewModel`の4つのメソッドは、クッキーを直接処理することなく、任意のViewModelから認証にアクセスできます：

### `CurrentUserID() As Integer`

```xojo
Function CurrentUserID() As Integer
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return Val(auth.Value("user_id").StringValue)
  Return 0
End Function
```

未認証時は `0` を返します — ゼロは SQLite `AUTOINCREMENT` 主キーでは有効な ID ではありません。

### `CurrentUsername() As String`

```xojo
Function CurrentUsername() As String
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return auth.Value("username").StringValue
  Return ""
End Function
```

### `RequireLogin() As Boolean`

HTML ルートを保護します。未認証ユーザーをログインページにリダイレクトし、`next` パラメータを使ってログイン後に元の URL へ戻せます。

```xojo
Function RequireLogin() As Boolean
  If CurrentUserID() > 0 Then Return False
  Redirect("/login?next=" + EncodeURLComponent(Request.Path))
  Return True
End Function
```

保護されたViewModelの使用パターン：

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard -- stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()` はリダイレクトを発行しますが、**実行を自動停止しません** — リダイレクト済みであることを示すために `True` を返します。常に `If RequireLogin() Then Return` とペアで使用してください。`Return` を忘れると、リダイレクト送信後もハンドラーが実行を続けてしまいます。

### `RequireLoginJSON() As Boolean`

API ルートを保護します。HTML リダイレクトの代わりに 401 JSON エラーを返します（API クライアントは HTML リダイレクトに従うことができません）。

```xojo
Function RequireLoginJSON() As Boolean
  If CurrentUserID() > 0 Then Return False
  Response.Status = 401
  WriteJSON("{""error"":""Authentication required""}")
  Return True
End Function
```

使用法：

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... rest of API handler
End Sub
```

### 自動注入コンテキスト — `current_user`

`BaseViewModel.Render()` は常にすべてのテンプレートコンテキストに `current_user` Dictionary を注入し、安全なデフォルト値を使用するため、テンプレートは `UndefinedVariableException` をスローしません:

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
    `logged_in` は文字列 `"1"` または `"0"` です — ブール値ではありません。JinjaX テンプレートの `Dictionary` 値はすべて文字列であるためです。`== True` ではなく `== "1"` で比較してください。

---

## SSRセッション制限とクライアント側の回避方法

Xojo Web 2 では、`WebSession` 状態は永続的な WebSocket 接続に結びついています。純粋な SSR モード（`HandleURL` が常に `True` を返し、WebSocket が確立されない）では、各 HTTP リクエストにセッションがありません。これは以下を意味します:

- `POST` 中に保存されたフラッシュメッセージは、リダイレクト後の `GET` が到着する前に**失われます**。
- ログイン済みのユーザー名はセッション状態から**テンプレートレンダラーに渡せません**。
- **`SetFlash()` と `Session.LogIn()` はサイレントに何もしません** — Nil セッションに書き込もうとするためです。

XjMVVM はこれらの制限を 3 つのメカニズムで回避します:

| メカニズム | ストレージ | 目的 | 生涯 |
|-----------|---------|------|------|
| `mvvm_auth` cookie | HTTPクッキー | サーバー側認証 | ブラウザがクリアするか`Max-Age=0`まで |
| `localStorage._auth_user` | ブラウザlocalStorage | クライアント側nav表示 | タブ/再起動を超えて永続的 |
| `sessionStorage._flash_msg` | ブラウザsessionStorage | ワンショットフラッシュメッセージ | 現在のタブのみ、リダイレクトを超えて |

### フラッシュメッセージ — `sessionStorage`

`RedirectWithAuth` によって送信される JS 中間ページは成功メッセージを `sessionStorage` に書き込みます。Alpine.js はそれを次のページロード時に読み取って表示します:

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

### インラインエラー表示

ログインとサインアップのエラーはフラッシュメッセージを使用できません（リダイレクトにより失われてしまうため）。代わりに、ViewModel は `error_message` テンプレート変数を使ってフォームを再レンダリングします:

```xojo
// In LoginVM.OnPost() — on failed login:
Var ctx As New Dictionary
ctx.Value("error_message") = "Invalid username or password."
ctx.Value("next_url") = nextURL
Render("auth/login.html", ctx)
```

テンプレートはそれをインラインで表示します：

```html
{% if error_message %}
<div class="flash flash-error">{{ error_message }}</div>
{% endif %}
```

### nav認証状態 — `localStorage`

Alpine.jsは`localStorage._auth_user`を読んで正しいnav状態を表示します：

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

## 認証ViewModel

### LoginVM

`GET /login` — ログインフォームを `error_message = ""` でレンダリングし、ログイン後のリダイレクト用に `next` クエリパラメータを読み取ります。

`POST /login` — ユーザー名とパスワードが空でないことを検証し、`UserModel.VerifyPassword()` を呼び出します。成功時は `RedirectWithAuth(nextURL, userID, username)` を呼び出します。失敗時はインラインエラーメッセージでログインフォームを再レンダリングします（フラッシュではなく — `SetFlash` は SSR では機能しません）。

### SignupVM

`GET /signup` — `error_message = ""` でサインアップフォームをレンダリングします。

`POST /signup` — 検証: ユーザー名必須（3 文字以上）、パスワード（6 文字以上）、パスワード一致。`UserModel.Create()` を呼び出します。`0` が返る場合（ユーザー名がすでに使用済み）はエラーで再レンダリングします。成功時は `RedirectWithAuth("/notes", newID, username)` を呼び出します。

### LogoutVM

`POST /logout` のみ — GET はサポートされていません。`RedirectWithLogout("/login")` を呼び出します。ログアウトに POST を使用することで、プリフェッチやリンクプリロード経由の意図しないログアウトを防止します。

---

## 認証ルート

```xojo
mRouter.Get("/login",   AddressOf CreateLoginVM)
mRouter.Post("/login",  AddressOf CreateLoginVM)
mRouter.Post("/logout", AddressOf CreateLogoutVM)
mRouter.Get("/signup",  AddressOf CreateSignupVM)
mRouter.Post("/signup", AddressOf CreateSignupVM)
```

ログインとサインアップの `GET` と `POST` は同じ ViewModel ファクトリーを共有します — ViewModel 自体が `Request.Method` に基づいて `OnGet()` または `OnPost()` にディスパッチします。

---

## スキーマ

`users`テーブルは`DBAdapter.InitDB()`で作成されます：

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS users (" + _
  "id            INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "username      TEXT NOT NULL UNIQUE, " + _
  "password_hash TEXT NOT NULL, " + _
  "created_at    TEXT DEFAULT (datetime('now')))")
```

`username` の `UNIQUE` 制約はデータベースレベルのセーフティネットです。`UserModel.Create()` のアプリケーションレベルチェックは、ViewModel がエラーメッセージを表示するためのより明確なシグナル（`0` 返却）を提供します。