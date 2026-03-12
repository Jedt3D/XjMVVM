---
title: "เส้นทางที่ปกป้อง & การจำกัดขอบเขตข้อมูลต่อผู้ใช้"
description: วิธีการปกป้องเส้นทางด้วยการยืนยันตัวตน และจำกัดข้อมูลต่อผู้ใช้เพื่อให้ผู้ใช้แต่ละคนเห็นเฉพาะบันทึกของตัวเองเท่านั้น
---

# เส้นทางที่ปกป้อง & การจำกัดขอบเขตข้อมูลต่อผู้ใช้

XjMVVM v0.9.3 นำเสนอฟีเจอร์ที่เกี่ยวข้องกันสองประการ: **เส้นทางที่ปกป้อง** ซึ่งต้องการการยืนยันตัวตน และ **ข้อมูลที่จำกัดต่อผู้ใช้** ที่แยกบันทึกต่อผู้ใช้ รวมกันแล้ว ระบบจึงมั่นใจว่าผู้ใช้จะต้องเข้าสู่ระบบเพื่อเข้าถึงแอปพลิเคชันและสามารถเห็นได้เฉพาะบันทึกของตัวเองเท่านั้น

## เส้นทางที่ปกป้อง

ViewModel ที่ต้องการการยืนยันตัวตนจะเรียกเมธอด guard ที่ด้านบนสุดของ `OnGet()` หรือ `OnPost()` มีสองเมธอด guard — วิธีหนึ่งสำหรับเส้นทาง HTML และอีกวิธีหนึ่งสำหรับเส้นทาง API

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

### วิธีป้องกันเส้นทาง HTML — `RequireLogin()`

```xojo
Sub OnGet()
  If RequireLogin() Then Return
  // ... handler logic (only runs if authenticated)
End Sub
```

`RequireLogin()` เรียก `ParseAuthCookie()` เพื่อตรวจสอบ Cookie `mvvm_auth` ที่ได้รับการเซ็นชื่อ HMAC หากไม่ถูกต้องหรือหายไป ระบบจะเปลี่ยนเส้นทางไปยัง `/login?next=<encoded-current-path>` เพื่อให้ผู้ใช้กลับไปที่จุดหมายปลายทางดั้งเดิมหลังจากเข้าสู่ระบบ

### วิธีป้องกันเส้นทาง API — `RequireLoginJSON()`

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... handler logic
End Sub
```

ไคลเอนต์ API (JavaScript `fetch`, แอปมือถือ, เครื่องมือ CLI) ไม่สามารถติดตามการ redirect แบบ HTML ได้ `RequireLoginJSON()` จะส่งกลับสถานะ 401 พร้อม error body แบบ JSON แทน:

```json
{"error":"Authentication required"}
```

### เส้นทางใดที่ได้รับการปกป้อง?

ทั้ง 19 เส้นทาง ViewModel ต้องการการยืนยันตัวตน:

| ทรัพยากร | เส้นทาง | วิธีป้องกัน |
|----------|--------|-------|
| Notes (7) | `/notes`, `/notes/new`, `/notes/:id`, `/notes/:id/edit`, `POST /notes`, `POST /notes/:id`, `POST /notes/:id/delete` | `RequireLogin()` |
| Tags (7) | `/tags`, `/tags/new`, `/tags/:id`, `/tags/:id/edit`, `POST /tags`, `POST /tags/:id`, `POST /tags/:id/delete` | `RequireLogin()` |
| API (5) | `/api/notes`, `/api/notes/:id`, `POST /api/notes`, `/api/tags`, `/api/tags/:id` | `RequireLoginJSON()` |

เส้นทางการยืนยันตัวตน (`/login`, `/signup`, `/logout`) **ไม่** ได้รับการปกป้อง — ผู้ใช้จะต้องสามารถเข้าถึงได้โดยไม่ต้องเข้าสู่ระบบ

### เปลี่ยนเส้นทางหลังการเข้าสู่ระบบด้วยพารามิเตอร์ `next`

เมื่อ `RequireLogin()` เปลี่ยนเส้นทางไปยัง `/login` ระบบจะเพิ่ม URL ปัจจุบันเป็นพารามิเตอร์ query:

```
/login?next=%2Fnotes%2F42%2Fedit
```

`LoginVM` อ่านพารามิเตอร์ `next` นี้และส่งผ่านไปยัง `RedirectWithAuth()` หลังจากการเข้าสู่ระบบสำเร็จ ส่งผู้ใช้กลับไปยังจุดที่พวกเขากำลังพยายามไป:

```xojo
// In LoginVM.OnPost() — after successful verification:
Var nextURL As String = GetFormValue("next")
If nextURL.Length = 0 Then nextURL = "/notes"
RedirectWithAuth(nextURL, userID, username)
```

---

## ข้อมูลที่จำกัดต่อผู้ใช้

บันทึกถูกจำกัดต่อผู้ใช้ — ผู้ใช้แต่ละคนมีชุดบันทึกของตัวเอง แท็กยังคงเป็นส่วนกลาง (แชร์ในทุกผู้ใช้) แต่ยังคงต้องการการเข้าสู่ระบบเพื่อเข้าถึง

### การเปลี่ยนแปลงโครงสร้างฐานข้อมูล

ตาราง `notes` มีคอลัมน์ `user_id`:

```sql
notes (id, title, body, created_at, updated_at, user_id)
```

Migration ใน `DBAdapter.InitDB()` เพิ่มคอลัมน์ลงในตารางที่มีอยู่:

```xojo
// Add user_id column if it doesn't exist (migration for existing databases)
Var rs As RowSet = db.SelectSQL( _
  "SELECT COUNT(*) AS cnt FROM pragma_table_info('notes') WHERE name='user_id'")
