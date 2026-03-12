---
title: 例
description: ノート機能から取られた実際のテンプレート例 — 基本レイアウト、リスト、詳細、共有フォーム。
---

# 例

これらはノート機能で使用されている実際のテンプレートで、注釈付きです。

## 基本レイアウト

基本レイアウトはサイト構造を定義します。すべてのページテンプレートはこれを拡張します:

```html
{# templates/layouts/base.html #}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{% block title %}App{% endblock %} | XjMVVM</title>
  <style>
    body { font-family: -apple-system, sans-serif; max-width: 800px;
           margin: 0 auto; padding: 20px; }
    /* ... */
  </style>
</head>
<body>
  <nav>
    <a href="/">Home</a>
    <a href="/notes">Notes</a>
  </nav>

  {# フラッシュメッセージは BaseViewModel.Render() によって自動的に注入されます #}
  {% if flash %}
  <div class="flash flash-{{ flash.type }}">{{ flash.message }}</div>
  {% endif %}

  <main>
    {% block content %}{% endblock %}
  </main>
</body>
</html>
```

`flash` 変数は 2 つのキーを持つ `Dictionary` です: `type` (`"success"`、`"error"`、`"info"`) と `message` (文字列)。自動的に注入されます — 任意の ViewModel は `SetFlash()` を呼び出でき、メッセージは次のレンダリングされたページに表示されます。

## ノートリスト

```html
{# templates/notes/list.html #}
{% extends "layouts/base.html" %}

{% block title %}Notes{% endblock %}

{% block content %}
<div style="display:flex; justify-content:space-between; align-items:center;">
  <h1>Notes</h1>
  <a href="/notes/new" class="btn btn-primary">New Note</a>
</div>

{% if notes %}
  {% for note in notes %}
  <div style="border:1px solid #ddd; padding:15px; margin:10px 0; border-radius:4px;">
    <h3 style="margin:0 0 8px">
      <a href="/notes/{{ note.id }}">{{ note.title }}</a>
    </h3>
    <p style="color:#666; margin:0 0 10px">{{ note.body }}</p>
    <small style="color:#999">Updated: {{ note.updated_at }}</small>
    <div style="margin-top:10px;">
      <a href="/notes/{{ note.id }}/edit" class="btn btn-sm">Edit</a>
      {# DELETE は HTML にないため POST フォームで削除 #}
      <form method="post" action="/notes/{{ note.id }}/delete"
            style="display:inline"
            onsubmit="return confirm('Delete this note?')">
        <button type="submit" class="btn btn-danger btn-sm">Delete</button>
      </form>
    </div>
  </div>
  {% endfor %}
{% else %}
  <p>No notes yet. <a href="/notes/new">Create your first note.</a></p>
{% endif %}
{% endblock %}
```

重要なポイント: `note.id`、`note.title`、`note.body`、`note.updated_at` は Dictionary キーです。delete アクションは `POST` フォームです。HTML フォームは GET と POST のみをサポートします — ブラウザフォームに HTTP DELETE はありません。

## 共有 create/edit フォーム

1 つのテンプレートは新規ノートフォームと編集フォームの両方を提供します。`note` 変数の存在がアクティブなモードを決定します:

```html
{# templates/notes/form.html #}
{% extends "layouts/base.html" %}

{% block title %}{% if note %}Edit Note{% else %}New Note{% endif %}{% endblock %}

{% block content %}
<h1>{% if note %}Edit Note{% else %}New Note{% endif %}</h1>

{# モードに基づいてフォームアクションと値をポピュレート #}
<form method="post" action="{% if note %}/notes/{{ note.id }}{% else %}/notes{% endif %}">
  <div>
    <label for="title">Title <span style="color:red">*</span></label>
    <input type="text" id="title" name="title"
           value="{{ note.title if note else '' }}"
           required>
  </div>
  <div>
    <label for="body">Body</label>
    <textarea id="body" name="body">{{ note.body if note else '' }}</textarea>
  </div>
  <button type="submit" class="btn btn-primary">
    {% if note %}Save Changes{% else %}Create Note{% endif %}
  </button>
  <a href="{% if note %}/notes/{{ note.id }}{% else %}/notes{% endif %}"
     class="btn">Cancel</a>
</form>
{% endblock %}
```

`NotesNewVM` は `note` キーを渡しません (または `Nil` を渡します) — フォームは create モードでレンダリングされます。`NotesEditVM` はロードされた `note` Dictionary を渡します — フォームは既存の値でプリポピュレートされます。

## ノート詳細

```html
{# templates/notes/detail.html #}
{% extends "layouts/base.html" %}

{% block title %}{{ note.title }}{% endblock %}

{% block content %}
<div style="display:flex; justify-content:space-between; align-items:center;">
  <h1>{{ note.title }}</h1>
  <div>
    <a href="/notes/{{ note.id }}/edit" class="btn">Edit</a>
    <form method="post" action="/notes/{{ note.id }}/delete"
          style="display:inline"
          onsubmit="return confirm('Delete this note?')">
      <button type="submit" class="btn btn-danger">Delete</button>
    </form>
  </div>
</div>

<div style="white-space:pre-wrap; margin:20px 0;">{{ note.body }}</div>
<small style="color:#999">
  Created: {{ note.created_at }} · Updated: {{ note.updated_at }}
</small>

<div style="margin-top:20px;">
  <a href="/notes">← Back to Notes</a>
</div>
{% endblock %}
```

`white-space:pre-wrap` は `\n` を `<br>` に変換する必要なくボディテキストの改行を保持します — プレーンテキストボディコンテンツに有用です。

## エラーページ

エラーテンプレートは ルーターの `Serve404()` と `Serve500()` メソッドによって `status_code` と `message` を渡されます:

```html
{# templates/errors/404.html #}
{% extends "layouts/base.html" %}
{% block title %}404 Not Found{% endblock %}
{% block content %}
<h1>404 — Page Not Found</h1>
<p>{{ message }}</p>
<a href="/">Go home</a>
{% endblock %}
```

エラーテンプレートはフラッシュメッセージについて心配する必要があります — ルーターによって直接レンダリングされます。任意の ViewModel が実行される前に。
