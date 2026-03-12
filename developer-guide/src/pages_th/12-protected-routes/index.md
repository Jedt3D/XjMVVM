---
title: "เส้นทางที่ป้องกัน & User Scoping"
description: วิธีการป้องกันเส้นทางด้วยการตรวจสอบสิทธิ์และกำหนดขอบเขตข้อมูลต่อผู้ใช้เพื่อให้แต่ละผู้ใช้มองเห็นเฉพาะบันทึกของตนเอง
---

# เส้นทางที่ป้องกัน & User Scoping

XjMVVM v0.9.3 แนะนำสองคุณสมบัติที่เกี่ยวข้องกัน: **เส้นทางที่ป้องกัน** ที่ต้องการการตรวจสอบสิทธิ์ และ **ข้อมูลที่กำหนดขอบเขตตามผู้ใช้** ที่แยกบันทึกต่อผู้ใช้ เมื่อนำมารวมกันจะช่วยให้ผู้ใช้ต้องเข้าสู่ระบบเพื่อเข้าถึงแอปและสามารถดูเฉพาะบันทึกของตนเองเท่านั้น

## เส้นทางที่ป้องกัน

ทุก ViewModel ที่ต้องการการตรวจสอบสิทธิ์จะเรียกใช้เมธอด guard ที่ด้านบนของ `OnGet()` หรือ `OnPost()` มี guard สองตัว — ตัวหนึ่งสำหรับเส้นทาง HTML ตัวหนึ่งสำหรับเส้นทาง API

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 10
#lineWidth: 1.5
[Incoming Request] -> [ViewModel.OnGet() / OnPost()]
[ViewModel.OnGet() / OnPost()] -> [HTML route?]
[HTML route?] yes -> [RequireLogin()|ParseAuthCookie()\nRedirect /login?next=url]
[HTML route?] no -> [RequireLoginJSON()|ParseAuthCookie()\n401 JSON error]
[RequireLogin()] authenticated -> [Handler continues]
[RequireLogin()] not authenticated -> [302 Redirect to /login]
[RequireLoginJSON()] authenticated -> [Handler continues]
[RequireLoginJSON()] not authenticated -> [401 JSON response]
-->
<!-- ascii
Incoming Request
  +-- ViewModel.OnGet() / OnPost()
        +-- HTML route? -> RequireLogin()
        |     +-- authenticated -> handler continues
        |     +-- not authenticated -> 302 /login?next=url
        +-- API route? -> RequireLoginJSON()
              +-- authenticated -> handler continues
              +-- not authenticated -> 401 {"error":"Authentication required"}
-->
<!-- /diagram -->

### Guard เส้นทาง HTML — `RequireLogin()`

```xojo
Sub OnGet()
  If RequireLogin() Then Return
  // ... handler logic (only runs if authenticated)
End Sub
```

`RequireLogin()` เรียกใช้ `ParseAuthCookie()` เพื่อตรวจสอบ cookie `mvvm_auth` ที่ลงนาม HMAC หากไม่ถูกต้องหรือขาด ระบบจะเปลี่ยนเส้นทางไปยัง `/login?next=<encoded-current-path>` เพื่อให้ผู้ใช้กลับไปยังปลายทางเดิมหลังจากเข้าสู่ระบบ

