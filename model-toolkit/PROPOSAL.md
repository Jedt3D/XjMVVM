# Model Toolkit — Proposal

**Date:** 2026-03-12
**Author:** Claude (research + drafting) + Worajedt (vision + direction)
**Status:** Draft — awaiting answers to clarifying questions

---

## 1. Vision

A **standalone application** that manages the entire lifecycle of the MVVM framework's data layer:

```
Schema Design → Code Generation → Migration → Versioning → Documentation
                        ↑
                    AI Agent
```

It takes the manual, error-prone work out of creating and evolving Models, BaseModel subclasses, database tables, and their documentation — and replaces it with a tool that **understands your MVVM architecture** natively.

---

## 2. Clarifying Questions

Before finalizing the design, these questions will shape critical decisions:

### Architecture & Scope

**Q1. Single-project or multi-project?**
Should the toolkit manage only the MVVM project's database, or be a general-purpose tool that can target any Xojo project (or even non-Xojo projects)?
**A1.** it should be used with the only MVVM project's database

**Q2. SQLite-only or multi-database from day one?**
Your current MVVM app uses SQLite. Do you want PostgreSQL/MySQL support immediately, or should we start SQLite-only and add others later? This affects the migration engine complexity significantly.
**A2** No, only SQLite3 support at this moment. Also has specific procedures for each database brands to let us handle edge cases of each database engines later.

**Q3. Schema source of truth — where should it live?**
Options:
- **A) Project file** (like TMS Data Modeler's `.DGP`) — the toolkit owns the schema definition
- **B) The Xojo Model classes themselves** — reverse-engineer from existing `TableName()` + `Columns()` + custom SQL
- **C) A schema DSL file** (like Prisma's `.prisma` or DBML) — a text file in the repo that both humans and AI can read/edit
- **D) The database itself** — inspect the live SQLite file and generate from that
My recommendation: **Option C** — a `.schema` or `.dbml`-like text file. It's version-controllable, AI-readable, human-editable, and can generate both Xojo code AND SQL. But your preference matters here.
**A3** C) A Schema DSL file.

**Q4. How important is visual ER diagramming?**
TMS Data Modeler's ER diagrams are a major feature. Do you want:
- **A) Full visual drag-and-drop ER editor** (like TMS) — this is the hardest to build in Xojo
- **B) Auto-generated diagrams** (read-only, from schema file) — like nomnoml/dbdiagram renders
- **C) Text-based schema definition with optional diagram export** — simpler, CLI-friendly
- **D) Skip diagrams for now** — focus on code generation and migration first

**A4** A) Full visual D&D ER Editor or Viewer at least for the first phase.

### Code Generation

**Q5. What code should be generated?**
Currently your models follow a pattern (override `TableName()`, `Columns()`, add custom CRUD methods). Should the toolkit generate:
- **A) Complete Model classes** (`.xojo_code` files ready to drop in)
- **B) Model + ViewModel stubs** (CRUD ViewModels for each model)
- **C) Model + ViewModel + Templates** (full resource scaffolding, like Rails `scaffold`)
- **D) Only migration SQL** (leave Xojo code to the developer)
- **A5** B) Model + ViewModel stubs

**Q6. Should generated code be editable after generation?**
Two philosophies:

- **Rails-style**: Generate once, then the developer owns the file. Re-generation overwrites.
- **Prisma-style**: Generated code is in a separate "do not edit" layer. Custom logic goes in a different file.
Your current models mix generated-like patterns with custom methods (e.g., `GetTagsForNote` in NoteModel). How should that work?

**A6** Prisma style

### Migration & Versioning

**Q7. Migration strategy?**
- **A) Declarative** (Atlas-style): define desired state, tool computes diff automatically
- **B) Sequential scripts** (Flyway-style): numbered SQL files, applied in order
- **C) Hybrid**: auto-generate migration scripts from schema changes, but let developer edit before applying
- **D) Simple** (current approach): `CREATE TABLE IF NOT EXISTS` with no alter support

My recommendation: **Option C** — auto-generate + review. It matches your AI-assisted workflow and gives safety.
**A7** Option C Hybrid

**Q8. Version tracking granularity?**
- Track every schema change as a version (like git commits)?
- Or snapshot-based (like TMS — archive at meaningful milestones)?
**A8** snapshot-based like TMS Data Modeler

### AI Integration

**Q9. What should the AI agent do?**
Potential AI tasks, ranked by value:
1. **Generate schema from natural language** — "I need a blog with posts, comments, and tags"
2. **Review schema changes** — "This migration drops a column with data. Are you sure?"
3. **Generate documentation** — produce markdown docs from schema
4. **Suggest indexes** — analyze queries and recommend optimizations
5. **Generate test data** — create realistic seed data
6. **Explain migrations** — "This migration adds a foreign key from notes to users"
Which of these matter most to you?
**A9** 1, 2, 3, 4, 5 (important) and 6 when everything else are done

