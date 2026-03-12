/**
 * Prism.js language definition for Xojo
 * https://github.com/worajedt/xojo-syntax-highlight
 *
 * Xojo เป็นภาษาโปรแกรมที่พัฒนาต่อมาจาก BASIC รองรับการสร้างแอป Desktop/Web/Mobile
 * ไฟล์นี้กำหนด grammar สำหรับ Prism.js เพื่อ highlight code Xojo ได้ถูกต้อง
 *
 * ครอบคลุมรูปแบบต่อไปนี้:
 *   - ความคิดเห็น // และ ' (apostrophe)
 *   - String ในเครื่องหมายคำพูดคู่
 *   - ตัวเลขแบบทศนิยม, &h hex, &b binary
 *   - คำสงวน Xojo เฉพาะ เช่น Var, Nil, Self, Super, #tag
 *
 * วิธีใช้:
 *   โหลดไฟล์นี้หลัง prism.js แล้วใช้ language 'xojo' ใน code block
 *   <pre><code class="language-xojo">...</code></pre>
 *
 * หลักการทำงานของ Prism.js:
 *   Prism จะ match pattern ตามลำดับใน object ด้านล่าง
 *   pattern ที่อยู่ก่อนมี priority สูงกว่า (first match wins)
 *   greedy: true ป้องกัน Prism จากการ re-tokenize ข้อความที่ match แล้ว
 */
