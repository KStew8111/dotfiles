return {
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    -- AstroNvim's astrocore runs at priority 10000; loading after it means
    -- nightfox (and the rig palette) wins over the default astrotheme.
    priority = 1000,
    config = function()
      local nightfox = require "nightfox"

      -- Prefer the palette rig-theme-apply wrote for the active theme. Fall
      -- back to the committed snapshot so Neovim is still themed where the
      -- host state dir is absent (devcontainers, CI, dotfiles-only installs).
      local function read_palette(path)
        if vim.fn.filereadable(path) == 0 then return nil end
        local ok, parsed = pcall(dofile, path)
        if ok and type(parsed) == "table" and type(parsed.palette) == "table" then return parsed end
      end

      local theme = read_palette(vim.fn.expand "~/.local/state/rig/theme/nvim.lua")
      if not theme then
        local ok, bundled = pcall(require, "rig_theme_default")
        if ok and type(bundled) == "table" and type(bundled.palette) == "table" then theme = bundled end
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
