
# Claude Code Extension: Reverse-Engineering & Integration Report

This report details the process of reverse-engineering the Claude Code VS Code extension to understand its communication mechanisms and provides a detailed guide for integrating its functionality with an external editor like Neovim.

## 1. Deconstructing the Extension

The initial step was to deconstruct the VSIX package to access its source code.

- **Command:** `unzip anthropic.claude-code-1.0.51.vsix -d unzipped_vsix`
- **Key Files Analyzed:**
    - `extension/package.json`: Provided metadata, including commands and activation events.
    - `extension/extension.js`: The minified source code containing the core logic.

## 2. Communication Protocol Analysis

Analysis of `extension.js` revealed the following communication mechanisms:

- **WebSocket Server:** The extension hosts a local WebSocket server.
- **Authentication:** The server requires an `x-claude-code-ide-authorization` header for all incoming WebSocket connections.
- **JSON-RPC 2.0:** All communication over the WebSocket is structured using the JSON-RPC 2.0 protocol.

## 3. Locating Connection Details

The extension facilitates communication with its backend by storing connection details in a lock file.

- **Lock File Location:** `~/.claude/ide/`
- **Discovery:** The lock file is named after the port it's running on (e.g., `40145.lock`).
- **Contents:** The file is a JSON object containing the `port` and a UUID `authToken`.

**Example Lock File Content:**
```json
{"pid":367494,"workspaceFolders":["/home/alejandro/Code/MCP/Agent-MCP"],"ideName":"Visual Studio Code","transport":"ws","runningInWindows":false,"authToken":"35b20821-2914-48d4-9998-1bbc66e2c5a2"}
```

## 4. Tool Discovery and API Surface

A race condition was discovered where the client could connect before the extension had finished registering its tools. Adding a small delay before sending the first request resolved this. The `tools/list` method was used to retrieve a complete list of available tools.

**Python Snippet for Connection and Tool Discovery:**
```python
import websocket
import json
import time
import threading

def on_message(ws, message):
    print(message)

def on_error(ws, error):
    print(error)

def on_close(ws, close_status_code, close_msg):
    print("### closed ###")

def on_open(ws):
    def run(*args):
        # Delay to avoid race condition
        time.sleep(1)
        # Request the list of tools
        ws.send(json.dumps({"jsonrpc": "2.0", "method": "tools/list", "id": 1}))
        time.sleep(1)
        ws.close()
    thread = threading.Thread(target=run)
    thread.start()

if __name__ == "__main__":
    # Replace with details from your lock file
    port = 40145
    auth_token = "35b20821-2914-48d4-9998-1bbc66e2c5a2"
    
    ws = websocket.WebSocketApp(f"ws://127.0.0.1:{port}",
                              header={"x-claude-code-ide-authorization": auth_token},
                              on_message=on_message,
                              on_error=on_error,
                              on_close=on_close)
    ws.on_open = on_open
    ws.run_forever()
```

---

## 5. Detailed Tool Analysis & Neovim Integration Guide

### `tools/list`
- **Purpose:** Discovers all available tools and their JSON schemas.
- **Neovim Integration:** This should be the first call made by a Neovim client. The response can be used to dynamically generate corresponding Lua/Python functions.

### `openDiff`
- **Purpose:** Opens a visual diff view.
- **Parameters:** `old_file_path`, `new_file_path`, `new_file_contents`, `tab_name`.
- **Functionality:** Uses VS Code's virtual file system and the `vscode.diff` command. It returns a promise that resolves when the user accepts or rejects the diff.
- **Neovim Integration:**
    1.  Create two temporary, unlisted buffers.
    2.  Populate them with the old and new file contents.
    3.  Use `:diffsplit` to open the diff view.
    4.  Create buffer-local commands (e.g., `:ClaudeAccept`, `:ClaudeReject`) to handle the user's choice, write the file or discard it, and send the appropriate response back over the WebSocket.

### `getDiagnostics`
- **Purpose:** Retrieves all diagnostic issues (errors, warnings).
- **Parameters:** `uri` (optional).
- **Functionality:** Wraps the `vscode.languages.getDiagnostics()` API.
- **Neovim Integration:** Use the response to populate Neovim's native diagnostic system via `vim.diagnostic.set()`. This allows Claude to have context on code quality.

### `openFile`
- **Purpose:** Opens a file and optionally selects a region of text.
- **Parameters:** `filePath`, `preview`, `startText`, `endText`, `selectToEndOfLine`, `makeFrontmost`.
- **Functionality:** Uses `vscode.workspace.openTextDocument` and `vscode.window.showTextDocument`.
- **Neovim Integration:**
    -   Use `:edit` or `:tabedit` to open the file.
    -   Use `vim.fn.searchpos()` to find the line/column for `startText` and `endText`.
    -   Use `vim.api.nvim_win_set_cursor()` and visual mode commands to create the selection.

### `getOpenEditors`
- **Purpose:** Returns a list of all currently open editor tabs.
- **Functionality:** Iterates through `vscode.window.tabGroups.all`.
- **Neovim Integration:** Replicate by combining `vim.api.nvim_list_tabs()`, `vim.api.nvim_tabpage_list_wins()`, and `vim.api.nvim_buf_get_name()` to build a similar list.

### `getCurrentSelection`
- **Purpose:** Gets the selected text from the currently active editor.
- **Functionality:** Uses `vscode.window.activeTextEditor`.
- **Neovim Integration:** Get the visual selection range with `vim.fn.getpos("'<")` and `vim.fn.getpos("'>")` and extract the text from the buffer.

### `executeCode`
- **Purpose:** Executes Python code in a Jupyter Notebook.
- **Parameters:** `code`.
- **Functionality:** Depends on the `ms-toolsai.jupyter` VS Code extension. It injects a new cell into the active notebook and executes it.
- **Neovim Integration:** This is the most complex tool. It requires a Neovim plugin that can interface with Jupyter kernels (e.g., `jupytext.vim`, `iron.nvim`). The plugin would need to manage the kernel connection, execute the code, and format the output.

### Other Tools
- **`close_tab` / `closeAllDiffTabs`:** Manage editor tabs. In Neovim, this would map to `:q` or `:tabclose` on the appropriate tabs.
- **`getWorkspaceFolders`:** Maps to `vim.lsp.get_active_clients({ bufnr = 0 })` to find workspace roots or a custom project management solution.
- **`checkDocumentDirty` / `saveDocument`:** Maps to checking the `'modified'` buffer option and using `:write`.
- **`getLatestSelection`:** Can be implemented by using autocommands on `CursorMoved` and `VisualEnter`/`VisualLeave` to cache the last selection.

---

## Conclusion

The Claude Code extension offers a powerful, well-defined set of tools for IDE interaction. A successful Neovim integration is highly feasible by creating a client that respects the WebSocket/JSON-RPC protocol and carefully maps the tool functionalities to Neovim's native APIs and command system.
