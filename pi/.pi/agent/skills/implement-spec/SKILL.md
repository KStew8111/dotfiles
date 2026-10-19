---
name: implement-spec
description: "Implement the result of /to-spec and /to-tickets in code."
disable-model-invocation: true
---

<!--
Local fork of vendor/mattpocock-skills/skills/engineering/implement-spec (forked at 24fe0ef).
Local additions: the "Readable history" section and the history hooks in steps 3-5.
When the vendor skill changes, merge its edits here.
-->

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

The goal is the entire spec implemented on a single **integration branch**, with every ticket resolved the way the issue tracker closes work.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

**Implementer subagents** should be run in the background where possible for maximum concurrency.

## Readable history

The tracker lives outside the repo, so a reviewer reading `git log` cannot see it. Write history that is **self-describing**: a reader who has only the repo should understand what each branch and commit changed and why.

- **Branch names** describe the change in a short kebab-case slug, e.g. `wa-map-latched-input-health`, `diagnostics-advisory-attribution`. Name the integration branch after the spec's outcome the same way.
- **Commit and merge messages** use a subject that says what behaviour changed, plus a body that summarises what was built and why. Write this summary from the ticket's "what to build" and acceptance criteria, in the repo's own terms. A merge subject names the delivered capability, e.g. `Merge working-area map health diagnostics`.
- **In-repo spec.** The spec, and every document it cites as normative (inventories, registries, schemas), is committed in the repo that owns the behaviour, under `docs/`. In a multi-repo workspace, put it in the repo the spec treats as its primary owner, and in each other touched repo add a short `docs/` note that points to it.

## Steps

1. Read the spec and tickets to understand the task graph.

2. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

3. Create the integration branch, named per **Readable history**. Its first commit adds the **in-repo spec**; this step is done when every document the spec cites as normative resolves to a committed file. If the issue tracker closes work through PRs, or the user asks for one, open a draft PR after the first merge in step 5 (a branch with no commits ahead of main can't open one), marked as closing the spec and tickets.

4. Use **implementer subagents** to implement each ticket, each in its own worktree on its own branch, named per **Readable history**. Each implementer subagent:
   - confirms its worktree is based on the integration branch before starting, and resets onto it if not;
   - calls the Skill tool with `tdd` to build the ticket;
   - writes commit messages per **Readable history**;
   - merges the integration branch tip into its own branch before reporting done

5. Once an **implementer subagent** completes, merge its work to the integration branch with a **merger subagent**. The merge commit message follows **Readable history**: a capability subject and a body summarising what the ticket delivered.

6. If this changes the **frontier** of available tickets, kick off more **implementer subagents** to work on the new tickets. This allows for maximum concurrency.

7. Once all tickets are complete, call the Skill tool with `code-review` on the integration branch. Fix all issues raised by the code review in a single **implementer subagent**.

8. If a draft PR exists, mark it ready for review. Otherwise, resolve each ticket the way the issue tracker closes work, and report the integration branch.

9. Clean up all **implementer subagent** worktrees.
