---
title: "JSON API และการให้บริการไฟล์แบบ Static"
description: วิธีที่ XjMVVM เปิดเผย JSON API ที่มีการรับรองตัวตน พร้อมกับเส้นทาง SSR ของมัน และวิธีการทำงานของเซิร์ฟเวอร์ไฟล์แบบ static ที่สร้างขึ้นมา
---

# JSON API และการให้บริการไฟล์แบบ Static

XjMVVM สามารถให้บริการหน้า HTML ที่สร้างจากเซิร์ฟเวอร์ **และ** JSON API จากแอปพลิเคชันเดียวกัน — ไม่จำเป็นต้องใช้กระบวนการแยกต่างหากหรือเฟรมเวิร์กอื่น API ใช้ Router เดียวกัน ลวดลายการใช้งาน ViewModel เดียวกัน และ Models เดียวกัน ความแตกต่างเพียงอย่างเดียวคือรูปแบบของการตอบสนองและการป้องกันการเข้าถึง

---

## โมดูล JSONSerializer

**ไฟล์:** `Framework/JSONSerializer.xojo_code`

โมดูลง่ายๆ ที่แปลง `Dictionary` และ `Variant()` ของ `Dictionary` เป็นสตริง JSON ไม่ต้องพึ่งพาไลบรารีภายนอกใดๆ — เพียงแค่การจัดการสตริง

```xojo
Module JSONSerializer

  // Escape a value for use inside a JSON string literal
  Function EscapeString(s As String) As String
    s = s.ReplaceAll("\", "\\")
    s = s.ReplaceAll(Chr(34), "\""")  // double-quote
    s = s.ReplaceAll(Chr(10), "\n")   // newline
    s = s.ReplaceAll(Chr(13), "\r")   // carriage return
    s = s.ReplaceAll(Chr(9),  "\t")   // tab
    Return s
  End Function

  // Serialize a Dictionary of string values to a JSON object
  Function DictToJSON(d As Dictionary) As String
    Var parts() As String
    For Each key As Variant In d.Keys
      Var k As String = EscapeString(key.StringValue)
      Var v As String = EscapeString(d.Value(key).StringValue)
      parts.Add("""" + k + """" + ":" + """" + v + """")
    Next
    Return "{" + String.FromArray(parts, ",") + "}"
  End Function

  // Serialize a Variant() of Dictionary to a JSON array
  Function ArrayToJSON(items() As Variant) As String
    Var parts() As String
    For Each item As Variant In items
      Var d As Dictionary = item
      parts.Add(DictToJSON(d))
    Next
    Return "[" + String.FromArray(parts, ",") + "]"
  End Function

End Module
```

!!! note
    ค่าทั้งหมดจะถูกจัดอักษรเป็น JSON string — ไม่มีประเภท numeric หรือ boolean ความสอดคล้องกับวิธีการทำงานของ `RowToDict` — ค่าฐานข้อมูลทั้งหมดเก็บไว้เป็น `StringValue` ผู้ใช้งาน API ควรแยกวิเคราะห์ตัวเลขจากสตริงตามความจำเป็น

### `WriteJSON` บน BaseViewModel

```xojo
Sub WriteJSON(jsonString As String)
  Response.Header("Content-Type") = "application/json; charset=utf-8"
  Response.Write(jsonString)
End Sub
```

content-type จะสัญญาณว่าเป็น JSON ให้กับผู้ใช้งาน ViewModel ไม่จำเป็นต้องตั้งค่าหัวข้อโดยตรง — เพียงเรียก `WriteJSON(...)` ด้วยสตริงที่ถูกจัดอักษรแล้ว

---

## การรับรองตัวตนของ API

ปลายทาง API ทั้งหมดต้องใช้การรับรองตัวตน ต่างจากเส้นทาง HTML ที่เปลี่ยนเส้นทางไปยัง `/login` เส้นทาง API จะส่งกลับข้อผิดพลาด **401 JSON** เมื่อผู้ใช้ไม่ได้รับการรับรองตัวตน:

