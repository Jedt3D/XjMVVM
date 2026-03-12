---
title: ファイル命名
description: ViewModel ファイル、モデルファイル、テンプレートファイルの命名規約。
---

# ファイル命名

## ViewModels

ViewModel ファイルは `{Feature}{Action}VM.xojo_code` パターンに従います。ここで:

- **Feature** は名詞 (コレクション操作は複数形、アイテム操作は単数形)
- **Action** はこの ViewModel が何をするかを説明する動詞
- **VM** サフィックスは、これが ViewModel であることを一目で明確にします

リソースの 7 つの標準的なアクションは RESTful 規約に従います:

| アクション | HTTP | URL | ファイル |
|---|---|---|---|
| すべてをリスト | `GET` | `/notes` | `NotesListVM.xojo_code` |
| 新規フォームを表示 | `GET` | `/notes/new` | `NotesNewVM.xojo_code` |
| 作成 | `POST` | `/notes` | `NotesCreateVM.xojo_code` |
| 詳細を表示 | `GET` | `/notes/:id` | `NotesDetailVM.xojo_code` |
| 編集フォームを表示 | `GET` | `/notes/:id/edit` | `NotesEditVM.xojo_code` |
| 更新 | `POST` | `/notes/:id` | `NotesUpdateVM.xojo_code` |
| 削除 | `POST` | `/notes/:id/delete` | `NotesDeleteVM.xojo_code` |

すべてのリソースが 7 つすべてを必要とするわけではありません。読み取り専用リソースは `ListVM` と `DetailVM` のみを持つかもしれません。REST 以外のページ (ホームページやダッシュボードなど) は単純な説明的名前を取得します: `HomeViewModel.xojo_code`。

### クラス名はファイル名に一致

ファイル内のクラス名はファイル名と正確に一致する必要があります:

```
NotesCreateVM.xojo_code  →  Class NotesCreateVM
NoteModel.xojo_code      →  Class NoteModel
```

Xojo はランタイムでクラス名を使用します（ファイル名ではありません）が、両者を一致させることで混乱を防げます。

## モデル

モデルファイルは `{Feature}Model.xojo_code` パターンに従います:

```
NoteModel.xojo_code     # 単数形 — 「ノートのモデル」
UserModel.xojo_code     # 今後
ProductModel.xojo_code  # 今後
```

名詞の **単数形** を使用します — モデルはエンティティ自体を表し、それのコレクションではありません。

## テンプレート

テンプレートファイルは小文字の `snake_case` 名と `.html` 拡張子を使用します。

フォルダ名はフィーチャー (小文字の複数形) と一致します:

```
templates/
  notes/
    list.html     ← コレクションビュー
    detail.html   ← 単一アイテムビュー
    form.html     ← create + edit (共有)
  users/
    list.html
    detail.html
    form.html
  layouts/
    base.html     ← サイトレイアウト、決して直接レンダリングされない
  errors/
    404.html
    500.html
```

### 共有フォームテンプレート

create フォームと edit フォームがほぼ同じ場合、単一の `form.html` を使用してコンテキスト変数の存在を切り替えます:

```html
{# templates/notes/form.html #}
{% if note %}
  {# エディットモード — note.id が存在 #}
  <form method="post" action="/notes/{{ note.id }}">
  <h1>Edit Note</h1>
{% else %}
  {# 作成モード — ノートなし #}
  <form method="post" action="/notes">
  <h1>New Note</h1>
{% endif %}
```

ViewModel はコンテキスト Dictionary で `note` を渡すか省略することでモードを制御します。

## ルート登録命名

`App.Opening()` でルートを登録するときは、順序を合わせます: GET を POST の前に、リストを詳細の前に登録します:

```xojo
// App.Opening() で — ルートを論理的順序で登録
mRouter.Get("/",                 New HomeViewModelFactory())
mRouter.Get("/notes",            New NotesListVMFactory())
mRouter.Get("/notes/new",        New NotesNewVMFactory())    // ← :id の前である必要があります
mRouter.Post("/notes",           New NotesCreateVMFactory())
mRouter.Get("/notes/:id",        New NotesDetailVMFactory())
mRouter.Get("/notes/:id/edit",   New NotesEditVMFactory())
mRouter.Post("/notes/:id",       New NotesUpdateVMFactory())
mRouter.Post("/notes/:id/delete",New NotesDeleteVMFactory())
```

!!! warning "順序が重要です"
    `/notes/new` は `/notes/:id` **の前に** 登録する必要があります。ルーターはルートを登録順でマッチさせます — `:id` が最初に来た場合、リテラルセグメント `new` は ID 値として取得されます。
