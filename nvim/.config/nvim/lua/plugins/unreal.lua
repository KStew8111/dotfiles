return {
  {
    "taku25/UnrealDev.nvim",
    -- Define all plugins in the development suite.
    -- You can remove any plugins you don't use.
    dependencies = {
      {
        "taku25/UNL.nvim", -- Core Library
        build = "cargo build --release --manifest-path scanner/Cargo.toml",
        lazy = false,
      },
      "taku25/UEP.nvim", -- Project Explorer
      "taku25/UEA.nvim", -- Asset (Blueprint) Inspector
      "taku25/UBT.nvim", -- Build Tool
      "taku25/UCM.nvim", -- Class Manager
      "taku25/ULG.nvim", -- Log Viewer
      "taku25/USH.nvim", -- Unreal Shell
      {
        "taku25/UNX.nvim", -- Logical View
        dependencies = {
          "MunifTanjim/nui.nvim",
          "nvim-tree/nvim-web-devicons",
        },
      },
      "taku25/UDB.nvim", -- Debug
      {
        "taku25/USX.nvim", -- Syntax highlight
        lazy = false,
      },

      -- UI Plugins (Optional)
      "nvim-telescope/telescope.nvim",
      "j-hui/fidget.nvim",
      "nvim-lualine/lualine.nvim",
      {
        "romus204/tree-sitter-manager.nvim",
        opts = {
          ensure_installed = { "cpp", "ushader", "verse" },
          highlight = { "cpp", "ushader", "verse" },
          border = "rounded",
          languages = {
            cpp = {
              install_info = {
                url = "https://github.com/taku25/tree-sitter-cpp",
                use_repo_queries = true,
              },
            },
            ushader = {
              install_info = {
                url = "https://github.com/taku25/tree-sitter-unreal-shader",
                use_repo_queries = true,
              },
            },
            verse = {
              install_info = {
                url = "https://github.com/taku25/tree-sitter-verse",
                use_repo_queries = true,
              },
            },
          },
        },
        config = function(_, opts)
          vim.filetype.add {
            extension = {
              verse = "verse",
              usf = "ushader",
              ush = "ushader",
            },
          }
          require("tree-sitter-manager").setup(opts)
          local group = vim.api.nvim_create_augroup("MyTreesitter", { clear = true })
          vim.api.nvim_create_autocmd("FileType", {
            group = group,
            pattern = opts.highlight,
            callback = function(args) vim.treesitter.start(args.buf) end,
          })
        end,
      },
      -- ...
    },
    opts = {
      -- Configuration specific to UnrealDev.nvim
      -- (e.g., disable setup for plugins you don't have)
      setup_modules = {
        UBT = true,
        UEP = true,
        ULG = true,
        USH = true,
        UCM = true,
        UEA = true,
        UNX = true,
      },
    },
  },

  -- ---
  -- Individual Plugin Settings (Optional)
  -- ---
  --{ 'taku25/UBT.nvim', opts = { ... } },
  --{ 'taku25/UEP.nvim', opts = { ... } },
  --{ 'taku25/UEA.nvim', opts = { ... } },
  -- ...
}
