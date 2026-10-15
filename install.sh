#!/bin/bash

set -e

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
ALL=false
INSTALL_NVIM=false
INSTALL_PI=false
INSTALL_COPILOT=false
INSTALL_BEADS=false
INSTALL_ZSH=false
INSTALL_GHOSTTY=false
INSTALL_ZELLIJ=false
INSTALL_HERDR=false
INSTALL_HERMES=false
INSTALL_LAZYGIT=false
INSTALL_GH=false
GH_SKIP_AUTH=false
GH_TOKEN_ARG=""
SET_SHELL=false

usage() {
  cat <<'EOF'
Usage: install.sh [OPTIONS]

Install dotfiles components. If no component flags are given, all components
are installed.

Options:
  -a, --all          Install all components
  -n, --nvim         Install Neovim and stow the AstroNvim configuration
  -i, --pi           Install pi coding agent (npm global) and stow its configuration
  -c, --copilot      Install GitHub Copilot CLI (npm global) and stow skills
  -b, --beads        Install beads issue tracker CLI (npm global)
  -z, --zsh          Install zsh, oh-my-zsh, and stow the zsh configuration
  -g, --ghostty      Install ghostty and stow its configuration (x86_64 only)
  -j, --zellij       Install zellij and stow its configuration
  -H, --herdr        Install herdr (agent-aware terminal multiplexer) and stow its
                     configuration, then install the herdr Pi integration
  -e, --hermes       Install Hermes Agent (Nous Research) via its official installer,
                     which publishes the ~/.local/bin/hermes launchers
  -l, --lazygit      Install lazygit
  -G, --gh           Install GitHub CLI and authenticate (login skipped when headless)
      --gh-token T   Authenticate gh with token T instead of interactive login
      --no-auth      With --gh, install gh without authenticating
      --chsh         Change the default login shell to zsh
  -h, --help         Show this help message

Examples:
  install.sh                        # Install all components, non-interactively
  install.sh --zsh --chsh           # Install zsh and make it the default shell
  install.sh --nvim --zellij        # Install only nvim and zellij
  install.sh --gh --no-auth         # Install gh, leave authentication to you
  install.sh --gh --gh-token "$TOK" # Install and authenticate gh non-interactively
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
    -i|--pi)
      INSTALL_PI=true
      shift
      ;;
    -c|--copilot)
      INSTALL_COPILOT=true
      shift
      ;;
    -b|--beads)
      INSTALL_BEADS=true
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
    -H|--herdr)
      INSTALL_HERDR=true
      shift
      ;;
    -e|--hermes)
      INSTALL_HERMES=true
      shift
      ;;
    -l|--lazygit)
      INSTALL_LAZYGIT=true
      shift
      ;;
    -G|--gh)
      INSTALL_GH=true
      shift
      ;;
    --gh-token)
      if [[ -z ${2:-} || ${2} == -* ]]; then
        echo "Missing value for --gh-token" >&2
        exit 1
      fi
      GH_TOKEN_ARG="$2"
      INSTALL_GH=true
      shift 2
      ;;
    --no-auth)
      GH_SKIP_AUTH=true
      shift
      ;;
    --chsh)
      SET_SHELL=true
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
if ! $ALL && ! $INSTALL_NVIM && ! $INSTALL_PI && ! $INSTALL_COPILOT && ! $INSTALL_BEADS && ! $INSTALL_ZSH && ! $INSTALL_GHOSTTY && ! $INSTALL_ZELLIJ && ! $INSTALL_HERDR && ! $INSTALL_HERMES && ! $INSTALL_LAZYGIT && ! $INSTALL_GH; then
  ALL=true
fi

if $ALL; then
  INSTALL_NVIM=true
  INSTALL_PI=true
  INSTALL_COPILOT=true
  INSTALL_BEADS=true
  INSTALL_ZSH=true
  INSTALL_GHOSTTY=true
  INSTALL_ZELLIJ=true
  INSTALL_HERDR=true
  INSTALL_HERMES=true
  INSTALL_LAZYGIT=true
  INSTALL_GH=true
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
# Neovim version
# ---------------------------------------------------------------------------
# Neovim 0.12.5's supported Linux builds require glibc 2.34, which Ubuntu
# 22.04+ (glibc 2.35) ships on both x86_64 and arm64. Install that one version
# from the main repo and stow the single AstroNvim v6 config everywhere.
NVIM_VER="0.12.5"

