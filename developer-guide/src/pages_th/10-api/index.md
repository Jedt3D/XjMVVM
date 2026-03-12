---
title: "JSON API & Static Serving"
description: วิธีการ XjMVVM เปิดเผย JSON API พร้อมกับเส้นทาง SSR และวิธีการเซิร์ฟเวอร์ไฟล์สแตติกในตัวทำงาน
---

# JSON API & Static Serving

XjMVVM สามารถให้บริการทั้ง **หน้า HTML ที่แสดงบนเซิร์ฟเวอร์** **และ** JSON API จากแอปพลิเคชันเดียวกัน — ไม่มีกระบวนการแยกต่างหากหรือเฟรมเวิร์ก API ใช้ Router เดียวกัน รูปแบบ ViewModels เดียวกัน และ Models เดียวกัน ความแตกต่างเพียงอย่างเดียวคือรูปแบบการตอบสนอง

---

## โมดูล JSONSerializer

**ไฟล์:** `Framework/JSONSerializer.xojo_code`

โมดูลง่าย ๆ ที่แปลง `Dictionary` และ `Variant()` ของ `Dictionary` เป็นสตริง JSON ไม่ขึ้นอยู่กับไลบรารีภายนอก — เพียงแค่การจัดการสตริง

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
    ค่าทั้งหมดถูกทำให้เป็นอนุกรมเป็นสตริง JSON — ไม่มีประเภทตัวเลขหรือบูลีน นี่สอดคล้องกับวิธี `RowToDict` ทำงาน: ค่าฐานข้อมูลทั้งหมดถูกเก็บเป็น `StringValue` ผู้บริโภค API ควรแยกตัวเลขจากสตริงตามต้องการ

### `WriteJSON` ใน BaseViewModel

```xojo
Sub WriteJSON(jsonString As String)
  Response.Header("Content-Type") = "application/json; charset=utf-8"
  Response.Write(jsonString)
End Sub
```

ประเภทเนื้อหาสัญญาณ JSON ให้ลูกค้า ไม่มี ViewModel ต้องตั้งค่า headers โดยตรง — เพียงแค่เรียก `WriteJSON(...)` ด้วยสตริง serialized

---

## API ViewModels

ทั้งหมด API ViewModels อาศัยอยู่ใต้ `ViewModels/API/` ตามรูปแบบ `OnGet()`/`OnPost()` เดียวกับ ViewModels SSR — ความแตกต่างเพียงอย่างเดียวคือว่าพวกเขาเรียก `WriteJSON()` แทน `Render()`

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: right
#spacing: 44
#padding: 10
#lineWidth: 1.5
[GET /api/notes] -> [NotesAPIListVM|model.GetAll()\nArrayToJSON()]
[GET /api/notes/:id] -> [NotesAPIDetailVM|model.GetByID(id)\nGetTagsForNote(id)\nembed tags in JSON]
[POST /api/notes] -> [NotesAPICreateVM|validate\nmodel.Create()\n201 Created]
[GET /api/tags] -> [TagsAPIListVM|model.GetAll()\nArrayToJSON()]
[GET /api/tags/:id] -> [TagsAPIDetailVM|model.GetByID(id)\nDictToJSON()]
-->
<!-- ascii
GET  /api/notes       → NotesAPIListVM   → ArrayToJSON(notes)
GET  /api/notes/:id   → NotesAPIDetailVM → note + embedded tags array
POST /api/notes       → NotesAPICreateVM → 201 Created + new note JSON
GET  /api/tags        → TagsAPIListVM    → ArrayToJSON(tags)
GET  /api/tags/:id    → TagsAPIDetailVM  → DictToJSON(tag)
-->
<!-- /diagram -->

### NotesAPIListVM — `GET /api/notes`

```xojo
Sub OnGet()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(notes))
End Sub
```

ปฏิกิริยา: `[{"id":"1","title":"Hello","body":"...","created_at":"...","updated_at":"..."},...]`

### NotesAPIDetailVM — `GET /api/notes/:id`

ส่งคืนโน้ตด้วย `tags` array ที่ฝัง:

