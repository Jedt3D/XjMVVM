---
title: แบบฟอร์ม MIME และ UTF-8
description: วิธีการเข้ารหัสข้อมูลแบบฟอร์ม HTML วิธี FormParser ถอดรหัส และวิธี UTF-8 percent-encoding ทำงานอย่างถูกต้องใน Xojo
---

# แบบฟอร์ม MIME และ UTF-8

## การเข้ารหัสแบบฟอร์ม HTML

เมื่อเบราว์เซอร์ส่ง `<form method="post">` มันจะเข้ารหัสค่าฟิลด์เป็นสตริงไบต์ในเนื้อหาคำขอ รูปแบบการเข้ารหัสถูกระบุโดยแอตทริบิวต์ `enctype` ของแบบฟอร์ม

โครงการนี้จัดการการเข้ารหัสเริ่มต้น: `application/x-www-form-urlencoded`

### เนื้อหาที่เข้ารหัสดูเหมือนไร

ให้แบบฟอร์มนี้:

```html
<form method="post" action="/notes">
  <input name="title" value="Hello World">
  <textarea name="body">Line 1
Line 2</textarea>
</form>
```

เนื้อหา POST ที่ส่งไปยังเซิร์ฟเวอร์คือ:

```
title=Hello+World&body=Line+1%0ALine+2
```

กฎ:
- ฟิลด์คั่นด้วย `&`
- กุญแจและค่าคั่นด้วย `=`
- ช่องว่างกลายเป็น `+`
- อักขระพิเศษกลายเป็น `%XX` โดยที่ `XX` คือค่าไบต์ฐานสิบหก
- อักขระหลายไบต์ (ไทย emoji ตัวอักษรเน้น) กลายเป็นลำดับ `%XX` หลายตัว — หนึ่งต่อไบต์ UTF-8

### อ่านเนื้อหา POST ใน Xojo

`WebRequest.Body` ของ Xojo มีสตริงที่เข้ารหัสดิบ มันต้องอ่าน **เพียงครั้งเดียว** ทันทีเพราะบัฟเฟอร์ภายในอาจไม่สามารถอ่านซ้ำได้หลังจากการเข้าถึงแรก `BaseViewModel.Handle()` แคชมัน:

```xojo
Sub Handle()
  // แคช POST body ทันที — Request.Body อาจอ่านได้เพียงครั้งเดียวเท่านั้น
  If Request.Method = "POST" Then
    mRawBody = Request.Body
  End If
  // ...
End Sub
```

## FormParser — วิธีการทำงาน

`FormParser.Parse(body)` แปลงสตริงที่เข้ารหัสดิบเป็นพจนานุกรม `Dictionary` ของกุญแจ → คู่ค่า

การใช้งานแบบเต็มที่มีคำอธิบายประกอบ:

```xojo
Function Parse(body As String) As Dictionary
  Var result As New Dictionary()
  If body.Length = 0 Then Return result

  // แยกบน & เพื่อรับคู่ key=value แต่ละอัน
  Var pairs() As String = body.Split("&")

  For i As Integer = 0 To pairs.Count - 1
    Var pair As String = pairs(i)

    // ค้นหาตัวคั่น = (ดัชนี 0-based)
    Var eqPos As Integer = pair.IndexOf("=")

    If eqPos >= 0 Then
      // ถอดรหัสทั้งกุญแจและค่า
      Var key   As String = DecodeURIComponent(pair.Left(eqPos))
      Var value As String = DecodeURIComponent(pair.Middle(eqPos + 1))
      result.Value(key) = value
    ElseIf pair.Length > 0 Then
      // กุญแจที่ไม่มี = (เช่น checkbox ที่ทำเครื่องหมายด้วยค่าไม่มี)
      result.Value(DecodeURIComponent(pair)) = ""
    End If
  Next

  Return result
End Function
```

