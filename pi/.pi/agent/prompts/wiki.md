---
description: Analyze the codebase and produce structured markdown wiki pages (architecture, modules, APIs, conventions)
---

Analyze the current codebase and produce a set of structured Markdown pages
covering **architecture**, **modules**, **APIs**, and **conventions**. Write them
into a `wiki/` directory.

## Before you start

- Read the project's own guidance first (`AGENTS.md`, `CLAUDE.md`, or similar)
  and any existing docs (e.g. `architecture/`, `docs/`) so the wiki aggregates
  and links to them rather than duplicating them.
- Determine the project's structure: top-level modules/packages, entry points,
  public interfaces, and build/test/lint conventions.

## Output structure

Create `wiki/` with at least:

- `README.md` — landing page: what the project is, a table of contents, and a
  module/package index linking to each module page.
- `architecture.md` — system overview and data flow. Link to any existing
  architecture docs/diagrams instead of copying them.
- `modules/` — one page per module/package: purpose, key files, entry points,
  and how it relates to other modules.
- `apis.md` — public interfaces: functions, classes, endpoints, message types,
  config schemas, etc. (adapt to the project's actual interface types).
- `conventions.md` — coding style, naming, formatting/lint rules, and the
  project's build/test/commit conventions.

## Guidelines

- Base every page on what you actually find in the code; don't invent APIs.
- Keep pages concise and developer-readable — prose plus short code/signature
  snippets, not raw file dumps.
- Link between pages (relative links) so the wiki is navigable.
- If a `wiki/_manifest.json` exists, update it to record the files you generated
  and their checksums so future runs can detect what changed.
- Report a short summary of what you created and any gaps you found.
