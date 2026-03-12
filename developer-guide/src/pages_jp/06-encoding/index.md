---
title: フォーム、MIME & UTF-8
description: HTML フォームデータの符号化方法、FormParser がそれをデコードする方法、UTF-8 パーセントエンコーディングが Xojo で正しく機能する方法。
---

# フォーム、MIME & UTF-8

## HTML フォームエンコーディング

ブラウザが `<form method="post">` を送信するとき、フィールド値をリクエストボディ内のバイト文字列として符号化します。エンコーディング形式はフォームの `enctype` 属性で指定されます。

このプロジェクトはデフォルトエンコーディングを処理します: `application/x-www-form-urlencoded`。

### エンコードされたボディはどのように見えるか

このフォームを考えます:

```html
<form method="post" action="/notes">
  <input name="title" value="Hello World">
  <textarea name="body">Line 1
Line 2</textarea>
</form>
```

サーバーに送信された POST ボディ:

```
title=Hello+World&body=Line+1%0ALine+2
```

規則:
- フィールドは `&` で分離
- キーと値は `=` で分離
- スペースは `+` になる
- 特殊文字は `%XX` になる。`XX` は 16 進バイト値
- マルチバイト文字 (タイ、絵文字、アクセント付き文字) は複数の `%XX` シーケンス — 1 つずつ UTF-8 バイト

### Xojo で POST ボディを読む

Xojo の `WebRequest.Body` は生のエンコードされた文字列を含みます。**一度** 読む必要があります。直後に。内部バッファは最初のアクセス後に再読み取り可能ではないかもしれないため。`BaseViewModel.Handle()` はキャッシュします:

```xojo
Sub Handle()
  // POST ボディを直後にキャッシュ — Request.Body は 1 回のみ読み取り可能かもしれません
  If Request.Method = "POST" Then
    mRawBody = Request.Body
  End If
  // ...
End Sub
```

## FormParser — それがどのように機能するか

`FormParser.Parse(body)` は生のエンコードされた文字列をキー → 値ペアの `Dictionary` に変換します。

完全な実装、注釈付き:

```xojo
Function Parse(body As String) As Dictionary
  Var result As New Dictionary()
  If body.Length = 0 Then Return result

  // & で分割して個々の key=value ペアを取得
  Var pairs() As String = body.Split("&")

  For i As Integer = 0 To pairs.Count - 1
    Var pair As String = pairs(i)

    // = セパレータを検索 (0-based インデックス)
    Var eqPos As Integer = pair.IndexOf("=")

    If eqPos >= 0 Then
      // キーと値をデコード
      Var key   As String = DecodeURIComponent(pair.Left(eqPos))
      Var value As String = DecodeURIComponent(pair.Middle(eqPos + 1))
      result.Value(key) = value
    ElseIf pair.Length > 0 Then
      // = を持たないキー (例: チェックボックスがチェックされていて値がない)
      result.Value(DecodeURIComponent(pair)) = ""
    End If
  Next

  Return result
End Function
```

!!! note "0-based 文字列インデックス"
    `pair.IndexOf("=")` は 0-based 位置を返します。`pair.Left(eqPos)` はキー (`=` の前のすべて) を抽出します。`pair.Middle(eqPos + 1)` は値を抽出します (`=` の後のすべて)。`Middle()` は 0-based で `IndexOf` に正しく整合します。決に `Mid()` を使用しないでください — それは `IndexOf` と組み合わせると間違った結果を与える従来の 1-based 関数です。

## DecodeURIComponent — UTF-8 トリック

これはプロジェクト内で最も重要なエンコーディング関数です。それを間違うとタイテキスト、絵文字、非 ASCII 入力をサイレントに破損させます。

### 間違ったアプローチ (マルチバイト文字を破損)

```xojo
// ❌ 間違い — Chr() は整数を Unicode コードポイントにマップします、生バイトではなく
If ch = "%" Then
  Var byte As Integer = Integer.FromHex(hex)
  result = result + Chr(byte)   // Chr(0xE0) = "à"、0xE0 バイトではない
End If
```

`Chr(0xE0)` は Unicode 文字 U+00E0 (`à`) を返し、これは 2 バイト UTF-8 シーケンス `0xC3 0xA0` です。しかし私たちが望んだのは単一バイト `0xE0`、それは 3 バイト タイ文字シーケンスのスタートバイトのようなもの `ก` (`0xE0 0xB8 0x81`) です。バイトごどのの 2 バイト対バイトの不一致はすべてのマルチバイト文字を破損させます。

### 正しいアプローチ (MemoryBlock + DefineEncoding)

