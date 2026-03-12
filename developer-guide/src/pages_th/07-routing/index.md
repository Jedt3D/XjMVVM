---
title: "สถาปัตยกรรมการกำหนดเส้นทาง"
description: วิธีการไหลของคำขอ HTTP ผ่าน HandleURL เมื่อใดที่ Xojo ครอบครองการควบคุม และวิธีการข้ามไปมาระหว่างระบบ SSR และการควบคุม WebPage ของ Xojo
---

# สถาปัตยกรรมการกำหนดเส้นทาง

## สองโลกภายในแอปพลิเคชันเดียว

แอปพลิเคชัน Xojo Web 2 โฮสต์ระบบจัดการคำขอ HTTP ที่แตกต่างกันโดยพื้นฐานสองระบบพร้อมกัน ทุกคำขอ HTTP เข้ามาผ่าน `HandleURL` และค่าที่ส่งคืนจะตัดสินใจว่าโลกใดจะจัดการกับมัน

| โลก | จุดเข้า | การตอบสนอง |
|-------|-------------|----------|
| **MVVM (SSR)** | `HandleURL` → Router → ViewModel → JinjaX | HTTP ธรรมดา HTML ไร้สถานะ |
| **Xojo WebPage** | Bootstrap HTML → WebSocket → Session → controls | การควบคุม UI ที่มีสถานะและเหตุการณ์ |

- `Return True` — แอปพลิเคชันนี้จัดการแล้ว Xojo ไม่ทำอะไรเพิ่มเติม
- `Return False` — Xojo จัดการ (ให้บริการ bootstrap HTML ไฟล์กรอบงาน JS หรือข้อความ WebSocket)

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

## แผนภาพการตัดสินใจ HandleURL

`HandleURL` ใช้ลำดับการตรวจสอบที่คงที่ก่อนส่งคำขอใด ๆ การปกติของเส้นทางมาก่อน — ทุกการเปรียบเทียบขึ้นอยู่กับมัน

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

### ความแปลกประหลาดของ `request.Path`

!!! warning
    Xojo Web 2 ละเว้น `/` นำหน้าจาก `request.Path` คำขอไปที่ `/notes` มาถึงพร้อม `request.Path = "notes"` ไม่ใช่ `"/notes"` ทุกการเปรียบเทียบเส้นทางล้มเหลวเงียบ ๆ หากไม่มีการปกติ

ปกติเสมอก่อนการตรวจสอบเส้นทาง:

```xojo
Var p As String = request.Path
If p.Left(1) <> "/" Then p = "/" + p
If p.Length > 1 And p.Right(1) = "/" Then p = p.Left(p.Length - 1)
```

หากไม่มีนี้ `"notes" <> "/notes"` ประเมินผล `True` โดยไม่มีข้อผิดพลาด — ทุกการจับคู่เส้นทางล้มเหลวอย่างเงียบ ๆ

---

## ท่อประมวลผลคำขอ MVVM

สำหรับเส้นทาง SSR ที่จับคู่ได้ ท่อประมวลผลทั้งหมดจาก `HandleURL` ไปยังการตอบสนอง HTML:

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

เนื่องจากเส้นทาง SSR ส่งคืน `True` Xojo ไม่เคยสร้าง WebSocket session สำหรับพวกเขา ซึ่งหมายความว่าการควบคุม WebPage ของ Xojo (`WebLabel` `WebListBox` ฯลฯ) ไม่สามารถใช้จาก ViewModel ได้ และไม่มีการกดจากเซิร์ฟเวอร์ไปยังเบราว์เซอร์แบบเรียลไทม์หากไม่เพิ่ม Server-Sent Events หรือการโพล JS แยกต่างหาก

---

## ขั้นตอนการเปลี่ยนเส้นทาง `/tests`

Test runner (`XojoUnitTestPage`) คือ Xojo WebPage — ต้องการ WebSocket session ที่ใช้งานได้ การเข้าถึงที่นั่นจากลิงก์ MVVM ต้องใช้ขั้นตอนสามขั้น

### เหตุที่ไม่สามารถแค่ `Return False` ที่ `/tests`

Xojo ให้บริการ bootstrap HTML ของตัวเองที่ **เส้นทางราก** `/` เท่านั้น สำหรับเส้นทางใด ๆ อื่น ๆ การส่งคืน `False` จะสร้าง 404 ของเบราว์เซอร์ที่เปล่า — ไม่ใช่เทมเพลต 404 ของ MVVM เพียงแค่หน้าข้อผิดพลาดของเบราว์เซอร์

### เหตุที่ `DefaultWindow=XojoUnitTestPage` ขัดข้อง

การตั้งค่า `DefaultWindow=XojoUnitTestPage` ในโครงการทำให้ Xojo สร้างมันเป็น WebPage แรกเมื่อ session เชื่อมต่อ แต่ `XojoUnitTestPage.Opening` เรียกใช้การตั้งค่า toolbar และการลงทะเบียน test — โค้ดที่ต้องการให้หน้าและ session มีการเชื่อมต่ออย่างเต็มที่ ในเวลา bootstrap พวกเขาไม่ได้ ผลลัพธ์: การขัดข้องที่รันไทม์

