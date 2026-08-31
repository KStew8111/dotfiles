# Global agent guidance

## Plan structure (applies whenever you produce an implementation plan)

When asked to produce a plan — whether via plan mode (`/plan` / `plan_mode_complete`), the
`/write-plan` template, or any "plan this feature" request — structure the plan with
these sections, in this order:

1. **Goal** — one or two sentences on what should be true after the change.
2. **Scope & impact** — which modules/packages/files are touched; whether public
   interfaces, config, schemas, or build dependencies change. Note cross-module coupling.
3. **Design** — the approach, key files, and the interfaces involved, referencing
   relevant entry points and configuration.
4. **Steps** — numbered, concrete implementation steps in dependency order. Keep
   each step small enough to review.
5. **Build & test plan** — exact commands to build, run tests, and verify behavior
   at runtime, taken from the project's own guidance (`AGENTS.md`/`CLAUDE.md` in the
   repo), not guessed.
6. **Risks & unknowns** — gotchas, format/lint expectations, and open questions that
   need answers before coding.

Guidelines: prefer small reviewable increments; before finalizing, read the project's
own guidance files and identify its real build/test/lint commands; flag anything that
needs clarification before implementation begins.