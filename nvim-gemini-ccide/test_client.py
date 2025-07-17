#!/usr/bin/env python3
import websocket
import json
import time

print("MCP Client Test")
print("=" * 40)

print("Waiting for server to start...")
time.sleep(2)

try:
    ws = websocket.WebSocket()
    ws.settimeout(5.0)  # Add timeout
    ws.connect("ws://localhost:45000")  # Use port 45000
    print("✅ Connected to MCP server")
    
    # Test tools/list
    request = {"jsonrpc": "2.0", "method": "tools/list", "id": 1}
    print(f"\nSending: {json.dumps(request)}")
    ws.send(json.dumps(request))
    
    response = ws.recv()
    if response:
        data = json.loads(response)
        print(f"Response: {json.dumps(data, indent=2)}")
        
        if "result" in data and "tools" in data["result"]:
            print(f"\nFound {len(data['result']['tools'])} tools:")
            for tool in data['result']['tools']:
                print(f"  - {tool['name']}: {tool['description']}")
    else:
        print("❌ No response received")
    
    # Test a tool call
    request = {
        "jsonrpc": "2.0", 
        "method": "tools/call",
        "params": {
            "name": "getCurrentSelection",
            "arguments": {}
        },
        "id": 2
    }
    print(f"\nCalling tool: getCurrentSelection")
    ws.send(json.dumps(request))
    
    response = ws.recv()
    if response:
        data = json.loads(response)
        print(f"Tool response: {json.dumps(data, indent=2)}")
    
    ws.close()
    print("\n✅ Test completed successfully")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    import traceback
    traceback.print_exc()