#!/usr/bin/env python3
"""
Auto-polling MCP monitor - Continuously polls all MCP tools
"""

import sys
import json
import time
import threading

LOG_FILE = "/tmp/nvim_mcp_auto_poll.log"

def log(message):
    timestamp = time.strftime("%H:%M:%S")
    entry = f"[{timestamp}] {message}"
    with open(LOG_FILE, "a") as f:
        f.write(entry + "\n")
        f.flush()
    print(entry, file=sys.stderr)

def format_result(result):
    if isinstance(result, dict) and "content" in result:
        content = result["content"]
        if isinstance(content, list) and len(content) > 0:
            text = content[0].get("text", "")
            try:
                data = json.loads(text)
                return json.dumps(data, indent=2)
            except:
                return text
    return str(result)

responses = {}

def stdin_reader():
    """Read responses from Neovim"""
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                break
            line = line.strip()
            if line:
                try:
                    response = json.loads(line)
                    request_id = response.get("id")
                    if request_id in responses:
                        tool_name = responses.pop(request_id)
                        log(f"\n=== {tool_name} ===")
                        log(format_result(response.get("result", {})))
                except:
                    pass
        except:
            break

def send_request(tool_name, args=None):
    request_id = f"auto-{int(time.time() * 1000)}"
    request = {
        "id": request_id,
        "tool": tool_name,
        "args": args or {}
    }
    responses[request_id] = tool_name
    print(f"NVIM_REQUEST:{json.dumps(request)}")
    sys.stdout.flush()

def main():
    # Clear log
    with open(LOG_FILE, "w") as f:
        f.write(f"=== Auto Poll Monitor - {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    
    # Start reader
    reader = threading.Thread(target=stdin_reader)
    reader.daemon = True
    reader.start()
    
    print("READY")
    sys.stdout.flush()
    
    log("Auto-polling started (1 second interval)")
    
    # Continuous polling loop
    while True:
        try:
            # Poll all tools
            send_request("getCurrentSelection")
            time.sleep(0.1)
            send_request("getOpenEditors")
            time.sleep(0.1)
            send_request("getDiagnostics", {"uri": ""})
            time.sleep(0.1)
            send_request("getWorkspaceFolders")
            
            # Wait before next poll
            time.sleep(1)
            
        except KeyboardInterrupt:
            break
    
    log("Monitor stopped")

if __name__ == "__main__":
    main()