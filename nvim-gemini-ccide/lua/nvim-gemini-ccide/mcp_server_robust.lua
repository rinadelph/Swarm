-- nvim-gemini-ccide/lua/nvim-gemini-ccide/mcp_server_robust.lua
-- MCP Server that Claude Code can connect to

local M = {}
local tools = require('nvim-gemini-ccide.tools') -- Import tools module

local server_job = nil
local server_port = nil
local auth_token = nil -- Store auth token here
local python_server_pid = nil -- Store the PID of the Python server
local tmux_session_name = "nvim_mcp_debug" -- Dedicated tmux session for logs
local log_file = "/tmp/nvim_mcp_debug.log" -- Persistent log file

-- Helper function to check if a process exists
local function process_exists(pid)
  if type(pid) ~= "number" then return false end
  -- Use kill -0 to check if process exists without sending a signal
  -- This is a common Unix-like way to check process existence
  return os.execute("kill -0 " .. pid .. " 2>/dev/null") == 0
end

-- Function to clean up stale lock files
local function cleanup_stale_lock_files()
  local lock_dir = vim.fn.expand("~/.claude/ide/")
  -- Glob for all .lock files, then filter for Neovim ones
  local all_lock_files = vim.fn.glob(lock_dir .. "*.lock", false, true)
  
  if #all_lock_files == 0 then
    return
  end

  vim.notify("MCP Server: Cleaning up stale Neovim lock files...", vim.log.levels.INFO)
  for _, lock_file in ipairs(all_lock_files) do
    local content = vim.fn.readfile(lock_file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content, "\n"))
      if ok and data and data.pid and data.ideName == "Neovim" then -- Check if it's our Neovim lock file
        if not process_exists(data.pid) then
          vim.fn.delete(lock_file)
          vim.notify("MCP Server: Deleted stale Neovim lock file: " .. lock_file .. " (PID: " .. data.pid .. ")", vim.log.levels.INFO)
        else
        end
      elseif ok and data and data.ideName ~= "Neovim" then
      else
        -- Malformed or missing PID/ideName, or empty file, delete it if it's not a known VS Code pattern
        local filename = vim.fn.fnamemodify(lock_file, ":t")
        -- Simple check to avoid deleting VS Code's PID-named lock files if they don't have ideName
        if not filename:match("^%d+%.lock$") then -- If it's not just a number.lock (like VS Code's)
          vim.fn.delete(lock_file)
          vim.notify("MCP Server: Deleted malformed/empty/unknown lock file: " .. lock_file, vim.log.levels.WARN)
        else
        end
      end
    else
      -- Empty file, delete it
      vim.fn.delete(lock_file)
      vim.notify("MCP Server: Deleted empty lock file: " .. lock_file, vim.log.levels.WARN)
    end
  end
end