**Q10. MCP server — build one or use existing?**
Options:
- **Use existing SQLite MCP server** — works today, gives AI read/write access to your DB
- **Build a custom MCP server** that exposes your schema file, migration history, and code generation as tools — more powerful but more work
- **Both** — existing for DB access, custom for schema management
**A10** Use existing SQLite MCP Server + track record what we need to `improvement-sqlite-mcp.md` if possible

### Platform

**Q11. Primary interface preference?**
You mentioned three options. My assessment:

| Approach | Pros | Cons |
|----------|------|------|
| **Xojo Desktop app** | Visual ER diagrams possible, native macOS feel, matches your expertise | Slower to build, harder to integrate with AI CLI tools |
| **CLI tool** (Ruby TTY / Python) | Fast to build, pipeable, scriptable, AI-agent friendly | No visual diagrams, less discoverable for new users |
| **AI agent plugin** (MCP server) | Integrates directly into Claude Code/OpenCode workflow, zero context switching | Limited UI, slow for bulk operations (as you noted) |
| **Hybrid: CLI + Xojo viewer** | CLI for generation/migration, Xojo app for visual review/diagrams | Two codebases to maintain |

My recommendation: **Start CLI (Python), graduate to Xojo Desktop.** The core engine (schema parsing, diffing, code generation, migration) should be a library that works headless. Then build the Xojo GUI on top for visual features. The CLI also becomes an MCP server trivially.

What's your preference?
**A11** CLI using `xojo-ttytoolkit` (xojo lib) and generate report with `JinjaX` (xojo lib) then view on default browser.
> `xojo-ttytoolkit` - `'/Users/worajedt/Xojo Projects/xojo-ttytoolkit'`
> `JinjaX` - `/Users/worajedt/Xojo Projects/JinjaX_Implementation/JinjaX_Project/JinjaX`


---

## 3. Competitive Analysis Summary

### What We Can Learn From Each Tool

| Tool | Key Insight to Adopt |
|------|---------------------|
| **TMS Data Modeler** | Diagrams-as-views (not the model). Version comparison with selective alter scripts. Project validation rules. Logical domains for DB-agnostic type abstraction. |
| **Flyway** | Convention-over-configuration naming (`V1__description.sql`). Dead-simple mental model. Migration metadata table. |
| **Prisma** | Schema-first DSL is the sweet spot. Type-safe generated client. Shadow database for drift detection. MCP server for AI integration. |
| **Django Migrations** | Auto-detection of model changes is the killer feature. Dependency graph for migration ordering. Squashing. |
| **Rails** | Scaffold generators (model + controller + views + migration in one command). `schema.rb` as living documentation. |
| **Atlas** | Declarative "desired state" workflow. Migration linting (detect destructive changes). Language-agnostic. |
| **DBML/DBDiagram** | Clean, readable schema DSL. Bidirectional SQL conversion. Separate documentation site generation (dbdocs.io). |
| **ChartDB** | AI-powered DDL generation across SQL dialects from visual design. |
| **Neon MCP** | Branch-based migration safety (test on a branch before applying to production). |
| **Bytebase/DBHub** | Progressive schema discovery (token-efficient for AI). `search_objects` pattern. |

### Competitive Positioning

No existing tool does what we're building because:

1. **None target Xojo** — every code generator outputs Python/TypeScript/Ruby/Delphi, never Xojo `.xojo_code` files
2. **None understand the MVVM Dictionary contract** — our models must return `Dictionary`, not ORM objects
3. **None generate the full MVVM stack** — BaseModel subclass + ViewModel stubs + JinjaX templates
4. **None combine schema design + migration + Xojo code gen + AI assistance** in one tool

This is inherently a **custom tool** — the question is how much we borrow from proven patterns.

---

## 4. Proposed Architecture

### Schema Definition Language (SDL)

A text-based schema file (`.model` or `.schema`) that serves as the single source of truth:

```
# notes.model — example schema definition

project "mvvm-notes"
database sqlite

model Note {
  id        Integer   @primary @autoincrement
  title     String    @required
  body      String?
  user_id   Integer   @references(User.id)
  created_at DateTime @default(now)
  updated_at DateTime @default(now) @on_update(now)
}

model Tag {
  id         Integer  @primary @autoincrement
  name       String   @required
  created_at DateTime @default(now)
}

model User {
  id            Integer  @primary @autoincrement
  username      String   @required @unique
  password_hash String   @required
  created_at    DateTime @default(now)
}

// Junction tables
junction NoteTag {
  note_id Integer @references(Note.id) @on_delete(cascade)
  tag_id  Integer @references(Tag.id)  @on_delete(cascade)
  @primary(note_id, tag_id)
}

// Indexes
index Note.updated_at_desc on Note(updated_at DESC)
```

