---
title: การให้บริการ Static Assets
description: วิธีการให้บริการไฟล์ CSS, JavaScript, รูปภาพ และไฟล์ static อื่นๆ ในแอป XjMVVM
---

# การให้บริการ Static Assets

เนื่องจาก `HandleURL` จะสกัดกั้นทุกคำขอ คุณต้องจัดการคำขอ static assets (`.css`, `.js`, รูปภาพ, ฟอนต์) อย่างชัดเจน มีสามวิธี โดยเรียงลำดับจากง่ายไปยังยืดหยุ่นมากที่สุด

## Option 1 — CDN links (แนะนำสำหรับไลบรารี)

สำหรับไลบรารีบุคคลที่สาม (Tailwind, Alpine.js, ไลบรารีแผนภูมิ) ให้เชื่อมโยงจาก CDN โดยตรง ไม่จำเป็นต้องใช้โค้ด Xojo

```html
{# templates/layouts/base.html #}
<head>
  <link rel="stylesheet" href="https://cdn.tailwindcss.com">
  <script src="https://unpkg.com/alpinejs@3" defer></script>
</head>
```

ใช้วิธีนี้สำหรับไลบรารีที่คุณไม่ได้แก้ไข ความซับซ้อนในการปรับใช้เป็นศูนย์

## Option 2 — Static file ViewModel

สำหรับ CSS, JS และรูปภาพของคุณเอง ให้ลงทะเบียนเส้นทาง `/static/:file` ที่อ่านไฟล์จากดิสก์และเขียนไปยังการตอบสนอง

### 1. สร้าง ViewModel

สร้าง `ViewModels/StaticFileVM.xojo_code`:

```xojo
Class StaticFileVM
  Inherits BaseViewModel

  Sub OnGet()
    Var fileName As String = GetParam("file")

    // Security: reject path traversal attempts
    If fileName.Contains("..") Or fileName.Contains("/") Or fileName.Contains("\") Then
      Response.Status = 400
      Response.Write("Bad Request")
      Return
    End If

    // Build path to static/ folder (adjust for your project layout)
    Var staticDir As New FolderItem("/path/to/mvvm/static", FolderItem.PathModes.Native)
    Var file As FolderItem = staticDir.Child(fileName)

    If Not file.Exists Then
      Response.Status = 404
      Response.Write("Not Found")
      Return
    End If

    // Set MIME type based on extension
    Response.Header("Content-Type") = MimeType(fileName)

    // Cache static assets for 1 hour in production
    Response.Header("Cache-Control") = "public, max-age=3600"

    // Read and write file bytes
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

ใน `App.Opening()` ให้ลงทะเบียนเส้นทาง static **หลังจาก** เส้นทางอื่นๆ ทั้งหมดเพื่อหลีกเลี่ยงการจับคู่เส้นทางแอปพลิเคชันโดยไม่ตั้งใจ:

```xojo
// Register application routes first
mRouter.Get("/",           New HomeViewModelFactory())
mRouter.Get("/notes",      New NotesListVMFactory())
// ... all other routes ...

// Static files last
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
    ตรวจสอบชื่อไฟล์เสมอก่อนการอ่านจากดิสก์ การตรวจสอบ path traversal (`..`, `/`, `\`) ในตัวอย่างข้างต้นเป็นข้อกำหนดขั้นต่ำ ไม่ว่าสร้างเส้นทางไฟล์จากข้อมูลที่ป้อนโดยผู้ใช้โดยไม่มีการตรวจสอบ

## Option 3 — Xojo Copy Files build step

สำหรับไฟล์ที่ควรรวมอยู่กับไบนารีแอปพลิเคชัน (ฟอนต์, รูปภาพเริ่มต้น) ให้ใช้ **Copy Files** build step ของ Xojo เพื่อรวมไฟล์เหล่านั้นในโฟลเดอร์ Resources ของแอป

จากนั้นเข้าถึงพวกมันในรันไทม์ผ่าน:

```xojo
Var resourceDir As FolderItem = App.ExecutableFile.Parent.Child("Resources")
Var file As FolderItem = resourceDir.Child(fileName)
```

วิธีนี้เหมาะสำหรับไฟล์ที่มาพร้อมกับแอปและไม่เปลี่ยนแปลงในรันไทม์ สำหรับ asset นักพัฒนาที่คุณแก้ไขบ่อยครั้งระหว่างการพัฒนา Option 2 จะสะดวกกว่า

## MIME types reference

| ส่วนขยาย | MIME type |
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