-- Test configuration for Neovim
-- Add plugin to runtimepath
vim.opt.runtimepath:append(vim.fn.getcwd())

-- Set up the plugin
require('nvim-gemini-ccide').setup({
  auto_start = true,   -- Auto-start MCP server
  port = 45000,        -- Fixed port for testing
  keymaps = true,
  debug = true,
})

-- Show status after startup
vim.defer_fn(function()
  vim.cmd('MCPStatus')
  
  -- Check if lock file was created
  local lock_files = vim.fn.glob(vim.fn.expand("~/.claude/ide/neovim_*.lock"), false, true)
  if #lock_files > 0 then
    print("Lock file created: " .. lock_files[1])
    
    -- Read and show lock file content
    local content = vim.fn.readfile(lock_files[1])
    print("Lock file content: " .. table.concat(content, "\n"))
  else
    print("No lock file created yet")
  end
end, 2000)