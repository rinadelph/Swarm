#!/usr/bin/env python3
"""
MCP Server for Neovim - Implements the Model Context Protocol
This server allows Claude to connect to Neovim and access editor functionality.
It communicates with Neovim via stdin/stdout for tool calls.
"""

import asyncio
import websockets
import json
import sys
import os
import uuid
import threading
import time
from typing import Dict, Any, Optional

# Set up logging to file
LOG_FILE = "/tmp/nvim_mcp_debug.log"

def log(message):
    """Write log message to log file only"""
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(message + '\n')
            f.flush()
    except:
        pass

class NeovimBridge:
    """
    Handles communication with Neovim via stdin/stdout.
    Sends tool call requests to Neovim and waits for responses.
    """
    def __init__(self):
        self.pending_requests: Dict[str, asyncio.Future] = {}
        self.reader_thread = None
        self.loop = None
        self.status_thread = None
        self._running = False
    
    def start(self):
        """Start the bridge - starts the reader thread"""
        if not self.reader_thread or not self.reader_thread.is_alive():
            log(f"[BRIDGE] Starting reader thread")
            self.loop = asyncio.get_event_loop()
            self._running = True
            self.reader_thread = threading.Thread(target=self._read_from_stdin_sync, daemon=True)
            self.reader_thread.start()
            # Start status monitor thread
            self.status_thread = threading.Thread(target=self._status_monitor, daemon=True)
            self.status_thread.start()

    def stop(self):
        """Stop the bridge threads"""
        self._running = False

    def _read_from_stdin_sync(self):
        """Reads responses from Neovim via stdin in a separate thread."""
        while self._running:
            try:
                line = sys.stdin.readline()
                if not line:
                    log("[BRIDGE] stdin closed, exiting reader thread.")
                    break
                    
                line = line.strip()
                if not line:
                    continue
                    
                # Neovim sends responses as JSON on a single line
                response = json.loads(line)
                request_id = response.get("id")
                if request_id and request_id in self.pending_requests:
                    future = self.pending_requests.pop(request_id)
                    if not future.done():
                        # Use call_soon_threadsafe to set the result in the async context
                        self.loop.call_soon_threadsafe(
                            future.set_result, response.get("result")
                        )
                else:
                    log(f"[BRIDGE] Received unhandled response from Neovim: {response}")
            except json.JSONDecodeError:
                log(f"[BRIDGE] Invalid JSON from Neovim: {line}")
            except Exception as e:
                log(f"[BRIDGE] Error processing Neovim response: {e}")

    async def call_tool(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """
        Sends a tool call request to Neovim and waits for its response.
        """
        log(f"[BRIDGE] call_tool called for: {tool_name}")
        
        request_id = str(uuid.uuid4()) # Use UUID for request ID
        request = {
            "id": request_id,
            "tool": tool_name,
            "args": args
        }

        future = asyncio.Future()
        self.pending_requests[request_id] = future

        # Send request to Neovim via stdout
        request_json = f"NVIM_REQUEST:{json.dumps(request)}"
        log(f"[BRIDGE] Sending to Neovim: {request_json}")
        print(request_json)
        sys.stdout.flush()

        try:
            # Wait for the response from Neovim
            result = await asyncio.wait_for(future, timeout=10) # 10 second timeout
            return result
        except asyncio.TimeoutError:
            log(f"[BRIDGE] Timeout waiting for Neovim response for tool '{tool_name}' (ID: {request_id})")
            self.pending_requests.pop(request_id, None) # Clean up pending request
            raise Exception(f"Neovim did not respond in time for tool: {tool_name}")
        except Exception as e:
            log(f"[BRIDGE] Error calling tool '{tool_name}': {e}")
            raise

    def _status_monitor(self):
        """Periodically logs the current file and selection status."""
        # Wait a bit for the server to fully start
        time.sleep(5)
        while self._running:
            try:
                # Get current file
                file_future = asyncio.run_coroutine_threadsafe(
                    self.call_tool("getOpenEditors", {}), self.loop
                )
                file_result = file_future.result(timeout=2)
                
                # Get current selection
                selection_future = asyncio.run_coroutine_threadsafe(
                    self.call_tool("getCurrentSelection", {}), self.loop
                )
                selection_result = selection_future.result(timeout=2)
                
                # Parse the results
                editors_data = json.loads(file_result['content'][0]['text'])
                selection_data = json.loads(selection_result['content'][0]['text'])
                
                current_file = selection_data.get('filePath', 'No file')
                selection_text = selection_data.get('text', '')
                selection = selection_data.get('selection', {})
                is_empty = selection.get('isEmpty', True)
                
                if is_empty:
                    log(f"[STATUS] Current file: {current_file} | No selection")
                else:
                    start_line = selection.get('start', {}).get('line', 0) + 1  # Convert to 1-based
                    end_line = selection.get('end', {}).get('line', 0) + 1
                    selection_preview = selection_text[:50] + "..." if len(selection_text) > 50 else selection_text
                    selection_preview = selection_preview.replace('\n', '\\n')
                    log(f"[STATUS] Current file: {current_file} | Lines {start_line}-{end_line} | Selection: '{selection_preview}'")
                
            except Exception as e:
                log(f"[STATUS] Error getting status: {e}")
            
            # Wait 10 seconds before next check
            time.sleep(10)

class MCPServer:
    def __init__(self, auth_token: str, nvim_bridge: NeovimBridge):
        self.connections = set()
        self.auth_token = auth_token
        self.nvim_bridge = nvim_bridge
        self.tools = self._register_tools()

    def _register_tools(self) -> Dict[str, Dict[str, Any]]:
        """
        Registers the tools that this MCP server can expose to Claude.
        These should correspond to the capabilities implemented in Neovim.
        """
        return {
            "getCurrentSelection": {
                "description": "Get current text selection in Neovim",
                "inputSchema": {"type": "object", "properties": {}}
            },
            "getOpenEditors": {
                "description": "Get list of open buffers in Neovim",
                "inputSchema": {"type": "object", "properties": {}}
            },
            "openFile": {
                "description": "Open a file in Neovim",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "filePath": {"type": "string"}
                    },
                    "required": ["filePath"]
                }
            },
            "getWorkspaceFolders": {
                "description": "Get workspace folders from Neovim",
                "inputSchema": {"type": "object", "properties": {}}
            },
            "getDiagnostics": {
                "description": "Get diagnostics (errors, warnings) from Neovim",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "uri": {"type": "string"}
                    }
                }
            },
            "checkDocumentDirty": {
                "description": "Check if a document in Neovim has unsaved changes",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "uri": {"type": "string"}
                    },
                    "required": ["uri"]
                }
            },
            "saveDocument": {
                "description": "Save a document in Neovim",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "uri": {"type": "string"}
                    },
                    "required": ["uri"]
                }
            },
            "closeAllDiffTabs": {
                "description": "Close all diff tabs in Neovim",
                "inputSchema": {"type": "object", "properties": {}}
            }
        }

    async def handle_request(self, websocket, request: Dict[str, Any]):
        """Handles incoming JSON-RPC requests from Claude."""
        method = request.get("method")
        params = request.get("params", {})
        request_id = request.get("id")

        log(f"[SERVER] Received method: {method}, ID: {request_id}")

        response: Dict[str, Any] = {"jsonrpc": "2.0", "id": request_id}

        try:
            if method == "initialize":
                # Handle MCP initialization handshake
                response["result"] = {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {
                        "tools": {}
                    },
                    "serverInfo": {
                        "name": "neovim-mcp",
                        "version": "1.0.0"
                    }
                }
                log(f"[SERVER] Initialized MCP connection")
            elif method in ["initialized", "notifications/initialized", "ide_connected", "notifications/cancelled"]:
                # Handle various notification methods
                log(f"[SERVER] Received notification: {method}")
                # No response needed for notifications
                if request_id is None:
                    return
                response["result"] = {}
            elif method == "tools/list":
                response["result"] = {"tools": [
                    {
                        "name": name, 
                        "description": info["description"],
                        "inputSchema": info["inputSchema"]
                    }
                    for name, info in self.tools.items()
                ]}
                log(f"[SERVER] Responding with {len(self.tools)} tools.")
            elif method == "tools/call":
                tool_name = params.get("name")
                tool_args = params.get("arguments", {})
                log(f"[SERVER] Calling Neovim tool: {tool_name} with args: {tool_args}")

                if tool_name in self.tools:
                    # Forward the tool call to Neovim via the bridge
                    result = await self.nvim_bridge.call_tool(tool_name, tool_args)
                    response["result"] = result
                else:
                    raise ValueError(f"Unknown tool: {tool_name}")
            else:
                raise ValueError(f"Unknown method: {method}")

        except Exception as e:
            log(f"[SERVER] Error handling request (ID: {request_id}): {e}")
            response["error"] = {
                "code": -32603, # Internal error
                "message": str(e)
            }

        await websocket.send(json.dumps(response))
        log(f"[SERVER] Sent response for request {request_id}")

    async def handler(self, websocket):
        """WebSocket connection handler."""
        log(f"[SERVER] New connection from {websocket.remote_address}")

        # Get headers from the request
        headers = {}
        if hasattr(websocket, 'request_headers'):
            headers = dict(websocket.request_headers)
        elif hasattr(websocket, 'request') and hasattr(websocket.request, 'headers'):
            headers = dict(websocket.request.headers)
            
        log(f"[SERVER] Headers: {headers}")

        auth_header = headers.get('x-claude-code-ide-authorization') or headers.get('X-Claude-Code-Ide-Authorization')
        log(f"[SERVER] Auth token received: {auth_header}")
        log(f"[SERVER] Expected auth token: {self.auth_token}")
        
        # Validate auth token
        if auth_header != self.auth_token:
            log(f"[SERVER] Unauthorized connection attempt")
            await websocket.close(1008, "Unauthorized")
            return
        
        log(f"[SERVER] Connection authorized")
        self.connections.add(websocket)
        
        try:
            async for message in websocket:
                log(f"[SERVER] Received: {message}")
                try:
                    request = json.loads(message)
                    await self.handle_request(websocket, request)
                except json.JSONDecodeError as e:
                    log(f"[SERVER] Invalid JSON: {e}")
                except Exception as e:
                    log(f"[SERVER] Error: {e}")
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                    
        except websockets.exceptions.ConnectionClosed:
            log(f"[SERVER] Connection closed")
        finally:
            self.connections.remove(websocket)


