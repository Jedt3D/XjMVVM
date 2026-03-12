---
title: "ระบบยืนยันตัวตน"
description: วิธีที่ XjMVVM จัดการการลงทะเบียนผู้ใช้, การเข้าสู่ระบบ, การออกจากระบบ, การแฮชรหัสผ่าน, และการยืนยันตัวตนแบบ cookie สำหรับโหมด SSR
---

# ระบบยืนยันตัวตน

การยืนยันตัวตนใน XjMVVM สร้างขึ้นจากสามชั้น: **`UserModel`** จัดเก็บและตรวจสอบข้อมูลประจำตัว, **`BaseViewModel`** มีเมธอด auth ที่ใช้ cookie เพื่อปกป้องเส้นทางและเปิดเผยผู้ใช้ปัจจุบันให้กับเทมเพลต, และ **JavaScript ฝั่งเบราว์เซอร์** เชื่อมช่องว่างเซสชัน SSR สำหรับสถานะเนวิเกชันและข้อความแฟลช

!!! warning
    **`Self.Session` มีค่าเป็น Nil เสมอในโหมด SSR** Xojo Web 2 ของ `WebSession` ต้องการการเชื่อมต่อ WebSocket ที่คงอยู่ ในโหมด SSR บริสุทธิ์ — ซึ่ง `HandleURL` จะคืนค่า `True` เสมอ — ไม่มี WebSocket และไม่มีเซสชัน การยืนยันตัวตนทั้งหมดใช้ cookie ที่ลงนาม HMAC แทน

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
[LoginVM / SignupVM] RedirectWithAuth() -> [Set-Cookie: mvvm_auth=...|JS intermediate page:\nlocalStorage + sessionStorage]
[Set-Cookie: mvvm_auth=...|JS intermediate page:\nlocalStorage + sessionStorage] -> [Redirect to /notes]
[GET any protected route] -> [BaseViewModel.RequireLogin()]
[BaseViewModel.RequireLogin()] ParseAuthCookie() -> [Cookie valid?]
[Cookie valid?] no -> [Redirect /login?next=url]
[Cookie valid?] yes -> [OnGet() / OnPost()]
-->
<!-- ascii
POST /login or /signup
  +-- LoginVM / SignupVM
        +-- UserModel.VerifyPassword() or .Create()
        +-- RedirectWithAuth()
              +-- Set-Cookie: mvvm_auth=userID:username:HMAC
              +-- JS intermediate page sets localStorage + sessionStorage
              +-- Redirect to /notes

GET protected route
  +-- BaseViewModel.RequireLogin()
        +-- ParseAuthCookie() reads + verifies cookie
              +-- invalid -> Redirect /login?next=url
              +-- valid   -> OnGet() / OnPost()
-->
<!-- /diagram -->

---

## UserModel

**ไฟล์:** `Models/UserModel.xojo_code`

`UserModel` สืบทอดจาก `BaseModel` ตารางของมันคือ `users(id, username, password_hash, created_at)` คอลัมน์ `password_hash` จัดเก็บสตริงเดียวในรูปแบบ `hash:salt`

### การแฮช SHA-256 ฝั่งไคลเอนต์

ก่อนฟอร์มการเข้าสู่ระบบหรือการลงทะเบียนถูกส่ง เบราว์เซอร์จะแฮชรหัสผ่านโดยใช้ [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest) เพื่อไม่ให้รหัสผ่านเป็นข้อความธรรมชาติข้ามเครือข่าย:

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0')).join('');
}
</script>
```

Alpine.js ดักจับการส่งฟอร์ม แฮชรหัสผ่าน แล้วส่ง:

```html
<form method="post" action="/login"
      x-data="{
        hashed: false,
        async handleSubmit(e) {
          if (this.hashed) return;
          const pwEl = document.getElementById('password');
          pwEl.value = await sha256hex(pwEl.value);
          this.hashed = true;
          e.target.submit();
        }
      }"
      @submit.prevent="handleSubmit($event)">
