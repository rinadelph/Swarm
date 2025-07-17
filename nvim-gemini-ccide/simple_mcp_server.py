#!/usr/bin/env python3
"""Simple MCP server for testing"""

import asyncio
import websockets
import json
import sys

async def handle_connection(websocket, path):
    """Handle WebSocket connection"""
    print(f"New connection from {websocket.remote_address}, path: {path}", file=sys.stderr)
    
    try:
        async for message in websocket:
            print(f"Received: {message}", file=sys.stderr)
            
            try:
                request = json.loads(message)
                method = request.get("method")
                request_id = request.get("id")
                
                if method == "tools/list":
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "result": {
                            "tools": [
                                {"name": "test1", "description": "Test tool 1"},
                                {"name": "test2", "description": "Test tool 2"}
                            ]
                        }
                    }
                else:
                    response = {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {"code": -32601, "message": "Method not found"}
                    }
                
                print(f"Sending: {json.dumps(response)}", file=sys.stderr)
                await websocket.send(json.dumps(response))
                
            except Exception as e:
                print(f"Error: {e}", file=sys.stderr)
                
    except websockets.exceptions.ConnectionClosed:
        print("Connection closed", file=sys.stderr)

async def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 45001
    print(f"Starting simple MCP server on port {port}", file=sys.stderr)
    
    async with websockets.serve(handle_connection, "localhost", port):
        print(f"Server ready on ws://localhost:{port}", file=sys.stderr)
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())