---
title: 概要
description: Xojo Web 2 で構築されたサーバーサイドレンダリング (SSR) MVVM Web フレームワーク (XjMVVM)。JinjaX テンプレートエンジンで動作します。
---

# 概要

これは **XjMVVM** (Xojo MVVM Web Framework) — Xojo Web 2 で構築されたサーバーサイドレンダリング (SSR) Web アプリケーションフレームワークです。Xojo の組み込み WebPage および WebControl GUI システムを使用する代わりに、すべての HTTP リクエストは `HandleURL` で傍受されて ViewModel にルーティングされ、**JinjaX テンプレートエンジン**を使用して HTML レスポンスがレンダリングされます。

アーキテクチャは意図的に **Flask** または **Django** に似ています — Python で SSR Web アプリケーションを構築した人なら誰でも使い慣れています。Flask を使用したことがない場合は、こう考えてください: ブラウザがページをリクエストすると、サーバーはコードを実行して HTML 文字列をビルドし、それを返します。JavaScript フレームワークはなく、レンダリング用の WebSocket もありません。シンプルなリクエスト/レスポンスです。

## リクエストのライフサイクル

すべてのリクエスト (URL に関係なく) は同じパイプラインを通ります。

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

このパイプラインの何も `WebPage`、`WebButton`、`WebTextField`、または他の Xojo Web コントロールを使用しません。プロジェクトファイルのデフォルト WebPage は Xojo のプロジェクト構造に必要なプレースホルダーです — 実際には提供されることはありません。

## アプリの実行

1. **Xojo 2025r3.1** で `mvvm.xojo_project` を開きます。
2. **Run** (⌘R) をクリックします。アプリは `http://localhost:8080` で起動します。
3. SQLite データベース `data/notes.sqlite` は初回起動時に自動的に作成されます。

CLI ビルドシステムはありません。すべてのテストとビルドは Xojo IDE 内で発生します。

## このガイドの内容

| セクション | 学習内容 |
|---|---|
| [なぜ MVVM?](concepts/index.html) | このデザイン背後にある建築的な決定とトレードオフ |
| [規約](conventions/index.html) | ディレクトリ構造、ファイル命名、メソッドとプロパティの命名 |
| [静的ファイル](static-files/index.html) | CSS、JS、画像をサーブする方法 |
| [テンプレート](templates/index.html) | JinjaX セットアップ、Jinja2 構文、実例、完全なタグリファレンス |
| [データベース](database/index.html) | SQLite パターン、Dictionary コントラクト、スレッドセーフティ |
| [エンコーディング](encoding/index.html) | フォーム解析、MIME タイプ、UTF-8 とパーセントエンコーディング |

## 現在のバージョン

**v0.3.0** — Unicode (タイ語、絵文字) でフルな CRUD が動作、フォーム検証、フラッシュメッセージ、404/500 エラーページ、POST/Redirect/GET パターン。フェーズ 3 (認証、複数のモデル) は次です。
