---
title: Forms, MIME & UTF-8
description: HTML form data ถูกเข้ารหัสอย่างไร, FormParser ถอดรหัสอย่างไร, และวิธีที่ UTF-8 percent-encoding ทำงานอย่างถูกต้องใน Xojo
---

# Forms, MIME & UTF-8

## HTML form encoding

เมื่อเบราว์เซอร์ส่ง `<form method="post">`, มันเข้ารหัสค่าช่องฟิลด์เป็นสตริงไบต์ในเนื้อความคำขอ รูปแบบเข้ารหัสถูกระบุโดยแอตทริบิวต์ `enctype` ของฟอร์ม

โปรเจคนี้จัดการการเข้ารหัสเริ่มต้น: `application/x-www-form-urlencoded`

### เนื้อความที่เข้ารหัสมีลักษณะอย่างไร

กำหนดฟอร์มนี้:

```html
<form method="post" action="/notes">
  <input name="title" value="Hello World">
  <textarea name="body">Line 1
Line 2</textarea>
</form>
```

เนื้อความ POST ที่ส่งไปยังเซิร์ฟเวอร์คือ:

```
title=Hello+World&body=Line+1%0ALine+2
```

กฎต่างๆ:
- ฟิลด์ถูกแยกด้วย `&`
- คีย์และค่าถูกแยกด้วย `=`
- ช่องว่างกลายเป็น `+`
- ตัวอักษรพิเศษกลายเป็น `%XX` โดยที่ `XX` คือค่าไบต์ฐานสิบหก
- อักขระหลายไบต์ (ไทย, emoji, ตัวอักษรที่มีสัญญะ) กลายเป็นหลายลำดับ `%XX` — ลำดับละหนึ่งต่อไบต์ UTF-8

### การอ่านเนื้อความ POST ใน Xojo

`WebRequest.Body` ของ Xojo มีสตริงที่เข้ารหัสดิบ ต้องอ่าน **เพียงครั้งเดียว**, ทันทีเพราะบัฟเฟอร์ภายในอาจไม่สามารถอ่านซ้ำได้หลังจากการเข้าถึงครั้งแรก `BaseViewModel.Handle()` เก็บข้อมูลไว้:

```xojo
Sub Handle()
  // เก็บเนื้อความ POST ทันที — Request.Body อาจอ่านได้เพียงครั้งเดียวเท่านั้น
  If Request.Method = "POST" Then
    mRawBody = Request.Body
  End If
  // ...
End Sub
```

## FormParser — วิธีการทำงาน

`FormParser.Parse(body)` แปลงสตริงที่เข้ารหัสเป็น `Dictionary` ของคู่คีย์ → ค่า

การใช้งานฉบับสมบูรณ์พร้อมคำอธิบาย:

```xojo
Function Parse(body As String) As Dictionary
  Var result As New Dictionary()
  If body.Length = 0 Then Return result

  // แยกบน & เพื่อรับคู่ key=value แต่ละคู่
  Var pairs() As String = body.Split("&")

  For i As Integer = 0 To pairs.Count - 1
    Var pair As String = pairs(i)

    // ค้นหาตัวแยก = (ดัชนีแบบ 0)
    Var eqPos As Integer = pair.IndexOf("=")

    If eqPos >= 0 Then
      // ถอดรหัสทั้งคีย์และค่า
      Var key   As String = DecodeURIComponent(pair.Left(eqPos))
      Var value As String = DecodeURIComponent(pair.Middle(eqPos + 1))
      result.Value(key) = value
    ElseIf pair.Length > 0 Then
      // คีย์ที่ไม่มี = (เช่น checkbox ที่เลือกโดยไม่มีค่า)
      result.Value(DecodeURIComponent(pair)) = ""
    End If
  Next

  Return result
End Function
```

!!! note "การจัดทำดัชนีสตริงแบบ 0"
    `pair.IndexOf("=")` ส่งคืนตำแหน่งแบบ 0 `pair.Left(eqPos)` แยกคีย์ (ทุกอย่างก่อน `=`) `pair.Middle(eqPos + 1)` แยกค่า (ทุกอย่างหลัง `=`) `Middle()` เป็นแบบ 0 และจัดตำแหน่งอย่างถูกต้องกับ `IndexOf` ไม่เคยใช้ `Mid()` — เป็นฟังก์ชันเดิมแบบ 1 ที่ให้ผลลัพธ์ที่ผิดเมื่อรวมกับ `IndexOf`

