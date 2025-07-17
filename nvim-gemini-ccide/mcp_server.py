#!/usr/bin/env python3
"""
MCP Server for Neovim - Implements the Model Context Protocol
This server allows Claude to connect to Neovim and access editor functionality
"""

import asyncio
import websockets
import json
import sys
import socket
from typing import Dict, Any, Optional

class NeovimMCPServer:
    def __init__(self, nvim_bridge):
        self.nvim_bridge = nvim_bridge
        self.tools = self._register_tools()
        
    def _register_tools(self) -> Dict[str, Dict[str, Any]]:
        """Register available tools"""
        return {
            "getOpenEditors": {
                "description": "Get list of open buffers in Neovim",
                "inputSchema": {"type": "object", "properties": {}}
            },
            "getCurrentSelection": {
                "description": "Get current text selection",
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
                "description": "Get workspace folders",
                "inputSchema": {"type": "object", "properties": {}}
            },
            "getDiagnostics": {
                "description": "Get diagnostics from Neovim",
                "inputSchema": {
                    "type": "object", 
                    "properties": {
                        "uri": {"type": "string"}
                    }
                }
            },
            "executeCommand": {
                "description": "Execute a Vim command",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "command": {"type": "string"}
                    },
                    "required": ["command"]
                }
            }
        }
    
    async def handle_request(self, websocket, request: Dict[str, Any]):
        """Handle JSON-RPC request"""
        method = request.get("method")
        params = request.get("params", {})
        request_id = request.get("id")
        
        print(f"Handling request - method: {method}, id: {request_id}", file=sys.stderr)
        
        try:
            if method == "tools/list":
                # Return available tools
                result = {
                    "tools": [
                        {
                            "name": name,
                            "description": info["description"],
                            "inputSchema": info["inputSchema"]
                        }
                        for name, info in self.tools.items()
                    ]
                }
                print(f"Returning {len(result['tools'])} tools", file=sys.stderr)
            elif method == "tools/call":
                # Call a specific tool
                tool_name = params.get("name")
                tool_args = params.get("arguments", {})
                
                print(f"Calling tool: {tool_name} with args: {tool_args}", file=sys.stderr)
                
                if tool_name in self.tools:
                    # Forward to Neovim and get result
                    result = await self.nvim_bridge.call_tool(tool_name, tool_args)
                else:
                    raise Exception(f"Unknown tool: {tool_name}")
            else:
                raise Exception(f"Unknown method: {method}")
            
            # Send response
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": result
            }
            
        except Exception as e:
            print(f"Request error: {e}", file=sys.stderr)
            # Send error response
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32603,
                    "message": str(e)
                }
            }
        
        print(f"Sending response: {json.dumps(response)[:100]}...", file=sys.stderr)
        await websocket.send(json.dumps(response))
    
    async def handle_connection(self, websocket):
        """Handle WebSocket connection"""
        print(f"New connection from {websocket.remote_address}", file=sys.stderr)
        
        try:
            async for message in websocket:
                print(f"Received message: {message}", file=sys.stderr)
                try:
                    request = json.loads(message)
                    print(f"Parsed request: {request}", file=sys.stderr)
                    await self.handle_request(websocket, request)
                except json.JSONDecodeError as e:
                    print(f"Invalid JSON: {message}, error: {e}", file=sys.stderr)
                except Exception as e:
                    print(f"Error handling request: {e}", file=sys.stderr)
                    import traceback
                    traceback.print_exc(file=sys.stderr)
        except websockets.exceptions.ConnectionClosed:
            print("Connection closed", file=sys.stderr)
        except Exception as e:
            print(f"Connection error: {e}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)

class NeovimBridge:
    """Bridge to communicate with Neovim via stdio"""
    
    def __init__(self):
        self.request_id = 0
        self.pending_requests = {}
        
    async def call_tool(self, tool_name: str, args: Dict[str, Any]) -> Dict[str, Any]:
        """Call a tool in Neovim and get the result"""
        self.request_id += 1
        request = {
            "id": self.request_id,
            "tool": tool_name,
            "args": args
        }
        
        # Send request to Neovim via stdout
        print(f"NVIM_REQUEST:{json.dumps(request)}")
        sys.stdout.flush()
        
        # For now, return mock data
        # In real implementation, we'd wait for response from Neovim
        if tool_name == "getOpenEditors":
            return {
                "content": [{
                    "type": "text",
                    "text": json.dumps({
                        "editors": [
                            {"filePath": "/tmp/test.txt", "uri": "file:///tmp/test.txt"}
                        ]
                    })
                }]
            }
        elif tool_name == "getCurrentSelection":
            return {
                "content": [{
                    "type": "text",
                    "text": json.dumps({
                        "text": "",
                        "selection": {"isEmpty": True}
                    })
                }]
            }
        else:
            return {"content": [{"type": "text", "text": "OK"}]}

async def find_free_port(start_port: int = 0) -> int:
    """Find a free port to listen on"""
    if start_port == 0:
        # Let the system choose
        sock = socket.socket()
        sock.bind(('', 0))
        port = sock.getsockname()[1]
        sock.close()
        return port
    else:
        # Try the specified port
        sock = socket.socket()
        try:
            sock.bind(('', start_port))
            sock.close()
            return start_port
        except:
            # Find next available
            sock.bind(('', 0))
            port = sock.getsockname()[1]
            sock.close()
            return port

async def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    port = await find_free_port(port)
    
    # Create bridge and server
    bridge = NeovimBridge()
    server = NeovimMCPServer(bridge)
    
    # Start WebSocket server
    print(f"Starting MCP server on ws://localhost:{port}", file=sys.stderr)
    
    # Report the port to Neovim AFTER we know we're ready
    print(f"PORT:{port}")
    sys.stdout.flush()
    
    # Create handler function with correct signature
    async def handler(websocket, path):
        print(f"Handler called with path: {path}", file=sys.stderr)
        await server.handle_connection(websocket)
    
    try:
        async with websockets.serve(handler, "localhost", port):
            print("MCP server ready", file=sys.stderr)
            await asyncio.Future()  # Run forever
    except Exception as e:
        print(f"Server error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)

if __name__ == "__main__":
    asyncio.run(main())