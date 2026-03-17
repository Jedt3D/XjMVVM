---
title: Introduction
description: A server-side rendered Xojo MVVM Web Framework (XjMVVM) built on Xojo Web 2, powered by JinjaX templates.
---

# Introduction

This is **XjMVVM** (Xojo MVVM Web Framework) — a server-side rendered (SSR) web application framework built on Xojo Web 2. Instead of using Xojo's built-in WebPage and WebControl GUI system, every HTTP request is intercepted in `HandleURL` and routed to a ViewModel, which renders an HTML response using the **JinjaX template engine**.

The architecture is deliberately similar to **Flask** or **Django** — familiar to anyone who has built SSR web apps in Python. If you've never used Flask, think of it this way: the browser asks for a page, the server runs some code, builds an HTML string, and sends it back. No JavaScript framework, no WebSockets for rendering, just clean request/response.

## The request lifecycle

Every request — regardless of URL — flows through the same pipeline:

<!-- diagram -->
<!-- nomnoml
#fill: white
#stroke: black
#direction: down
#spacing: 36
#padding: 8
#lineWidth: 1.5
[Browser] HTTP Request -> [HandleURL: WebApplication.HandleURL]
[HandleURL: WebApplication.HandleURL] -> [Router]
[Router] -> [ViewModel: ViewModel.Handle]
[ViewModel: ViewModel.Handle] queries -> [<database> Model]
[<database> Model] Dictionary -> [ViewModel: ViewModel.Handle]
[ViewModel: ViewModel.Handle] -> [Render: JinjaX.CompiledTemplate.Render]
[Render: JinjaX.CompiledTemplate.Render] HTML -> [Browser]
-->
<!-- ascii
Browser
  │  HTTP Request  (GET /notes  or  POST /notes/42)
  ▼
WebApplication.HandleURL
  │  Returns True (takes ownership of all requests)
  ▼
Router
  │  Matches path pattern → selects ViewModel
  │  Extracts URL params  (e.g. /notes/:id → id = "42")
  ▼
ViewModel.Handle()
  │  Dispatches to OnGet() or OnPost()
  ▼
Model  (database queries)
  │  Returns Dictionary / Variant() of Dictionary
  ▼
ViewModel builds context Dictionary
  │  { "notes": [...], "flash": {...}, "page_title": "Notes" }
  ▼
JinjaX.CompiledTemplate.Render(context) → HTML string
  │  Template: templates/notes/list.html
  ▼
WebResponse.Write(html)
  ▼
Browser renders the page
-->
<!-- /diagram -->

Nothing in this pipeline uses `WebPage`, `WebButton`, `WebTextField`, or any other Xojo web control. The `Default` WebPage in the project file is a required placeholder for Xojo's project structure — it is never actually served.

## Running the app

1. Open `mvvm.xojo_project` in **Xojo 2025r3.1**.
2. Click **Run** (⌘R). The app starts on `http://localhost:8080`.
3. The SQLite database `data/notes.sqlite` is created automatically on first launch.

There is no CLI build system. All testing and building happens inside the Xojo IDE.

## What's in this guide

| Section | What you'll learn |
|---|---|
| [Why MVVM?](concepts/index.html) | The architectural decisions and trade-offs behind this design |
| [Routing](routing/index.html) | HandleURL decision tree, the `/tests` redirect dance, crossing between SSR and Xojo WebPage |
| [Conventions](conventions/index.html) | Directory structure, file naming, method and property naming |
| [Static Files](static-files/index.html) | How to serve CSS, JS, and images |
| [Templates](templates/index.html) | JinjaX setup, Jinja2 syntax, real examples, full tag reference |
| [Database](database/index.html) | SQLite patterns, the Dictionary contract, thread safety |
| [DB Layer Reference](database/model-reference.html) | Three-layer architecture (DBAdapter / BaseModel / NoteModel), full CRUD API, trade-offs |
| [Tags & Many-to-Many](tags/index.html) | Second resource, junction table, GetTagsForNote, SetTagsForNote |
| [Auth System](auth/index.html) | Cookie-based auth, HMAC-signed cookies, SHA-256 + salt password hashing, SSR session workarounds |
| [JSON API & Static Serving](api/index.html) | JSONSerializer, authenticated API ViewModels, 201/401/422 status codes, ServeStatic path-traversal guard |
| [Alpine.js](alpine/index.html) | Minimal client-side interactivity — nav auth state, flash messages, form validation |
| [Protected Routes & User Scoping](protected-routes/index.html) | Route guards (RequireLogin / RequireLoginJSON), user-scoped notes, ownership enforcement |
| [Encoding](encoding/index.html) | Form parsing, MIME types, UTF-8 and percent-encoding |

## Current version

**v1.0.0** — User-scoped notes (each user sees only their own), cookie-based authentication (HMAC-signed `mvvm_auth` cookie replaces broken WebSession auth), protected routes (all 19 routes require login), Alpine.js for client-side interactivity, JSON API with auth, and a built-in static file server for the developer docs at `/dist/*`.
