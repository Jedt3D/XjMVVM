---
title: ルーティングアーキテクチャ
description: HTTPリクエストがHandleURLを通過する方法、Xojoがいつ制御を奪うか、SSR世界とXojo WebPageコントロール間で安全に移動する方法。
---

# ルーティングアーキテクチャ

## 1つのアプリ内の2つの世界

Xojo Web 2アプリケーションは、根本的に異なる2つのリクエスト処理システムを同時にホストしています。すべてのHTTPリクエストは`HandleURL`を通り、その戻り値がどちらの世界がそれを処理するかを決定します。

| 世界 | エントリーポイント | レスポンス |
|-------|-------------|----------|
| **MVVM (SSR)** | `HandleURL` → Router → ViewModel → JinjaX | プレーンHTTP、ステートレスHTML |
| **Xojo WebPage** | ブートストラップHTML → WebSocket → Session → コントロール | ステートフル、イベント駆動UI |

- `Return True` — このアプリが処理しました。Xojoはそれ以上何もしません
- `Return False` — Xojoが処理します（ブートストラップHTML、JSフレームワークファイル、またはWebSocketメッセージを提供します）

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 40
#padding: 10
#lineWidth: 1.5
[Browser] -> [HandleURL: App.HandleURL]
[HandleURL: App.HandleURL] Return True -> [MVVM SSR]
[HandleURL: App.HandleURL] Return False -> [Xojo Framework]
[MVVM SSR] -> [ViewModel]
[ViewModel] HTML -> [Browser]
[Xojo Framework] -> [WebSocket Session]
[WebSocket Session] UI events -> [Browser]
-->
<!-- ascii
Browser
  │
  ▼
App.HandleURL
  ├─ Return True  →  MVVM SSR  →  ViewModel  →  HTML  →  Browser
  └─ Return False →  Xojo Framework  →  WebSocket Session  →  Browser
-->
<!-- /diagram -->

---

## HandleURL決定ツリー

`HandleURL` は、リクエストをディスパッチする前に、固定順序で検査を適用します。パスの正規化が最初です — すべての比較はこれに依存します。

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 32
#padding: 8
#lineWidth: 1.5
[Browser GET path] -> [Normalize path]
[Normalize path] -> [p = "/" AND _xojo=1?]
[p = "/" AND _xojo=1?] Yes -> [Return False: Xojo bootstrap]
[p = "/" AND _xojo=1?] No -> [p = "/tests"?]
[p = "/tests"?] Yes -> [302 redirect to /?_xojo=1]
[302 redirect to /?_xojo=1] -> [Return True]
[p = "/tests"?] No -> [Router.Route(...)]
[Router.Route(...)] matched -> [ViewModel handles request]
[ViewModel handles request] -> [Return True]
[Router.Route(...)] no match -> [Return False: Xojo serves file]
-->
<!-- ascii
Browser GET path
  │
  ▼
Normalize: prepend "/" if missing, strip trailing "/"
  │
  ├─ p = "/" AND QueryString = "_xojo=1"
  │     └── Return False  →  Xojo serves bootstrap HTML
  │
  ├─ p = "/tests"
  │     └── 302 redirect to /?_xojo=1  →  Return True
  │
  └─ all other paths
        └── Router.Route(...)
              ├─ matched  →  ViewModel.Handle()  →  Return True
              └─ no match →  Return False  →  Xojo serves JS/CSS/WebSocket
-->
<!-- /diagram -->

### `request.Path`の問題

!!! warning
    Xojo Web 2は`request.Path`から先頭の`/`を省略します。`/notes`へのリクエストは`request.Path = "notes"`として到着します。`"/notes"`ではなく。正規化がなければ、すべてのパス比較がサイレントに失敗します。

任意のパスチェック前に常に正規化してください：

```xojo
Var p As String = request.Path
If p.Left(1) <> "/" Then p = "/" + p
If p.Length > 1 And p.Right(1) = "/" Then p = p.Left(p.Length - 1)
```

