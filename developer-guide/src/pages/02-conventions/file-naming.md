---
title: File Naming
description: Naming conventions for ViewModel files, Model files, and template files.
---

# File Naming

## ViewModels

ViewModel files follow the pattern `{Feature}{Action}VM.xojo_code`, where:

- **Feature** is the noun (plural for collection operations, singular for item operations)
- **Action** is the verb that describes what this ViewModel does
- **VM** suffix makes it immediately obvious this is a ViewModel

The seven standard actions for a resource follow RESTful conventions:

| Action | HTTP | URL | File |
|---|---|---|---|
| List all | `GET` | `/notes` | `NotesListVM.xojo_code` |
| Show new form | `GET` | `/notes/new` | `NotesNewVM.xojo_code` |
| Create | `POST` | `/notes` | `NotesCreateVM.xojo_code` |
| Show detail | `GET` | `/notes/:id` | `NotesDetailVM.xojo_code` |
| Show edit form | `GET` | `/notes/:id/edit` | `NotesEditVM.xojo_code` |
| Update | `POST` | `/notes/:id` | `NotesUpdateVM.xojo_code` |
| Delete | `POST` | `/notes/:id/delete` | `NotesDeleteVM.xojo_code` |

Not every resource needs all seven. A read-only resource might only have `ListVM` and `DetailVM`. A non-REST page (like a home page or dashboard) gets a simple descriptive name: `HomeViewModel.xojo_code`.

### Class name matches file name

The class name inside the file must match the file name exactly:

```
NotesCreateVM.xojo_code  →  Class NotesCreateVM
NoteModel.xojo_code      →  Class NoteModel
```

Xojo uses the class name — not the file name — at runtime, but keeping them identical prevents confusion.

## Models

Model files follow the pattern `{Feature}Model.xojo_code`:

```
NoteModel.xojo_code     # singular — "the model for a note"
UserModel.xojo_code     # future
ProductModel.xojo_code  # future
```

Use the **singular** form of the noun — the Model represents the entity itself, not a collection of it.

## Templates

Template files use lowercase `snake_case` names and the `.html` extension.

The folder name matches the feature (lowercase plural):

```
templates/
  notes/
    list.html     ← collection view
    detail.html   ← single-item view
    form.html     ← create + edit (shared)
  users/
    list.html
    detail.html
    form.html
  layouts/
    base.html     ← site layout, never rendered directly
  errors/
    404.html
    500.html
```

### Shared form templates

When a create form and edit form are nearly identical, use a single `form.html` and switch on the presence of a context variable:

```html
{# templates/notes/form.html #}
{% if note %}
  {# Edit mode — note.id exists #}
  <form method="post" action="/notes/{{ note.id }}">
  <h1>Edit Note</h1>
{% else %}
  {# Create mode — no note #}
  <form method="post" action="/notes">
  <h1>New Note</h1>
{% endif %}
```

The ViewModel controls mode by passing or omitting `note` in the context dictionary.

## Route registration naming

When registering routes in `App.Opening()`, match the order: GET before POST, list before detail:

```xojo
// In App.Opening() — register routes in logical order
mRouter.Get("/",                 New HomeViewModelFactory())
mRouter.Get("/notes",            New NotesListVMFactory())
mRouter.Get("/notes/new",        New NotesNewVMFactory())    // ← must come before :id
mRouter.Post("/notes",           New NotesCreateVMFactory())
mRouter.Get("/notes/:id",        New NotesDetailVMFactory())
mRouter.Get("/notes/:id/edit",   New NotesEditVMFactory())
mRouter.Post("/notes/:id",       New NotesUpdateVMFactory())
mRouter.Post("/notes/:id/delete",New NotesDeleteVMFactory())
```

!!! warning "Order matters"
    `/notes/new` must be registered **before** `/notes/:id`. The Router matches routes in registration order — if `:id` comes first, the literal segment `new` is captured as an ID value.
