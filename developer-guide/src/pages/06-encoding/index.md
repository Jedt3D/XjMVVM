---
title: Forms, MIME & UTF-8
description: How HTML form data is encoded, how FormParser decodes it, and how UTF-8 percent-encoding works correctly in Xojo.
---

# Forms, MIME & UTF-8

## HTML form encoding

When a browser submits a `<form method="post">`, it encodes the field values as a byte string in the request body. The encoding format is specified by the form's `enctype` attribute.

This project handles the default encoding: `application/x-www-form-urlencoded`.

### What the encoded body looks like

Given this form:

```html
<form method="post" action="/notes">
  <input name="title" value="Hello World">
  <textarea name="body">Line 1
Line 2</textarea>
</form>
```

The POST body sent to the server is:

```
title=Hello+World&body=Line+1%0ALine+2
```

The rules:
- Fields are separated by `&`
- Key and value are separated by `=`
- Spaces become `+`
- Special characters become `%XX` where `XX` is the hex byte value
- Multi-byte characters (Thai, emoji, accented letters) become multiple `%XX` sequences — one per UTF-8 byte

### Reading the POST body in Xojo

Xojo's `WebRequest.Body` contains the raw encoded string. It must be read **once**, immediately, because the internal buffer may not be re-readable after the first access. `BaseViewModel.Handle()` caches it:

```xojo
Sub Handle()
  // Cache POST body immediately — Request.Body may only be readable once
  If Request.Method = "POST" Then
    mRawBody = Request.Body
  End If
  // ...
End Sub
```

## FormParser — how it works

`FormParser.Parse(body)` converts the raw encoded string into a `Dictionary` of key → value pairs.

The full implementation, annotated:

```xojo
Function Parse(body As String) As Dictionary
  Var result As New Dictionary()
  If body.Length = 0 Then Return result

  // Split on & to get individual key=value pairs
  Var pairs() As String = body.Split("&")

  For i As Integer = 0 To pairs.Count - 1
    Var pair As String = pairs(i)

    // Find the = separator (0-based index)
    Var eqPos As Integer = pair.IndexOf("=")

    If eqPos >= 0 Then
      // Decode both key and value
      Var key   As String = DecodeURIComponent(pair.Left(eqPos))
      Var value As String = DecodeURIComponent(pair.Middle(eqPos + 1))
      result.Value(key) = value
    ElseIf pair.Length > 0 Then
      // Key with no = (e.g. a checkbox that's checked with no value)
      result.Value(DecodeURIComponent(pair)) = ""
    End If
  Next

  Return result
End Function
```

!!! note "0-based string indexing"
    `pair.IndexOf("=")` returns a 0-based position. `pair.Left(eqPos)` extracts the key (everything before `=`). `pair.Middle(eqPos + 1)` extracts the value (everything after `=`). `Middle()` is 0-based and aligns correctly with `IndexOf`. Never use `Mid()` — it is a legacy 1-based function that gives wrong results when combined with `IndexOf`.

## DecodeURIComponent — the UTF-8 trick

This is the most important encoding function in the project. Getting it wrong silently corrupts Thai text, emoji, and any non-ASCII input.

### The wrong approach (corrupts multi-byte characters)

```xojo
// ❌ WRONG — Chr() maps integers to Unicode code points, not raw bytes
If ch = "%" Then
  Var byte As Integer = Integer.FromHex(hex)
  result = result + Chr(byte)   // Chr(0xE0) = "à", not the byte 0xE0
End If
```

`Chr(0xE0)` returns the Unicode character U+00E0 (`à`), which is a two-byte UTF-8 sequence `0xC3 0xA0`. But we wanted the single byte `0xE0`, which is the start byte of a three-byte Thai character sequence like `ก` (`0xE0 0xB8 0x81`). The two-byte-per-byte mismatch corrupts every multi-byte character.

### The correct approach (MemoryBlock + DefineEncoding)