```

`hashed` flag ป้องกันการประมวลผลซ้ำ ในกรณีที่ `e.target.submit()` ทำให้ submit event ถูก fire ขึ้นมาอีกครั้งด้วยเหตุใดก็ตาม

!!! note
    `crypto.subtle` พร้อมใช้งานในเบราว์เซอร์สมัยใหม่ทั้งหมด และไม่ต้องการไลบรารี่ใด ๆ มันพร้อมใช้งานเฉพาะในบริบทที่ปลอดภัย (HTTPS หรือ localhost)

### การจัดเก็บรหัสผ่านฝั่งเซิร์ฟเวอร์

เซิร์ฟเวอร์รับแฮช SHA-256 ฝั่งไคลเอนต์ (`SHA256(plaintext)`) เป็นฟิลด์รหัสผ่าน จากนั้นจะใช้แฮชที่สองกับเกลือสุ่มต่อผู้ใช้ก่อนจัดเก็บ:

```xojo
Private Function HashPassword(password As String, salt As String) As String
  // password is already SHA256(plaintext) from the browser
  Return EncodeHex(Crypto.SHA256(password + salt))
End Function
```

ค่าจัดเก็บ: `SHA256(SHA256(plaintext) + salt) : salt`

แบบจำลองแฮชดับเบิลนี้หมายความว่าฐานข้อมูลไม่เคยเห็นรหัสผ่านดั้งเดิมของผู้ใช้แม้ว่าผู้โจมตีจะมีโค้ดต้นทาง `EncodeHex(Crypto.SHA256(...))` ส่งกลับสตริงเลขฐานสิบหก 64 ตัวอักษร — ไม่ใช่สตริงที่มีคุณสมบัติ `.Hex` ฟังก์ชันส่วนกลาง `EncodeHex()` จำเป็น

!!! warning
    การใช้ SHA-256 + เกลือสุ่มต่อผู้ใช้เพียงพอสำหรับแอปพลิเคชันภายในหรือความเสี่ยงต่ำส่วนใหญ่ สำหรับแอปพลิเคชันที่มีความปลอดภัยสูงหรือเผชิญต่อสาธารณะ การใช้การผูก bcrypt หรือ Argon2 ควรใช้หากมีอยู่สำหรับแพลตฟอร์มของคุณ

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

ส่งกลับ `id` ใหม่เมื่อสำเร็จ หรือ `0` ถ้าชื่อผู้ใช้ถูกใช้ไปแล้ว

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
    `stored.Middle(colonPos + 1)` เป็นแบบ 0-based (`String.Middle` จัดตำแหน่งกับ `IndexOf`) ไม่เคยใช้ `Mid()` ที่นี่ — ฟังก์ชันเดิมที่มีพื้นฐาน 1 จะสร้างออฟ-บาย-วันและทำให้การแยกเกลือเสียหาย

---

## การยืนยันตัวตนโดยใช้ Cookie

เนื่องจาก `Self.Session` มีค่าเป็น Nil เสมอในโหมด SSR, XjMVVM ใช้ cookie HTTP ที่ลงนาม HMAC สำหรับการยืนยันตัวตน cookie ถูกตั้งค่าผ่านส่วนหัว HTTP `Set-Cookie` และตรวจสอบในทุกคำขอ

### รูปแบบ Cookie

```
mvvm_auth=<userID>:<username>:<HMAC>
```

HMAC คำนวณเป็น:

```
SHA256(userID + ":" + username + ":" + App.mAuthSecret)
```

`App.mAuthSecret` เป็นสตริงเลขฐานสิบหก 32 ไบต์แบบสุ่มที่สร้างครั้งเดียวในตอนเริ่มต้นผ่าน `Crypto.GenerateRandomBytes(32)` มันเปลี่ยนแปลงในทุกการรีสตาร์ท ซึ่งทำให้ auth cookie ที่มีอยู่ทั้งหมดหมดอายุทันที

### AuthCookieValue — สร้าง Cookie

```xojo
Function AuthCookieValue(userID As Integer, username As String) As String
  Var payload As String = Str(userID) + ":" + username
  Var hmac As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
  Return payload + ":" + hmac
