---
description: Turn a rough task idea into a detailed, self-contained prompt for a planning agent
argument-hint: "<rough task idea>"
---

Draft a detailed prompt that will be handed to a planning agent. The rough idea
is:

> ${@:-the task currently being discussed in this conversation}

## Before drafting

- Read the project's own guidance first: `AGENTS.md`, `CLAUDE.md`, or similar
  context files in the repo root (and any referenced sub-guides), so the prompt
  reflects real conventions rather than assumptions.
- Inspect the code enough to ground the prompt in reality: identify the actual
  files, modules, interfaces, and commands involved. Reference them by path.
- If earlier conversation established decisions or constraints relevant to the
  task, carry them in explicitly — do not assume the planning agent has this
  conversation as context.

## Output format

Emit exactly one fenced code block containing the finished prompt, ready to
paste into a planning session. The prompt must have these sections:

1. **Objective** — one or two sentences on the end state, not the how.
2. **Context** — background the planner can't discover itself: prior decisions,
   related work, affected files/modules with paths, cross-module coupling.
3. **Requirements** — explicit, individually testable requirements. Number them.
4. **Constraints** — hard limits: compatibility, performance, style, scope
   boundaries, things that must not change.
5. **Out of scope** — adjacent work that looks tempting but is explicitly not
   part of this task.
6. **Acceptance criteria** — how success is verified: commands to run, behavior
   to observe, states that must hold.
7. **Open questions** — anything ambiguous that the planner should resolve or
   flag before implementation starts.

## Guidelines

- Write the prompt so it stands alone: a fresh agent with no memory of this
  conversation should be able to act on it.
- Be concrete over abstract — file paths, symbols, and commands over vague
  gestures.
- Keep it tight: every sentence should remove ambiguity for the planner. Cut
  anything that doesn't.
- Do not begin implementing; the deliverable is the prompt itself.