## DecodeURIComponent — เคล็ดลับ UTF-8

นี่คือฟังก์ชันเข้ารหัสที่สำคัญที่สุดในโปรเจค การทำให้ผิดพลาดอย่างเงียบๆ จะทำให้ข้อความไทย, emoji และอินพุตที่ไม่ใช่ ASCII ทั้งหมดเสียหาย

### แนวทางที่ผิด (เสียหายอักขระหลายไบต์)

```xojo
// ❌ ผิด — Chr() แมปจำนวนเต็มกับจุดรหัส Unicode, ไม่ใช่ไบต์ดิบ
If ch = "%" Then
  Var byte As Integer = Integer.FromHex(hex)
  result = result + Chr(byte)   // Chr(0xE0) = "à", ไม่ใช่ไบต์ 0xE0
End If
```

`Chr(0xE0)` ส่งคืนตัวอักษร Unicode U+00E0 (`à`), ซึ่งเป็นลำดับ UTF-8 สองไบต์ `0xC3 0xA0` แต่เราต้องการไบต์เดียว `0xE0`, ซึ่งเป็นไบต์เริ่มต้นของลำดับอักขระไทยสามไบต์เช่น `ก` (`0xE0 0xB8 0x81`) ความไม่ตรงกันระหว่าง 2 ไบต์นี้ทำให้อักขระหลายไบต์ทุกตัวเสียหาย

### แนวทางที่ถูกต้อง (MemoryBlock + DefineEncoding)

```xojo
// ✅ ถูกต้อง — รวบรวมไบต์ดิบใน MemoryBlock, จากนั้นถอดรหัสเป็น UTF-8
Function DecodeURIComponent(encoded As String) As String
  // + → space (ต้องเกิดขึ้นก่อน)
  Var s As String = encoded.ReplaceAll("+", " ")
  If s.Length = 0 Then Return ""

  Var mb As New MemoryBlock(s.Length)
  Var byteCount As Integer = 0
  Var i As Integer = 0

  While i < s.Length
    Var ch As String = s.Middle(i, 1)

    If ch = "%" And i + 2 < s.Length Then
      // ไบต์ที่เข้ารหัสเปอร์เซ็นต์ — แยกตัวเลขฐานสิบหกทั้งสอง
      Var hex As String = s.Middle(i + 1, 2)
      Try
        mb.Byte(byteCount) = Integer.FromHex(hex)   // จัดเก็บไบต์ดิบ
        byteCount = byteCount + 1
        i = i + 3   // ข้าม %XX
      Catch
        // ฐานสิบหกไม่ถูกต้อง — ถือว่า % เป็นตัวอักษรตามตัวอักษร
        mb.Byte(byteCount) = Asc(ch)
        byteCount = byteCount + 1
        i = i + 1
      End Try
    Else
      // ตัวอักษรตามตัวอักษร — จัดเก็บค่าไบต์ของมัน
      mb.Byte(byteCount) = Asc(ch)
      byteCount = byteCount + 1
      i = i + 1
    End If
  Wend

  // ตีความไบต์ที่รวบรวมเป็นสตริง UTF-8
  Var raw As String = mb.StringValue(0, byteCount)
  Return DefineEncoding(raw, Encodings.UTF8)
End Function
```

ข้อมูลเชิงลึกที่สำคัญ: รวบรวมไบต์ดิบทั้งหมดใน `MemoryBlock` ก่อน, จากนั้นเรียก `DefineEncoding(..., Encodings.UTF8)` เพียงครั้งเดียวที่ส่วนท้าย สิ่งนี้จะประกอบลำดับหลายไบต์อย่างถูกต้องก่อนที่ Xojo จะตีความการเข้ารหัสสตริง

## การนับดัชนีสตริงแบบ 0-based ใน Xojo 2025

สตริง Xojo 2025 ใช้ API สมัยใหม่ที่ **0-based** อย่างเต็มที่ ฟังก์ชันเดิม `Mid()` เป็นแบบ 1 และต้องไม่ใช้ร่วมกับ `IndexOf()`:

