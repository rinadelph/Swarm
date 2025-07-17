-- Diagnostic script for MCP server
-- Run this in Neovim to see what's happening

local mcp_server = require('nvim-gemini-ccide.mcp_server_robust')

print("=== MCP Server Diagnostics ===")

-- Get current status
local status = mcp_server.status()
print("Server running: " .. tostring(status.running))
print("Server port: " .. tostring(status.port))
print("Server PID: " .. tostring(status.pid))

-- Check if we can see the job
if status.running then
  print("\n=== Testing direct communication ===")
  
  -- Try to send a message directly
  local job_id = vim.g.mcp_server_job_id
  if job_id then
    print("Job ID: " .. job_id)
    
    -- Check if job is valid
    local job_info = vim.fn.jobpid(job_id)
    print("Job PID: " .. tostring(job_info))
    
    -- Try sending a test message
    local test_msg = vim.json.encode({test = "direct_message"}) .. "\n"
    local send_result = vim.fn.chansend(job_id, test_msg)
    print("Send result: " .. tostring(send_result))
  else
    print("No job ID found in vim.g.mcp_server_job_id")
  end
end

-- Check the log file
print("\n=== Recent log entries ===")
local log_file = "/tmp/nvim_mcp_debug.log"
local log_lines = vim.fn.readfile(log_file)
if #log_lines > 0 then
  local start = math.max(1, #log_lines - 10)
  for i = start, #log_lines do
    print(log_lines[i])
  end
else
  print("Log file is empty")
end

-- Check for Python process
print("\n=== Python process check ===")
local ps_output = vim.fn.system("ps aux | grep mcp_server_robust | grep -v grep")
print(ps_output)

-- Manually test a tool
print("\n=== Manual tool test ===")
local tools = require('nvim-gemini-ccide.tools')
local handler = tools.get_handler('getCurrentSelection')
if handler then
  local result = handler({})
  print("getCurrentSelection result:")
  print(vim.inspect(result))
end