**Why this format:**
- Human-readable and version-controllable (git-friendly diffs)
- AI can read AND write it (no binary format)
- Generates both SQL and Xojo code
- Inspired by Prisma Schema but simplified for our needs
- Supports annotations (`@primary`, `@references`, etc.) that map to both SQL constraints and Xojo code patterns

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Model Toolkit                         │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │  Parser   │  │  Differ  │  │Generator │  │  AI    │ │
│  │          │  │          │  │          │  │ Agent  │ │
│  │ .model → │  │ v1 ↔ v2  │  │ → .sql   │  │        │ │
│  │  AST     │  │  changes │  │ → .xojo  │  │ Review │ │
│  │          │  │          │  │ → .md    │  │ Suggest│ │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘ │
│       ↕              ↕              ↕            ↕      │
│  ┌─────────────────────────────────────────────────────┐│
│  │              Core Schema Model (in-memory)          ││
│  │   Tables, Columns, Relations, Indexes, Constraints  ││
│  └─────────────────────────────────────────────────────┘│
│       ↕              ↕              ↕            ↕      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │ Reverse  │  │Migration │  │  Version  │  │  MCP   │ │
│  │ Engineer │  │ Runner   │  │  Store    │  │ Server │ │
│  │          │  │          │  │          │  │        │ │
│  │ DB → AST │  │ SQL →DB  │  │ Snapshots│  │ Claude │ │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Responsibility |
|-----------|---------------|
| **Parser** | Read `.model` files → internal AST representation |
| **Differ** | Compare two schema versions, produce a changeset |
| **Generator** | Produce output files from schema: SQL DDL, Xojo `.xojo_code`, Markdown docs |
| **Reverse Engineer** | Read a live database → schema AST (import existing DBs) |
| **Migration Runner** | Apply SQL migrations to a database, track applied versions |
| **Version Store** | Save/load schema snapshots, maintain history |
| **AI Agent** | Review changes, suggest schemas, generate docs, explain migrations |
| **MCP Server** | Expose toolkit operations as MCP tools for Claude Code / OpenCode |

---

## 5. Feature Specification

### 5.1 Schema Management

