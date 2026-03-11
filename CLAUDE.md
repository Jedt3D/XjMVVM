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

## Planned Project Structure

```
Framework/      → Router, BaseViewModel, FormParser, QueryParser
ViewModels/     → One ViewModel per route (inherits BaseViewModel)
Models/         → Data access classes returning Dictionary objects
templates/      → JinjaX HTML files (layouts/, errors/, feature folders)
```

## Current State

The project is in early Phase 1 (core framework). Only scaffolding files exist:
- `App.xojo_code` — empty WebApplication shell
- `Session.xojo_code` — default WebSession
- `WebPage1.xojo_code` — placeholder (to be removed)
- `MVVM_Architecture_Proposal.md` — full architecture spec and implementation roadmap
- `MVVM_Knowledge_Base.md` — MVVM pattern reference

## Development

This is a Xojo project — it must be opened and built in the **Xojo IDE**. There is no CLI build system. The `.xojo_code` files use Xojo's text project format and can be edited directly, but testing requires running through the IDE.

When editing `.xojo_code` files directly:
- Classes use `#tag Class` / `#tag EndClass` delimiters
- Methods use `#tag Method` / `#tag EndMethod` with metadata attributes
- Events use `#tag Event` / `#tag EndEvent`
- WebPages have a layout section (`Begin WebPage ... End`) followed by `#tag WindowCode`

## JinjaX Template Reference

Templates use Jinja2 syntax: `{{ var }}`, `{% if %}`, `{% for %}`, `{% extends %}`, `{% include %}`, `{% block %}`. Autoescape is on by default. Custom filters registered via `env.RegisterFilter()`. Templates loaded from filesystem via `JinjaX.FileSystemLoader`.
