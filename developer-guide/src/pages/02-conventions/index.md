---
title: Conventions Overview
description: Naming and structural conventions used throughout the XjMVVM framework.
---

# Conventions

Consistent conventions make the codebase predictable. When every developer follows the same patterns for file names, class names, and method names, you can navigate an unfamiliar feature without opening every file.

This section covers three areas:

- **[Directory Structure](directory-structure.html)** — where everything lives and why
- **[File Naming](file-naming.html)** — how ViewModels, Models, and templates are named
- **[Methods & Properties](naming-methods-properties.html)** — naming rules for Xojo code

## Quick reference

| Thing | Convention | Example |
|---|---|---|
| ViewModel file | `{Feature}{Action}VM.xojo_code` | `NotesCreateVM.xojo_code` |
| Model file | `{Feature}Model.xojo_code` | `NoteModel.xojo_code` |
| Template folder | `templates/{feature}/` | `templates/notes/` |
| Template file | `{action}.html` | `form.html`, `list.html` |
| Private property | `mCamelCase` | `mFormData`, `mRawBody` |
| ViewModel method (GET) | `OnGet()` | overrides `BaseViewModel.OnGet()` |
| ViewModel method (POST) | `OnPost()` | overrides `BaseViewModel.OnPost()` |
| Dictionary key | `snake_case` string | `"page_title"`, `"created_at"` |
| URL path param | `:snake_case` | `/notes/:id` |
