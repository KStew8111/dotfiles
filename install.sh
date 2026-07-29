#!/bin/bash

set -e

cd "$HOME/dotfiles"

# Detect Ubuntu major version (falls back to 0 on non-Ubuntu systems)
UBUNTU_VER=0
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" = "ubuntu" ]; then
    UBUNTU_VER=$(echo "$VERSION_ID" | cut -d. -f1)
  fi
fi

# Ubuntu 22 and older → AstroNvim v5 (nvim-legacy)
# Ubuntu 24 and newer → AstroNvim v6 (nvim)
if [ "$UBUNTU_VER" -le 22 ] && [ "$UBUNTU_VER" -gt 0 ]; then
  echo "Detected Ubuntu $UBUNTU_VER — using AstroNvim v5 (nvim-legacy)"
  stow -t "$HOME" nvim-legacy
else
  echo "Detected Ubuntu $UBUNTU_VER (or non-Ubuntu) — using AstroNvim v6 (nvim)"
  stow -t "$HOME" nvim
fi

# Install opencode if not installed
if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode not found — installing..."
  curl -fsSL https://opencode.ai/install | bash
fi

# Install opencode config
stow -t "$HOME" opencode

# Configure providers
read -rp "Would you like to run 'opencode providers login' to add a provider? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
  opencode providers login
fi
