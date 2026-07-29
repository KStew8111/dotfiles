---
description: Wake or sleep the petdex mascot. Toggles the floating pet on/off
---

The user wants to control the petdex mascot from inside the agent. The mascot is a floating macOS window driven by hooks installed in agent settings. /petdex is a one-shot toggle that flips the entire state in a single command.

Run the matching command using the persisted petdex binary at `$HOME/.petdex/bin/petdex.js` (always present after `petdex hooks install`):

- `/petdex` (no args) → run `node "$HOME/.petdex/bin/petdex.js" toggle`
- `/petdex up` → run `node "$HOME/.petdex/bin/petdex.js" up`
- `/petdex down` → run `node "$HOME/.petdex/bin/petdex.js" down`
- `/petdex status` → run `node "$HOME/.petdex/bin/petdex.js" hooks status`
- `/petdex doctor` → run `node "$HOME/.petdex/bin/petdex.js" doctor`

Show the command output verbatim to the user. Don't reinterpret, don't explain. The CLI's output is already user-facing.

If `$HOME/.petdex/bin/petdex.js` doesn't exist, the user hasn't run `petdex hooks install` yet. Tell them to run `npx petdex@latest init` first, then retry.

Arguments: `$ARGUMENTS`
