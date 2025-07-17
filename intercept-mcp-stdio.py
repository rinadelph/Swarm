#!/usr/bin/env python3
"""
MCP stdio interceptor - sits between Claude Code and VS Code extension
"""

import sys
import json
import subprocess
import threading
import datetime
import os

LOG_DIR = "mitm-claude/logs/mcp_messages"
os.makedirs(LOG_DIR, exist_ok=True)

class MCPInterceptor:
    def __init__(self, target_command):
        self.target_command = target_command
        self.message_count = 0
        
    def log_message(self, direction, data):
        """Log MCP messages to file"""
        self.message_count += 1
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{LOG_DIR}/mcp_{direction}_{self.message_count:04d}_{timestamp}.json"
        
        try:
            # Try to parse as JSON for pretty printing
            json_data = json.loads(data)
            with open(filename, 'w') as f:
                json.dump(json_data, f, indent=2)
            print(f"[MCP-{direction}] Logged message {self.message_count} to {filename}")
        except:
            # If not JSON, save as text
            with open(filename, 'w') as f:
                f.write(data)
            print(f"[MCP-{direction}] Logged raw message {self.message_count}")
    
    def relay_stdin_to_process(self, process):
        """Relay stdin to target process, logging messages"""
        while True:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                
                # Log the message
                self.log_message("request", line.strip())
                
                # Forward to target process
                process.stdin.write(line)
                process.stdin.flush()
                
            except Exception as e:
                print(f"[MCP-Error] stdin relay: {e}", file=sys.stderr)
                break
    
    def relay_process_to_stdout(self, process):
        """Relay process output to stdout, logging messages"""
        while True:
            try:
                line = process.stdout.readline()
                if not line:
                    break
                
                # Log the message
                self.log_message("response", line.strip())
                
                # Forward to stdout
                sys.stdout.write(line)
                sys.stdout.flush()
                
            except Exception as e:
                print(f"[MCP-Error] stdout relay: {e}", file=sys.stderr)
                break
    
    def run(self):
        """Run the interceptor"""
        print(f"[MCP-Interceptor] Starting intercept of: {self.target_command}", file=sys.stderr)
        
        # Start the target process
        process = subprocess.Popen(
            self.target_command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=0
        )
        
        # Create threads for bidirectional relay
        stdin_thread = threading.Thread(target=self.relay_stdin_to_process, args=(process,))
        stdout_thread = threading.Thread(target=self.relay_process_to_stdout, args=(process,))
        
        stdin_thread.start()
        stdout_thread.start()
        
        # Wait for process to complete
        process.wait()
        
        print(f"[MCP-Interceptor] Process exited with code {process.returncode}", file=sys.stderr)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: intercept-mcp-stdio.py <command> [args...]", file=sys.stderr)
        sys.exit(1)
    
    interceptor = MCPInterceptor(sys.argv[1:])
    interceptor.run()