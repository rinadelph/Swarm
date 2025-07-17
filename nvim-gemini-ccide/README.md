# nvim-gemini-ccide

A Neovim plugin that provides MCP (Model Context Protocol) server for Claude IDE integration, enabling real-time observation of your Neovim editing session.

## Features

- 🤖 **Auto-start MCP server** - Starts automatically when Neovim launches
- 🔍 **Real-time monitoring** - Claude can see what file you're editing and what you're selecting
- 📊 **Status updates** - Periodic updates every 10 seconds showing current context
- 🔒 **Secure** - Only listens on localhost with unique auth tokens
- 🧹 **Auto-cleanup** - Removes stale lock files automatically

## What This Does

This plugin creates an MCP server that Claude can connect to via the `/ide` command. Once connected, Claude receives real-time information about:
- Which file you're currently editing
- Text selections (with line numbers)
- Your working directory
- Open buffers

This creates a collaborative coding experience where Claude understands your current context without you having to explain what you're working on.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  dir = '/home/alejandro/VPS/CCIde/nvim-gemini-ccide',
  name = 'nvim-gemini-ccide',
  config = function()
    require('nvim-gemini-ccide').setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  '/home/alejandro/VPS/CCIde/nvim-gemini-ccide',
  config = function()
    require('nvim-gemini-ccide').setup()
  end
}
```

## Configuration

Default configuration:

```lua
require('nvim-gemini-ccide').setup({
  auto_start = true,              -- Auto-start MCP server on launch
  port = 0,                       -- Port (0 = auto-select)
  keymaps = true,                 -- Enable default keymaps
  keymaps_prefix = "<leader>m",   -- Keymap prefix
  notifications = {
    startup = true,               -- Show startup notifications
    level = vim.log.levels.INFO,  -- Notification level
  },
  status_monitor = {
    enabled = true,               -- Enable status monitoring
    interval = 10000,             -- Update interval (ms)
  }
})
```

## Usage

### Automatic Mode (Default)

1. Start Neovim - MCP server starts automatically
2. You'll see: `🤖 MCP Server ready on port XXXXX`
3. In Claude, type `/ide` to connect
4. Claude can now see what you're working on!

### Manual Control

| Command | Keybinding | Description |
|---------|------------|-------------|
| `:MCPStart` | `<leader>ms` | Start MCP server |
| `:MCPStop` | `<leader>mx` | Stop MCP server |
| `:MCPStatus` | `<leader>m?` | Check server status |
| `:MCPTest` | `<leader>mt` | Test MCP tools |

### What Claude Sees

When connected via `/ide`, Claude receives status updates like:

```
[STATUS] Current file: /home/user/project/main.py | Lines 15-22 | Selection: 'def calculate_sum(a, b):\n    return a + b'
[STATUS] Current file: /home/user/project/main.py | No selection
```

## Requirements

- Neovim 0.7+
- Python 3.6+
- `websockets` Python package:
  ```bash
  pip install websockets
  ```

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌────────────┐     ┌─────────┐
│   Neovim    │────▶│  MCP Server  │────▶│ Debug Log  │────▶│ Claude  │
│   (Lua)     │ IPC │  (Python)    │     │            │     │  (/ide) │
└─────────────┘     └──────────────┘     └────────────┘     └─────────┘
```

## Debugging

### Check Debug Log
```bash
tail -f /tmp/nvim_mcp_debug.log
```

### Monitor in tmux
```bash
tmux new-window -n mcp_debug 'tail -f /tmp/nvim_mcp_debug.log'
```

### Common Issues

**Server won't start:**
- Check Python dependencies: `pip install websockets`
- Look for errors in debug log
- Try manual start: `:MCPStart`

**Claude can't connect:**
- Verify server is running: `:MCPStatus`
- Check lock file exists: `ls ~/.claude/ide/*.lock`
- Ensure no firewall blocking localhost

## Security

- Server only binds to `127.0.0.1` (localhost)
- Each session uses a unique authentication token
- Lock files are stored in `~/.claude/ide/`
- No code execution capabilities - observation only

## Tools Available

The MCP server provides these tools:
- `getCurrentSelection` - Current text selection with line numbers
- `getOpenEditors` - List of open buffers
- `getWorkspaceFolders` - Current working directory
- `getDiagnostics` - LSP diagnostics (errors/warnings)
- `checkDocumentDirty` - Check if buffer has unsaved changes
- `saveDocument` - Save current buffer
- `openFile` - Open a file in Neovim
- `closeAllDiffTabs` - Close diff windows

## License

MIT

## Contributing

Pull requests welcome! Areas for improvement:
- Additional context (git status, mode indicators)
- Richer selection information
- Performance optimizations
- Additional tool implementations

## Acknowledgments

Built for integration with [Claude](https://claude.ai) by Anthropic.