---
title: なぜ XjMVVM?
description: XjMVVM の背後にあるアーキテクチャ上の決定 — なぜ Xojo の WebPage システムを回避し、なぜ JinjaX を使用した MVVM パターンなのか。
---

# なぜ XjMVVM?

このページではフレームワーク設計の背後にある主要な意思決定を説明します。*なぜ*を理解することで、このガイド内の他のすべての規約が意味をなします。

## なぜ Xojo の WebPage システムを回避するのか?

Xojo Web 2 は完全な GUI ウィジェットシステムを提供します: `WebPage`、`WebButton`、`WebTextField`、`WebListBox` など。これらのコントロールは WebSocket を介して通信し、状態を自動的に管理します。Xojo のウィジェットモデルに密接に対応する単純な内部ツールの場合、うまく機能します。

このプロジェクトはそのシステムを完全に回避します。理由はこちらです:

**完全な HTML/CSS コントロール。** WebControl は独自の HTML を独自のクラス名と構造でレンダリングします。Tailwind のような CSS フレームワークを統合することなく、カスタムデザインシステムを簡単に適用することはできません。JinjaX テンプレートでは、HTML を自分で書きます — すべてのタグ、すべてのクラス、すべてのデータ属性はあなたのものです。

**標準的な HTTP セマンティクス。** WebControl ページはステートフル WebSocket セッションです。標準的な HTTP アプリのように動作しません: ブックマークは信頼できず、ブラウザ履歴は厄介で、REST API は追加するのが難しくなります。SSR アプローチは、すべての URL が適切な HTTP エンドポイントを意味します — 予測可能、キャッシュ可能、リンク可能。

**デザイナーフレンドリーなテンプレート。** HTML テンプレートは `templates/` フォルダに存在します。デザイナーやフロントエンド開発者は、完全な IDE サポート（構文ハイライト、Emmet、Prettier）を備えたテキストエディタを使って編集できます。Xojo コードに触れる必要は一切ありません。

**UI レイヤーにセッション状態がない。** Xojo WebControl は暗黙的なセッション状態を持ちます。ViewModel はリクエストごとにステートレスです — リクエストを受け取り、処理して、レスポンスを返します。唯一の永続的なコストは `Session`（`WebSession` クラス）とデータベースです。

## なぜ MVC ではなく MVVM?

クラシック MVC (Model-View-Controller) では、コントローラーはルーティングロジックとモデルのオーケストレーションの両方を担当します。Xojo では、これはすべてのルートを処理する 1 つの大きなコントローラークラスを意味します。

XjMVVM は MVVM を使用して、ルートごとのアーキテクチャの関心をより明確に分離します。

| レイヤー | クラス | 責任 |
|---|---|---|
| **View** | Jinja2 `.html` ファイル | プレゼンテーションのみ — ビジネスロジックはありません |
| **ViewModel** | ルートごとに 1 クラス | モデルをオーケストレート、テンプレートコンテキストをビルド |
| **Model** | データアクセスクラス | データベースクエリ、`Dictionary` オブジェクトを返す |

ルートごとに 1 つの ViewModel (例: `NotesListVM`、`NotesCreateVM`) は、各クラスを小さく焦点を絞った状態に保ちます。新しい機能を追加するには、既存のものを変更するのではなく、新しいファイルを追加します。

依存関係の方向は厳密に一方向です:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 40
#padding: 8
#lineWidth: 1.5
[View] -> [ViewModel]
[ViewModel] -> [Model]
[Model] SQL -> [<database> Database]
[<database> Database] rows -> [Model]
[Model] Dictionary -> [ViewModel]
[ViewModel] context -> [View]
-->
<!-- ascii
View  →  ViewModel  →  Model  →  Database
-->
<!-- /diagram -->

ViewModel はテンプレート名をビジネスロジックで参照しません。モデルは ViewModel を参照しません。これにより、各レイヤーは独立してテスト可能で置き換え可能になります。

## なぜ JinjaX?

JinjaX は Python の Jinja2 テンプレートエンジンの純粋な Xojo 実装です。選ばれた理由は次のとおりです:

**Jinja2 はデファクトスタンダードです。** Flask、Django、Ansible、または Saltstack に慣れた開発者は既に構文を知っています。学習曲線は最小限です。

