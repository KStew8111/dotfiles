return {
  "erichlf/devcontainer-cli.nvim",
  dependencies = { "akinsho/toggleterm.nvim" },
  opts = {
    interactive = false,
    toplevel = true,
    remove_existing_container = true,
    dotfiles_repository = "https://github.com/KStew8111/dotfiles.git",
    dotfiles_branch = "devcontainer-config",
    dotfiles_targetPath = "~/dotfiles",
    dotfiles_installCommand = "install.sh",
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

      local cmd = {}

      -- 2. Build the command array
      -- We pass each argument as a separate element to avoid quoting issues
      if vim.env.ZELLIJ ~= nil then
        -- 'zellij run' opens a new floating pane or tiled pane by default.
        -- To force a new TAB, we use 'zellij action new-tab'
        -- But 'run' is usually better for one-off tasks.
        cmd = {
          "zellij",
          "run",
          "-i",
          "-c",
          "--",
          "bash",
          "-c",
          string.format(
            "%s up --workspace-folder %s && %s exec --workspace-folder %s %s .",
            devcontainer_bin,
            workspace,
            devcontainer_bin,
            workspace,
            "nvim"
          ),
        }
      elseif vim.fn.executable "ghostty" == 1 then
        cmd = {
          "ghostty",
          "-e",
          bash_bin,
          "-c",
          devcontainer_bin .. " exec --workspace-folder " .. workspace .. " nvim",
        }
      elseif vim.fn.executable "alacritty" == 1 then
        cmd = {
          "alacritty",
          "-e",
          bash_bin,
          "-c",
          devcontainer_bin .. " exec --workspace-folder " .. workspace .. " bash",
        }
      else
        cmd = {
          "gnome-terminal",
          "--",
          bash_bin,
          "-c",
          devcontainer_bin .. " exec --workspace-folder " .. workspace .. " bash",
        }
      end

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
