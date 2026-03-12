"""
xojo_lexer.py — Pygments lexer for the Xojo programming language.

Xojo is a BASIC-derived, case-insensitive language for Desktop/Web/Mobile apps.
This lexer is based on the reference implementations in:
  - xojo-syntax-highlight/highlightjs/xojo.highlight.js
  - xojo-syntax-highlight/prismjs/xojo.prism.js
  - xojo-syntax-highlight/codemirror/xojo.codemirror.js

Registration: imported and registered in build.py before Pygments is used.
Usage in Markdown fenced blocks: ```xojo
"""

import re

from pygments.lexer import RegexLexer, words
from pygments.token import (
    Comment,
    Keyword,
    Name,
    Number,
    Operator,
    Punctuation,
    String,
    Text,
)


class XojoLexer(RegexLexer):
    """Pygments lexer for the Xojo programming language."""

    name = "Xojo"
    aliases = ["xojo"]
    filenames = ["*.xojo_code", "*.xojo_script"]
    flags = re.IGNORECASE | re.MULTILINE

    # ── Token lists (mirrors the three JS reference implementations) ──────────

    _KEYWORDS = (
        "Var", "Dim",
        "Sub", "Function", "Property", "Event", "Delegate",
        "Class", "Module", "Interface", "Enum", "Namespace",
        "If", "Then", "Else", "ElseIf", "End",
        "For", "Each", "Next",
        "While", "Wend",
        "Do", "Loop", "Until",
        "Select", "Case", "Break", "Continue",
        "Try", "Catch", "Finally", "Raise", "RaiseEvent",
        "Return", "Exit", "New",
        "Inherits", "Implements", "Extends",
        "AddHandler", "RemoveHandler",
        "Public", "Private", "Protected",
        "Static", "Shared", "Global",
        "Override", "Virtual", "Final", "Abstract",
        "ParamArray", "Optional",
        "As", "ByRef", "ByVal", "Of",
        "Call", "Using",
    )

    _OPERATOR_KEYWORDS = (
        "And", "Or", "Not", "Xor",
        "Mod", "In",
        "Is", "IsA", "Isa",
        "AddressOf", "WeakAddressOf",
    )

    _TYPES = (
        "Integer", "Int8", "Int16", "Int32", "Int64",
        "UInt8", "UInt16", "UInt32", "UInt64",
        "Single", "Double",
        "Boolean", "String", "Variant",
        "Object", "Color", "Ptr", "Auto",
        "CString", "WString",
    )

    _LITERALS = (
        "True", "False", "Nil",
    )

    _BUILTINS = (
        "Self", "Super", "Me",
    )

    # ── Token rules ───────────────────────────────────────────────────────────

    tokens = {
        "root": [

            # ── 1. Line comments (//) — must come before operators ──────────
            (r"//.*$", Comment.Single),

            # ── 2. Apostrophe comments (') — BASIC-style ───────────────────
            # Uses a negative lookbehind to not match the start of a string
            # (strings use double-quotes in Xojo, so ' is always a comment)
            (r"'[^\r\n]*", Comment.Single),

            # ── 3. Preprocessor directives (#tag, #pragma, #if, …) ─────────
            # Consume the entire line as Comment.Preproc (class "cp") so it
            # maps cleanly to the .cp CSS rule in both light and dark themes.
            (
                r"#(?:tag|pragma|if|elseif|else|endif|region|endregion)\b[^\r\n]*",
                Comment.Preproc,
            ),

            # ── 4. String literals — no multiline ──────────────────────────
            (r'"[^"\n]*"', String.Double),

            # ── 5. Numeric literals ─────────────────────────────────────────
            # &h / &H  hex
            (r"&[hH][0-9a-fA-F]+\b", Number.Hex),
            # &b / &B  binary
            (r"&[bB][01]+\b", Number.Bin),
            # decimal / float / scientific
            (r"\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b", Number),

            # ── 6. Boolean / Nil literals ───────────────────────────────────
            (words(_LITERALS, prefix=r"\b", suffix=r"\b"), Keyword.Constant),

            # ── 7. Built-in self-references (Self, Super, Me) ───────────────
            (words(_BUILTINS, prefix=r"\b", suffix=r"\b"), Name.Builtin.Pseudo),

            # ── 8. Data types ───────────────────────────────────────────────
            (words(_TYPES, prefix=r"\b", suffix=r"\b"), Keyword.Type),

            # ── 9. Operator keywords (And, Or, Not, …) ─────────────────────
            (words(_OPERATOR_KEYWORDS, prefix=r"\b", suffix=r"\b"), Operator.Word),

            # ── 10. Language keywords ────────────────────────────────────────
            (words(_KEYWORDS, prefix=r"\b", suffix=r"\b"), Keyword),

            # ── 11. Symbolic operators ───────────────────────────────────────
            (r"[<>!=+\-*\/&|^]=?|[<>]{2}", Operator),

            # ── 12. Punctuation ─────────────────────────────────────────────
            (r"[{}()\[\].,;:]", Punctuation),

            # ── 13. Identifiers ─────────────────────────────────────────────
            (r"[A-Za-z_]\w*", Name),

            # ── 14. Whitespace & other ───────────────────────────────────────
            (r"\s+", Text.Whitespace),
            (r".", Text),
        ],
    }


def register():
    """Register the XojoLexer with Pygments at runtime.

    Pygments' get_lexer_by_name() flow (this version):
      1. Iterates LEXERS looking for an entry whose aliases tuple contains
         the requested alias (lowercased).
      2. If found, checks whether the display name is already in _lexer_cache.
      3. If cached → returns immediately (no module import needed).

    Strategy: add an entry to LEXERS *and* pre-populate _lexer_cache with
    the display name "Xojo" so _load_lexers() is never called (and we never
    need __all__ on this module).
    """
    from pygments.lexers import LEXERS, _lexer_cache

    LEXERS["XojoLexer"] = (
        "xojo_lexer",         # module name — not actually loaded (see below)
        "Xojo",               # display name  ← must match _lexer_cache key
        ("xojo",),            # aliases (lowercased)
        ("*.xojo_code",),     # filename globs
        (),                   # mime types
    )

    # Pre-populate cache keyed by display name so _load_lexers is never called
    _lexer_cache["Xojo"] = XojoLexer