- **Define** models in `.model` files (the SDL above)
- **Parse** and validate schemas (catch errors like TMS's Project Validation)
- **Import** existing databases via reverse engineering (SQLite `PRAGMA table_info`, PostgreSQL `information_schema`)
- **Export** to SQL DDL for any supported database

### 5.2 Code Generation

Generate complete, ready-to-use Xojo code from the schema:

**Model class** (e.g., `NoteModel.xojo_code`):
```xojo
// Generated by Model Toolkit — safe to customize
#tag Class
Protected Class NoteModel
Inherits BaseModel

  #tag Method, Flags = &h1
    Function TableName() As String
      Return "notes"
    End Function
  #tag EndMethod

  #tag Method, Flags = &h1
    Function Columns() As String
      Return "id, title, body, user_id, created_at, updated_at"
    End Function
  #tag EndMethod

  #tag Method, Flags = &h0
    Function Create(title As String, body As String, userID As Integer) As Integer
      Var db As SQLiteDatabase = OpenDB()
      Var ps As SQLitePreparedStatement = _
        db.Prepare("INSERT INTO notes (title, body, user_id) VALUES (?, ?, ?)")
      ps.BindType(0, SQLitePreparedStatement.SQLITE_TEXT)
      ps.BindType(1, SQLitePreparedStatement.SQLITE_TEXT)
      ps.BindType(2, SQLitePreparedStatement.SQLITE_INTEGER)
      ps.Bind(0, title)
      ps.Bind(1, body)
      ps.Bind(2, userID)
      ps.ExecuteSQL
      Var newID As Integer = db.LastRowID
      db.Close
      Return newID
    End Function
  #tag EndMethod

  // ... GetByID, Update, Delete follow same pattern
  // Custom methods (associations, etc.) preserved on regeneration

#tag EndClass
```

**Migration SQL** (e.g., `migrations/V003__add_user_id_to_notes.sql`):
```sql
-- Migration: Add user_id to notes
-- Generated: 2026-03-12T10:30:00
-- Direction: UP

ALTER TABLE notes ADD COLUMN user_id INTEGER REFERENCES users(id);
CREATE INDEX idx_notes_user_id ON notes(user_id);

-- DOWN (rollback)
-- DROP INDEX idx_notes_user_id;
-- ALTER TABLE notes DROP COLUMN user_id;
```

**Documentation** (Markdown):
```markdown
## Note

| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT |
| title | TEXT | NOT NULL |
| body | TEXT | |
| user_id | INTEGER | REFERENCES users(id) |
| created_at | TEXT | DEFAULT datetime('now') |
| updated_at | TEXT | DEFAULT datetime('now') |

### Relationships
- **belongs_to** User (via user_id)
- **has_many** Tags (via note_tags junction)
```

### 5.3 Migration System

Inspired by Flyway's simplicity + Atlas's auto-generation + TMS's selective application:

```
migrations/
├── V001__initial_schema.sql        ← auto-generated from first .model
├── V002__add_tags.sql              ← auto-generated from schema diff
├── V003__add_user_id_to_notes.sql  ← auto-generated, reviewed by developer
├── V004__add_indexes.sql
└── migration_history.json          ← tracks what's been applied
```

**Workflow:**
1. Edit `.model` file (or ask AI to edit it)
2. Run `toolkit migrate:generate` — diffs current schema vs last version, produces SQL
3. **Review** the generated SQL (AI can explain it)
4. Run `toolkit migrate:apply` — executes against the database
5. Version snapshot is saved automatically

**Safety features** (learned from Atlas + TMS):
- Destructive change warnings (DROP TABLE, DROP COLUMN)
- Data-dependent change detection ("this ALTER may fail if column has NULLs")
- Dry-run mode (show SQL without executing)
- Rollback scripts generated alongside UP scripts

### 5.4 Version Control

**Two layers of versioning:**

1. **Schema snapshots** — each version of the `.model` file is archived with metadata
2. **Migration history** — which migrations have been applied to which database

**Version comparison** (inspired by TMS Data Modeler):
- Side-by-side diff of any two schema versions
- Filter by change type (added tables, modified columns, dropped indexes)
- Generate alter scripts from selected changes only

### 5.5 AI Agent Integration

The AI agent enhances every step of the workflow:

| Task | How AI Helps |
|------|-------------|
| **Schema design** | "Create a blog schema with posts, comments, and categories" → generates `.model` file |
| **Migration review** | "This migration drops the `email` column from users. 47 rows have data. Proceed?" |
| **Documentation** | Auto-generates model reference docs in the developer-guide format |
| **Index suggestions** | Analyzes query patterns in ViewModels, suggests missing indexes |
| **Code review** | Reviews generated Xojo code for MVVM compliance |
| **Test data** | Generates realistic seed data matching schema constraints |
| **Schema evolution** | "Add soft-delete to all models" → modifies schema + generates migration |

**MCP Server tools** (exposed to Claude Code / OpenCode):

```json
{
  "tools": [
    {"name": "schema_read",       "description": "Read current schema definition"},
    {"name": "schema_edit",       "description": "Modify schema (add/alter/drop models)"},
    {"name": "schema_validate",   "description": "Validate schema for errors and warnings"},
    {"name": "schema_diff",       "description": "Compare two schema versions"},
    {"name": "migrate_generate",  "description": "Generate migration SQL from schema changes"},
    {"name": "migrate_apply",     "description": "Apply pending migrations to database"},
    {"name": "migrate_status",    "description": "Show migration history and pending changes"},
    {"name": "codegen_model",     "description": "Generate Xojo Model class from schema"},
    {"name": "codegen_viewmodel", "description": "Generate ViewModel stubs for a model"},
    {"name": "codegen_template",  "description": "Generate JinjaX HTML templates for CRUD"},
    {"name": "docs_generate",     "description": "Generate documentation pages for models"},
    {"name": "db_inspect",        "description": "Inspect live database schema"},
    {"name": "db_query",          "description": "Run read-only query on database"},
    {"name": "reverse_engineer",  "description": "Import existing database into schema file"}
  ]
}
```

### 5.6 Project Validation (TMS-inspired)

Automatic checks on every schema change:

**Errors:**
- Table without any columns
- Column without a type
- Foreign key referencing non-existent table/column
- Circular references without explicit handling
- Duplicate table/column names
- Primary key missing on non-junction table

**Warnings:**
- Table without a primary key
- Foreign key column type mismatch with referenced column
- Reserved word used as table/column name (per target DB)
- Missing index on foreign key column
- Column name exceeds DB-specific length limit
- No `updated_at` timestamp column (convention warning)

---

## 6. Implementation Plan

### Recommended Platform Strategy

**Phase 1-3: Python CLI** — fast to build, AI-friendly, testable
**Phase 4+: Xojo Desktop** — visual schema browser, ER diagrams, migration manager

The Python CLI becomes the **engine** that the Xojo Desktop app calls via shell. This is the same architecture that the developer-guide uses (Python build script, Xojo app).

---

### Phase 1 — Foundation (Schema Parser + SQL Generator)
**Goal:** Parse `.model` files and generate SQL DDL
**Deliverables:**
- Schema Definition Language (SDL) specification
- Parser: `.model` → AST (Python, clean data classes)
- SQL Generator: AST → `CREATE TABLE` statements (SQLite first)
- CLI: `toolkit init`, `toolkit validate`, `toolkit sql`
- Unit tests for parser and generator
- Sample `.model` file for the MVVM project's current schema (notes, tags, users, note_tags)

**Key decisions:** Finalize SDL syntax, validation rules

---

### Phase 2 — Code Generation (Xojo Output)
**Goal:** Generate complete Xojo `.xojo_code` files from schema
**Deliverables:**
- Xojo Model class generator (BaseModel subclass with TableName, Columns, CRUD methods)
- Xojo ViewModel stub generator (list, detail, create, edit, delete)
- JinjaX template generator (list, detail, form, delete-confirm)
- Route registration snippet generator
- CLI: `toolkit generate model Note`, `toolkit generate scaffold Note`
- Regeneration with custom-code preservation (marker comments for safe zones)

**Key decisions:** Code generation templates, custom-code preservation strategy

**Question to be answered:** Should the templates of .xojo_code can be save in Jinja format? Since we already have JinjaX for Xojo already. May be useful if it's not too slow.

---

### Phase 3 — Migration Engine
**Goal:** Track schema changes and generate/apply migrations
**Deliverables:**
- Schema differ: compare two ASTs, produce changeset
- Migration SQL generator: changeset → numbered SQL files (UP + DOWN)
- Migration runner: apply pending migrations to SQLite database
- Migration history tracker (`_migrations` table in DB or JSON file)
- Destructive change detection and warnings
- Dry-run mode
- CLI: `toolkit migrate:generate`, `toolkit migrate:apply`, `toolkit migrate:status`, `toolkit migrate:rollback`

**Key decisions:** Migration naming convention, rollback strategy, history storage

---

### Phase 4 — Reverse Engineering + Version Management
**Goal:** Import existing databases, manage schema versions
**Deliverables:**
- SQLite reverse engineer: `PRAGMA table_info` / `PRAGMA foreign_key_list` → AST → `.model` file
- Version snapshots: save/load schema at points in time
- Version comparison: diff any two snapshots, show changes
- Selective alter script generation (TMS-style: pick which changes to include)
- CLI: `toolkit import:sqlite path/to/db`, `toolkit version:save "description"`, `toolkit version:diff v1 v2`

**Key decisions:** Snapshot storage format, PostgreSQL reverse engineering (if multi-DB)

---

### Phase 5 — AI Agent + MCP Server
**Goal:** AI-powered schema design, review, and documentation
**Deliverables:**
- MCP server exposing all toolkit operations as tools
- AI schema generation: natural language → `.model` file
- AI migration review: explain changes, warn about risks
- AI documentation generation: schema → developer-guide Markdown pages
- AI index suggestions: analyze ViewModel queries for missing indexes
- Integration with Claude Code and OpenCode
- CLI: `toolkit ai:review`, `toolkit ai:docs`, `toolkit ai:suggest-indexes`

**Key decisions:** MCP server implementation (Python stdio), AI model choice, prompt engineering

---

### Phase 6 — Xojo Desktop Application
**Goal:** Visual interface for schema management
**Deliverables:**
- Schema browser (tree view of models, columns, relationships)
- Property inspector (edit column properties in a panel)
- Migration manager (list, preview, apply, rollback)
- Version comparison viewer (side-by-side diff)
- Validation results panel
- Calls Python CLI engine for all operations

**Key decisions:** UI layout, Xojo controls vs HTML-rendered views

---

### Phase 7 — Visual ER Diagrams (Xojo Desktop)
**Goal:** Auto-generated and interactive ER diagrams
**Deliverables:**
- ER diagram renderer (using Xojo Canvas or Object2D)
- Auto-layout algorithm for table positioning
- Relationship lines with cardinality markers
- Export to PNG/SVG
- Optional: drag-and-drop table placement
- Diagram-as-view (multiple diagrams per project showing subsets)

**Key decisions:** Rendering approach, interactivity level

---

### Phase 8 — Multi-Database Support
**Goal:** Support PostgreSQL alongside SQLite
**Deliverables:**
- PostgreSQL SQL generator (types, sequences, schemas)
- PostgreSQL reverse engineer (via `information_schema`)
- PostgreSQL migration runner
- Database-agnostic type mapping (like TMS's logical domains)
- MCP server for PostgreSQL access
- CLI: `toolkit target:postgres`, type conversion warnings

**Key decisions:** Type mapping strategy, connection management

---

## 7. Technology Choices

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Core engine | Python 3 | Fast to build, AI-friendly, you already use it for developer-guide |
| Schema parser | Python (lark or hand-written recursive descent) | Full control over SDL syntax |
| SQL generation | Python string templates | Simple, debuggable, per-dialect |
| Xojo code gen | Python Jinja2 templates | Already in your stack, perfect for code templates |
| Migration runner | Python + sqlite3 stdlib | Zero dependencies for SQLite |
| MCP server | Python (stdio transport) | Standard MCP pattern, easy to integrate |
| CLI interface | Python (argparse or click) | Lightweight, no TTY-toolkit needed for v1 |
| Desktop GUI | Xojo Desktop | Phase 6+, your expertise, native macOS |
| Version storage | JSON files in project directory | Git-friendly, simple, inspectable |
| AI integration | Anthropic API (Claude) | Already in your workflow |

---

## 8. File Structure

```
model-toolkit/
├── PROPOSAL.md              ← this document
├── schema/                  ← schema definition files
│   └── mvvm.model           ← the project's schema
├── migrations/              ← generated migration SQL files
│   ├── V001__initial.sql
│   └── ...
├── versions/                ← schema version snapshots
│   └── ...
├── generated/               ← generated Xojo code (staging area)
│   ├── Models/
│   ├── ViewModels/
│   └── templates/
├── docs/                    ← generated documentation
│   └── models/
├── toolkit/                 ← Python source code
│   ├── __init__.py
│   ├── cli.py               ← CLI entry point
│   ├── parser.py            ← SDL parser
│   ├── schema.py            ← AST data classes
│   ├── validator.py         ← project validation
│   ├── differ.py            ← schema diff engine
│   ├── generators/
│   │   ├── sql.py            ← SQL DDL generator
│   │   ├── xojo.py           ← Xojo .xojo_code generator
│   │   ├── migration.py      ← migration SQL generator
│   │   └── docs.py           ← documentation generator
│   ├── reverse/
│   │   ├── sqlite.py         ← SQLite reverse engineering
│   │   └── postgres.py       ← PostgreSQL reverse engineering
│   ├── migrate/
│   │   ├── runner.py         ← migration executor
│   │   └── history.py        ← migration tracking
│   ├── versions/
│   │   └── store.py          ← version snapshot management
│   ├── ai/
│   │   ├── agent.py          ← AI integration
│   │   └── prompts.py        ← prompt templates
│   └── mcp/
│       └── server.py         ← MCP server for Claude Code
├── templates/                ← Jinja2 templates for code generation
│   ├── xojo_model.j2
│   ├── xojo_viewmodel.j2
│   ├── jinjax_list.j2
│   ├── jinjax_form.j2
│   ├── migration_up.j2
│   └── doc_model.j2
├── tests/                   ← Python unit tests
│   ├── test_parser.py
│   ├── test_validator.py
│   ├── test_differ.py
│   ├── test_sql_gen.py
│   └── test_xojo_gen.py
└── pyproject.toml            ← Python project config
```

---

## 9. Usage Examples (How It Would Feel)

### CLI Usage

```bash
# Initialize a new project
$ toolkit init --db sqlite
Created schema/project.model

# Import existing database
$ toolkit import:sqlite ../data/notes.sqlite
Imported 4 tables: notes, tags, note_tags, users
Written to schema/mvvm.model

# Validate schema
$ toolkit validate
✓ 4 models, 0 errors, 1 warning
⚠ notes: no index on foreign key column user_id

# Edit schema (add a column)
# ... edit schema/mvvm.model, add "email String? @unique" to User ...

# Generate migration
$ toolkit migrate:generate -m "add email to users"
Generated: migrations/V005__add_email_to_users.sql
  ↑ ALTER TABLE users ADD COLUMN email TEXT UNIQUE
  ↓ (rollback) ALTER TABLE users DROP COLUMN email

# Review with AI
$ toolkit ai:review migrations/V005__add_email_to_users.sql
🤖 This migration adds a nullable email column with a UNIQUE constraint.
   Safe to apply — no existing data will be affected.
   Consider: adding a NOT NULL constraint later after backfilling.

# Apply migration
$ toolkit migrate:apply
Applied V005__add_email_to_users.sql ✓
Migration history updated.

# Generate Xojo code
$ toolkit generate model User
Generated: generated/Models/UserModel.xojo_code

# Scaffold full CRUD
$ toolkit generate scaffold Note
Generated:
  generated/Models/NoteModel.xojo_code
  generated/ViewModels/Notes/NotesListVM.xojo_code
  generated/ViewModels/Notes/NotesDetailVM.xojo_code
  generated/ViewModels/Notes/NotesCreateVM.xojo_code
  generated/ViewModels/Notes/NotesEditVM.xojo_code
  generated/ViewModels/Notes/NotesDeleteVM.xojo_code
  generated/templates/notes/list.html
  generated/templates/notes/detail.html
  generated/templates/notes/form.html
  generated/templates/notes/delete.html

# Generate documentation
$ toolkit docs:generate
Generated: docs/models/note.md, docs/models/tag.md, docs/models/user.md
```

### MCP Server Usage (from Claude Code)

```
User: Add a "categories" table with name and description, and link it to notes

Claude: I'll use the Model Toolkit to add this.
  → [schema_read] Reading current schema...
  → [schema_edit] Adding Category model and NoteCategory junction...
  → [schema_validate] Validating... ✓ 0 errors
  → [migrate_generate] Generating migration V006__add_categories.sql
  → [codegen_model] Generating CategoryModel.xojo_code
  → [docs_generate] Updating model documentation

Done! I've added:
- Category model (id, name, description, created_at)
- NoteCategory junction table
- Migration V006 ready to apply
- CategoryModel.xojo_code generated
```

---

## 10. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| SDL syntax too complex | Users won't adopt | Start minimal, add features by demand |
| Xojo code gen breaks on IDE import | Blocking | Test every generated file in Xojo IDE early |
| SQLite ALTER limitations | Some migrations impossible | Document limitations, provide workarounds (create new table, copy data, rename) |
| AI hallucinations in schema design | Bad schemas generated | Always validate + require human review before apply |
| Scope creep toward full ORM | Never ships | Stay focused: schema → code → migration → docs. No query builder. |
| Two-language stack (Python + Xojo) | Maintenance burden | Python is the engine, Xojo is optional GUI. Engine works standalone. |

---

## 11. What Makes This Unique

1. **Xojo-native code generation** — no other tool generates `.xojo_code` files
2. **MVVM-aware** — understands the Dictionary data contract, BaseModel pattern, ViewModel/template structure
3. **AI-first migration review** — every schema change gets AI safety analysis
4. **Schema-first with reverse engineering** — works for new projects AND existing databases
5. **MCP integration** — use it from within your AI coding workflow, not as a separate tool
6. **Opinionated for your stack** — not a generic database tool, but one that knows your conventions

---

## 12. Follow-Up Questions (Round 2)

Your answers reshape the proposal significantly. The biggest shifts:

- **All-Xojo stack** (xojo-ttytoolkit CLI + JinjaX code gen) — no Python at all
- **ER viewer/editor is Phase 1 priority** (not deferred to Phase 7)
- **Prisma-style separation** — generated code lives in a "do not edit" layer

Here are the deeper questions these answers raise:

### Architecture: All-Xojo Stack

**Q12. xojo-ttytoolkit is a Console App toolkit. The ER editor needs HTMLViewer (AntV X6). How should these coexist?**

Two possible architectures:

- **A) Two separate apps**: a Console app (`model-toolkit` CLI using xojo-ttytoolkit) for schema/migration/codegen commands, and a Desktop app (`model-viewer`) for the ER diagram + property editor. The CLI launches the Desktop app when needed (e.g., `toolkit diagram` opens the viewer).
- **B) One Desktop app with dual personality**: a Xojo Desktop app that has an HTMLViewer for the ER diagram AND can be invoked from the command line (Xojo Desktop apps can accept `System.CommandLine` arguments, though they still show a window).
- **C) Desktop app only**: skip the CLI, do everything through the Desktop GUI with menus/toolbar. Use xojo-ttytoolkit only for a lightweight helper (e.g., `toolkit migrate:apply` for server-side use where no GUI is available).