If rs.Column("cnt").IntegerValue = 0 Then
  db.ExecuteSQL("ALTER TABLE notes ADD COLUMN user_id INTEGER NOT NULL DEFAULT 0")
  db.ExecuteSQL("CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id)")
End If
```

`DEFAULT 0` มั่นใจว่าบันทึกที่มีอยู่ก่อน (สร้างขึ้นก่อนการมีอยู่ของการยืนยันตัวตน) ยังคงสามารถเข้าถึงได้ บันทึกใหม่ได้รับ ID ของผู้ใช้ที่ผ่านการยืนยันตัวตน

### NoteModel — เมธอดที่จำกัดต่อผู้ใช้

ทุกเมธอด `NoteModel` ต้องการพารามิเตอร์ `userID` ทุกคำสั่ง SQL รวมถึง `WHERE user_id = ?`:

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

เมธอดเพิ่มเติมที่จำกัดต่อผู้ใช้สำหรับการแบ่งหน้า:

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

### รูปแบบ ViewModel — การส่งผ่าน userID

ViewModel Notes ทุกอันอ่าน `CurrentUserID()` (จาก Cookie การยืนยันตัวตน) และส่งผ่านไปยังโมเดล:

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

รูปแบบนี้มั่นใจว่า:

1. ผู้ใช้จะต้องผ่านการยืนยันตัวตน (`RequireLogin`)
2. ผู้ใช้สามารถเห็นเฉพาะบันทึกของตัวเองได้เท่านั้น (`GetAll(userID)`)
3. โมเดลบังคับการจำกัดขอบเขตที่ระดับ SQL (`WHERE user_id = ?`)

### การบังคับใช้ความเป็นเจ้าของ

`GetByID`, `Update` และ `Delete` ทั้งหมดมีคำสั่ง `AND user_id = ?` ใน WHERE clause หากผู้ใช้ A พยายามเข้าถึงบันทึกของผู้ใช้ B โดยการเดาอย่างตัวเลข คำสั่ง SQL จะส่งกลับ `Nil` (หรือส่งผลกระทบต่อ 0 แถว) และ ViewModel จะส่งกลับ 404:

```xojo
// In NotesDetailVM.OnGet():
Var note As Dictionary = model.GetByID(id, userID)
If note Is Nil Then
  RenderError(404, "Note not found")
  Return
End If
```

ไม่มีข้อผิดพลาดแยกต่างหาก "คุณไม่เป็นเจ้าของสิ่งนี้" — บันทึกนั้นไม่มีอยู่จากมุมมองของผู้ใช้ปัจจุบัน

### Tags — กลาง แต่ได้รับการปกป้อง

Tags ถูกแชร์ในทุกผู้ใช้ พวกเขาต้องการการเข้าสู่ระบบ แต่ไม่ได้ถูกจำกัดขอบเขตโดยผู้ใช้:

```xojo
// In TagsListVM.OnGet():
Sub OnGet()
  If RequireLogin() Then Return    // must be logged in
  Var model As New TagModel()
  Var tags() As Variant = model.GetAll()  // no userID — tags are global
  // ...
End Sub
```

การออกแบบนี้หมายความว่าผู้ใช้ทั้งหมดแชร์คำศัพท์แท็กเดียวกัน แท็กที่สร้างขึ้นโดยผู้ใช้หนึ่งจะพร้อมใช้งานสำหรับผู้ใช้ทั้งหมด

---

## ทดสอบความเป็นเจ้าของ

`NoteOwnershipTests` ตรวจสอบว่าการจำกัดขอบเขตของผู้ใช้ทำงานอย่างถูกต้อง:

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

การทดสอบเหล่านี้ใช้ค่า `userID` ที่แตกต่างกัน (999 เทียบกับ 888) เพื่อพิสูจน์ว่าการจำกัดขอบเขตระดับ SQL ป้องกันการเข้าถึงข้ามผู้ใช้