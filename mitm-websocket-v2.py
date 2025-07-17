#!/usr/bin/env python3
import asyncio
import websockets
import json
import datetime
import os

VSCODE_PORT = 40145
MITM_PORT = 40146
LOG_DIR = "mitm-claude/logs/mcp_websocket"

print(f"[MITM] Starting on port {MITM_PORT}")
print(f"[MITM] Will forward to VS Code on port {VSCODE_PORT}")
print(f"[MITM] Waiting for connections...")

async def handle_client(websocket, path):
    client_addr = websocket.remote_address
    print(f"\n[MITM] New connection from {client_addr}")
    
    try:
        # Connect to VS Code
        async with websockets.connect(f"ws://localhost:{VSCODE_PORT}/") as vscode:
            print(f"[MITM] Connected to VS Code MCP server")
            
            # Relay messages
            async def client_to_vscode():
                async for message in websocket:
                    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                    filename = f"{LOG_DIR}/request_{timestamp}.json"
                    print(f"[MITM] Client->VSCode: {message[:100]}...")
                    with open(filename, 'w') as f:
                        f.write(message)
                    await vscode.send(message)
            
            async def vscode_to_client():
                async for message in vscode:
                    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                    filename = f"{LOG_DIR}/response_{timestamp}.json"
                    print(f"[MITM] VSCode->Client: {message[:100]}...")
                    with open(filename, 'w') as f:
                        f.write(message)
                    await websocket.send(message)
            
            await asyncio.gather(client_to_vscode(), vscode_to_client())
            
    except Exception as e:
        print(f"[MITM] Error: {e}")

async def main():
    os.makedirs(LOG_DIR, exist_ok=True)
    async with websockets.serve(handle_client, "localhost", MITM_PORT):
        await asyncio.Future()

asyncio.run(main())
