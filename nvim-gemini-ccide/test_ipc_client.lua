-- Test IPC client for Neovim
-- This script starts the test server and handles tool requests

local tools = require('nvim-gemini-ccide.tools')

-- Log file for test output
local log_file = "/tmp/nvim_ipc_test.log"

local function log(msg)
  local file = io.open(log_file, "a")
  if file then
    file:write(os.date("[%H:%M:%S] ") .. msg .. "\n")
    file:close()
  end
end

local function start_test_server()
  -- Clear log file
  vim.fn.system("echo '=== IPC Test Log ===' > " .. log_file)
  log("Starting test IPC server...")
  
  local server_script = "/home/alejandro/VPS/CCIde/nvim-gemini-ccide/test_ipc_server.py"
  
  local job_id = vim.fn.jobstart({
    "python3", server_script
  }, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          log("STDOUT: " .. line)
          
          -- Handle NVIM_REQUEST messages
          if line:match("^NVIM_REQUEST:") then
            local json_str = line:sub(14)
            log("Received request: " .. json_str)
            
            local ok, request_data = pcall(vim.json.decode, json_str)
            if ok and request_data then
              local request_id = request_data.id
              local tool_name = request_data.tool
              local tool_args = request_data.args
              
              log("Processing tool: " .. tool_name .. " (ID: " .. request_id .. ")")
              
              -- Get tool handler
              local handler = tools.get_handler(tool_name)
              local response = {}
              
              if handler then
                local result = handler(tool_args)
                response = {
                  id = request_id,
                  result = result
                }
                log("Tool result: " .. vim.inspect(result))
              else
                response = {
                  id = request_id,
                  error = {
                    code = -32601,
                    message = "Unknown tool: " .. tool_name
                  }
                }
                log("Unknown tool: " .. tool_name)
              end
              
              -- Send response back
              local response_json = vim.json.encode(response) .. "\n"
              log("Sending response: " .. response_json:sub(1, 100) .. "...")
              local bytes_sent = vim.fn.chansend(job_id, response_json)
              log("Sent " .. bytes_sent .. " bytes")
            else
              log("Failed to parse request: " .. json_str)
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
    on_exit = function(_, exit_code, _)
      log("Test server exited with code: " .. exit_code)
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
  
  if job_id <= 0 then
    log("Failed to start test server!")
    return nil
  end
  
  log("Test server started with job ID: " .. job_id)
  return job_id
end

-- Run the test
local job_id = start_test_server()

if job_id then
  -- Open a test file and make a selection for testing
  vim.cmd("edit test_file.txt")
  vim.cmd("normal! ggVG")  -- Select all
  
  log("Test setup complete. Waiting for tool requests...")
  
  -- Notify user
  vim.notify("IPC test running. Check log: " .. log_file, vim.log.levels.INFO)
  
  -- Open log in tmux for monitoring
  vim.fn.system("tmux new-window -n ipc_log 'tail -f " .. log_file .. "'")
end