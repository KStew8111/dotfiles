-- diffview.nvim — a PR-style review view for a branch's changes.
--
-- The command that matters is the triple-dot form, which diffview resolves via
-- the merge base — the same set of changes GitHub shows under "Files changed":
--
--   :DiffviewOpen origin/main...HEAD
--
-- Two-dot (`main..HEAD`) diffs the tips instead, so commits that only landed on
-- the base branch show up as reversions. Fetch first and diff `origin/main` to
-- avoid that.
--
--   :DiffviewOpen          " working tree / index changes
--   :DiffviewClose         " close the view (also :tabclose)
--   :DiffviewFileHistory   " per-commit history for the repo, a path, or --range=main..HEAD
--
-- diffview only needs Neovim >= 0.7 (LuaJIT), so it is compatible with the
-- frozen AstroNvim v5 / Neovim 0.10.4 stack here. Pin the commit in
-- lazy-lock.json rather than bumping it casually.
return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
    "DiffviewFileHistory",
    "DiffviewLog",
  },
  keys = {
    {
      "<leader>gB",
      function()
        local base = vim.fn.input("Diffview base ref: ", "origin/main")
        if base == "" then return end
        vim.cmd("DiffviewOpen " .. base .. "...HEAD")
      end,
      desc = "Diffview: branch vs base",
    },
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
    { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: file history" },
  },
}
