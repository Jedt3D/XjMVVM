---
title: Serving Static Assets
description: How to serve CSS, JavaScript, images, and other static files in a XjMVVM app.
---

# Serving Static Assets

Because `HandleURL` intercepts every request, you must explicitly handle requests for static assets (`.css`, `.js`, images, fonts). There are three approaches, ordered from simplest to most flexible.

## Option 1 — CDN links (recommended for libraries)

For third-party libraries (Tailwind, Alpine.js, chart libraries), link directly from a CDN. No Xojo code required.

```html
{# templates/layouts/base.html #}
<head>
  <link rel="stylesheet" href="https://cdn.tailwindcss.com">
  <script src="https://unpkg.com/alpinejs@3" defer></script>
</head>
```

Use this for libraries you don't modify. Zero deployment complexity.

## Option 2 — Static file ViewModel

For your own CSS, JS, and images, register a `/static/:file` route that reads the file from disk and writes it to the response.

### 1. Create the ViewModel

Create `ViewModels/StaticFileVM.xojo_code`:

```xojo
Class StaticFileVM
  Inherits BaseViewModel

  Sub OnGet()
    Var fileName As String = GetParam("file")

    // Security: reject path traversal attempts
    If fileName.Contains("..") Or fileName.Contains("/") Or fileName.Contains("\") Then
      Response.Status = 400
      Response.Write("Bad Request")
      Return
    End If

    // Build path to static/ folder (adjust for your project layout)
    Var staticDir As New FolderItem("/path/to/mvvm/static", FolderItem.PathModes.Native)
    Var file As FolderItem = staticDir.Child(fileName)

    If Not file.Exists Then
      Response.Status = 404
      Response.Write("Not Found")
      Return
    End If

    // Set MIME type based on extension
    Response.Header("Content-Type") = MimeType(fileName)

    // Cache static assets for 1 hour in production
    Response.Header("Cache-Control") = "public, max-age=3600"

    // Read and write file bytes
    Var bs As BinaryStream = BinaryStream.Open(file, False)
    Response.Write(bs.Read(bs.Length))
    bs.Close()
  End Sub

  Private Function MimeType(fileName As String) As String
    Var ext As String = fileName.NthField(".", fileName.CountFields(".")).Lowercase
    Select Case ext
    Case "css"   : Return "text/css; charset=utf-8"
    Case "js"    : Return "application/javascript; charset=utf-8"
    Case "png"   : Return "image/png"
    Case "jpg", "jpeg" : Return "image/jpeg"
    Case "gif"   : Return "image/gif"
    Case "svg"   : Return "image/svg+xml"
    Case "ico"   : Return "image/x-icon"
    Case "woff2" : Return "font/woff2"
    Case "woff"  : Return "font/woff"
    Case "pdf"   : Return "application/pdf"
    Else          : Return "application/octet-stream"
    End Select
  End Function

End Class
```

### 2. Register the route

In `App.Opening()`, register the static route **after** all other routes to avoid accidentally matching application paths:

```xojo
// Register application routes first
mRouter.Get("/",           New HomeViewModelFactory())
mRouter.Get("/notes",      New NotesListVMFactory())
// ... all other routes ...

// Static files last
mRouter.Get("/static/:file", New StaticFileVMFactory())
```

### 3. Create the static/ folder

```
mvvm/
  static/
    app.css
    app.js
    logo.png
```

### 4. Reference in templates

```html
<link rel="stylesheet" href="/static/app.css">
<script src="/static/app.js" defer></script>
<img src="/static/logo.png" alt="Logo">
```

!!! warning "Security"
    Always validate the filename before reading from disk. The path traversal check (`..`, `/`, `\`) in the example above is the minimum required. Never construct a file path from user input without validation.

## Option 3 — Xojo Copy Files build step

For files that should be bundled with the application binary (fonts, default images), use Xojo's **Copy Files** build step to include them in the app's Resources folder.

Then access them at runtime via:

```xojo
Var resourceDir As FolderItem = App.ExecutableFile.Parent.Child("Resources")
Var file As FolderItem = resourceDir.Child(fileName)
```

This approach is best for files that ship with the app and never change at runtime. For developer assets that you edit frequently during development, Option 2 is more convenient.

## MIME types reference

| Extension | MIME type |
|---|---|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css; charset=utf-8` |
| `.js` | `application/javascript; charset=utf-8` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg` / `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.svg` | `image/svg+xml` |
| `.ico` | `image/x-icon` |
| `.woff2` | `font/woff2` |
| `.woff` | `font/woff` |
| `.pdf` | `application/pdf` |