End Function
```

### ParseAuthCookie — ตรวจสอบ Cookie

เรียกในทุกคำขอเพื่อแยกและตรวจสอบผู้ใช้ที่ได้รับการยืนยันตัวตน ผลลัพธ์ถูกแคชต่อคำขอผ่านคุณสมบัติ `mAuthParsed` / `mAuthCache` เพื่อหลายการเรียก (จาก `RequireLogin`, `CurrentUserID`, `Render`) ไม่ต้องแยกวิเคราะห์ใหม่

```xojo
Private Function ParseAuthCookie() As Dictionary
  If mAuthParsed Then Return mAuthCache

  mAuthParsed = True
  mAuthCache = Nil

  // Read the Cookie header
  Var cookieHeader As String = Request.Header("Cookie")
  If cookieHeader.Length = 0 Then Return Nil

  // Find mvvm_auth=... value
  Var value As String = ""  // ... extract from cookie header ...

  // Parse userID:username:hmac
  Var firstColon As Integer = value.IndexOf(":")
  Var lastColon As Integer = value.Length - 65  // HMAC is always 64 hex chars
  If firstColon < 0 Or lastColon < 0 Then Return Nil

  Var userID As String = value.Left(firstColon)
  Var username As String = value.Middle(firstColon + 1, lastColon - firstColon - 2)
  Var receivedHMAC As String = value.Middle(lastColon)

  // Verify HMAC
  Var payload As String = userID + ":" + username
  Var expectedHMAC As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
  If receivedHMAC <> expectedHMAC Then Return Nil

  // Valid — cache and return
  Var result As New Dictionary
  result.Value("user_id") = userID
  result.Value("username") = username
  mAuthCache = result
  Return result
End Function
```

!!! note
    การตรวจสอบ HMAC ช่วยให้ cookie ไม่สามารถปลอมแปลงได้ ผู้โจมตีจะต้องได้ `App.mAuthSecret` เพื่อสร้าง cookie ที่ถูกต้องสำหรับผู้ใช้ใด ๆ

### RedirectWithAuth — ตั้งค่า Cookie เมื่อเข้าสู่ระบบ/ลงทะเบียน

หลังจากการยืนยันตัวตนสำเร็จ `RedirectWithAuth` ทำสามสิ่งในการตอบสนองเดียว:

1. ตั้งค่า cookie `mvvm_auth` ผ่านส่วนหัว HTTP `Set-Cookie`
2. ส่งหน้า JS กลางที่เก็บชื่อผู้ใช้ใน `localStorage` และข้อความแฟลชใน `sessionStorage`
3. เปลี่ยนเส้นทางเบราว์เซอร์ไปยัง URL เป้าหมาย

```xojo
Sub RedirectWithAuth(targetURL As String, userID As Integer, username As String)
  Var cookieVal As String = AuthCookieValue(userID, username)
  Response.Header("Set-Cookie") = "mvvm_auth=" + cookieVal + "; Path=/; SameSite=Lax"
  Response.Header("Content-Type") = "text/html; charset=utf-8"
  Response.Write("<html><body><script>" + _
    "localStorage.setItem('_auth_user','" + username + "');" + _
    "sessionStorage.setItem('_flash_msg','Welcome, " + username + "!');" + _
    "sessionStorage.setItem('_flash_type','success');" + _
    "window.location.href='" + targetURL + "';" + _
    "</script></body></html>")
End Sub
```

หน้า JS กลางจำเป็นเพราะ:

- `Set-Cookie` ตั้งค่า cookie HTTP (สำหรับการยืนยันตัวตนฝั่งเซิร์ฟเวอร์ในคำขอต่อมา)
- `localStorage` เก็บชื่อผู้ใช้ (สำหรับการแสดงสถานะเนวิเกชันฝั่งไคลเอนต์ผ่าน Alpine.js)
- `sessionStorage` เก็บข้อความแฟลช (สำหรับการแสดงครั้งเดียวหลังจากเปลี่ยนเส้นทาง)

กลไกการจัดเก็บสามอันนี้ใช้เพื่อวัตถุประสงค์ที่แตกต่างกันและไม่สามารถแทนที่ซึ่งกันและกันได้

### RedirectWithLogout — ล้าง Cookie

```xojo
Sub RedirectWithLogout(targetURL As String)
  Response.Header("Set-Cookie") = "mvvm_auth=; Path=/; Max-Age=0; SameSite=Lax"
  Response.Header("Content-Type") = "text/html; charset=utf-8"
  Response.Write("<html><body><script>" + _
    "localStorage.removeItem('_auth_user');" + _
    "window.location.href='" + targetURL + "';" + _
    "</script></body></html>")
End Sub
```

`Max-Age=0` บอกเบราว์เซอร์ให้ลบ cookie ทันที

---

## ตัวช่วย BaseViewModel Auth

สี่เมธอดบน `BaseViewModel` ทำให้การยืนยันตัวตนเข้าถึงได้จาก ViewModel ใด ๆ โดยไม่จัดการ cookie โดยตรง:

### `CurrentUserID() As Integer`

```xojo
Function CurrentUserID() As Integer
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return Val(auth.Value("user_id").StringValue)
  Return 0
