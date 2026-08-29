return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- Pin nvim-treesitter to the master branch explicitly. The repo's default
  -- branch is now "main", which removed the nvim-treesitter.configs module
  -- that AstroNvim v5 relies on (main = "nvim-treesitter.configs"). Without
  -- this pin, lazy.nvim clones from "main" and the config module is missing.
  dependencies = { { "nvim-treesitter/nvim-treesitter", branch = "master" }, "nvim-mini/mini.nvim" }, -- if you use the mini.nvim suite
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.icons' },        -- if you use standalone mini plugins
  -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {},
}
