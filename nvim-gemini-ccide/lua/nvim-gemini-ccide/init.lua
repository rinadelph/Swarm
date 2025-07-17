-- nvim-gemini-ccide/lua/nvim-gemini-ccide/init.lua
-- Neovim plugin that provides MCP server for Claude

local mcp_server = require('nvim-gemini-ccide.mcp_server_robust')
local tools = require('nvim-gemini-ccide.tools')

local M = {}

local function setup_commands()
  -- Server commands
  vim.api.nvim_create_user_command('MCPStart', function(opts)
    local port = tonumber(opts.args) or 0
    local actual_port = mcp_server.start(port)
    if actual_port then
      vim.notify(string.format("🤖 MCP server started on port %d", actual_port), vim.log.levels.INFO)
      vim.notify("💡 Use /ide in Claude to connect", vim.log.levels.INFO)
    end
  end, { nargs = "?", desc = "Start MCP server on specified port (or auto)" })
  
  vim.api.nvim_create_user_command('MCPStop', function()
    mcp_server.stop()
    vim.notify("MCP server stopped", vim.log.levels.INFO)
  end, { desc = "Stop MCP server" })
  
  vim.api.nvim_create_user_command('MCPStatus', function()
    local status = mcp_server.status()
    if status.running then
      vim.notify("MCP server running on port " .. status.port, vim.log.levels.INFO)
    else
      vim.notify("MCP server not running", vim.log.levels.WARN)
    end
  end, { desc = "Show MCP server status" })
  
  -- Test commands
  vim.api.nvim_create_user_command('MCPTest', function()
    -- Test the tools locally
    local handler = tools.get_handler('getCurrentSelection')
    if handler then
      local result = handler({})
      vim.notify("getCurrentSelection result: " .. vim.inspect(result), vim.log.levels.INFO)
    end
  end, { desc = "Test MCP tools" })
end

local function setup_keymaps(opts)
  local prefix = opts.keymaps_prefix or "<leader>m"
  
  vim.keymap.set("n", prefix .. "s", ":MCPStart<CR>", { desc = "Start MCP server" })
  vim.keymap.set("n", prefix .. "x", ":MCPStop<CR>", { desc = "Stop MCP server" })
  vim.keymap.set("n", prefix .. "?", ":MCPStatus<CR>", { desc = "MCP server status" })
end

local function setup_autocmds()
  -- Stop server on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      mcp_server.stop()
    end,
    desc = "Stop MCP server on exit"
  })
end

function M.setup(opts)
  opts = opts or {}
  
  -- Store configuration
  M.config = vim.tbl_deep_extend("force", {
    auto_start = true,        -- Auto-start by default
    port = 0,                 -- Let system choose port
    keymaps = true,           -- Enable keymaps by default
    keymaps_prefix = "<leader>m",
    notifications = {
      startup = true,         -- Show startup notifications
      level = vim.log.levels.INFO,
    },
    status_monitor = {
      enabled = true,         -- Enable status monitoring
      interval = 10000,       -- 10 seconds
    }
  }, opts)
  
  -- Set up commands
  setup_commands()
  
  -- Set up keymaps if enabled
  if M.config.keymaps then
    setup_keymaps(M.config)
  end
  
  -- Set up autocmds
  setup_autocmds()
  
  -- Auto-start server if configured
  if M.config.auto_start then
    vim.defer_fn(function()
      local actual_port = mcp_server.start(M.config.port)
      if actual_port then
        if M.config.notifications.startup then
          vim.notify(string.format("🤖 MCP Server ready on port %d", actual_port), M.config.notifications.level)
          vim.notify("📁 Lock file: ~/.claude/ide/" .. actual_port .. ".lock", M.config.notifications.level)
          vim.notify("💡 Use /ide in Claude to connect", M.config.notifications.level)
        end
      end
    end, 1500)
  end
end

-- Export for advanced usage
M.server = mcp_server
M.tools = tools

return M