| วิธีการ | ฐาน | หมายเหตุ |
|---|---|---|
| `String.IndexOf("x")` | **0-based** | ส่งคืน `0` สำหรับตัวอักษรแรก |
| `String.Middle(index, len)` | **0-based** | จัดตำแหน่งตามธรรมชาติกับ `IndexOf` |
| `String.Left(n)` | count | ไม่เกี่ยวกับดัชนี — ปลอดภัยเสมอ |
| `String.Right(n)` | count | ไม่เกี่ยวกับดัชนี — ปลอดภัยเสมอ |
| `Mid(s, start, len)` | **1-based** | ฟังก์ชัน VB เดิม — อย่าใช้ |

```xojo
Var pair As String = "title=Hello"
Var eqPos As Integer = pair.IndexOf("=")  // ส่งคืน 5 (0-based)

// ✅ ถูกต้อง — Middle() เป็น 0-based
Var key   As String = pair.Left(eqPos)          // "title"
Var value As String = pair.Middle(eqPos + 1)    // "Hello"

// ❌ ผิด — Mid() เป็น 1-based, ผิดหนึ่ง
Var value As String = Mid(pair, eqPos + 1)      // "=Hello" (ผิด!)
```

วนรอบตัวนับยังใช้ `Middle` แบบ 0:

```xojo
Var i As Integer = 0
While i < s.Length
  Var ch As String = s.Middle(i, 1)   // 0-based
  i = i + 1
Wend
```

## ประเภท MIME และ Content-Type

`Content-Type` บอกเบราว์เซอร์ (และเซิร์ฟเวอร์) วิธีตีความเนื้อความ ประเภทที่เกี่ยวข้องมากที่สุดสองประเภท:

**Request Content-Type** (ตั้งค่าโดยเบราว์เซอร์):
- `application/x-www-form-urlencoded` — การเข้ารหัสฟอร์ม HTML เริ่มต้น
- `multipart/form-data` — สำหรับการอัปโหลดไฟล์ (ยังไม่ได้ใช้งาน)
- `application/json` — สำหรับคำขอ JSON API

**Response Content-Type** (ตั้งค่าโดย ViewModel หรือ Router):
- `text/html; charset=utf-8` — การตอบสนองหน้าที่เรนเดอร์ทั้งหมด
- `application/json` — สำหรับการตอบสนอง JSON API
- `text/css; charset=utf-8` — ไฟล์ CSS ที่เสิร์ฟ
- `application/javascript; charset=utf-8` — ไฟล์ JS ที่เสิร์ฟ

รวม `; charset=utf-8` ในประเภทข้อความเสมอ หากไม่มี เบราว์เซอร์บางตัวจะตั้งค่าเริ่มต้นเป็น Latin-1 ซึ่งทำให้เนื้อหาไทยและ non-ASCII อื่นๆ เสียหาย

```xojo
// ตั้งค่า Content-Type อย่างชัดเจนเสมอ
Response.Header("Content-Type") = "text/html; charset=utf-8"
Response.Write(html)
```

`BaseViewModel.Render()` ตั้งค่านี้โดยอัตโนมัติ คุณต้องตั้งค่าด้วยตนเองเมื่อเขียนการตอบสนองแบบดิบเท่านั้น (ตัวจัดการข้อผิดพลาด, ไฟล์คงที่, จุดปลายทาง JSON)

## การแยกวิเคราะห์สตริงคิวรี

สตริงคิวรี URL (ส่วน `?key=val&key2=val2` ของ URL ที่ได้รับ) ใช้รูปแบบเข้ารหัสเปอร์เซ็นต์เดียวกับเนื้อความฟอร์ม `QueryParser.Parse()` จัดการกับมันเหมือนกับ `FormParser.Parse()`

```xojo
// ใน ViewModel
Var sort As String = GetParam("sort")    // อ่าน ?sort=asc
Var page As String = GetParam("page")   // อ่าน ?page=2
```

`GetParam()` ตรวจสอบพารามิเตอร์เส้นทางก่อน, จากนั้นกลับไปเป็นสตริงคิวรี — ดังนั้น `/notes/42?sort=asc` พร้อมเส้นทาง `/notes/:id` ให้ `GetParam("id") = "42"` และ `GetParam("sort") = "asc"`