Which approach do you prefer?

**A12** A) Two separate apps:

**Q13. JinjaX for code generation templates — how should templates be stored?**

Your question from Phase 2: "Should the templates of .xojo_code be saved in Jinja format?"

JinjaX is fully standalone (confirmed — no web dependency). Two storage approaches:

- **A) FileSystemLoader** — templates stored as `.j2` files in a `templates/codegen/` folder alongside the toolkit:
  ```
  model-toolkit/
  ├── templates/codegen/
  │   ├── base_model.xojo.j2      ← JinjaX template
  │   ├── viewmodel_list.xojo.j2
  │   └── viewmodel_create.xojo.j2
  ```
  Easier to edit, AI can modify them, visible in git.

- **B) DictLoader** — templates embedded as string constants in a Xojo module:
  ```xojo
  Module CodegenTemplates
    Const ModelTemplate As String = "..."
  End Module
  ```
  Self-contained (single binary), but harder to edit and version.

- **C) Hybrid** — ship with embedded defaults (DictLoader), but allow user overrides via FileSystemLoader (check filesystem first, fall back to embedded). Like Rails generators.

Which approach?

**A13** C) Hybrid

**Q14. Parser in Xojo — are you comfortable with building a recursive descent parser in Xojo?**

The `.model` SDL needs a parser. In Python this would be trivial (lark, pyparsing). In Xojo, we'd write a hand-rolled recursive descent parser (tokenizer → AST). Your JinjaX implementation already has a full parser (JinjaLexer, JinjaParser), so the pattern is proven.

