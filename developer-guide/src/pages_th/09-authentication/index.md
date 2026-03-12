---
title: "ระบบ Auth"
description: วิธีการ XjMVVM จัดการการลงทะเบียนผู้ใช้ การเข้าสู่ระบบ การออกจากระบบ การแฮชรหัสผ่าน และการป้องกันเส้นทางต่อ request
---

# ระบบ Auth

Authentication ใน XjMVVM สร้างขึ้นข้ามสามชั้น: **`UserModel`** เก็บและตรวจสอบข้อมูลประจำตัว **`Session`** คลาสติดตามว่าใครเข้าสู่ระบบ และ **`BaseViewModel`** ให้ helpers ที่ป้องกันเส้นทางและเปิดเผยผู้ใช้ปัจจุบันต่อเทมเพลต

## ภาพรวม

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 10
#lineWidth: 1.5
[POST /login or /signup] -> [LoginVM / SignupVM]
[LoginVM / SignupVM] verify -> [UserModel|FindByUsername()\nVerifyPassword()\nCreate()]
[UserModel] result -> [LoginVM / SignupVM]
[LoginVM / SignupVM] LogIn(id, username) -> [Session|CurrentUserID\nCurrentUsername\nIsLoggedIn()]
[Session] -> [Redirect to /]
[GET any protected route] -> [BaseViewModel.RequireLogin()]
[BaseViewModel.RequireLogin()] not logged in -> [Redirect /login]
[BaseViewModel.RequireLogin()] logged in -> [OnGet() / OnPost()]
-->
<!-- ascii
POST /login or /signup
  └── LoginVM / SignupVM
        ├── UserModel.VerifyPassword() or .Create()
        └── Session.LogIn(id, username) → Redirect /

GET protected route
  └── BaseViewModel.RequireLogin()
        ├── not logged in → Redirect /login
        └── logged in → OnGet() / OnPost()
-->
<!-- /diagram -->

---

## UserModel

**ไฟล์:** `Models/UserModel.xojo_code`

`UserModel` สืบทอด `BaseModel` ตารางของมันคือ `users(id, username, password_hash, created_at)` คอลัมน์ `password_hash` เก็บสตริงเดียวในรูปแบบ `hash:salt`

### การแฮชรหัสผ่าน

Xojo ไม่มีการผูกมัด bcrypt ในไลบรารีมาตรฐาน เฟรมเวิร์กใช้ **SHA-256 ด้วย salt แบบสุ่ม** — ทางเลือกที่ได้รับความเข้าใจอย่างดี ซึ่งปลอดภัยเมื่อ salt เป็นแบบสุ่มและเก็บไว้ต่อผู้ใช้

```xojo
Private Function GenerateSalt() As String
  // Time + random number — unique per call
  Var raw As String = Str(System.Ticks) + Str(Rnd)
  Return EncodeHex(Crypto.SHA256(raw))
End Function

Private Function HashPassword(password As String, salt As String) As String
  Return EncodeHex(Crypto.SHA256(password + salt))
End Function
```

แฮชและ salt รวมกันเป็นคอลัมน์เดียวด้วยตัวแยก `:`:

```xojo
Var stored As String = hash + ":" + salt  // e.g. "a3f9...b2:e7c1...44"
```

เก็บสคีมาไว้ง่าย ๆ — ไม่มีคอลัมน์ `salt` แยก — และทำให้ `VerifyPassword` ฟังก์ชันที่อิสระ

!!! note
    ใช้ SHA-256 + per-user random salt เหมาะสำหรับแอปพลิเคชันภายในหรือ low-risk ส่วนใหญ่ สำหรับแอปพลิเคชัน high-security หรือ public-facing การผูกมัด bcrypt หรือ Argon2 ควรใช้หากมี ไปยัง platform

### การสร้างผู้ใช้

```xojo
Function Create(username As String, password As String) As Integer
  // Reject duplicate usernames before hashing
  If FindByUsername(username) <> Nil Then Return 0

  Var salt As String = GenerateSalt()
  Var hash As String = HashPassword(password, salt)
  Var stored As String = hash + ":" + salt

  Var db As SQLiteDatabase = OpenDB()
  db.ExecuteSQL("INSERT INTO users (username, password_hash) VALUES (?, ?)", username, stored)
  Var newID As Integer = db.LastRowID
  db.Close()
  Return newID
End Function
```

