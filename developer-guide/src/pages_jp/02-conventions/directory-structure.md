---
title: ディレクトリ構造
description: プロジェクト内のすべてのフォルダーとファイルの注釈付きマップ。
---

# ディレクトリ構造

```
mvvm/
├── mvvm.xojo_project           # Xojo プロジェクトファイル (IDE で開く)
├── mvvm.xojo_resources         # アプリでバンドルされた静的リソース
│
├── App.xojo_code               # WebApplication — Opening()、HandleURL()
├── Session.xojo_code           # WebSession サブクラス — ユーザーごとの状態、フラッシュメッセージ
├── Default.xojo_code           # 必須プレースホルダー WebPage (提供されません)
│
├── Framework/                  # 再利用可能なインフラストラクチャ — めったに変更されない
│   ├── Router.xojo_code        # ルート登録とディスパッチ
│   ├── BaseViewModel.xojo_code # ベースクラス: Handle()、Render()、Redirect()、flash
│   ├── FormParser.xojo_code    # application/x-www-form-urlencoded POST ボディを解析
│   ├── QueryParser.xojo_code   # URL クエリ文字列を解析 (?key=val&...)
│   └── RouteDefinition.xojo_code  # データクラス: method、pattern、factory
│
├── ViewModels/                 # ルートごとに 1 クラス
│   ├── HomeViewModel.xojo_code # GET /
│   └── Notes/                  # フィーチャーフォルダ — すべてのノート関連の ViewModel
│       ├── NotesListVM.xojo_code   # GET  /notes
│       ├── NotesNewVM.xojo_code    # GET  /notes/new
│       ├── NotesCreateVM.xojo_code # POST /notes
│       ├── NotesDetailVM.xojo_code # GET  /notes/:id
│       ├── NotesEditVM.xojo_code   # GET  /notes/:id/edit
│       ├── NotesUpdateVM.xojo_code # POST /notes/:id
│       └── NotesDeleteVM.xojo_code # POST /notes/:id/delete
│
├── Models/                     # データアクセス — Dictionary オブジェクトのみを返す
│   └── NoteModel.xojo_code     # notes テーブルの SQLite CRUD
│
├── JinjaXLib/                  # 完全な JinjaX ソースツリー (Xojo での Jinja2 エンジン)
│   └── ...                     # JinjaX をアップグレードしている場合を除き変更しないでください
│
├── templates/                  # HTML テンプレート (Jinja2 構文)
│   ├── layouts/
│   │   └── base.html           # サイトレイアウト — nav、フラッシュメッセージ、コンテンツブロック
│   ├── home.html               # GET /
│   ├── notes/
│   │   ├── list.html           # GET /notes
│   │   ├── detail.html         # GET /notes/:id
│   │   └── form.html           # GET /notes/new と GET /notes/:id/edit (共有)
│   └── errors/
│       ├── 404.html
│       └── 500.html
│
├── data/
│   └── notes.sqlite            # SQLite データベース (初回実行時に自動作成)
│
└── developer-guide/            # このドキュメント
    ├── build.py
    ├── nav.yaml
    ├── src/
    └── dist/
```

## Framework vs ViewModels

`Framework/` フォルダには 1 回書いてめったに触れないコードが含まれています。これは「エンジン」です — ルーティング、基本 ViewModel ライフサイクル、リクエスト/レスポンスヘルパー。新しい機能を追加するときは、`Framework/` を変更しません。

`ViewModels/` はすべてのアプリケーション固有の作業が行われる場所です。すべての新しいルートは、関連するフィーチャーフォルダに新しい ViewModel ファイルを取得します。

## ViewModels のフィーチャーフォルダ

HTTP メソッドではなく、フィーチャーで ViewModel をグループ化します:

```
ViewModels/
  Notes/         ← すべての 7 つのノート関連 ViewModel がここに存在
  Users/         ← すべてのユーザー関連 ViewModel (今後)
  Admin/         ← すべての管理関連 ViewModel (今後)
```

これにより、関連ファイルが一緒に保たれ、1 つの場所でフィーチャーに関するすべてを見つけやすくなります。

## テンプレートミラーリング

`templates/` 構造は URL 階層を反映しています:

| URL | テンプレート |
|---|---|
| `/notes` | `templates/notes/list.html` |
| `/notes/new` | `templates/notes/form.html` |
| `/notes/:id` | `templates/notes/detail.html` |
| `/notes/:id/edit` | `templates/notes/form.html` |
| エラー 404 | `templates/errors/404.html` |

`form.html` テンプレートは create と edit ルート間で共有されます。`note` コンテキスト変数の存在を検査します: 存在する場合、フォームはエディットモード; 存在しない場合、フォームは作成モード。

## `data/` ディレクトリ

現在、データベースパスは開発用にハードコードされています。本番ビルドの場合、`SpecialFolder.ApplicationData` を使用して、データベースを正しい OS 位置に配置します:

```xojo
// 開発 (IDE デバッグ実行用にハードコード)
Var dbFile As New FolderItem("/path/to/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)

// 本番 (正しいアプローチ)
Var appData As FolderItem = SpecialFolder.ApplicationData
Var dbFile As FolderItem = appData.Child("mvvm").Child("notes.sqlite")
```
