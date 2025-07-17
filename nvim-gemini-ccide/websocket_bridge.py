#!/usr/bin/env python3
"""
WebSocket bridge for Neovim Claude Code plugin
Communicates with Neovim via stdio and with Claude Code via WebSocket
"""

import sys
import json
import websocket
import threading
import time
from queue import Queue

class ClaudeWebSocketBridge:
    def __init__(self, port, auth_token):
        self.url = f"ws://127.0.0.1:{port}"
        self.auth_token = auth_token
        self.ws = None
        self.running = True
        self.send_queue = Queue()
        
    def connect(self):
        """Connect to Claude Code WebSocket server"""
        try:
            self.ws = websocket.WebSocketApp(
                self.url,
                header={"x-claude-code-ide-authorization": self.auth_token},
                on_message=self.on_message,
                on_error=self.on_error,
                on_close=self.on_close,
                on_open=self.on_open
            )
            
            # Run WebSocket in a separate thread
            wst = threading.Thread(target=self.ws.run_forever)
            wst.daemon = True
            wst.start()
            
            # Give it time to connect
            time.sleep(0.5)
            
            return True
        except Exception as e:
            self.send_to_nvim({
                "type": "error",
                "message": f"Failed to connect: {str(e)}"
            })
            return False
    
    def on_open(self, ws):
        """WebSocket opened"""
        self.send_to_nvim({
            "type": "connected",
            "message": "Connected to Claude Code"
        })
        
        # Start sender thread
        sender_thread = threading.Thread(target=self.sender_loop)
        sender_thread.daemon = True
        sender_thread.start()
    
    def on_message(self, ws, message):
        """Received message from Claude Code"""
        self.send_to_nvim({
            "type": "message",
            "data": message
        })
    
    def on_error(self, ws, error):
        """WebSocket error"""
        self.send_to_nvim({
            "type": "error",
            "message": str(error)
        })
    
    def on_close(self, ws, close_status_code, close_msg):
        """WebSocket closed"""
        self.running = False
        self.send_to_nvim({
            "type": "closed",
            "message": "Connection closed"
        })
    
    def send_to_nvim(self, data):
        """Send data to Neovim via stdout"""
        print(json.dumps(data))
        sys.stdout.flush()
    
    def send_to_websocket(self, message):
        """Queue message to send to WebSocket"""
        if self.ws and self.running:
            self.send_queue.put(message)
    
    def sender_loop(self):
        """Send queued messages to WebSocket"""
        while self.running:
            try:
                message = self.send_queue.get(timeout=0.1)
                if self.ws:
                    self.ws.send(message)
            except:
                continue
    
    def run(self):
        """Main loop - read from stdin and forward to WebSocket"""
        while self.running:
            try:
                line = sys.stdin.readline()
                if not line:
                    break
                
                # Parse command from Neovim
                try:
                    cmd = json.loads(line.strip())
                    if cmd.get("type") == "send":
                        self.send_to_websocket(cmd.get("data", ""))
                    elif cmd.get("type") == "close":
                        self.running = False
                        if self.ws:
                            self.ws.close()
                except json.JSONDecodeError:
                    pass
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                self.send_to_nvim({
                    "type": "error",
                    "message": f"Bridge error: {str(e)}"
                })
        
        self.running = False
        if self.ws:
            self.ws.close()

def main():
    if len(sys.argv) != 3:
        print(json.dumps({
            "type": "error",
            "message": "Usage: websocket_bridge.py <port> <auth_token>"
        }))
        sys.exit(1)
    
    port = int(sys.argv[1])
    auth_token = sys.argv[2]
    
    bridge = ClaudeWebSocketBridge(port, auth_token)
    
    if bridge.connect():
        bridge.run()
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()