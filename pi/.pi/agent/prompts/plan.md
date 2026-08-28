---
description: Produce a structured implementation plan for a feature or change
argument-hint: "<feature or change description>"
---

Produce a clear, actionable implementation plan for the following change:

> $@

## Before planning

- Read the project's own guidance first and follow it: `AGENTS.md`, `CLAUDE.md`,
  or similar context files in the repo root (and any referenced sub-guides).
- Identify the project's build, test, and lint commands from that guidance (or
  by inspecting the repo) so the plan uses the real commands, not guesses.

## Required sections

1. **Goal** — one or two sentences on what should be true after the change.
2. **Scope & impact** — which modules/packages/files are touched, and whether
   the change affects public interfaces, config, schemas, or build dependencies.
   Note any cross-module coupling.
3. **Design** — the approach, key files, and the interfaces involved. Reference
   the relevant entry points and configuration.
4. **Steps** — numbered, concrete implementation steps in dependency order. Keep
   each step small enough to review.
5. **Build & test plan** — the exact commands to build, run tests, and verify
   behavior at runtime, taken from the project's own conventions.
6. **Risks & unknowns** — potential gotchas, format/lint expectations, and any
   open questions that need answers before coding.

## Guidelines

- Prefer small, reviewable increments over one large change.
- Call out anything that needs clarification before implementation begins.
- End with a short "Ready to implement" summary listing the first step to start.
