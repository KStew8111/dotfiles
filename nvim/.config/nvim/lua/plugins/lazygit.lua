return {
  "kdheepak/lazygit.nvim",
  cmd = {
    "LazyGit",
    "LazyGitConfig",
    "LazyGitCurrentFile",
    "LazyGitFilter",
    "LazyGitFilterCurrentFile",
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  -- Use LazyGitCurrentFile (git-root aware) so lazygit always opens the repo the
  -- current file belongs to, instead of relying on the cwd. This runs
  -- `lazygit -p <git-root>` under the hood — the same thing you were doing by hand.
  keys = {
    { "<leader>lg", "<cmd>LazyGitCurrentFile<cr>", desc = "LazyGit" },
  },
  -- Disable AstroNvim's *other*, toggleterm-based lazygit keymaps (`<leader>gg`
  -- and `<leader>tl`). They add --work-tree/--git-dir flags from a different
  -- detection path and suffer the same env issues, causing a duplicate/broken
  -- binding. `<leader>lg` is now the single source of truth.
  specs = {
    {
      "AstroNvim/astrocore",
      opts = function(_, opts)
        local maps = opts.mappings
        maps.n["<Leader>gg"] = false
        maps.n["<Leader>tl"] = false
      end,
    },
  },
  config = function()
    -- 1) TERM/terminfo fallback: in some devcontainers the nvim :terminal job
    --    inherits a TERM (e.g. xterm-ghostty) that isn't in the container's
    --    terminfo, so lazygit's gocui can't initialize the screen -> black window.
    local has_terminfo = function(term)
      if vim.fn.executable "infocmp" ~= 1 then return true end
      vim.fn.system("infocmp " .. term .. " >/dev/null 2>&1")
      return vim.v.shell_error == 0
    end
    if not has_terminfo(vim.env.TERM) and has_terminfo "xterm-256color" then
      vim.env.TERM = "xterm-256color"
      vim.env.COLORTERM = vim.env.COLORTERM or "truecolor"
    end

    -- 2) The devcontainer sets GIT_DIR / GIT_WORK_TREE (duplicated, so vim.env.*
    --    is a table). lazygit.nvim sees them set and adds `-w <GIT_WORK_TREE>
    --    -g <GIT_DIR>`, which makes lazygit chdir to the wrong path and draw a
    --    black screen. Unset them so lazygit uses the repo you're actually in.
    vim.env.GIT_DIR = nil
    vim.env.GIT_WORK_TREE = nil

    -- 3) Gracefully handle a missing lazygit config: create
    --    ~/.config/lazygit/config.yml with the built-in defaults if it doesn't
    --    exist, so :LazyGitConfig works and lazygit behaves predictably.
    local config_dir = vim.trim(vim.fn.system "lazygit -cd")
    if config_dir ~= "" then
      vim.fn.mkdir(config_dir, "p")
      local config_file = config_dir .. "/config.yml"
      if vim.fn.filereadable(config_file) == 0 then
        local f = io.open(config_file, "w")
        if f then
          f:write(vim.fn.system "lazygit -c")
          f:close()
        end
      end
    end

    require("lazygit").setup()
  end,
}