**純粋な Xojo ソースです。** 完全な JinjaX ソースツリーは `JinjaXLib/` 配下に存在します。バイナリの `.xojo_library` 依存性がないため、Xojo のテキストプロジェクト形式（`.xojo_code` ファイル）で動作し、完全に検査・デバッグ可能です。

**セットアップ後はスレッドセーフです。** `JinjaEnvironment` は `App.Opening()` で 1 回初期化され、その後は読み取り専用です。各リクエストは新しい `CompiledTemplate` と `JinjaContext` を作成します — これらはリクエストごとのオブジェクトで、決して共有されません。

**テンプレート継承が機能します。** `{% extends %}`、`{% block %}`、および `{% include %}` を使用すると、ベースレイアウトを一度構築してすべてのページをそこから構成できます。

## Dictionary データコントラクト

これはシステム全体の最も重要な規則です。

JinjaX はドット記法（`{{ note.title }}`）をオブジェクトの `EvaluateGetAttr` を呼び出すことで解決します。Xojo では、`EvaluateGetAttr` は `Dictionary` に対してのみ実装されており、名前でキーを検索します。カスタム Xojo クラスインスタンスは `EvaluateGetAttr` をサポートしないため、ドットアクセスはサイレントに空文字列としてレンダリングされます。

**規則:** テンプレートに渡されるすべてのデータは `Dictionary` または `Variant()` の `Dictionary` オブジェクトの配列である必要があります。モデルは常にこれら 2 つのタイプのいずれかを返します — カスタムクラスインスタンスを返しません。

```xojo
// ✅ 正解 — Dictionary キーはテンプレートのドット記法で動作
Var row As New Dictionary()
row.Value("title") = rs.Column("title").StringValue
row.Value("body")  = rs.Column("body").StringValue
results.Add(row)   // Variant() Dictionary の配列

// ❌ 間違い — カスタムクラスインスタンス、ドットアクセスはテンプレートで失敗
Var note As New NoteClass()
note.Title = rs.Column("title").StringValue
results.Add(note)  // {{ note.title }} は空の文字列としてレンダリング
```

テンプレートでは、配列は `Dictionary` オブジェクトを含む `Variant()` である必要があります:

```html
{% for note in notes %}
  <h2>{{ note.title }}</h2>   {# works — Dictionary key lookup #}
  <p>{{ note.body }}</p>
{% endfor %}
```

## Post/Redirect/Get

すべてのフォーム送信は **Post/Redirect/Get (PRG)** パターンに従います:

1. ブラウザがフォームを送信 → `POST /notes` (`NotesCreateVM` で処理)
2. ViewModel は検証とノートの作成を行う
3. ViewModel は `Redirect("/notes")` を呼び出す — HTTP 302
4. ブラウザはリダイレクトに従う → `GET /notes` (`NotesListVM` で処理)
5. ブラウザはリストページをレンダリング

これにより、ブラウザがリロードでフォームを再送信することを防ぎます ("このページをリロードしますか?" ダイアログ)。また、ユーザーが見るすべてのページが GET リクエストで作成されたことを意味します — ブラウザ履歴、ブックマーク、戻るボタンはすべて正しく機能します。

検証が失敗した場合、ViewModel はリダイレクト**しません** — 同じ GET テンプレートを使用してエラーメッセージとともにフォームを再レンダリングします:

```xojo
// 検証失敗 — 再レンダリング、リダイレクトなし
If title.Trim = "" Then
  SetFlash("Title is required", "error")
  Redirect("/notes/new")
  Return
End If
```

## セッション分離

`App` は共有シングルトン — すべてのユーザーのリクエストは同じ `App` インスタンスで実行されます。`App` プロパティにユーザー固有のデータを保存しないでください。

ユーザーごとの状態は `Session` クラス（`WebSession` を継承）にあります。各ブラウザセッションは、Xojo のランタイムによって自動的に独自の `Session` インスタンスを取得します:

```
App.mRouter      → 共有、Opening() 後読み取り専用  ✅ 安全
App.mJinja       → 共有、Opening() 後読み取り専用  ✅ 安全
Session.userID   → ユーザーごと、ブラウザごとに 1 インスタンス  ✅ 安全
App.currentUser  → すべてのユーザーで共有             ❌ 決してしないでください
```
