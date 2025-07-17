#!/usr/bin/env python3
"""Test if stdin reading is blocking stdout writing"""

import sys
import threading
import time

def stdin_reader():
    """Read from stdin in a separate thread"""
    print("[READER] Thread started", file=sys.stderr)
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        print(f"[READER] Got: {line.strip()}", file=sys.stderr)
        # Echo back
        print(f"ECHO: {line.strip()}")
        sys.stdout.flush()

# Start reader thread
reader = threading.Thread(target=stdin_reader)
reader.daemon = True
reader.start()

# Test immediate stdout writing
print("PORT:12345")
sys.stdout.flush()
print("[MAIN] Sent PORT", file=sys.stderr)

time.sleep(0.1)

print("NVIM_REQUEST:test")
sys.stdout.flush()
print("[MAIN] Sent NVIM_REQUEST", file=sys.stderr)

# Keep running
time.sleep(2)