```json
{"error":"Authentication required"}
```

ViewModel API ทั้งหมดเรียก `RequireLoginJSON()` เป็นบรรทัดแรก:

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return  // 401 if no valid mvvm_auth cookie
  // ... rest of handler
End Sub
```

ไคลเอนต์ API ต้องรวม cookie `mvvm_auth` ในคำขอของพวกเขา สำหรับ JavaScript ที่ใช้ในเบราว์เซอร์ (`fetch`) สิ่งนี้เกิดขึ้นโดยอัตโนมัติเมื่อใช้ `credentials: 'same-origin'` สำหรับไคลเอนต์ภายนอก cookie จะต้องได้รับผ่านปลายทางการเข้าสู่ระบบ และส่งไปพร้อมกับคำขอต่อมา

---

## API ViewModels

ViewModel API ทั้งหมดอยู่ในโฟลเดอร์ `ViewModels/API/` พวกเขาปฏิบัติตามลวดลายเดียวกับ SSR ViewModels — `OnGet()`/`OnPost()` — ความแตกต่างเพียงอย่างเดียวคือพวกเขาเรียก `WriteJSON()` แทน `Render()`

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[GET /api/notes] -> [NotesAPIListVM|RequireLoginJSON()\nmodel.GetAll(userID)\nArrayToJSON()]
[GET /api/notes/:id] -> [NotesAPIDetailVM|RequireLoginJSON()\nmodel.GetByID(id, userID)\nembed tags in JSON]
[POST /api/notes] -> [NotesAPICreateVM|RequireLoginJSON()\nvalidate\nmodel.Create(title, body, userID)\n201 Created]
[GET /api/tags] -> [TagsAPIListVM|RequireLoginJSON()\nmodel.GetAll()\nArrayToJSON()]
[GET /api/tags/:id] -> [TagsAPIDetailVM|RequireLoginJSON()\nmodel.GetByID(id)\nDictToJSON()]
-->
<!-- ascii
GET  /api/notes       -> NotesAPIListVM   -> RequireLoginJSON() -> ArrayToJSON(notes)
GET  /api/notes/:id   -> NotesAPIDetailVM -> RequireLoginJSON() -> note + embedded tags array
POST /api/notes       -> NotesAPICreateVM -> RequireLoginJSON() -> 201 Created + new note JSON
GET  /api/tags        -> TagsAPIListVM    -> RequireLoginJSON() -> ArrayToJSON(tags)
GET  /api/tags/:id    -> TagsAPIDetailVM  -> RequireLoginJSON() -> DictToJSON(tag)
-->
<!-- /diagram -->

### NotesAPIListVM — `GET /api/notes`

ส่งกลับบันทึกย่อทั้งหมดสำหรับผู้ใช้ที่ได้รับการรับรองตัวตน:

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll(userID)
  WriteJSON(JSONSerializer.ArrayToJSON(notes))
End Sub
```

การตอบสนอง: `[{"id":"1","title":"Hello","body":"...","created_at":"...","updated_at":"...","user_id":"5"},...]`

บันทึกย่อถูกจำกัดขอบเขตให้เป็นของผู้ใช้ที่ได้รับการรับรองตัวตน — แต่ละผู้ใช้มองเห็นได้เฉพาะบันทึกย่อของตนเองเท่านั้น

### NotesAPIDetailVM — `GET /api/notes/:id`

ส่งกลับบันทึกย่อที่มีอาร์เรย์ `tags` แบบฝังตัว ส่งกลับ 404 หากบันทึกย่อไม่มีอยู่หรือเป็นของผู้ใช้คนอื่น:

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var id As Integer = Val(GetParam("id"))
  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var note As Dictionary = model.GetByID(id, userID)

  If note = Nil Then
    Response.Status = 404
    WriteJSON("{""error"":""Note not found""}")
    Return
  End If

  // Embed tags array inside the note JSON object
  Var tags() As Variant = model.GetTagsForNote(id)
  Var noteJSON As String = JSONSerializer.DictToJSON(note)
  Var tagsJSON As String = JSONSerializer.ArrayToJSON(tags)
  noteJSON = noteJSON.Left(noteJSON.Length - 1) + ",""tags"":" + tagsJSON + "}"
  WriteJSON(noteJSON)
