return {
  "kdheepak/lazygit.nvim",
  cmd = {
    "LazyGit",
    "LazyGitConfig",
    "LazyGitCurrentFile",
    "LazyGitFilter",
    "LazyGitFilterCurrentFile",
  },
  -- optional for floating window border decoration
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  -- setting the keybinding for LazyGit with 'keys' is recommended in
  -- order to load the plugin when the command is run for the first time
  keys = {
    { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
  },
  config = function()
    -- Fixes a black/blank screen in devcontainers/docker where lazygit's
    -- gocui UI fails to initialize the screen. The nvim :terminal job inherits
    -- a TERM that may not be present in the container's terminfo (e.g.
    -- xterm-ghostty over `devcontainer exec`), so lazygit draws nothing.
    -- Fall back to a TERM that base images always ship, plus truecolor.
    local has_terminfo = function(term)
      if vim.fn.executable "infocmp" ~= 1 then return true end
      vim.fn.system("infocmp " .. term .. " >/dev/null 2>&1")
      return vim.v.shell_error == 0
    end
    if not has_terminfo(vim.env.TERM) and has_terminfo "xterm-256color" then
      vim.env.TERM = "xterm-256color"
      vim.env.COLORTERM = vim.env.COLORTERM or "truecolor"
    end

    -- Root cause of the black screen in this devcontainer: GIT_DIR and
    -- GIT_WORK_TREE are set (and duplicated) in the container's environment,
    -- so vim.env.* comes back as a table. lazygit.nvim sees those set and adds
    -- `-w <GIT_WORK_TREE> -g <GIT_DIR>` to the lazygit call, which makes lazygit
    -- chdir into the wrong path and fail to draw its UI. Unset them so lazygit
    -- just uses the repo you're actually editing.
    vim.env.GIT_DIR = nil
    vim.env.GIT_WORK_TREE = nil

    require("lazygit").setup()
  end,
}
