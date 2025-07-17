-- nvim-gemini-ccide/lua/nvim-gemini-ccide/client.lua

local utils = require('nvim-gemini-ccide.utils')
local tools = require('nvim-gemini-ccide.tools')

local M = {}

-- State
local bridge_job = nil
local connection_details = nil
local connected = false
local request_id = 0
local pending_requests = {}

-- Send data to the WebSocket bridge
local function send_to_bridge(data)
  if bridge_job then
    vim.fn.chansend(bridge_job, vim.json.encode(data) .. "\n")
  end
end

-- Send JSON-RPC request through the bridge
local function send_request(method, params, callback)
  request_id = request_id + 1
  local request = {
    jsonrpc = "2.0",
    method = method,
    params = params or {},
    id = request_id
  }
  
  if callback then
    pending_requests[request_id] = callback
  end
  
  send_to_bridge({
    type = "send",
    data = vim.json.encode(request)
  })
  
  return request_id
end

-- Handle messages from the WebSocket bridge
local function handle_bridge_message(data)
  local ok, msg = pcall(vim.json.decode, data)
  if not ok then return end
  
  if msg.type == "connected" then
    connected = true
    vim.notify("Claude Code: " .. msg.message, vim.log.levels.INFO)
    
    -- Wait a bit for server initialization (race condition)
    vim.defer_fn(function()
      -- Request the list of tools upon connection
      send_request("tools/list", {}, function(response)
        if response.result and response.result.tools then
          vim.notify("Claude Code: Retrieved " .. #response.result.tools .. " tools", vim.log.levels.INFO)
          tools.register(response.result.tools)
        end
      end)
    end, 1000)
    
  elseif msg.type == "message" then
    -- Parse the actual Claude Code message
    local ok2, claude_msg = pcall(vim.json.decode, msg.data)
    if ok2 then
      -- Handle response to our request
      if claude_msg.id and pending_requests[claude_msg.id] then
        local callback = pending_requests[claude_msg.id]
        pending_requests[claude_msg.id] = nil
        callback(claude_msg)
      
      -- Handle request from Claude Code (if any)
      elseif claude_msg.method then
        local handler = tools.get_handler(claude_msg.method)
        if handler then
          vim.defer_fn(function()
            local result = handler(claude_msg.params)
            if connected and claude_msg.id then
              local response = {
                jsonrpc = "2.0",
                id = claude_msg.id,
                result = result
              }
              send_to_bridge({
                type = "send",
                data = vim.json.encode(response)
              })
            end
          end, 0)
        end
      end
    end
    
  elseif msg.type == "error" then
    vim.notify("Claude Code Error: " .. msg.message, vim.log.levels.ERROR)
    
  elseif msg.type == "closed" then
    connected = false
    vim.notify("Claude Code: " .. msg.message, vim.log.levels.WARN)
  end
end

function M.connect()
  if bridge_job then
    vim.notify("Claude Code: Already connected", vim.log.levels.WARN)
    return
  end
  
  connection_details = utils.get_connection_details()
  if not connection_details then
    return
  end
  
  -- Find the bridge script
  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
  local bridge_script = plugin_dir .. "/websocket_bridge.py"
  
  -- Check if bridge script exists
  if vim.fn.filereadable(bridge_script) == 0 then
    vim.notify("Claude Code: WebSocket bridge not found at " .. bridge_script, vim.log.levels.ERROR)
    return
  end
  
  -- Start the WebSocket bridge
  bridge_job = vim.fn.jobstart({
    "python3", bridge_script,
    tostring(connection_details.port),
    connection_details.authToken
  }, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          handle_bridge_message(line)
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          vim.notify("Claude Code Bridge Error: " .. line, vim.log.levels.ERROR)
        end
      end
    end,
    on_exit = function(_, code, _)
      bridge_job = nil
      connected = false
      pending_requests = {}
      vim.notify("Claude Code: Bridge process exited with code " .. code, vim.log.levels.INFO)
    end
  })
  
  if bridge_job == 0 then
    vim.notify("Claude Code: Failed to start WebSocket bridge", vim.log.levels.ERROR)
    bridge_job = nil
  else
    vim.notify("Claude Code: Starting WebSocket bridge...", vim.log.levels.INFO)
  end
end

function M.disconnect()
  if bridge_job then
    send_to_bridge({ type = "close" })
    vim.fn.jobstop(bridge_job)
    bridge_job = nil
    connected = false
    pending_requests = {}
  end
end

function M.is_connected()
  return connected
end

-- Public API for calling tools
function M.call_tool(tool_name, args, callback)
  if not connected then
    vim.notify("Claude Code: Not connected", vim.log.levels.ERROR)
    return nil
  end
  
  return send_request("tools/call", {
    name = tool_name,
    arguments = args or {}
  }, callback)
end

-- Get list of available tools
function M.list_tools(callback)
  if not connected then
    vim.notify("Claude Code: Not connected", vim.log.levels.ERROR)
    return nil
  end
  
  return send_request("tools/list", {}, callback)
end

return M