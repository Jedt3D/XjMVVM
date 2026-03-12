---
title: "Alpine.js"
description: XjMVVMがクライアント側の最小限のインタラクティビティにAlpine.jsをどのように、そしてなぜ使うのか、また平易なHTMLやhtmxと比較した場合の使い分けについて。
---

# Alpine.js

XjMVVM はサーバーレンダリングフレームワークです — HTML は JS フレームワークではなく Xojo から生成されます。Alpine.js は、サーバーが状態を管理できない小さなギャップを埋めます。つまり、ブラウザのローカル状態（localStorage、sessionStorage）に応答してページ全体をリロードせず動作する必要があるリアクティブな UI 要素です。

## 設計思想

> **サーバーが描画する。Alpine が反応する。htmx がフェッチする。**

目標は可能な限り最小限のJavaScriptを使用することです。すべてのインタラクティブ要素の判断フローは以下のとおりです:

1. **平易なHTMLフォーム + PRGパターンで処理できるか?** → それを使う、JSは不要
2. **ブラウザのローカル状態に応答するか、インラインDOM更新が必要か?** → Alpine を使う
3. **サーバーからフェッチしてページの一部を更新する必要があるか?** → htmx を使う([htmx導入計画](#when-to-reach-for-htmx)を参照)

Alpineは決してサーバー側ロジックの置き換えとして使用されません。サーバーで実行できるすべてのビジネスルール、データ、検証はサーバーに留まります。

---

## インストール

Alpine はビルドステップなしで CDN から読み込まれます。`layouts/base.html` の `</body>` の前に 1 行追加します:

```html
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>
```

`defer`属性は必須です — AlpineはDOMが解析された後に処理する必要があります。

!!! note
    `@3` ではなく特定のバージョン（例: `@3.14.3`）に固定してください。ビルドが再現可能になり、アップストリームの CDN 更新がアプリを破壊することを防げます。

---

## XjMVVMで使用されるコアディレクティブ

| ディレクティブ | 目的 |
|---|---|
| `x-data="{ ... }"` | リアクティブ状態を持つコンポーネントを宣言する |
| `x-show="expr"` | ブール式に基づいて`display:none`を切り替える |
| `x-text="expr"` | 要素のテキストコンテンツを式の値に設定する |
| `:class="expr"` | `class`属性を動的にバインドする |
| `@submit.prevent="fn"` | フォーム送信を傍受し、デフォルトを防ぎ、関数を呼び出す |
| `@submit="expr"` | デフォルトを防がずにフォーム送信時に式を実行する |
| `x-cloak` | Alpineが初期化されるまで要素を非表示にする(FOUCを防ぐ) |
| `init()` | ライフサイクルフック — コンポーネント初期化時に1回実行される |

---

## パターン1 — ナビゲーション認証状態

ナビゲーションバーは、`localStorage` で制御される「ログイン/サインアップ」（ログアウト状態）または「ユーザー名 + ログアウト」（ログイン状態）を表示する必要があります。Xojo Web 2 SSR モードは通常の HTTP リクエスト間で `WebSession` 状態を保持しないため、サーバーはこれを注入できません。

```html
<nav x-data="{ user: localStorage.getItem('_auth_user') }">

  <!-- ログアウト状態: デフォルトで表示、ユーザーが設定されている場合はAlpineで非表示 -->
  <span class="nav-auth" x-show="!user">
    <a href="/login" class="btn btn-sm">Log In</a>
    <a href="/signup" class="btn btn-primary btn-sm">Sign Up</a>
  </span>

  <!-- ログイン状態: x-cloakで非表示、Alpineがユーザーの存在を確認するまで隠れたまま -->
  <span class="nav-auth" x-show="user" x-cloak>
    <span x-text="user" style="font-size:0.9em; color:#555;"></span>
    <form method="post" action="/logout"
          @submit="localStorage.removeItem('_auth_user');
                   sessionStorage.setItem('_flash_msg', 'You have been logged out.');
                   sessionStorage.setItem('_flash_type', 'success');">
      <button type="submit" class="btn btn-sm">Log Out</button>
    </form>
  </span>

</nav>
```

ログイン状態の span の `x-cloak` は、Alpine が初期化される前に両方の状態がフラッシュするのを防ぎます。これを機能させるために必要な CSS ルールをスタイルシートに含めてください:

```css
[x-cloak] { display: none !important; }
```

ログアウトフォームの`@submit`は、POSTが送信される前にlocalStorageをクリアし、フラッシュメッセージをキューイングします。別のイベントリスナーやスクリプトブロックは不要です。

---

## パターン2 — クライアント側フラッシュメッセージ

POST → リダイレクト → GET サイクルのフラッシュメッセージは、SSR モードでは Xojo のセッションを使用できません — リダイレクト後の GET が到着するまでにセッションは失われています。回避策: フォーム送信前に `sessionStorage` に書き込み、次のページロード時に読み取ります。

Alpineは`init()`でキューイングされたメッセージを読み取って表示し、表示するものがない場合は`x-show`で非表示に保ちます:

```html
<div x-data="{
  msg: '',
  type: 'success',
  init() {
    var m = sessionStorage.getItem('_flash_msg');
    var t = sessionStorage.getItem('_flash_type') || 'success';
    sessionStorage.removeItem('_flash_msg');
    sessionStorage.removeItem('_flash_type');
    if (m && !document.querySelector('.flash')) { this.msg = m; this.type = t; }
  }
}" x-show="msg" :class="'flash flash-' + type" x-text="msg" style="display:none"></div>
```

`!document.querySelector('.flash')` ガードは、Xojo サーバー側セッションがフラッシュを直接配信する場合（WebSocket モード対応）のダブルフラッシュを防ぎます。

---

## パターン3 — 非同期前処理によるフォーム送信

認証フォームは、POST が送信される前に Web Crypto API を使用してクライアント側でパスワードをハッシュする必要があります。これは本質的に非同期であり、送信イベントをインターセプトする必要があります。Alpine の `@submit.prevent` + `x-data` の非同期メソッドはこれを簡潔に処理し、別途 `addEventListener` スクリプトブロックは不要です。

SHA-256 ヘルパーはフォームの上にある小さな `<script>` で定義されます（Alpine メソッドが実行されるときにスコープ内にある必要があります）:

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2,'0')).join('');
}
</script>

