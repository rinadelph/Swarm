#!/usr/bin/env python3
"""Test script to verify IPC channel with Neovim"""

import sys
import json
import time

def log(msg):
    print(f"[TEST] {msg}", file=sys.stderr)
    sys.stderr.flush()

log("Starting IPC test")

# Test 1: Send a simple NVIM_REQUEST
request = {
    "id": "test-1",
    "tool": "getCurrentSelection",
    "args": {}
}

log(f"Sending request: {request}")
print(f"NVIM_REQUEST:{json.dumps(request)}")
sys.stdout.flush()

# Wait for response
log("Waiting for response...")
response_line = sys.stdin.readline()

if response_line:
    log(f"Received response: {response_line.strip()}")
    try:
        response = json.loads(response_line.strip())
        log(f"Parsed response: {response}")
    except json.JSONDecodeError as e:
        log(f"Failed to parse response: {e}")
else:
    log("No response received - stdin closed or timeout")

# Test 2: Try another tool
request2 = {
    "id": "test-2", 
    "tool": "getOpenEditors",
    "args": {}
}

log(f"Sending second request: {request2}")
print(f"NVIM_REQUEST:{json.dumps(request2)}")
sys.stdout.flush()

response_line2 = sys.stdin.readline()
if response_line2:
    log(f"Received second response: {response_line2.strip()}")

log("Test completed")