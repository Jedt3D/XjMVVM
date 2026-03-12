---
title: "ระบบการตรวจสอบสิทธิ์"
description: วิธีที่ XjMVVM จัดการการลงทะเบียนผู้ใช้ การเข้าสู่ระบบ การออกจากระบบ การแฮช รหัสผ่าน และการตรวจสอบสิทธิ์ตามคุกกี้สำหรับโหมด SSR
---

# ระบบการตรวจสอบสิทธิ์

การตรวจสอบสิทธิ์ใน XjMVVM สร้างขึ้นจากสามชั้น: **`UserModel`** เก็บและตรวจสอบข้อมูลประจำตัว **`BaseViewModel`** จัดเตรียมตัวช่วยด้านการตรวจสอบสิทธิ์ตามคุกกี้ที่ปกป้องเส้นทางและเปิดเผยผู้ใช้ปัจจุบันให้แม่แบบ และ **JavaScript ฝั่งเบราว์เซอร์** เชื่อมช่องว่าง SSR session สำหรับสถานะนำทางและข้อความประกาศ

!!! warning
    **`Self.Session` เป็น Nil เสมอในโหมด SSR** Xojo Web 2 `WebSession` ต้องการการเชื่อมต่อ WebSocket ที่ยั่งยืน ในโหมด SSR บริสุทธิ์ — โดยที่ `HandleURL` ส่งกลับ `True` เสมอ — ไม่มี WebSocket และไม่มี session ทั้งหมดการตรวจสอบสิทธิ์ใช้คุกกี้ที่ลงนามด้วย HMAC แทน

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

`UserModel` สืบทอด `BaseModel` ตารางของมันคือ `users(id, username, password_hash, created_at)` คอลัมน์ `password_hash` เก็บสตริงเดียวในรูปแบบ `hash:salt`

### การแฮช SHA-256 ฝั่งไคลเอ็นต์

ก่อนที่ฟอร์มเข้าสู่ระบบหรือลงทะเบียนจะถูกส่ง เบราว์เซอร์จะแฮชรหัสผ่านโดยใช้ [Web Crypto API](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest) เพื่อที่รหัสผ่านในรูปแบบข้อความธรรมชาติจะไม่ผ่านเครือข่าย:

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0')).join('');
}
</script>
```

Alpine.js ขัดขวางการส่งฟอร์ม แฮชรหัสผ่าน จากนั้นส่ง:

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

ธง `hashed` ป้องกันการประมวลผลซ้ำหาก `e.target.submit()` ไม่ทำให้เหตุการณ์เกิดซ้ำ

!!! note
    `crypto.subtle` พร้อมใช้งานในเบราว์เซอร์สมัยใหม่ทั้งหมดและไม่ต้องใช้ไลบรารี `crypto.subtle` ใช้ได้เฉพาะในบริบทที่ปลอดภัย (HTTPS หรือ localhost)

### การเก็บรหัสผ่านฝั่งเซิร์ฟเวอร์

เซิร์ฟเวอร์รับแฮช SHA-256 ฝั่งไคลเอ็นต์ (`SHA256(plaintext)`) เป็นฟิลด์รหัสผ่าน จากนั้นจึงใช้แฮชที่สองด้วยการสุ่มต่อผู้ใช้ salt ก่อนการจัดเก็บ:

```xojo
Private Function HashPassword(password As String, salt As String) As String
  // password is already SHA256(plaintext) from the browser
  Return EncodeHex(Crypto.SHA256(password + salt))
