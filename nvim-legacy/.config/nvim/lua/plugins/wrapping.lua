return {
  "andrewferrier/wrapping.nvim",
  -- Pin to v2.1.3: the latest master requires Neovim 0.11+ (commit 6045aff7,
  -- 2026-04-02). v2.1.3 (2026-02-08) is the last release compatible with
  -- Neovim 0.10.4 used by the legacy/AstroNim v5 config on Ubuntu 22.04.
  commit = "338ec89a",  -- tag v2.1.3
  config = function() require("wrapping").setup() end,
}
