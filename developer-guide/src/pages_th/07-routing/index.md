---
title: "สถาปัตยกรรมการกำหนดเส้นทาง"
description: วิธีการไหลของคำขอ HTTP ผ่าน HandleURL เมื่อ Xojo เข้ามาทำงาน และวิธีการข้ามอย่างปลอดภัยระหว่างโลก SSR และตัวควบคุม WebPage ของ Xojo
---

# สถาปัตยกรรมการกำหนดเส้นทาง

## สองโลกข้างในแอปพลิเคชันเดียว

แอปพลิเคชัน Xojo Web 2 โฮสต์ระบบจัดการคำขอสองระบบที่แตกต่างกันโดยพื้นฐาน พร้อมกันทั้งสอง ทุกคำขอ HTTP เข้ามาผ่าน `HandleURL` และค่าที่ส่งคืนจะตัดสินใจว่าโลกใดจะจัดการมัน

| โลก | จุดเข้า | การตอบสนอง |
|-------|-------------|----------|
| **MVVM (SSR)** | `HandleURL` → Router → ViewModel → JinjaX | Plain HTTP, stateless HTML |
| **Xojo WebPage** | Bootstrap HTML → WebSocket → Session → controls | Stateful, event-driven UI |

- `Return True` — แอปนี้จัดการแล้ว Xojo ไม่ทำอะไรต่อไป
- `Return False` — Xojo จัดการ (ให้บริการ bootstrap HTML, ไฟล์ JS framework หรือข้อความ WebSocket)

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 40
#padding: 10
#lineWidth: 1.5
[Browser] -> [HandleURL: App.HandleURL]
[HandleURL: App.HandleURL] Return True -> [MVVM SSR]
[HandleURL: App.HandleURL] Return False -> [Xojo Framework]
[MVVM SSR] -> [ViewModel]
[ViewModel] HTML -> [Browser]
[Xojo Framework] -> [WebSocket Session]
[WebSocket Session] UI events -> [Browser]
-->
<!-- ascii
Browser
  │
  ▼
App.HandleURL
  ├─ Return True  →  MVVM SSR  →  ViewModel  →  HTML  →  Browser
  └─ Return False →  Xojo Framework  →  WebSocket Session  →  Browser
-->
<!-- /diagram -->

---

## แผนผังการตัดสินใจ HandleURL

`HandleURL` ใช้ลำดับการตรวจสอบที่ตายตัวก่อนส่งคำขอใดๆ การ normalize path มาก่อนเสมอ — ทุกการเปรียบเทียบขึ้นอยู่กับมัน

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 32
#padding: 8
#lineWidth: 1.5
[Browser GET path] -> [Normalize path]
[Normalize path] -> [p = "/" AND _xojo=1?]
[p = "/" AND _xojo=1?] Yes -> [Return False: Xojo bootstrap]
[p = "/" AND _xojo=1?] No -> [p = "/tests"?]
[p = "/tests"?] Yes -> [302 redirect to /?_xojo=1]
[302 redirect to /?_xojo=1] -> [Return True]
[p = "/tests"?] No -> [Router.Route(...)]
[Router.Route(...)] matched -> [ViewModel handles request]
[ViewModel handles request] -> [Return True]
[Router.Route(...)] no match -> [Return False: Xojo serves file]
-->
<!-- ascii
Browser GET path
  │
  ▼
Normalize: prepend "/" if missing, strip trailing "/"
  │
  ├─ p = "/" AND QueryString = "_xojo=1"
  │     └── Return False  →  Xojo serves bootstrap HTML
  │
  ├─ p = "/tests"
  │     └── 302 redirect to /?_xojo=1  →  Return True
  │
  └─ all other paths
        └── Router.Route(...)
              ├─ matched  →  ViewModel.Handle()  →  Return True
              └─ no match →  Return False  →  Xojo serves JS/CSS/WebSocket
-->
<!-- /diagram -->

### พฤติกรรมพิเศษของ `request.Path`

!!! warning
    Xojo Web 2 ละเว้น `/` นำหน้าจาก `request.Path` คำขอไป `/notes` มาถึงพร้อม `request.Path = "notes"` ไม่ใช่ `"/notes"` ทุกการเปรียบเทียบเส้นทางล้มเหลวเงียบๆ โดยไม่มีการปกติ

ปกติเสมอก่อนการตรวจสอบเส้นทางใดๆ:

```xojo
Var p As String = request.Path
If p.Left(1) <> "/" Then p = "/" + p
If p.Length > 1 And p.Right(1) = "/" Then p = p.Left(p.Length - 1)
```

โดยไม่มีสิ่งนี้ `"notes" <> "/notes"` ประเมินเป็น `True` โดยไม่มีข้อผิดพลาด — ทุกการจับคู่เส้นทางล้มเหลว

