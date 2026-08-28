---
description: Review the current uncommitted/unsaved changes
---

Review the current changes and give focused, actionable feedback.

## Before reviewing

- Read the project's own guidance first and follow it: `AGENTS.md`, `CLAUDE.md`,
  or similar context files in the repo root (and any referenced sub-guides).
- Identify the project's build, test, and lint commands from that guidance so
  the review checks against the real conventions.

## What to review

Unless a target is given, review the local changes for the project/area we are
working in. Identify what changed first (e.g. `git diff` / `git status`), then
review those files.

> $@

## Focus areas

- **Correctness** — logic errors, off-by-one, null/empty handling, integer
  overflow, resource leaks.
- **Framework/domain specifics** — correct use of the project's core
  abstractions, interfaces, and configuration; no misuse of its conventions.
- **Safety & determinism** — input validation, bounds checks, handling of
  missing/invalid data, no unguarded access, thread-safety and locking.
- **Build & lint** — would this pass the project's build and test commands?
  Conformance with its format/lint config (e.g. `.clang-format`, `.clang-tidy`,
  linters, formatters).
- **Error handling** — are failures surfaced, logged, or swallowed?
- **Cross-module coupling** — unintended dependency on another module's
  internals, config/interface assumptions.

## Output format

For each significant issue, report:
- File and (approximate) line
- Severity: `blocking` / `should-fix` / `nit`
- One-line summary plus why it matters

Then give a short overall assessment and a prioritized list of the top fixes.

## Guidelines

- Be concrete; suggest the fix, don't just flag the problem.
- Don't review generated/build artifacts (e.g. `build/`, `dist/`, `node_modules/`,
  `install/`, `log/`).
- If the change is small, this should stay brief.