ส่งคืน `id` ใหม่ที่สำเร็จ หรือ `0` หากชื่อผู้ใช้ถูกนำไปแล้ว การตรวจสอบความเป็นเอกลักษณ์ทำได้ที่ชั้นแอปพลิเคชัน (`FindByUsername`) แทนที่จะพึ่งพา `UNIQUE` constraint เพียงอย่างเดียว — นี่ให้สัญญาณที่สะอาด (การส่งคืน `0`) โดยไม่จำเป็นต้องจับข้อผิดพลาดฐานข้อมูล

### การตรวจสอบรหัสผ่าน

```xojo
Function VerifyPassword(username As String, password As String) As Boolean
  Var row As Dictionary = FindByUsername(username)
  If row = Nil Then Return False

  Var stored As String = row.Value("password_hash").StringValue
  Var colonPos As Integer = stored.IndexOf(":")
  If colonPos < 0 Then Return False

  Var hash As String = stored.Left(colonPos)
  Var salt As String = stored.Middle(colonPos + 1)
  Return HashPassword(password, salt) = hash
End Function
```

!!! warning
    `stored.Middle(colonPos + 1)` คือ 0-based (`String.Middle` ตรงกับ `IndexOf`) ไม่เคยใช้ `Mid()` ที่นี่ — ฟังก์ชัน legacy ที่อิง 1 จะสร้าง off-by-one และเสียสาล salt

---

## Session

**ไฟล์:** `Session.xojo_code` (ขยาย `WebSession`)

`Session` เก็บ **session properties** — ไม่ใช่ตัวแปรชั่วคราว Identity ผู้ใช้ที่ตรวจสอบแล้ว WebSession properties ถูกกำหนดขอบเขตโดยอัตโนมัติต่อผู้ใช้และคงอยู่ตลอด lifetime ของการเชื่อมต่อ WebSocket

```xojo
Protected Class Session
Inherits WebSession

  Sub LogIn(userID As Integer, username As String)
    CurrentUserID = userID
    CurrentUsername = username
  End Sub

  Sub LogOut()
    CurrentUserID = 0
    CurrentUsername = ""
  End Sub

  Function IsLoggedIn() As Boolean
    Return CurrentUserID > 0
  End Function

  // ...flash message methods unchanged from v0.2.0...

  CurrentUserID   As Integer   // 0 = not logged in
  CurrentUsername As String
End Class
```

`CurrentUserID = 0` คือเซนทิเนลสำหรับ "ไม่ได้เข้าสู่ระบบ" — ศูนย์ไม่เคยเป็นค่า SQLite `AUTOINCREMENT` primary key ที่ถูกต้อง

---

## BaseViewModel auth helpers

วิธีสามวิธีถูกเพิ่มไปยัง `BaseViewModel` เพื่อให้ auth เข้าถึงได้จากใด ๆ ViewModel โดยไม่ต้องแคสต์ `Session` โดยตรง:

### `RequireLogin() As Boolean`

```xojo
Function RequireLogin() As Boolean
  Var ws As WebSession = Self.Session
  If ws IsA Session Then
    Var sess As Session = Session(ws)
    If Not sess.IsLoggedIn() Then
      SetFlash("Please log in to continue", "info")
      Redirect("/login")
      Return True  // ← caller must check this and return
    End If
  End If
  Return False
End Function
```

รูปแบบการใช้ใน ViewModel ที่ป้องกัน:

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard — stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()` ปัญหา redirect แต่ **ไม่สามารถหยุดการทำให้ยิ่ง** — มันส่งคืน `True` เพื่อสัญญาณผู้เรียก ตรงกับ `If RequireLogin() Then Return` เสมอ ลืม `Return` จะทำให้ handler ดำเนินการต่อหลังจาก redirect ส่งไปแล้ว ส่งผลให้เกิดข้อผิดพลาดการเขียนสองครั้ง

### `CurrentUserID()` และ `CurrentUsername()`

```xojo
Function CurrentUserID() As Integer
  Var ws As WebSession = Self.Session
  If ws IsA Session Then Return Session(ws).CurrentUserID
  Return 0
End Function

Function CurrentUsername() As String
  Var ws As WebSession = Self.Session
  If ws IsA Session Then Return Session(ws).CurrentUsername
  Return ""