End Sub
```

อาร์เรย์แท็กถูกฉีดเข้าโดยการจัดการสตริง — การลบเครื่องหมาย `}` ปิดท้ายและเพิ่ม `,"tags":[...]}` ก่อนปิดอีกครั้ง สิ่งนี้ตั้งใจ: `JSONSerializer.DictToJSON` จัดการเฉพาะพจนานุกรมสตริงแบบราบเรียบเท่านั้น การฝังอาร์เรย์ที่ซ้อนกันต้องใช้การจัดองค์ประกอบด้วยตนเอง

!!! note
    แนวทางนี้ทำงานได้อย่างน่าเชื่อถือเพราะ `DictToJSON` ให้ผลลัพธ์เป็นออบเจกต์ JSON ที่ถูกต้องเสมอและลงท้ายด้วย `}` หากตัวจัดอักษรเปลี่ยนแปลง จุดการฉีดนี้จะต้องได้รับการตรวจสอบใหม่

### NotesAPICreateVM — `POST /api/notes`

```xojo
Sub OnPost()
  If RequireLoginJSON() Then Return

  Var title As String = GetFormValue("title").Trim()
  Var body As String = GetFormValue("body")

  If title.Length = 0 Then
    Response.Status = 422      // Unprocessable Entity -- validation error
    WriteJSON("{""error"":""Title is required""}")
    Return
  End If

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var newID As Integer = model.Create(title, body, userID)
  Var note As Dictionary = model.GetByID(newID, userID)

  Response.Status = 201        // Created
  WriteJSON(JSONSerializer.DictToJSON(note))
End Sub
```

รหัสสถานะที่ใช้โดย API: **200** สำหรับการอ่านที่สำเร็จ **201** สำหรับการสร้างที่สำเร็จ **401** สำหรับไม่มีการรับรองตัวตน **404** สำหรับไม่พบ **422** สำหรับล้มเหลวการตรวจสอบ

### TagsAPIListVM — `GET /api/tags`

แท็กเป็นส่วนกลาง (ไม่ได้จำกัดขอบเขตตามผู้ใช้) แต่ยังคงต้องใช้การรับรองตัวตน:

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(tags))
End Sub
```

### TagsAPIDetailVM — `GET /api/tags/:id`

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return

  Var id As Integer = Val(GetParam("id"))
  Var model As New TagModel()
  Var tag As Dictionary = model.GetByID(id)

  If tag = Nil Then
    Response.Status = 404
    WriteJSON("{""error"":""Tag not found""}")
    Return
  End If

  WriteJSON(JSONSerializer.DictToJSON(tag))
