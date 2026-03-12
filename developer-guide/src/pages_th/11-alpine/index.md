---
title: "Alpine.js"
description: วิธีการและเหตุผลที่ XjMVVM ใช้ Alpine.js สำหรับการโต้ตอบแบบ client-side ขั้นต่ำ และเวลาที่ควรเลือกใช้มันแทน HTML ธรรมชาติหรือ htmx
---

# Alpine.js

XjMVVM เป็น framework ที่ render จากเซิร์ฟเวอร์ — HTML มาจาก Xojo ไม่ใช่จาก JS framework Alpine.js เติมเต็มช่องว่างเล็ก ๆ ที่เซิร์ฟเวอร์ไม่สามารถจัดการสถานะได้: UI elements ที่มีการ react ต่อสถานะในเบราว์เซอร์ (localStorage, sessionStorage) โดยไม่ต้องโหลดหน้าเต็มใหม่

## Philosophy

> **Server renders. Alpine reacts. htmx fetches.**

เป้าหมายคือให้ JavaScript น้อยที่สุดเท่าที่เป็นไปได้ ต้นไม้การตัดสินใจสำหรับ interactive elements ใด ๆ คือ:

1. **สามารถจัดการด้วย plain HTML form + PRG pattern ได้หรือไม่?** → ใช้อันนี้ ไม่ต้องมี JS
2. **มันต้อง react ต่อสถานะในเบราว์เซอร์หรือต้องการ inline DOM updates หรือไม่?** → Alpine
3. **มันต้องดึงข้อมูลจากเซิร์ฟเวอร์และอัปเดตส่วนของหน้าหรือไม่?** → htmx (ดู [htmx adoption plan](#when-to-reach-for-htmx))

Alpine ไม่เคยใช้เป็นทดแทนสำหรับ server-side logic ชิ้นส่วนธุรกิจ ข้อมูล และการตรวจสอบทั้งหมดที่สามารถอยู่บนเซิร์ฟเวอร์ก็อยู่บนเซิร์ฟเวอร์

---

## Installation

Alpine ถูก load จาก CDN โดยไม่มี build step ตัวเดียวที่ด้านล่างของ `layouts/base.html` ก่อน `</body>`:

```html
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>
```

`defer` attribute จำเป็นต้อง — Alpine ต้อง process DOM หลังจากที่มันได้รับการ parse แล้ว

!!! note
    Pin ไปเป็นเวอร์ชันที่เฉพาะเจาะจง (เช่น `@3.14.3`) มากกว่า `@3` เพื่อให้ builds มีความเสถียรและ upstream CDN update ไม่สามารถทำลายแอปได้

---

## Core directives used in XjMVVM

| Directive | Purpose |
|---|---|
| `x-data="{ ... }"` | ประกาศ reactive component กับ state ของมัน |
| `x-show="expr"` | Toggles `display:none` ตาม boolean expression |
| `x-text="expr"` | ตั้ง element text content เป็นค่า expression |
| `:class="expr"` | Binds `class` attribute แบบ dynamic |
| `@submit.prevent="fn"` | Intercepts form submit, prevents default, calls a function |
| `@submit="expr"` | Runs an expression on form submit โดยไม่ prevent default |
| `x-cloak` | Hides an element จนกว่า Alpine จะ initialize (prevents FOUC) |
| `init()` | Lifecycle hook — runs once เมื่อ component initialize |

---

## Pattern 1 — Nav auth state

Nav bar ต้องแสดง Log In / Sign Up (logged-out) หรือ username + Log Out (logged-in) ที่ขับเคลื่อนโดย `localStorage` เซิร์ฟเวอร์ไม่สามารถ inject สิ่งนี้ได้เพราะ Xojo Web 2 SSR mode ไม่สามารถคงอยู่ `WebSession` state ระหว่าง plain HTTP requests

```html
<nav x-data="{ user: localStorage.getItem('_auth_user') }">

  <!-- Logged-out state: visible by default, hidden by Alpine if user is set -->
  <span class="nav-auth" x-show="!user">
    <a href="/login" class="btn btn-sm">Log In</a>
    <a href="/signup" class="btn btn-primary btn-sm">Sign Up</a>
  </span>

  <!-- Logged-in state: hidden by x-cloak until Alpine confirms user exists -->
  <span class="nav-auth" x-show="user" x-cloak>
    <span x-text="user" style="font-size:0.9em; color:#555;"></span>
    <form method="post" action="/logout"
          @submit="localStorage.removeItem('_auth_user');
                   sessionStorage.setItem('_flash_msg', 'You have been logged out.');
                   sessionStorage.setItem('_flash_type', 'success');">
      <button type="submit" class="btn btn-sm">Log Out</button>
    </form>
  </span>

</nav>
```

`x-cloak` บน logged-in span ป้องกัน flash ของทั้งสองสถานะก่อนที่ Alpine จะ initialize CSS rule ที่ทำให้สิ่งนี้ทำงานต้องอยู่ในสไตล์ชีต:

```css
[x-cloak] { display: none !important; }
```

`@submit` บน logout form clear localStorage และ queue flash message ก่อนที่ POST จะถูก submit ไม่จำเป็นต้องมี separate event listener หรือ script block

---

## Pattern 2 — Client-side flash messages

Flash messages สำหรับ POST→redirect→GET cycle ไม่สามารถใช้ session ของ Xojo ใน SSR mode — session หายไปเมื่อ redirect's GET มาถึง workaround: write ไปที่ `sessionStorage` ก่อน form submit, read มันบน next page load

Alpine reads และ displays queued message ใน `init()` จากนั้น `x-show` เก็บมันไว้ hidden หากไม่มีอะไรให้แสดง:

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

`!document.querySelector('.flash')` guard ป้องกัน double-flash หาก Xojo server-side session บังเอิญ deliver flash โดยตรง (future-proofs สำหรับ WebSocket mode)

---

## Pattern 3 — Form submit with async pre-processing

Auth forms ต้อง hash password client-side ด้วย Web Crypto API ก่อนที่ POST จะถูกส่ง นี่คือ inherently async และต้อง intercept submit event Alpine's `@submit.prevent` + async method ใน `x-data` handles นี่ได้อย่างสะอาด ไม่มี separate `addEventListener` script block

SHA-256 helper ถูกกำหนดใน small `<script>` เหนือ form (มันต้องอยู่ในขอบเขตเมื่อ Alpine method runs):

```html
<script>
async function sha256hex(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2,'0')).join('');
}
</script>

<form method="post" action="/login"
      x-data="{
        hashed: false,
        async handleSubmit(e) {
          if (this.hashed) return;
          const pwEl = document.getElementById('password');
          pwEl.value = await sha256hex(pwEl.value);
          localStorage.setItem('_auth_user', document.getElementById('username').value);
          sessionStorage.setItem('_flash_msg', 'Welcome back!');
          sessionStorage.setItem('_flash_type', 'success');
          this.hashed = true;
          e.target.submit();
        }
      }"
      @submit.prevent="handleSubmit($event)">
  ...
</form>
```

`hashed` flag ป้องกัน re-processing หาก `e.target.submit()` บังเอิญ re-fires event `e.target.submit()` (DOM method) bypasses `submit` event ทั้งหมด ดังนั้น flag นี้เป็นหลัก safety guard

### Adding inline validation

Signup form เพิ่ม password validation `pwError` state drives inline error paragraph ไม่มี extra DOM wiring:

```html
<p x-show="pwError" x-text="pwError"
   style="display:none; color:#721c24; background:#f8d7da;
          padding:8px 12px; border-radius:4px; margin:0 0 12px;"></p>
```

ภายใน `handleSubmit`:

```javascript
if (pw.length < 6) { this.pwError = 'Password must be at least 6 characters.'; return; }
if (pw !== cf)     { this.pwError = 'Passwords do not match.'; return; }
this.pwError = '';
```

ไม่มี `document.getElementById`, ไม่มี manual `style.display` toggling Alpine keeps element ในการซิงค์

---

## Pattern 4 — Multi-value checkboxes (no Alpine needed)

Tag checkboxes บน note form ก่อนหน้านี้ต้องมี JS เพื่อ collect checked values เป็น hidden field นี่คือ unnecessary — native HTML form serialization sends checkboxes ทั้งหมดที่ checked ด้วย `name` เดียวกันเป็น multiple values Xojo's `FormParser` ตรวจสอบแล้ว comma-append สำหรับ duplicate keys

Pattern ที่ถูกต้องต้องการ **ไม่มี JavaScript เลย**:

```html
{% for tag in all_tags %}
<input type="checkbox" name="tag_ids" value="{{ tag.id }}"
       {% if tag.selected == "1" %}checked{% endif %}>
{{ tag.name }}
{% endfor %}
```

Form submits `tag_ids=1&tag_ids=3`, FormParser stores `"1,3"` และ ViewModel splits บน `","` เหมือนก่อนหน้า ไม่มี hidden field ไม่มี script block

!!! tip
    ก่อนที่จะ reach for Alpine (หรือ JS ใด ๆ) check ว่า browser's native form serialization ทำสิ่งที่คุณต้องการแล้วหรือไม่ Multiple checkboxes, radio groups และ `<select multiple>` ทั้งหมดทำงานได้โดยไม่มี JavaScript

---

## JS footprint comparison

| What | Before Alpine | After Alpine |
|---|---|---|
| base.html IIFE | 30 lines | 0 (replaced by `x-data` attributes) |
| login.html `<script>` | 19 lines | 8 (sha256hex helper only) |
| signup.html `<script>` | 35 lines | 8 (sha256hex helper only) |
| notes/form.html `<script>` | 9 lines | 0 (removed entirely) |
| **Total custom JS** | **93 lines** | **16 lines** |
| Alpine CDN | 0 | 14 KB (minified + gzip: ~5 KB) |

16 lines irreducible คือ SHA-256 helper function (duplicated ข้าม login และ signup) นี่ไม่สามารถย้ายไปยังไฟล์ที่แชร์โดยไม่มี build step — deliberate trade-off เพื่อรักษา zero build tooling

---

## When to reach for htmx

Alpine manages **local browser state** เมื่อ interaction ต้อง **fetch จากเซิร์ฟเวอร์และอัปเดตส่วนของหน้า** add htmx แทนการขยาย Alpine

Trigger features ที่รับประกัน adding htmx:

- Inline edit (click note → form appears in place, saves ไม่มี reload)
- Delete ไม่มี reload (remove row จาก list)
- Live search / filter (notes หรือ tags update เมื่อคุณพิมพ์)
- Pagination ไม่มี reload
- Tag toggle บน list view

htmx และ Alpine compose อย่างสะอาด — Alpine owns local state, htmx owns server round-trips libraries ทั้งสองไม่ conflict

---

## What Alpine will never replace

| JS | Reason |
|---|---|
| `crypto.subtle.digest` (SHA-256) | Browser security API ไม่มี Alpine equivalent |
| `localStorage` / `sessionStorage` reads และ writes | Still needed; Alpine เพียงแค่ organises มันใน `x-data` |
| Server-side session persistence | Architectural — requires cookie-based auth ไม่เกี่ยวข้องกับ Alpine |