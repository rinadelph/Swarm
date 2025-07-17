-- Swarm Neovim - Modern VSCode-like Configuration
-- Clean, professional development environment

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic settings
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.colorcolumn = "80"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.termguicolors = true

-- Split settings
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- Set leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Plugin setup
require("lazy").setup({
  -- Color scheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha", -- Dark theme
        background = {
          light = "latte",
          dark = "mocha",
        },
        transparent_background = false,
        show_end_of_buffer = false,
        term_colors = false,
        dim_inactive = {
          enabled = false,
          shade = "dark",
          percentage = 0.15,
        },
        integrations = {
          nvimtree = true,
          telescope = true,
          which_key = true,
        },
      })
      vim.cmd.colorscheme "catppuccin"
    end,
  },

  -- File icons
  {
    "nvim-tree/nvim-web-devicons",
    config = function()
      require("nvim-web-devicons").setup({
        override = {},
        default = true,
      })
    end,
  },

  -- Modern file explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- Disable netrw
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1

      require("nvim-tree").setup({
        sort_by = "case_sensitive",
        view = {
          width = 30,
          side = "left",
          number = false,
          relativenumber = false,
        },
        renderer = {
          group_empty = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
        git = {
          enable = true,
        },
        actions = {
          open_file = {
            quit_on_open = false,
            resize_window = false,
          },
        },
      })

      -- Auto-open nvim-tree and focus on file editor
      local function open_nvim_tree()
        require("nvim-tree.api").tree.open()
        vim.cmd("wincmd p") -- Focus on the file editor window
      end

      vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })
    end,
  },

  -- Better statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "catppuccin",
          component_separators = { left = "│", right = "│" },
          section_separators = { left = "", right = "" },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.4",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_config = {
            horizontal = {
              preview_width = 0.6,
            },
          },
        },
      })
    end,
  },

  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "vim", "javascript", "typescript", "python", "rust", "go", "html", "css", "json" },
        highlight = {
          enable = true,
        },
        indent = {
          enable = true,
        },
      })
    end,
  },

  -- Claude Code Integration (MCP Server)
  {
    dir = '/home/alejandro/VPS/CCIde/nvim-gemini-ccide',
    name = 'nvim-gemini-ccide',
    config = function()
      require('nvim-gemini-ccide').setup()
      -- That's it! The plugin now auto-starts by default
    end,
  },
})

-- Key mappings
local map = vim.keymap.set

-- File explorer
map('n', '<C-e>', ':NvimTreeToggle<CR>', { desc = 'Toggle file explorer' })
map('n', '<leader>e', ':NvimTreeFocus<CR>', { desc = 'Focus file explorer' })

-- Window navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Move to left window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Move to right window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Move to bottom window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Move to top window' })

-- File operations
map('n', '<leader>w', ':w<CR>', { desc = 'Save file' })
map('n', '<leader>q', ':q<CR>', { desc = 'Quit' })
map('n', '<leader>Q', ':qa<CR>', { desc = 'Quit all' })

-- Telescope
map('n', '<leader>ff', ':Telescope find_files<CR>', { desc = 'Find files' })
map('n', '<leader>fg', ':Telescope live_grep<CR>', { desc = 'Find in files' })
map('n', '<leader>fb', ':Telescope buffers<CR>', { desc = 'Find buffers' })

-- Better movement
map('n', 'j', 'gj', { desc = 'Move down visual line' })
map('n', 'k', 'gk', { desc = 'Move up visual line' })

-- Clear search highlighting
map('n', '<Esc>', ':noh<CR>', { desc = 'Clear search highlighting' })

-- Better indenting
map('v', '<', '<gv', { desc = 'Indent left' })
map('v', '>', '>gv', { desc = 'Indent right' })

-- Move lines
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- MCP Server (Claude Integration)
map('n', '<leader>ms', ':MCPStart<CR>', { desc = 'Start MCP server for Claude' })
map('n', '<leader>mx', ':MCPStop<CR>', { desc = 'Stop MCP server' })
map('n', '<leader>m?', ':MCPStatus<CR>', { desc = 'Check MCP server status' })
map('n', '<leader>mt', ':MCPTest<CR>', { desc = 'Test MCP tools' })

-- MCP Monitor
map('n', '<leader>mm', ':MCPMonitor<CR>', { desc = 'Start MCP monitor' })
map('n', '<leader>mM', ':MCPMonitorStop<CR>', { desc = 'Stop MCP monitor' })

