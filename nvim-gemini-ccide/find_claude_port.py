#!/usr/bin/env python3
"""
Find the actual Claude Code VS Code extension port
"""

import os
import json
import glob
import socket

def find_claude_code_port():
    """Find the active Claude Code extension port"""
    lock_files = glob.glob(os.path.expanduser("~/.claude/ide/*.lock"))
    
    if not lock_files:
        print("No lock files found")
        return None
    
    # Try each lock file
    for lock_file in lock_files:
        try:
            with open(lock_file, 'r') as f:
                content = f.read().strip()
                
            # Try to parse as JSON first
            data = None
            port = None
            auth_token = None
            
            try:
                data = json.loads(content)
                if isinstance(data, dict):
                    port = data.get('port')
                    auth_token = data.get('authToken')
            except:
                # Not JSON, might be just a port number
                try:
                    port = int(content)
                except:
                    pass
                    
            # If no port from content, try filename
            if not port:
                filename = os.path.basename(lock_file)
                if filename.endswith('.lock'):
                    try:
                        port = int(filename[:-5])
                    except ValueError:
                        continue
            
            # Check if port is in valid range
            if port and 1024 <= port <= 65535:
                # Test if port is actually listening
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                result = sock.connect_ex(('127.0.0.1', port))
                sock.close()
                
                if result == 0:
                    print(f"Found active Claude Code on port {port}")
                    print(f"Lock file: {lock_file}")
                    print(f"Auth token: {data.get('authToken', 'N/A')}")
                    print(f"PID: {data.get('pid', 'N/A')}")
                    return {
                        'port': port,
                        'auth_token': data.get('authToken'),
                        'lock_file': lock_file,
                        'data': data
                    }
                    
        except Exception as e:
            print(f"Error reading {lock_file}: {e}")
            continue
    
    # If no valid port found in lock files, scan common ports
    print("\nScanning for VS Code MCP server on common ports...")
    for port in range(40000, 50000):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(0.1)
        result = sock.connect_ex(('127.0.0.1', port))
        sock.close()
        
        if result == 0:
            # Check if it's a WebSocket server
            try:
                import websocket
                ws = websocket.WebSocket()
                ws.settimeout(0.5)
                ws.connect(f'ws://127.0.0.1:{port}')
                ws.close()
                print(f"Found WebSocket server on port {port}")
            except:
                pass
    
    return None

if __name__ == "__main__":
    result = find_claude_code_port()
    if result:
        print("\n✅ Claude Code extension found!")
        print(json.dumps(result, indent=2))
    else:
        print("\n❌ Could not find Claude Code extension")
        print("Make sure VS Code is running with the Claude Code extension active")