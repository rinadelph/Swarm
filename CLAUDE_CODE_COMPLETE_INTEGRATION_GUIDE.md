# Claude Code Extension: Complete Integration Guide

This comprehensive guide combines reverse-engineering findings with practical implementation details for integrating Claude Code functionality into any editor or application.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Connection Protocol](#connection-protocol)
4. [Authentication](#authentication)
5. [Lock File Discovery](#lock-file-discovery)
6. [Available Tools - Complete Reference](#available-tools---complete-reference)
7. [Implementation Examples](#implementation-examples)
8. [Editor Integration Guides](#editor-integration-guides)
9. [Troubleshooting](#troubleshooting)
10. [Advanced Topics](#advanced-topics)

## Overview

The Claude Code VS Code extension exposes IDE functionality through a WebSocket server using JSON-RPC 2.0 protocol. This enables Claude (and any other client) to:

- View and edit files
- Manage diffs and code changes
- Access diagnostics and errors
- Execute code (including Jupyter notebooks)
- Interact with the editor UI
- Access workspace information

## Architecture

```
┌─────────────┐     WebSocket      ┌──────────────────┐
│   Claude    │ ◄─────────────────► │  VS Code Ext.    │
│   (or any   │     JSON-RPC 2.0    │  (MCP Server)    │
│   client)   │                     │  Port: Dynamic   │
└─────────────┘                     └──────────────────┘
       │                                     │
       └─────── Lock File ──────────────────┘
           (~/.claude/ide/<pid>.lock)
```

## Connection Protocol

### WebSocket Details

- **Protocol**: `ws://` (not encrypted)
- **Host**: `localhost` / `127.0.0.1`
- **Port**: Dynamically assigned (found in lock file)
- **Message Format**: JSON-RPC 2.0

### Message Structure

**Request:**
```json
{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "openFile",
        "arguments": {
            "filePath": "/path/to/file.js"
        }
    },
    "id": 1
}
```

**Response:**
```json
{
    "jsonrpc": "2.0",
    "result": {
        "content": [
            {
                "type": "text",
                "text": "File opened successfully"
            }
        ]
    },
    "id": 1
}
```

## Authentication

All WebSocket connections must include an authentication header:

```
x-claude-code-ide-authorization: <auth-token-from-lock-file>
```

Connections without valid authentication are immediately closed with code 1008.

## Lock File Discovery

### Location

- **Unix/Linux/macOS**: `~/.claude/ide/`
- **Windows**: `%USERPROFILE%\.claude\ide\`

### File Naming

Lock files are named using the VS Code process PID: `<pid>.lock`

### File Format

```json
{
    "pid": 367494,
    "workspaceFolders": ["/home/user/project"],
    "ideName": "Visual Studio Code",
    "transport": "ws",
    "runningInWindows": false,
    "authToken": "35b20821-2914-48d4-9998-1bbc66e2c5a2",
    "port": 40145
}
```

**Note**: Early versions stored only port in the filename (e.g., `40145.lock`). Always check file content.

## Available Tools - Complete Reference

### 1. `tools/list`
**Purpose**: Discover all available tools and their schemas
- **Parameters**: None
- **Returns**: List of all tools with their JSON schemas
- **Usage**: Should be the first call to discover available functionality

### 2. `openDiff`
**Purpose**: Opens a visual diff between two file versions
- **Parameters**:
  - `old_file_path`: Path to original file
  - `new_file_path`: Path to modified file
  - `new_file_contents`: Content of the modified version
  - `tab_name`: Name for the diff tab
- **Returns**: Promise that resolves when user accepts/rejects
- **VS Code Implementation**: Uses virtual file system and `vscode.diff` command

### 3. `getDiagnostics`
**Purpose**: Retrieves all diagnostic issues (errors, warnings, hints)
- **Parameters**:
  - `uri` (optional): Specific file URI to filter diagnostics
- **Returns**: Array of diagnostic objects with severity, range, message
- **VS Code Implementation**: Wraps `vscode.languages.getDiagnostics()`

### 4. `openFile`
**Purpose**: Opens a file and optionally selects text
- **Parameters**:
  - `filePath`: Path to the file
  - `preview` (optional): Open in preview mode
  - `startText` (optional): Text to find for selection start
  - `endText` (optional): Text to find for selection end
  - `selectToEndOfLine` (optional): Extend selection to line end
  - `makeFrontmost` (optional): Focus the editor
- **VS Code Implementation**: Uses `vscode.workspace.openTextDocument` and `vscode.window.showTextDocument`

### 5. `getOpenEditors`
**Purpose**: Returns list of all open editor tabs
- **Parameters**: None
- **Returns**: Array of open file paths with their tab groups
- **VS Code Implementation**: Iterates through `vscode.window.tabGroups.all`

### 6. `getCurrentSelection`
**Purpose**: Gets selected text from active editor
- **Parameters**: None
- **Returns**: Selected text and location information
- **VS Code Implementation**: Uses `vscode.window.activeTextEditor`

### 7. `getLatestSelection`
**Purpose**: Gets the most recent text selection
- **Parameters**: None
- **Returns**: Last selected text (cached)
- **Note**: Useful for retrieving selection after focus changes

### 8. `executeCode`
**Purpose**: Executes code in integrated terminal or Jupyter notebook
- **Parameters**:
  - `code`: Code string to execute
- **Special Requirements**: Jupyter extension for notebook execution
- **VS Code Implementation**: Depends on `ms-toolsai.jupyter` extension

### 9. `close_tab`
**Purpose**: Closes a specific editor tab
- **Parameters**:
  - `tab` identifier
- **Returns**: Success/failure status

### 10. `closeAllDiffTabs`
**Purpose**: Closes all diff view tabs
- **Parameters**: None
- **Returns**: Number of tabs closed

### 11. `getWorkspaceFolders`
**Purpose**: Returns all workspace folders
- **Parameters**: None
- **Returns**: Array of workspace folder paths
- **VS Code Implementation**: Returns `vscode.workspace.workspaceFolders`

### 12. `checkDocumentDirty`
**Purpose**: Checks if document has unsaved changes
- **Parameters**:
  - `uri`: Document URI
- **Returns**: Boolean indicating dirty state

### 13. `saveDocument`
**Purpose**: Saves the specified document
- **Parameters**:
  - `uri`: Document URI
- **Returns**: Success/failure status

## Implementation Examples

### Python Complete Client

```python
#!/usr/bin/env python3
import websocket
import json
import glob
import os
import time
import threading
from typing import Optional, Dict, Any

class ClaudeCodeClient:
    def __init__(self):
        self.ws = None
        self.request_id = 0
        self.responses = {}
        
    def connect(self) -> bool:
        """Connect to Claude Code extension"""
        lock_file = self._find_lock_file()
        if not lock_file:
            return False
            
        with open(lock_file, 'r') as f:
            lock_data = json.load(f)
            
        port = lock_data.get('port', 40145)
        auth_token = lock_data['authToken']
        
        self.ws = websocket.WebSocketApp(
            f"ws://127.0.0.1:{port}",
            header={"x-claude-code-ide-authorization": auth_token},
            on_message=self._on_message,
            on_error=self._on_error,
            on_close=self._on_close
        )
        
        # Start connection in thread
        wst = threading.Thread(target=self.ws.run_forever)
        wst.daemon = True
        wst.start()
        
        # Wait for connection
        time.sleep(1)
        return True
        
    def _find_lock_file(self) -> Optional[str]:
        """Find the Claude extension lock file"""
        lock_files = glob.glob(os.path.expanduser("~/.claude/ide/*.lock"))
        return lock_files[0] if lock_files else None
        
    def _on_message(self, ws, message):
        """Handle incoming messages"""
        data = json.loads(message)
        if 'id' in data:
            self.responses[data['id']] = data
            
    def _on_error(self, ws, error):
        print(f"Error: {error}")
        
    def _on_close(self, ws, close_status_code, close_msg):
        print("Connection closed")
        
    def call_tool(self, tool_name: str, arguments: Dict[str, Any] = None) -> Dict[str, Any]:
        """Call a tool and wait for response"""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments or {}
            },
            "id": self.request_id
        }
        
        self.ws.send(json.dumps(request))
        
        # Wait for response
        timeout = 5
        start = time.time()
        while self.request_id not in self.responses:
            if time.time() - start > timeout:
                raise TimeoutError(f"No response for request {self.request_id}")
            time.sleep(0.1)
            
        return self.responses.pop(self.request_id)
        
    def list_tools(self) -> list:
        """Get list of available tools"""
        self.request_id += 1
        request = {
            "jsonrpc": "2.0",
            "method": "tools/list",
            "params": {},
            "id": self.request_id
        }
        
        self.ws.send(json.dumps(request))
        
        # Wait for response
        timeout = 5
        start = time.time()
        while self.request_id not in self.responses:
            if time.time() - start > timeout:
                raise TimeoutError("No response for tools/list")
            time.sleep(0.1)
            
        response = self.responses.pop(self.request_id)
        return response.get('result', {}).get('tools', [])

# Usage example
if __name__ == "__main__":
    client = ClaudeCodeClient()
    
    if client.connect():
        print("Connected to Claude Code extension")
        
        # List available tools
        tools = client.list_tools()
        print(f"\nAvailable tools: {len(tools)}")
        for tool in tools:
            print(f"  - {tool['name']}")
            
        # Open a file
        result = client.call_tool("openFile", {
            "filePath": "/path/to/your/file.py"
        })
        print(f"\nOpen file result: {result}")
        
        # Get diagnostics
        result = client.call_tool("getDiagnostics")
        print(f"\nDiagnostics: {result}")
```

### JavaScript/TypeScript Client

```typescript
import WebSocket from 'ws';
import { promises as fs } from 'fs';
import { glob } from 'glob';
import path from 'path';
import os from 'os';

interface LockFile {
    pid: number;
    workspaceFolders: string[];
    ideName: string;
    transport: string;
    runningInWindows: boolean;
    authToken: string;
    port?: number;
}

class ClaudeCodeClient {
    private ws: WebSocket | null = null;
    private requestId = 0;
    private pendingRequests = new Map<number, {
        resolve: (value: any) => void;
        reject: (reason: any) => void;
    }>();

    async connect(): Promise<boolean> {
        const lockFile = await this.findLockFile();
        if (!lockFile) {
            console.error('No Claude Code extension running');
            return false;
        }

        const lockData: LockFile = JSON.parse(
            await fs.readFile(lockFile, 'utf-8')
        );

        const port = lockData.port || 40145;
        const authToken = lockData.authToken;

        return new Promise((resolve) => {
            this.ws = new WebSocket(`ws://127.0.0.1:${port}`, {
                headers: {
                    'x-claude-code-ide-authorization': authToken
                }
            });

            this.ws.on('open', () => {
                console.log('Connected to Claude Code extension');
                // Wait for server initialization
                setTimeout(() => resolve(true), 1000);
            });

            this.ws.on('message', (data) => {
                const message = JSON.parse(data.toString());
                if (message.id && this.pendingRequests.has(message.id)) {
                    const { resolve } = this.pendingRequests.get(message.id)!;
                    this.pendingRequests.delete(message.id);
                    resolve(message);
                }
            });

            this.ws.on('error', (error) => {
                console.error('WebSocket error:', error);
                resolve(false);
            });
        });
    }

    private async findLockFile(): Promise<string | null> {
        const lockFiles = await glob(
            path.join(os.homedir(), '.claude/ide/*.lock')
        );
        return lockFiles[0] || null;
    }

    async callTool(toolName: string, args: any = {}): Promise<any> {
        if (!this.ws) throw new Error('Not connected');

        const id = ++this.requestId;
        const request = {
            jsonrpc: '2.0',
            method: 'tools/call',
            params: {
                name: toolName,
                arguments: args
            },
            id
        };

        return new Promise((resolve, reject) => {
            this.pendingRequests.set(id, { resolve, reject });
            this.ws!.send(JSON.stringify(request));

            // Timeout after 5 seconds
            setTimeout(() => {
                if (this.pendingRequests.has(id)) {
                    this.pendingRequests.delete(id);
                    reject(new Error('Request timeout'));
                }
            }, 5000);
        });
    }
}
```

## Editor Integration Guides

### Neovim Integration

```lua
-- claude-code.nvim - Neovim client for Claude Code extension
local M = {}
local uv = vim.loop
local json = vim.json

-- State
local state = {
    connected = false,
    ws = nil,
    request_id = 0,
    pending_requests = {}
}

-- Find lock file
function M.find_lock_file()
    local home = os.getenv("HOME")
    local lock_dir = home .. "/.claude/ide/"
    local handle = uv.fs_scandir(lock_dir)
    
    if not handle then
        return nil
    end
    
    while true do
        local name, type = uv.fs_scandir_next(handle)
        if not name then break end
        
        if type == "file" and name:match("%.lock$") then
            return lock_dir .. name
        end
    end
    
    return nil
end

-- Read lock file
function M.read_lock_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    
    local content = file:read("*all")
    file:close()
    
    return json.decode(content)
end

-- Connect to Claude Code extension
function M.connect()
    local lock_file = M.find_lock_file()
    if not lock_file then
        vim.notify("No Claude Code extension found", vim.log.levels.ERROR)
        return false
    end
    
    local lock_data = M.read_lock_file(lock_file)
    if not lock_data then
        vim.notify("Failed to read lock file", vim.log.levels.ERROR)
        return false
    end
    
    local port = lock_data.port or 40145
    local auth_token = lock_data.authToken
    
    -- Create WebSocket connection using external helper
    -- (Neovim doesn't have native WebSocket support)
    local cmd = string.format(
        "python3 -c 'import claude_ws_bridge; claude_ws_bridge.start(%d, \"%s\")'",
        port, auth_token
    )
    
    -- Start the bridge process
    state.job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            M.handle_message(table.concat(data, "\n"))
        end,
        on_exit = function(_, code, _)
            state.connected = false
            vim.notify("Claude Code connection closed", vim.log.levels.INFO)
        end
    })
    
    state.connected = true
    vim.notify("Connected to Claude Code", vim.log.levels.INFO)
    
    -- Wait for initialization
    vim.wait(1000)
    
    return true
end

-- Send request
function M.call_tool(tool_name, args, callback)
    if not state.connected then
        vim.notify("Not connected to Claude Code", vim.log.levels.ERROR)
        return
    end
    
    state.request_id = state.request_id + 1
    local request = {
        jsonrpc = "2.0",
        method = "tools/call",
        params = {
            name = tool_name,
            arguments = args or {}
        },
        id = state.request_id
    }
    
    state.pending_requests[state.request_id] = callback
    
    -- Send via job channel
    vim.fn.chansend(state.job_id, json.encode(request) .. "\n")
end

-- Handle incoming messages
function M.handle_message(data)
    local ok, message = pcall(json.decode, data)
    if not ok then return end
    
    if message.id and state.pending_requests[message.id] then
        local callback = state.pending_requests[message.id]
        state.pending_requests[message.id] = nil
        
        if callback then
            callback(message)
        end
    end
end

-- Neovim commands
function M.setup()
    -- Create commands
    vim.api.nvim_create_user_command("ClaudeConnect", function()
        M.connect()
    end, {})
    
    vim.api.nvim_create_user_command("ClaudeOpenFile", function(opts)
        M.call_tool("openFile", {
            filePath = opts.args
        }, function(response)
            vim.notify("File opened in VS Code")
        end)
    end, { nargs = 1, complete = "file" })
    
    vim.api.nvim_create_user_command("ClaudeGetDiagnostics", function()
        M.call_tool("getDiagnostics", {}, function(response)
            -- Parse and display diagnostics
            if response.result and response.result.content then
                local content = response.result.content[1].text
                local diagnostics = json.decode(content)
                
                -- Convert to Neovim diagnostics
                for _, diag in ipairs(diagnostics) do
                    vim.notify(string.format(
                        "%s: %s", 
                        diag.severity, 
                        diag.message
                    ))
                end
            end
        end)
    end, {})
    
    -- Key mappings
    vim.keymap.set("n", "<leader>cc", ":ClaudeConnect<CR>", 
        { desc = "Connect to Claude Code" })
    vim.keymap.set("n", "<leader>co", ":ClaudeOpenFile ", 
        { desc = "Open file in VS Code" })
    vim.keymap.set("n", "<leader>cd", ":ClaudeGetDiagnostics<CR>", 
        { desc = "Get diagnostics from VS Code" })
end

return M
```

### Emacs Integration

```elisp
;;; claude-code.el --- Claude Code integration for Emacs

(require 'websocket)
(require 'json)

(defvar claude-code-connection nil
  "WebSocket connection to Claude Code extension.")

(defvar claude-code-request-id 0
  "Counter for request IDs.")

(defvar claude-code-pending-requests (make-hash-table :test 'equal)
  "Hash table of pending requests.")

(defun claude-code-find-lock-file ()
  "Find Claude Code extension lock file."
  (let* ((lock-dir (expand-file-name "~/.claude/ide/"))
         (files (directory-files lock-dir t "\\.lock$")))
    (car files)))

(defun claude-code-read-lock-file (file)
  "Read and parse lock file."
  (with-temp-buffer
    (insert-file-contents file)
    (json-read)))

(defun claude-code-connect ()
  "Connect to Claude Code extension."
  (interactive)
  (let* ((lock-file (claude-code-find-lock-file))
         (lock-data (when lock-file (claude-code-read-lock-file lock-file)))
         (port (or (cdr (assoc 'port lock-data)) 40145))
         (auth-token (cdr (assoc 'authToken lock-data))))
    
    (when claude-code-connection
      (websocket-close claude-code-connection))
    
    (setq claude-code-connection
          (websocket-open
           (format "ws://127.0.0.1:%d" port)
           :on-message #'claude-code-on-message
           :on-close #'claude-code-on-close
           :custom-header-alist
           `(("x-claude-code-ide-authorization" . ,auth-token))))
    
    (message "Connected to Claude Code extension")))

(defun claude-code-on-message (_websocket frame)
  "Handle incoming message."
  (let* ((text (websocket-frame-text frame))
         (data (json-read-from-string text))
         (id (cdr (assoc 'id data)))
         (callback (gethash id claude-code-pending-requests)))
    (when callback
      (funcall callback data)
      (remhash id claude-code-pending-requests))))

(defun claude-code-on-close (_websocket)
  "Handle connection close."
  (setq claude-code-connection nil)
  (message "Claude Code connection closed"))

(defun claude-code-call-tool (tool-name args callback)
  "Call a Claude Code tool."
  (when claude-code-connection
    (setq claude-code-request-id (1+ claude-code-request-id))
    (let ((request (json-encode
                    `((jsonrpc . "2.0")
                      (method . "tools/call")
                      (params . ((name . ,tool-name)
                                (arguments . ,args)))
                      (id . ,claude-code-request-id)))))
      (puthash claude-code-request-id callback claude-code-pending-requests)
      (websocket-send-text claude-code-connection request))))

(defun claude-code-open-file (file)
  "Open file in VS Code."
  (interactive "fFile: ")
  (claude-code-call-tool
   "openFile"
   `((filePath . ,file))
   (lambda (_response)
     (message "Opened %s in VS Code" file))))

(provide 'claude-code)
```

## Troubleshooting

### Common Issues and Solutions

1. **Race Condition on Connection**
   - **Problem**: "Method not found" error immediately after connecting
   - **Solution**: Add 1-second delay after connection before sending requests
   - **Reason**: Extension needs time to register all tool handlers

2. **No Lock File Found**
   - **Problem**: Can't find lock file in `~/.claude/ide/`
   - **Solution**: 
     - Ensure VS Code is running with Claude Code extension
     - Open at least one file in VS Code
     - Check if extension is activated (look for Claude icon)

3. **Authentication Failed**
   - **Problem**: Connection closed with code 1008
   - **Solution**: 
     - Re-read lock file for current auth token
     - Ensure header name is exactly `x-claude-code-ide-authorization`
     - Token may have changed if VS Code restarted

4. **Port Connection Refused**
   - **Problem**: Can't connect to WebSocket port
   - **Solution**:
     - Verify port number in lock file
     - Check if VS Code process is still running
     - Look for firewall/security software blocking local connections

5. **Incomplete Tool List**
   - **Problem**: Some tools missing from `tools/list` response
   - **Solution**: Wait longer after connection (up to 2 seconds)
   - **Reason**: Some tools may be registered asynchronously

### Debug Techniques

1. **Monitor Lock Files**
   ```bash
   watch -n 1 'ls -la ~/.claude/ide/'
   ```

2. **Check Port Usage**
   ```bash
   lsof -i:40145  # Or whatever port is in lock file
   netstat -an | grep 40145
   ```

3. **Test with curl**
   ```bash
   # Won't work for WebSocket, but tests if port is open
   curl -v http://127.0.0.1:40145
   ```

4. **VS Code Extension Logs**
   - Open VS Code Output panel
   - Select "Claude Code" from dropdown
   - Check for error messages

5. **Use Chrome DevTools**
   - Open `chrome://inspect`
   - Click "Open dedicated DevTools for Node"
   - Can inspect WebSocket frames

## Advanced Topics

### Building a WebSocket Bridge

For languages without native WebSocket support, create a bridge:

```python
# websocket_bridge.py
import sys
import json
import websocket
import threading
from queue import Queue

class WebSocketBridge:
    def __init__(self, port, auth_token):
        self.url = f"ws://127.0.0.1:{port}"
        self.auth_token = auth_token
        self.ws = None
        self.message_queue = Queue()
        
    def connect(self):
        self.ws = websocket.WebSocketApp(
            self.url,
            header={"x-claude-code-ide-authorization": self.auth_token},
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )
        
        wst = threading.Thread(target=self.ws.run_forever)
        wst.daemon = True
        wst.start()
        
    def on_message(self, ws, message):
        # Forward to stdout for parent process
        print(message)
        sys.stdout.flush()
        
    def on_error(self, ws, error):
        sys.stderr.write(f"Error: {error}\n")
        
    def on_close(self, ws, close_status_code, close_msg):
        sys.exit(0)
        
    def send_message(self, message):
        if self.ws:
            self.ws.send(message)
            
    def run(self):
        self.connect()
        
        # Read from stdin and forward to WebSocket
        for line in sys.stdin:
            self.send_message(line.strip())
```

### Creating Custom Tools

While you can't add tools to the VS Code extension, you can:

1. **Proxy Pattern**: Create your own MCP server that forwards to VS Code and adds tools
2. **Composite Operations**: Combine multiple tool calls to create new functionality
3. **Tool Wrappers**: Add pre/post processing to existing tools

### Performance Optimization

1. **Connection Pooling**: Reuse WebSocket connections
2. **Request Batching**: Send multiple requests in quick succession
3. **Caching**: Cache responses for read-only operations like `getWorkspaceFolders`
4. **Async Operations**: Use async/await or callbacks for non-blocking operations

### Security Considerations

1. **Local Only**: Extension only listens on localhost
2. **Auth Token Rotation**: Token changes when VS Code restarts
3. **File Access**: Extension has same file access as VS Code process
4. **Code Execution**: `executeCode` tool can run arbitrary code

## Conclusion

The Claude Code VS Code extension provides a well-designed API for IDE integration. With this guide, you can build robust integrations for any editor or application. The WebSocket + JSON-RPC protocol is straightforward, and the tool set covers most common IDE operations.

Key success factors:
- Handle the connection race condition
- Implement proper error handling
- Map tools to native editor operations
- Provide good user feedback

---

*Documentation based on Claude Code VS Code Extension v1.0.51*
*Last updated: July 2024*