### Guard เส้นทาง API — `RequireLoginJSON()`

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... handler logic
End Sub
```

ไคลเอนต์ API (JavaScript `fetch`, แอปมือถือ, เครื่องมือ CLI) ไม่สามารถตามด้วย HTML redirects `RequireLoginJSON()` จึงส่งกลับสถานะ 401 พร้อมเนื้อหาข้อผิดพลาด JSON แทน:

```json
{"error":"Authentication required"}
```

### เส้นทางใดที่ได้รับการป้องกัน?

เส้นทาง ViewModel ทั้ง 19 เส้นต้องการการตรวจสอบสิทธิ์:

| Resource | Routes | Guard |
|----------|--------|-------|
| Notes (7) | `/notes`, `/notes/new`, `/notes/:id`, `/notes/:id/edit`, `POST /notes`, `POST /notes/:id`, `POST /notes/:id/delete` | `RequireLogin()` |
| Tags (7) | `/tags`, `/tags/new`, `/tags/:id`, `/tags/:id/edit`, `POST /tags`, `POST /tags/:id`, `POST /tags/:id/delete` | `RequireLogin()` |
| API (5) | `/api/notes`, `/api/notes/:id`, `POST /api/notes`, `/api/tags`, `/api/tags/:id` | `RequireLoginJSON()` |

เส้นทาง Auth (`/login`, `/signup`, `/logout`) **ไม่** ได้รับการป้องกัน — ผู้ใช้จะต้องสามารถเข้าถึงได้โดยไม่ต้องเข้าสู่ระบบ

### การเปลี่ยนเส้นทางหลังเข้าสู่ระบบด้วยพารามิเตอร์ `next`

เมื่อ `RequireLogin()` เปลี่ยนเส้นทางไปยัง `/login` ระบบจะเพิ่ม URL ปัจจุบันเป็นพารามิเตอร์ query:

```
/login?next=%2Fnotes%2F42%2Fedit
```

`LoginVM` อ่านพารามิเตอร์ `next` นี้และส่งผ่านไปยัง `RedirectWithAuth()` หลังจากเข้าสู่ระบบสำเร็จ ส่งผู้ใช้กลับไปยังตำแหน่งที่พวกเขาพยายามไป:

```xojo
// In LoginVM.OnPost() — after successful verification:
Var nextURL As String = GetFormValue("next")
If nextURL.Length = 0 Then nextURL = "/notes"
RedirectWithAuth(nextURL, userID, username)
```

---

## ข้อมูลที่กำหนดขอบเขตตามผู้ใช้

บันทึกได้รับการกำหนดขอบเขตต่อผู้ใช้ — แต่ละผู้ใช้มีชุดบันทึกของตนเอง แท็กยังคงเป็นแบบกลาง (ใช้ร่วมกันในทุกผู้ใช้) แต่ยังคงต้องการการเข้าสู่ระบบเพื่อเข้าถึง

### การเปลี่ยนแปลง Database schema

ตาราง `notes` มีคอลัมน์ `user_id`:

```sql
notes (id, title, body, created_at, updated_at, user_id)
```

การอพเกรดใน `DBAdapter.InitDB()` เพิ่มคอลัมน์ให้กับตารางที่มีอยู่:

```xojo
// Add user_id column if it doesn't exist (migration for existing databases)
Var rs As RowSet = db.SelectSQL( _
  "SELECT COUNT(*) AS cnt FROM pragma_table_info('notes') WHERE name='user_id'")
If rs.Column("cnt").IntegerValue = 0 Then
  db.ExecuteSQL("ALTER TABLE notes ADD COLUMN user_id INTEGER NOT NULL DEFAULT 0")
  db.ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id)")
End If
```

`DEFAULT 0` ช่วยให้บันทึกที่มีอยู่ (สร้างก่อนที่จะมี auth) ยังคงสามารถเข้าถึงได้ บันทึกใหม่จะได้รับ ID ของผู้ใช้ที่ได้รับการตรวจสอบสิทธิ์

### NoteModel — เมธอดที่กำหนดขอบเขตตามผู้ใช้

ทุกเมธอด `NoteModel` ต้องการพารามิเตอร์ `userID` ทุกค่า SQL query รวม `WHERE user_id = ?`:

```xojo
Function GetAll(userID As Integer) As Variant()
  Var results() As Variant
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL( _
    "SELECT " + Columns() + " FROM notes WHERE user_id = ? ORDER BY updated_at DESC", userID)
  While Not rs.AfterLastRow
    results.Add(RowToDict(rs))
    rs.MoveToNextRow()
  Wend
  rs.Close()
  db.Close()
  Return results
End Function

Function GetByID(id As Integer, userID As Integer) As Dictionary
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL( _
    "SELECT " + Columns() + " FROM notes WHERE id = ? AND user_id = ?", id, userID)
  // ...
End Function

Function Create(title As String, body As String, userID As Integer) As Integer
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)", title, body, userID)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function

