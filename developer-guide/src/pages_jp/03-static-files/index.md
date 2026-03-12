---
title: 静的アセットの提供
description: XjMVVM アプリで CSS、JavaScript、画像、その他の静的ファイルをサーブする方法。
---

# 静的アセットの提供

`HandleURL` がすべてのリクエストをインターセプトするため、静的アセット（`.css`、`.js`、画像）のリクエストを明示的に処理する必要があります。シンプルな順から柔軟な順に並べた 3 つのアプローチがあります。

## オプション 1 — CDN リンク (ライブラリに推奨)

サードパーティのライブラリ (Tailwind、Alpine.js、チャートライブラリ) の場合、CDN から直接リンクします。Xojo コードは不要です。

```html
{# templates/layouts/base.html #}
<head>
  <link rel="stylesheet" href="https://cdn.tailwindcss.com">
  <script src="https://unpkg.com/alpinejs@3" defer></script>
</head>
```

更新しないライブラリにはこの方法を使用します。デプロイの複雑さはゼロです。

## オプション 2 — 静的ファイル ViewModel

独自の CSS・JS・画像の場合、ディスクからファイルを読み取ってレスポンスに書き込む `/static/:file` ルートを登録します。

### 1. ViewModel を作成

`ViewModels/StaticFileVM.xojo_code` を作成:

```xojo
Class StaticFileVM
  Inherits BaseViewModel

  Sub OnGet()
    Var fileName As String = GetParam("file")

    // セキュリティ: パストラバーサル試行を拒否
    If fileName.Contains("..") Or fileName.Contains("/") Or fileName.Contains("\") Then
      Response.Status = 400
      Response.Write("Bad Request")
      Return
    End If

    // static/ フォルダへのパスをビルド (プロジェクトレイアウトに合わせて調整)
    Var staticDir As New FolderItem("/path/to/mvvm/static", FolderItem.PathModes.Native)
    Var file As FolderItem = staticDir.Child(fileName)

    If Not file.Exists Then
      Response.Status = 404
      Response.Write("Not Found")
      Return
    End If

    // 拡張に基づいて MIME タイプを設定
    Response.Header("Content-Type") = MimeType(fileName)

    // 本番でキャッシュ静的アセット 1 時間
    Response.Header("Cache-Control") = "public, max-age=3600"

    // ファイルバイトを読み取り、書き込み
    Var bs As BinaryStream = BinaryStream.Open(file, False)
    Response.Write(bs.Read(bs.Length))
    bs.Close()
  End Sub

  Private Function MimeType(fileName As String) As String
    Var ext As String = fileName.NthField(".", fileName.CountFields(".")).Lowercase
    Select Case ext
    Case "css"   : Return "text/css; charset=utf-8"
    Case "js"    : Return "application/javascript; charset=utf-8"
    Case "png"   : Return "image/png"
    Case "jpg", "jpeg" : Return "image/jpeg"
    Case "gif"   : Return "image/gif"
    Case "svg"   : Return "image/svg+xml"
    Case "ico"   : Return "image/x-icon"
    Case "woff2" : Return "font/woff2"
    Case "woff"  : Return "font/woff"
    Case "pdf"   : Return "application/pdf"
    Else          : Return "application/octet-stream"
    End Select
  End Function

End Class
```

### 2. ルートを登録

`App.Opening()` で、他のすべてのルートの**後に**静的ルートを登録して、アプリケーションパスと誤ってマッチするのを避けます:

```xojo
// アプリケーションルートを最初に登録
mRouter.Get("/",           New HomeViewModelFactory())
mRouter.Get("/notes",      New NotesListVMFactory())
// ... その他のルート ...

// 静的ファイルを最後に
mRouter.Get("/static/:file", New StaticFileVMFactory())
```

### 3. static/ フォルダを作成

```
mvvm/
  static/
    app.css
    app.js
    logo.png
```

### 4. テンプレートで参照

```html
<link rel="stylesheet" href="/static/app.css">
<script src="/static/app.js" defer></script>
<img src="/static/logo.png" alt="Logo">
```

!!! warning "セキュリティ"
    ディスクから読み取る前に必ずファイル名を検証してください。上記のパストラバーサルチェック（`..`、`/`、`\`）は最低限必須です。ユーザー入力を直接使ってファイルパスを構築しないでください。

## オプション 3 — Xojo Copy Files ビルドステップ

アプリケーションバイナリでバンドルする必要があるファイル (フォント、デフォルト画像) の場合、Xojo の **Copy Files** ビルドステップを使用してそれらをアプリケーションの Resources フォルダに含めます。

その後、実行時に以下を使用してアクセスします:

```xojo
Var resourceDir As FolderItem = App.ExecutableFile.Parent.Child("Resources")
Var file As FolderItem = resourceDir.Child(fileName)
```

このアプローチは、アプリケーションに同梱され、実行時に変化しないファイルに最適です。開発中に頻繁に編集する開発用アセットの場合は、オプション 2 の方が便利です。

## MIME タイプリファレンス

| 拡張子 | MIME タイプ |
|---|---|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css; charset=utf-8` |
| `.js` | `application/javascript; charset=utf-8` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg` / `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.svg` | `image/svg+xml` |
| `.ico` | `image/x-icon` |
| `.woff2` | `font/woff2` |
| `.woff` | `font/woff` |
| `.pdf` | `application/pdf` |
