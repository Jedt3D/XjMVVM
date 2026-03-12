---
title: 認証システム
description: XjMVVMがユーザー登録、ログイン、ログアウト、パスワードハッシング、リクエストごとの認証ガードをどのように処理するか。
---

# 認証システム

XjMVVMの認証は3つのレイヤーに構築されています：**`UserModel`**は認証情報を格納して検証し、**`Session`**クラスはログインしているユーザーを追跡し、**`BaseViewModel`**はルートを保護し、現在のユーザーをテンプレートに公開するヘルパーを提供します。

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
[LoginVM / SignupVM] LogIn(id, username) -> [Session|CurrentUserID\nCurrentUsername\nIsLoggedIn()]
[Session] -> [Redirect to /]
[GET any protected route] -> [BaseViewModel.RequireLogin()]
[BaseViewModel.RequireLogin()] not logged in -> [Redirect /login]
[BaseViewModel.RequireLogin()] logged in -> [OnGet() / OnPost()]
-->
<!-- ascii
POST /login or /signup
  └── LoginVM / SignupVM
        ├── UserModel.VerifyPassword() or .Create()
        └── Session.LogIn(id, username) → Redirect /

GET protected route
  └── BaseViewModel.RequireLogin()
        ├── not logged in → Redirect /login
        └── logged in → OnGet() / OnPost()
-->
<!-- /diagram -->

---

## UserModel

**File:** `Models/UserModel.xojo_code`

`UserModel`は`BaseModel`を継承します。そのテーブルは`users(id, username, password_hash, created_at)`です。`password_hash`列は`hash:salt`形式の単一文字列を格納します。

### パスワードハッシング

Xojoはその標準ライブラリにbcryptバインディングを持ちません。フレームワークは**SHA-256とランダムソルト**を使用します — ソルトが無作為で、ユーザーあたり格納されている場合、よく理解される安全な代替案。

```xojo
Private Function GenerateSalt() As String
  // Time + random number — unique per call
  Var raw As String = Str(System.Ticks) + Str(Rnd)
  Return EncodeHex(Crypto.SHA256(raw))
End Function

Private Function HashPassword(password As String, salt As String) As String
  Return EncodeHex(Crypto.SHA256(password + salt))
End Function
```

ハッシュとソルトは`:`セパレータで1つの列に結合されます：

```xojo
Var stored As String = hash + ":" + salt  // e.g. "a3f9...b2:e7c1...44"
```

これはスキーマをシンプルに保ちます — 別の`salt`列はありません — そして`VerifyPassword`を自己完結させます。

!!! note
    SHA-256 + ユーザーごとのランダムソルトを使用することは、ほとんどの内部またはリスクの低いアプリケーションに適切です。高セキュリティまたは公開向けアプリの場合、プラットフォームで利用可能な場合はbcryptまたはArgon2バインディングを使用する必要があります。

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

成功時に新しい`id`を返すか、ユーザー名が既に取られている場合は`0`を返します。一意性チェックはデータベース`UNIQUE`制約のみに依存するのではなく、アプリケーションレイヤー（`FindByUsername`）で実行されます — これはデータベース例外をキャッチすることなく、クリーンな信号（`0`戻り値）を与えます。

### パスワード検証

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
    `stored.Middle(colonPos + 1)`は0ベースです（`String.Middle`は`IndexOf`と同じです）。ここで`Mid()`を使用しないでください — 1ベースのレガシー関数はオフバイワンを生成し、ソルト抽出を破損させます。

---

## Session

**File:** `Session.xojo_code` （extends `WebSession`）

`Session`は認証されたユーザーのIDを**セッションプロパティ**として格納します — 一時変数ではなく。WebSessionプロパティは自動的にユーザーごとにスコープされ、WebSocket接続のライフタイム全体にわたって永続化されます。

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

  // ...flash message methods unchanged from v0.2.0...

  CurrentUserID   As Integer   // 0 = not logged in
  CurrentUsername As String