これがないと、`"notes" <> "/notes"` がエラーなしで `True` と評価され、すべてのルートマッチがサイレントに失敗します。

---

## MVVMリクエストパイプライン

マッチされたSSRルートの場合、`HandleURL`からHTML応答までの完全なパイプライン：

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 28
#padding: 8
#lineWidth: 1.5
[HandleURL] normalize + match -> [Router]
[Router] factory.Invoke() -> [ViewModel]
[ViewModel] OnGet / OnPost -> [Model]
[<database> Model] Dictionary -> [ViewModel]
[ViewModel] context -> [JinjaX Template]
[JinjaX Template] HTML string -> [response.Write]
[response.Write] Return True -> [Browser]
-->
<!-- ascii
HandleURL  →  normalize path, match route
Router     →  factory.Invoke()  →  new ViewModel
 ViewModel  →  OnGet() / OnPost()
Model      →  returns Dictionary / Variant() of Dictionary
 ViewModel  →  builds context Dictionary
JinjaX     →  CompiledTemplate.Render(context)  →  HTML string
response.Write(html)  →  Return True  →  Browser
-->
<!-- /diagram -->

SSR ルートが `True` を返すため、Xojo はそれらに対して WebSocket セッションを確立しません。つまり、ViewModel から Xojo WebPage コントロール（`WebLabel`、`WebListBox` など）を使用することはできず、Server-Sent Events や JS ポーリングを別途追加しない限り、サーバーからブラウザへのリアルタイムプッシュも不可能です。

---

## `/tests`リダイレクトダンス

テストランナー（`XojoUnitTestPage`）はXojo WebPageです — ライブWebSocketセッションが必要です。MVVMリンクからそこに到達するには、3ステップのダンスが必要です。

### なぜ`/tests`で単に`Return False`できないのか

Xojoはその**ルートパス** `/`でのみブートストラップHTMLを提供します。他のパスの場合、`False`を返すと、MVVMの404テンプレートではなく、ブラウザエラーページのみが生成されます。

### なぜ `DefaultWindow=XojoUnitTestPage` はクラッシュするのか

プロジェクトで `DefaultWindow=XojoUnitTestPage` を設定すると、セッション接続時に Xojo がそれを最初の WebPage としてインスタンス化します。しかし `XojoUnitTestPage.Opening` はツールバーのセットアップとテスト登録を実行します — ページとセッションが完全に接続済みであることを前提とするコードです。ブートストラップ時点ではまだ接続されていません。結果：実行時クラッシュ。

### 実際に機能すること

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 32
#padding: 8
#lineWidth: 1.5
[Browser: GET /tests] -> [HandleURL]
[HandleURL] 302 /?_xojo=1 -> [Browser: follows redirect]
[Browser: follows redirect] -> [HandleURL: GET /?_xojo=1]
[HandleURL: GET /?_xojo=1] Return False -> [Xojo Bootstrap]
[Xojo Bootstrap] WebSocket established -> [Default: Shown event]
[Default: Shown event] testPage.Show() -> [XojoUnitTestPage]
[XojoUnitTestPage] Opening + Shown -> [Browser: Test Runner UI]
-->
<!-- ascii
Browser GET /tests
  │
HandleURL: 302 redirect to /?_xojo=1  →  Return True
  │
Browser follows redirect → GET /?_xojo=1
  │
HandleURL: Return False  (bypasses Router)
  │
Xojo serves bootstrap HTML → Xojo.js → WebSocket opens
  │
Session established → DefaultWindow = Default (empty WebPage)
  │
Default.Shown fires → New XojoUnitTestPage → testPage.Show()
  │
XojoUnitTestPage.Opening + Shown → test groups loaded ✓
  │
Browser: XojoUnit test runner UI (via WebSocket)
-->
<!-- /diagram -->

