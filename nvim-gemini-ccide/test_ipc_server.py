#!/usr/bin/env python3
"""
Simple test server to verify IPC communication with Neovim.
This server receives tool calls from Neovim and sends back responses.
"""

import sys
import json
import time
import threading

def log(message):
    """Write log message to stderr"""
    print(f"[TEST-SERVER] {message}", file=sys.stderr)
    sys.stderr.flush()

def stdin_reader():
    """Read responses from stdin in a separate thread"""
    log("Stdin reader thread started")
    while True:
        try:
            line = sys.stdin.readline()
            if not line:
                log("Stdin closed")
                break
            
            line = line.strip()
            if line:
                log(f"Received from stdin: {line}")
                # Parse and handle response
                try:
                    data = json.loads(line)
                    log(f"Parsed response: {data}")
                except json.JSONDecodeError as e:
                    log(f"Invalid JSON: {e}")
        except Exception as e:
            log(f"Error in stdin reader: {e}")
            break

def main():
    log("Test IPC server starting...")
    
    # Start stdin reader thread
    reader = threading.Thread(target=stdin_reader)
    reader.daemon = True
    reader.start()
    
    # Send initial message to Neovim
    print("READY")
    sys.stdout.flush()
    
    # Simulate some tool requests
    time.sleep(1)
    
    # Test 1: Request current selection
    request1 = {
        "id": "test-1",
        "tool": "getCurrentSelection",
        "args": {}
    }
    log(f"Sending request: {request1}")
    print(f"NVIM_REQUEST:{json.dumps(request1)}")
    sys.stdout.flush()
    
    time.sleep(2)
    
    # Test 2: Request open editors
    request2 = {
        "id": "test-2", 
        "tool": "getOpenEditors",
        "args": {}
    }
    log(f"Sending request: {request2}")
    print(f"NVIM_REQUEST:{json.dumps(request2)}")
    sys.stdout.flush()
    
    time.sleep(2)
    
    # Test 3: Request diagnostics
    request3 = {
        "id": "test-3",
        "tool": "getDiagnostics",
        "args": {"uri": ""}
    }
    log(f"Sending request: {request3}")
    print(f"NVIM_REQUEST:{json.dumps(request3)}")
    sys.stdout.flush()
    
    # Keep running indefinitely
    log("Server running. Waiting for responses...")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log("Server interrupted by user")

if __name__ == "__main__":
    main()