```xojo
// ✅ 正解 — MemoryBlock で生バイトを収集し、UTF-8 としてデコード
Function DecodeURIComponent(encoded As String) As String
  // + → スペース (最初に発生する必要があります)
  Var s As String = encoded.ReplaceAll("+", " ")
  If s.Length = 0 Then Return ""

  Var mb As New MemoryBlock(s.Length)
  Var byteCount As Integer = 0
  Var i As Integer = 0

  While i < s.Length
    Var ch As String = s.Middle(i, 1)

    If ch = "%" And i + 2 < s.Length Then
      // パーセントエンコードバイト — 2 つの 16 進数字を抽出
      Var hex As String = s.Middle(i + 1, 2)
      Try
        mb.Byte(byteCount) = Integer.FromHex(hex)   // 生バイトを保存
        byteCount = byteCount + 1
        i = i + 3   // %XX を過ぎてスキップ
      Catch
        // 無効な 16 進 — % をリテラル文字として扱う
        mb.Byte(byteCount) = Asc(ch)
        byteCount = byteCount + 1
        i = i + 1
      End Try
    Else
      // リテラル文字 — そのバイト値を保存
      mb.Byte(byteCount) = Asc(ch)
      byteCount = byteCount + 1
      i = i + 1
    End If
  Wend

  // 収集バイトを UTF-8 文字列として解釈
  Var raw As String = mb.StringValue(0, byteCount)
  Return DefineEncoding(raw, Encodings.UTF8)
End Function
```

重要な洞察: すべての生バイトを `MemoryBlock` に最初に収集し、その後、最後に `DefineEncoding(..., Encodings.UTF8)` を 1 回呼び出します。これはマルチバイトシーケンスを正しく組み立てます。Xojo が文字列エンコーディングを解釈する前に。

## 文字列インデックス — Xojo 2025 で 0-based

Xojo 2025 文字列は完全に **0-based** な最新 API を使用します。従来の `Mid()` 関数は 1-based で、`IndexOf()` と一緒に決に使用してはいけません:

| メソッド | ベース | メモ |
|---|---|---|
| `String.IndexOf("x")` | **0-based** | 最初の文字に `0` を返す |
| `String.Middle(index, len)` | **0-based** | `IndexOf` と自然に整合 |
| `String.Left(n)` | count | インデックス無関係 — 常に安全 |
| `String.Right(n)` | count | インデックス無関係 — 常に安全 |
| `Mid(s, start, len)` | **1-based** | 従来の VB 関数 — 使用しないでください |

```xojo
Var pair As String = "title=Hello"
Var eqPos As Integer = pair.IndexOf("=")  // 5 を返す (0-based)

// ✅ 正解 — Middle() は 0-based
Var key   As String = pair.Left(eqPos)          // "title"
Var value As String = pair.Middle(eqPos + 1)    // "Hello"

// ❌ 間違い — Mid() は 1-based、1 つずれている
Var value As String = Mid(pair, eqPos + 1)      // "=Hello" (間違い!)
```

カウンターループも 0-based `Middle` を使用:

```xojo
Var i As Integer = 0
While i < s.Length
  Var ch As String = s.Middle(i, 1)   // 0-based
  i = i + 1
Wend
```

## MIME タイプと Content-Type

`Content-Type` はボディをどう解釈するかをブラウザ (とサーバー) に伝えます。最も関連のある 2 つのタイプ:

**リクエスト Content-Type** (ブラウザで設定):
- `application/x-www-form-urlencoded` — デフォルト HTML フォームエンコーディング
- `multipart/form-data` — ファイルアップロード用 (まだ実装されていません)
- `application/json` — JSON API リクエスト用

**レスポンス Content-Type** (ViewModel またはルーターで設定):
- `text/html; charset=utf-8` — すべてのレンダリングされたページレスポンス
- `application/json` — JSON API レスポンス用
- `text/css; charset=utf-8` — サーブされた CSS ファイル用
- `application/javascript; charset=utf-8` — サーブされた JS ファイル用

常にテキスト型に `; charset=utf-8` を含めます。それなしで、いくつかのブラウザは Latin-1 にデフォルトします。タイなど非 ASCII コンテンツを破損させます。

```xojo
// 常に Content-Type を明示的に設定
Response.Header("Content-Type") = "text/html; charset=utf-8"
Response.Write(html)
```

`BaseViewModel.Render()` はこれを自動的に設定します。生のレスポンス (エラーハンドラー、静的ファイル、JSON エンドポイント) を書き込むときのみ手動で設定する必要があります。

## クエリ文字列解析

URL クエリ文字列 (GET URL の `?key=val&key2=val2` 部分) はフォームボディと同じパーセントエンコーディング形式を使用します。`QueryParser.Parse()` は `FormParser.Parse()` と同じように処理します。

```xojo
// ViewModel で
Var sort As String = GetParam("sort")    // ?sort=asc を読む
Var page As String = GetParam("page")   // ?page=2 を読む
```

`GetParam()` はパスパラメータを最初にチェック、クエリ文字列にフォールバック — そのため `/notes/42?sort=asc` ルート `/notes/:id` で `GetParam("id") = "42"` と `GetParam("sort") = "asc"` を与えます。
