#!/usr/bin/env python3
import sys
import time

# Test different output methods
print("PORT:12345")  # This should work
sys.stdout.flush()

time.sleep(0.1)

print("NVIM_REQUEST:test")  # This should also work
sys.stdout.flush()

# Also print to stderr to compare
print("[DEBUG] Sent to stdout: PORT and NVIM_REQUEST", file=sys.stderr)
sys.stderr.flush()

# Keep running for a bit
time.sleep(1)