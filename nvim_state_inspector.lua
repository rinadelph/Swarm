-- Neovim State Inspector
-- This script shows current file, selection, and tests MCP tools

local function inspect_current_state()
  print("=== Neovim Current State ===")
  
  -- Current file
  local current_file = vim.api.nvim_buf_get_name(0)
  print("Current file: " .. current_file)
  
  -- File type
  local filetype = vim.bo.filetype
  print("File type: " .. filetype)
  
  -- Current mode
  local mode = vim.fn.mode()
  local mode_name = ({
    n = "Normal",
    v = "Visual (char)",
    V = "Visual (line)", 
    [""] = "Visual (block)",
    i = "Insert",
    c = "Command"
  })[mode] or mode
  print("Current mode: " .. mode_name)
  
  -- Cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  print("Cursor position: line " .. cursor[1] .. ", col " .. cursor[2])
  
  -- Selection (if in visual mode)
  if mode == 'v' or mode == 'V' or mode == '' then
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    print("\nSelection:")
    print("  Start: line " .. start_pos[2] .. ", col " .. start_pos[3])
    print("  End: line " .. end_pos[2] .. ", col " .. end_pos[3])
    
    -- Get selected text
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
    if #lines > 0 then
      if mode == 'v' and #lines == 1 then
        -- Character-wise visual on single line
        lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
      elseif mode == 'v' then
        -- Character-wise visual on multiple lines
        lines[1] = lines[1]:sub(start_pos[3])
        lines[#lines] = lines[#lines]:sub(1, end_pos[3])
      end
      
      print("\nSelected text:")
      for i, line in ipairs(lines) do
        print("  " .. i .. ": " .. line)
      end
    end
  else
    print("\nNo selection (not in visual mode)")
  end
  
  -- Open buffers
  print("\n=== Open Buffers ===")
  local buffers = vim.api.nvim_list_bufs()
  local loaded_count = 0
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) ~= "" then
      loaded_count = loaded_count + 1
      local name = vim.api.nvim_buf_get_name(buf)
      local modified = vim.bo[buf].modified and " [+]" or ""
      print(string.format("  Buffer %d: %s%s", buf, name, modified))
    end
  end
  print("Total loaded buffers: " .. loaded_count)
  
  -- Test MCP tools directly
  print("\n=== Testing MCP Tools ===")
  local tools = require('nvim-gemini-ccide.tools')
  
  -- Test getCurrentSelection
  local handler = tools.get_handler('getCurrentSelection')
  if handler then
    local result = handler({})
    print("\ngetCurrentSelection result:")
    -- Parse the JSON result
    if result and result.content and result.content[1] then
      local ok, data = pcall(vim.json.decode, result.content[1].text)
      if ok then
        print("  File: " .. (data.filePath or "none"))
        print("  Text: " .. (data.text or "none"))
        print("  Selection empty: " .. tostring(data.selection and data.selection.isEmpty))
      else
        print("  Raw result: " .. vim.inspect(result))
      end
    end
  else
    print("getCurrentSelection handler not found!")
  end
  
  -- Test getOpenEditors
  handler = tools.get_handler('getOpenEditors')
  if handler then
    local result = handler({})
    print("\ngetOpenEditors result:")
    if result and result.content and result.content[1] then
      local ok, data = pcall(vim.json.decode, result.content[1].text)
      if ok and data.editors then
        print("  Open editors: " .. #data.editors)
        for i, editor in ipairs(data.editors) do
          print("    " .. i .. ": " .. editor.filePath)
        end
      end
    end
  end
  
  -- Check MCP server status
  print("\n=== MCP Server Status ===")
  local mcp = require('nvim-gemini-ccide')
  local status = mcp.server.status()
  print("Running: " .. tostring(status.running))
  print("Port: " .. tostring(status.port))
  print("PID: " .. tostring(status.pid))
end

-- Run the inspection
inspect_current_state()

-- If you want to test visual mode selection:
print("\n=== Instructions ===")
print("1. Enter visual mode (v, V, or Ctrl-V)")
print("2. Select some text")
print("3. Run :source % again to see selection info")