End Function
```

ค่าที่เก็บ: `SHA256(SHA256(plaintext) + salt) : salt`

โมเดลแฮชคู่นี้หมายความว่าฐานข้อมูลไม่เคยเห็นรหัสผ่านเดิมของผู้ใช้แม้ว่าผู้บุกรุกจะมีซอร์สเซิร์ฟเวอร์ `EncodeHex(Crypto.SHA256(...))` ส่งกลับสตริงเลขฐานสิบหก 64 ตัวอักษร — ไม่ใช่สตริงที่มีคุณสมบัติ `.Hex` จำเป็นต้องใช้ฟังก์ชันส่วนกลาง `EncodeHex()`

!!! warning
    การใช้ SHA-256 + random salt ต่อผู้ใช้นั้นเพียงพอสำหรับแอปพลิเคชันภายในหรือที่มีความเสี่ยงต่ำ สำหรับแอปพลิเคชันที่มีความปลอดภัยสูงหรือเผชิญต่อสาธารณชน ควรใช้การผูก bcrypt หรือ Argon2 หากมีสำหรับแพลตฟอร์มของคุณ

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

ส่งกลับ `id` ใหม่เมื่อสำเร็จ หรือ `0` หากชื่อผู้ใช้ถูกใช้ไปแล้ว

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
    `stored.Middle(colonPos + 1)` มีฐาน 0 (`String.Middle` สอดคล้องกับ `IndexOf`) อย่าใช้ `Mid()` ที่นี่ — ฟังก์ชันเวอร์ชันเดิมที่มีฐาน 1 จะสร้างความผิดพลาดหนึ่งหน่วยและทำให้การแยก salt เสียหาย

---

## การตรวจสอบสิทธิ์ตามคุกกี้

เนื่องจาก `Self.Session` เป็น Nil เสมอในโหมด SSR XjMVVM จึงใช้คุกกี้ HTTP ที่ลงนามด้วย HMAC สำหรับการตรวจสอบสิทธิ์ คุกกี้ถูกตั้งค่าผ่านส่วนหัว HTTP `Set-Cookie` และตรวจสอบการใช้งานในทุกคำขอ

### รูปแบบคุกกี้

```
mvvm_auth=<userID>:<username>:<HMAC>
```

HMAC คำนวณได้ดังนี้:

```
SHA256(userID + ":" + username + ":" + App.mAuthSecret)
```

`App.mAuthSecret` คือสตริง hex 32 ไบต์แบบสุ่มที่สร้างครั้งเดียวเมื่อเริ่มต้นผ่าน `Crypto.GenerateRandomBytes(32)` มันเปลี่ยนแปลงในการรีสตาร์ททุกครั้ง ซึ่งจะทำให้คุกกี้ auth ที่มีอยู่ทั้งหมดไม่ถูกต้องอย่างมีประสิทธิ

### AuthCookieValue — สร้างคุกกี้

```xojo
Function AuthCookieValue(userID As Integer, username As String) As String
  Var payload As String = Str(userID) + ":" + username
  Var hmac As String = EncodeHex(Crypto.SHA256(payload + ":" + App.mAuthSecret))
  Return payload + ":" + hmac
End Function
```

### ParseAuthCookie — ตรวจสอบคุกกี้

เรียกในทุกคำขอเพื่อแยกและตรวจสอบผู้ใช้ที่ได้รับการยืนยันตัวตน ผลลัพธ์จะถูกแคชต่อคำขอผ่านคุณสมบัติ `mAuthParsed` / `mAuthCache` เพื่อให้หลายการเรียก (จาก `RequireLogin` `CurrentUserID` `Render`) ไม่แยกวิเคราะห์ซ้ำ

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
    การตรวจสอบ HMAC ช่วยให้คุกกี้ไม่สามารถปลอมได้ ผู้บุกรุกจะต้องมี `App.mAuthSecret` เพื่อสร้างคุกกี้ที่ถูกต้องสำหรับผู้ใช้รายใดก็ได้

### RedirectWithAuth — ตั้งคุกกี้เมื่อเข้าสู่ระบบ/ลงทะเบียน

หลังจากการตรวจสอบสิทธิ์สำเร็จ `RedirectWithAuth` ทำสามสิ่งในการตอบสนองหนึ่ง:

1. ตั้งคุกกี้ `mvvm_auth` ผ่านส่วนหัว HTTP `Set-Cookie`
2. ส่งหน้า JS ระดับกลางที่เก็บชื่อผู้ใช้ใน `localStorage` และข้อความประกาศในใน `sessionStorage`
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

หน้า JS ระดับกลางนั้นจำเป็นเพราะ:

- `Set-Cookie` ตั้งคุกกี้ HTTP (สำหรับการตรวจสอบสิทธิ์ฝั่งเซิร์ฟเวอร์ในคำขอต่อมา)
- `localStorage` เก็บชื่อผู้ใช้ (สำหรับการแสดงสถานะนำทางฝั่งไคลเอ็นต์ผ่าน Alpine.js)
- `sessionStorage` เก็บข้อความประกาศ (สำหรับการแสดงครั้งเดียวหลังจากเปลี่ยนเส้นทาง)

กลไกการจัดเก็บสามนี้ทำหน้าที่ต่างกันและไม่สามารถแทนที่ได้

### RedirectWithLogout — การล้างคุกกี้

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

`Max-Age=0` บอกเบราว์เซอร์ให้ลบคุกกี้ทันที

---

## ตัวช่วย Auth ของ BaseViewModel

สี่วิธีบน `BaseViewModel` ทำให้การตรวจสอบสิทธิ์สามารถเข้าถึงได้จาก ViewModel ใดก็ได้โดยไม่ต้องจัดการคุกกี้โดยตรง:

### `CurrentUserID() As Integer`

```xojo
Function CurrentUserID() As Integer
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return Val(auth.Value("user_id").StringValue)
  Return 0
