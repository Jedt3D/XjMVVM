# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Xojo Web 2 application** implementing a server-side rendered (SSR) MVVM architecture — similar to Flask/Django — using JinjaX as the template engine. It bypasses Xojo's built-in WebPage GUI controls entirely, routing all HTTP requests through `WebApplication.HandleURL` and rendering HTML via JinjaX templates.

**Xojo version:** 2025r3.1 (project version 2025.031)
**App type:** Web (`IsWebProject=True`)
**Debug port:** 8080
**Bundle ID:** `com.worajedt.mvvm`

## Architecture

The architecture follows a strict layered pattern:

```
Browser → HandleURL → Router → ViewModel → Model → Database
                                    ↓
                          JinjaX Template → HTML Response
```

### Key architectural rules:
1. **Dictionary Data Contract** (most critical rule): JinjaX dot-notation (`{{ user.name }}`) only works with `Dictionary` objects. Models must return `Dictionary` or `Variant()` of `Dictionary` — never custom class instances. ViewModels build `Dictionary` contexts for templates.
2. **No WebPage controls**: All rendering goes through JinjaX HTML templates in `templates/`. The existing `WebPage1` is a placeholder to be deleted.
3. **Session isolation**: Never store user-specific data in `App` — use `WebSession` (the `Session` class). `App` is shared across all users.
4. **Dependency direction**: View → ViewModel → Model (never reverse). ViewModels never reference HTML/template structure; Models never reference ViewModels.
5. **Post/Redirect/Get**: All form submissions follow POST → process → Redirect(302) → GET pattern to prevent duplicate submissions.

### Singletons on App (shared, read-only after Opening):
- `mRouter As Router` — route registration and dispatch
- `mJinja As JinjaEnvironment` — template compilation (thread-safe after setup)

### Per-request objects (created fresh, thread-safe):
- `ViewModel` instances, `CompiledTemplate`, `JinjaContext`

## Project Structure

```
Framework/      → Router, BaseViewModel, FormParser, QueryParser, RouteDefinition
ViewModels/     → One ViewModel per route (inherits BaseViewModel)
Models/         → Data access classes returning Dictionary objects
templates/      → JinjaX HTML files (layouts/, errors/, feature folders)
JinjaXLib/      → Full JinjaX source (Jinja2-compatible engine, pure Xojo)
data/           → SQLite database (auto-created at startup)
```

## Current State

**Phase 2 complete** — Full Notes CRUD is implemented and running.

- `Framework/` — Router, BaseViewModel, FormParser (UTF-8-correct), QueryParser, RouteDefinition
- `Models/NoteModel.xojo_code` — SQLite CRUD returning Dictionary objects
- `ViewModels/Notes/` — 7 ViewModels covering full Notes CRUD
- `templates/` — layouts/base.html, notes/*, errors/404.html, errors/500.html
- Flash messages via Session, POST/Redirect/GET throughout, error pages

**Next:** Phase 3 — additional models, authentication, more resource types.

## Development

This is a Xojo project — it must be opened and built in the **Xojo IDE**. There is no CLI build system. The `.xojo_code` files use Xojo's text project format and can be edited directly, but testing requires running through the IDE.

When editing `.xojo_code` files directly:
- Classes use `#tag Class` / `#tag EndClass` delimiters
- Methods use `#tag Method` / `#tag EndMethod` with metadata attributes
- Events use `#tag Event` / `#tag EndEvent`
- WebPages have a layout section (`Begin WebPage ... End`) followed by `#tag WindowCode`

## String Indexing (CRITICAL)

Xojo 2025 strings and arrays are **fully 0-based** with the modern API. `Mid()` is a legacy 1-based VB function — never use it. Use `String.Middle()`.

| Method | Base | Notes |
|--------|------|-------|
| `String.IndexOf("x")` | **0-based** | Returns `0` for first character |
| `String.Middle(index, len)` | **0-based** | Aligns with `IndexOf` naturally |
| `String.Left(n)` / `Right(n)` | count-based | Index-agnostic — always safe |

```vb
// WRONG: Mid() is 1-based legacy — silently wrong when used with IndexOf
Var value As String = pair.Mid(eqPos + 1)

// CORRECT: Middle() is 0-based — eqPos+1 skips past the '=' cleanly
Var value As String = pair.Middle(eqPos + 1)
```

Counter loops use 0-based `Middle` with `i < s.Length`:

```vb
Var i As Integer = 0
While i < s.Length
  Var ch As String = s.Middle(i, 1)
  i = i + 1
Wend
```

## UTF-8 / Percent-Decoding

**Never use `Chr(code)` per decoded byte.** `Chr()` maps integers to Unicode code points — `Chr(0xE0)` is `à`, not the UTF-8 byte `0xE0`. This corrupts any multi-byte character (Thai, emoji, etc.).

Correct pattern — collect raw bytes in a `MemoryBlock`, then `DefineEncoding(..., Encodings.UTF8)`:

```vb
mb.Byte(byteCount) = Integer.FromHex(hex)
byteCount = byteCount + 1
// after loop:
Return DefineEncoding(mb.StringValue(0, byteCount), Encodings.UTF8)
```

## JinjaX Template Reference

Templates use Jinja2 syntax: `{{ var }}`, `{% if %}`, `{% for %}`, `{% extends %}`, `{% include %}`, `{% block %}`. Autoescape is on by default. Custom filters registered via `env.RegisterFilter()`. Templates loaded from filesystem via `JinjaX.FileSystemLoader`.
