return {
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    -- AstroNvim's astrocore runs at priority 10000; loading after it means
    -- nightfox (and the rig palette) wins over the default astrotheme.
    priority = 1000,
    config = function()
      local nightfox = require "nightfox"

      -- rig-theme-apply writes the active palette here so `rig-theme-apply
      -- <theme>` reaches Neovim as well. Without the file (a fresh checkout
      -- before install) keep AstroNvim's default theme.
      local theme_file = vim.fn.expand "~/.local/state/rig/theme/nvim.lua"
      local theme
      if vim.fn.filereadable(theme_file) == 1 then
        local ok, parsed = pcall(dofile, theme_file)
        if ok and type(parsed) == "table" and type(parsed.palette) == "table" then theme = parsed end
      end

      nightfox.setup {
        options = {
          transparent = true,
          styles = {
            comments = "italic",
            conditionals = "italic",
            keywords = "italic,bold",
            types = "italic,bold",
            operators = "bold",
            variables = "bold",
          },
        },
        palettes = theme and { nightfox = theme.palette } or nil,
      }

      if theme then vim.cmd.colorscheme "nightfox" end
    end,
  },
}
