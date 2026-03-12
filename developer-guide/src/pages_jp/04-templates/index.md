---
title: JinjaX の概要
description: JinjaX とは何か、フレームワークにどのようにフィットするか、App.Opening() でどのようにセットアップするか。
---

# JinjaX & テンプレート

JinjaX は Jinja2 テンプレートエンジンの純粋 Xojo 実装です。Python の Jinja2 と互換性のある構文で HTML テンプレートを書くことができます — Flask と Django で使用されるのと同じエンジン。

## JinjaX が提供するもの

- **テンプレート継承** — `{% extends "layouts/base.html" %}` を使用した `{% block %}` オーバーライド
- **テンプレート インクルード** — `{% include "partials/nav.html" %}`
- **変数出力** — `{{ variable }}` 自動 HTML エスケープ付き
- **制御フロー** — `{% if %}`、`{% for %}`、`{% else %}`、`{% elif %}`
- **フィルター** — `{{ value | upper }}`、`{{ value | length }}`、カスタムフィルター
- **自動エスケープ** — XSS 保護がデフォルトで有効

## プロジェクトソース

JinjaX は `JinjaXLib/` の下でプロジェクトルートに存在します。コンパイル済みライブラリではなく完全な Xojo ソースとして含まれており、text 形式の `.xojo_code` プロジェクトファイルで機能し、必要に応じて検査またはデバッグできます。

JinjaX をアップグレードしたり修正したりする場合を除き、`JinjaXLib/` を変更しないでください。

## App.Opening() でのセットアップ

`JinjaEnvironment` はアプリケーション起動時に 1 回初期化され、共有シングルトンとして `App` に保存されます。`Opening()` 完了後は読み取り専用で、これによりスレッドセーフになります:

```xojo
// App.Opening() で

// 1. 環境を作成
mJinja = New JinjaX.JinjaEnvironment()

// 2. テンプレートフォルダをポイント
//    IDE デバッグ出力位置からどこでも機能するように絶対パスを使用
Var projectDir As New FolderItem("/path/to/mvvm", FolderItem.PathModes.Native)
Var templatesDir As FolderItem = projectDir.Child("templates")
mJinja.Loader = New JinjaX.FileSystemLoader(templatesDir)

// 3. 自動エスケープを有効にする (XSS に対して保護 — 常にオン)
mJinja.Autoescape = True

// 4. カスタムフィルターを登録
mJinja.RegisterFilter("truncate80", AddressOf TruncateFilter)
```

## カスタムフィルターを登録

フィルターは `Variant` を受け取り `Variant` を返す Xojo メソッドです。テンプレートがパイプ `|` 演算子で使用する文字列名で登録します:

```xojo
// App.xojo_code (またはモジュール) で
Function TruncateFilter(value As Variant) As Variant
  Var s As String = value.StringValue
  If s.Length > 80 Then
    Return s.Left(77) + "..."
  End If
  Return s
End Function

// Opening() で登録:
mJinja.RegisterFilter("truncate80", AddressOf TruncateFilter)
```

テンプレートで:

```html
{{ note.body | truncate80 }}
```

## ViewModel から環境にアクセス

`JinjaEnvironment` は `Handle()` が呼ばれる前にルーターから各 ViewModel に渡されます。`BaseViewModel` はそれを `Jinja` プロパティとして保存します。直接アクセスする必要はありません — `Render()` を呼び出すだけです:

```xojo
// 任意の ViewModel で — Render() は内部的に Self.Jinja を使用
Var ctx As New Dictionary()
ctx.Value("notes") = NoteModel.GetAll()
Render("notes/list.html", ctx)
```

## スレッドセーフティ

`JinjaEnvironment` は `Opening()` 完了後にスレッド間で共有するのは安全です。理由は:

- `RegisterFilter` は `Opening()` 中にのみ呼ばれます — リクエスト処理中には決して呼びません
- `GetTemplate()` と `Render()` は環境から読み取るだけです
- `CompiledTemplate` と `JinjaContext` はリクエストごとに新規作成されます (スタック割り当て、共有されません)

各リクエストは独自の `CompiledTemplate` と `JinjaContext` を取得します — これらは共有されません。
