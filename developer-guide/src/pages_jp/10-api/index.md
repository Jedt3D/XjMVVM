---
title: "JSON API & 静的ファイル配信"
description: XjMVVMがSSRルートと同時に認証済みJSON APIを公開する方法、および組み込み静的ファイルサーバーの動作原理。
---

# JSON API & 静的ファイル配信

XjMVVM は、同じアプリケーションからサーバーレンダリングされた HTML ページ**と** JSON API の両方を提供でき、別プロセスやフレームワークは不要です。API は同じ Router、同じ ViewModel パターン、同じ Model を使用します。唯一の違いはレスポンス形式と認証ガードです。

---

## JSONSerializer モジュール

**ファイル:** `Framework/JSONSerializer.xojo_code`

`Dictionary` と `Variant()` の `Dictionary` を JSON 文字列に変換するシンプルなモジュールです。外部ライブラリに依存せず、文字列操作のみを使用します。

```xojo
Module JSONSerializer

  // Escape a value for use inside a JSON string literal
  Function EscapeString(s As String) As String
    s = s.ReplaceAll("\", "\\")
    s = s.ReplaceAll(Chr(34), "\""")  // double-quote
    s = s.ReplaceAll(Chr(10), "\n")   // newline
    s = s.ReplaceAll(Chr(13), "\r")   // carriage return
    s = s.ReplaceAll(Chr(9),  "\t")   // tab
    Return s
  End Function

  // Serialize a Dictionary of string values to a JSON object
  Function DictToJSON(d As Dictionary) As String
    Var parts() As String
    For Each key As Variant In d.Keys
      Var k As String = EscapeString(key.StringValue)
      Var v As String = EscapeString(d.Value(key).StringValue)
      parts.Add("""" + k + """" + ":" + """" + v + """")
    Next
    Return "{" + String.FromArray(parts, ",") + "}"
  End Function

  // Serialize a Variant() of Dictionary to a JSON array
  Function ArrayToJSON(items() As Variant) As String
    Var parts() As String
    For Each item As Variant In items
      Var d As Dictionary = item
      parts.Add(DictToJSON(d))
    Next
    Return "[" + String.FromArray(parts, ",") + "]"
  End Function

End Module
```

!!! note
    すべての値は JSON 文字列としてシリアライズされます — 数値型やブール型はありません。これは `RowToDict` の動作と一致しており、すべてのデータベース値は `StringValue` として保存されます。API の利用者は必要に応じて文字列から数値をパースしてください。

### BaseViewModel の `WriteJSON`

```xojo
Sub WriteJSON(jsonString As String)
  Response.Header("Content-Type") = "application/json; charset=utf-8"
  Response.Write(jsonString)
End Sub
```

Content-Type はクライアントに JSON であることを通知します。ViewModel がヘッダを直接設定する必要はありません — シリアライズされた文字列で `WriteJSON(...)` を呼び出すだけです。

---

## API認証

すべてのAPIエンドポイントには認証が必要です。HTMLルートが `/login` にリダイレクトするのと異なり、APIルートは認証されていないユーザーに対して **401 JSON エラー** を返します：

```json
{"error":"Authentication required"}
```

すべてのAPI ViewModelは最初の行として `RequireLoginJSON()` を呼び出します：

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return  // 401 if no valid mvvm_auth cookie
  // ... rest of handler
