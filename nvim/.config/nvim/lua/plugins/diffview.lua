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
-- A ROS workspace is a non-git root with one or more repos under src/, and
-- Neovim is often started at that root with no file buffer. diffview's own
-- repo resolution (buffer, then cwd) finds nothing there, so the mappings below
-- resolve the repo themselves — buffer, else cwd, else the working trees found
-- under the cwd (prompting when there are several) — and hand diffview
-- `-C<root>`. A typed `:DiffviewOpen` still works whenever a file from the repo
-- is open.
--
--   :DiffviewOpen          " working tree / index changes
--   :DiffviewClose         " close the view (also :tabclose)
--   :DiffviewFileHistory   " per-commit history for the repo, a path, or --range=main..HEAD
--
-- Requires only Neovim >= 0.7, so it is safe on the frozen legacy stack too.

-- Git top-level for the focused buffer, else the cwd. nil when neither is
-- inside a working tree.
local function buffer_repo()
  local file = vim.api.nvim_buf_get_name(0)
  local dir = vim.bo.buftype == ""
    and file ~= ""
    and not file:find("://", 1, true)
    and vim.fn.fnamemodify(file, ":p:h")
  for _, d in ipairs { dir or "", vim.fn.getcwd() } do
    if d ~= "" then
      local out = vim.fn.systemlist { "git", "-C", d, "rev-parse", "--show-toplevel" }
      if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then return vim.trim(out[1]) end
    end
  end
end

-- Working trees under `root`, bounded, pruning dot-dirs and the heavy ROS
-- build/install/log trees (plus node_modules). For the workspace-root case.
local function repos_under(root)
  local found, prune = {}, { build = true, install = true, log = true, node_modules = true }
  local function walk(dir, depth)
    if depth > 3 or #found >= 25 then return end
    if vim.uv.fs_stat(dir .. "/.git") then
      local out = vim.fn.systemlist { "git", "-C", dir, "rev-parse", "--show-toplevel" }
      if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then found[#found + 1] = vim.trim(out[1]) end
      return
    end
    local handle = vim.uv.fs_scandir(dir)
    if not handle then return end
    while true do
      local name, typ = vim.uv.fs_scandir_next(handle)
      if not name then break end
      if typ == "directory" and name:sub(1, 1) ~= "." and not prune[name] then
        walk(dir .. "/" .. name, depth + 1)
      end
    end
  end
  walk(root, 0)
  table.sort(found)
  return found
end

local function no_repo()
  vim.notify("diffview: no git repo at the buffer, cwd, or under it", vim.log.levels.WARN)
end

-- Resolve a repo (buffer -> cwd -> repos under cwd, picking when several) and
-- run cb with its top-level path.
local function with_repo(cb)
  local root = buffer_repo()
  if root then return cb(root) end
  local found = repos_under(vim.fn.getcwd())
  if #found == 0 then return no_repo() end
  if #found == 1 then return cb(found[1]) end
  vim.ui.select(found, { prompt = "Diffview repo:" }, function(choice)
    if choice then cb(choice) end
  end)
end

-- `-C<path>` has no space (`-C` takes the path attached) and the Lua API takes
-- args as a list, so paths containing spaces stay intact.
local function open(args)
  with_repo(function(root)
    require("diffview").open(vim.list_extend({ "-C" .. root }, args or {}))
  end)
end

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
        open { base .. "...HEAD" }
      end,
      desc = "Diffview: branch vs base",
    },
    { "<leader>gd", function() open() end, desc = "Diffview: working tree" },
    { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
    {
      "<leader>gH",
      function()
        with_repo(function(root)
          require("diffview").file_history(nil, { "-C" .. root })
        end)
      end,
      desc = "Diffview: file history",
    },
  },
}
