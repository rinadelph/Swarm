# MCP Interception Summary

## How Claude Code's /ide Command Works

We've successfully set up a man-in-the-middle proxy to intercept the Model Context Protocol (MCP) communication between Claude Code and VS Code.

### Key Findings:

1. **MCP Server**: VS Code extension runs an MCP server on `localhost:40145` using WebSocket protocol
2. **Lock Files**: Located in `~/.claude/ide/`, named by PID (e.g., `367937.lock`)
3. **Communication**: JSON-RPC messages over WebSocket connection

### Current Setup:

1. **Original VS Code MCP Server**: Port 40145 (PID: 367937)
2. **MITM WebSocket Proxy**: Port 40146 (forwards to 40145)
3. **Modified Lock File**: `~/.claude/ide/367937.lock` points to our proxy port 40146

### Testing Instructions:

1. **Verify proxy is running**:
   ```bash
   netstat -tlnp | grep 40146
   ```

2. **Start Claude in debug mode**:
   ```bash
   claude --debug
   ```

3. **Type the /ide command**:
   ```
   > /ide
   ```

4. **Check captured messages**:
   ```bash
   ls -la mitm-claude/logs/mcp_websocket/
   ```

### Files Created:

- `mitm-websocket.py` - Basic WebSocket MITM proxy
- `mitm-websocket-v2.py` - Enhanced proxy with better logging
- `intercept-mcp-stdio.py` - Stdio interceptor (for future use)
- Various test scripts for setup and monitoring

### MCP Protocol Details:

The MCP uses JSON-RPC over WebSocket with messages for:
- Tool discovery and execution
- Resource access (files, git state)
- Completion suggestions
- IDE state synchronization

### Next Steps:

With the proxy in place, you can now:
1. Capture all MCP messages between Claude and VS Code
2. Analyze the protocol implementation
3. Understand how /ide integrates with the IDE
4. Potentially create custom MCP servers or clients