# MCP Manager Plugin for Swarm

The MCP Manager plugin provides a convenient interface for managing Model Context Protocol (MCP) servers within Swarm. It allows you to configure, launch, and monitor MCP servers directly from your terminal.

## Features

- **Configure MCP Servers**: Add, edit, and delete MCP server configurations
- **Launch Servers**: Start MCP servers in dedicated tabs with proper environment setup
- **Monitor Status**: View running MCP servers and their status
- **Quick Access**: Enter the terminal of any running MCP server
- **Two Server Types**: Support for both stdio and HTTP-based MCP servers

## Usage

### Launching the Plugin

Press `Ctrl+b 2` to open the MCP Manager plugin as a floating window.

### Main Menu

When you open the plugin, you'll see the main menu with these options:

1. **Current MCPs** - View and manage running MCP servers
2. **Launch MCP** - Start a configured MCP server
3. **Add MCP** - Configure a new MCP server
4. **Quit** (q) - Close the MCP Manager

### Managing MCP Servers

#### Adding a New MCP Server

1. Select "Add MCP" from the main menu (press 3)
2. Fill in the configuration fields:
   - **Name**: A descriptive name for your MCP server
   - **Type**: Choose between "stdio" or "http"
   - **Command**: The command to run (e.g., "npx", "python")
   - **Arguments**: Command arguments (space-separated)
   - **Port**: (HTTP only) The port number for HTTP servers
   - **Working Dir**: Optional working directory
   - **Env Vars**: Environment variables in KEY=VALUE format (one per line)

3. Navigate between fields using Tab/Shift+Tab
4. Press Enter on the last field to save the configuration

#### Launching an MCP Server

1. Select "Launch MCP" from the main menu (press 2)
2. Use arrow keys to select a configured server
3. Press Enter to launch it
4. The server will start in a new tab named "MCP: [server name]"

#### Managing Running Servers

1. Select "Current MCPs" from the main menu (press 1)
2. Use arrow keys to select a running server
3. Available actions:
   - **Enter**: Switch to the server's terminal
   - **s**: Stop the selected server
   - **r**: Restart the selected server
   - **b**: Go back to main menu

### Example Configurations

#### Claude Desktop MCP Server (stdio)
```
Name: Claude Desktop MCP
Type: stdio
Command: npx
Arguments: -y @modelcontextprotocol/server-everything
Working Dir: (empty)
Env Vars: (empty)
```

#### Python MCP Server (HTTP)
```
Name: Python MCP Server
Type: http
Command: python
Arguments: -m mcp_server
Port: 8080
Working Dir: /home/user/mcp-servers
Env Vars: MCP_PORT=8080
```

## Navigation

- **Arrow Keys**: Navigate through menus and lists
- **Tab/Shift+Tab**: Move between form fields
- **Enter**: Select/Confirm
- **Esc**: Cancel/Go back
- **q**: Quit (from main menu)

## Technical Details

The plugin is implemented in Rust using the Swarm plugin API. It:
- Manages MCP server configurations (currently in-memory, persistence TODO)
- Creates new tabs for each MCP server
- Launches servers using `open_command_pane_background`
- Tracks running instances and their status
- Provides a simple terminal UI for interaction

## Future Improvements

- Persistent storage for configurations
- Better pane ID tracking for running servers
- Support for stopping servers via the plugin
- Configuration import/export
- Server health monitoring
- Log viewing capabilities