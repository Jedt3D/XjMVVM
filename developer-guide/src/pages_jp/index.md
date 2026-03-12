---
title: 導入
description: Xojo Web 2上に構築されたサーバーサイドレンダリング Xojo MVVM Webフレームワーク(XjMVVM)で、JinjaXテンプレートで駆動されています。
---

# 導入

これは**XjMVVM**(Xojo MVVM Web Framework)です — Xojo Web 2上に構築されたサーバーサイドレンダリング(SSR)Webアプリケーションフレームワークです。XojoのビルトインWebPageおよびWebControl GUIシステムを使用する代わりに、すべてのHTTPリクエストは`HandleURL`でインターセプトされてViewModelにルーティングされ、**JinjaXテンプレートエンジン**を使用してHTMLレスポンスをレンダリングします。

このアーキテクチャは意図的に**Flask**または**Django**と類似しています — Pythonでサーバーサイドレンダリング Webアプリを構築した経験のある人には馴染み深いものです。FlaskやDjangoを使用したことがない場合は、こう考えてください: ブラウザがページをリクエストすると、サーバーは何らかのコードを実行し、HTML文字列を構築し、それを送り返します。JavaScriptフレームワークなし、レンダリング用のWebSocketなし、ただきれいなリクエスト/レスポンスだけです。

## リクエストライフサイクル

すべてのリクエスト — URLに関係なく — は同じパイプラインを通ります:

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

このパイプラインには、`WebPage`、`WebButton`、`WebTextField`、またはその他のXojo Webコントロールは一切使用されません。プロジェクトファイル内のデフォルトWebPageはXojoのプロジェクト構造に必要なプレースホルダーです — 実際には提供されません。

## アプリを実行する

1. `mvvm.xojo_project`を**Xojo 2025r3.1**で開きます。
2. **Run**(⌘R)をクリックします。アプリは`http://localhost:8080`で起動します。
3. SQLiteデータベース`data/notes.sqlite`は初回起動時に自動的に作成されます。

CLIビルドシステムはありません。すべてのテストとビルドはXojo IDE内で行われます。

## このガイドの内容

| セクション | 学習する内容 |
|---|---|
| [なぜMVVM?](concepts/index.html) | このデザインの背後にあるアーキテクチャの決定とトレードオフ |
| [ルーティング](routing/index.html) | HandleURLの決定ツリー、`/tests`リダイレクトダンス、SSRとXojo WebPageの切り替え |
| [規約](conventions/index.html) | ディレクトリ構造、ファイル命名、メソッドとプロパティの命名規則 |
| [静的ファイル](static-files/index.html) | CSS、JS、画像を提供する方法 |
| [テンプレート](templates/index.html) | JinjaXセットアップ、Jinja2構文、実際の例、完全なタグリファレンス |
| [データベース](database/index.html) | SQLiteパターン、Dictionaryコントラクト、スレッドセーフティ |
| [DBレイヤーリファレンス](database/model-reference.html) | 3層アーキテクチャ(DBAdapter / BaseModel / NoteModel)、完全なCRUD API、トレードオフ |
| [タグと多対多](tags/index.html) | 2番目のリソース、結合テーブル、GetTagsForNote、SetTagsForNote |
| [認証システム](auth/index.html) | クッキーベース認証、HMAC署名クッキー、SHA-256 + ソルトパスワードハッシング、SSRセッション対応 |
| [JSON API と静的提供](api/index.html) | JSONSerializer、認証されたAPI ViewModel、201/401/422ステータスコード、ServeStaticパストラバーサルガード |
| [Alpine.js](alpine/index.html) | 最小限のクライアント側インタラクティビティ — ナビゲーション認証状態、フラッシュメッセージ、フォーム検証 |
| [保護されたルートとユーザースコーピング](protected-routes/index.html) | ルートガード(RequireLogin / RequireLoginJSON)、ユーザースコープされたノート、所有権の強制 |
| [エンコーディング](encoding/index.html) | フォーム解析、MIMEタイプ、UTF-8とパーセントエンコーディング |

## 現在のバージョン

**v0.9.3** — ユーザースコープされたノート(各ユーザーは自分のノートのみを表示)、クッキーベース認証(HMAC署名`mvvm_auth`クッキーが壊れたWebSession認証に置き換わる)、保護されたルート(すべての19ルートはログインが必要)、クライアント側のインタラクティビティのためのAlpine.js、認証付きJSON API、および開発者ドキュメント用の`/dist/*`でのビルトイン静的ファイルサーバー。