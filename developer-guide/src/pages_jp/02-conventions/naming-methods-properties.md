---
title: メソッドとプロパティ
description: Xojo メソッド、プロパティ、Dictionary キーの命名規約。
---

# メソッドとプロパティ

## ViewModel メソッド

すべての ViewModel は `BaseViewModel` から継承し、以下の 1 つまたは両方をオーバーライドします:

```xojo
Sub OnGet()   // GET リクエストを処理
Sub OnPost()  // POST リクエストを処理
```

これらは意図的にイベントハンドラーのように命名されています — HTTP メソッドに**応答する**ものであり、自ら何かを開始するものではありません。`OnGet()` のみをオーバーライドした場合、そのルートへの `POST` は基底クラスから自動的に 405 レスポンスを返します。

ViewModel 内のプライベートヘルパーメソッドは説明的な動詞優先名を使用します:

```xojo
// ✅ 良好 — 英語を読むように、何をするかを説明する
Private Function FindNoteOrRedirect(id As Integer) As Dictionary
Private Sub ValidateTitle(title As String)

// ❌ 避ける — あいまい、ゲッターのように読む
Private Function GetData() As Dictionary
Private Sub Process()
```

## プロパティ

Xojo 規約: プライベート (モジュールレベル) プロパティは `m` プレフィックスと `camelCase` を使用します:

```xojo
Private mFormData As Dictionary   // キャッシュされた解析済み POST ボディ
Private mRawBody  As String       // 生の POST ボディバイト
```

パブリックプロパティ（`BaseViewModel` によって継承または設定されるもの）はプレフィックスなしです:

```xojo
// これらは Handle() が呼ばれる前にルーターで設定されます
Request    As WebRequest
Response   As WebResponse
Session    As WebSession
Jinja      As JinjaX.JinjaEnvironment
PathParams As Dictionary
```

## モデルメソッド

モデルメソッドはデータ操作を明確に説明します。標準的な CRUD 動詞を使用します:

| 操作 | メソッド名 | 戻り型 |
|---|---|---|
| すべての行をフェッチ | `GetAll()` | `Variant()` of `Dictionary` |
| 1 行をフェッチ | `GetByID(id As Integer)` | `Dictionary` or `Nil` |
| 作成 | `Create(...)` | `Integer` (新しい行 ID) |
| 更新 | `Update(id, ...)` | `Sub` (戻り値なし) |
| 削除 | `Delete(id As Integer)` | `Sub` (戻り値なし) |

モデルメソッドは `Shared` です — モデルクラスをインスタンス化する必要はありません。クラスを直接呼び出せます:

```xojo
// ✅ クラスで直接呼び出す
Var notes As Variant() = NoteModel.GetAll()
Var note As Dictionary = NoteModel.GetByID(42)
NoteModel.Delete(42)

// ❌ モデルをインスタンス化しない
Var model As New NoteModel()
model.GetAll()
```

## Dictionary キー

`Dictionary` オブジェクト内のキー — テンプレートのコンテキスト Dictionary とモデルの戻り値の両方 — は `snake_case` 文字列を使用します。これは SQLite のカラム名と Jinja2 テンプレートで使用される変数名に一致します:

```xojo
// モデル → Dictionary
row.Value("id")         = rs.Column("id").IntegerValue
row.Value("title")      = rs.Column("title").StringValue
row.Value("created_at") = rs.Column("created_at").StringValue

// ViewModel → テンプレートのコンテキスト Dictionary
Var ctx As New Dictionary()
ctx.Value("notes")      = NoteModel.GetAll()    // Variant() of Dictionary
ctx.Value("page_title") = "All Notes"
ctx.Value("flash")      = ...                   // Render() によって自動的に注入
```

テンプレートでは、同じ `snake_case` キー名がドット記法でアクセスされます:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

## BaseViewModel ヘルパーメソッド

これらのメソッドは常に任意の ViewModel 内で利用可能です:

`GetFormValue(key)` — URL エンコードされた POST ボディからフィールドを読み取ります。初回呼び出し時にボディを遅延解析し、結果をキャッシュします。

```xojo
Var title As String = GetFormValue("title")
Var body  As String = GetFormValue("body")
```

`GetParam(key)` — URL パスパラメータまたはクエリ文字列パラメータを読み取ります。パスパラメータはクエリ文字列パラメータより優先されます。

```xojo
// /notes/:id を持つルートで URL /notes/42
Var id As Integer = GetParam("id").ToInteger()

// URL /notes?sort=asc
Var sort As String = GetParam("sort")
```

`Render(templateName, context)` — テンプレートをコンパイルしてレンダリングし、フラッシュメッセージを自動注入して、HTML レスポンスを書き込みます。

```xojo
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

`Redirect(url, statusCode)` — HTTP リダイレクトを送信します。デフォルトステータスは 302 です。実行を停止するために常に直後に `Return` を呼び出します。

```xojo
Redirect("/notes")
Return
```

`SetFlash(message, type)` — セッションにフラッシュメッセージを保存します。次の `Render()` 呼び出し時に自動的にテンプレートコンテキストへ注入されます。タイプは `"success"`、`"error"`、または `"info"` です。

```xojo
SetFlash("Note created.", "success")
Redirect("/notes")
Return
```