### สิ่งที่ใช้งานจริง ๆ

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

หน้า `Default` คือ `WebPage` ที่ว่างเปล่าอย่างชาญฉลาด เหตุการณ์ `Shown` ของมันเกิดขึ้นหลังจาก session ได้รับการตั้งค่าอย่างเต็มที่ — จุดที่ปลอดภัยที่สุดในการแสดง `XojoUnitTestPage`:

```xojo
// Default.xojo_code — Shown event
Sub Shown()
  Var testPage As New XojoUnitTestPage
  testPage.Show()
End Sub
```

`XojoUnitTestPage` มี `ImplicitInstance=False` ดังนั้น `New XojoUnitTestPage` จำเป็น — `XojoUnitTestPage.Show()` โดยตรงจะเป็นข้อผิดพลาดในการรวบรวม

### เหตุใด `/?_xojo=1` ไม่ใช่เพียง `/`?

`/` คือเส้นทาง MVVM ที่ลงทะเบียน Router จะจับคู่มันและส่งคืน `True` ให้หน้า MVVM — ไม่เคยเข้าถึง `Return False` พารามิเตอร์ query `_xojo=1` คือเซนทิเนลที่บอก `HandleURL` ให้ข้าม Router เบราว์เซอร์ปกติที่ไปยัง `/` ไม่เคยส่ง `_xojo=1` ดังนั้นหน้าแรกจึงไม่ได้รับผลกระทบ

---

## การลิงก์ย้อนกลับ: Xojo WebPage → MVVM

เพื่อนำทางจาก Xojo WebPage กลับไปยังเส้นทาง MVVM ให้ใช้ `Session.GoToURL()` สิ่งนี้ส่งคำแนะนำการนำทางระดับเบราว์เซอร์ออกจาก WebSocket session ทั้งหมด

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
    ภายในเหตุการณ์ `WebToolbar.Pressed` `Me` หมายถึง `WebToolbar` เอง ไม่ใช่หน้า `Me.Session` ไม่มีอยู่ใน `WebToolbar` ใช้ global `Session` ที่ใช้เธรดทั่วไป โดยตรง

### API การนำทาง

| จาก | ไป | วิธี | หมายเหตุ |
|------|----|--------|-------|
| MVVM template | MVVM route | `<a href="/notes">` | Anchor HTML มาตรฐาน |
| MVVM template | Xojo WebPage | `<a href="/tests">` | ขั้นตอนการเปลี่ยนเส้นทางทำให้เกิด |
| Xojo WebPage | MVVM route | `Session.GoToURL("/")` | นำทางระดับเบราว์เซอร์ หยุด WebSocket |
| Xojo WebPage | Xojo WebPage | `page.Show()` | ภายใน WebSocket ไม่เปลี่ยน URL |

---

## Router ส่งคืนบูลีน

`Router.Route()` คือ `Function As Boolean` ไม่ใช่ `Sub` เมื่อไม่มีเส้นทาง MVVM ที่ตรงกัน (เช่น `/framework/Xojo.js` `/websocket`) มันส่งคืน `False` `HandleURL` ขยายผล `False` นั้นไปยังตัวจัดการของ Xojo เซลฟ์ซึ่งให้บริการไฟล์

```xojo
// HandleURL — simplified
Return mRouter.Route(request, response, session, mJinja)
// If no route matched → Router returns False → HandleURL returns False
// → Xojo serves Xojo.js, WebSocket frames, etc.
```

หากส่วนประกอบ `Route()` ส่งคืน `True` เสมอ ไฟล์ JS และ CSS ของ Xojo จะถูกปิดกั้น WebSocket session จะไม่เคยสร้างขึ้น และโฟลว์ `/tests` จะขาดทั้งหมด

---

## อ้างอิงไฟล์

| ไฟล์ | บทบาท |
|------|------|
| `App.xojo_code` | `HandleURL` — การปกติของเส้นทาง `/tests` redirect `/?_xojo=1` passthrough Router dispatch |
| `Framework/Router.xojo_code` | ลงทะเบียนเส้นทาง (`Get` `Post` `Any`) การจับคู่เส้นทาง (`ParsePath`) dispatch หน้าข้อผิดพลาด |
| `Default.xojo_code` | Trampoline `WebPage` — เหตุการณ์ `Shown` สร้างอินสแตนซ์ `XojoUnitTestPage` หลังจาก session พร้อม |
| `mvvm.xojo_project` | `DefaultWindow=Default` — ต้องเป็น `Default` ไม่ใช่ `XojoUnitTestPage` |
| `XojoUnit/XojoUnitTestPage.xojo_code` | Test runner ปุ่ม XjMVVM toolbar เรียก `Session.GoToURL("/")` |
