-- Minimal init file for testing the plugin
vim.opt.runtimepath:append(vim.fn.getcwd())

-- Load the plugin
local ok, claude = pcall(require, 'nvim-gemini-ccide')
if not ok then
  print("Failed to load plugin: " .. tostring(claude))
  return
end

-- Set up with manual start
claude.setup({
  auto_start = false,  -- Don't auto-start
  keymaps = true,
  debug = true,
})

print("Neovim MCP Plugin loaded!")
print("Commands:")
print("  :MCPStart [port]  - Start MCP server")
print("  :MCPStatus        - Check server status")
print("  :MCPStop          - Stop server")
print("  :MCPTest          - Test MCP tools")
print("")
print("Try: :MCPStart")