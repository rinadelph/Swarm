-- Simple IPC test

vim.notify("Starting simple IPC test", vim.log.levels.INFO)

-- Test file writing first
local log_file = "/tmp/nvim_ipc_test.log"
local file = io.open(log_file, "w")
if file then
  file:write("Test log created at " .. os.date() .. "\n")
  file:close()
  vim.notify("Log file created: " .. log_file, vim.log.levels.INFO)
else
  vim.notify("Failed to create log file!", vim.log.levels.ERROR)
  return
end

-- Now test the IPC
local tools = require('nvim-gemini-ccide.tools')

local job_id = vim.fn.jobstart({
  "python3", "/home/alejandro/VPS/CCIde/nvim-gemini-ccide/test_ipc_server.py"
}, {
  on_stdout = function(_, data, _)
    local file = io.open(log_file, "a")
    if file then
      for _, line in ipairs(data) do
        if line ~= "" then
          file:write("STDOUT: " .. line .. "\n")
          
          -- Handle NVIM_REQUEST
          if line:match("^NVIM_REQUEST:") then
            local json_str = line:sub(14)
            file:write("Got request: " .. json_str .. "\n")
            
            local ok, request = pcall(vim.json.decode, json_str)
            if ok and request then
              -- Call tool handler
              local handler = tools.get_handler(request.tool)
              if handler then
                local result = handler(request.args or {})
                local response = vim.json.encode({
                  id = request.id,
                  result = result
                })
                file:write("Sending response: " .. response .. "\n")
                vim.fn.chansend(job_id, response .. "\n")
              end
            end
          end
        end
      end
      file:close()
    end
  end,
  on_stderr = function(_, data, _)
    local file = io.open(log_file, "a")
    if file then
      for _, line in ipairs(data) do
        if line ~= "" then
          file:write("STDERR: " .. line .. "\n")
        end
      end
      file:close()
    end
  end,
  on_exit = function(_, code, _)
    local file = io.open(log_file, "a")
    if file then
      file:write("Process exited with code: " .. code .. "\n")
      file:close()
    end
  end,
  stdout_buffered = false,
  stderr_buffered = false,
})

if job_id > 0 then
  vim.notify("Test server started, job ID: " .. job_id, vim.log.levels.INFO)
  
  -- Open test file and select text
  vim.cmd("edit /home/alejandro/VPS/CCIde/nvim-gemini-ccide/test_file.txt")
  vim.cmd("normal! ggVG")
  
  -- Show log in new tmux window
  vim.fn.system("tmux new-window -n ipc_log 'tail -f " .. log_file .. "'")
else
  vim.notify("Failed to start test server!", vim.log.levels.ERROR)
end