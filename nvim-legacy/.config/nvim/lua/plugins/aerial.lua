-- Legacy (AstroNvim v5 / Neovim 0.10.4 / nvim-treesitter master) compatibility
-- override.
--
-- aerial v2.7's treesitter backend computes symbol end-ranges that can run one
-- line past EOF on markdown buffers (with the frozen nvim-treesitter-master
-- markdown parser), raising
--   "aerial/backends/treesitter/extensions.lua:61: Invalid 'text': Expected Lua string"
-- every time a markdown file is opened. Aerial's own pure-Lua markdown backend
-- handles markdown fine, so use it for markdown buffers. The default backends
-- still apply to every other filetype.
---@type LazySpec
return {
  "stevearc/aerial.nvim",
  ---@type aerial.Config
  opts = {
    backends = {
      markdown = { "markdown" },
    },
  },
}