# Map architecture to Neovim release tarball naming
case "$TARGET_ARCH" in
  aarch64) NVIM_TARBALL="nvim-linux-arm64" ;;
  x86_64)  NVIM_TARBALL="nvim-linux-x86_64" ;;
esac

# ---------------------------------------------------------------------------
# npm helper
# ---------------------------------------------------------------------------
# pi (and the other npm-based CLIs below) need a modern Node. Ubuntu 26.04
# ships Node 22, but Ubuntu 22.04 (e.g. NVIDIA Jetson Orin L4T) still ships
# Node 12, which cannot run pi >= 1.2 (needs >= 22.19.0: its CLI imports
# enableCompileCache from node:module). When the system Node is missing or too
# old, install a known-good one from the official nodejs.org tarball — the same
# release-tarball approach used for nvim, gh, lazygit and zellij — rather than
# the distro package, which on those releases is far too old.
NODE_VER="22.23.3"
NODE_MIN_MAJOR=22
NODE_MIN_MINOR=19

case "$TARGET_ARCH" in
  aarch64) NODE_ARCH="arm64" ;;
  x86_64)  NODE_ARCH="x64" ;;
esac

# True when the Node on PATH is at least $NODE_MIN_MAJOR.$NODE_MIN_MINOR.
node_is_current() {
  command -v node >/dev/null 2>&1 || return 1

  local v major minor
  v=$(node --version 2>/dev/null) || return 1
  v=${v#v}
  major=${v%%.*}
  minor=${v#*.}
  minor=${minor%%.*}
  [[ $major =~ ^[0-9]+$ && $minor =~ ^[0-9]+$ ]] || return 1
  (( major > NODE_MIN_MAJOR || (major == NODE_MIN_MAJOR && minor >= NODE_MIN_MINOR) ))
}

install_node() {
  echo "Installing Node.js ${NODE_VER}..."

  local tarball="node-v${NODE_VER}-linux-${NODE_ARCH}"
  curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 15 --max-time 300 \
    "https://nodejs.org/dist/v${NODE_VER}/${tarball}.tar.xz" -o /tmp/node.tar.xz
  sudo mkdir -p /opt
  sudo rm -rf "/opt/${tarball}" "/opt/node-${NODE_VER}"
  sudo tar -xJf /tmp/node.tar.xz -C /opt
  sudo mv "/opt/${tarball}" "/opt/node-${NODE_VER}"
  # Symlink into /usr/local/bin so node/npm/npx win over any distro binaries
  # (e.g. Ubuntu 22.04's Node 12 from apt) that may still be on PATH.
  sudo ln -sfn "/opt/node-${NODE_VER}/bin/node" /usr/local/bin/node
  sudo ln -sfn "/opt/node-${NODE_VER}/bin/npm" /usr/local/bin/npm
  sudo ln -sfn "/opt/node-${NODE_VER}/bin/npx" /usr/local/bin/npx
  rm -f /tmp/node.tar.xz
}

ensure_npm() {
  # Make a modern node + npm available, installing one if the system's is
  # missing or too old.
  if ! node_is_current; then
    install_node
  fi

  # Prefer the Node we may have just installed under /usr/local/bin.
  case ":$PATH:" in
    *:/usr/local/bin:*) ;;
    *) PATH="/usr/local/bin:$PATH"; export PATH ;;
  esac

  if ! command -v npm >/dev/null 2>&1; then
    echo "⚠  npm not found after Node install attempt — skipping npm-based tools."
    return 1
  fi
}

ensure_npm_prefix() {
  # Use a user-writable global prefix so `npm install -g` doesn't need sudo.
  if ! grep -q 'prefix=' "$HOME/.npmrc" 2>/dev/null; then
    echo "prefix=$HOME/.npm-global" >> "$HOME/.npmrc"
  fi
  mkdir -p "$HOME/.npm-global/bin"
}

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

# nvim-treesitter (main branch) builds parsers with the `tree-sitter` CLI.
# Mason ships a prebuilt CLI whose arm64 build hard-requires glibc 2.39, so it
# fails to load on Ubuntu 22.04 (glibc 2.35). Build the CLI from source with
# cargo instead, linking it against the host glibc; rig installs Rust and
# ~/.cargo/bin is on the session PATH.
TREE_SITTER_CLI_VER="0.27.1"