-- Start the MCP server
function M.start(port)
  if server_job then
    vim.notify("MCP server already running on port " .. server_port, vim.log.levels.WARN)
    return server_port
  end
  
  cleanup_stale_lock_files() -- Perform cleanup before starting new server
  
  -- Kill any existing MCP server processes
  vim.fn.system("pkill -f mcp_server_robust.py 2>/dev/null || true")
  vim.wait(100) -- Wait a bit for processes to die

  -- Always use dynamic port (0 means let the system choose)
  port = 0
  
  -- Generate auth token (UUID-like)
  auth_token = string.format("nvim-%d-%d-%d", 
    os.time(), 
    vim.fn.getpid(), 
    math.random(10000, 99999)
  )
  
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
  local server_script = plugin_dir .. "/mcp_server_robust.py" -- Use the robust server
  
  -- Check if server script exists
  if vim.fn.filereadable(server_script) == 0 then
    vim.notify("MCP Server: Python script not found at " .. server_script, vim.log.levels.ERROR)
    return nil
  end

  -- Clear previous log file content
  vim.fn.system("echo '=== MCP Debug Log ===' > " .. log_file) 
  
  -- Create tmux session for monitoring logs
  vim.fn.system("tmux kill-session -t nvim_mcp_debug 2>/dev/null || true")
  vim.fn.system(string.format("tmux new-session -d -s nvim_mcp_debug 'tail -f %s'", log_file))

  -- Start the Python MCP server with proper stdin/stdout handling
  -- stderr goes to log file, stdout/stdin for IPC
  server_job = vim.fn.jobstart({
    "python3", server_script, tostring(port), auth_token
  }, {
    stderr_buffered = false,
    stdout_buffered = false,
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          
          -- Parse server output
          if line:match("^PORT:") then
            server_port = tonumber(line:match("^PORT:(%d+)"))
            -- write_lock_file will be called after PID is received
            vim.notify("MCP server started on port " .. server_port, vim.log.levels.INFO)
            vim.notify("Auth token: " .. auth_token, vim.log.levels.INFO)
          elseif line:match("^AUTH:") then
            -- Auth token confirmation from server (optional, for debugging)
            local server_auth = line:match("^AUTH:(.+)")
          elseif line:match("^PID:") then
            python_server_pid = tonumber(line:match("^PID:(%d+)"))
            if server_port then -- Only write lock file if port is already known
              M.write_lock_file(server_port)
            end
          elseif line:match("^NVIM_REQUEST:") then
            -- Handle requests from Python server to Neovim
            local json_str = line:gsub("^NVIM_REQUEST:", "")
            local ok, request_data = pcall(vim.json.decode, json_str)
            if ok and request_data then
                local request_id = request_data.id
                local tool_name = request_data.tool
                local tool_args = request_data.args

                local handler = tools.get_handler(tool_name)
                local response = {}
                if handler then
                    local result = handler(tool_args)
                    response = {
                        id = request_id,
                        result = result
                    }
                else
                    -- Handle unknown tool
                    response = {
                        id = request_id,
                        error = {
                            code = -32601, -- Method not found
                            message = "Unknown tool: " .. tool_name
                        }
                    }
                end
                -- Send response back to Python server via stdin
                local response_json = vim.json.encode(response) .. "\n"
                vim.fn.chansend(server_job, response_json)
            else
                vim.notify("MCP Server: Invalid NVIM_REQUEST JSON: " .. json_str, vim.log.levels.ERROR)
            end
          else
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          -- Write stderr to log file
          local file = io.open(log_file, "a")
          if file then
            file:write(line .. "\n")
            file:close()
          end
          -- Also notify in Neovim for critical errors
          if line:match("ERROR") or line:match("Error") then
            vim.notify("MCP Server Error: " .. line, vim.log.levels.ERROR)
          end
        end
      end
    end,
    on_exit = function(_, code, _)
      server_job = nil
      server_port = nil
      python_server_pid = nil
      M.remove_lock_file()
      M.kill_tmux_session() -- Kill tmux session on exit
      vim.notify("MCP server stopped (exit code: " .. code .. ")", vim.log.levels.INFO)
    end
  })
  
  if server_job == 0 then
    vim.notify("Failed to start MCP server", vim.log.levels.ERROR)
    server_job = nil
    return nil
  end
  
  -- Wait a bit for server to start and report its port and PID
  vim.wait(2000, function() return server_port ~= nil and python_server_pid ~= nil end)
  
  -- Launch detached tmux session for logs
  vim.fn.system("tmux new-session -d -s " .. tmux_session_name .. " 'tail -f " .. log_file .. "'")
  vim.notify("MCP Server: Debug logs available in tmux session: " .. tmux_session_name, vim.log.levels.INFO)
  vim.notify("To attach: tmux attach -t " .. tmux_session_name, vim.log.levels.INFO)
  
  return server_port
end

-- Stop the MCP server
function M.stop()
  if server_job then
    vim.fn.jobstop(server_job)
    server_job = nil
    server_port = nil
    python_server_pid = nil
    M.kill_tmux_session() -- Kill tmux session on stop
  end
end

-- Kill the dedicated tmux session
function M.kill_tmux_session()
  vim.fn.system("tmux kill-session -t " .. tmux_session_name .. " 2>/dev/null || true")
end

-- Write lock file for Claude to find us
function M.write_lock_file(port)
  local lock_dir = vim.fn.expand("~/.claude/ide/")
  vim.fn.mkdir(lock_dir, "p")
  
  -- The lock file name is just the port number
  local lock_file = lock_dir .. port .. ".lock"
  local lock_data = {
    pid = python_server_pid or vim.fn.getpid(), -- Use Python PID if available, else Neovim PID
    port = port,
    ideName = "Neovim",
    transport = "ws",
    authToken = auth_token,  -- Use the generated auth token
    workspaceFolders = { vim.fn.getcwd() },
    runningInWindows = vim.fn.has("win32") == 1
  }
  
  local file = io.open(lock_file, "w")
  if file then
    file:write(vim.json.encode(lock_data))
    file:close()
    vim.g.claude_mcp_lock_file = lock_file
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
    pid = python_server_pid or server_job -- Report Python PID if available
  }
end

return M