End Function
```

สิ่งเหล่านี้ให้การเข้าถึง session state ที่ปลอดภัยโดยไม่ต้องผู้เรียกแคสต์ `WebSession` ไปยัง `Session` ด้วยตนเอง

### Auto-injected `current_user` context

`BaseViewModel.Render()` อัตโนมัติฉีด `current_user` dictionary เข้าไปในทุกบริบท template:

```xojo
Var userCtx As New Dictionary()
userCtx.Value("id")        = Str(sess.CurrentUserID)
userCtx.Value("username")  = sess.CurrentUsername
userCtx.Value("logged_in") = If(sess.IsLoggedIn(), "1", "0")
context.Value("current_user") = userCtx
```

ทุก template สามารถแตกแขนงในสถานะ login โดยไม่ต้องให้ ViewModel ผ่านมันไป:

```html
{% if current_user.logged_in == "1" %}
  <span>{{ current_user.username }}</span>
  <form method="post" action="/logout">
    <button type="submit">Log out</button>
  </form>
{% else %}
  <a href="/login">Log in</a>
{% endif %}
```

!!! note
    `logged_in` คือสตริง `"1"` หรือ `"0"` — ไม่ใช่บูลีน — เพราะค่า `Dictionary` ในเทมเพลต JinjaX เป็นสตริงทั้งหมด เปรียบเทียบกับ `== "1"` ไม่ใช่ `== True`

---

## Auth ViewModels

### LoginVM

`GET /login` — อปสร shader ฟอร์มเข้าสู่ระบบ หากเข้าสู่ระบบแล้ว ให้เปลี่ยนเส้นทาง `/`

`POST /login` — ตรวจสอบชื่อผู้ใช้ + รหัสผ่านไม่ว่าง จากนั้นเรียก `UserModel.VerifyPassword()` สำเร็จจะเรียก `Session.LogIn()` และ redirect บ้านด้วยข้อความ flash ล้มเหลว redirect กลับไป `/login` พร้อมข้อความแสดงข้อผิดพลาด

### SignupVM

`GET /signup` — อปสร shader ฟอร์มสมัครสมาชิก หากเข้าสู่ระบบแล้ว ให้เปลี่ยนเส้นทาง `/`

`POST /signup` — ตรวจสอบ: ชื่อผู้ใช้ต้องระบุ ≥3 ตัวอักษร รหัสผ่าน ≥6 ตัวอักษร รหัสผ่านตรงกัน เรียก `UserModel.Create()` หากส่งคืน `0` (ชื่อผู้ใช้นำไป) redirect กลับพร้อมข้อผิดพลาด สำเร็จ ทันที เรียก `Session.LogIn()` ดังนั้นผู้ใช้เข้าสู่ระบบหลังสร้างบัญชีของพวกเขา

### LogoutVM

`POST /logout` เท่านั้น — GET ไม่สนับสนุน เรียก `Session.LogOut()` และ redirect บ้าน ใช้ POST สำหรับ logout ป้องกัน logout เผลอผ่าน prefetch หรือ link pre-loading

---

## เส้นทาง Auth

```xojo
mRouter.Get("/login",   AddressOf CreateLoginVM)
mRouter.Post("/login",  AddressOf CreateLoginVM)
mRouter.Post("/logout", AddressOf CreateLogoutVM)
mRouter.Get("/signup",  AddressOf CreateSignupVM)
mRouter.Post("/signup", AddressOf CreateSignupVM)
```

ทั้ง `GET` และ `POST` สำหรับ login และ signup แบ่ง ViewModel factory เดียวกัน — ViewModel เองแยกส่วนไปยัง `OnGet()` หรือ `OnPost()` ตาม `Request.Method`

---

## สคีมา

ตาราง `users` ถูกสร้างใน `DBAdapter.InitDB()`:

```xojo
db.ExecuteSQL("CREATE TABLE IF NOT EXISTS users (" + _
  "id            INTEGER PRIMARY KEY AUTOINCREMENT, " + _
  "username      TEXT NOT NULL UNIQUE, " + _
  "password_hash TEXT NOT NULL, " + _
  "created_at    TEXT DEFAULT (datetime('now')))")
```

ข้อ จำกัด `UNIQUE` บน `username` คือเครือข่ายความปลอดภัยระดับฐานข้อมูล การตรวจสอบระดับแอปพลิเคชันใน `UserModel.Create()` ให้สัญญาณที่สะอาด (ส่งคืน `0`) ที่ใช้โดย ViewModels เพื่อแสดงข้อความแสดง flash "ชื่อผู้ใช้นำไปแล้ว"