But it's more code than Python. Alternatively:
- **A) Hand-rolled Xojo parser** — full control, proven pattern from JinjaX, no dependencies
- **B) Simpler format** — use YAML instead of a custom DSL (XjTTYLib already has `XjYAML`), which eliminates the parser entirely:
  ```yaml
  project: mvvm-notes
  database: sqlite
  
  models:
    Note:
      id: Integer @primary @autoincrement
      title: String @required
      body: String?
      user_id: Integer @references(User.id)
      created_at: DateTime @default(now)
      updated_at: DateTime @default(now) @on_update(now)
  
    Tag:
      id: Integer @primary @autoincrement
      name: String @required
      created_at: DateTime @default(now)
  ```
  The `XjYAML` parser handles structure; you only need a lightweight annotation parser for `@primary`, `@references(...)`, etc.

- **C) JSON schema file** — simplest to parse (Xojo has JSONItem built-in), but less human-friendly

Which do you prefer? Option B (YAML + annotation parser) is the sweet spot — reuses your existing XjYAML and cuts parser work by 80%.

**A14** It may be B) but what's about performance between XjYAML vs JinjaX parser? Can we do algorithms analysis and other pros and cons between 2 competitors?

### Prisma-Style Code Separation

**Q15. How should the "do not edit" vs "custom code" split work in practice?**

