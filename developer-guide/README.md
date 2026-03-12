# MVVM Developer Guide

Static HTML documentation for the MVVM Xojo Web 2 framework.

## Setup

```bash
cd developer-guide
pip3 install -r requirements.txt --break-system-packages
```

## Build

```bash
python3 build.py
```

Output goes to `dist/`. Open `dist/index.html` in a browser.

## Add or edit content

1. Edit or create a Markdown file in `src/pages/`
2. If it's a new page, add it to `nav.yaml`
3. Run `python3 build.py`

## Structure

```
src/
  _layout/page.html    # Jinja2 master template (sidebar, TOC, nav)
  _assets/style.css    # Stripe-like CSS
  _assets/docs.js      # Sidebar toggle, TOC scroll highlight
  pages/               # One .md file per page
    index.md
    01-concepts/
    02-conventions/
    03-static-files/
    04-templates/
    05-database/
    06-encoding/
nav.yaml               # Sidebar navigation structure
build.py               # Static site generator
dist/                  # Generated HTML (open dist/index.html)
```

## Markdown features

- Fenced code blocks with syntax highlighting (xojo, html, sql, python)
- Tables
- `!!! note`, `!!! warning`, `!!! tip` callout blocks
- YAML frontmatter: `title:` and `description:` per page
- Auto-generated TOC from `##` and `###` headings
- Prev / Next page navigation (order from nav.yaml)
