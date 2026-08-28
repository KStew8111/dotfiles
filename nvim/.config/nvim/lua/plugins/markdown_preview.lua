-- return {
--   "iamcco/markdown-preview.nvim",
--   cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
--   build = "cd app && yarn install",
--   init = function()
--     vim.g.mkdp_filetypes = { "markdown" }
--     vim.g.mkdp_browser = "chrome"
--     vim.g.mkdp_echo_preview_url = 1
--   end,
--   ft = { "markdown" },
-- }
return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  build = function()
    require("lazy").load { plugins = { "markdown-preview.nvim" } }
    -- Try the pre-built binary first (works on x86_64).
    -- On ARM64 there is no binary, so fall back to npm install.
    local app_dir = vim.fn.stdpath "data" .. "/lazy/markdown-preview.nvim/app"
    local bin = app_dir .. "/bin/markdown-preview-" .. vim.fn["mkdp#util#get_platform"]()
    if not vim.fn.executable(bin) then
      vim.fn.system({ "npm", "install", "--prefix", app_dir })
    else
      vim.fn["mkdp#util#install"]()
    end
  end,
  keys = {
    {
      "<leader>cp",
      ft = "markdown",
      "<cmd>MarkdownPreviewToggle<cr>",
      desc = "Markdown Preview",
    },
  },
  -- config = function() vim.cmd [[do FileType]] end,
  config = function()
    vim.g.mkdp_auto_close = 0

    -- ─── Remote (SSH) support ───────────────────────────────────────────
    -- When running Neovim on a remote machine via SSH, the preview server
    -- can't (and shouldn't) open a browser there.  Instead we:
    --   1. Use a fixed port (7070) so SSH port forwarding works reliably
    --   2. Set mkdp_browserfunc to a custom function that shows the URL
    --      via vim.notify(), copies it to the clipboard (OSC 52), and
    --      stores it for later retrieval with :MkdpShowUrl.
    --
    -- The server still binds to 127.0.0.1 (the plugin default), so it is
    -- only reachable through the SSH tunnel — no exposure to the network.
    --
    -- Requires SSH port forwarding.  Either:
    --   ssh -L 7070:localhost:7070 user@host
    -- or in ~/.ssh/config:
    --   Host my-remote
    --     RemoteForward 7070 localhost:7070
    local is_ssh = vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil
    if is_ssh then
      vim.g.mkdp_port = "7070"

      -- Lua function called by the Vim wrapper below.
      -- The plugin's server calls this via RPC when a preview is opened.
      _G.MkdpOpenBrowserRemote = function(url)
        -- Store for later retrieval
        vim.g.mkdp_remote_url = url

        -- Show via vim.notify (appears in message area / notifications)
        vim.notify(url, vim.log.levels.INFO, { title = "Markdown Preview" })

        -- Also print so it's in :messages
        print("[Markdown Preview] " .. url)

        -- Copy to clipboard (Neovim 0.10+ uses OSC 52 over SSH,
        -- so this copies to your LOCAL clipboard even on a remote machine)
        pcall(vim.fn.setreg, "+", url)
      end

      -- Vim function wrapper — the plugin calls this via nvim.call()
      vim.cmd([[
        function! MkdpOpenBrowserRemote(url) abort
          call luaeval("_G.MkdpOpenBrowserRemote(_A)", a:url)
        endfunction
      ]])

      vim.g.mkdp_browserfunc = "MkdpOpenBrowserRemote"

      -- Convenience command to re-show the URL (e.g. if you missed it)
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

    vim.cmd [[do FileType]]
  end,
}