Three patterns used in the industry:

- **A) Separate files, inheritance chain**:
  ```
  Models/
  ├── _generated/           ← "DO NOT EDIT" — regenerated freely
  │   ├── NoteModelBase.xojo_code    (TableName, Columns, CRUD)
  │   └── TagModelBase.xojo_code
  └── NoteModel.xojo_code            ← YOUR CODE — inherits NoteModelBase
      TagModel.xojo_code             (custom methods: GetTagsForNote, etc.)
  ```
  `NoteModel Inherits NoteModelBase`. Generated base has all boilerplate. Your custom `NoteModel` adds `GetTagsForNote`, association logic, etc.

- **B) Separate files, partial-class style** (Xojo doesn't have partial classes, so you'd use a module + extension pattern):
  ```
  Models/
  ├── _generated/NoteModel.Generated.xojo_code   ← DO NOT EDIT
  └── NoteModel.xojo_code                        ← YOUR CODE (calls generated methods)
  ```
  Less clean in Xojo since you can't split a class across files.

- **C) Single file with marker comments**:
  ```xojo
  // ===== GENERATED — DO NOT EDIT BELOW =====
  Function TableName() As String
    Return "notes"
  End Function
  // ===== END GENERATED =====
  
  // ===== CUSTOM CODE — your methods below =====
  Function GetTagsForNote(noteID As Integer) As Variant()
    // ...
  End Function
  ```
  Simpler but fragile — risk of accidental edits in the generated zone.

