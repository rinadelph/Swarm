-- nvim-gemini-ccide/lua/nvim-gemini-ccide/utils.lua

local M = {}

-- Finds the active Claude IDE lock file.
function M.find_lock_file()
  local lock_dir = vim.fn.expand("~/.claude/ide/")
  
  -- Check if directory exists
  if vim.fn.isdirectory(lock_dir) == 0 then
    vim.notify("Claude Code: Lock directory not found: " .. lock_dir, vim.log.levels.ERROR)
    return nil
  end
  
  -- Find all .lock files
  local lock_files = vim.fn.glob(lock_dir .. "*.lock", false, true)
  
  if #lock_files == 0 then
    vim.notify("Claude Code: No lock files found", vim.log.levels.ERROR)
    return nil
  end
  
  -- Sort by modification time (newest first)
  table.sort(lock_files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  
  vim.notify("Claude Code: Found lock file: " .. lock_files[1], vim.log.levels.DEBUG)
  return lock_files[1]
end

-- Reads and parses the lock file to get connection details.
function M.get_connection_details()
  local lock_file = M.find_lock_file()
  if not lock_file then
    return nil
  end
  
  -- Read the lock file
  local content = vim.fn.readfile(lock_file)
  if #content == 0 then
    vim.notify("Claude Code: Lock file is empty", vim.log.levels.ERROR)
    return nil
  end
  
  -- Join lines and parse JSON
  local json_str = table.concat(content, "\n")
  local ok, data = pcall(vim.json.decode, json_str)
  
  if not ok then
    vim.notify("Claude Code: Failed to parse lock file: " .. tostring(data), vim.log.levels.ERROR)
    return nil
  end
  
  -- Extract port (might be in the data or we need to extract from filename)
  local port = data.port
  if not port then
    -- Try to extract from filename (e.g., "40145.lock")
    local filename = vim.fn.fnamemodify(lock_file, ":t")
    port = filename:match("^(%d+)%.lock$")
  end
  
  if not port or not data.authToken then
    vim.notify("Claude Code: Invalid lock file format", vim.log.levels.ERROR)
    return nil
  end
  
  vim.notify(string.format("Claude Code: Found connection - Port: %s, PID: %s", 
    tostring(port), tostring(data.pid)), vim.log.levels.DEBUG)
  
  return {
    port = tonumber(port) or 40145,
    authToken = data.authToken,
    pid = data.pid,
    workspaceFolders = data.workspaceFolders or {},
  }
end

-- Check if VS Code process is still running
function M.is_vscode_running(pid)
  if not pid then return false end
  
  -- Check if process exists (works on Unix-like systems)
  local handle = io.popen(string.format("ps -p %d -o comm=", pid))
  if handle then
    local result = handle:read("*a")
    handle:close()
    return result and result:match("code") ~= nil
  end
  
  return false
end

return M