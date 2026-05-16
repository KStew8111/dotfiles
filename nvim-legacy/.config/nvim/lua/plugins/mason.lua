-- Customize Mason

---@type LazySpec
return {
  -- use mason-tool-installer for automatically installing Mason packages
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    -- overrides `require("mason-tool-installer").setup(...)`
    opts = {
      -- Make sure to use the names found in `:Mason`
      ensure_installed = {
        -- install language servers
        "lua-language-server",
        "pyright",
        "clangd",
        "markdown-oxide",
        "rust-analyzer",

        -- install formatters
        "stylua",
        "clang-format",
        "autopep8",
        "biome",

        -- install debuggers
        "debugpy",
        "cpptools",

        -- install any other package
        "tree-sitter-cli",
        "cpplint",
      },
    },
  },
}
