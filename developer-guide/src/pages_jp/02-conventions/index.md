---
title: 規約の概要
description: XjMVVM フレームワーク全体で使用される命名および構造の規約。
---

# 規約

一貫した規約はコードベースを予測可能にします。すべての開発者が同じパターンをファイル名、クラス名、メソッド名に従う場合、すべてのファイルを開くことなく、未知の機能をナビゲートできます。

このセクションは 3 つの領域をカバーします:

- **[ディレクトリ構造](directory-structure.html)** — すべてが存在する場所とその理由
- **[ファイル命名](file-naming.html)** — ViewModel、モデル、テンプレートの命名方法
- **[メソッドとプロパティ](naming-methods-properties.html)** — Xojo コードの命名規則

## クイックリファレンス

| 項目 | 規約 | 例 |
|---|---|---|
| ViewModel ファイル | `{Feature}{Action}VM.xojo_code` | `NotesCreateVM.xojo_code` |
| モデルファイル | `{Feature}Model.xojo_code` | `NoteModel.xojo_code` |
| テンプレートフォルダ | `templates/{feature}/` | `templates/notes/` |
| テンプレートファイル | `{action}.html` | `form.html`, `list.html` |
| プライベートプロパティ | `mCamelCase` | `mFormData`, `mRawBody` |
| ViewModel メソッド (GET) | `OnGet()` | `BaseViewModel.OnGet()` をオーバーライド |
| ViewModel メソッド (POST) | `OnPost()` | `BaseViewModel.OnPost()` をオーバーライド |
| Dictionary キー | `snake_case` 文字列 | `"page_title"`, `"created_at"` |
| URL パスパラメータ | `:snake_case` | `/notes/:id` |
