#!/usr/bin/env python3
"""
build.py — Static site generator for XjMVVM Developer Guide.

Usage:
    python3 build.py                  # build all languages from cached sources
    python3 build.py --translate      # (re)generate Thai & Japanese via Haiku 4.5
    python3 build.py --lang en        # build only English
    python3 build.py --lang th        # build only Thai
    python3 build.py --lang jp        # build only Japanese

Requires ANTHROPIC_API_KEY in env for --translate mode.
"""

import json
import os
import re
import sys
import shutil
import subprocess
import textwrap
from pathlib import Path

import markdown
import yaml
from jinja2 import Environment, FileSystemLoader
from markdown.extensions.codehilite import CodeHiliteExtension
from markdown.extensions.fenced_code import FencedCodeExtension
from markdown.extensions.tables import TableExtension
from markdown.extensions.toc import TocExtension
from markdown.extensions.admonition import AdmonitionExtension

# ── Register Xojo Pygments lexer ─────────────────────────────────────────────
# Must happen before any Pygments call so CodeHilite can resolve 'xojo'.
sys.path.insert(0, str(Path(__file__).parent))  # ensure build dir is on path
try:
    from xojo_lexer import register as _register_xojo
    _register_xojo()
except Exception as _e:
    print(f"  [WARN] Could not register Xojo lexer: {_e}")

# ── Paths ────────────────────────────────────────────────────────────────────

ROOT     = Path(__file__).parent
SRC      = ROOT / "src"
DIST     = ROOT.parent / "templates" / "dist"

def _rel(p):
    """Return p relative to ROOT when possible, otherwise absolute."""
    try:
        return p.relative_to(ROOT)
    except ValueError:
        return p

LAYOUT   = SRC / "_layout"
ASSETS   = SRC / "_assets"
PAGES_EN = SRC / "pages"
NAV_FILE = ROOT / "nav.yaml"

LANGUAGES = {
    "en": {"label": "English",  "pages_dir": SRC / "pages",
           "flag": "EN", "translate_to": None},
    "th": {"label": "ภาษาไทย", "pages_dir": SRC / "pages_th",
           "flag": "TH", "translate_to": "Thai"},
    "jp": {"label": "日本語",   "pages_dir": SRC / "pages_jp",
           "flag": "JP", "translate_to": "Japanese"},
}

# ── Markdown setup ───────────────────────────────────────────────────────────

MD_EXTENSIONS = [
    FencedCodeExtension(),
    CodeHiliteExtension(
        guess_lang=False,
        css_class="highlight",
        noclasses=False,   # class-based CSS; colors handled in style.css per theme
    ),
    TocExtension(permalink=True, toc_depth="2-3"),
    TableExtension(),
    AdmonitionExtension(),
    "markdown.extensions.attr_list",
    "markdown.extensions.def_list",
    "markdown.extensions.abbr",
    "markdown.extensions.smarty",
]


def make_md():
    return markdown.Markdown(extensions=MD_EXTENSIONS)


# ── YAML frontmatter ─────────────────────────────────────────────────────────

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def parse_frontmatter(text):
    m = FRONTMATTER_RE.match(text)
    if m:
        meta = yaml.safe_load(m.group(1)) or {}
        body = text[m.end():]
    else:
        meta = {}
        body = text
    return meta, body


# ── nomnoml diagram renderer ──────────────────────────────────────────────────
# nomnoml renders directly to clean B&W SVG via its own #fill/#stroke directives.
# No post-processing needed — colours are controlled in the diagram source itself.

_NOMNOML_SCRIPT = """
const nomnoml = require('nomnoml');
let src = '';
process.stdin.on('data', chunk => { src += chunk; });
process.stdin.on('end', () => {
  process.stdout.write(nomnoml.renderSvg(src));
});
"""


def render_nomnoml(source: str) -> str:
    """Render nomnoml source to a clean inline SVG string via Node.js."""
    result = subprocess.run(
        ["node", "-e", _NOMNOML_SCRIPT],
        input=source,
        capture_output=True,
        text=True,
        cwd=str(ROOT),          # node_modules lives in developer-guide/
    )
    if result.returncode != 0:
        raise RuntimeError(f"nomnoml render failed:\n{result.stderr}")
    return result.stdout.strip()


# ── Diagram tab processor ─────────────────────────────────────────────────────
# Recognises comment blocks:
#   <!-- diagram -->
#   <!-- nomnoml  ...  -->
#   <!-- ascii    ...  -->
#   <!-- /diagram -->
#
# Renders nomnoml to SVG at build time; outputs a two-tab widget: [Diagram | ASCII]

DIAGRAM_BLOCK_RE = re.compile(
    r"<!-- diagram -->\s*"
    r"<!-- nomnoml\s*(.*?)-->\s*"
    r"<!-- ascii\s*(.*?)-->\s*"
    r"<!-- /diagram -->",
    re.DOTALL,
)

_diag_counter = [0]


