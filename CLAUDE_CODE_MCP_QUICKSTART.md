# Claude Code MCP Integration Quick Start Guide

## What is MCP?

Model Context Protocol (MCP) is the communication protocol used by Claude Code to interact with IDEs. It enables Claude to:
- View and edit files
- See diagnostics and errors
- Execute code
- Access git information
- Interact with the editor's UI

## Quick Connection Example

### Python WebSocket Client

```python
#!/usr/bin/env python3
import websocket
import json
import glob
import os
import time

def connect_to_claude_extension():
    # 1. Find the lock file
    lock_files = glob.glob(os.path.expanduser("~/.claude/ide/*.lock"))
    if not lock_files:
        print("Error: No Claude Code extension running")
        print("Make sure VS Code is open with the Claude Code extension")
        return None
    
    # 2. Read connection details
    with open(lock_files[0], 'r') as f:
        lock_data = json.load(f)
    
    port = lock_data.get('port', 40145)
    auth_token = lock_data['authToken']
    
    print(f"Found Claude extension on port {port}")
    print(f"Auth token: {auth_token[:10]}...")
    
    # 3. Connect with authentication
    headers = {
        "x-claude-code-ide-authorization": auth_token
    }
    
    ws = websocket.WebSocket()
    try:
        ws.connect(f"ws://127.0.0.1:{port}", header=headers)
        print("Connected successfully!")
        
        # IMPORTANT: Wait for server initialization
        time.sleep(1)
        
        return ws
    except Exception as e:
        print(f"Connection failed: {e}")
        return None

def list_available_tools(ws):
    """Get list of all available tools/methods"""
    request = {
        "jsonrpc": "2.0",
        "method": "tools/list",
        "params": {},
        "id": 1
    }
    
    ws.send(json.dumps(request))
    response = json.loads(ws.recv())
    
    if "result" in response:
        print("\nAvailable tools:")
        for tool in response["result"]["tools"]:
            print(f"  - {tool['name']}: {tool.get('description', 'No description')}")
    else:
        print(f"Error: {response}")

def get_open_editors(ws):
    """Get list of currently open files"""
    request = {
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
            "name": "getOpenEditors",
            "arguments": {}
        },
        "id": 2
    }
    
    ws.send(json.dumps(request))
    response = json.loads(ws.recv())
    
    if "result" in response:
        print("\nOpen editors:")
        content = response["result"]["content"]
        if isinstance(content, list) and content:
            data = json.loads(content[0]["text"])
            for editor in data.get("editors", []):
                print(f"  - {editor}")
    else:
        print(f"Error: {response}")

def main():
    # Connect to Claude extension
    ws = connect_to_claude_extension()
    if not ws:
        return
    
    try:
        # List available tools
        list_available_tools(ws)
        
        # Get open editors
        get_open_editors(ws)
        
    finally:
        ws.close()
        print("\nConnection closed")

if __name__ == "__main__":
    main()
```

## Installation & Usage

1. **Install dependencies**:
   ```bash
   pip install websocket-client
   ```

2. **Ensure VS Code is running** with Claude Code extension active

3. **Run the script**:
   ```bash
   python3 claude_mcp_client.py
   ```

## Common Operations

### Open a File
```python
request = {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "openFile",
        "arguments": {
            "path": "/path/to/your/file.py"
        }
    },
    "id": 3
}
```

### Get Current Selection
```python
request = {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "getCurrentSelection",
        "arguments": {}
    },
    "id": 4
}
```

### Execute Code
```python
request = {
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
        "name": "executeCode",
        "arguments": {
            "code": "print('Hello from Claude!')"
        }
    },
    "id": 5
}
```

## Lock File Locations

- **macOS/Linux**: `~/.claude/ide/*.lock`
- **Windows**: `%USERPROFILE%\.claude\ide\*.lock`

## Troubleshooting

### No lock file found
- Make sure VS Code is running
- Open at least one file in VS Code
- Check if Claude Code extension is installed and activated

### Connection refused
- Verify the port number in the lock file
- Check if another application is using the port
- Restart VS Code and try again

### Unauthorized error
- The auth token may have changed - re-read the lock file
- Make sure you're including the authorization header

### Method not found
- Add a 1-second delay after connecting (race condition)
- Verify the method name is correct
- Check if the extension version supports the method

## Next Steps

1. Build a proper client library for your language
2. Implement error handling and reconnection logic
3. Create editor-specific integrations (Neovim, Emacs, etc.)
4. Explore all available tools and their parameters
5. Consider contributing to open-source MCP clients

---

*Based on Claude Code VS Code Extension v1.0.51*