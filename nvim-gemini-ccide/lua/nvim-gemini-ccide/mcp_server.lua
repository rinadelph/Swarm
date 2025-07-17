-- nvim-gemini-ccide/lua/nvim-gemini-ccide/mcp_server.lua
-- MCP Server that Claude Code can connect to

local M = {}

local server_job = nil
local server_port = nil

-- Start the MCP server
function M.start(port)
  if server_job then
    vim.notify("MCP server already running on port " .. server_port, vim.log.levels.WARN)
    return server_port
  end
  
  -- Always use dynamic port (0 means let the system choose)
  port = 0
  
  -- Generate auth token (UUID-like)
  local auth_token = string.format("nvim-%d-%d-%d", 
    os.time(), 
    vim.fn.getpid(), 
    math.random(10000, 99999)
  )
  
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
  local server_script = plugin_dir .. "/mcp_server_robust.py"
  
  -- Create a debug log file
  local log_file = "/tmp/mcp_debug.log"
  vim.fn.system("echo '=== MCP Debug Log ===' > " .. log_file)
  
  -- Store auth token for later use
  M.auth_token = auth_token
  
  -- Start the Python MCP server in a tmux session for debugging
  vim.fn.system("tmux kill-session -t mcp_debug 2>/dev/null || true")
  vim.fn.system(string.format(
    "tmux new-session -d -s mcp_debug 'python3 %s %s %s 2>&1 | tee %s'",
    server_script, tostring(port), auth_token, log_file
  ))
  
  -- Get the PID of the tmux session
  local tmux_pid = vim.fn.system("tmux list-panes -t mcp_debug -F '#{pane_pid}' 2>/dev/null | head -1"):gsub("\n", "")
  
  -- Monitor the server output
  server_job = vim.fn.jobstart({
    "tail", "-f", log_file
  }, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          -- Parse server output
          if line:match("^PORT:") then
            server_port = tonumber(line:match("^PORT:(%d+)"))
            M.write_lock_file(server_port)
            vim.notify("MCP server started on port " .. server_port, vim.log.levels.INFO)
            vim.notify("Auth token: " .. M.auth_token, vim.log.levels.INFO)
            vim.notify("Debug logs: tmux attach -t mcp_debug or tail -f /tmp/mcp_debug.log", vim.log.levels.INFO)
          elseif line:match("^AUTH:") then
            -- Auth token confirmation from server
            local server_auth = line:match("^AUTH:(.+)")
            vim.notify("Server confirmed auth: " .. server_auth, vim.log.levels.DEBUG)
          elseif line:match("^PID:") then
            -- Server process ID
            local server_pid = line:match("^PID:(.+)")
            vim.notify("Server PID: " .. server_pid, vim.log.levels.DEBUG)
          else
            vim.notify("MCP Server: " .. line, vim.log.levels.DEBUG)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.notify("MCP Server Error: " .. line, vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code, _)
      server_job = nil
      server_port = nil
      M.remove_lock_file()
      vim.notify("MCP server stopped (exit code: " .. code .. ")", vim.log.levels.INFO)
    end
  })
  
  if server_job == 0 then
    vim.notify("Failed to start MCP server", vim.log.levels.ERROR)
    server_job = nil
    return nil
  end
  
  -- Wait a bit for server to start and report its port
  vim.wait(2000, function() return server_port ~= nil end)
  
  return server_port
end

-- Stop the MCP server
function M.stop()
  if server_job then
    vim.fn.jobstop(server_job)
    server_job = nil
    server_port = nil
  end
end

-- Write lock file for Claude to find us
function M.write_lock_file(port)
  local lock_dir = vim.fn.expand("~/.claude/ide/")
  vim.fn.mkdir(lock_dir, "p")
  
  local lock_file = lock_dir .. "neovim_" .. vim.fn.getpid() .. ".lock"
  local lock_data = {
    pid = vim.fn.getpid(),
    port = port,
    ideName = "Neovim",
    transport = "ws",
    authToken = M.auth_token,  -- Use the same auth token
    workspaceFolders = { vim.fn.getcwd() },
    runningInWindows = vim.fn.has("win32") == 1
  }
  
  local file = io.open(lock_file, "w")
  if file then
    file:write(vim.json.encode(lock_data))
    file:close()
    vim.g.claude_mcp_lock_file = lock_file
    vim.notify("Created lock file: " .. lock_file, vim.log.levels.DEBUG)
  end
end

-- Remove lock file on exit
function M.remove_lock_file()
  if vim.g.claude_mcp_lock_file then
    vim.fn.delete(vim.g.claude_mcp_lock_file)
    vim.g.claude_mcp_lock_file = nil
  end
end

-- Get server status
function M.status()
  return {
    running = server_job ~= nil,
    port = server_port,
    pid = server_job
  }
end

return M