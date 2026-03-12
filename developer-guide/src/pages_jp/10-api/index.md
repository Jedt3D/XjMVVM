---
title: JSON API と静的提供
description: XjMVVMがSSRルートと並行してJSON APIを公開する方法、および組み込み静的ファイルサーバーがどのように機能するか。
---

# JSON API と静的提供

XjMVVMは、同じアプリケーションから**サーバーレンダリングHTMLページ** と **JSON API**の両方を提供できます — 別のプロセスやフレームワークは必要ありません。APIは同じRouter、同じViewModelsパターン、同じModelsを使用します。唯一の違いはレスポンス形式です。

---

## JSONSerializerモジュール

**File:** `Framework/JSONSerializer.xojo_code`

`Dictionary`と`Variant()`の`Dictionary`をJSON文字列に変換する単純なモジュール。外部ライブラリに依存しません — 文字列操作だけです。

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
    すべての値はJSON文字列としてシリアライズされます — 数値またはブール値の型ではなく。これは`RowToDict`がどのように機能するかと一致しています：すべてのデータベース値は`StringValue`として格納されます。APIのコンシューマーは必要に応じて文字列から数値を解析する必要があります。

### BaseViewModelの`WriteJSON`

```xojo
Sub WriteJSON(jsonString As String)
  Response.Header("Content-Type") = "application/json; charset=utf-8"
  Response.Write(jsonString)
End Sub
```

コンテンツタイプはクライアントにJSONを信号で伝えます。ViewModelはヘッダーを直接設定する必要がありません — シリアライズされた文字列でシリアライズされた`WriteJSON(...)`を呼び出すだけです。

---

## API ViewModel

すべてのAPI ViewModelは`ViewModels/API/`の下に住んでいます。SSR ViewModelと同じ`OnGet()`/`OnPost()`パターンに従います — 唯一の違いは、`Render()`の代わりに`WriteJSON()`を呼び出します。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[GET /api/notes] -> [NotesAPIListVM|model.GetAll()\nArrayToJSON()]
[GET /api/notes/:id] -> [NotesAPIDetailVM|model.GetByID(id)\nGetTagsForNote(id)\nembed tags in JSON]
[POST /api/notes] -> [NotesAPICreateVM|validate\nmodel.Create()\n201 Created]
[GET /api/tags] -> [TagsAPIListVM|model.GetAll()\nArrayToJSON()]
[GET /api/tags/:id] -> [TagsAPIDetailVM|model.GetByID(id)\nDictToJSON()]
-->
<!-- ascii
GET  /api/notes       → NotesAPIListVM   → ArrayToJSON(notes)
GET  /api/notes/:id   → NotesAPIDetailVM → note + embedded tags array
POST /api/notes       → NotesAPICreateVM → 201 Created + new note JSON
GET  /api/tags        → TagsAPIListVM    → ArrayToJSON(tags)
GET  /api/tags/:id    → TagsAPIDetailVM  → DictToJSON(tag)
-->
<!-- /diagram -->

### NotesAPIListVM — `GET /api/notes`

```xojo
Sub OnGet()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(notes))
End Sub
```

レスポンス：`[{"id":"1","title":"Hello","body":"...","created_at":"...","updated_at":"..."},...]`

### NotesAPIDetailVM — `GET /api/notes/:id`

埋め込まれた`tags`配列を持つnoteを返します：

```xojo
Sub OnGet()
  Var id As Integer = Val(GetParam("id"))
  Var model As New NoteModel()
  Var note As Dictionary = model.GetByID(id)

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

タグ配列は文字列操作により埋め込まれます — 閉じ`}`を削除し、再度クローズする前に`,"tags":[...]}`を追加します。これは意図的です：`JSONSerializer.DictToJSON`はフラット文字列ディクショナリのみを処理します。ネストされた配列を埋め込むには、手動での構成が必要です。

!!! note
    このアプローチは確実に機能します。なぜなら`DictToJSON`は常に`}`で終わる有効なJSONオブジェクトを生成するからです。シリアライザーが変わる場合は、この埋め込みポイントをレビューする必要があります。

### NotesAPICreateVM — `POST /api/notes`

```xojo
Sub OnPost()
  Var title As String = GetFormValue("title").Trim()
  Var body As String = GetFormValue("body")

  If title.Length = 0 Then
    Response.Status = 422      // Unprocessable Entity — validation error
    WriteJSON("{""error"":""Title is required""}")
    Return
  End If

  Var model As New NoteModel()
  Var newID As Integer = model.Create(title, body)
  Var note As Dictionary = model.GetByID(newID)

  Response.Status = 201        // Created
  WriteJSON(JSONSerializer.DictToJSON(note))
End Sub
```

APIで使用されるステータスコード：成功したよみのための**200**、成功した作成のための**201**、見つからないための**404**、検証失敗のための**422**。

### TagsAPIListVM — `GET /api/tags`

```xojo
Sub OnGet()
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(tags))
End Sub
```

### TagsAPIDetailVM — `GET /api/tags/:id`

```xojo
Sub OnGet()
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

SSRルートと並行して`App.Opening`に登録：

```xojo
// JSON API routes
mRouter.Get("/api/notes",       AddressOf CreateNotesAPIListVM)
mRouter.Post("/api/notes",      AddressOf CreateNotesAPICreateVM)
mRouter.Get("/api/notes/:id",   AddressOf CreateNotesAPIDetailVM)
mRouter.Get("/api/tags",        AddressOf CreateTagsAPIListVM)
mRouter.Get("/api/tags/:id",    AddressOf CreateTagsAPIDetailVM)
```

`/api/`プリフィックスは、APIルートをSSRルートから慣例で分離します — ルーターは同じように扱います。

---

## 静的ファイルサーバー

**File:** `App.xojo_code` （`ServeStatic`メソッド + `HandleURL`ディスパッチ）

静的ファイルサーバーは、`/dist/*`で実行中のアプリから開発者ドキュメントサイトに直接アクセス可能にします。ファイルは`templates/dist/`から提供されます — `build.py`スクリプトが出力するのと同じフォルダ。

### HandleURLディスパッチ

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

`p.Middle(6)`は`/dist/`プリフィックス（6文字、0ベース）をストリップし、残りを`ServeStatic`に渡します。

### ServeStatic — パストラバーサル防止

```xojo
Private Function ServeStatic(relativePath As String, response As WebResponse) As Boolean
  // Start from the known safe root
  Var f As FolderItem = App.ExecutableFile.Parent.Child("templates").Child("dist")

  // Walk each path segment individually — never concatenate raw user input
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

  // Directory → try index.html automatically
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
    **決して**生のURL文字列を連結してファイルパスを構築しないでください。`/dist/../data/notes.sqlite`へのリクエストは、パスが直接連結されている場合、データベースファイルを提供します。`Child()`を経由して各セグメントをウォークし、`..`と`.`を拒否することで、パストラバーサル攻撃を完全に防ぎます。

### Content-Typeマッピング

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

不明な拡張子は`application/octet-stream`にフォールバックします。追加ファイルタイプを提供する場合は、ここに新しいエントリを追加してください。

### ドキュメントへのアクセス

ポート8080でアプリを実行すると、開発者ドキュメントは以下で利用可能です：

```
http://localhost:8080/dist/en/index.html
http://localhost:8080/dist/th/index.html
http://localhost:8080/dist/jp/index.html
```

`/dist/`ルートはSSRルーターの前に処理されるため、静的サーバーはそのプリフィックスに対して常に優先されます。