!!! note "ดัชนีสตริง 0-based"
    `pair.IndexOf("=")` คืนตำแหน่ง 0-based `pair.Left(eqPos)` แยกกุญแจ (ทุกอย่างก่อน `=`) `pair.Middle(eqPos + 1)` แยกค่า (ทุกอย่างหลัง `=`) `Middle()` คือ 0-based และจัดตำแหน่งอย่างถูกต้องกับ `IndexOf` ไม่เคยใช้ `Mid()` — มันคือฟังก์ชัน VB เก่า 1-based ที่ให้ผลลัพธ์ที่ผิดเมื่อรวมกับ `IndexOf`

## DecodeURIComponent — เคล็ดลับ UTF-8

นี่คือฟังก์ชันการเข้ารหัสที่สำคัญที่สุดในโครงการ การทำให้ผิดปนเปื้อนข้อความไทย emoji และข้อมูลป้อนที่ไม่ใช่ ASCII อย่างเงียบ ๆ

### วิธีการ ผิด (ทำให้อักขระหลายไบต์เสียหาย)

```xojo
// ❌ ผิด — Chr() แมปจำนวนเต็มกับจุดรหัส Unicode ไม่ใช่ไบต์ดิบ
If ch = "%" Then
  Var byte As Integer = Integer.FromHex(hex)
  result = result + Chr(byte)   // Chr(0xE0) = "à" ไม่ใช่ไบต์ 0xE0
End If
```

`Chr(0xE0)` คืนอักขระ Unicode U+00E0 (`à`) ซึ่งเป็นลำดับ UTF-8 สองไบต์ `0xC3 0xA0` แต่เราต้องการไบต์เดียว `0xE0` ซึ่งเป็นไบต์เริ่มต้นของลำดับตัวอักษรไทยสามไบต์เช่น `ก` (`0xE0 0xB8 0x81`) ความเบาบางของไบต์ต่อไบต์แต่ละไบต์เสียหายอักขระหลายไบต์ทั้งหมด

### วิธีการ ถูก (MemoryBlock + DefineEncoding)

```xojo
// ✅ ถูก — รวบรวมไบต์ดิบใน MemoryBlock จากนั้นถอดรหัสเป็น UTF-8
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
      // ไบต์ที่เข้ารหัสเปอร์เซ็นต์ — แยกตัวเลขฐานสิบหกสองตัว
      Var hex As String = s.Middle(i + 1, 2)
      Try
        mb.Byte(byteCount) = Integer.FromHex(hex)   // เก็บไบต์ดิบ
        byteCount = byteCount + 1
        i = i + 3   // ข้าม %XX
      Catch
        // hex ไม่ถูกต้อง — ถือว่า % เป็นอักขระตามตัวอักษร
        mb.Byte(byteCount) = Asc(ch)
        byteCount = byteCount + 1
        i = i + 1
      End Try
    Else
      // อักขระตามตัวอักษร — เก็บค่าไบต์
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

ข้อมูลสำคัญ: รวบรวมไบต์ดิบทั้งหมดเข้า `MemoryBlock` ก่อน จากนั้นเรียก `DefineEncoding(..., Encodings.UTF8)` เพียงครั้งเดียวที่ท้ายสุด สิ่งนี้จะประกอบลำดับหลายไบต์ได้อย่างถูกต้องก่อนที่ Xojo จะตีความการเข้ารหัสสตริง

## ดัชนีสตริง — 0-based ใน Xojo 2025

สตริง Xojo 2025 ใช้ API สมัยใหม่ที่เป็น 0-based อย่างเต็มที่ ฟังก์ชัน `Mid()` เก่ามี 1-based และต้องไม่ใช้ร่วมกับ `IndexOf()`:

| วิธีการ | ฐาน | หมายเหตุ |
|---|---|---|
| `String.IndexOf("x")` | **0-based** | คืน `0` สำหรับอักขระแรก |
| `String.Middle(index, len)` | **0-based** | จัดตำแหน่งธรรมชาติกับ `IndexOf` |
| `String.Left(n)` | count | ดัชนี-ไม่รู้ — เสมอปลอดภัย |
| `String.Right(n)` | count | ดัชนี-ไม่รู้ — เสมอปลอดภัย |
| `Mid(s, start, len)` | **1-based** | ฟังก์ชัน VB เก่า — อย่าใช้ |

```xojo
Var pair As String = "title=Hello"
Var eqPos As Integer = pair.IndexOf("=")  // ส่งคืน 5 (0-based)