End Function
```

ส่งกลับ `0` เมื่อไม่ได้รับการตรวจสอบสิทธิ์ — ศูนย์ไม่มีวันเป็น ID หลักประจำตัว SQLite `AUTOINCREMENT` ที่ถูกต้อง

### `CurrentUsername() As String`

```xojo
Function CurrentUsername() As String
  Var auth As Dictionary = ParseAuthCookie()
  If auth <> Nil Then Return auth.Value("username").StringValue
  Return ""
End Function
```

### `RequireLogin() As Boolean`

ปกป้องเส้นทาง HTML เปลี่ยนเส้นทางผู้ใช้ที่ไม่ได้รับการตรวจสอบสิทธิ์ไปยังหน้าเข้าสู่ระบบด้วยพารามิเตอร์ `next` เพื่อให้พวกเขากลับไปที่ URL เดิมหลังจากเข้าสู่ระบบ

```xojo
Function RequireLogin() As Boolean
  If CurrentUserID() > 0 Then Return False
  Redirect("/login?next=" + EncodeURLComponent(Request.Path))
  Return True
End Function
```

รูปแบบการใช้งานใน ViewModel ที่ได้รับการปกป้องใดก็ได้:

```xojo
Sub OnGet()
  If RequireLogin() Then Return  // guard -- stops execution if redirect issued
  // ... rest of handler
