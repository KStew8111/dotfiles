#!/bin/bash

set -e

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
ALL=false
INSTALL_NVIM=false
INSTALL_OPENCODE=false
INSTALL_ZSH=false
INSTALL_GHOSTTY=false
INSTALL_ZELLIJ=false
SET_SHELL=false
LOGIN_PROVIDERS=false

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Install dotfiles components. If no component flags are given, all components
are installed.

Options:
  -a, --all          Install all components
  -n, --nvim         Install Neovim and stow the AstroNvim configuration
  -o, --opencode     Install opencode and stow its configuration
  -z, --zsh          Install zsh, oh-my-zsh, and stow the zsh configuration
  -g, --ghostty      Install ghostty and stow its configuration (x86_64 only)
  -j, --zellij       Install zellij and stow its configuration
      --chsh         Change the default login shell to zsh
  -p, --providers    Run 'opencode providers login' (interactive)
  -h, --help         Show this help message

Examples:
  install.sh                        # Install all components, non-interactively
  install.sh --zsh --chsh           # Install zsh and make it the default shell
  install.sh --nvim --zellij        # Install only nvim and zellij
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--all)
      ALL=true
      shift
      ;;
    -n|--nvim)
      INSTALL_NVIM=true
      shift
      ;;
    -o|--opencode)
      INSTALL_OPENCODE=true
      shift
      ;;
    -z|--zsh)
      INSTALL_ZSH=true
      shift
      ;;
    -g|--ghostty)
      INSTALL_GHOSTTY=true
      shift
      ;;
    -j|--zellij)
      INSTALL_ZELLIJ=true
      shift
      ;;
    --chsh)
      SET_SHELL=true
      shift
      ;;
    -p|--providers)
      LOGIN_PROVIDERS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Default to --all when no component flags are provided.
if ! $ALL && ! $INSTALL_NVIM && ! $INSTALL_OPENCODE && ! $INSTALL_ZSH && ! $INSTALL_GHOSTTY && ! $INSTALL_ZELLIJ; then
  ALL=true
fi

if $ALL; then
  INSTALL_NVIM=true
  INSTALL_OPENCODE=true
  INSTALL_ZSH=true
  INSTALL_GHOSTTY=true
  INSTALL_ZELLIJ=true
fi

cd "$HOME/dotfiles"

# ---------------------------------------------------------------------------
# Detect architecture
# ---------------------------------------------------------------------------
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  TARGET_ARCH="x86_64" ;;
  aarch64) TARGET_ARCH="aarch64" ;;
  arm64)   TARGET_ARCH="aarch64" ;;
  *)       echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Detect Ubuntu major version (falls back to 0 on non-Ubuntu systems)
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Installers
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Neovim / AstroNvim
# ---------------------------------------------------------------------------
if $INSTALL_NVIM; then
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
fi

# ---------------------------------------------------------------------------
# zsh / oh-my-zsh
# ---------------------------------------------------------------------------
if $INSTALL_ZSH; then
  if ! command -v zsh >/dev/null 2>&1; then
    echo "Installing zsh..."
    sudo apt-get update && sudo apt-get install -y zsh
  fi

  # Stow zsh config BEFORE oh-my-zsh so .zshrc is managed by dotfiles
  stow -t "$HOME" zsh

  if $SET_SHELL; then
    echo "Changing default shell to zsh..."
    ZSH_PATH=$(which zsh)
    # Prefer sudo when available without a password (common in devcontainers),
    # because plain `chsh` prompts for the current user's password and can hang
    # in non-interactive environments.
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo chsh -s "$ZSH_PATH" "$USER"
    else
      chsh -s "$ZSH_PATH"
    fi
  fi

  # Install oh-my-zsh if not installed, preserving the dotfiles-managed .zshrc
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  else
    echo "oh-my-zsh already installed — skipping"
  fi
fi

# ---------------------------------------------------------------------------
# ghostty (x86_64 only)
# ---------------------------------------------------------------------------
if $INSTALL_GHOSTTY; then
  if [ "$TARGET_ARCH" = "x86_64" ]; then
    if ! command -v ghostty >/dev/null 2>&1; then
      echo "Installing ghostty..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
    fi
    stow -t "$HOME" ghostty
  else
    echo "Skipping ghostty install — not supported on $TARGET_ARCH"
  fi
fi

# ---------------------------------------------------------------------------
# zellij
# ---------------------------------------------------------------------------
if $INSTALL_ZELLIJ; then
  if ! command -v zellij >/dev/null 2>&1; then
    echo "Installing zellij 0.43.1..."
    ZELLIJ_VER="0.43.1"
    curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VER}/zellij-${TARGET_ARCH}-unknown-linux-musl.tar.gz" -o /tmp/zellij.tar.gz
    sudo tar -xzf /tmp/zellij.tar.gz -C /usr/local/bin zellij
    rm /tmp/zellij.tar.gz
  fi
  stow -t "$HOME" zellij
fi

# ---------------------------------------------------------------------------
# Providers (interactive)
# ---------------------------------------------------------------------------
if $LOGIN_PROVIDERS; then
  opencode providers login
fi