```xojo
Sub OnGet()
  Var id As Integer = Val(GetParam("id"))
  Var model As New NoteModel()
  Var note As Dictionary = model.GetByID(id)

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

อาร์เรย์แท็กถูกฉีดโดยการจัดการสตริง — ลบปิดการ `}` และผนวก `,"tags":[...]}` ก่อนปิดอีกครั้ง นี่เจตนา: `JSONSerializer.DictToJSON` จัดการเฉพาะดิกชันนารีสตริงแบบสม่ำเสมอเท่านั้น การฝัง array ที่ซ้อนกันต้องใช้องค์ประกอบด้วยตนเอง

!!! note
    วิธีนี้ใช้งานได้อย่างน่าเชื่อถือเพราะ `DictToJSON` ทำให้ JSON object ที่ถูกต้องเสมอจบด้วย `}` หากตัวจำหน่ายเปลี่ยน จุดฉีดนี้ต้องตรวจสอบ

### NotesAPICreateVM — `POST /api/notes`

```xojo
Sub OnPost()
  Var title As String = GetFormValue("title").Trim()
  Var body As String = GetFormValue("body")

  If title.Length = 0 Then
    Response.Status = 422      // Unprocessable Entity — validation error
    WriteJSON("{""error"":""Title is required""}")
    Return
  End If

  Var model As New NoteModel()
  Var newID As Integer = model.Create(title, body)
  Var note As Dictionary = model.GetByID(newID)

  Response.Status = 201        // Created
  WriteJSON(JSONSerializer.DictToJSON(note))
End Sub
```

รหัสสถานะที่ใช้โดย API: **200** สำหรับการอ่านที่สำเร็จ **201** สำหรับการสร้างที่สำเร็จ **404** สำหรับไม่พบ **422** สำหรับความล้มเหลวในการตรวจสอบ

### TagsAPIListVM — `GET /api/tags`

```xojo
Sub OnGet()
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()
  WriteJSON(JSONSerializer.ArrayToJSON(tags))
End Sub
```

### TagsAPIDetailVM — `GET /api/tags/:id`

```xojo
Sub OnGet()
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

คำนำหน้า `/api/` แยก API routes จาก SSR routes ตามอนุสัญญา — Router ปฏิบัติต่อพวกเขาเหมือนกัน

---

## เซิร์ฟเวอร์ไฟล์สแตติก

**ไฟล์:** `App.xojo_code` (วิธี `ServeStatic` + การส่ง `HandleURL`)

เซิร์ฟเวอร์ไฟล์สแตติกทำให้ไซต์เอกสารพัฒนาเข้าถึงได้โดยตรงจากแอปที่ทำงานอยู่ที่ `/dist/*` ไฟล์ให้บริการจาก `templates/dist/` — โฟลเดอร์เดียวกับที่สคริปต์ `build.py` ส่งออก

### การส่ง HandleURL

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

`p.Middle(6)` ลบ คำนำหน้า `/dist/` (6 อักขระ 0-based) และส่งส่วนที่เหลือไปยัง `ServeStatic`

### ServeStatic — การป้องกัน path traversal

```xojo
Private Function ServeStatic(relativePath As String, response As WebResponse) As Boolean
  // Start from the known safe root
  Var f As FolderItem = App.ExecutableFile.Parent.Child("templates").Child("dist")

  // Walk each path segment individually — never concatenate raw user input
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

  // Directory → try index.html automatically
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
    **ไม่เคย** สร้างเส้นทางไฟล์โดยการต่อสตริง URL ดิบ คำขอสำหรับ `/dist/../data/notes.sqlite` จะให้บริการไฟล์ฐานข้อมูลหากเส้นทางสร้างขึ้นโดยตรง การเดินผ่านแต่ละส่วนผ่าน `Child()` และปฏิเสธ `..` และ `.` ป้องกันการโจมตีการเดินทาง path ทั้งหมด

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

ส่วนขยายที่ไม่รู้จักตกอยู่ `application/octet-stream` เพิ่มรายการใหม่ที่นี่หากให้บริการประเภทไฟล์เพิ่มเติม

### การเข้าถึงเอกสาร

พร้อมแอปที่ทำงานบนพอร์ต 8080 เอกสารพัฒนาจะพร้อมใช้ที่:

```
http://localhost:8080/dist/en/index.html
http://localhost:8080/dist/th/index.html
http://localhost:8080/dist/jp/index.html
```

เส้นทาง `/dist/` ถูกจัดการก่อนเส้นทาง SSR ดังนั้นเซิร์ฟเวอร์สแตติกจึงมีลำดับความสำคัญเสมอสำหรับคำนำหน้านั้น