ensure_tree_sitter_cli() {
  # Non-interactive shells don't source ~/.cargo/env, so cargo wouldn't be found.
  if [ -f "$HOME/.cargo/env" ]; then
    . "$HOME/.cargo/env"
  fi

  # A previous run (or a compatible distro build) already provides a CLI.
  if command -v tree-sitter >/dev/null 2>&1 && tree-sitter --version >/dev/null 2>&1; then
    echo "tree-sitter CLI already available ($(tree-sitter --version | head -n1))"
    return
  fi

  # Drop Mason's prebuilt CLI if it is present but unusable, so it can't shadow
  # the compatible one built below.
  rm -f "$HOME/.local/share/nvim/mason/bin/tree-sitter"
  rm -rf "$HOME/.local/share/nvim/mason/packages/tree-sitter-cli"

  if ! command -v cargo >/dev/null 2>&1; then
    echo "⚠  cargo not found — cannot build tree-sitter CLI; nvim-treesitter parser installs will fail." >&2
    return
  fi

  echo "Building tree-sitter CLI ${TREE_SITTER_CLI_VER} with cargo (may take a few minutes)..."
  cargo install tree-sitter-cli --version "$TREE_SITTER_CLI_VER" --locked \
    || echo "⚠  Failed to build tree-sitter CLI — nvim-treesitter parser installs may fail." >&2
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

  # Migrate from the old per-release split: a previous install on older Ubuntu
  # may have stowed the AstroNvim v5 config, so drop those symlinks first or
  # stow will refuse the conflicting paths.
  stow -D -t "$HOME" nvim-legacy 2>/dev/null || true

  # Stow the shared AstroNvim v6 configuration on every supported system.
  stow -t "$HOME" nvim

  # Provide a glibc-compatible tree-sitter CLI for nvim-treesitter.
  ensure_tree_sitter_cli
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
    CURRENT_USER=$(id -un 2>/dev/null || whoami 2>/dev/null || echo "$USER")

    if [ -z "$CURRENT_USER" ]; then
      echo "Warning: could not determine current user; skipping chsh." >&2
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo chsh -s "$ZSH_PATH" "$CURRENT_USER"
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
# herdr (agent-aware terminal multiplexer)
# ---------------------------------------------------------------------------
# herdr persists terminals AND knows which pane holds an agent and whether that
# agent is idle/working/blocked, so several Pi sessions can run at once and you
# can see which one needs you. Its server owns the panes, so agents survive
# closing the window and (with the Pi integration) resume their sessions after a
# server restart. ~/.config/herdr/ also holds runtime state (sockets,
# session.json, logs); stow only ever adds the config.toml symlink there, so
# never `stow --adopt` or restow after a wipe.
if $INSTALL_HERDR; then
  HERDR_VER="0.9.3"
  # Release binaries ship per-arch under these exact asset names. Checksums are
  # pinned here so a compromised download cannot run: herdr's own install.sh
  # verifies a checksum too, but it always grabs the LATEST release, whereas
  # everything else in this script is version-pinned for reproducibility.
  case "$TARGET_ARCH" in
    aarch64) HERDR_SHA="4de7aa3e25678812e92960de64f7c2aaa1bca1f0f80a3c5e559837e231e1f5c0" ;;
    x86_64)  HERDR_SHA="18a8dc65f1c2fa485884344356dea1cfd911c6f06cf46fa78e193f4087f4dba7" ;;
  esac

  PATH="$HOME/.local/bin:$PATH"
  INSTALLED_HERDR_VER=""
  if command -v herdr >/dev/null 2>&1; then
    INSTALLED_HERDR_VER=$(herdr --version 2>/dev/null | awk '{print $2}')
  fi

  if [ "$INSTALLED_HERDR_VER" != "$HERDR_VER" ]; then
    echo "Installing herdr ${HERDR_VER}..."
    curl -fsSL "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VER}/herdr-linux-${TARGET_ARCH}" -o /tmp/herdr
    ACTUAL_HERDR_SHA=$(sha256sum < /tmp/herdr | awk '{ print $1 }')
    if [ "$ACTUAL_HERDR_SHA" != "$HERDR_SHA" ]; then
      echo "✗ herdr checksum mismatch (expected ${HERDR_SHA}, got ${ACTUAL_HERDR_SHA})" >&2
      rm -f /tmp/herdr
      exit 1
    fi
    install -D -m 0755 /tmp/herdr "$HOME/.local/bin/herdr"
    rm -f /tmp/herdr
  else
    echo "herdr ${HERDR_VER} already installed — skipping"
  fi

  stow -t "$HOME" herdr

  # The Pi integration drops herdr-agent-state.ts into Pi's extensions dir so
  # herdr gets authoritative idle/working/blocked state and can restore the Pi
  # conversation after a server restart. herdr regenerates that file, so it is
  # gitignored rather than committed.
  if command -v pi >/dev/null 2>&1; then
    echo "Installing herdr Pi integration..."
    herdr integration install pi
  else
    echo "⚠  Skipping herdr Pi integration — pi not on PATH (run install.sh --pi first)."
  fi
