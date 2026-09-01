return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- Pin nvim-treesitter to the master branch explicitly. The repo's default
  -- branch is now "main", which removed the nvim-treesitter.configs module
  -- that AstroNvim v5 relies on (main = "nvim-treesitter.configs"). Without
  -- this pin, lazy.nvim clones from "main" and the config module is missing.
  --
  -- NOTE: this master pin REQUIRES astrocore v2 in lazy-lock.json. astrocore
  -- v3+ dropped support for the nvim-treesitter master layout (its
  -- treesitter.lua calls `require("nvim-treesitter").get_installed`, which
  -- only exists in the main-branch rewrite) and threw
  --   "treesitter.lua:64: attempt to call field 'get_installed' (a nil value)"
  -- on every file open. The AstroNvim v5 snapshot pins astrocore ^2, but the
  -- lockfile had drifted to astrocore v3.1.0; keep astrocore at v2.1.2
  -- (50521898) here or the error returns.
  dependencies = { { "nvim-treesitter/nvim-treesitter", branch = "master" }, "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {},
}
