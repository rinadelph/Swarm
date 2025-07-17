# Testing the Neovim MCP Plugin

## What This Plugin Does

This plugin starts an MCP (Model Context Protocol) server **inside Neovim** that Claude can connect to. It's the opposite of what we were doing before - instead of Neovim connecting to VS Code, Claude will connect to Neovim.

## How to Test

### 1. Start Neovim with the plugin

```bash
cd /home/alejandro/VPS/CCIde/nvim-gemini-ccide
nvim -u init.lua test_file.txt
```

### 2. Inside Neovim, start the MCP server

```vim
:MCPStart 45000
```

You should see:
- "MCP server started on port 45000"
- "Claude can now connect to: ws://localhost:45000"

### 3. Check the status

```vim
:MCPStatus
```

### 4. Check if lock file was created

In another terminal:
```bash
ls -la ~/.claude/ide/neovim_*.lock
cat ~/.claude/ide/neovim_*.lock
```

The lock file should contain:
```json
{
  "pid": <neovim-pid>,
  "port": 45000,
  "ideName": "Neovim",
  "transport": "ws",
  "authToken": "nvim-<timestamp>-<pid>",
  "workspaceFolders": ["<current-directory>"],
  "runningInWindows": false
}
```

### 5. Test with Claude

Run Claude and type `/ide` - it should find the Neovim MCP server!

## What the Server Provides

When Claude connects, it can:
- Get list of open buffers (`getOpenEditors`)
- Get current selection (`getCurrentSelection`)
- Get diagnostics (`getDiagnostics`)
- Open files (`openFile`)
- Save documents (`saveDocument`)
- Get workspace folders (`getWorkspaceFolders`)

## Troubleshooting

1. **Port already in use**: Use a different port number
2. **Python not found**: Make sure `python3` is in PATH
3. **websocket module missing**: Run `pip install websocket-client`
4. **Server doesn't start**: Check `:messages` in Neovim for errors

## Architecture

```
┌─────────────┐     WebSocket      ┌──────────────────┐
│   Claude    │ ──────────────────► │  Neovim MCP      │
│             │     JSON-RPC 2.0    │  Server          │
└─────────────┘                     └──────────────────┘
                                            │
                                            ▼
                                    ┌──────────────────┐
                                    │  Neovim Buffer/  │
                                    │  Editor State    │
                                    └──────────────────┘
```