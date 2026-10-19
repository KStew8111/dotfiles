-- Fallback rig palette, committed so Neovim still looks right where the host
-- state dir is absent: devcontainers, CI, or a fresh machine with dotfiles but
-- no rig install. It is a snapshot of themes/papaya/colors.toml; the live
-- palette in ~/.local/state/rig/theme/nvim.lua takes precedence when present.
-- Refresh this file if the papaya palette changes.
return {
  theme = "papaya",
  palette = {
    black   = { base = "#0e0b09", bright = "#6f6255", dim = "#080605" },
    red     = { base = "#ff5f56", bright = "#ff7b73", dim = "#a0443c" },
    green   = { base = "#8fd460", bright = "#a8e37f", dim = "#628441" },
    yellow  = { base = "#ffc24d", bright = "#ffd27a", dim = "#a07a37" },
    blue    = { base = "#5aa2ff", bright = "#82b8ff", dim = "#456999" },
    magenta = { base = "#ff8000", bright = "#ffa64d", dim = "#954d05" },
    cyan    = { base = "#4fd1c5", bright = "#74e0d6", dim = "#3f8279" },
    white   = { base = "#e9e1d7", bright = "#faf6f0", dim = "#8b7f72" },
    orange  = { base = "#ff8a1f", bright = "#fda14c", dim = "#955316" },
    pink    = { base = "#d98cff", bright = "#e6a8ff", dim = "#805492" },

    comment = "#6f6255",
    bg0 = "#080605",
    bg1 = "#14100d",
    bg2 = "#201a15",
    bg3 = "#201a15",
    bg4 = "#3a2a1c",
    fg0 = "#faf6f0",
    fg1 = "#e9e1d7",
    fg2 = "#8b7f72",
    fg3 = "#6f6255",
    sel0 = "#3a2a1c",
    sel1 = "#201a15",
  },
}
