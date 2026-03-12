---
title: はじめに
description: Xojo Web 2上に構築されたサーバーサイドレンダリング（SSR）Xojo MVVMフレームワーク（XjMVVM）。JinjaXテンプレートエンジンを使用しています。
---

# はじめに

これは **XjMVVM** （Xojo MVVM Web Framework） — Xojo Web 2上に構築されたサーバーサイドレンダリング（SSR）Webアプリケーションフレームワークです。Xojoの組み込みWebPageおよびWebControl GUIシステムを使用する代わりに、すべてのHTTPリクエストは `HandleURL` で傍受され、ViewModel にルーティングされ、**JinjaX テンプレートエンジン**を使用してHTML応答をレンダリングします。

このアーキテクチャは意図的に **Flask** または **Django** に似ています — PythonでSSRウェブアプリを構築したことのある人ならば、誰もが馴染みがあります。Flaskを使用したことがない場合は、このように考えてください。ブラウザがページをリクエストし、サーバーがコードを実行し、HTML文字列を作成して戻します。JavaScriptフレームワークもなく、レンダリング用のWebSocketもなく、クリーンなリクエスト/レスポンスだけです。

## リクエストのライフサイクル

すべてのリクエスト（URLに関係なく）は、同じパイプラインを通過します：

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 8
#lineWidth: 1.5
[Browser] HTTP Request -> [HandleURL: WebApplication.HandleURL]
[HandleURL: WebApplication.HandleURL] -> [Router]
[Router] -> [ViewModel: ViewModel.Handle]
[ViewModel: ViewModel.Handle] queries -> [<database> Model]
[<database> Model] Dictionary -> [ViewModel: ViewModel.Handle]
[ViewModel: ViewModel.Handle] -> [Render: JinjaX.CompiledTemplate.Render]
[Render: JinjaX.CompiledTemplate.Render] HTML -> [Browser]
-->
<!-- ascii
Browser
  │  HTTP Request  (GET /notes  or  POST /notes/42)
  ▼
WebApplication.HandleURL
  │  Returns True (takes ownership of all requests)
  ▼
Router
  │  Matches path pattern → selects ViewModel
  │  Extracts URL params  (e.g. /notes/:id → id = "42")
  ▼
 ViewModel.Handle()
  │  Dispatches to OnGet() or OnPost()
  ▼
Model  (database queries)
  │  Returns Dictionary / Variant() of Dictionary
  ▼
 ViewModel builds context Dictionary
  │  { "notes": [...], "flash": {...}, "page_title": "Notes" }
  ▼
JinjaX.CompiledTemplate.Render(context) → HTML string
  │  Template: templates/notes/list.html
  ▼
WebResponse.Write(html)
  ▼
Browser renders the page
-->
<!-- /diagram -->

このパイプラインでは、`WebPage`、`WebButton`、`WebTextField`、またはその他のXojoウェブコントロールは使用されていません。プロジェクトファイルの`Default` WebPageは、Xojoのプロジェクト構造のために必要なプレースホルダーですが、実際には提供されることはありません。

## アプリの実行

1. **Xojo 2025r3.1** で`mvvm.xojo_project`を開きます。
2. **Run** （⌘R）をクリックします。アプリは`http://localhost:8080`で起動します。
3. SQLiteデータベース`data/notes.sqlite`は初回起動時に自動的に作成されます。

CLIビルドシステムはありません。すべてのテストとビルドはXojo IDE内で行われます。

## このガイドの内容

| セクション | 学べること |
|---|---|
| [MVVMが必要な理由？](concepts/index.html) | このデザインの背後にある建築上の決定とトレードオフ |
| [ルーティング](routing/index.html) | HandleURL決定ツリー、`/tests`リダイレクトダンス、SSRとXojo WebPageの間のクロス |
| [規約](conventions/index.html) | ディレクトリ構造、ファイル命名、メソッドとプロパティの命名 |
| [静的ファイル](static-files/index.html) | CSS、JS、画像の提供方法 |
| [テンプレート](templates/index.html) | JinjaXセットアップ、Jinja2構文、実例、完全なタグリファレンス |
| [データベース](database/index.html) | SQLiteパターン、Dictionaryコントラクト、スレッド安全性 |
| [DBレイヤーリファレンス](database/model-reference.html) | 3層アーキテクチャ（DBAdapter / BaseModel / NoteModel）、完全なCRUD API、トレードオフ |
| [タグと多対多](tags/index.html) | 2番目のリソース、結合テーブル、GetTagsForNote、SetTagsForNote |
| [認証システム](auth/index.html) | UserModel、SHA-256 + ソルトパスワードハッシング、Session、RequireLoginガード |
| [JSON API と静的提供](api/index.html) | JSONSerializer、API ViewModel、201/422ステータスコード、ServeStaticパストラバーサルガード |
| [エンコーディング](encoding/index.html) | フォーム解析、MIMEタイプ、UTF-8およびパーセントエンコーディング |

## 現在のバージョン

**v0.9.0** — JSON APIレイヤー、認証（SHA-256 + ソルト、セッションログイン/ログアウト）、多対多note_tagsを持つTagsリソース、および`/dist/*`の開発者ドキュメント用の組み込み静的ファイルサーバー。本番パス修正（v0.4.2）により、DB とテンプレートは、すべての環境で実行可能ファイルに相対的に解決されることが保証されます。