-- Auto commands
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight yanked text",
  group = vim.api.nvim_create_augroup("highlight_yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})

-- Remove trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Remove trailing whitespace",
  group = vim.api.nvim_create_augroup("remove_trailing_whitespace", { clear = true }),
  pattern = "*",
  command = [[%s/\s\+$//e]],
})

print("🚀 Swarm Neovim loaded! Press <Space>ff to find files, <Ctrl-e> to toggle explorer")
print("🤖 MCP Server auto-starting... Use <Space>m? for status, /ide in Claude to connect")

-- IPC Test Function
function TestIPCServer()
  local log_file = "/tmp/nvim_ipc_test.log"
  
  -- Clear log
  vim.fn.system("echo '=== IPC Test Log ===' > " .. log_file)
  
  local function log(msg)
    local file = io.open(log_file, "a")
    if file then
      file:write(os.date("[%H:%M:%S] ") .. msg .. "\n")
      file:close()
    end
  end
  
  log("Starting IPC test server...")
  
  -- Import tools
  local ok, tools = pcall(require, 'nvim-gemini-ccide.tools')
  if not ok then
    vim.notify("Failed to load tools module!", vim.log.levels.ERROR)
    return
  end
  
  local job_id = vim.fn.jobstart({
    "python3", "/home/alejandro/VPS/CCIde/nvim-gemini-ccide/test_ipc_server.py"
  }, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          log("STDOUT: " .. line)
          
          -- Handle NVIM_REQUEST
          if line:match("^NVIM_REQUEST:") then
            local json_str = line:sub(14)
            log("Processing request: " .. json_str)
            
            local ok, request = pcall(vim.json.decode, json_str)
            if ok and request then
              local handler = tools.get_handler(request.tool)
              if handler then
                local result = handler(request.args or {})
                local response = vim.json.encode({
                  id = request.id,
                  result = result
                })
                log("Sending response: " .. response)
                vim.fn.chansend(job_id, response .. "\n")
              else
                log("No handler for tool: " .. request.tool)
              end
            end
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          log("STDERR: " .. line)
        end
      end
    end,
    on_exit = function(_, code, _)
      log("Process exited with code: " .. code)
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if job_id > 0 then
    vim.notify("IPC test started! Check log: " .. log_file, vim.log.levels.INFO)
    
    -- Open test file
    vim.cmd("edit test_file.txt")
    vim.cmd("normal! ggVG")  -- Select all
    
    -- Open log monitor
    vim.fn.system("tmux new-window -n ipc_log 'tail -f " .. log_file .. "'")
  else
    vim.notify("Failed to start IPC test!", vim.log.levels.ERROR)
  end
end

-- Add command for IPC test
vim.api.nvim_create_user_command('TestIPC', TestIPCServer, { desc = 'Run IPC test server' })

-- Continuous MCP Monitor Function
function StartMCPMonitor()
  local log_file = "/tmp/nvim_mcp_monitor.log"
  
  -- Import tools
  local ok, tools = pcall(require, 'nvim-gemini-ccide.tools')
  if not ok then
    vim.notify("Failed to load tools module!", vim.log.levels.ERROR)
    return
  end
  
  -- Store job ID globally so we can stop it later
  if vim.g.mcp_monitor_job and vim.fn.jobwait({vim.g.mcp_monitor_job}, 0)[1] == -1 then
    vim.notify("MCP Monitor already running!", vim.log.levels.WARN)
    return
  end
  
  vim.g.mcp_monitor_job = vim.fn.jobstart({
    "python3", "/home/alejandro/VPS/CCIde/nvim-gemini-ccide/continuous_ipc_monitor.py"
  }, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" and line:match("^NVIM_REQUEST:") then
          local json_str = line:sub(14)
          local ok, request = pcall(vim.json.decode, json_str)
          if ok and request then
            local handler = tools.get_handler(request.tool)
            if handler then
              local result = handler(request.args or {})
              local response = vim.json.encode({
                id = request.id,
                result = result
              })
              vim.fn.chansend(vim.g.mcp_monitor_job, response .. "\n")
            end
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      -- Monitor stderr shows menu and status
      for _, line in ipairs(data) do
        if line ~= "" and not line:match("^====") and not line:match("^Press") and not line:match("^Auto-refresh") then
          -- Only show important messages
          if line:match("ERROR") or line:match("WARN") then
            vim.notify(line, vim.log.levels.WARN)
          end
        end
      end
    end,
    on_exit = function(_, code, _)
      vim.notify("MCP Monitor stopped (exit code: " .. code .. ")", vim.log.levels.INFO)
      vim.g.mcp_monitor_job = nil
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if vim.g.mcp_monitor_job > 0 then
    vim.notify("MCP Monitor started! Check log: " .. log_file, vim.log.levels.INFO)
    
    -- Open log monitor in new tmux window
    vim.fn.system("tmux new-window -n mcp_monitor 'tail -f " .. log_file .. "'")
    
    -- Open monitor control in another tmux pane
    vim.fn.system("tmux split-window -v -t mcp_monitor 'echo \"MCP Monitor Controls:\"; echo \"1-8: Test tools\"; echo \"a: Toggle auto mode\"; echo \"q: Quit\"; echo \"\"; cat > " .. vim.g.mcp_monitor_job .. "'")
  else
    vim.notify("Failed to start MCP Monitor!", vim.log.levels.ERROR)
  end
end

function StopMCPMonitor()
  if vim.g.mcp_monitor_job then
    vim.fn.jobstop(vim.g.mcp_monitor_job)
    vim.g.mcp_monitor_job = nil
    vim.notify("MCP Monitor stopped", vim.log.levels.INFO)
  else
    vim.notify("MCP Monitor not running", vim.log.levels.WARN)
  end
end

-- Add commands for MCP Monitor
vim.api.nvim_create_user_command('MCPMonitor', StartMCPMonitor, { desc = 'Start continuous MCP monitor' })
vim.api.nvim_create_user_command('MCPMonitorStop', StopMCPMonitor, { desc = 'Stop MCP monitor' })

-- Simple Auto-polling Monitor
function StartAutoMonitor()
  local log_file = "/tmp/nvim_mcp_monitor.log"
  
  -- Import tools
  local ok, tools = pcall(require, 'nvim-gemini-ccide.tools')
  if not ok then
    vim.notify("Failed to load tools module!", vim.log.levels.ERROR)
    return
  end
  
  -- Stop existing monitor
  if vim.g.auto_monitor_job then
    vim.fn.jobstop(vim.g.auto_monitor_job)
  end
  if vim.g.auto_monitor_timer then
    vim.fn.timer_stop(vim.g.auto_monitor_timer)
  end
  
  -- Start simple monitor
  vim.g.auto_monitor_job = vim.fn.jobstart({
    "python3", "/home/alejandro/VPS/CCIde/nvim-gemini-ccide/simple_monitor.py"
  }, {
    on_stdout = function(_, data, _)
      -- Just log everything
    end,
    on_stderr = function(_, data, _)
      -- Monitor logs
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  -- Auto-poll function
  local function poll_tools()
    if not vim.g.auto_monitor_job then
      return
    end
    
    -- Get current state
    local selection = tools.get_handler('getCurrentSelection')({})
    local editors = tools.get_handler('getOpenEditors')({})
    local diagnostics = tools.get_handler('getDiagnostics')({uri = ""})
    
    -- Send to monitor
    local data = {
      time = os.date("%H:%M:%S"),
      selection = vim.json.decode(selection.content[1].text),
      editors = vim.json.decode(editors.content[1].text),
      diagnostics = vim.json.decode(diagnostics.content[1].text)
    }
    
    vim.fn.chansend(vim.g.auto_monitor_job, vim.json.encode(data) .. "\n")
  end
  
  -- Start polling timer (every 1 second)
  vim.g.auto_monitor_timer = vim.fn.timer_start(1000, poll_tools, {['repeat'] = -1})
  
  vim.notify("Auto monitor started! Log: " .. log_file, vim.log.levels.INFO)
  
  -- Open log viewer
  vim.fn.system("tmux new-window -n auto_monitor 'tail -f " .. log_file .. "'")
end

function StopAutoMonitor()
  if vim.g.auto_monitor_job then
    vim.fn.jobstop(vim.g.auto_monitor_job)
    vim.g.auto_monitor_job = nil
  end
  if vim.g.auto_monitor_timer then
    vim.fn.timer_stop(vim.g.auto_monitor_timer)
    vim.g.auto_monitor_timer = nil
  end
  vim.notify("Auto monitor stopped", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command('AutoMonitor', StartAutoMonitor, { desc = 'Start auto-polling monitor' })
vim.api.nvim_create_user_command('AutoMonitorStop', StopAutoMonitor, { desc = 'Stop auto-polling monitor' })