async def main():
    """Main entry point for the MCP server."""
    if len(sys.argv) < 3:
        print("[SERVER] Usage: mcp_server_robust.py <port> <auth_token>")
        sys.exit(1)

    port = int(sys.argv[1])
    auth_token = sys.argv[2]
    
    nvim_bridge = NeovimBridge()
    # Start the bridge's stdin reader immediately
    nvim_bridge.start()
    
    server = MCPServer(auth_token, nvim_bridge)
    
    log(f"[SERVER] Attempting to start MCP server on ws://localhost:{port}")
    
    # Create server with MCP subprotocol support
    async with websockets.serve(
        server.handler, 
        "127.0.0.1",  # Explicitly use IPv4
        port,
        subprotocols=["mcp"]  # This is required for Claude
    ) as ws_server:
        # Get actual port if 0 was specified
        actual_port = ws_server.sockets[0].getsockname()[1] if ws_server.sockets else port
        
        # Print connection info for Neovim
        print(f"PORT:{actual_port}")
        print(f"AUTH:{auth_token}")
        print(f"PID:{os.getpid()}")
        sys.stdout.flush()
        
        log(f"[SERVER] MCP server successfully started on ws://localhost:{actual_port}")
        
        # Run forever
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("[SERVER] Server interrupted by user")
    except Exception as e:
        log(f"[SERVER] Fatal error: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)