Sub Update(id As Integer, title As String, body As String, userID As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL( _
    "UPDATE notes SET title = ?, body = ?, updated_at = datetime('now') WHERE id = ? AND user_id = ?", _
    title, body, id, userID)
  db.Close()
End Sub

Sub Delete(id As Integer, userID As Integer)
  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("DELETE FROM notes WHERE id = ? AND user_id = ?", id, userID)
  db.Close()
End Sub
```

เมธอดเพิ่มเติมที่กำหนดขอบเขตตามผู้ใช้สำหรับการแบ่งหน้า:

```xojo
Function CountForUser(userID As Integer) As Integer
  Var db As SQLiteDatabase = OpenDB()
  Var rs As RowSet = db.SelectSQL("SELECT COUNT(*) AS cnt FROM notes WHERE user_id = ?", userID)
  Var count As Integer = rs.Column("cnt").IntegerValue
  rs.Close()
  db.Close()
  Return count
End Function

Function FindPaginatedForUser(userID As Integer, limit As Integer, offset As Integer, _
    orderBy As String) As Variant()
  // SELECT ... FROM notes WHERE user_id = ? ORDER BY ... LIMIT ? OFFSET ?
End Function
```

### แนวทาง ViewModel — การส่งผ่าน userID

ทุก Notes ViewModel อ่าน `CurrentUserID()` (จากคุกกี้การตรวจสอบสิทธิ์) และส่งผ่านไปยังโมเดล:

```xojo
Sub OnGet()
  If RequireLogin() Then Return

  Var userID As Integer = CurrentUserID()
  Var model As New NoteModel()
  Var notes() As Variant = model.GetAll(userID)

  Var ctx As New Dictionary
  ctx.Value("notes") = notes
  Render("notes/list.html", ctx)
End Sub
```

แนวทางนี้ช่วยให้:

1. ผู้ใช้จะต้องได้รับการตรวจสอบสิทธิ์ (`RequireLogin`)
2. ผู้ใช้สามารถดูเฉพาะบันทึกของตนเองได้ (`GetAll(userID)`)
3. โมเดลบังคับใช้การกำหนดขอบเขตที่ระดับ SQL (`WHERE user_id = ?`)

### การบังคับใช้ความเป็นเจ้าของ

`GetByID`, `Update` และ `Delete` ล้วนรวม `AND user_id = ?` ในประโยค WHERE ของพวกเขา หากผู้ใช้ A พยายามเข้าถึงบันทึกของผู้ใช้ B โดยเดาหมายเลข ID query จะส่งกลับ `Nil` (หรือส่งผลกระทบ 0 แถว) และ ViewModel จะส่งกลับ 404:

```xojo
// In NotesDetailVM.OnGet():
Var note As Dictionary = model.GetByID(id, userID)
If note Is Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

ไม่มีข้อผิดพลาด "you don't own this" แยกต่างหาก — บันทึกเพียงแค่ไม่มีอยู่จากมุมมองของผู้ใช้ปัจจุบัน

### Tags — เป็นแบบทั่วไป แต่ได้รับการป้องกัน

Tags ใช้ร่วมกันในทุกผู้ใช้ พวกเขาต้องการการเข้าสู่ระบบแต่ไม่ได้รับการกำหนดขอบเขตตามผู้ใช้:

```xojo
// In TagsListVM.OnGet():
Sub OnGet()
  If RequireLogin() Then Return    // must be logged in
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()  // no userID — tags are global
  // ...
End Sub
```

ดีไซน์นี้หมายความว่าผู้ใช้ทั้งหมดใช้คำศัพท์แท็กเดียวกัน แท็กที่สร้างโดยผู้ใช้คนหนึ่งสามารถใช้ได้กับผู้ใช้ทั้งหมด

---

## การทดสอบการเป็นเจ้าของ

`NoteOwnershipTests` ตรวจสอบว่า user scoping ทำงานอย่างถูกต้อง:

```xojo
Sub WrongUserCannotReadTest()
  Var model As New NoteModel()
  Var id As Integer = model.Create("Secret", "body", 999)

  // User 888 should NOT see user 999's note
  Var note As Dictionary = model.GetByID(id, 888)
  Assert.IsNil(note)
End Sub

Sub WrongUserCannotDeleteTest()
  Var model As New NoteModel()
  Var id As Integer = model.Create("Secret", "body", 999)

  // User 888 tries to delete user 999's note — should have no effect
  model.Delete(id, 888)

  // Note should still exist for user 999
  Var note As Dictionary = model.GetByID(id, 999)
  Assert.IsNotNil(note)
End Sub
```

การทดสอบเหล่านี้ใช้ค่า `userID` ที่แตกต่างกัน (999 vs 888) เพื่อพิสูจน์ว่า SQL-level scoping ป้องกันการเข้าถึงข้ามผู้ใช้