`Default` ページはシンプルな空の WebPage です。その `Shown` イベントはセッションが完全に確立された後に発火します — `XojoUnitTestPage` を表示するための最も早い安全なタイミングです:

```xojo
// Default.xojo_code — Shown event
Sub Shown()
  Var testPage As New XojoUnitTestPage
  testPage.Show()
End Sub
```

`XojoUnitTestPage` は `ImplicitInstance=False` であるため、`New XojoUnitTestPage` が必要です — `XojoUnitTestPage.Show()` を直接呼び出すとコンパイルエラーになります。

### なぜ `/?_xojo=1` で、単なる `/` ではないのか

`/` は MVVM 登録ルートです。ルーターがマッチして MVVM ホームページを提供し、`Return True` を返します — `Return False` に到達することはありません。`_xojo=1` クエリパラメータは、`HandleURL` に Router をスキップするよう指示するためのセンチネル値です。通常のブラウザが `/` を訪問するときは `_xojo=1` を送信しないため、ホームページには影響しません。

---

## リンクバック：Xojo WebPage → MVVM

Xojo WebPageからMVVMルートに戻ってナビゲートするには、`Session.GoToURL()`を使用します。これはブラウザレベルのナビゲーション指示を送信し、WebSocketセッション全体を完全に抜けます。

```xojo
// XojoUnitTestPage — WebToolbar Pressed event
Sub Pressed(item As WebToolbarButton)
  Select Case item.Caption
  Case "XjMVVM"
    Session.GoToURL("/")   // browser navigates to MVVM home
  End Select
End Sub
```

!!! warning
    `WebToolbar.Pressed` イベント内では、`Me` はページではなく `WebToolbar` 自体を指します。`Me.Session` は `WebToolbar` には存在しません。スレッドローカルグローバルの `Session` を直接使用してください。

### ナビゲーション API

| From | To | Method | Notes |
|------|----|--------|-------|
| MVVMテンプレート | MVVMルート | `<a href="/notes">` | 標準HTMLアンカー |
| MVVMテンプレート | Xojo WebPage | `<a href="/tests">` | リダイレクトダンスをトリガー |
| Xojo WebPage | MVVMルート | `Session.GoToURL("/")` | ブラウザレベルナビゲーション、WebSocketをドロップ |
| Xojo WebPage | Xojo WebPage | `page.Show()` | WebSocket内部、URL変更なし |

---

## ルーターはBooleanを返す

`Router.Route()`は`Sub`ではなく`Function As Boolean`です。MVVMルートがマッチしない場合（例：`/framework/Xojo.js`、`/websocket`）、`False`を返します。`HandleURL`がその`False`をXojoの独自のハンドラーに伝播し、ファイルを提供します。

```xojo
// HandleURL — simplified
Return mRouter.Route(request, response, session, mJinja)
// If no route matched → Router returns False → HandleURL returns False
// → Xojo serves Xojo.js, WebSocket frames, etc.
```

`Route()` が常に `True` を返した場合、Xojo 独自の JS・CSS ファイルはブロックされ、WebSocket セッションは確立されず、`/tests` フローは完全に破壊されます。

---

## ファイルリファレンス

| File | Role |
|------|------|
| `App.xojo_code` | `HandleURL` — パス正規化、`/tests`リダイレクト、`/?_xojo=1`パススルー、Routerディスパッチ |
| `Framework/Router.xojo_code` | ルート登録（`Get`、`Post`、`Any`）、パスマッチング（`ParsePath`）、ディスパッチ、エラーページ |
| `Default.xojo_code` | トランポリンWebPage — `Shown`イベントはセッションの準備完了後に`XojoUnitTestPage`をインスタンス化 |
| `mvvm.xojo_project` | `DefaultWindow=Default` — `XojoUnitTestPage`ではなく`Default`である必要があります |
| `XojoUnit/XojoUnitTestPage.xojo_code` | テストランナー。XjMVVMツールバーボタンは`Session.GoToURL("/")`を呼び出します |
