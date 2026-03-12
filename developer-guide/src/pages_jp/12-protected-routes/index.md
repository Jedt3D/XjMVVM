---
title: "保護されたルートとユーザースコーピング"
description: 認証の背後にルートを保護し、ユーザーごとにデータをスコープして、各ユーザーが自分のレコードのみを表示できるようにする方法。
---

# 保護されたルートとユーザースコーピング

XjMVVM v0.9.3 では 2 つの関連機能が導入されました: 認証を必要とする**保護されたルート**と、レコードをユーザーごとに分離する**ユーザースコープデータ**です。この 2 つを組み合わせることで、ユーザーはアプリにアクセスするためにログインが必要となり、自分のノートのみを表示できます。

## 保護されたルート

認証が必要な ViewModel はすべて、`OnGet()` または `OnPost()` の先頭でガードメソッドを呼び出します。ガードは 2 つあります — 1 つは HTML ルート用、もう 1 つは API ルート用です。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 10
#lineWidth: 1.5
[Incoming Request] -> [ViewModel.OnGet() / OnPost()]
[ViewModel.OnGet() / OnPost()] -> [HTML route?]
[HTML route?] yes -> [RequireLogin()|ParseAuthCookie()\nRedirect /login?next=url]
[HTML route?] no -> [RequireLoginJSON()|ParseAuthCookie()\n401 JSON error]
[RequireLogin()] authenticated -> [Handler continues]
[RequireLogin()] not authenticated -> [302 Redirect to /login]
[RequireLoginJSON()] authenticated -> [Handler continues]
[RequireLoginJSON()] not authenticated -> [401 JSON response]
-->
<!-- ascii
Incoming Request
  +-- ViewModel.OnGet() / OnPost()
        +-- HTML route? -> RequireLogin()
        |     +-- authenticated -> handler continues
        |     +-- not authenticated -> 302 /login?next=url
        +-- API route? -> RequireLoginJSON()
              +-- authenticated -> handler continues
              +-- not authenticated -> 401 {"error":"Authentication required"}
-->
<!-- /diagram -->

### HTML ルートガード — `RequireLogin()`

```xojo
Sub OnGet()
  If RequireLogin() Then Return
  // ... handler logic (only runs if authenticated)
End Sub
```

`RequireLogin()` は `ParseAuthCookie()` を呼び出して HMAC 署名済みの `mvvm_auth` クッキーを検証します。無効または存在しない場合は `/login?next=<encoded-current-path>` にリダイレクトされ、ログイン後にユーザーは元のページへ戻れます。

### API ルートガード — `RequireLoginJSON()`

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... handler logic
End Sub
```

API クライアント（JavaScript `fetch`、モバイルアプリ、CLI ツール）は HTML リダイレクトに従うことができません。`RequireLoginJSON()` は代わりに 401 ステータスと JSON エラーボディを返します:

```json
{"error":"Authentication required"}
```

### どのルートが保護されているか？

19 個すべての ViewModel ルートは認証が必要です：

| リソース | ルート | ガード |
|----------|--------|-------|
| Notes (7) | `/notes`, `/notes/new`, `/notes/:id`, `/notes/:id/edit`, `POST /notes`, `POST /notes/:id`, `POST /notes/:id/delete` | `RequireLogin()` |
| Tags (7) | `/tags`, `/tags/new`, `/tags/:id`, `/tags/:id/edit`, `POST /tags`, `POST /tags/:id`, `POST /tags/:id/delete` | `RequireLogin()` |
| API (5) | `/api/notes`, `/api/notes/:id`, `POST /api/notes`, `/api/tags`, `/api/tags/:id` | `RequireLoginJSON()` |

Auth ルート（`/login`、`/signup`、`/logout`）は**保護されていません** — ユーザーはログインせずにこれらにアクセスできる必要があります。

### ログイン後の `next` パラメータによるリダイレクト

`RequireLogin()` が `/login` にリダイレクトするとき、現在の URL をクエリパラメータとして追加します:

```
/login?next=%2Fnotes%2F42%2Fedit
```

`LoginVM` はこの `next` パラメータを読み取り、ログイン成功後に `RedirectWithAuth()` に渡して、ユーザーを元の場所に戻します:

```xojo
// In LoginVM.OnPost() — after successful verification:
Var nextURL As String = GetFormValue("next")
If nextURL.Length = 0 Then nextURL = "/notes"
RedirectWithAuth(nextURL, userID, username)
```

---

## ユーザースコープデータ

ノートはユーザーごとにスコープされます — 各ユーザーは独自のノートセットを持ちます。タグは引き続きグローバル（すべてのユーザー間で共有）ですが、アクセスにはログインが必要です。

### データベース スキーマの変更

`notes` テーブルは `user_id` 列を含みます：

```sql
notes (id, title, body, created_at, updated_at, user_id)
```

`DBAdapter.InitDB()` のマイグレーションは既存のテーブルに列を追加します:

```xojo
// Add user_id column if it doesn't exist (migration for existing databases)
Var rs As RowSet = db.SelectSQL( _
  "SELECT COUNT(*) AS cnt FROM pragma_table_info('notes') WHERE name='user_id'")