---

## MVVM Request Pipeline

สำหรับเส้นทาง SSR ที่จับคู่ได้ ท่อ pipeline เต็มรูปแบบจาก `HandleURL` ไปยังการตอบสนอง HTML:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 28
#padding: 8
#lineWidth: 1.5
[HandleURL] normalize + match -> [Router]
[Router] factory.Invoke() -> [ViewModel]
[ViewModel] OnGet / OnPost -> [Model]
[<database> Model] Dictionary -> [ViewModel]
[ViewModel] context -> [JinjaX Template]
[JinjaX Template] HTML string -> [response.Write]
[response.Write] Return True -> [Browser]
-->
<!-- ascii
HandleURL  →  normalize path, match route
Router     →  factory.Invoke()  →  new ViewModel
ViewModel  →  OnGet() / OnPost()
Model      →  returns Dictionary / Variant() of Dictionary
ViewModel  →  builds context Dictionary
JinjaX     →  CompiledTemplate.Render(context)  →  HTML string
response.Write(html)  →  Return True  →  Browser
-->
<!-- /diagram -->

เพราะว่าเส้นทาง SSR ส่งกลับ `True` Xojo จึงไม่มีวาระสร้าง WebSocket session สำหรับมัน นี่หมายความว่าตัวควบคุม Xojo WebPage (`WebLabel` `WebListBox` เป็นต้น) ไม่สามารถใช้จาก ViewModel ได้ และไม่มีการ push แบบเรียลไทม์จากเซิร์ฟเวอร์ไปยังเบราว์เซอร์โดยไม่เพิ่ม Server-Sent Events หรือ JS polling แยกต่างหาก

---

## การเปลี่ยนเส้นทาง `/tests`

โปรแกรมรันเทส (`XojoUnitTestPage`) คือ Xojo WebPage — ต้องการ WebSocket session ที่ใช้งานอยู่ การไปถึงที่นั่นจากลิงก์ MVVM ต้องการลำดับการเต้นรำสามขั้น

### เหตุใดคุณจึงไม่สามารถใช้ `Return False` ที่ `/tests` ได้

Xojo เสิร์ฟ bootstrap HTML ของมัน ที่ **เส้นทางราก** `/` เท่านั้น สำหรับเส้นทางอื่นๆ การส่งกลับ `False` จะสร้างเบราว์เซอร์ 404 เปล่า — ไม่ใช่เทมเพลต MVVM 404 เพียงเพจข้อผิดพลาดเบราว์เซอร์

### เหตุใด `DefaultWindow=XojoUnitTestPage` ทำให้เกิด Crash

การตั้งค่า `DefaultWindow=XojoUnitTestPage` ในโครงการทำให้ Xojo สร้าง instance มันเป็น WebPage แรกเมื่อเซสชันเชื่อมต่อ แต่ `XojoUnitTestPage.Opening` เรียกใช้การตั้งค่าแถบเครื่องมือและการลงทะเบียนเทส — โค้ดที่ต้องการให้เพจและเซสชันมีเส้นลวดเต็ม ในเวลา bootstrap มันไม่มี ผลลัพธ์: crash ในเวลาทำงาน

### สิ่งที่ใช้ได้จริง

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 32
#padding: 8
#lineWidth: 1.5
[Browser: GET /tests] -> [HandleURL]
[HandleURL] 302 /?_xojo=1 -> [Browser: follows redirect]
[Browser: follows redirect] -> [HandleURL: GET /?_xojo=1]
[HandleURL: GET /?_xojo=1] Return False -> [Xojo Bootstrap]
[Xojo Bootstrap] WebSocket established -> [Default: Shown event]
[Default: Shown event] testPage.Show() -> [XojoUnitTestPage]
[XojoUnitTestPage] Opening + Shown -> [Browser: Test Runner UI]
-->
<!-- ascii
Browser GET /tests
  │
HandleURL: 302 redirect to /?_xojo=1  →  Return True
  │
Browser follows redirect → GET /?_xojo=1
  │
HandleURL: Return False  (bypasses Router)
  │
Xojo serves bootstrap HTML → Xojo.js → WebSocket opens
  │
Session established → DefaultWindow = Default (empty WebPage)
  │
Default.Shown fires → New XojoUnitTestPage → testPage.Show()
  │
XojoUnitTestPage.Opening + Shown → test groups loaded ✓
  │
Browser: XojoUnit test runner UI (via WebSocket)
-->
<!-- /diagram -->

เพจ `Default` คือ WebPage เปล่าธรรมดา เหตุการณ์ `Shown` ของมันเกิดขึ้นหลังจากสร้างเซสชันเต็ม — จุดนิรภัยสูงสุดแรกเพื่อแสดง `XojoUnitTestPage`:

```xojo
// Default.xojo_code — Shown event
Sub Shown()
  Var testPage As New XojoUnitTestPage
  testPage.Show()
End Sub
```

`XojoUnitTestPage` มี `ImplicitInstance=False` ดังนั้น `New XojoUnitTestPage` จึงจำเป็น — `XojoUnitTestPage.Show()` โดยตรงจะเป็นข้อผิดพลาดการรวบรวม

### เหตุใด `/?_xojo=1` และไม่เพียงแค่ `/`

`/` เป็นเส้นทาง MVVM ที่ลงทะเบียน Router จะจับคู่มันและส่งกลับ `True` ให้บริการเพจ MVVM หลัก — ไม่เคยถึง `Return False` พารามิเตอร์การสอบถาม `_xojo=1` คือ sentinel ที่บอก `HandleURL` ให้ข้ามตัว Router ปกติ browser ที่เยี่ยมชม `/` ไม่เคยส่ง `_xojo=1` ดังนั้นเพจหลักจึงไม่ได้รับผลกระทบ

---

## การเชื่อมโยงกลับ: Xojo WebPage → MVVM

หากต้องการนำทางจาก Xojo WebPage กลับไปยังเส้นทาง MVVM ให้ใช้ `Session.GoToURL()` สิ่งนี้ส่งคำแนะนำการนำทางระดับเบราว์เซอร์ โดยแตกออกจากเซสชัน WebSocket ทั้งหมด

```xojo
// XojoUnitTestPage — WebToolbar Pressed event
Sub Pressed(item As WebToolbarButton)
  Select Case item.Caption
  Case "XjMVVM"
    Session.GoToURL("/")   // browser navigates to MVVM home
  End Select
End Sub
```

!!! warning
    ภายในเหตุการณ์ `WebToolbar.Pressed` `Me` หมายถึง `WebToolbar` เอง ไม่ใช่เพจ `Me.Session` ไม่มีอยู่บน `WebToolbar` ใช้ thread-local global `Session` โดยตรง

### API นำทาง

| จาก | ถึง | วิธี | หมายเหตุ |
|------|----|--------|-------|
| MVVM template | MVVM route | `<a href="/notes">` | HTML anchor มาตรฐาน |
| MVVM template | Xojo WebPage | `<a href="/tests">` | กระตุ้นลำดับ redirect dance |
| Xojo WebPage | MVVM route | `Session.GoToURL("/")` | นำทางระดับเบราว์เซอร์ ปล่อย WebSocket |
| Xojo WebPage | Xojo WebPage | `page.Show()` | ภายใน WebSocket ไม่มีการเปลี่ยน URL |

---

## Router ส่งคืนค่า Boolean

`Router.Route()` คือ `Function As Boolean` ไม่ใช่ `Sub` เมื่อไม่มีเส้นทาง MVVM ตรงกัน (เช่น `/framework/Xojo.js` `/websocket`) จะส่งคืน `False` `HandleURL` ส่งต่อ `False` นั้นไปยัง handler ของ Xojo เอง ซึ่งให้บริการไฟล์

```xojo
// HandleURL — simplified
Return mRouter.Route(request, response, session, mJinja)
// If no route matched → Router returns False → HandleURL returns False
// → Xojo serves Xojo.js, WebSocket frames, etc.
```

ถ้า `Route()` ส่งกลับ `True` เสมอ ไฟล์ JS และ CSS ของ Xojo เองจะถูกบล็อก เซสชัน WebSocket จะไม่มีวาระสร้าง และการไหลของ `/tests` จะแตก

---

## อ้างอิงไฟล์

| ไฟล์ | บทบาท |
|------|------|
| `App.xojo_code` | `HandleURL` — normalize path การเปลี่ยนเส้นทาง `/tests` การผ่าน `/?_xojo=1` การส่งตัว Router |
| `Framework/Router.xojo_code` | การลงทะเบียนเส้นทาง (`Get` `Post` `Any`) การจับคู่เส้นทาง (`ParsePath`) การส่งตัว หน้าข้อผิดพลาด |
| `Default.xojo_code` | Trampoline `WebPage` — เหตุการณ์ `Shown` สร้าง instance `XojoUnitTestPage` หลังจากเซสชันพร้อม |
| `mvvm.xojo_project` | `DefaultWindow=Default` — ต้องเป็น `Default` ไม่ใช่ `XojoUnitTestPage` |
| `XojoUnit/XojoUnitTestPage.xojo_code` | ตัวรันเทส ปุ่ม XjMVVM แถบเครื่องมือเรียก `Session.GoToURL("/")` |