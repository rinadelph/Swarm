#!/usr/bin/env python3
"""
Continuous IPC Monitor - Logs all MCP tool activity as you use Neovim
This allows testing what Claude would see when using the MCP tools.
"""

import sys
import json
import time
import threading
import signal

LOG_FILE = "/tmp/nvim_mcp_monitor.log"

def log(message, level="INFO"):
    """Write log message to file and stderr"""
    timestamp = time.strftime("%H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}"
    
    # Write to log file
    with open(LOG_FILE, "a") as f:
        f.write(log_entry + "\n")
        f.flush()
    
    # Also print to stderr for immediate visibility
    print(log_entry, file=sys.stderr)
    sys.stderr.flush()

def format_tool_result(result):
    """Format tool result for better readability"""
    if isinstance(result, dict) and "content" in result:
        content = result["content"]
        if isinstance(content, list) and len(content) > 0:
            text = content[0].get("text", "")
            try:
                # Try to parse as JSON for pretty printing
                data = json.loads(text)
                return json.dumps(data, indent=2)
            except:
                return text
    return json.dumps(result, indent=2)

class ToolMonitor:
    def __init__(self):
        self.running = True
        self.pending_responses = {}
        
    def stdin_reader(self):
        """Read responses from Neovim"""
        log("Stdin reader started")
        while self.running:
            try:
                line = sys.stdin.readline()
                if not line:
                    log("Stdin closed", "WARN")
                    break
                
                line = line.strip()
                if line:
                    try:
                        response = json.loads(line)
                        request_id = response.get("id")
                        
                        if request_id in self.pending_responses:
                            tool_name = self.pending_responses.pop(request_id)
                            log(f"Response for {tool_name} (ID: {request_id}):", "RESPONSE")
                            log(format_tool_result(response.get("result", {})), "DATA")
                            log("-" * 80, "SEP")
                        else:
                            log(f"Unexpected response: {line}", "WARN")
                    except json.JSONDecodeError:
                        log(f"Invalid JSON from Neovim: {line}", "ERROR")
            except Exception as e:
                log(f"Error in stdin reader: {e}", "ERROR")
                
    def send_tool_request(self, tool_name, args=None):
        """Send a tool request to Neovim"""
        request_id = f"monitor-{int(time.time() * 1000)}"
        request = {
            "id": request_id,
            "tool": tool_name,
            "args": args or {}
        }
        
        self.pending_responses[request_id] = tool_name
        
        log(f"Calling tool: {tool_name}", "REQUEST")
        if args:
            log(f"Arguments: {json.dumps(args, indent=2)}", "ARGS")
        
        print(f"NVIM_REQUEST:{json.dumps(request)}")
        sys.stdout.flush()
        
    def interactive_menu(self):
        """Show interactive menu for manual tool testing"""
        menu = """
==== MCP Tool Monitor ====
1. getCurrentSelection - Get selected text
2. getOpenEditors - List open files
3. getDiagnostics - Get diagnostics/errors
4. getWorkspaceFolders - Get workspace info
5. openFile <path> - Open a file
6. checkDocumentDirty <uri> - Check if file modified
7. saveDocument <uri> - Save a file
8. closeAllDiffTabs - Close diff tabs

Press number (1-8) or 'q' to quit
Auto-refresh: Press 'a' to toggle auto mode
        """
        
        auto_mode = False
        auto_interval = 2.0
        last_auto_time = 0
        
        print(menu, file=sys.stderr)
        
        while self.running:
            # Check for auto mode
            if auto_mode and time.time() - last_auto_time > auto_interval:
                self.send_tool_request("getCurrentSelection")
                time.sleep(0.1)
                self.send_tool_request("getOpenEditors")
                last_auto_time = time.time()
            
            # Non-blocking input check
            import select
            if sys.stdin in select.select([sys.stdin], [], [], 0.1)[0]:
                choice = input().strip().lower()
                
                if choice == 'q':
                    self.running = False
                    break
                elif choice == 'a':
                    auto_mode = not auto_mode
                    log(f"Auto mode: {'ON' if auto_mode else 'OFF'}", "MODE")
                elif choice == '1':
                    self.send_tool_request("getCurrentSelection")
                elif choice == '2':
                    self.send_tool_request("getOpenEditors")
                elif choice == '3':
                    uri = input("URI (empty for current): ").strip()
                    self.send_tool_request("getDiagnostics", {"uri": uri})
                elif choice == '4':
                    self.send_tool_request("getWorkspaceFolders")
                elif choice == '5':
                    path = input("File path: ").strip()
                    if path:
                        self.send_tool_request("openFile", {"filePath": path})
                elif choice == '6':
                    uri = input("File URI: ").strip()
                    if uri:
                        self.send_tool_request("checkDocumentDirty", {"uri": uri})
                elif choice == '7':
                    uri = input("File URI: ").strip()
                    if uri:
                        self.send_tool_request("saveDocument", {"uri": uri})
                elif choice == '8':
                    self.send_tool_request("closeAllDiffTabs")
            
            time.sleep(0.1)

def main():
    # Clear log file
    with open(LOG_FILE, "w") as f:
        f.write(f"=== MCP Tool Monitor Started at {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    
    log("MCP Tool Monitor starting...")
    log(f"Log file: {LOG_FILE}")
    
    monitor = ToolMonitor()
    
    # Start stdin reader thread
    reader_thread = threading.Thread(target=monitor.stdin_reader)
    reader_thread.daemon = True
    reader_thread.start()
    
    # Signal handler for clean exit
    def signal_handler(sig, frame):
        log("Shutting down monitor...", "INFO")
        monitor.running = False
        sys.exit(0)
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Send initial status request
    print("READY")
    sys.stdout.flush()
    
    time.sleep(0.5)
    
    # Get initial state
    log("Getting initial Neovim state...", "INIT")
    monitor.send_tool_request("getOpenEditors")
    time.sleep(0.2)
    monitor.send_tool_request("getCurrentSelection")
    
    # Start interactive menu
    try:
        monitor.interactive_menu()
    except KeyboardInterrupt:
        pass
    
    log("Monitor stopped", "INFO")

if __name__ == "__main__":
    main()