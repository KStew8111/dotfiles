-- OSC 52 clipboard for SSH sessions.
--
-- When Neovim runs on a remote host (rig-launch-nvim's "ssh: <host>"
-- entries), there is no local display for the usual clipboard providers, so
-- yanks would otherwise fail. Supplying a `vim.g.clipboard` provider that
-- writes OSC 52 escape sequences through the terminal is what puts them on
-- your local clipboard. Ghostty allows OSC 52 writes by default; reads prompt.
--
-- AstroNvim already sets `clipboard = "unnamedplus"`; this only supplies the
-- provider, and only over SSH — local sessions keep their native provider.
return {
  "AstroNvim/astrocore",
  opts = function(_, opts)
    if not (vim.env.SSH_CONNECTION or vim.env.SSH_TTY) then return opts end

    local osc52 = require "vim.ui.clipboard.osc52"
    opts.options = opts.options or {}
    opts.options.g = vim.tbl_deep_extend("force", opts.options.g or {}, {
      clipboard = {
        name = "OSC 52",
        copy = {
          ["+"] = osc52.copy "+",
          ["*"] = osc52.copy "*",
        },
        paste = {
          ["+"] = osc52.paste "+",
          ["*"] = osc52.paste "*",
        },
      },
    })
    return opts
  end,
}
