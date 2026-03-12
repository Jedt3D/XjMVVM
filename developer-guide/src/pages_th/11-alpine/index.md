---
title: "Alpine.js"
description: วิธีและเหตุผลที่ XjMVVM ใช้ Alpine.js สำหรับการโต้ตอบฝั่งไคลเอนต์ขั้นต่ำ และเมื่อใดที่ควรใช้ HTML ธรรมชาติหรือ htmx แทน
---

# Alpine.js

XjMVVM เป็นเฟรมเวิร์กที่เรนเดอร์จากเซิร์ฟเวอร์ — HTML มาจาก Xojo ไม่ใช่จาก JS framework Alpine.js เติมช่องว่างเล็กๆ ที่เซิร์ฟเวอร์ไม่สามารถจัดการสถานะได้: องค์ประกอบ UI ที่ตอบสนองต่อสถานะในเบราว์เซอร์ (localStorage, sessionStorage) โดยไม่โหลดหน้าใหม่

## ปรัชญา

> **เซิร์ฟเวอร์เรนเดอร์ Alpine ตอบสนอง htmx ดึงข้อมูล**

เป้าหมายคือการใช้ JavaScript ให้น้อยที่สุด แผนการตัดสินใจสำหรับองค์ประกอบโต้ตอบใดๆ คือ:

1. **แบบฟอร์ม HTML ธรรมชาติ + รูปแบบ PRG สามารถจัดการได้หรือไม่** → ใช้สิ่งนั้น ไม่มี JS
2. **มันตอบสนองต่อสถานะในเบราว์เซอร์หรือต้องการการอัปเดต DOM แบบอินไลน์หรือไม่** → Alpine
3. **มันต้องดึงข้อมูลจากเซิร์ฟเวอร์และอัปเดตส่วนของหน้าหรือไม่** → htmx (ดูที่ [แผนการนำ htmx มาใช้](#when-to-reach-for-htmx))

Alpine ไม่เคยถูกใช้เป็นตัวแทนของตรรมชาติเซิร์ฟเวอร์ กฎธุรกิจ ข้อมูล และการตรวจสอบทั้งหมดที่สามารถอยู่บนเซิร์ฟเวอร์นั้นสามารถอยู่บนเซิร์ฟเวอร์ได้

---

## การติดตั้ง

Alpine ถูกโหลดจาก CDN โดยไม่มีขั้นตอนการสร้าง บรรทัดเดียวที่ด้านล่างของ `layouts/base.html` ก่อน `</body>`:

```html
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.14.3/dist/cdn.min.js"></script>
```

แอตทริบิวต์ `defer` จำเป็น — Alpine ต้องประมวลผล DOM หลังจากที่มันถูกแยกวิเคราะห์แล้ว

!!! note
    ปักหมุดไปยังเวอร์ชันเฉพาะ (เช่น `@3.14.3`) แทน `@3` เพื่อให้บิลด์ทำซ้ำได้และการอัปเดต CDN ต้นน้ำไม่สามารถทำลายแอปได้

---

## คำสั่ง Core ที่ใช้ใน XjMVVM

| คำสั่ง | วัตถุประสงค์ |
|---|---|
| `x-data="{ ... }"` | ประกาศคอมโพเนนต์ที่ตอบสนองพร้อมสถานะของมัน |
| `x-show="expr"` | สลับ `display:none` ตามนิพจน์บูลีน |
| `x-text="expr"` | ตั้งค่าเนื้อหาข้อความขององค์ประกอบให้เป็นค่านิพจน์ |
| `:class="expr"` | ผูกแอตทริบิวต์ `class` แบบไดนามิก |
| `@submit.prevent="fn"` | ขัดขวางการส่งแบบฟอร์ม ป้องกันค่าเริ่มต้น เรียกฟังก์ชัน |
| `@submit="expr"` | รันนิพจน์บนการส่งแบบฟอร์มโดยไม่ป้องกันค่าเริ่มต้น |
| `x-cloak` | ซ่อนองค์ประกอบจนกว่า Alpine จะเริ่มต้น (ป้องกัน FOUC) |
| `init()` | ฮุก Lifecycle — ทำงานครั้งเดียวเมื่อคอมโพเนนต์เริ่มต้น |

---

## รูปแบบ 1 — สถานะตรวจสอบสิทธิ์ Nav

บาร์นำทางต้องแสดงเข้าสู่ระบบ / ลงทะเบียน (ออกจากระบบ) หรือชื่อผู้ใช้ + ออกจากระบบ (เข้าสู่ระบบ) ขับเคลื่อนโดย `localStorage` เซิร์ฟเวอร์ไม่สามารถฉีดสิ่งนี้ได้เนื่องจากโหมด SSR ของ Xojo Web 2 ไม่รักษา `WebSession` สถานะระหว่างคำขอ HTTP ธรรมชาติ

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

`x-cloak` บนช่วงเข้าสู่ระบบป้องกันการแสดงผลของทั้งสองสถานะก่อน Alpine เริ่มต้น กฎ CSS ที่ทำให้สิ่งนี้ใช้งานได้ต้องอยู่ในสไตล์ชีต:

```css
[x-cloak] { display: none !important; }
```

`@submit` บนแบบฟอร์มออกจากระบบล้างสมาชิกและคิวข้อความแฟลชก่อนที่จะส่ง POST หลังฟังก์ชันตัวฟังชายตัวสนับสนุนหรือบล็อกสคริปต์ที่แยกต่างหาก

---

## รูปแบบ 2 — ข้อความแฟลชฝั่งไคลเอนต์

ข้อความแฟลชสำหรับวัฏจักร POST→ リダイเรกต์→GET ไม่สามารถใช้เซสชันของ Xojo ในโหมด SSR ได้ — เซสชันจะหายไปเมื่อเวลาที่ GET ของการเปลี่ยนเส้นทางมาถึง วิธีแก้ปัญหาคือ เขียนไปที่ `sessionStorage` ก่อนที่แบบฟอร์มจะส่ง อ่านในการโหลดหน้าต่อไป

Alpine อ่านและแสดงข้อความในคิวใน `init()` จากนั้น `x-show` เก็บไว้ซ่อนถ้าไม่มีอะไรให้แสดง:

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

การป้องกัน `!document.querySelector('.flash')` ป้องกันการแสดงแฟลชซ้ำหากเซสชันเซิร์ฟเวอร์ฝั่ง Xojo เกิดขึ้นเพื่อส่งแฟลชโดยตรง (ป้องกันล่วงหน้าสำหรับโหมด WebSocket)

---

## รูปแบบ 3 — ส่งแบบฟอร์มพร้อมการประมวลผลก่อนอะแซงก์ก

แบบฟอร์มตรวจสอบสิทธิ์ต้องแฮชรหัสผ่านฝั่งไคลเอนต์ด้วย Web Crypto API ก่อนที่จะส่ง POST นี่เป็นสิ่งที่ไม่สามารถเลื่อนไปได้ตามธรรมชาติและต้องขัดขวางเหตุการณ์ submit Alpine's `@submit.prevent` + วิธีการแบบอะแซงก์ใน `x-data` จัดการสิ่งนี้อย่างสะอาด โดยไม่มีบล็อก `addEventListener` สคริปต์แยกต่างหาก

ตัวช่วย SHA-256 ถูกกำหนดไว้ในคำสั่ง `<script>` เล็ก ๆ เหนือแบบฟอร์ม (จะต้องอยู่ในขอบเขตเมื่อวิธีการของ Alpine ทำงาน):

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

ธง `hashed` ป้องกันการประมวลผลซ้ำหากวิธี `e.target.submit()` ทำให้เหตุการณ์ submit ไฟร์ใหม่ `e.target.submit()` (วิธี DOM) ข้ามเหตุการณ์ submit โดยสิ้นเชิง ดังนั้นธงส่วนใหญ่เป็นการป้องกันความปลอดภัย

### เพิ่มการตรวจสอบแบบอินไลน์

แบบฟอร์มลงทะเบียนจะเพิ่มการตรวจสอบรหัสผ่าน `pwError` สถานะขับเคลื่อนย่อหน้าข้อผิดพลาดแบบอินไลน์โดยไม่มีการจากสายอื่นๆ:

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

ไม่มี `document.getElementById` ไม่มีการสลับ `style.display` ด้วยตนเอง Alpine ทำให้องค์ประกอบอยู่ในซิงค์

---

## รูปแบบ 4 — กล่องตรวจสอบหลายค่า (ไม่จำเป็นต้องใช้ Alpine)

กล่องตรวจสอบแท็กบนแบบฟอร์มบันทึกย่อต้องใช้ JS เพื่อรวบรวมค่าที่ตรวจสอบลงในฟิลด์ที่ซ่อน สิ่งนี้ไม่จำเป็น — การจัดลำดับแบบฟอร์มดั้งเดิมส่งกล่องตรวจสอบทั้งหมดที่มี `name` เดียวกันเป็นค่าหลายค่า `FormParser` ของ Xojo จัดการการต่อเพิ่มแล้วสำหรับคีย์ที่ซ้ำกัน

รูปแบบที่ถูกต้องต้องการ **ไม่มี JavaScript เลย**:

```html
{% for tag in all_tags %}
<input type="checkbox" name="tag_ids" value="{{ tag.id }}"
       {% if tag.selected == "1" %}checked{% endif %}>
{{ tag.name }}
{% endfor %}
```

แบบฟอร์มส่ง `tag_ids=1&tag_ids=3` FormParser เก็บ `"1,3"` และ ViewModel แยกออกมา `","` เช่นเดิม ไม่มีฟิลด์ที่ซ่อน ไม่มีบล็อกสคริปต์

!!! tip
    ก่อนที่จะมาถึง Alpine (หรือ JS ใดๆ) ให้ตรวจสอบว่าการจัดลำดับแบบฟอร์มดั้งเดิมของเบราว์เซอร์นั้นทำสิ่งที่คุณต้องการแล้ว กล่องตรวจสอบหลายกล่อง กลุ่มปุ่มวิทยุ และ `<select multiple>` ล้วนใช้งานได้โดยไม่มี JavaScript

---

## การเปรียบเทียบการใช้พื้นที่ JS

| สิ่งที่ | ก่อนที่ Alpine | หลังจาก Alpine |
|---|---|---|
| base.html IIFE | 30 บรรทัด | 0 (แทนที่ด้วยแอตทริบิวต์ `x-data`) |
| login.html `<script>` | 19 บรรทัด | 8 (ตัวช่วย sha256hex เท่านั้น) |
| signup.html `<script>` | 35 บรรทัด | 8 (ตัวช่วย sha256hex เท่านั้น) |
| notes/form.html `<script>` | 9 บรรทัด | 0 (ลบออกทั้งหมด) |
| **รวมจำนวน JS ที่กำหนดเอง** | **93 บรรทัด** | **16 บรรทัด** |
| Alpine CDN | 0 | 14 KB (minified + gzip: ~5 KB) |

16 บรรทัดที่หลีกไม่ได้คือฟังก์ชันตัวช่วย SHA-256 (ทำซ้ำในหน้าเข้าสู่ระบบและลงทะเบียน) นี้ไม่สามารถย้ายไปยังไฟล์ที่แชร์ได้โดยไม่มีขั้นตอนการสร้าง — การแลกเปลี่ยนที่ตั้งใจไว้เพื่อให้เกิดเป็นศูนย์เครื่องมือสร้าง

---

## เมื่อใดที่ควรมาถึง htmx

Alpine จัดการ **สถานะในเบราว์เซอร์ในท้องถิ่น** เมื่อการโต้ตอบต้องการ **ดึงข้อมูลจากเซิร์ฟเวอร์และอัปเดตส่วนของหน้า** ให้เพิ่ม htmx แทนการขยาย Alpine

คุณสมบัติทริกเกอร์ที่รับประกันการเพิ่ม htmx:

- การแก้ไขแบบอินไลน์ (บันทึกคลิก → แบบฟอร์มปรากฏในสถานที่ บันทึกโดยไม่ต้องโหลดใหม่)
- ลบโดยไม่ต้องโหลดใหม่ (ลบแถวออกจากรายการ)
- ค้นหาสดชื่น / ตัวกรอง (บันทึกย่อหรือแท็กอัปเดตเมื่อคุณพิมพ์)
- การแบ่งหน้าโดยไม่ต้องโหลดใหม่
- สลับแท็กในมุมมองรายการ

htmx และ Alpine องค์ประกอบอย่างสะอาด — Alpine เป็นเจ้าของสถานะในท้องถิ่น htmx เป็นเจ้าของรอบเซิร์ฟเวอร์ ห้องสมุดทั้งสองไม่ขัดแย้งกัน

---

## สิ่งที่ Alpine จะไม่เปลี่ยนแปลงไป

| JS | เหตุผล |
|---|---|
| `crypto.subtle.digest` (SHA-256) | Browser security API, ไม่มี Alpine equivalent |
| `localStorage` / `sessionStorage` อ่านและเขียน | ยังคง จำเป็น Alpine เพียงแค่จัดระเบียบพวกเขาใน `x-data` |
| ความยืดหยุ่นของเซสชันฝั่งเซิร์ฟเวอร์ | สถาปัตยกรรม — ต้องการการตรวจสอบสิทธิ์ตามคุกกี้ ไม่เกี่ยวข้องกับ Alpine |