**Option A (inheritance) is the cleanest for Xojo.** It maps naturally to Xojo's class hierarchy: `NoteModel Inherits NoteModelBase Inherits BaseModel`. But it means changing your existing code to use a 3-level inheritance chain.

Which pattern do you prefer? And are you OK with the 3-level inheritance (`NoteModel → NoteModelBase → BaseModel`)?

**A15** Option A for sure

### ER Diagram Scope

**Q16. For Phase 1 ER viewer — read-only or editable?**

Building a full drag-and-drop ER *editor* (create tables, add columns, draw FK lines) with AntV X6 + Xojo property panel is substantial work. Two approaches:

- **A) Phase 1 = read-only viewer**: parse `.model` file → render ER diagram in HTMLViewer. Click a table to see its columns in a native panel. No editing in the diagram — edit the `.model` file directly or via CLI prompts.
- **B) Phase 1 = full editor**: create/edit/delete tables visually, draw FK relationships, property panel edits columns. Changes write back to `.model` file.

Option A ships in days. Option B takes weeks. Which do you want first?

**A16** A) Phase 1 - read only

**Q17. ER diagram — from `.model` file or from live database?**

- **A) From `.model` file** — read the schema DSL, render as diagram. Source of truth is the text file.
- **B) From live SQLite database** — reverse-engineer via `PRAGMA table_info`, render as diagram. Source of truth is the DB.
- **C) Both** — primary from `.model`, but also support "inspect this database" mode.

This connects to Q3 (you chose Schema DSL as source of truth), so A or C?

**A17** C) Both

### Migration & Versioning Details

**Q18. Snapshot storage format?**

For TMS-style snapshots, how should versions be stored?

- **A) Timestamped copies of the `.model` file**:
  ```
  versions/
  ├── 2026-03-12_initial.model
  ├── 2026-03-13_add-categories.model
  └── manifest.json        ← list of versions with descriptions
  ```
- **B) Git tags/commits** — just tag the git repo at meaningful points, no separate storage. Use `git diff` for comparison.
- **C) Delta-based** — store only the diff between versions (more complex, smaller files).

Option A is simplest and self-contained. Option B leverages git you already use. Which?

**A18** A) timestamped copies

**Q19. SQLite ALTER TABLE limitations — how to handle?**

SQLite has major ALTER TABLE limitations:
- Can ADD COLUMN (since 3.2.0)
- Can RENAME COLUMN (since 3.25.0)
- Can DROP COLUMN (since 3.35.0)
- **Cannot**: change column type, add/remove constraints, modify defaults

For unsupported changes, the standard workaround is the "12-step" process:
1. Create new table with desired schema
2. Copy data from old table
3. Drop old table
4. Rename new table

Should the migration generator:
- **A) Auto-generate the 12-step process** when needed (complex but hands-free)
- **B) Warn and let the developer write the migration manually** (simpler, safer)
- **C) Hybrid** — auto-generate 12-step for simple cases (type change, add constraint), warn for complex ones (data transformation)

**A19** It should be A) only. Also has specific procedures for each database brands to let us handle edge cases of each database engines later.

### Output & Documentation

**Q20. "Generate report with JinjaX, view on default browser" — what reports?**

You mentioned generating reports viewable in the browser. Which reports do you envision?

- **A) Schema documentation** — model reference pages (like the developer-guide format)
- **B) Migration report** — what changed, what SQL will run, risk assessment
- **C) Validation report** — errors and warnings with clickable links
- **D) Version comparison** — side-by-side diff of two schema versions (like TMS)
- **E) All of the above**

And should these use the developer-guide's existing page.html layout + CSS (consistent look), or a separate simpler template?

**A20** E) All of the above

**Q21. Should the ER diagram be embeddable in the developer-guide documentation?**

You already have nomnoml for architecture diagrams in the developer-guide. Should the toolkit also:
- **A) Export the ER diagram as a nomnoml-compatible block** (for embedding in `.md` pages)
- **B) Export as SVG/PNG** (for manual insertion)
- **C) Auto-generate a developer-guide page** with the ER diagram + model docs in one page
- **D) Not needed** — ER diagram is only in the toolkit app

**A21** A) should be enough

---

## Next Steps

1. **Answer Round 2 questions** (Q12–Q21) — these finalize the technical architecture
2. **Revise the proposal** with updated architecture (all-Xojo, xojo-ttytoolkit CLI, JinjaX codegen, AntV X6 ER viewer)
3. **Revise the phase plan** — ER viewer moves to Phase 1, Python references removed
4. **Build Phase 1** — start implementation
