-- Customize Treesitter
-- --------------------
-- Treesitter customization is handled by AstroCore; nvim-treesitter (main
-- branch) only provides the parser download/build utility.

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      -- Do not let AstroCore install tree-sitter-cli from Mason: its prebuilt
      -- arm64 binary hard-requires glibc 2.39 and fails on Ubuntu 22.04. The
      -- dotfiles installer builds a compatible CLI with cargo into ~/.cargo/bin.
      auto_install_cli = false,
    },
  },
}
