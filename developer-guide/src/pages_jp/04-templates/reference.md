---
title: タグ & フィルターリファレンス
description: JinjaX でサポートされるすべての Jinja2 タグとフィルターの完全なリファレンス (Xojo 固有のメモ付き)。
---

# タグ & フィルターリファレンス

## タグ

タグは `{% %}` デリミターを使用し、テンプレートロジックを制御します。すべての標準的な Jinja2 ブロックタグは JinjaX でサポートされています。

### `{% extends %}`

親テンプレートから継承します。ファイルの **最初** のタグである必要があります。

```html
{% extends "layouts/base.html" %}
```

テンプレートは 1 つの親のみを拡張できます。子テンプレートは `{% block %}` タグ内にのみコンテンツを定義できます。

### `{% block %}`

オーバーライド可能な領域を定義します。親では、デフォルトコンテンツを設定します。子では、置き換えます。

```html
{# 親 (base.html) で #}
{% block title %}Default Title{% endblock %}

{# 子で — オーバーライド #}
{% block title %}Notes List{% endblock %}
```

子ブロック内で `{{ super() }}` を呼び出して、親のコンテンツをインクルードします:

```html
{% block title %}{{ super() }} — Notes{% endblock %}
{# レンダリング: "Default Title — Notes" #}
```

### `{% include %}`

この時点で別のテンプレートを挿入します。含まれたファイルは現在のコンテキストを共有します。

```html
{% include "partials/pagination.html" %}
{% include "partials/nav.html" %}
```

`ignore missing` を使用すると、ファイルが存在しない場合はサイレントにスキップします:

```html
{% include "partials/optional.html" ignore missing %}
```

### `{% if %} / {% elif %} / {% else %} / {% endif %}`

条件付き出力。

```html
{% if user %}
  Hello, {{ user.name }}
{% elif guest %}
  Hello, guest
{% else %}
  Please log in
{% endif %}
```

サポートされるオペレータ: `==`、`!=`、`<`、`>`、`<=`、`>=`、`and`、`or`、`not`、`in`、`is`。

```html
{% if notes | length > 0 and is_admin %}
{% if note.title is not none %}
{% if "admin" in user.roles %}
```

### `{% for %} / {% else %} / {% endfor %}`

`Variant()` 配列を反復します。`{% else %}` ブロックはシーケンスが空のときレンダリングします。

```html
{% for note in notes %}
  <p>{{ note.title }}</p>
{% else %}
  <p>No notes.</p>
{% endfor %}
```

ブロック内で利用可能なループ変数:

| 変数 | 型 | 説明 |
|---|---|---|
| `loop.index` | Integer | 1-based イテレーションカウント |
| `loop.index0` | Integer | 0-based イテレーションカウント |
| `loop.first` | Boolean | 最初のイテレーションで True |
| `loop.last` | Boolean | 最後のイテレーションで True |
| `loop.length` | Integer | シーケンスの総アイテム数 |

### `{% set %}`

テンプレート内で変数を割り当てる:

```html
{% set count = notes | length %}
<p>{{ count }} note{{ "s" if count != 1 else "" }}</p>

{% set full_name = user.first_name + " " + user.last_name %}
```

### `{% macro %} / {% endmacro %}`

再利用可能なテンプレート関数を定義:

```html
{% macro render_note(note, show_edit=True) %}
  <div class="note">
    <h3>{{ note.title }}</h3>
    {% if show_edit %}
      <a href="/notes/{{ note.id }}/edit">Edit</a>
    {% endif %}
  </div>
{% endmacro %}

{# これを呼び出す: #}
{{ render_note(note) }}
{{ render_note(note, show_edit=False) }}
```

### `{% with %} / {% endwith %}`

ローカル変数を持つ一時的なスコープを作成:

```html
{% with error = "Title is required" %}
  <p class="error">{{ error }}</p>
{% endwith %}
```

### `{% raw %} / {% endraw %}`

Jinja2 構文をリテラルで出力 — JavaScript テンプレート文字列を含める場合に有用:

```html
{% raw %}
  <script>
    const template = `Hello {{ name }}`; // Jinja で処理されない
  </script>
{% endraw %}
```

### `{% comment %}` / `{# #}`

テンプレートコメント — ブラウザに送信されません:

```html
{# このコメントは出力から削除されます #}
```

---

## フィルター

フィルターは `|` pipe オペレータを使用して値を変換します。複数のフィルターをチェーンできます。

### 文字列フィルター

| フィルター | 例 | 出力 |
|---|---|---|
| `upper` | `{{ "hello" \| upper }}` | `HELLO` |
| `lower` | `{{ "HELLO" \| lower }}` | `hello` |
| `title` | `{{ "hello world" \| title }}` | `Hello World` |
| `capitalize` | `{{ "hello world" \| capitalize }}` | `Hello world` |
| `trim` | `{{ "  hi  " \| trim }}` | `hi` |
| `replace(a,b)` | `{{ "foo" \| replace("o","0") }}` | `f00` |
| `truncate(n)` | `{{ "long text" \| truncate(5) }}` | `lo...` |
| `wordcount` | `{{ "hi there" \| wordcount }}` | `2` |

### シーケンスフィルター

| フィルター | 例 | 結果 |
|---|---|---|
| `length` | `{{ notes \| length }}` | アイテム数 |
| `first` | `{{ notes \| first }}` | 最初のアイテム |
| `last` | `{{ notes \| last }}` | 最後のアイテム |
| `reverse` | `{% for n in notes \| reverse %}` | 逆順イテレーション |
| `sort` | `{% for n in notes \| sort(attribute="title") %}` | ソート済みイテレーション |
| `join(sep)` | `{{ tags \| join(", ") }}` | `"a, b, c"` |

### タイプ/セーフティフィルター

| フィルター | 説明 |
|---|---|
| `safe` | HTML を信頼できるものとしてマーク — 自動エスケープをバイパス。ユーザー入力では決に使用しないでください。 |
| `int` | 整数に変換 |
| `float` | 浮動小数点に変換 |
| `string` | 文字列に変換 |
| `default(val)` | 変数が定義されていないまたは空の場合 `val` を使用 |

### カスタムフィルター (このプロジェクト)

`App.Opening()` で `mJinja.RegisterFilter(name, AddressOf func)` でカスタムフィルターを登録します。

フィルター関数シグネチャ:

```xojo
Function MyFilter(value As Variant) As Variant
  // value を変換、結果を返す
End Function
```

---

## Xojo 固有の制約

これらは完全な Python Jinja2 との比較での制限です — サイレントエラーを避けるためにそれらを知りましょう。

**Dictionary のみのドット記法。** `{{ obj.key }}` は `obj` が `Dictionary` の場合にのみ機能します。カスタムクラスインスタンスはサポートされていません — それらのプロパティはテンプレートのドット記法でアクセスできません。

**オブジェクトのメソッド呼び出しはありません。** `{{ note.title.upper() }}` は機能しません。代わりにフィルターを使用: `{{ note.title | upper }}`。

**Python ビルトインはありません。** `range()`、`enumerate()`、`zip()` および同様の Python ビルトインは利用できません。テンプレートに渡す前に、ViewModel で必要なデータをビルドします。

**配列は `Variant()` である必要があります。** 配列を `Variant()` として渡す (型付き配列ではなく `String()` または `Integer()` のような)。JinjaX の `RenderFor` は `Variant()` を期待します。

**`Nil` はフォルシーです。** 値が `Nil` である Dictionary キーは `{% if %}` テストでフォルシーと評価されます。存在しないキーもフォルシーと評価されます (エラーではありません)。
