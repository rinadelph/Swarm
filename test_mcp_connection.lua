-- Test MCP connection in current Neovim session
-- Run this with :source % in Neovim

print("=== Testing MCP Connection ===")

-- Check if MCP server is running
local mcp = require('nvim-gemini-ccide')
local status = mcp.server.status()

if status.running then
  print("✓ MCP server is running on port " .. (status.port or "unknown"))
else
  print("✗ MCP server is not running")
  print("Starting MCP server...")
  local port = mcp.server.start()
  if port then
    print("✓ Started on port " .. port)
  else
    print("✗ Failed to start server")
    return
  end
end

-- Test tool directly
print("\n=== Testing getCurrentSelection tool ===")
local tools = require('nvim-gemini-ccide.tools')
local handler = tools.get_handler('getCurrentSelection')

if handler then
  -- Enter visual mode and select some text
  vim.cmd('normal! ggVG')  -- Select all text
  
  -- Call the tool
  local result = handler({})
  print("Tool result:")
  print(vim.inspect(result))
  
  -- Exit visual mode
  vim.cmd('normal! <Esc>')
else
  print("✗ getCurrentSelection tool not found")
end

-- List all available tools
print("\n=== Available tools ===")
local tool_list = {
  'getCurrentSelection',
  'getOpenEditors', 
  'openFile',
  'getWorkspaceFolders',
  'getDiagnostics',
  'checkDocumentDirty',
  'saveDocument',
  'closeAllDiffTabs'
}

for _, tool_name in ipairs(tool_list) do
  local h = tools.get_handler(tool_name)
  if h then
    print("✓ " .. tool_name)
  else
    print("✗ " .. tool_name .. " (not found)")
  end
end