---
title: การเสิร์ฟทรัพยากรคงที่
description: วิธีการเสิร์ฟไฟล์ CSS JavaScript รูปภาพและไฟล์คงที่อื่น ๆ ในแอป XjMVVM
---

# การเสิร์ฟทรัพยากรคงที่

เนื่องจาก `HandleURL` ดักจับคำขอทั้งหมด คุณต้องจัดการคำขออย่างชัดเจนสำหรับทรัพยากรคงที่ (`.css`, `.js`, รูปภาพ ฟอนต์) มีสามวิธี เรียงลำดับจากที่ง่ายที่สุดไปยังที่ยืดหยุ่นมากที่สุด

## ตัวเลือกที่ 1 — ลิงก์ CDN (แนะนำสำหรับไลบรารี)

สำหรับไลบรารีบุคคลที่สาม (Tailwind Alpine.js ไลบรารีแผนภูมิ) ลิงก์โดยตรงจาก CDN ไม่ต้องใช้โค้ด Xojo

```html
{# templates/layouts/base.html #}
<head>
  <link rel="stylesheet" href="https://cdn.tailwindcss.com">
  <script src="https://unpkg.com/alpinejs@3" defer></script>
</head>
```

ใช้สำหรับไลบรารีที่คุณไม่ปรับเปลี่ยน ความซับซ้อนของการปรับใช้เป็นศูนย์

## ตัวเลือกที่ 2 — Static file ViewModel

สำหรับ CSS JS และรูปภาพของคุณเอง ลงทะเบียนเส้นทาง `/static/:file` ที่อ่านไฟล์จากดิสก์และเขียนไปยังการตอบสนอง

### 1. สร้าง ViewModel

สร้าง `ViewModels/StaticFileVM.xojo_code`:

```xojo
Class StaticFileVM
  Inherits BaseViewModel

  Sub OnGet()
    Var fileName As String = GetParam("file")

    // ความปลอดภัย: ปฏิเสธความพยายามการข้ามเส้นทาง
    If fileName.Contains("..") Or fileName.Contains("/") Or fileName.Contains("\") Then
      Response.Status = 400
      Response.Write("Bad Request")
      Return
    End If

    // สร้างเส้นทางไปยังโฟลเดอร์ static/ (ปรับตามเค้าโครงโครงการของคุณ)
    Var staticDir As New FolderItem("/path/to/mvvm/static", FolderItem.PathModes.Native)
    Var file As FolderItem = staticDir.Child(fileName)

    If Not file.Exists Then
      Response.Status = 404
      Response.Write("Not Found")
      Return
    End If

    // ตั้งค่าประเภท MIME ตามนามสกุล
    Response.Header("Content-Type") = MimeType(fileName)

    // แคชทรัพยากรคงที่เป็นเวลา 1 ชั่วโมงในโปรดักชัน
    Response.Header("Cache-Control") = "public, max-age=3600"

    // อ่านและเขียนไบต์ไฟล์
    Var bs As BinaryStream = BinaryStream.Open(file, False)
    Response.Write(bs.Read(bs.Length))
    bs.Close()
  End Sub

  Private Function MimeType(fileName As String) As String
    Var ext As String = fileName.NthField(".", fileName.CountFields(".")).Lowercase
    Select Case ext
    Case "css"   : Return "text/css; charset=utf-8"
    Case "js"    : Return "application/javascript; charset=utf-8"
    Case "png"   : Return "image/png"
    Case "jpg", "jpeg" : Return "image/jpeg"
    Case "gif"   : Return "image/gif"
    Case "svg"   : Return "image/svg+xml"
    Case "ico"   : Return "image/x-icon"
    Case "woff2" : Return "font/woff2"
    Case "woff"  : Return "font/woff"
    Case "pdf"   : Return "application/pdf"
    Else          : Return "application/octet-stream"
    End Select
  End Function

End Class
```

### 2. ลงทะเบียนเส้นทาง

ใน `App.Opening()` ลงทะเบียนเส้นทางคงที่ **หลังจาก** เส้นทางอื่นทั้งหมดเพื่อหลีกเลี่ยงการจับคู่เส้นทางแอปพลิเคชันโดยไม่ตั้งใจ:

```xojo
// ลงทะเบียนเส้นทางแอปพลิเคชันก่อน
mRouter.Get("/",           New HomeViewModelFactory())
mRouter.Get("/notes",      New NotesListVMFactory())
// ... เส้นทางอื่นทั้งหมด ...

// ไฟล์คงที่สุดท้าย
mRouter.Get("/static/:file", New StaticFileVMFactory())
```

### 3. สร้างโฟลเดอร์ static/

```
mvvm/
  static/
    app.css
    app.js
    logo.png
```

### 4. อ้างอิงในเทมเพลต

```html
<link rel="stylesheet" href="/static/app.css">
<script src="/static/app.js" defer></script>
<img src="/static/logo.png" alt="Logo">
```

!!! warning "ความปลอดภัย"
    เสมอยืนยันชื่อไฟล์ก่อนอ่านจากดิสก์ การตรวจสอบการข้ามเส้นทาง (`..`, `/`, `\`) ในตัวอย่างข้างต้นเป็นข้อกำหนดขั้นต่ำที่จำเป็น ไม่เคยสร้างเส้นทางไฟล์จากข้อมูลป้อนผู้ใช้โดยไม่มีการตรวจสอบ

## ตัวเลือกที่ 3 — Xojo Copy Files build step

สำหรับไฟล์ที่ควรมีชุดรวมกับไบนารีแอปพลิเคชัน (ฟอนต์ รูปภาพเริ่มต้น) ให้ใช้ขั้น **Copy Files** ของ Xojo เพื่อรวมไฟล์เหล่านั้นไว้ในโฟลเดอร์ Resources ของแอป

จากนั้นเข้าถึงพวกมันในเวลาทำงานผ่าน:

```xojo
Var resourceDir As FolderItem = App.ExecutableFile.Parent.Child("Resources")
Var file As FolderItem = resourceDir.Child(fileName)
```

วิธีการนี้เหมาะสำหรับไฟล์ที่ส่งมาพร้อมกับแอปและไม่เปลี่ยนแปลงในเวลาทำงาน สำหรับทรัพยากรนักพัฒนาที่คุณแก้ไขบ่อย ๆ ระหว่างการพัฒนา ตัวเลือกที่ 2 จะสะดวกมากกว่า

## อ้างอิงประเภท MIME

| นามสกุล | ประเภท MIME |
|---|---|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css; charset=utf-8` |
| `.js` | `application/javascript; charset=utf-8` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg` / `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.svg` | `image/svg+xml` |
| `.ico` | `image/x-icon` |
| `.woff2` | `font/woff2` |
| `.woff` | `font/woff` |
| `.pdf` | `application/pdf` |
