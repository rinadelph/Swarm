-- Test script to understand Neovim IPC with jobstart
-- This demonstrates bidirectional communication with a Python process

-- Simple Python echo server for testing
local python_script = [[
import sys
import json

print("PYTHON: Starting echo server", file=sys.stderr)
sys.stderr.flush()

while True:
    line = sys.stdin.readline()
    if not line:
        break
    
    try:
        data = json.loads(line.strip())
        print(f"PYTHON: Received: {data}", file=sys.stderr)
        
        # Echo back with a response
        response = {
            "type": "response",
            "original": data,
            "echo": f"Echo: {data.get('message', 'no message')}"
        }
        
        print(json.dumps(response))
        sys.stdout.flush()
        
    except Exception as e:
        print(f"PYTHON: Error: {e}", file=sys.stderr)
        sys.stderr.flush()
]]

-- Write the Python script to a temp file
local script_path = "/tmp/test_echo.py"
local file = io.open(script_path, "w")
file:write(python_script)
file:close()

-- Start the Python process
local job_id
local received_data = {}

job_id = vim.fn.jobstart({"python3", script_path}, {
    on_stdout = function(_, data, _)
        print("Neovim: Received from Python stdout:")
        for _, line in ipairs(data) do
            if line ~= "" then
                print("  > " .. line)
                table.insert(received_data, line)
            end
        end
    end,
    on_stderr = function(_, data, _)
        print("Neovim: Python stderr:")
        for _, line in ipairs(data) do
            if line ~= "" then
                print("  [ERR] " .. line)
            end
        end
    end,
    on_exit = function(_, code, _)
        print("Neovim: Python process exited with code: " .. code)
    end,
    stdout_buffered = true,
    stderr_buffered = true,
})

-- Send some test messages
vim.defer_fn(function()
    print("\nNeovim: Sending test message 1...")
    local msg1 = vim.json.encode({message = "Hello from Neovim!"})
    vim.fn.chansend(job_id, msg1 .. "\n")
end, 500)

vim.defer_fn(function()
    print("\nNeovim: Sending test message 2...")
    local msg2 = vim.json.encode({message = "Second message", data = {1, 2, 3}})
    vim.fn.chansend(job_id, msg2 .. "\n")
end, 1000)

-- Check results after 2 seconds
vim.defer_fn(function()
    print("\nNeovim: Final results:")
    print("Received " .. #received_data .. " responses")
    for i, data in ipairs(received_data) do
        print(i .. ": " .. data)
    end
    
    -- Clean up
    vim.fn.jobstop(job_id)
    os.remove(script_path)
end, 2000)

print("Neovim: Test started with job ID: " .. job_id)