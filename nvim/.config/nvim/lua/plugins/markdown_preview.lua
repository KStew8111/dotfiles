-- Markdown preview: live browser preview via a pure-Lua SSE server.
-- selimacerbas/markdown-preview.nvim (replaces iamcco's Node-based
-- preview — the old config lives in git history):
--   * instant updates via Server-Sent Events, scroll sync follows cursor
--   * Mermaid diagrams render inline (click to expand, zoom, pan, export)
--   * LaTeX math via KaTeX, highlight.js code blocks, dark/light toggle
--   * zero npm/Node — just Neovim + live-server.nvim
--   * browser-side libs (markdown-it/mermaid/katex/highlight.js) load
--     from CDNs, so the preview page needs internet access
return {
  "selimacerbas/markdown-preview.nvim",
  dependencies = { "selimacerbas/live-server.nvim" },
  cmd = { "MarkdownPreview", "MarkdownPreviewRefresh", "MarkdownPreviewStop" },
  ft = { "markdown" },
  keys = {
    {
      "<leader>cp",
      ft = "markdown",
      "<cmd>MarkdownPreviewToggle<cr>",
      desc = "Markdown Preview",
    },
  },
  config = function()
    -- Upstream only ships Start/Stop/Refresh — recreate the old toggle.
    vim.api.nvim_create_user_command("MarkdownPreviewToggle", function()
      local mdp = require("markdown_preview")
      if vim.g.md_preview_active then
        mdp.stop()
      else
        mdp.start()
      end
    end, { desc = "Toggle Markdown preview" })

    -- ─── Remote (SSH / dev container) support ──────────────────────────
    -- When Neovim runs somewhere without a browser (SSH box or container),
    -- the preview server must not try to open one there.  Instead:
    --   1. Fixed port on SSH (7070) so `ssh -L 7070:localhost:7070` tunnels
    --      work reliably (or ~/.ssh/config: RemoteForward 7070 localhost:7070)
    --   2. hooks.on_start() shows the URL via notify/print and copies it
    --      (OSC 52 → your LOCAL clipboard over SSH)
    --
    -- The server keeps binding 127.0.0.1 (plugin default) and every URL
    -- carries a per-session auth token, so exposure stays limited to:
    --   * SSH: the tunnel itself
    --   * devcontainers with --net=host: container-localhost IS host-
    --     localhost, so the URL just works — no forwarding needed
    --   * other containers: VS Code auto-forwards the port
    local is_ssh = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil
    local in_container = vim.env.REMOTE_CONTAINERS ~= nil
      or vim.env.DEVCONTAINER ~= nil
      or vim.env.CODESPACES ~= nil
      or vim.fn.filereadable("/.dockerenv") == 1

    local opts = {
      instance_mode = "takeover", -- one shared server + tab across instances
      default_theme = "dark",
      -- auto_refresh / scroll_sync / debounce_ms / yaml_mode: sane defaults
    }

    opts.hooks = {
      on_start = function(url)
        vim.g.md_preview_active = true -- state for :MarkdownPreviewToggle

        if is_ssh or in_container then
          vim.g.mkdp_remote_url = url
          vim.notify(url, vim.log.levels.INFO, { title = "Markdown Preview" })
          print("[Markdown Preview] " .. url)
          pcall(vim.fn.setreg, "+", url)
        end
      end,
      on_stop = function()
        vim.g.md_preview_active = false
      end,
    }

    if is_ssh or in_container then
      opts.open_browser = false
      if is_ssh then
        opts.port = 7070
      end

      -- Re-show the URL later (e.g. if you missed the notification)
      vim.api.nvim_create_user_command("MkdpShowUrl", function()
        local url = vim.g.mkdp_remote_url
        if url then
          vim.notify(url, vim.log.levels.INFO, { title = "Markdown Preview" })
          pcall(vim.fn.setreg, "+", url)
          print("[Markdown Preview] " .. url)
        else
          vim.notify("No preview URL yet. Run :MarkdownPreview first.", vim.log.levels.WARN)
        end
      end, { desc = "Show Markdown Preview URL and copy to clipboard" })
    end

    require("markdown_preview").setup(opts)
  end,
}