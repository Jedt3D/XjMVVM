---
title: 使用ガイド
description: Jinja2 テンプレート構文の使用方法 — 変数、ブロック、ループ、条件、フィルター、テンプレート継承。
---

# 使用ガイド

## テンプレート継承

すべてのページテンプレートは基本レイアウトを拡張することで開始します:

```html
{# templates/notes/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Notes{% endblock %}

{% block content %}
  <h1>All Notes</h1>
  {# ページコンテンツはここへ #}
{% endblock %}
```

基本レイアウトは、子テンプレートが埋める名前付きブロックを定義します:

```html
{# templates/layouts/base.html #}
<!DOCTYPE html>
<html>
<head>
  <title>{% block title %}App{% endblock %} | XjMVVM</title>
</head>
<body>
  <nav>...</nav>

  {% if flash %}
  <div class="flash flash-{{ flash.type }}">{{ flash.message }}</div>
  {% endif %}

  <main>
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

子テンプレートは、親で定義されているブロックのみをオーバーライドできます。子テンプレートの `{% block %}` タグの外のコンテンツは無視されます。

## 変数

二重波括弧で変数を出力します。HTML は自動的にエスケープされます — `<script>` は `&lt;script&gt;` になります:

```html
{{ note.title }}
{{ note.created_at }}
{{ page_title }}
```

変数は `Render()` に渡すコンテキスト `Dictionary` から来ます。Dictionary キーはテンプレートの変数名になります。

### Dictionary ドット記法

JinjaX は `{{ note.title }}` をオブジェクトで `note.Value("title")` を呼び出すことで解決します。これはすべてのデータが `Dictionary` オブジェクトである必要があるコア理由です — `Dictionary` のみが `EvaluateGetAttr` を介したドット記法ルックアップをサポートします。

### 生出力 (エスケープなし)

事前にレンダリングされた HTML (信頼できるコンテンツのみ) を出力する必要がある場合:

```html
{{ content | safe }}
```

ユーザー提供のコンテンツで `| safe` を使用しないでください。

## 条件

```html
{% if note %}
  <h1>Edit: {{ note.title }}</h1>
{% elif draft %}
  <h1>Draft</h1>
{% else %}
  <h1>New Note</h1>
{% endif %}
```

Jinja2 の偽値（falsy）: `False`、`0`、`""` （空文字列）、`[]` （空配列）、`None`/`Nil`。存在しないキーも偽値として扱われます。

## ループ

`Variant()` の `Dictionary` オブジェクト配列を反復:

```html
{% for note in notes %}
  <div class="note">
    <h2>{{ note.title }}</h2>
    <p>{{ note.body }}</p>
    <time>{{ note.updated_at }}</time>
  </div>
{% else %}
  <p>No notes yet. <a href="/notes/new">Create one.</a></p>
{% endfor %}
```

`{% else %}` ブロックは配列が空のときにレンダリングされます。

### ループ変数

`{% for %}` ブロック内では、特別な `loop` 変数が利用可能です:

| 変数 | 値 |
|---|---|
| `loop.index` | 現在のイテレーション、1-based |
| `loop.index0` | 現在のイテレーション、0-based |
| `loop.first` | 最初のイテレーションで `True` |
| `loop.last` | 最後のイテレーションで `True` |
| `loop.length` | アイテムの総数 |

```html
{% for note in notes %}
  {% if loop.first %}<ul>{% endif %}
  <li class="{% if loop.last %}last{% endif %}">
    {{ loop.index }}. {{ note.title }}
  </li>
  {% if loop.last %}</ul>{% endif %}
{% endfor %}
```

## フィルター

フィルターはパイプ `|` 演算子を使用して値を変換します:

```html
{{ note.title | upper }}
{{ note.title | lower }}
{{ note.body  | truncate(100) }}
{{ notes      | length }}
{{ note.title | default("Untitled") }}
{{ note.title | replace("foo", "bar") }}
```

フィルターをチェーンできます:

```html
{{ note.title | upper | truncate(50) }}
```

## テンプレート インクルード

部分テンプレートをインクルードします:

```html
{% include "partials/pagination.html" %}
```

含まれるテンプレートは親と同じコンテキストを共有します — 同じすべての変数にアクセスできます。

## コメント

テンプレートコメントはブラウザに送信されません:

```html
{# このコメントは出力から削除されます #}
```

HTML コメントはブラウザに送信されます:

```html
<!-- このコメントはページソースに表示されます -->
```

## 空白制御

`-` を使用してタグの周囲の空白を削除:

```html
{%- for note in notes -%}
  {{ note.title }}
{%- endfor -%}
```

テンプレートから JSON や CSV を生成する場合に有用です。

## ViewModel からコンテキストを渡す

コンテキスト `Dictionary` のすべてのものはテンプレート変数になります:

```xojo
Sub OnGet()
  Var ctx As New Dictionary()
  ctx.Value("notes")      = NoteModel.GetAll()   // Variant() of Dictionary
  ctx.Value("page_title") = "All Notes"
  ctx.Value("is_admin")   = False
  Render("notes/list.html", ctx)
End Sub
```

テンプレートで:

```html
<title>{{ page_title }}</title>
{% if is_admin %}<a href="/admin">Admin</a>{% endif %}
{% for note in notes %}...{% endfor %}
```

フラッシュメッセージは `BaseViewModel.Render()` によって自動的に注入されます — 手動でコンテキストに追加する必要はありません。
