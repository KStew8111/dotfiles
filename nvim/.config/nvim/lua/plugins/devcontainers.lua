return {
  "erichlf/devcontainer-cli.nvim",
  dependencies = { "akinsho/toggleterm.nvim" },
  opts = {
    interactive = false,
    toplevel = true,
    remove_existing_container = true,
    dotfiles_repository = "https://github.com/KStew8111/dotfiles.git",
    dotfiles_branch = "main",
    dotfiles_targetPath = "~/dotfiles",
    -- NOTE: devcontainer-cli.nvim reads `dotfiles_install_command`, but its
    -- default config key is `dotfiles_installCommand`. Set both so the custom
    -- wrapper is used regardless of that inconsistency.
    dotfiles_installCommand = "install-devcontainer.sh",
    dotfiles_install_command = "install-devcontainer.sh",
    shell = "bash",
    nvim_binary = "nvim",
    log_level = "debug",
    console_level = "info",
  },
  config = function(_, opts)
    local devcontainer = require "devcontainer-cli"

    -- 2. Define our fixed connection logic

    local function fixed_connect()
      -- 1. Resolve absolute paths for the host binaries
      local bash_bin = vim.fn.exepath "bash"
      local devcontainer_bin = vim.fn.exepath "devcontainer"
      local workspace = vim.fn.getcwd()

      -- Safety check to prevent launching an empty command
      if devcontainer_bin == "" or bash_bin == "" then
        print "Error: Could not find bash or devcontainer on host PATH."
        return
      end

      -- 2. Build the devcontainer up command, including dotfiles settings
      --    so it matches what :DevcontainerUp would do.
      local up_cmd = devcontainer_bin .. " up --workspace-folder '" .. workspace .. "'"
      up_cmd = up_cmd .. " --remove-existing-container"
      up_cmd = up_cmd .. " --update-remote-user-uid-default off"

      if opts.dotfiles_repository and opts.dotfiles_repository ~= "" then
        up_cmd = up_cmd .. " --dotfiles-repository '" .. opts.dotfiles_repository .. "'"
        if opts.dotfiles_branch and opts.dotfiles_branch ~= "" then
          up_cmd = up_cmd .. " -b " .. opts.dotfiles_branch
        end
        if opts.dotfiles_targetPath and opts.dotfiles_targetPath ~= "" then
          up_cmd = up_cmd .. " --dotfiles-target-path '" .. opts.dotfiles_targetPath .. "'"
        end
        -- The plugin internally reads `dotfiles_install_command` (snake_case).
        local install_cmd = opts.dotfiles_install_command or opts.dotfiles_installCommand
        if install_cmd and install_cmd ~= "" then
          up_cmd = up_cmd .. " --dotfiles-install-command '" .. install_cmd .. "'"
        end
      end

      local nvim_binary = opts.nvim_binary or "nvim"
      local exec_cmd = devcontainer_bin .. " exec --workspace-folder '" .. workspace .. "' " .. nvim_binary

      -- Shell command that keeps the terminal open if either up or exec fails,
      -- so the error is visible instead of the window closing instantly.
      local shell_cmd = "(" .. up_cmd .. " && " .. exec_cmd .. ") || (ec=$?; echo 'DevcontainerConnect failed with exit code '$ec; read -rsp 'Press Enter to close...' _; exit $ec)"

      local cmd = {}
      local term_name = "gnome-terminal"

      if vim.env.ZELLIJ ~= nil then
        term_name = "zellij"
        cmd = {
          "zellij",
          "run",
          "-i",
          "-c",
          "--",
          "bash",
          "-c",
          shell_cmd,
        }
      elseif vim.fn.executable "ghostty" == 1 then
        term_name = "ghostty"
        cmd = {
          "ghostty",
          "-e",
          bash_bin,
          "-c",
          shell_cmd,
        }
      elseif vim.fn.executable "alacritty" == 1 then
        term_name = "alacritty"
        cmd = {
          "alacritty",
          "-e",
          bash_bin,
          "-c",
          shell_cmd,
        }
      elseif vim.fn.executable "gnome-terminal" == 1 then
        term_name = "gnome-terminal"
        cmd = {
          "gnome-terminal",
          "--",
          bash_bin,
          "-c",
          shell_cmd,
        }
      else
        vim.notify("No supported terminal emulator found (ghostty, alacritty, gnome-terminal).", vim.log.levels.ERROR)
        return
      end

      vim.notify("DevcontainerConnect using " .. term_name .. ": " .. shell_cmd, vim.log.levels.INFO)

      -- 3. Launch the process
      vim.fn.jobstart(cmd, {
        detach = true,
        cwd = workspace,
      })
    end

    -- 3. Run the plugin's setup
    devcontainer.setup(opts)

    -- 4. FORCE OVERRIDE: Manually redefine the command so it uses our fixed logic
    -- This overwrites whatever the plugin created during setup.
    vim.api.nvim_create_user_command("DevcontainerConnect", fixed_connect, {
      desc = "Connect to devcontainer using Ghostty",
    })

    -- Also patch the table just in case other functions call it
    devcontainer.connect = fixed_connect
  end,
}
