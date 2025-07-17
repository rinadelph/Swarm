#!/usr/bin/env python3
"""MCP Server compatible with websockets v15"""

import asyncio
import websockets
import json
import sys
import os

class MCPServer:
    def __init__(self, auth_token):
        self.connections = set()
        self.auth_token = auth_token
        
    async def handle_request(self, websocket, request):
        """Handle JSON-RPC request"""
        method = request.get("method")
        request_id = request.get("id")
        params = request.get("params", {})
        
        print(f"[SERVER] Method: {method}, ID: {request_id}", file=sys.stderr)
        
        if method == "tools/list":
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "tools": [
                        {
                            "name": "getCurrentSelection",
                            "description": "Get current text selection in Neovim"
                        },
                        {
                            "name": "getOpenEditors", 
                            "description": "Get list of open buffers"
                        },
                        {
                            "name": "openFile",
                            "description": "Open a file in Neovim"
                        }
                    ]
                }
            }
        elif method == "tools/call":
            tool_name = params.get("name")
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{
                        "type": "text",
                        "text": f"Mock result for tool: {tool_name}"
                    }]
                }
            }
        else:
            response = {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
        
        await websocket.send(json.dumps(response))
        print(f"[SERVER] Sent response for request {request_id}", file=sys.stderr)
    
    async def handler(self, websocket):
        """WebSocket handler for v15"""
        print(f"[SERVER] New connection from {websocket.remote_address}", file=sys.stderr)
        
        # Check authentication
        auth_header = None
        if hasattr(websocket, 'request_headers'):
            headers = dict(websocket.request_headers)
            print(f"[SERVER] Headers: {headers}", file=sys.stderr)
            auth_header = headers.get('x-claude-code-ide-authorization', None)
            print(f"[SERVER] Auth token received: {auth_header}", file=sys.stderr)
            print(f"[SERVER] Expected auth token: {self.auth_token}", file=sys.stderr)
        
        # Validate auth token
        if auth_header != self.auth_token:
            print(f"[SERVER] Unauthorized connection attempt", file=sys.stderr)
            await websocket.close(1008, "Unauthorized")
            return
        
        print(f"[SERVER] Connection authorized", file=sys.stderr)
        self.connections.add(websocket)
        
        try:
            async for message in websocket:
                print(f"[SERVER] Received: {message}", file=sys.stderr)
                try:
                    request = json.loads(message)
                    await self.handle_request(websocket, request)
                except json.JSONDecodeError as e:
                    print(f"[SERVER] Invalid JSON: {e}", file=sys.stderr)
                except Exception as e:
                    print(f"[SERVER] Error: {e}", file=sys.stderr)
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                    
        except websockets.exceptions.ConnectionClosed:
            print(f"[SERVER] Connection closed", file=sys.stderr)
        finally:
            self.connections.remove(websocket)

async def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    auth_token = sys.argv[2] if len(sys.argv) > 2 else None
    
    if not auth_token:
        print(f"[SERVER] Error: Auth token required", file=sys.stderr)
        sys.exit(1)
    
    server = MCPServer(auth_token)
    
    print(f"[SERVER] Starting MCP server on port {port}", file=sys.stderr)
    print(f"[SERVER] Auth token: {auth_token}", file=sys.stderr)
    
    # Create server and get actual port
    server_instance = await websockets.serve(server.handler, "localhost", port)
    
    # Get the actual port assigned
    actual_port = server_instance.sockets[0].getsockname()[1]
    
    print(f"PORT:{actual_port}")  # For Neovim
    print(f"AUTH:{auth_token}")  # For Neovim
    sys.stdout.flush()
    
    print(f"[SERVER] Ready on ws://localhost:{actual_port}", file=sys.stderr)
    
    # Run forever
    await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())