fi

# ---------------------------------------------------------------------------
# Hermes Agent (Nous Research)
# ---------------------------------------------------------------------------
# Hermes ships its own installer: it clones into ~/.hermes/hermes-agent,
# acquires its Python/Node runtimes, publishes the ~/.local/bin/{hermes,
# hermes-agent,hermes-acp} launchers, and adds ~/.local/bin to the shell rc.
# Run it non-interactively so it cannot block on the API-key setup prompts;
# `hermes setup` finishes configuration afterwards.
#
# Agent only: the Desktop app is a heavy Electron build (the installer's
# --include-desktop). rig's bin/rig-hermes-desktop starts it once it exists.
if $INSTALL_HERMES; then
  if [[ -x "$HOME/.local/bin/hermes" ]] || command -v hermes >/dev/null 2>&1; then
    echo "Hermes Agent already installed — skipping (update with 'hermes update')"
  else
    echo "Installing Hermes Agent..."
    # Downloaded first so a failed fetch (which would pipe an empty script into
    # bash and look like success) is caught, and so this stays free of a
    # mid-script `set -o pipefail`.
    if curl -fsSL --retry 3 --retry-delay 5 \
      https://hermes-agent.nousresearch.com/install.sh -o /tmp/hermes-install.sh \
      && bash /tmp/hermes-install.sh --non-interactive; then
      echo "Hermes Agent installed — run 'hermes setup' to configure it."
    else
      echo "⚠  Hermes Agent install failed — continuing." >&2
    fi
    rm -f /tmp/hermes-install.sh
  fi
fi

# ---------------------------------------------------------------------------
# lazygit
# ---------------------------------------------------------------------------
if $INSTALL_LAZYGIT; then
  if ! command -v lazygit >/dev/null 2>&1; then
    LAZYGIT_VER="0.64.1"
    case "$TARGET_ARCH" in
      aarch64) LAZYGIT_ARCH="arm64" ;;
      x86_64)  LAZYGIT_ARCH="x86_64" ;;
    esac
    echo "Installing lazygit ${LAZYGIT_VER}..."
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VER}/lazygit_${LAZYGIT_VER}_Linux_${LAZYGIT_ARCH}.tar.gz" -o /tmp/lazygit.tar.gz
    sudo tar -xzf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
    rm -f /tmp/lazygit.tar.gz
  else
    echo "lazygit already installed — skipping"
  fi
fi

