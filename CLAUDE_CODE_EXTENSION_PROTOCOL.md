# Claude Code VS Code Extension Protocol Documentation

## Overview

This document provides a complete technical specification for the Claude Code VS Code extension's communication protocol, discovered through reverse-engineering. This information enables integration with other editors like Neovim, Emacs, or custom applications.

## Architecture

The Claude Code VS Code extension implements a WebSocket server that communicates with the Claude CLI using JSON-RPC 2.0 protocol. The extension acts as a bridge between Claude and the VS Code editor, providing programmatic access to editor functionality.

## Communication Protocol

### WebSocket Server

- **Protocol**: WebSocket (ws://)
- **Host**: localhost (127.0.0.1)
- **Port**: Dynamically assigned (not fixed to 40145)
- **Authentication**: Required via HTTP header

### Authentication

The WebSocket connection requires authentication using a custom header:

```
x-claude-code-ide-authorization: <auth-token>
```

The auth token is generated when the extension starts and stored in the lock file.

### Message Format

All communication uses JSON-RPC 2.0 protocol:

```json
{
  "jsonrpc": "2.0",
  "method": "tools/list",
  "params": {},
  "id": 1
}
```

## Lock File Mechanism

The extension creates a lock file that contains connection details for clients to discover the server.

### Location

Lock files are stored in: `~/.claude/ide/`

### Naming Convention

Lock files are named using the VS Code process PID: `<pid>.lock`

Example: `367494.lock`

### Lock File Format

```json
{
  "pid": 367494,
  "workspaceFolders": ["/home/alejandro/Code/MCP/Agent-MCP"],
  "ideName": "Visual Studio Code",
  "transport": "ws",
  "runningInWindows": false,
  "authToken": "35b20821-2914-48d4-9998-1bbc66e2c5a2",
  "port": 40145
}
```

**Note**: The port number may not be included in all versions. If missing, clients need to scan for the WebSocket server or use other discovery methods.

## Available Tools/Methods

The following methods are exposed by the extension:

### File Operations

1. **openFile**
   - Opens a file in the editor
   - Parameters: file path

2. **openDiff**
   - Opens a diff view between two files
   - Parameters: original and modified file paths

3. **close_tab**
   - Closes a specific editor tab
   - Parameters: tab identifier

4. **closeAllDiffTabs**
   - Closes all diff view tabs
   - No parameters

5. **saveDocument**
   - Saves the current document
   - Parameters: document URI

### Editor State

6. **getOpenEditors**
   - Returns list of currently open editors
   - No parameters

7. **getCurrentSelection**
   - Gets the currently selected text
   - No parameters

8. **getLatestSelection**
   - Gets the most recent text selection
   - No parameters

### Workspace Information

9. **getWorkspaceFolders**
   - Returns list of workspace folders
   - No parameters

10. **getDiagnostics**
    - Gets diagnostic information (errors, warnings)
    - Parameters: optional file filter

11. **checkDocumentDirty**
    - Checks if a document has unsaved changes
    - Parameters: document URI

### Code Execution

12. **executeCode**
    - Executes code in the integrated terminal
    - Parameters: code to execute

## Implementation Guide

### 1. Client Connection Flow

```python
import websocket
import json
import glob
import time

# 1. Find lock file
lock_files = glob.glob(os.path.expanduser("~/.claude/ide/*.lock"))
if not lock_files:
    raise Exception("No Claude Code extension running")

# 2. Parse lock file
with open(lock_files[0], 'r') as f:
    lock_data = json.load(f)

port = lock_data.get('port', 40145)  # Default if not specified
auth_token = lock_data['authToken']

# 3. Connect with authentication
headers = {
    "x-claude-code-ide-authorization": auth_token
}
ws = websocket.WebSocket()
ws.connect(f"ws://127.0.0.1:{port}", header=headers)

# 4. Wait for server initialization (important!)
time.sleep(1)

# 5. Send JSON-RPC request
request = {
    "jsonrpc": "2.0",
    "method": "tools/list",
    "params": {},
    "id": 1
}
ws.send(json.dumps(request))

# 6. Receive response
response = json.loads(ws.recv())
```

### 2. Important Implementation Notes

1. **Race Condition**: There's a race condition when connecting immediately after the extension starts. Add a 1-second delay before sending requests.

2. **Port Discovery**: If the port isn't in the lock file, you may need to:
   - Scan common port ranges
   - Use the VS Code process PID to find listening ports
   - Parse VS Code logs

3. **Error Handling**: The server will close connections with code 1008 for unauthorized requests.

4. **Persistence**: The lock file is deleted when VS Code closes, so check for its existence before connecting.

## Neovim Integration Example

```lua
local M = {}
local json = require('json')

function M.find_claude_server()
    local lock_files = vim.fn.glob("~/.claude/ide/*.lock", false, true)
    if #lock_files == 0 then
        error("No Claude Code extension found")
    end
    
    local lock_content = vim.fn.readfile(lock_files[1])
    local lock_data = json.decode(table.concat(lock_content, '\n'))
    
    return {
        port = lock_data.port or 40145,
        auth_token = lock_data.authToken
    }
end

function M.send_request(method, params)
    local server = M.find_claude_server()
    
    -- Use vim's jobstart or external process to handle WebSocket
    -- This is a simplified example
    local request = {
        jsonrpc = "2.0",
        method = method,
        params = params or {},
        id = vim.fn.localtime()
    }
    
    -- Actual WebSocket implementation would go here
    -- Could use:
    -- - External Python/Node.js helper script
    -- - Neovim's built-in LSP client (adapted for WebSocket)
    -- - Third-party Lua WebSocket library
end

-- Example usage
function M.get_open_files()
    return M.send_request("getOpenEditors")
end

function M.open_file(filepath)
    return M.send_request("openFile", {path = filepath})
end

return M
```

## Security Considerations

1. **Local Only**: The WebSocket server only listens on localhost
2. **Auth Token**: Generated per session, stored in user-only readable directory
3. **No Encryption**: Communication is not encrypted (ws:// not wss://)

## Troubleshooting

### Common Issues

1. **"Method not found" error**: Add delay after connecting before sending requests
2. **Connection refused**: Check if VS Code and extension are running
3. **Unauthorized**: Verify auth token from lock file is correct
4. **No lock file**: Extension may not be activated - open a file in VS Code first

### Debugging Tips

1. Check VS Code Extension Host logs: `~/.config/Code/logs/`
2. Use Chrome DevTools to inspect WebSocket traffic
3. Monitor lock file creation: `watch -n 1 'ls -la ~/.claude/ide/'`

## Future Considerations

1. The protocol may change in future versions
2. Additional methods may be added
3. Authentication mechanism might be enhanced
4. Port discovery could be improved

---

*This documentation is based on reverse-engineering version 1.0.51 of the Claude Code VS Code extension. The protocol is subject to change in future versions.*