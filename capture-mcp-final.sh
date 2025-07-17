#!/bin/bash

echo "=== Final MCP Capture Test ==="

# Clean up
pkill -f mitm-websocket.py
rm -rf mitm-claude/logs/mcp_*
mkdir -p mitm-claude/logs/mcp_websocket

# 1. Start WebSocket proxy with better logging
echo "1. Starting enhanced WebSocket proxy..."
cat > mitm-websocket-v2.py << 'EOF'
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
EOF

python3 mitm-websocket-v2.py &
PROXY_PID=$!
sleep 2

# 2. Find all Claude-related processes
echo -e "\n2. Current Claude processes:"
ps aux | grep -E "(claude|Code Helper)" | grep -v grep | awk '{print $2, $11}' | head -10

# 3. Check existing lock files
echo -e "\n3. Lock files before test:"
ls -la ~/.claude/ide/*.lock 2>/dev/null

# 4. Create intercept instructions
echo -e "\n4. MCP Intercept Instructions:"
echo "===================================="
echo "The WebSocket proxy is now running on port 40146"
echo ""
echo "To intercept MCP communication:"
echo "1. Find the VS Code extension lock file:"
echo "   ls ~/.claude/ide/*.lock"
echo ""
echo "2. If the lock file uses WebSocket transport, modify it:"
echo "   - Change the port from 40145 to 40146"
echo "   - Or create a new lock file pointing to 40146"
echo ""
echo "3. Run Claude and test:"
echo "   claude --debug"
echo "   Type: /ide"
echo ""
echo "4. Watch for captured messages in:"
echo "   mitm-claude/logs/mcp_websocket/"
echo "===================================="

# 5. Monitor
echo -e "\n5. Monitoring (press Ctrl+C to stop)..."
watch -n 1 'echo "=== Connections ==="; netstat -an | grep -E "4014[56]"; echo -e "\n=== Captured Messages ==="; ls -lt mitm-claude/logs/mcp_websocket/ 2>/dev/null | head -5'