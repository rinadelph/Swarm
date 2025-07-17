-- Test IPC timing issue
print("=== Testing IPC Timing ===")

-- Get the current MCP server job
local mcp_server = require('nvim-gemini-ccide.mcp_server_robust')
local status = mcp_server.status()

if not status.running then
  print("MCP server not running!")
  return
end

-- Create a simple test to send data through the channel
print("\nTesting direct channel communication...")

-- Get the server job ID (we need to expose this)
-- For now, let's test with a simple echo server

local test_job = vim.fn.jobstart({
  'python3', '-c', [[
import sys
import time

print("[TEST] Python started", file=sys.stderr)
sys.stderr.flush()

while True:
    line = sys.stdin.readline()
    if not line:
        break
    print(f"[TEST] Received: {line.strip()}", file=sys.stderr)
    sys.stderr.flush()
    
    # Echo back immediately
    sys.stdout.write(f"ECHO: {line}")
    sys.stdout.flush()
    print(f"[TEST] Sent response", file=sys.stderr)
    sys.stderr.flush()
]]
}, {
  on_stdout = function(_, data, _)
    for _, line in ipairs(data) do
      if line ~= "" then
        print("STDOUT: " .. line .. " (at " .. os.clock() .. ")")
      end
    end
  end,
  on_stderr = function(_, data, _)
    for _, line in ipairs(data) do
      if line ~= "" then
        print("STDERR: " .. line)
      end
    end
  end,
  stdout_buffered = false,
  stderr_buffered = false,
})

-- Send test message
vim.defer_fn(function()
  local start_time = os.clock()
  print("\nSending test message at " .. start_time)
  vim.fn.chansend(test_job, "Hello from Neovim\n")
end, 100)

-- Stop after 1 second
vim.defer_fn(function()
  vim.fn.jobstop(test_job)
  print("\nTest completed")
end, 1000)