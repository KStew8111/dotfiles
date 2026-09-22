-- Markdown preview: live browser preview via a pure-Lua SSE server.
-- selimacerbas/markdown-preview.nvim (replaces iamcco's Node-based preview).
--
-- This legacy config runs inside dev containers, where there is no browser
-- and usually no xdg-open — so open_browser is disabled and the preview
-- URL is notified/printed instead; open it on the HOST.
--
-- The starscream devcontainer runs with --net=host, so 127.0.0.1:8421 in
-- the container IS the host's 127.0.0.1:8421 — no port forwarding needed.
-- (Other containers: VS Code auto-forwards the port.)
-- The URL carries a per-session auth token (?t=...); keep it private.
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
    -- Upstream only ships Start/Stop/Refresh — recreate the toggle.
    vim.api.nvim_create_user_command("MarkdownPreviewToggle", function()
      local mdp = require("markdown_preview")
      if vim.g.md_preview_active then
        mdp.stop()
      else
        mdp.start()
      end
    end, { desc = "Toggle Markdown preview" })

    require("markdown_preview").setup({
      open_browser = false, -- no browser inside the container
      hooks = {
        on_start = function(url)
          vim.g.md_preview_active = true -- state for :MarkdownPreviewToggle
          vim.g.mkdp_remote_url = url
          vim.notify(url, vim.log.levels.INFO, { title = "Markdown Preview" })
          print("[Markdown Preview] " .. url)
          pcall(vim.fn.setreg, "+", url)
        end,
        on_stop = function()
          vim.g.md_preview_active = false
        end,
      },
    })

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
  end,
}