<form method="post" action="/login"
      x-data="{
        hashed: false,
        async handleSubmit(e) {
          if (this.hashed) return;
          const pwEl = document.getElementById('password');
          pwEl.value = await sha256hex(pwEl.value);
          localStorage.setItem('_auth_user', document.getElementById('username').value);
          sessionStorage.setItem('_flash_msg', 'Welcome back!');
          sessionStorage.setItem('_flash_type', 'success');
          this.hashed = true;
          e.target.submit();
        }
      }"
      @submit.prevent="handleSubmit($event)">
  ...
</form>
```

`hashed` フラグは、`e.target.submit()` が何らかの理由でイベントを再発火させた場合の二重処理を防ぎます。`e.target.submit()`（DOM メソッド）は `submit` イベントを完全にバイパスするため、このフラグは主に安全ガードとして機能します。

### インライン検証の追加

サインアップフォームはパスワード検証を追加します。`pwError`状態は、追加のDOM配線なしでインラインエラー段落を駆動します:

```html
<p x-show="pwError" x-text="pwError"
   style="display:none; color:#721c24; background:#f8d7da;
          padding:8px 12px; border-radius:4px; margin:0 0 12px;"></p>
```

`handleSubmit`内:

```javascript
if (pw.length < 6) { this.pwError = 'Password must be at least 6 characters.'; return; }
if (pw !== cf)     { this.pwError = 'Passwords do not match.'; return; }
this.pwError = '';
```

`document.getElementById`なし、手動の`style.display`切り替えなし。Alpineが要素を同期させたままにします。

---

## パターン4 — 複数値チェックボックス(Alpineは不要)

ノートフォームのタグチェックボックスは、以前はチェック済みの値を非表示フィールドに集約するための JS が必要でした。しかしこれは不要です — ネイティブ HTML フォームのシリアライゼーションは、同じ `name` を持つすべてのチェック済みチェックボックスを複数の値として送信します。Xojo の `FormParser` はすでに重複キーのカンマ追加を処理しています。

正しいパターンは**JavaScriptを全く必要としません**:

```html
{% for tag in all_tags %}
<input type="checkbox" name="tag_ids" value="{{ tag.id }}"
       {% if tag.selected == "1" %}checked{% endif %}>
{{ tag.name }}
{% endfor %}
```

フォームは`tag_ids=1&tag_ids=3`を送信し、FormParserは`"1,3"`を格納し、ViewModelは前のように`","`で分割します。非表示フィールドなし、スクリプトブロックなし。

!!! tip
    Alpine（または任意の JS）を導入する前に、ブラウザのネイティブフォームシリアライゼーションがすでに必要なことをやっているか確認してください。複数チェックボックス、ラジオグループ、`<select multiple>` はすべて JavaScript なしで機能します。

---

## JSフットプリント比較

| 何 | Alpine前 | Alpine後 |
|---|---|---|
| base.html IIFE | 30行 | 0(`x-data`属性で置き換え) |
| login.html `<script>` | 19行 | 8(sha256hexヘルパーのみ) |
| signup.html `<script>` | 35行 | 8(sha256hexヘルパーのみ) |
| notes/form.html `<script>` | 9行 | 0(完全に削除) |
| **カスタムJS合計** | **93行** | **16行** |
| Alpine CDN | 0 | 14 KB(縮小化 + gzip: ~5 KB) |

削減不可能な 16 行は SHA-256 ヘルパー関数です（ログインとサインアップで重複）。ビルドステップなしで共有ファイルに移動することはできません — ビルドツールをゼロに保つための意図的なトレードオフです。

---

## htmxに手を出すべき場合

Alpine は**ローカルブラウザ状態**を管理します。インタラクションがサーバーからのフェッチとページの一部の更新を必要とする場合は、Alpine を拡張するのではなく htmx を追加してください。

htmx の追加が正当化される機能の例:

- インライン編集(ノートをクリック → フォームがインプレイスで表示され、リロードなしで保存)
- リロードなしで削除(リストから行を削除)
- ライブ検索/フィルタリング(入力時にノートまたはタグを更新)
- ページネーション(リロードなし)
- リストビューのタグ切り替え

htmx と Alpine はきれいに組み合わせられます — Alpine はローカル状態を担当し、htmx はサーバーのラウンドトリップを担当します。2 つのライブラリは競合しません。

---

## Alpineが決して置き換えることができないもの

| JS | 理由 |
|---|---|
| `crypto.subtle.digest`(SHA-256) | ブラウザセキュリティAPI、Alpine相当物なし |
| `localStorage` / `sessionStorage` の読み書き | 引き続き必要です。Alpine は単に `x-data` 内で整理するだけです |
| サーバー側セッション永続性 | アーキテクチャ上の要件 — クッキーベース認証が必要であり、Alpine とは無関係 |