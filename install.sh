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

# Install and stow zsh
if ! command -v zsh >/dev/null 2>&1; then
  echo "Installing zsh..."
  sudo apt-get update && sudo apt-get install -y zsh
fi

# Install oh-my-zsh if not installed
if ! grep -q "oh-my-zsh" "$HOME/.zshrc" 2>/dev/null; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

stow -t "$HOME" zsh
chsh -s "$(which zsh)"

# Install and stow ghostty
if ! command -v ghostty >/dev/null 2>&1; then
  echo "Installing ghostty..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
fi
stow -t "$HOME" ghostty

# Install and stow zellij (0.43.1)
if ! command -v zellij >/dev/null 2>&1; then
  echo "Installing zellij 0.43.1..."
  ZELLIJ_VER="0.43.1"
  curl -fsSL "https://github.com/zellij-org/zellij/releases/download/${ZELLIJ_VER}/zellij-${ZELLIJ_VER}-x86_64-linux.tar.gz" -o /tmp/zellij.tar.gz
  sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin zellij
  rm /tmp/zellij.tar.gz
fi
stow -t "$HOME" zellij

# Configure providers
read -rp "Would you like to run 'opencode providers login' to add a provider? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
  opencode providers login
fi
