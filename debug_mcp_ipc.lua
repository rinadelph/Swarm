-- Debug script to test MCP server IPC
-- This simulates what should happen when the MCP server communicates with Neovim

local tools = require('nvim-gemini-ccide.tools')

-- Test Python MCP bridge (simplified)
local python_bridge = [[
import sys
import json
import uuid

print("[BRIDGE] Starting MCP-Neovim bridge", file=sys.stderr)

# Simulate receiving a tool request from MCP
tool_request = {
    "id": str(uuid.uuid4()),
    "tool": "getCurrentSelection",
    "args": {}
}

print(f"NVIM_REQUEST:{json.dumps(tool_request)}")
sys.stdout.flush()

# Wait for response from Neovim
print("[BRIDGE] Waiting for Neovim response...", file=sys.stderr)
response_line = sys.stdin.readline()

if response_line:
    print(f"[BRIDGE] Got response: {response_line.strip()}", file=sys.stderr)
else:
    print("[BRIDGE] No response received", file=sys.stderr)
]]

-- Write test script
local script_path = "/tmp/test_mcp_bridge.py"
local file = io.open(script_path, "w")
file:write(python_bridge)
file:close()

-- Start the bridge
local job_id
local pending_requests = {}

job_id = vim.fn.jobstart({"python3", script_path}, {
    on_stdout = function(_, data, _)
        for _, line in ipairs(data) do
            if line ~= "" then
                print("NVIM: Received: " .. line)
                
                -- Handle NVIM_REQUEST
                if line:match("^NVIM_REQUEST:") then
                    local json_str = line:gsub("^NVIM_REQUEST:", "")
                    local ok, request = pcall(vim.json.decode, json_str)
                    
                    if ok and request then
                        print("NVIM: Processing tool: " .. request.tool)
                        
                        -- Get the tool handler
                        local handler = tools.get_handler(request.tool)
                        if handler then
                            local result = handler(request.args or {})
                            local response = {
                                id = request.id,
                                result = result
                            }
                            
                            -- Send response back
                            local response_json = vim.json.encode(response) .. "\n"
                            print("NVIM: Sending response: " .. response_json:gsub("\n", ""))
                            vim.fn.chansend(job_id, response_json)
                        else
                            print("NVIM: Unknown tool: " .. request.tool)
                        end
                    end
                end
            end
        end
    end,
    on_stderr = function(_, data, _)
        for _, line in ipairs(data) do
            if line ~= "" then
                print("NVIM: [Python] " .. line)
            end
        end
    end,
    on_exit = function(_, code, _)
        print("NVIM: Bridge exited with code: " .. code)
    end,
})

-- Clean up after 2 seconds
vim.defer_fn(function()
    vim.fn.jobstop(job_id)
    os.remove(script_path)
    print("\nNVIM: Test completed")
end, 2000)

print("NVIM: Started MCP bridge test with job ID: " .. job_id)