```xojo
// ✅ CORRECT — collect raw bytes in MemoryBlock, then decode as UTF-8
Function DecodeURIComponent(encoded As String) As String
  // + → space (must happen first)
  Var s As String = encoded.ReplaceAll("+", " ")
  If s.Length = 0 Then Return ""

  Var mb As New MemoryBlock(s.Length)
  Var byteCount As Integer = 0
  Var i As Integer = 0

  While i < s.Length
    Var ch As String = s.Middle(i, 1)

    If ch = "%" And i + 2 < s.Length Then
      // Percent-encoded byte — extract the two hex digits
      Var hex As String = s.Middle(i + 1, 2)
      Try
        mb.Byte(byteCount) = Integer.FromHex(hex)   // store the raw byte
        byteCount = byteCount + 1
        i = i + 3   // skip past %XX
      Catch
        // Invalid hex — treat % as a literal character
        mb.Byte(byteCount) = Asc(ch)
        byteCount = byteCount + 1
        i = i + 1
      End Try
    Else
      // Literal character — store its byte value
      mb.Byte(byteCount) = Asc(ch)
      byteCount = byteCount + 1
      i = i + 1
    End If
  Wend

  // Interpret the collected bytes as a UTF-8 string
  Var raw As String = mb.StringValue(0, byteCount)
  Return DefineEncoding(raw, Encodings.UTF8)
End Function
```

The key insight: collect all raw bytes into a `MemoryBlock` first, then call `DefineEncoding(..., Encodings.UTF8)` once at the end. This correctly assembles multi-byte sequences before Xojo interprets the string encoding.

## String indexing — 0-based in Xojo 2025

Xojo 2025 strings use a fully **0-based** modern API. The legacy `Mid()` function is 1-based and must never be used alongside `IndexOf()`:

| Method | Base | Notes |
|---|---|---|
| `String.IndexOf("x")` | **0-based** | Returns `0` for first character |
| `String.Middle(index, len)` | **0-based** | Aligns naturally with `IndexOf` |
| `String.Left(n)` | count | Index-agnostic — always safe |
| `String.Right(n)` | count | Index-agnostic — always safe |
| `Mid(s, start, len)` | **1-based** | Legacy VB function — do not use |

```xojo
Var pair As String = "title=Hello"
Var eqPos As Integer = pair.IndexOf("=")  // returns 5 (0-based)

// ✅ Correct — Middle() is 0-based
Var key   As String = pair.Left(eqPos)          // "title"
Var value As String = pair.Middle(eqPos + 1)    // "Hello"

// ❌ Wrong — Mid() is 1-based, off by one
Var value As String = Mid(pair, eqPos + 1)      // "=Hello" (wrong!)
```

Counter loops also use 0-based `Middle`:

```xojo
Var i As Integer = 0
While i < s.Length
  Var ch As String = s.Middle(i, 1)   // 0-based
  i = i + 1
Wend
```

## MIME types and Content-Type

`Content-Type` tells the browser (and server) how to interpret the body. The two most relevant types:

**Request Content-Type** (set by the browser):
- `application/x-www-form-urlencoded` — default HTML form encoding
- `multipart/form-data` — for file uploads (not yet implemented)
- `application/json` — for JSON API requests

**Response Content-Type** (set by the ViewModel or Router):
- `text/html; charset=utf-8` — all rendered page responses
- `application/json` — for JSON API responses
- `text/css; charset=utf-8` — served CSS files
- `application/javascript; charset=utf-8` — served JS files

Always include `; charset=utf-8` on text types. Without it, some browsers default to Latin-1, which breaks Thai and other non-ASCII content.

```xojo
// Always set Content-Type explicitly
Response.Header("Content-Type") = "text/html; charset=utf-8"
Response.Write(html)
```

`BaseViewModel.Render()` sets this automatically. You only need to set it manually when writing raw responses (error handlers, static files, JSON endpoints).

## Query string parsing

URL query strings (the `?key=val&key2=val2` part of a GET URL) use the same percent-encoding format as form bodies. `QueryParser.Parse()` handles them identically to `FormParser.Parse()`.

```xojo
// In a ViewModel
Var sort As String = GetParam("sort")    // reads ?sort=asc
Var page As String = GetParam("page")   // reads ?page=2
```

`GetParam()` checks path parameters first, then falls back to the query string — so `/notes/42?sort=asc` with a route `/notes/:id` gives `GetParam("id") = "42"` and `GetParam("sort") = "asc"`.
