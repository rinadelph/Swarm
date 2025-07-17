# Neovim MCP Server - Claude IDE Integration

## Overview

The MCP (Model Context Protocol) Server enables Claude to observe and understand what you're doing in Neovim in real-time. This creates a collaborative coding experience where Claude can provide contextual assistance based on what you're actively working on.

## Features

### Real-time Monitoring
- **Current file tracking** - Claude sees which file you have open
- **Selection tracking** - Claude knows what code you're selecting (with line numbers)
- **Working directory context** - Claude understands your project structure
- **Automatic startup** - MCP server starts when you launch Neovim

### Status Updates (Every 10 seconds)
```
[STATUS] Current file: /path/to/file.py | Lines 15-22 | Selection: 'def my_function()...'
[STATUS] Current file: /path/to/file.py | No selection
```

## How It Works

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐     ┌─────────┐
│   Neovim    │────▶│  MCP Server  │────▶│ Debug Log  │────▶│ Claude  │
│             │ IPC │   (Python)   │     │            │     │  (/ide) │
└─────────────┘     └──────────────┘     └────────────┘     └─────────┘
```

1. **Neovim** runs with the MCP plugin loaded
2. **MCP Server** (Python) communicates with Neovim via IPC
3. **Debug Log** captures real-time status updates
4. **Claude** observes through the `/ide` connection

## Usage

### Automatic Setup (Default)
The MCP server now starts automatically when you launch Neovim:

```bash
nvim -u nvim-swarm-modern.lua
```

You'll see:
```
🤖 MCP Server ready on port 42229 | Use /ide in Claude to connect
📁 Lock file: ~/.claude/ide/42229.lock
```

### Manual Control
If you need to manually control the server:

| Command | Keybinding | Description |
|---------|------------|-------------|
| `:MCPStart` | `<leader>ms` | Start MCP server |
| `:MCPStop` | `<leader>mx` | Stop MCP server |
| `:MCPStatus` | `<leader>m?` | Check server status |
| `:MCPTest` | `<leader>mt` | Test MCP tools |

### Connecting Claude

1. In Claude, type `/ide`
2. Claude will automatically connect to the running MCP server
3. You'll see "Connected to Neovim" confirmation
4. Claude can now see what you're working on!

## What Claude Can See

### File Information
- Current file path
- File type/language
- Open buffers

### Selection Details
- Selected text content
- Line numbers (start-end)
- Visual mode status

### Future Enhancements (Planned)
- Git diff visibility
- Cursor position when not selecting
- Mode changes (INSERT/NORMAL/VISUAL)
- Recent actions (save, open, close)
- Diagnostics (errors, warnings)

## Configuration

The MCP server configuration is in `nvim-swarm-modern.lua`:

```lua
mcp.setup({
  auto_start = true,     -- Auto-start on Neovim launch
  port = 0,              -- Let system choose port (recommended)
  keymaps = true,        -- Enable default keymaps
  keymaps_prefix = "<leader>m",
  debug = false,         -- Set true for verbose logging
})
```

## Logs and Debugging

### Debug Log Location
```
/tmp/nvim_mcp_debug.log
```

### Monitor Debug Log
```bash
# In a separate terminal
tail -f /tmp/nvim_mcp_debug.log

# Or in tmux
tmux new-window -n mcp_debug 'tail -f /tmp/nvim_mcp_debug.log'
```

### Enable Debug Mode
Edit `nvim-swarm-modern.lua` and set:
```lua
debug = true,  -- Enable debug messages
```

## Security

- The MCP server only listens on localhost (127.0.0.1)
- Each session has a unique auth token
- Lock files are automatically cleaned up
- No code execution - only observation

## Troubleshooting

### Server won't start
- Check if port is already in use
- Look for error messages in debug log
- Try `:MCPStop` then `:MCPStart`

### Claude can't connect
- Ensure MCP server is running: `:MCPStatus`
- Check lock file exists: `ls ~/.claude/ide/`
- Verify no firewall blocking localhost connections

### No status updates
- Check if responses are timing out in debug log
- Ensure Neovim has focus (not in terminal mode)
- Try selecting some text to trigger an update

## Development

### Adding New Observability
To add new information Claude can see:

1. Add tool handler in `tools.lua`
2. Update status monitor in `mcp_server_robust.py`
3. Document the new capability

### Project Structure
```
/home/alejandro/VPS/CCIde/
├── nvim-swarm-modern.lua      # Main Neovim config with MCP
├── nvim-gemini-ccide/         # MCP plugin directory
│   ├── lua/nvim-gemini-ccide/
│   │   ├── init.lua           # Plugin initialization
│   │   ├── mcp_server_robust.lua  # Neovim server manager
│   │   └── tools.lua          # Tool implementations
│   └── mcp_server_robust.py   # Python MCP server
└── MCP_IDE_INTEGRATION.md     # This documentation
```

## Privacy Note

The MCP server only shares:
- File paths and names
- Selected text content
- Basic editor state

It does NOT share:
- File contents (unless selected)
- System information
- Personal data
- Command history

---

Happy coding with Claude! 🤖✨