End Function
```

ส่งกลับ `0` เมื่อไม่ได้รับการยืนยันตัวตน — ศูนย์ไม่เคยเป็นคีย์หลักฐานอุปสรรค `AUTOINCREMENT` ของ SQLite ที่ถูกต้อง

### `CurrentUsername() As String`

```xojo
Function CurrentUsername() As String
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return auth.Value("username").StringValue
  Return ""
End Function
```

### `RequireLogin() As Boolean`

ปกป้องเส้นทาง HTML เปลี่ยนเส้นทางผู้ใช้ที่ไม่ได้รับการยืนยันตัวตนไปยังหน้าเข้าสู่ระบบพร้อมพารามิเตอร์ `next` เพื่อให้พวกเขากลับไป URL ดั้งเดิมหลังจากเข้าสู่ระบบ

```xojo
Function RequireLogin() As Boolean
  If CurrentUserID() > 0 Then Return False
  Redirect("/login?next=" + EncodeURLComponent(Request.Path))
  Return True
End Function
```

รูปแบบการใช้งานใน ViewModel ที่ได้รับการปกป้องใด ๆ:

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard -- stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()` ออกการเปลี่ยนเส้นทาง แต่ **ไม่สามารถหยุดการทำงาน** — มันส่งกลับ `True` เพื่อส่งสัญญาณให้ผู้เรียก จับคู่เสมอกับ `If RequireLogin() Then Return` ลืมคำสั่ง `Return` จะทำให้ตัวจัดการทำงานต่อหลังจากการเปลี่ยนเส้นทางถูกส่งไปแล้ว

### `RequireLoginJSON() As Boolean`

ปกป้องเส้นทาง API ส่งกลับข้อผิดพลาด 401 JSON แทนการเปลี่ยนเส้นทาง (ไคลเอนต์ API ไม่สามารถทำตามการเปลี่ยนเส้นทาง HTML)

```xojo
Function RequireLoginJSON() As Boolean
  If CurrentUserID() > 0 Then Return False
  Response.Status = 401
  WriteJSON("{""error"":""Authentication required""}")
  Return True
End Function
```

การใช้งาน:

```xojo
Sub OnGet()
  If RequireLoginJSON() Then Return
  // ... rest of API handler
End Sub
```

### บริบทที่ฉีดโดยอัตโนมัติ — `current_user`

`BaseViewModel.Render()` ฉีด dictionary `current_user` เสมอในบริบทเทมเพลตทุกอันที่มีค่าเริ่มต้นที่ปลอดภัย เพื่อให้เทมเพลตไม่เคยโยน `UndefinedVariableException`:

```xojo
Var userCtx As New Dictionary()
userCtx.Value("id") = "0"
userCtx.Value("username") = ""
userCtx.Value("logged_in") = "0"

Var auth As Dictionary = ParseAuthCookie()
If auth <> Nil Then
  userCtx.Value("id") = auth.Value("user_id").StringValue
  userCtx.Value("username") = auth.Value("username").StringValue
  userCtx.Value("logged_in") = "1"
End If
context.Value("current_user") = userCtx
```

!!! note
    `logged_in` เป็นสตริง `"1"` หรือ `"0"` — ไม่ใช่ boolean — เพราะค่า `Dictionary` ในเทมเพลต JinjaX ทั้งหมดเป็นสตริง เปรียบเทียบกับ `== "1"`, ไม่ใช่ `== True`

---

## ข้อจำกัดเซสชัน SSR และการแก้ไขฝั่งไคลเอนต์

ใน Xojo Web 2 สถานะ `WebSession` เชื่อมกับการเชื่อมต่อ WebSocket ที่คงอยู่ ในโหมด SSR บริสุทธิ์ — ซึ่ง `HandleURL` ส่งกลับ `True` เสมอและไม่มี WebSocket — คำขอ HTTP แต่ละคำขอจะไม่มีเซสชัน ซึ่งหมายความว่า:

- ข้อความแฟลชที่เก็บไว้ระหว่าง `POST` **จะหายไป** ในเวลา `GET` ที่เปลี่ยนเส้นทางไป
- ชื่อผู้ใช้ที่เข้าสู่ระบบ **ไม่พร้อมใช้งาน** สำหรับการแสดงเทมเพลตจากสถานะเซสชัน
- **`SetFlash()` และ `Session.LogIn()` ทำโดยปริยายว่าไม่มีอะไร** — พวกเขาเขียนไปยังเซสชัน Nil

XjMVVM แก้ไขข้อจำกัดเหล่านี้ด้วยกลไกสามอย่าง:

| กลไก | การจัดเก็บ | วัตถุประสงค์ | อายุการใช้งาน |
|-----------|---------|---------|----------|
| cookie `mvvm_auth` | cookie HTTP | การยืนยันตัวตนฝั่งเซิร์ฟเวอร์ | จนกว่าเบราว์เซอร์จะล้างหรือ `Max-Age=0` |
| `localStorage._auth_user` | localStorage เบราว์เซอร์ | การแสดงเนวิเกชันฝั่งไคลเอนต์ | คงอยู่ในแท็บ/การรีสตาร์ท |
| `sessionStorage._flash_msg` | sessionStorage เบราว์เซอร์ | ข้อความแฟลชแบบครั้งเดียว | แท็บปัจจุบันเท่านั้น อยู่รอดได้จากการเปลี่ยนเส้นทาง |

### ข้อความแฟลช — `sessionStorage`

หน้า JS กลาง (ส่งโดย `RedirectWithAuth`) เขียนข้อความสำเร็จไปยัง `sessionStorage` Alpine.js อ่านและแสดงในการโหลดหน้าถัดไป:

```html
<div x-data="{
  msg: '',
  type: 'success',
  init() {
    var m = sessionStorage.getItem('_flash_msg');
    var t = sessionStorage.getItem('_flash_type') || 'success';
    sessionStorage.removeItem('_flash_msg');
    sessionStorage.removeItem('_flash_type');
    if (m && !document.querySelector('.flash')) { this.msg = m; this.type = t; }
  }
}" x-show="msg" :class="'flash flash-' + type" x-text="msg" style="display:none"></div>
```

### การแสดงข้อผิดพลาดแบบอินไลน์

ข้อผิดพลาดการเข้าสู่ระบบและการลงทะเบียนไม่สามารถใช้ข้อความแฟลช (การเปลี่ยนเส้นทางจะหล่นพวกเขา) แทนนั้น ViewModel จะแสดงฟอร์มใหม่ด้วยตัวแปรเทมเพลต `error_message`:

```xojo
// In LoginVM.OnPost() — on failed login:
Var ctx As New Dictionary
ctx.Value("error_message") = "Invalid username or password."
ctx.Value("next_url") = nextURL
Render("auth/login.html", ctx)
```

เทมเพลตแสดงแบบอินไลน์:

```html
{% if error_message %}
<div class="flash flash-error">{{ error_message }}</div>
{% endif %}
```

### สถานะการยืนยันตัวตนเนวิเกชัน — `localStorage`

Alpine.js อ่าน `localStorage._auth_user` เพื่อแสดงสถานะเนวิเกชันที่ถูกต้อง:

```html
<nav x-data="{ user: localStorage.getItem('_auth_user') }">
  <span x-show="!user">
    <a href="/login">Log In</a>
    <a href="/signup">Sign Up</a>
  </span>
  <span x-show="user" x-cloak>
    <span x-text="user"></span>
    <form method="post" action="/logout"
          @submit="localStorage.removeItem('_auth_user')">
      <button type="submit">Log Out</button>
    </form>
  </span>
</nav>
```

---

## Auth ViewModels

### LoginVM

`GET /login` — แสดงฟอร์มการเข้าสู่ระบบด้วย `error_message = ""` และอ่านพารามิเตอร์ query `next` สำหรับการเปลี่ยนเส้นทางหลังเข้าสู่ระบบ

`POST /login` — ตรวจสอบ username + password ไม่ว่างเปล่า เรียก `UserModel.VerifyPassword()` เมื่อสำเร็จ เรียก `RedirectWithAuth(nextURL, userID, username)` เมื่อล้มเหลว แสดงฟอร์มการเข้าสู่ระบบใหม่ด้วยข้อความข้อผิดพลาดแบบอินไลน์ (ไม่ใช่แฟลช — `SetFlash` เสียหายใน SSR)

### SignupVM

`GET /signup` — แสดงฟ