#!/usr/bin/env python3
"""
WebSocket MITM proxy for Claude <-> VS Code MCP communication
"""

import asyncio
import websockets
import json
import datetime
import os
from websockets.server import serve as websocket_serve

# Original VS Code MCP server
VSCODE_MCP_HOST = "localhost"
VSCODE_MCP_PORT = 40145

# Our MITM proxy port
MITM_PORT = 40146

LOG_DIR = "mitm-claude/logs/mcp_websocket"
os.makedirs(LOG_DIR, exist_ok=True)

class WebSocketMITM:
    def __init__(self):
        self.message_count = 0
        
    def log_message(self, direction, data):
        """Log WebSocket messages"""
        self.message_count += 1
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        
        # Try to parse as JSON
        try:
            json_data = json.loads(data)
            filename = f"{LOG_DIR}/ws_{direction}_{self.message_count:04d}_{timestamp}.json"
            with open(filename, 'w') as f:
                json.dump(json_data, f, indent=2)
            print(f"[WS-{direction}] Message {self.message_count}: {json_data.get('method', json_data.get('result', 'unknown'))}")
        except:
            filename = f"{LOG_DIR}/ws_{direction}_{self.message_count:04d}_{timestamp}.txt"
            with open(filename, 'w') as f:
                f.write(data)
            print(f"[WS-{direction}] Raw message {self.message_count} logged")
    
    async def forward_to_vscode(self, websocket, path):
        """Handle client connection and forward to VS Code"""
        print(f"[MITM] New client connected from {websocket.remote_address}")
        
        # Connect to the real VS Code MCP server
        try:
            async with websockets.connect(f"ws://{VSCODE_MCP_HOST}:{VSCODE_MCP_PORT}/") as vscode_ws:
                print(f"[MITM] Connected to VS Code MCP server")
                
                # Create tasks for bidirectional forwarding
                client_to_vscode = asyncio.create_task(
                    self.relay_messages(websocket, vscode_ws, "request")
                )
                vscode_to_client = asyncio.create_task(
                    self.relay_messages(vscode_ws, websocket, "response")
                )
                
                # Wait for either connection to close
                done, pending = await asyncio.wait(
                    [client_to_vscode, vscode_to_client],
                    return_when=asyncio.FIRST_COMPLETED
                )
                
                # Cancel pending tasks
                for task in pending:
                    task.cancel()
                    
        except Exception as e:
            print(f"[MITM] Error connecting to VS Code: {e}")
            await websocket.close()
    
    async def relay_messages(self, source, destination, direction):
        """Relay messages between websockets"""
        try:
            async for message in source:
                # Log the message
                self.log_message(direction, message)
                
                # Forward to destination
                await destination.send(message)
                
        except websockets.exceptions.ConnectionClosed:
            print(f"[MITM] {direction} connection closed")
        except Exception as e:
            print(f"[MITM] Error in {direction} relay: {e}")

async def main():
    mitm = WebSocketMITM()
    
    print(f"[MITM] Starting WebSocket MITM proxy on port {MITM_PORT}")
    print(f"[MITM] Forwarding to VS Code MCP server at {VSCODE_MCP_HOST}:{VSCODE_MCP_PORT}")
    print(f"[MITM] Logs will be saved to: {LOG_DIR}")
    print()
    print("To use this proxy:")
    print(f"1. Stop Claude if running")
    print(f"2. Change ~/.claude/ide/40145.lock to {MITM_PORT}.lock")
    print(f"3. Start Claude and type /ide")
    print()
    
    async with websocket_serve(mitm.forward_to_vscode, "localhost", MITM_PORT):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())