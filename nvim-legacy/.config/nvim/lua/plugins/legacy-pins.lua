-- Hard version pins for the legacy stack (AstroNvim v5 / Neovim 0.10.4).
--
-- AstroNvim's `lazy_snapshot` normally pins these (it activates because
-- lazy_setup.lua sets `version = "^5"`), but a stale/drifted lazy-lock.json or
-- a config run without version tracking can silently resolve the v6-era
-- releases, which are incompatible with the frozen nvim-treesitter `master`
-- branch that AstroNvim v5 uses. These user-side specs keep the pins applied
-- regardless of the snapshot.
--
--   * astrocore v3+ calls `require("nvim-treesitter").get_installed`, which
--     only exists in the nvim-treesitter `main` rewrite. Against the frozen
--     master (42fc28ba) it throws on every file open:
--       treesitter.lua:64: attempt to call field 'get_installed' (a nil value)
--   * nvim-treesitter-textobjects `main` now hosts the rewrite
--     (lua/nvim-treesitter-textobjects/...), which cannot be driven through
--     nvim-treesitter.configs on Neovim 0.10.4.
--
-- Update these deliberately (and re-test in a devcontainer), not casually.

---@type LazySpec
return {
  { "AstroNvim/astrocore", version = "^2" },
  { "AstroNvim/astrolsp", version = "^3" },
  { "AstroNvim/astroui", version = "^3" },
  -- nvim-treesitter is already branch-pinned to `master` by AstroNvim v5 and
  -- render-markdown.lua; the commit pin additionally freezes it against
  -- movement on the master branch itself.
  { "nvim-treesitter/nvim-treesitter", commit = "42fc28ba918343ebfd5565147a42a26580579482" },
  { "nvim-treesitter/nvim-treesitter-textobjects", commit = "5ca4aaa6efdcc59be46b95a3e876300cfead05ef" },
}