// ✅ ถูก — Middle() คือ 0-based
Var key   As String = pair.Left(eqPos)          // "title"
Var value As String = pair.Middle(eqPos + 1)    // "Hello"

// ❌ ผิด — Mid() คือ 1-based ออกไปหนึ่ง
Var value As String = Mid(pair, eqPos + 1)      // "=Hello" (ผิด!)
```

ลูปตัวนับใช้ 0-based `Middle` ด้วย:

```xojo
Var i As Integer = 0
While i < s.Length
  Var ch As String = s.Middle(i, 1)   // 0-based
  i = i + 1
Wend
```

## ประเภท MIME และ Content-Type

`Content-Type` บอกเบราว์เซอร์ (และเซิร์ฟเวอร์) วิธีการตีความเนื้อหา สองประเภทที่เกี่ยวข้องมากที่สุด:

**Content-Type ของคำขอ** (ตั้งโดยเบราว์เซอร์):
- `application/x-www-form-urlencoded` — การเข้ารหัสแบบฟอร์ม HTML เริ่มต้น
- `multipart/form-data` — สำหรับการอัปโหลดไฟล์ (ยังไม่ใช้งาน)
- `application/json` — สำหรับคำขอ JSON API

**Content-Type ของการตอบสนอง** (ตั้งโดย ViewModel หรือ Router):
- `text/html; charset=utf-8` — ทั้งหมดเรนเดอร์หน้าการตอบสนอง
- `application/json` — สำหรับการตอบสนอง JSON API
- `text/css; charset=utf-8` — ไฟล์ CSS ที่เสิร์ฟ
- `application/javascript; charset=utf-8` — ไฟล์ JS ที่เสิร์ฟ

เสมอรวม `; charset=utf-8` บนประเภทข้อความ โดยไม่มีมัน เบราว์เซอร์บางตัวเริ่มต้นเป็น Latin-1 ซึ่งหักไทยและเนื้อหาที่ไม่ใช่ ASCII อื่น ๆ

```xojo
// เสมอตั้งค่า Content-Type อย่างชัดเจน
Response.Header("Content-Type") = "text/html; charset=utf-8"
Response.Write(html)
```

`BaseViewModel.Render()` ตั้งค่านี้โดยอัตโนมัติ คุณต้องตั้งค่าด้วยตนเองเมื่อเขียนการตอบสนองดิบ (ตัวจัดการข้อผิดพลาด ไฟล์คงที่ เอนด์พอยต์ JSON)

## การแยกวิเคราะห์สตริงการค้นหา

สตริงการค้นหา URL (ส่วน `?key=val&key2=val2` ของ URL GET) ใช้รูปแบบการเข้ารหัสเปอร์เซ็นต์เดียวกันกับเนื้อหาแบบฟอร์ม `QueryParser.Parse()` จัดการเช่นเดียวกับ `FormParser.Parse()`

```xojo
// ใน ViewModel
Var sort As String = GetParam("sort")    // อ่าน ?sort=asc
Var page As String = GetParam("page")   // อ่าน ?page=2
```

`GetParam()` ตรวจสอบพารามิเตอร์เส้นทางก่อน จากนั้นจึงกลับไปยังสตริงการค้นหา — ดังนั้น `/notes/42?sort=asc` ที่มีเส้นทาง `/notes/:id` ให้ `GetParam("id") = "42"` และ `GetParam("sort") = "asc"`
