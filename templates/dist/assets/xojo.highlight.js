/**
 * highlight.js language definition for Xojo
 * https://github.com/worajedt/xojo-syntax-highlight
 *
 * Xojo เป็นภาษาโปรแกรมที่พัฒนาต่อมาจาก BASIC รองรับการสร้างแอป Desktop/Web/Mobile
 * ไฟล์นี้กำหนด grammar สำหรับ highlight.js เพื่อ highlight code Xojo ได้ถูกต้อง
 *
 * ครอบคลุมรูปแบบต่อไปนี้:
 *   - ความคิดเห็น // และ ' (apostrophe)
 *   - String ในเครื่องหมายคำพูดคู่
 *   - ตัวเลขแบบทศนิยม, &h hex, &b binary
 *   - คำสงวน Xojo เฉพาะ เช่น Var, Nil, Self, Super, #tag
 *
 * วิธีใช้:
 *   import xojo from './xojo.highlight.js';
 *   hljs.registerLanguage('xojo', xojo);
 *   hljs.highlightAll();
 */
export default function(hljs) {

  // ────────────────────────────────────────────────────────────────────────────
  // คำสงวน (Keywords) ของภาษา Xojo
  //
  // highlight.js จะ match คำเหล่านี้เป็น token ประเภท "keyword" โดยอัตโนมัติ
  // เนื่องจากตั้ง case_insensitive: true คำว่า Var, VAR, var จึง match เหมือนกัน
  // ────────────────────────────────────────────────────────────────────────────
  const KEYWORDS = [
    // การประกาศตัวแปร:
    //   Var → รูปแบบใหม่ (Xojo 2019+)
    //   Dim → รูปแบบเก่าที่ยังรองรับเพื่อ backward compatibility
    'Var', 'Dim',

    // การประกาศฟังก์ชัน/เมธอด:
    //   Sub      → ไม่มีค่าคืนกลับ (void)
    //   Function → มีค่าคืนกลับ
    'Sub', 'Function',

    // โครงสร้าง OOP และโมดูล:
    //   Class     → กำหนด class
    //   Module    → กลุ่มของฟังก์ชัน/ค่าคงที่ (ไม่มี instance)
    //   Interface → กำหนด interface
    //   Enum      → กำหนดค่า enumeration
    'Class', 'Module', 'Interface', 'Enum',

    // การควบคุมเงื่อนไข (Conditional):
    //   If/Then/Else/ElseIf/End → รูปแบบ If แบบ block
    'If', 'Then', 'Else', 'ElseIf', 'End',

    // ลูป (Loops):
    //   For/Each/Next  → For-Next และ For Each
    //   While/Wend     → While loop
    //   Do/Loop/Until  → Do-Loop with optional Until/While
    'For', 'Each', 'Next', 'While', 'Wend', 'Do', 'Loop', 'Until',

    // Select-Case และการควบคุม flow:
    //   Select/Case    → เทียบเท่า switch-case
    //   Break/Continue → ออกจากลูป / ข้ามไปรอบถัดไป
    'Select', 'Case', 'Break', 'Continue',

    // การจัดการ exception:
    //   Try/Catch/Finally → block จัดการข้อผิดพลาด
    //   Raise             → โยน exception
    //   RaiseEvent        → ยิง event
    //   Return            → คืนค่าและออกจาก function
    //   Exit              → ออกจาก loop/sub
    'Try', 'Catch', 'Finally', 'Raise', 'RaiseEvent', 'Return', 'Exit',

    // OOP:
    //   New        → สร้าง instance ของ class
    //   Inherits   → กำหนด parent class
    //   Implements → implement interface
    //   Extends    → ขยาย (ใช้ใน generic type)
    'New', 'Inherits', 'Implements', 'Extends',

    // Event handler:
    //   AddHandler    → เพิ่ม event handler ณ runtime
    //   RemoveHandler → ลบ event handler ออก
    'AddHandler', 'RemoveHandler',

    // ระดับการเข้าถึง (Access modifiers):
    //   Public/Private/Protected → ควบคุมการมองเห็น
    //   Static                   → ตัวแปร local ที่ยังมีค่าระหว่าง call
    //   Shared                   → shared member ใช้ได้โดยไม่ต้องสร้าง instance
    //   Global                   → ตัวแปร global (ใช้ใน module)
    'Public', 'Private', 'Protected', 'Static', 'Shared', 'Global',

    // OOP modifiers:
    //   Override → override method จาก parent class
    //   Virtual  → method ที่ subclass สามารถ override ได้
    //   Final    → ป้องกันไม่ให้ override ต่อ
    //   Abstract → method ที่ต้องถูก override โดย subclass
    'Override', 'Virtual', 'Final', 'Abstract',

    // สมาชิกพิเศษของ class:
    //   Property   → getter/setter property
    //   Event      → กำหนด event
    //   Delegate   → function pointer
    //   ParamArray → พารามิเตอร์แบบ array (variadic)
    //   Optional   → พารามิเตอร์ที่ไม่จำเป็นต้องส่ง
    'Property', 'Event', 'Delegate', 'ParamArray', 'Optional',

    // Keyword ในการประกาศพารามิเตอร์:
    //   As    → กำหนดชนิดข้อมูล เช่น "Var x As Integer"
    //   ByRef → ส่งพารามิเตอร์แบบ reference (แก้ไขค่าต้นทางได้)
    //   ByVal → ส่งพารามิเตอร์แบบ copy (default)
    //   Of    → ใช้กับ generic type เช่น Dictionary(Of String, Integer)
    'As', 'ByRef', 'ByVal', 'Of',

    // อื่นๆ
    'Call', 'Using', 'Namespace',
  ];

  // ────────────────────────────────────────────────────────────────────────────
  // ค่าคงที่แบบ literal
  //
  // highlight.js จะ highlight คำเหล่านี้ด้วยสี "literal" (ต่างจาก keyword ปกติ)
  //   True / False → ค่า boolean
  //   Nil          → ค่า null ของ Xojo (เทียบเท่า null ใน C# / Nothing ใน VB)
  // ────────────────────────────────────────────────────────────────────────────
  const LITERALS = ['True', 'False', 'Nil'];

  // ────────────────────────────────────────────────────────────────────────────
  // ชนิดข้อมูลพื้นฐาน (Built-in data types)
  //
  // highlight.js จะ highlight คำเหล่านี้เป็น token ประเภท "type"
  // ────────────────────────────────────────────────────────────────────────────
  const TYPES = [
    // จำนวนเต็มแบบมีเครื่องหมาย (Signed integers):
    //   Integer = Int32 (32-bit), Int8 = byte, Int64 = long
    'Integer', 'Int8', 'Int16', 'Int32', 'Int64',

    // จำนวนเต็มแบบไม่มีเครื่องหมาย (Unsigned integers):
    'UInt8', 'UInt16', 'UInt32', 'UInt64',

    // ชนิดข้อมูลทั่วไป:
    'Single',    // ทศนิยมความแม่นยำเดียว (32-bit float)
    'Double',    // ทศนิยมความแม่นยำคู่ (64-bit float)
    'Boolean',   // ค่า True/False
    'String',    // ข้อความ Unicode
    'Variant',   // ชนิดข้อมูลที่ยืดหยุ่น (เก็บได้ทุกประเภท)

    // ชนิดข้อมูลพิเศษสำหรับ Xojo:
    'Object',    // object อ้างอิงทั่วไป
    'Color',     // สี (ARGB)
    'Ptr',       // raw pointer
    'Auto',      // ชนิดข้อมูลอัตโนมัติ (inferred)
    'CString',   // null-terminated C string สำหรับเชื่อมกับ C API
    'WString',   // null-terminated wide string
  ];

  // ────────────────────────────────────────────────────────────────────────────
  // ตัวดำเนินการแบบ keyword (Operator keywords)
  //
  // คำเหล่านี้ทำงานเป็น operator แต่เขียนเป็นคำภาษาอังกฤษ
  // highlight.js ไม่มี category "operator" ใน keywords object
  // จึงรวมเข้าไปใน keyword array แล้วใช้ CSS class เดียวกัน
  // ────────────────────────────────────────────────────────────────────────────
  const OPERATORS = [
    'And', 'Or', 'Not', 'Xor',          // ตัวดำเนินการเชิงตรรกะ (Logical operators)
    'Mod',                               // หารเอาเศษ (Modulo)
    'In',                                // ตรวจสอบสมาชิก (ใช้ใน For Each)
    'Is', 'IsA', 'Isa',                  // ตรวจสอบ Nil / ตรวจสอบชนิด (type check)
    'AddressOf', 'WeakAddressOf',        // ได้ pointer ไปยัง method (สำหรับ delegate/handler)
  ];

  // ────────────────────────────────────────────────────────────────────────────
  // Built-in object references
  //
  // อ้างอิงไปยัง object ปัจจุบันหรือ parent class:
  //   Self  → เทียบเท่า 'this' ใน Java/C#
  //   Super → เรียก method ของ parent class (เทียบเท่า 'super' ใน Java)
  //   Me    → ชื่อเก่าของ Self ก่อน Xojo จะเปลี่ยนชื่อ
  // ────────────────────────────────────────────────────────────────────────────
  const BUILTINS = ['Self', 'Super', 'Me'];

  // ────────────────────────────────────────────────────────────────────────────
  // Language definition object — สิ่งที่ส่งคืนจาก factory function
  // highlight.js จะนำ object นี้ไปใช้ highlight code ทุกครั้ง
  // ────────────────────────────────────────────────────────────────────────────
  return {
    name: 'Xojo',
    aliases: ['xojo'],       // ชื่อที่ใช้ใน code fence: ```xojo
    case_insensitive: true,  // Xojo ไม่แยก uppercase/lowercase

    // ─── keywords object ──────────────────────────────────────────────────────
    // แต่ละ key จะถูก map ไปยัง CSS class ที่ต่างกัน:
    //   keyword  → .hljs-keyword
    //   literal  → .hljs-literal
    //   type     → .hljs-type
    //   built_in → .hljs-built_in
    //
    // highlight.js ทำ keyword matching โดยอัตโนมัติ (whole-word, case-insensitive)
    // ไม่ต้องเขียน regex เอง
    // ─────────────────────────────────────────────────────────────────────────
    keywords: {
      keyword: [...KEYWORDS, ...OPERATORS],  // รวม operator-keyword เข้าไปด้วยกัน
      literal: LITERALS,
      type: TYPES,
      built_in: BUILTINS,
    },

    // ─── contains array ───────────────────────────────────────────────────────
    // รายการ "mode" ที่ highlight.js จะพยายาม match ตามลำดับ
    // mode ที่อยู่ก่อนมี priority สูงกว่า — ลำดับสำคัญมาก!
    //
    // ตัวอย่าง: comment อยู่ก่อน string
    //   // "this is a comment" → // ถูก match เป็น comment ก่อน
    //   " // not a comment"  → " ถูก match เป็น string ก่อน
    // ─────────────────────────────────────────────────────────────────────────
    contains: [
      // ─── 1. Line comment แบบ // ─────────────────────────────────────────────
      // hljs.COMMENT(begin, end) เป็น helper สร้าง mode สำหรับ comment
      // '$' ใน end คือ end-of-line (highlight.js ใส่ flag m ให้อัตโนมัติ)
      // → ผล: ข้อความตั้งแต่ // จนสุดบรรทัด ได้ class "hljs-comment"
      hljs.COMMENT('//', '$'),

      // ─── 2. Line comment แบบ ' (apostrophe) ─────────────────────────────────
      // Xojo รองรับ ' เป็น comment แบบ BASIC ดั้งเดิม
      // ทำงานเหมือนกัน: ' highlight ไปจนสุดบรรทัด
      hljs.COMMENT("'", '$'),

      // ─── 3. String (ข้อความในเครื่องหมายคำพูด) ──────────────────────────────
      // begin: '"' เริ่ม match เมื่อเจอ "
      // end: '"'   จบ match เมื่อเจอ " ปิด
      // illegal: '\\n' → ถ้า highlight.js พบ newline ก่อน " ปิด จะยกเลิก match
      //   เพราะ Xojo ไม่รองรับ string ที่ข้ามบรรทัด (multiline string)
      //   ป้องกันไม่ให้ missing " ทำให้ code ที่เหลือทั้งหมด highlight เป็น string
      {
        scope: 'string',
        begin: '"',
        end: '"',
        illegal: '\\n',
      },

      // ─── 4. ตัวเลข (Number literals) ────────────────────────────────────────
      // match pattern รองรับ 3 รูปแบบ Xojo:
      //
      //   &[hH][0-9a-fA-F]+\b  → hex literal เช่น &hFF00FF, &HFFFFFF
      //   &[bB][01]+\b          → binary literal เช่น &b10101010
      //   \b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b → ทศนิยม เช่น 42, 3.14, 1e6
      //
      // ลำดับสำคัญ: &h ต้องอยู่ก่อน ถ้าไม่มี & อาจถูกมองเป็น operator
      // relevance: 0 → ไม่นับ match นี้ในการ auto-detect ภาษา
      {
        scope: 'number',
        match: /&[hH][0-9a-fA-F]+\b|&[bB][01]+\b|\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/,
        relevance: 0,
      },

      // ─── 5. Preprocessor directives (#tag, #pragma, #if ...) ────────────────
      // match เฉพาะ token #<directive> จบที่ \b (word boundary)
      // flag /i → case-insensitive (#TAG, #Pragma ก็ match ได้)
      //
      // หมายเหตุ: pattern นี้ match แค่ "#tag" ไม่ใช่ทั้งบรรทัด
      // ดังนั้น "Module" ใน "#tag Module, Name = Utils" จะยังถูก highlight เป็น keyword
      // (ต่างจาก Prism.js และ CodeMirror ที่ consume ทั้งบรรทัดเป็น meta token)
      {
        scope: 'meta',
        match: /#(tag|pragma|if|else|elseif|endif|region|endregion)\b/i,
      },
    ],
  };
}