If rs.Column("cnt").IntegerValue = 0 Then
  db.ExecuteSQL("ALTER TABLE notes ADD COLUMN user_id INTEGER NOT NULL DEFAULT 0")
  db.ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id)")
End If
```

`DEFAULT 0` は、既存のノート（認証機能が追加される前に作成されたもの）が引き続きアクセスできることを保証します。新しいノートには認証済みユーザーの ID が付与されます。

### NoteModel — ユーザースコープメソッド

すべての `NoteModel` メソッドは `userID` パラメータが必要です。すべての SQL クエリは `WHERE user_id = ?` を含みます：

```xojo
Function GetAll(userID As Integer) As Variant()
  Var results() As Variant
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL( _
    "SELECT " + Columns() + " FROM notes WHERE user_id = ? ORDER BY updated_at DESC", userID)
  While Not rs.AfterLastRow
    results.Add(RowToDict(rs))
    rs.MoveToNextRow()
  Wend
  rs.Close()
  db.Close()
  Return results
End Function

Function GetByID(id As Integer, userID As Integer) As Dictionary
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL( _
    "SELECT " + Columns() + " FROM notes WHERE id = ? AND user_id = ?", id, userID)
  // ...
End Function

Function Create(title As String, body As String, userID As Integer) As Integer
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)", title, body, userID)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function

Sub Update(id As Integer, title As String, body As String, userID As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL( _
    "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?", _
    title, body, id, userID)
  db.Close()
End Sub

Sub Delete(id As Integer, userID As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("DELETE FROM notes WHERE id = ? AND user_id = ?", id, userID)
  db.Close()
End Sub
```

ページネーション用の追加ユーザースコープメソッド:

```xojo
Function CountForUser(userID As Integer) As Integer
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL("SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ?", userID)
  Var count As Integer = rs.Column("cnt").IntegerValue
  rs.Close()
  db.Close()
  Return count
End Function

Function FindPaginatedForUser(userID As Integer, limit As Integer, offset As Integer, _
    orderBy As String) As Variant()
  // SELECT ... FROM notes WHERE user_id = ? ORDER BY ... LIMIT ? OFFSET ?
End Function
```

### ViewModel パターン — userID の渡し方

すべての Notes ViewModel は `CurrentUserID()`（auth クッキーから）を読み取り、モデルに渡します:

```xojo
Sub OnGet()
  If RequireLogin() Then Return

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll(userID)

  Var ctx As New Dictionary
  ctx.Value("notes") = notes
  Render("notes/list.html", ctx)
End Sub
```

このパターンは以下を保証します：

1. ユーザーは認証される必要がある（`RequireLogin`）
2. ユーザーは自分のノートのみを表示できる（`GetAll(userID)`）
3. モデルは SQL レベルでスコーピングを実装する（`WHERE user_id = ?`）

### 所有権の実装

`GetByID`、`Update`、および `Delete` はすべて WHERE 句に `AND user_id = ?` を含みます。ユーザー A がユーザー B のノートの ID を推測してアクセスしようとすると、クエリは `Nil` を返す（または 0 行に影響する）ため、ViewModel は 404 を返します:

```xojo
// In NotesDetailVM.OnGet():
Var note As Dictionary = model.GetByID(id, userID)
If note Is Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

「このノートはあなたのものではありません」という別のエラーメッセージは表示しません — 現在のユーザーの視点からは、そのノートは単に存在しないことになります。

### タグ — グローバルだが保護されている

タグはすべてのユーザー間で共有されます。ログインは必要ですが、ユーザーによるスコープはありません:

```xojo
// In TagsListVM.OnGet():
Sub OnGet()
  If RequireLogin() Then Return    // must be logged in
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()  // no userID — tags are global
  // ...
End Sub
```

この設計により、すべてのユーザーが同じタグの語彙を共有します。1 人のユーザーが作成したタグはすべてのユーザーが利用できます。

---

## 所有権のテスト

`NoteOwnershipTests` はユーザースコーピングが正しく機能することを検証します:

```xojo
Sub WrongUserCannotReadTest()
  Var model As New NoteModel()
  Var id As Integer = model.Create("Secret", "body", 999)

  // User 888 should NOT see user 999's note
  Var note As Dictionary = model.GetByID(id, 888)
  Assert.IsNil(note)
End Sub

Sub WrongUserCannotDeleteTest()
  Var model As New NoteModel()
  Var id As Integer = model.Create("Secret", "body", 999)

  // User 888 tries to delete user 999's note — should have no effect
  model.Delete(id, 888)

  // Note should still exist for user 999
  Var note As Dictionary = model.GetByID(id, 999)
  Assert.IsNotNil(note)
End Sub
```

これらのテストは異なる `userID` 値（999 と 888）を使用して、SQL レベルのスコーピングがユーザー間の不正アクセスを防ぐことを証明します。