End Sub
```

API クライアントはリクエストに `mvvm_auth` クッキーを含める必要があります。ブラウザベースの JavaScript（`fetch`）の場合、`credentials: 'same-origin'` を使用すると自動的に送信されます。外部クライアントの場合、ログインエンドポイントでクッキーを取得し、以降のリクエストで送信してください。

---

## API ViewModels

すべてのAPI ViewModelは `ViewModels/API/` 配下に置かれます。SSR ViewModelと同じ `OnGet()`/`OnPost()` パターンに従います — 唯一の違いは `Render()` の代わりに `WriteJSON()` を呼び出す点です。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[GET /api/notes] -> [NotesAPIListVM|RequireLoginJSON()\nmodel.GetAll(userID)\nArrayToJSON()]
[GET /api/notes/:id] -> [NotesAPIDetailVM|RequireLoginJSON()\nmodel.GetByID(id, userID)\nembed tags in JSON]
[POST /api/notes] -> [NotesAPICreateVM|RequireLoginJSON()\nvalidate\nmodel.Create(title, body, userID)\n201 Created]
[GET /api/tags] -> [TagsAPIListVM|RequireLoginJSON()\nmodel.GetAll()\nArrayToJSON()]
[GET /api/tags/:id] -> [TagsAPIDetailVM|RequireLoginJSON()\nmodel.GetByID(id)\nDictToJSON()]
-->
<!-- ascii
GET  /api/notes       -> NotesAPIListVM   -> RequireLoginJSON() -> ArrayToJSON(notes)
GET  /api/notes/:id   -> NotesAPIDetailVM -> RequireLoginJSON() -> note + embedded tags array
POST /api/notes       -> NotesAPICreateVM -> RequireLoginJSON() -> 201 Created + new note JSON
GET  /api/tags        -> TagsAPIListVM    -> RequireLoginJSON() -> ArrayToJSON(tags)
GET  /api/tags/:id    -> TagsAPIDetailVM  -> RequireLoginJSON() -> DictToJSON(tag)
-->
<!-- /diagram -->

### NotesAPIListVM — `GET /api/notes`

認証されたユーザーのすべてのノートを返します：

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll(userID)
  WriteJSON(JSONSerializer.ArrayToJSON(notes))
End Sub
```

レスポンス: `[{"id":"1","title":"Hello","body":"...","created_at":"...","updated_at":"...","user_id":"5"},...]`

ノートは認証されたユーザーにスコープされます — 各ユーザーは自身のノートのみを表示します。

### NotesAPIDetailVM — `GET /api/notes/:id`

ノートを埋め込み `tags` 配列とともに返します。ノートが存在しないか別のユーザーに属する場合は404を返します：

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var id As Integer = Val(GetParam("id"))
  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var note As Dictionary = model.GetByID(id, userID)

  If note = Nil Then
    Response.Status = 404
    WriteJSON("{""error"":""Note not found""}")
    Return
  End If

  // Embed tags array inside the note JSON object
  Var tags() As Variant = model.GetTagsForNote(id)
  Var noteJSON As String = JSONSerializer.DictToJSON(note)
  Var tagsJSON As String = JSONSerializer.ArrayToJSON(tags)
  noteJSON = noteJSON.Left(noteJSON.Length - 1) + ",""tags"":" + tagsJSON + "}"
  WriteJSON(noteJSON)
End Sub
```

タグ配列は文字列操作で挿入されます — 閉じ `}` を削除し、`,"tags":[...]}` を追加して再度閉じます。これは意図的な設計です: `JSONSerializer.DictToJSON` はフラットな文字列 Dictionary のみを処理します。ネストされた配列を埋め込むには手動の構築が必要です。

!!! note
    `DictToJSON` は常に `}` で終わる有効なJSONオブジェクトを生成するため、このアプローチは確実に機能します。シリアライザが変更された場合は、この挿入ポイントを見直す必要があります。

### NotesAPICreateVM — `POST /api/notes`

```xojo
Sub OnPost()
  If RequireLoginJSON() Then Return

  Var title As String = GetFormValue("title").Trim()
  Var body As String = GetFormValue("body")

  If title.Length = 0 Then
    Response.Status = 422      // Unprocessable Entity -- validation error
    WriteJSON("{""error"":""Title is required""}")
    Return
  End If

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var newID As Integer = model.Create(title, body, userID)
  Var note As Dictionary = model.GetByID(newID, userID)

  Response.Status = 201        // Created
  WriteJSON(JSONSerializer.DictToJSON(note))
End Sub
```

API が使用するステータスコード: **200** は読み取り成功、**201** は作成成功、**401** は未認証、**404** は見つからない場合、**422** は検証失敗。

### TagsAPIListVM — `GET /api/tags`

タグはグローバル（ユーザースコープなし）ですが、それでも認証が必要です：

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(tags))
End Sub
```

### TagsAPIDetailVM — `GET /api/tags/:id`

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var id As Integer = Val(GetParam("id"))
  Var model As New TagModel()
  Var tag As Dictionary = model.GetByID(id)

  If tag = Nil Then
    Response.Status = 404
    WriteJSON("{""error"":""Tag not found""}")
    Return
  End If

  WriteJSON(JSONSerializer.DictToJSON(tag))