End Class
```

`CurrentUserID = 0`は「ログインしていない」のセンチネルです — ゼロはSQLite `AUTOINCREMENT`主キー値では有効ではありません。

---

## BaseViewModel認証ヘルパー

3つのメソッドが`BaseViewModel`に追加され、任意のViewModelから直接`Session`をキャストすることなく認証にアクセスできます：

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

保護されたViewModelでの使用パターン：

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard — stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()`はリダイレクトを発行しますが、**実行を停止することはできません** — これは呼び出し側に信号を返すため`True`を返します。常に`If RequireLogin() Then Return`と対にしてください。`Return`を忘れると、ハンドラーはリダイレクトが既に送信された後に実行を続け、おそらくダブルライトエラーが発生します。

### `CurrentUserID()`と`CurrentUsername()`

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

これらは呼び出し側が手動で`WebSession`を`Session`にキャストする必要なく、セッション状態への安全なアクセスを提供します。

### 自動注入`current_user`コンテキスト

`BaseViewModel.Render()`はすべてのテンプレートコンテキストに`current_user`ディクショナリを自動的に注入します：

```xojo
Var userCtx As New Dictionary()
userCtx.Value("id")        = Str(sess.CurrentUserID)
userCtx.Value("username")  = sess.CurrentUsername
userCtx.Value("logged_in") = If(sess.IsLoggedIn(), "1", "0")
context.Value("current_user") = userCtx
```

したがって、すべてのテンプレートは、ViewModelが明示的にそれを渡すことなく、ログイン状態を分岐させることができます：

```html
{% if current_user.logged_in == "1" %}
  <span>{{ current_user.username }}</span>
  <form method="post" action="/logout">
    <button type="submit">Log out</button>
  </form>
{% else %}
  <a href="/login">Log in</a>
{% endif %}
```

!!! note
    `logged_in`は文字列`"1"`または`"0"`です — ブール値ではなく — なぜなら、JinjaXテンプレート内の`Dictionary`値はすべて文字列だからです。`== True`ではなく`== "1"`と比較してください。

---

## 認証ViewModel

### LoginVM

`GET /login` — ログインフォームをレンダリングします。既にログインしている場合は、`/`にリダイレクトします。

`POST /login` — ユーザー名+パスワードが空でないことを検証し、`UserModel.VerifyPassword()`を呼び出します。成功時に、`Session.LogIn()`を呼び出し、フラッシュメッセージと共にホームにリダイレクトします。失敗時に、エラーフラッシュで`/login`に戻ります。

### SignupVM

`GET /signup` — サインアップフォームをレンダリングします。既にログインしている場合は、`/`にリダイレクトします。

`POST /signup` — 検証：ユーザー名が必須、3文字以上。パスワード6文字以上。パスワードが一致します。`UserModel.Create()`を呼び出します。`0`を返す場合（ユーザー名が取られている）、エラーと共に戻ります。成功時に、すぐに`Session.LogIn()`を呼び出し、ユーザーはアカウント作成直後にサインインします。

### LogoutVM

`POST /logout`のみ — GETはサポートされません。`Session.LogOut()`を呼び出し、ホームにリダイレクトします。ログアウトにPOSTを使用することは、プリフェッチまたはリンクプリロードを通じた偶発的なログアウトを防ぎます。

---

## 認証ルート

```xojo
mRouter.Get("/login",   AddressOf CreateLoginVM)
mRouter.Post("/login",  AddressOf CreateLoginVM)
mRouter.Post("/logout", AddressOf CreateLogoutVM)
mRouter.Get("/signup",  AddressOf CreateSignupVM)
mRouter.Post("/signup", AddressOf CreateSignupVM)
```

ログインとサインアップの両方にとって`GET`と`POST`は同じViewModelファクトリーを共有します — ViewModelそのものが`Request.Method`に基づいて`OnGet()`または`OnPost()`にディスパッチします。

---

## スキーマ

`users`テーブルは`DBAdapter.InitDB()`に作成されます：

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS users (" + _
  "id            INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "username      TEXT NOT NULL UNIQUE, " + _
  "password_hash TEXT NOT NULL, " + _
  "created_at    TEXT DEFAULT (datetime('now')))")
```

`username`の`UNIQUE`制約はデータベースレベルのセーフティネットです。`UserModel.Create()`のアプリケーションレベルチェックは、ViewModelsが「ユーザー名は既に取られています」フラッシュを表示するために使用するクリーンな信号（`0`戻り値）を提供します。
