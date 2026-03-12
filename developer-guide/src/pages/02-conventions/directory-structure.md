---
title: Directory Structure
description: Annotated map of every folder and file in the project.
---

# Directory Structure

```
mvvm/
├── mvvm.xojo_project           # Xojo project file (open this in the IDE)
├── mvvm.xojo_resources         # Static resources bundled with the app
│
├── App.xojo_code               # WebApplication — Opening(), HandleURL()
├── Session.xojo_code           # WebSession subclass — per-user state, flash messages
├── Default.xojo_code           # Required placeholder WebPage (never served)
│
├── Framework/                  # Reusable infrastructure — rarely modified
│   ├── Router.xojo_code        # Route registration and dispatch
│   ├── BaseViewModel.xojo_code # Base class: Handle(), Render(), Redirect(), flash
│   ├── FormParser.xojo_code    # Parses application/x-www-form-urlencoded POST bodies
│   ├── QueryParser.xojo_code   # Parses URL query strings (?key=val&...)
│   └── RouteDefinition.xojo_code  # Data class: method, pattern, factory
│
├── ViewModels/                 # One class per route
│   ├── HomeViewModel.xojo_code # GET /
│   └── Notes/                  # Feature folder — all note-related ViewModels
│       ├── NotesListVM.xojo_code   # GET  /notes
│       ├── NotesNewVM.xojo_code    # GET  /notes/new
│       ├── NotesCreateVM.xojo_code # POST /notes
│       ├── NotesDetailVM.xojo_code # GET  /notes/:id
│       ├── NotesEditVM.xojo_code   # GET  /notes/:id/edit
│       ├── NotesUpdateVM.xojo_code # POST /notes/:id
│       └── NotesDeleteVM.xojo_code # POST /notes/:id/delete
│
├── Models/                     # Data access — returns Dictionary objects only
│   └── NoteModel.xojo_code     # SQLite CRUD for the notes table
│
├── JinjaXLib/                  # Full JinjaX source tree (Jinja2 engine in Xojo)
│   └── ...                     # Do not modify unless upgrading JinjaX
│
├── templates/                  # HTML templates (Jinja2 syntax)
│   ├── layouts/
│   │   └── base.html           # Site layout — nav, flash messages, content block
│   ├── home.html               # GET /
│   ├── notes/
│   │   ├── list.html           # GET /notes
│   │   ├── detail.html         # GET /notes/:id
│   │   └── form.html           # GET /notes/new and GET /notes/:id/edit (shared)
│   └── errors/
│       ├── 404.html
│       └── 500.html
│
├── data/
│   └── notes.sqlite            # SQLite database (auto-created on first run)
│
└── developer-guide/            # This documentation
    ├── build.py
    ├── nav.yaml
    ├── src/
    └── dist/
```

## Framework vs. ViewModels

The `Framework/` folder contains code you write once and rarely touch again. It's the "engine" — routing, base ViewModel lifecycle, request/response helpers. When you add a new feature, you never modify `Framework/`.

`ViewModels/` is where all application-specific work happens. Every new route gets a new ViewModel file in the relevant feature folder.

## Feature folders in ViewModels

Group ViewModels by feature, not by HTTP method:

```
ViewModels/
  Notes/         ← all seven note-related ViewModels live here
  Users/         ← all user-related ViewModels (future)
  Admin/         ← all admin-related ViewModels (future)
```

This keeps related files together and makes it easy to find everything about a feature in one place.

## Template mirroring

The `templates/` structure mirrors the URL hierarchy:

| URL | Template |
|---|---|
| `/notes` | `templates/notes/list.html` |
| `/notes/new` | `templates/notes/form.html` |
| `/notes/:id` | `templates/notes/detail.html` |
| `/notes/:id/edit` | `templates/notes/form.html` |
| Error 404 | `templates/errors/404.html` |

The `form.html` template is shared between create and edit routes. It inspects the `note` context variable: if it exists, the form is in edit mode; if it's `Nil`, the form is in create mode.

## The `data/` directory

Currently the database path is hardcoded for development. For production builds, use `SpecialFolder.ApplicationData` to place the database in the correct OS location:

```xojo
// Development (hardcoded for IDE debug runs)
Var dbFile As New FolderItem("/path/to/mvvm/data/notes.sqlite", FolderItem.PathModes.Native)

// Production (correct approach)
Var appData As FolderItem = SpecialFolder.ApplicationData
Var dbFile As FolderItem = appData.Child("mvvm").Child("notes.sqlite")
```