def process_diagrams(text):
    def render_tab(m):
        _diag_counter[0] += 1
        uid            = f"diag{_diag_counter[0]}"
        nomnoml_source = m.group(1).strip()
        ascii_code     = m.group(2).strip()
        try:
            svg = render_nomnoml(nomnoml_source)
        except Exception as e:
            svg = f'<p style="color:red">nomnoml render error: {e}</p>'
        return (
            f'<div class="diagram-tabs" id="{uid}">\n'
            f'  <div class="diagram-tab-bar">\n'
            f'    <button class="diagram-tab active" '
            f'onclick="switchDiagram(\'{uid}\',\'nomnoml\',this)">Diagram</button>\n'
            f'    <button class="diagram-tab" '
            f'onclick="switchDiagram(\'{uid}\',\'ascii\',this)">ASCII</button>\n'
            f'  </div>\n'
            f'  <div class="diagram-panel diagram-nomnoml">\n'
            f'    {svg}\n'
            f'  </div>\n'
            f'  <div class="diagram-panel diagram-ascii" style="display:none">\n'
            f'    <pre class="ascii-diagram"><code>{ascii_code}</code></pre>\n'
            f'  </div>\n'
            f'</div>\n'
        )
    return DIAGRAM_BLOCK_RE.sub(render_tab, text)


# ── TOC extractor ─────────────────────────────────────────────────────────────

HEADING_RE = re.compile(r"^(#{2,3})\s+(.+)$", re.MULTILINE)


def extract_toc(md_body):
    items = []
    for m in HEADING_RE.finditer(md_body):
        level  = len(m.group(1))
        text   = m.group(2).strip()
        anchor = re.sub(r"[^\w\s-]", "", text.lower())
        anchor = re.sub(r"\s+", "-", anchor).strip("-")
        items.append({"level": level, "text": text, "anchor": anchor})
    return items


# ── Navigation ────────────────────────────────────────────────────────────────

def load_nav():
    with open(NAV_FILE) as f:
        return yaml.safe_load(f)


def build_flat_pages(nav):
    pages = []
    for section in nav["sections"]:
        for item in section["pages"]:
            pages.append(item)
    return pages


def find_neighbours(flat_pages, current_slug):
    for i, page in enumerate(flat_pages):
        if page["slug"] == current_slug:
            prev_page = flat_pages[i - 1] if i > 0 else None
            next_page = flat_pages[i + 1] if i < len(flat_pages) - 1 else None
            return prev_page, next_page
    return None, None


def slug_to_output_path(slug, lang_dist):
    if slug == "index":
        return lang_dist / "index.html"
    if slug.endswith("/index"):
        return lang_dist / slug.replace("/index", "") / "index.html"
    return lang_dist / (slug + ".html")


def relative_root(output_path, lang_dist):
    depth = len(output_path.relative_to(lang_dist).parts) - 1
    return "../" * depth if depth > 0 else "./"


# ── Translation via Claude Haiku 4.5 ─────────────────────────────────────────

def translate_markdown(content, target_lang):
    try:
        import anthropic
    except ImportError:
        print("  [WARN] anthropic package not installed — skipping translation")
        return content

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print(f"  [WARN] ANTHROPIC_API_KEY not set — skipping {target_lang} translation")
        return content

    client = anthropic.Anthropic(api_key=api_key)
    system_prompt = textwrap.dedent(f"""
        You are a technical documentation translator specialising in software development.
        Translate the given Markdown content to {target_lang}.
        Rules:
        - Preserve ALL Markdown formatting exactly (headings, bold, italic, lists, tables).
        - Preserve ALL fenced code blocks completely unchanged.
        - Preserve ALL HTML comments (<!-- ... -->) completely unchanged.
        - Translate the YAML frontmatter 'title:' and 'description:' values only.
        - Keep technical terms in English: XjMVVM, Xojo, JinjaX, ViewModel, Dictionary,
          SQLite, HandleURL, WebSession, GET, POST, HTTP, API, etc.
        - Keep all code variable names, function names, and file paths unchanged.
        - Output ONLY the translated Markdown — no preamble, no explanation.
    """).strip()

    print(f"    → Translating to {target_lang} via Haiku 4.5 ...", flush=True)
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=8192,
        system=system_prompt,
        messages=[{"role": "user", "content": content}],
    )
    return message.content[0].text


def ensure_translated_sources(nav, target_lang_code):
    lang_info   = LANGUAGES[target_lang_code]
    target_dir  = lang_info["pages_dir"]
    target_name = lang_info["translate_to"]
    flat_pages  = build_flat_pages(nav)

    print(f"\n  Preparing {target_lang_code} sources → {_rel(target_dir)}/")
    target_dir.mkdir(parents=True, exist_ok=True)

    for item in flat_pages:
        src_rel  = item["src"].replace("pages/", "")
        src_path = PAGES_EN / src_rel
        dst_path = target_dir / src_rel

        dst_path.parent.mkdir(parents=True, exist_ok=True)

        if dst_path.exists():
            print(f"    ✓ (cached)  {_rel(dst_path)}")
            continue

        raw        = src_path.read_text(encoding="utf-8")
        translated = translate_markdown(raw, target_name)
        dst_path.write_text(translated, encoding="utf-8")
        print(f"    ✓ translated {_rel(dst_path)}")


