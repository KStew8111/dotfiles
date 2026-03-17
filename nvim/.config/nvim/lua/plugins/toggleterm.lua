return {
  "akinsho/toggleterm.nvim",
  config = function()
    require("toggleterm").setup {
      -- your existing config
      on_open = function(term)
        -- Enable terminal job mode keybindings in the terminal
        vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<C-h>", [[<Cmd>wincmd h<CR>]], {
          noremap = true,
          silent = true,
        })
      end,
    }
  end,
}