(function (Prism) {
  Prism.languages['xojo'] = {

    // ────────────────────────────────────────────────────────────────────────────
    // 1. ความคิดเห็น (Comments) — ต้องอยู่อันดับแรกเสมอ
    //
    // ต้องมาก่อน string และ keyword เพื่อป้องกัน:
    //   - keyword ใน comment ถูก highlight (เช่น // Return this value)
    //   - string ใน comment ถูก match เป็น string token
    //
    // greedy: true → เมื่อ match แล้ว Prism จะไม่ลอง match pattern อื่นข้างใน
    // ────────────────────────────────────────────────────────────────────────────
    'comment': [
      // // line comment — match ตั้งแต่ // จนสุดบรรทัด
      { pattern: /\/\/.*/, greedy: true },

      // ' apostrophe comment — Xojo รองรับ ' เป็น comment แบบ BASIC ดั้งเดิม
      // ใช้ [^\r\n]* แทน .* เพราะ Prism 1.29+ ไม่รองรับ flags option บน pattern object
      // (การใช้ /.*/m หรือ flags: 'm' จะถูก ignore อย่างเงียบๆ)
      { pattern: /'[^\r\n]*/, greedy: true },
    ],

    // ────────────────────────────────────────────────────────────────────────────
    // 2. String (ข้อความในเครื่องหมายคำพูด)
    //
    // match "..." โดยไม่ให้ข้ามบรรทัด ([^"\n]*)
    // Xojo ไม่รองรับ multiline string — ถ้า " เปิดไม่มี " ปิดในบรรทัดเดียวกัน
    // pattern จะหยุดที่ท้ายบรรทัดเอง
    //
    // greedy: true ป้องกัน Prism ไม่ให้ match keyword/number ข้างใน string
    // ────────────────────────────────────────────────────────────────────────────
    'string': {
      pattern: /"[^"\n]*"/,
      greedy: true,
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 3. Preprocessor directives (#tag, #pragma, #if, ...)
    //
    // match ทั้งบรรทัดที่ขึ้นต้นด้วย # ตามด้วย directive ที่รู้จัก จนถึงสุดบรรทัด
    // Pattern: /#(?:tag|pragma|if|elseif|else|endif|region|endregion)\b[^\r\n]*/i
    //
    // greedy: true → สำคัญมาก! ป้องกัน Prism ไม่ให้ match pattern อื่นข้างใน
    //   preprocessor line เช่น "Module" ใน "#tag Module, Name = Utils"
    //   จะไม่ถูก highlight เป็น keyword เพราะทั้งบรรทัดเป็น token เดียวกัน
    //
    // alias: 'meta' → ทำให้ Prism ใช้ CSS class .token.meta สำหรับสีพิเศษ
    //   ต้องเพิ่ม CSS rule .token.meta { color: ... } เอง เพราะ Prism themes ไม่มี
    //
    // inside → กำหนด sub-pattern ภายใน token ที่ match แล้ว
    //   ทำให้ highlight เพิ่มเติมภายใน context ของ preprocessor token
    // ────────────────────────────────────────────────────────────────────────────
    'preprocessor': {
      pattern: /#(?:tag|pragma|if|elseif|else|endif|region|endregion)\b[^\r\n]*/i,
      greedy: true,
      alias: 'meta',
      inside: {
        // ─── Sub-highlight: directive keyword ─────────────────────────────────
        // เมื่อ match ทั้งบรรทัดเป็น preprocessor แล้ว
        // inside จะ highlight เฉพาะส่วน #directive เพิ่มเติมด้วยสี keyword
        //
        // /^#\w+/ match ตั้งแต่ต้น token (^) จนถึงสุดคำ
        // alias: 'keyword' → ใช้สีเดียวกับ keyword (สว่างกว่าสี meta)
        // ─────────────────────────────────────────────────────────────────────
        'directive': {
          pattern: /^#\w+/,
          alias: 'keyword',
        },
      },
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 4. Keywords — คำสงวนของภาษา Xojo
    //
    // \b...\b คือ word boundary ทำให้ match เฉพาะคำที่อยู่โดดๆ
    // เช่น "Integer" จะ match แต่ "MyInteger" จะไม่ match
    // flag /i ทำให้ match แบบ case-insensitive
    // ────────────────────────────────────────────────────────────────────────────
    'keyword': {
      pattern: /\b(?:Var|Dim|Sub|Function|Class|Module|Interface|Enum|If|Then|Else|ElseIf|End|For|Each|Next|While|Wend|Do|Loop|Until|Select|Case|Break|Continue|Try|Catch|Finally|Raise|RaiseEvent|Return|Exit|New|Inherits|Implements|Extends|AddHandler|RemoveHandler|Public|Private|Protected|Static|Shared|Global|Override|Virtual|Final|Abstract|Property|Event|Delegate|ParamArray|Optional|As|ByRef|ByVal|Of|Call|Using|Namespace)\b/i,
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 5. Operator keywords — ตัวดำเนินการแบบคำ
    //
    // And, Or, Not, Xor → logical operators
    // Mod               → modulo (หารเอาเศษ)
    // In                → membership check (ใช้ใน For Each)
    // Is, IsA, Isa      → type/nil checking
    // AddressOf         → ได้ pointer ไปยัง method
    //
    // alias: 'operator' → Prism ใช้ CSS class .token.operator
    //   ทำให้สีต่างจาก keyword ปกติในบางธีม
    // ────────────────────────────────────────────────────────────────────────────
    'operator-keyword': {
      pattern: /\b(?:And|Or|Not|Xor|Mod|In|Is|IsA|Isa|AddressOf|WeakAddressOf)\b/i,
      alias: 'operator',
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 6. Built-in references — อ้างอิงไปยัง object ปัจจุบัน
    //
    //   Self  → เทียบเท่า 'this' ใน Java/C# — อ้างอิง instance ปัจจุบัน
    //   Super → เรียก method ของ parent class
    //   Me    → ชื่อเก่าของ Self (ยังใช้ได้เพื่อ backward compatibility)
    //
    // alias: 'keyword' → ใช้สีเดียวกับ keyword ปกติ
    // ────────────────────────────────────────────────────────────────────────────
    'builtin': {
      pattern: /\b(?:Self|Super|Me)\b/i,
      alias: 'keyword',
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 7. Boolean literals — ค่าคงที่แบบ boolean
    //
    //   True / False → ค่า boolean ปกติ
    //   Nil          → ค่า null ของ Xojo (เทียบเท่า null ใน C#)
    // ────────────────────────────────────────────────────────────────────────────
    'boolean': {
      pattern: /\b(?:True|False|Nil)\b/i,
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 8. Data types (ชนิดข้อมูล)
    //
    // ครอบคลุม built-in types ทั้งหมดของ Xojo:
    //   Integer, Int8-Int64 → จำนวนเต็มมีเครื่องหมาย (signed)
    //   UInt8-UInt64        → จำนวนเต็มไม่มีเครื่องหมาย (unsigned)
    //   Single, Double      → ทศนิยม 32/64-bit
    //   Boolean, String     → ชนิดพื้นฐาน
    //   Variant             → ชนิดข้อมูลยืดหยุ่น
    //   Object, Color, Ptr  → ชนิดพิเศษ
    //   CString, WString    → string สำหรับเชื่อมต่อกับ C API
    //
    // alias: 'class-name' → Prism themes มักจะมีสี .token.class-name (เช่น cyan)
    //   เหมาะสำหรับ type name มากกว่า .token.type ที่ไม่มีในทุก theme
    // ────────────────────────────────────────────────────────────────────────────
    'type': {
      pattern: /\b(?:Integer|Int8|Int16|Int32|Int64|UInt8|UInt16|UInt32|UInt64|Single|Double|Boolean|String|Variant|Object|Color|Ptr|Auto|CString|WString)\b/i,
      alias: 'class-name',
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 9. Number literals (ตัวเลข)
    //
    // รองรับรูปแบบ Xojo ทั้งหมด:
    //   &hFF00FF   → hex literal (ขึ้นต้นด้วย &h หรือ &H)
    //   &b10101010 → binary literal (ขึ้นต้นด้วย &b หรือ &B)
    //   42         → จำนวนเต็ม
    //   3.14       → เลขทศนิยม
    //   1e6        → scientific notation
    //
    // สำคัญ: &h และ &b ต้องอยู่ก่อนในลำดับ alternation (|)
    //   เพราะ & อาจ match เป็น operator ได้ถ้า Prism ประมวลผลทีละตัว
    // ────────────────────────────────────────────────────────────────────────────
    'number': {
      pattern: /&[hH][0-9a-fA-F]+\b|&[bB][01]+\b|\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/,
    },

    // ────────────────────────────────────────────────────────────────────────────
    // 10. ตัวดำเนินการแบบสัญลักษณ์ (Symbolic operators)
    //
    // match สัญลักษณ์: <, >, !, +, -, *, /, &, |, ^, =
    // พร้อม compound: <=, >=, <>, <<, >>
    // ────────────────────────────────────────────────────────────────────────────
    'operator': /[<>!=+\-*\/&|^]=?|[<>]{2}/,

    // ────────────────────────────────────────────────────────────────────────────
    // 11. เครื่องหมายวรรคตอน (Punctuation)
    //
    // { } ( ) [ ] . , ; : — ไม่ highlight แยกสี แต่ต้อง match เพื่อให้ Prism
    // ประมวลผล token เหล่านี้ได้ถูกต้องและไม่ตกค้างเป็น plain text
    // ────────────────────────────────────────────────────────────────────────────
    'punctuation': /[{}()\[\].,;:]/,
  };
}(Prism));
