#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

./install.sh --nvim --zsh --chsh --lazygit --beads

# ---------------------------------------------------------------------------
# PATH for the devcontainer's default shell
# ---------------------------------------------------------------------------
# Devcontainer Dockerfiles set ENV SHELL=/bin/bash, so the dotfiles zshrc's
# npm-global PATH export never applies inside the container. Add
# ~/.npm-global/bin to .bashrc (idempotently) so npm-installed CLIs (bd, pi,
# copilot) are found in container terminals.
if ! grep -qs "npm-global/bin" "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
fi
