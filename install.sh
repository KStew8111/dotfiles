#!/bin/bash

set -e

cd "$HOME/dotfiles"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  TARGET_ARCH="x86_64" ;;
  aarch64) TARGET_ARCH="aarch64" ;;
  arm64)   TARGET_ARCH="aarch64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Detect Ubuntu major version (falls back to 0 on non-Ubuntu systems)
UBUNTU_VER=0
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" = "ubuntu" ]; then
    UBUNTU_VER=$(echo "$VERSION_ID" | cut -d. -f1)
  fi
fi

# Ubuntu 22 and older → AstroNvim v5 + Neovim 0.10.4
# Ubuntu 24 and newer → AstroNvim v6 + Neovim 0.12.4
if [ "$UBUNTU_VER" -le 22 ] && [ "$UBUNTU_VER" -gt 0 ]; then
  NVIM_VER="0.10.4"
  echo "Detected Ubuntu $UBUNTU_VER — using AstroNvim v5 (nvim-legacy)"
else
  NVIM_VER="0.12.4"
  echo "Detected Ubuntu $UBUNTU_VER (or non-Ubuntu) — using AstroNvim v6 (nvim)"
fi
# Map architecture to Neovim release tarball naming
case "$TARGET_ARCH" in
  aarch64) NVIM_TARBALL="nvim-linux-arm64" ;;
  x86_64)  NVIM_TARBALL="nvim-linux-x86_64" ;;
esac

# Install Neovim pinned to the Ubuntu-compatible version
install_neovim() {
  echo "Installing Neovim ${NVIM_VER}..."
  curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VER}/${NVIM_TARBALL}.tar.gz" -o /tmp/nvim.tar.gz
  sudo mkdir -p /opt
  sudo rm -rf "/opt/nvim-${NVIM_VER}" "/opt/${NVIM_TARBALL}"
  sudo tar -xzf /tmp/nvim.tar.gz -C /opt
  sudo mv "/opt/${NVIM_TARBALL}" "/opt/nvim-${NVIM_VER}"
  sudo ln -sfn "/opt/nvim-${NVIM_VER}/bin/nvim" /usr/local/bin/nvim
  rm -f /tmp/nvim.tar.gz
}

if ! command -v nvim >/dev/null 2>&1; then
  install_neovim
else
  INSTALLED_VER=$(nvim --version | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
  if [ "$INSTALLED_VER" != "$NVIM_VER" ]; then
    echo "Detected nvim ${INSTALLED_VER}, replacing with ${NVIM_VER}..."
    install_neovim
  else
    echo "Neovim ${NVIM_VER} already installed"
  fi
fi

# Stow the matching AstroNvim configuration
if [ "$UBUNTU_VER" -le 22 ] && [ "$UBUNTU_VER" -gt 0 ]; then
  stow -t "$HOME" nvim-legacy
else
  stow -t "$HOME" nvim
fi

# Install opencode if not installed
if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode not found — installing..."
  curl -fsSL https://opencode.ai/install | bash
fi

# Install opencode config
stow -t "$HOME" opencode

# Install zsh
if ! command -v zsh >/dev/null 2>&1; then
  echo "Installing zsh..."
  sudo apt-get update && sudo apt-get install -y zsh
fi

# Stow zsh config BEFORE oh-my-zsh so .zshrc is managed by dotfiles
stow -t "$HOME" zsh
chsh -s "$(which zsh)"

# Install oh-my-zsh if not installed, preserving the dotfiles-managed .zshrc
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "Installing oh-my-zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
  echo "oh-my-zsh already installed — skipping"
fi

# Install and stow ghostty (x86_64 only — not available/packaged for aarch64 on Ubuntu)
if [ "$TARGET_ARCH" = "x86_64" ]; then
  if ! command -v ghostty >/dev/null 2>&1; then
    echo "Installing ghostty..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
  fi
  stow -t "$HOME" ghostty
else
  echo "Skipping ghostty install — not supported on $TARGET_ARCH"
fi

# Install and stow zellij (0.43.1)
if ! command -v zellij >/dev/null 2>&1; then
  echo "Installing zellij 0.43.1..."
  ZELLIJ_VER="0.43.1"
  curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VER}/zellij-${TARGET_ARCH}-unknown-linux-musl.tar.gz" -o /tmp/zellij.tar.gz
  sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin zellij
  rm /tmp/zellij.tar.gz
fi
stow -t "$HOME" zellij

# Configure providers
read -rp "Would you like to run 'opencode providers login' to add a provider? [y/N] " response
if [[ "$response" =~ ^[Yy]$ ]]; then
  opencode providers login
fi
