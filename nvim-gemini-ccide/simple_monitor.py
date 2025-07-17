#!/usr/bin/env python3
"""
Simple MCP monitor - Just logs what Neovim sends
"""

import sys
import json
import time

LOG_FILE = "/tmp/nvim_mcp_monitor.log"

def log(message):
    timestamp = time.strftime("%H:%M:%S")
    entry = f"[{timestamp}] {message}"
    with open(LOG_FILE, "a") as f:
        f.write(entry + "\n")
        f.flush()
    print(entry, file=sys.stderr)

# Clear log
with open(LOG_FILE, "w") as f:
    f.write(f"=== Simple MCP Monitor - {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")

print("READY")
sys.stdout.flush()

log("Monitor started - waiting for Neovim activity")

# Just read stdin forever
while True:
    try:
        line = sys.stdin.readline()
        if not line:
            break
        line = line.strip()
        if line:
            log(f"Received: {line}")
    except KeyboardInterrupt:
        break
    except Exception as e:
        log(f"Error: {e}")

log("Monitor stopped")