---
description: Create a CI workflow that regenerates the wiki on every push to the default branch
---

Create a CI workflow that regenerates the `wiki/` directory on every push to the
default branch, so the wiki stays in sync with the code.

## Steps

1. **Detect the CI provider** from the repo (e.g. `.github/workflows/` for GitHub
   Actions, `.gitlab-ci.yml` for GitLab, etc.) and match its existing conventions
   (runners, default branch, secrets).
2. **Create a workflow** that, on push to the default branch:
   - Checks out the repo.
   - Installs pi (`@earendil-works/pi-coding-agent`).
   - Runs pi non-interactively to regenerate the wiki, e.g.
     `pi -p "Regenerate the wiki in wiki/ based on the current codebase"`,
     with the provider API key supplied from a CI secret.
   - Commits any changed files under `wiki/` back to the repo (or opens a PR),
     using a bot identity, and pushes.
3. **Document the required secret** (e.g. the provider API key) in the workflow
   or a comment so it's clear what must be configured.

## Guidelines

- The wiki must live inside a git repo for CI to commit it. If the wiki is not
  currently in a repo, note that and place it in the primary repo.
- Make the workflow idempotent: if nothing changed, it should make no commit.
- Don't run the full test/build pipeline — this job only regenerates docs.
- Report the workflow file you created and the secret(s) that must be set.