End Sub
```

!!! warning
    `RequireLogin()` ออกการเปลี่ยนเส้นทาง แต่ **ไม่สามารถหยุดการเรียกใช้งาน** — มันส่งกลับ `True` เพื่อส่งสัญญาณผู้เรียก จับคู่กับ `If RequireLogin() Then Return` เสมอ การลืม `Return` จะทำให้ตัวจัดการทำงานต่อไปหลังจากการเปลี่ยนเส้นทางถูกส่งไปแล้ว

### `RequireLoginJSON() As Boolean`

ปกป้องเส้นทาง API ส่งกลับข้อผิดพลาด JSON 401 แทนการเปลี่ยนเส้นทาง (ไคลเอ็นต์ API ไม่สามารถติดตามการเปลี่ยนเส้นทาง HTML)

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

### บริบทที่ฉีดเข้าไปโดยอัตโนมัติ — `current_user`

`BaseViewModel.Render()` ส่งเสมอตัวแปร `current_user` dictionary ลงในทุกบริบทแม่แบบด้วยค่าเริ่มต้นที่ปลอดภัย เพื่อไม่ให้แม่แบบโยน `UndefinedVariableException`:

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
    `logged_in` คือสตริง `"1"` หรือ `"0"` — ไม่ใช่บูลีน — เพราะค่า `Dictionary` ในแม่แบบ JinjaX ทั้งหมดเป็นสตริง เปรียบเทียบกับ `== "1"` ไม่ใช่ `== True`

---

## ข้อจำกัด SSR Session และวิธีการแก้ไขฝั่งไคลเอ็นต์

ใน Xojo Web 2 สถานะ `WebSession` เชื่อมโยงกับการเชื่อมต่อ WebSocket ที่ยั่งยืน ในโหมด SSR บริสุทธิ์ — โดยที่ `HandleURL` ส่งกลับ `True` เสมอและไม่มี WebSocket — แต่ละคำขอ HTTP ไม่มี session นี่หมายความว่า:

- ข้อความประกาศที่เก็บไว้ระหว่าง `POST` จะ **สูญหาย** ตามเวลาที่การเปลี่ยนเส้นทาง `GET` มาถึง
- ชื่อผู้ใช้ที่เข้าสู่ระบบ **ไม่พร้อม** สำหรับตัวเรนเดอร์แม่แบบจากสถานะ session
- **`SetFlash()` และ `Session.LogIn()` ทำเป็นว่าไม่มีอะไร** — พวกมันเขียนไป session Nil

XjMVVM ทำงานรอบข้อจำกัดเหล่านี้ด้วยสามกลไก:

| กลไก | ที่เก็บ | วัตถุประสงค์ | อายุการใช้งาน |
|-----------|---------|---------|----------|
| คุกกี้ `mvvm_auth` | คุกกี้ HTTP | การตรวจสอบสิทธิ์ฝั่งเซิร์ฟเวอร์ | จนกว่าเบราว์เซอร์จะล้างหรือ `Max-Age=0` |
| `localStorage._auth_user` | localStorage ของเบราว์เซอร์ | การแสดงนำทางฝั่งไคลเอ็นต์ | ทั้งทั่วแท็บ/การรีสตาร์ท |
| `sessionStorage._flash_msg` | sessionStorage ของเบราว์เซอร์ | ข้อความประกาศครั้งเดียว | แท็บปัจจุบันเท่านั้น รอดชีวิตจากการเปลี่ยนเส้นทาง |

### ข้อความประกาศ — `sessionStorage`

หน้า JS ระดับกลาง (ส่งโดย `RedirectWithAuth`) เขียนข้อความความสำเร็จไปยัง `sessionStorage` Alpine.js อ่านและแสดงสิ่งนี้ในการโหลดหน้าถัดไป:

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

### การเรนเดอร์ข้อผิดพลาดแบบอินไลน์

ข้อผิดพลาดในการเข้าสู่ระบบและลงทะเบียนไม่สามารถใช้ข้อความประกาศ (การเปลี่ยนเส้นทางจะสูญหาย) แทนที่จะเป็นเช่นนั้น ViewModel จะเรนเดอร์ฟอร์มอีกครั้งด้วยตัวแปรแม่แบบ `error_message`:

```xojo
// In LoginVM.OnPost() — on failed login:
Var ctx As New Dictionary
ctx.Value("error_message") = "Invalid username or password."
ctx.Value("next_url") = nextURL
Render("auth/login.html", ctx)
```

แม่แบบแสดงแบบอินไลน์:

```html
{% if error_message %}
<div class="flash flash-error">{{ error_message }}</div>
{% endif %}
```

### สถานะ auth นำทาง — `localStorage`

Alpine.js อ่าน `localStorage._auth_user` เพื่อแสดงสถานะนำทางที่ถูกต้อง:

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

`GET /login` — เรนเดอร์ฟอร์มเข้าสู่ระบบด้วย `error_message = ""` และอ่านพารามิเตอร์คิวรี `next` สำหรับการเปลี่ยนเส้นทางหลังจากเข้าสู่ระบบ

`POST /login` — ตรวจสอบความถูกต้องชื่อผู้ใช้ + รหัสผ่านไม่ว่างเปล่า เรียก `UserModel.VerifyPassword()` เมื่อสำเร็จ เรียก `RedirectWithAuth(nextURL, userID, username)` เมื่อล้มเหลว เรนเดอร์ฟอร์มเข้าสู่ระบบอีกครั้งด้วยข้อความแสดงข้อผิดพลาดแบบอินไลน์ (ไม่ใช่