End Sub
```

---

## APIルート

`App.Opening` でSSRルートと共に登録されます：

```xojo
// JSON API routes
mRouter.Get("/api/notes",       AddressOf CreateNotesAPIListVM)
mRouter.Post("/api/notes",      AddressOf CreateNotesAPICreateVM)
mRouter.Get("/api/notes/:id",   AddressOf CreateNotesAPIDetailVM)
mRouter.Get("/api/tags",        AddressOf CreateTagsAPIListVM)
mRouter.Get("/api/tags/:id",    AddressOf CreateTagsAPIDetailVM)
```

`/api/` プレフィックスは慣例により API ルートと SSR ルートを区別します — Router はどちらも同様に扱います。

---

## 静的ファイルサーバー

**ファイル:** `App.xojo_code` (`ServeStatic` メソッド + `HandleURL` ディスパッチ)

静的ファイルサーバーにより、開発者ドキュメントサイトは実行中のアプリから `/dist/*` でアクセス可能になります。ファイルは `templates/dist/` から提供されます — `build.py` スクリプトの出力先と同じフォルダです。

### HandleURL ディスパッチ

```xojo
// Redirect bare /dist to /dist/
If p = "/dist" Then
  response.Status = 302
  response.Header("Location") = "/dist/"
  Return True
End If
// Serve anything under /dist/
If p.Left(6) = "/dist/" Then
  Return ServeStatic(p.Middle(6), response)
End If
```

`p.Middle(6)` は `/dist/` プリフィックス（6文字、0ベース）を削除し、残りを `ServeStatic` に渡します。

### ServeStatic — パストラバーサル防止

```xojo
Private Function ServeStatic(relativePath As String, response As WebResponse) As Boolean
  // Start from the known safe root
  Var f As FolderItem = App.ExecutableFile.Parent.Child("templates").Child("dist")

  // Walk each path segment individually -- never concatenate raw user input
  Var parts() As String = relativePath.Split("/")
  For Each part As String In parts
    If part = "" Or part = "." Or part = ".." Then Continue  // skip dangerous segments
    f = f.Child(part)
    If f Is Nil Or Not f.Exists Then
      response.Status = 404
      response.Header("Content-Type") = "text/plain"
      response.Write("Not found")
      Return True
    End If
  Next

  // Directory -> try index.html automatically
  If f.IsFolder Then
    f = f.Child("index.html")
    If f Is Nil Or Not f.Exists Then
      response.Status = 404
      response.Write("Not found")
      Return True
    End If
  End If
  // ... content-type + file read ...
End Function
```

!!! warning
    **決して**生の URL 文字列を連結してファイルパスを構築しないでください。パスを直接連結した場合、`/dist/../data/notes.sqlite` へのリクエストでデータベースファイルが公開されてしまいます。`Child()` で各セグメントを一つずつ辿り、`..` と `.` を拒否することで、パストラバーサル攻撃を完全に防止します。

### Content-Type マッピング

```xojo
Var ext As String = f.Name.Lowercase
Var ct As String = "application/octet-stream"
If ext.EndsWith(".html")  Then ct = "text/html; charset=utf-8"
If ext.EndsWith(".css")   Then ct = "text/css"
If ext.EndsWith(".js")    Then ct = "application/javascript"
If ext.EndsWith(".svg")   Then ct = "image/svg+xml"
If ext.EndsWith(".png")   Then ct = "image/png"
If ext.EndsWith(".ico")   Then ct = "image/x-icon"
If ext.EndsWith(".woff2") Then ct = "font/woff2"
```

未知の拡張子は `application/octet-stream` にフォールバックします。追加のファイルタイプを配信する場合は、ここに新しいエントリを追加してください。

### ドキュメントへのアクセス

アプリがポート8080で実行されている場合、開発者ドキュメントは以下で利用可能です：

```
http://localhost:8080/dist/en/index.html
http://localhost:8080/dist/th/index.html
http://localhost:8080/dist/jp/index.html
```

`/dist/` ルートはSSR ルーターの前に処理されるため、静的サーバーは常にそのプリフィックスに対して優先されます。