# ---------------------------------------------------------------------------
# GitHub CLI
# ---------------------------------------------------------------------------
authenticate_gh() {
  # Already logged in? Nothing to do.
  if gh auth status >/dev/null 2>&1; then
    echo "gh already authenticated — skipping login"
    return 0
  fi

  # Precedence: explicit --gh-token, then gh's own env var, then the
  # conventional one. Record where the token came from so the log is honest.
  local token="${GH_TOKEN_ARG:-}"
  local source="--gh-token"
  if [[ -z $token && -n ${GH_TOKEN:-} ]]; then
    token="$GH_TOKEN"
    source="GH_TOKEN"
  fi
  if [[ -z $token && -n ${GITHUB_TOKEN:-} ]]; then
    token="$GITHUB_TOKEN"
    source="GITHUB_TOKEN"
  fi

  if [[ -n $token ]]; then
    echo "Authenticating gh with token from ${source}..."
    # --with-token reads the token from stdin; it is never echoed or logged.
    if printf '%s\n' "$token" | gh auth login --with-token; then
      gh auth setup-git
    else
      echo "⚠  gh token login failed — run 'gh auth login' manually." >&2
    fi
    return 0
  fi

  # No token supplied. Interactive login needs a TTY for the one-time code and
  # a desktop session for the browser hop — in a headless or piped install
  # there is nothing to talk to, so print instructions instead of hanging.
  if [[ -t 0 && -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    echo "Starting interactive gh login..."
    gh auth login --hostname github.com --git-protocol https --web \
      || echo "⚠  gh login did not complete — run 'gh auth login' manually." >&2
    return 0
  fi

  cat <<'EOF'
⚠  Skipping gh login: no token supplied and no desktop session detected.
   Authenticate later with either of:
     gh auth login
     export GH_TOKEN=<your-pat> && install.sh --gh
   Create a token at https://github.com/settings/tokens ('repo' scope).
EOF
}

if $INSTALL_GH; then
  if ! command -v gh >/dev/null 2>&1; then
    GH_VER="2.102.0"
    # gh's release archives use amd64/arm64, unlike the x86_64/aarch64 that
    # lazygit and zellij use, so map separately.
    case "$TARGET_ARCH" in
      aarch64) GH_ARCH="arm64" ;;
      x86_64)  GH_ARCH="amd64" ;;
    esac
    echo "Installing GitHub CLI ${GH_VER}..."
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_${GH_ARCH}.tar.gz" -o /tmp/gh.tar.gz
    rm -rf /tmp/gh-extract
    mkdir -p /tmp/gh-extract
    tar -xzf /tmp/gh.tar.gz -C /tmp/gh-extract
    # The archive nests the binary at <dir>/bin/gh, so extract then install it.
    sudo install -m 0755 "/tmp/gh-extract/gh_${GH_VER}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh
    rm -rf /tmp/gh.tar.gz /tmp/gh-extract
  else
    echo "gh already installed — skipping"
  fi

  # gh lands in /usr/local/bin. If the caller's PATH omits it (minimal
  # containers, some non-login shells) the login below would fail with
  # "gh: command not found" right after a successful install, so add it.
  case ":$PATH:" in
    *:/usr/local/bin:*) ;;
    *) PATH="/usr/local/bin:$PATH" ;;
  esac

  if $GH_SKIP_AUTH; then
    echo "Skipping gh authentication (--no-auth)"
  else
    authenticate_gh
  fi
fi

# ---------------------------------------------------------------------------
# pi coding agent
# ---------------------------------------------------------------------------
if $INSTALL_PI; then
  if ensure_npm; then
    ensure_npm_prefix
    echo "Installing pi coding agent..."
    npm install -g @earendil-works/pi-coding-agent
    stow -t "$HOME" pi
  fi
  # Stow pi config (settings, AGENTS.md, prompt templates) before first run so
  # pi's session state lands alongside stowed files, not on top of them.
  stow -t "$HOME" pi
  echo "Installing pi extensions..."
  pi install npm:@zjie-wang/pi-todo
  pi install npm:@zjie-wang/pi-ask-user
  pi install npm:pi-subagents
  pi install npm:@georgedong32/pi-review
fi

# ---------------------------------------------------------------------------
# GitHub Copilot CLI
# ---------------------------------------------------------------------------
if $INSTALL_COPILOT; then
  if ensure_npm; then
    ensure_npm_prefix
    echo "Installing GitHub Copilot CLI..."
    npm install -g @github/copilot
    stow -t "$HOME" copilot
  fi
fi

# ---------------------------------------------------------------------------
# beads issue tracker CLI
# ---------------------------------------------------------------------------
# Task management tool for coding agents. The npm package (@beads/bd) wraps
# the native `bd` binary, which its postinstall script downloads from GitHub
# releases. Config lives per-repo in .beads/, so there is nothing to stow.
if $INSTALL_BEADS; then
  if ensure_npm; then
    ensure_npm_prefix
    echo "Installing beads CLI..."
    npm install -g @beads/bd
  fi
fi