End Sub
```

---

## เส้นทาง API

ลงทะเบียนใน `App.Opening` พร้อมกับเส้นทาง SSR:

```xojo
// JSON API routes
mRouter.Get("/api/notes",       AddressOf CreateNotesAPIListVM)
mRouter.Post("/api/notes",      AddressOf CreateNotesAPICreateVM)
mRouter.Get("/api/notes/:id",   AddressOf CreateNotesAPIDetailVM)
mRouter.Get("/api/tags",        AddressOf CreateTagsAPIListVM)
mRouter.Get("/api/tags/:id",    AddressOf CreateTagsAPIDetailVM)
```

คำนำหน้า `/api/` แยกเส้นทาง API จากเส้นทาง SSR โดยแบบแผน — Router จัดการเหล่านี้ตรงกัน

---

## เซิร์ฟเวอร์ไฟล์แบบ static

**ไฟล์:** `App.xojo_code` (เมธอด `ServeStatic` + การจัดส่ง `HandleURL`)

เซิร์ฟเวอร์ไฟล์แบบ static ทำให้สามารถเข้าถึงเวบไซต์เอกสารนักพัฒนาได้โดยตรงจากแอปที่กำลังทำงานอยู่ที่ `/dist/*` ไฟล์จะถูกให้บริการจากโฟลเดอร์ `templates/dist/` — โฟลเดอร์เดียวกับที่สคริปต์ `build.py` ส่งออก

### การจัดส่ง HandleURL

```xojo
// Redirect bare /dist to /dist/
If p = "/dist" Then
  response.Status = 302
  response.Header("Location") = "/dist/"
  Return True
End If
// Serve anything under /dist/
If p.Left(6) = "/dist/" Then
  Return ServeStatic(p.Middle(6), response)
End If
```

`p.Middle(6)` จะลบคำนำหน้า `/dist/` (6 อักขระ แบบเป็นศูนย์) และส่งส่วนที่เหลือไปยัง `ServeStatic`

### ServeStatic — การป้องกันการข้ามเส้นทาง

```xojo
Private Function ServeStatic(relativePath As String, response As WebResponse) As Boolean
  // Start from the known safe root
  Var f As FolderItem = App.ExecutableFile.Parent.Child("templates").Child("dist")

  // Walk each path segment individually -- never concatenate raw user input
  Var parts() As String = relativePath.Split("/")
  For Each part As String In parts
    If part = "" Or part = "." Or part = ".." Then Continue  // skip dangerous segments
    f = f.Child(part)
    If f Is Nil Or Not f.Exists Then
      response.Status = 404
      response.Header("Content-Type") = "text/plain"
      response.Write("Not found")
      Return True
    End If
  Next

  // Directory -> try index.html automatically
  If f.IsFolder Then
    f = f.Child("index.html")
    If f Is Nil Or Not f.Exists Then
      response.Status = 404
      response.Write("Not found")
      Return True
    End If
  End If
  // ... content-type + file read ...
End Function
```

!!! warning
    **ไม่เคย** สร้างเส้นทางไฟล์โดยการต่อสตริง URL ที่ไม่ได้ประมวลผล คำขอสำหรับ `/dist/../data/notes.sqlite` จะให้บริการไฟล์ฐานข้อมูลหากเส้นทางถูกต่อกันโดยตรง การเดินผ่านแต่ละส่วนผ่าน `Child()` และปฏิเสธ `..` และ `.` ป้องกันการโจมตีการข้ามเส้นทางได้อย่างสมบูรณ์

### การแมป Content-Type

```xojo
Var ext As String = f.Name.Lowercase
Var ct As String = "application/octet-stream"
If ext.EndsWith(".html")  Then ct = "text/html; charset=utf-8"
If ext.EndsWith(".css")   Then ct = "text/css"
If ext.EndsWith(".js")    Then ct = "application/javascript"
If ext.EndsWith(".svg")   Then ct = "image/svg+xml"
If ext.EndsWith(".png")   Then ct = "image/png"
If ext.EndsWith(".ico")   Then ct = "image/x-icon"
If ext.EndsWith(".woff2") Then ct = "font/woff2"
```

นามสกุลที่ไม่รู้จักจะกลับไปใช้ `application/octet-stream` เพิ่มรายการใหม่ที่นี่หากต้องการให้บริการประเภทไฟล์เพิ่มเติม

### การเข้าถึงเอกสาร

เมื่อแอปทำงานบนพอร์ต 8080 เอกสารนักพัฒนาจะสามารถเข้าถึงได้ที่:

```
http://localhost:8080/dist/en/index.html
http://localhost:8080/dist/th/index.html
http://localhost:8080/dist/jp/index.html
```

เส้นทาง `/dist/` จะได้รับการจัดการก่อนเราเตอร์ SSR ดังนั้นเซิร์ฟเวอร์ static จะให้บริการสำหรับคำนำหน้านั้นเสมอ