# ── Page builder ──────────────────────────────────────────────────────────────

def build_page(item, nav, flat_pages, env, lang_code, lang_dist):
    lang_info = LANGUAGES[lang_code]
    pages_dir = lang_info["pages_dir"]
    src_rel   = item["src"].replace("pages/", "")
    src_path  = pages_dir / src_rel

    if not src_path.exists():
        src_path = PAGES_EN / src_rel      # fallback to EN
    if not src_path.exists():
        print(f"  [WARN] Missing: {src_path}")
        return

    raw                = src_path.read_text(encoding="utf-8")
    meta, body         = parse_frontmatter(raw)
    body_with_diagrams = process_diagrams(body)

    _diag_counter[0] = 0          # reset per-page
    md               = make_md()
    content_html     = md.convert(body_with_diagrams)
    toc_items        = extract_toc(body)

    prev_page, next_page = find_neighbours(flat_pages, item["slug"])
    output_path  = slug_to_output_path(item["slug"], lang_dist)
    root_prefix  = relative_root(output_path, lang_dist)

    # Language switcher links (absolute paths from site root)
    lang_links = []
    for lc, linfo in LANGUAGES.items():
        slug = item["slug"]
        if slug == "index":
            href = f"/{lc}/"
        elif slug.endswith("/index"):
            href = f"/{lc}/{slug.replace('/index', '/')}"
        else:
            href = f"/{lc}/{slug}.html"
        lang_links.append({
            "code":   lc,
            "label":  linfo["label"],
            "flag":   linfo["flag"],
            "href":   href,
            "active": lc == lang_code,
        })

    template = env.get_template("page.html")
    html = template.render(
        nav          = nav,
        current_slug = item["slug"],
        page_title   = meta.get("title", item["title"]),
        description  = meta.get("description", ""),
        content      = content_html,
        toc          = toc_items,
        prev_page    = prev_page,
        next_page    = next_page,
        root         = root_prefix,
        site_title   = nav["title"],
        site_version = nav["version"],
        lang_code    = lang_code,
        lang_links   = lang_links,
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html, encoding="utf-8")
    print(f"  ✓  {_rel(output_path)}")


# ── Main ──────────────────────────────────────────────────────────────────────

def build(langs=None, do_translate=False):
    if langs is None:
        langs = list(LANGUAGES.keys())

    print(f"\n🔨  Building XjMVVM Developer Guide → {DIST}/\n")

    DIST.mkdir(exist_ok=True)

    # Root redirect: dist/index.html → /en/
    root_redir = DIST / "index.html"
    root_redir.write_text(
        '<!DOCTYPE html><html><head>'
        '<meta http-equiv="refresh" content="0;url=/en/">'
        '<title>XjMVVM Docs</title></head>'
        '<body><a href="/en/">XjMVVM Developer Guide</a></body></html>',
        encoding="utf-8",
    )

    # Copy assets
    assets_out = DIST / "assets"
    assets_out.mkdir(exist_ok=True)
    if ASSETS.exists():
        for f in ASSETS.iterdir():
            if f.is_file():
                shutil.copy2(f, assets_out / f.name)
    print("  ✓  assets/ copied")

    # Copy Xojo grammar JS files if available
    for src, dst in [
        (Path("/tmp/hljs/xojo.highlight.js"),       assets_out / "xojo.highlight.js"),
        (Path("/tmp/prismjs/prismjs/xojo.prism.js"), assets_out / "xojo.prism.js"),
    ]:
        if src.exists():
            shutil.copy2(src, dst)
            print(f"  ✓  {dst.name} copied")

    nav        = load_nav()
    flat_pages = build_flat_pages(nav)
    env        = Environment(loader=FileSystemLoader(str(LAYOUT)), autoescape=False)

    total = 0
    for lang_code in langs:
        lang_info = LANGUAGES[lang_code]
        lang_dist = DIST / lang_code
        lang_dist.mkdir(exist_ok=True)

        if do_translate and lang_info["translate_to"]:
            ensure_translated_sources(nav, lang_code)
        elif lang_info["translate_to"]:
            pages_dir = lang_info["pages_dir"]
            if not pages_dir.exists():
                print(f"\n  [INFO] {lang_code}/ sources not found — "
                      f"run `python3 build.py --translate` to generate them.\n"
                      f"  Falling back to English for /{lang_code}/.")

        print(f"\n  [{lang_code.upper()}] Building {lang_info['label']} → dist/{lang_code}/")
        for item in flat_pages:
            build_page(item, nav, flat_pages, env, lang_code, lang_dist)
            total += 1

    print(f"\n✅  Done — {total} pages built across {len(langs)} language(s).\n")


if __name__ == "__main__":
    args         = sys.argv[1:]
    do_translate = "--translate" in args
    lang_filter  = None
    if "--lang" in args:
        idx = args.index("--lang")
        if idx + 1 < len(args):
            lang_filter = [args[idx + 1]]
    build(langs=lang_filter, do_translate=do_translate)
