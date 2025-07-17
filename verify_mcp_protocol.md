# Task: Verify MCP Protocol Implementation

Please help verify how the Model Context Protocol (MCP) actually works by:

1. **Reverse engineer the VS Code Claude extension** in `/home/alejandro/.vscode/extensions/anthropic.claude-code-1.0.51/`
   - Look at the JavaScript source code in `dist/extension.js` 
   - Find how it implements the MCP server
   - Check if it uses WebSocket or HTTP/SSE

2. **Read the documentation** in this repository:
   - Check any markdown files that explain the protocol
   - Look for references to SSE (Server-Sent Events) vs WebSocket

3. **Analyze our current implementation**:
   - Our Neovim plugin is at `nvim-gemini-ccide/`
   - We're currently using WebSocket on a dynamic port
   - The lock file is created at `~/.claude/ide/neovim_<pid>.lock`

4. **Key questions to answer**:
   - Does MCP use WebSocket or HTTP/SSE?
   - What endpoint does it connect to? (e.g., `/sse`, `/ws`, etc.)
   - What headers are required for authentication?
   - How does the handshake work?

Current issue: Claude Code shows "No IDE selected" when we type `/ide` even though our MCP server is running.

Please analyze the code and provide the correct implementation details.