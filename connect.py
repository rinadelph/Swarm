
import websocket
import json
import time
import threading

def on_message(ws, message):
    print(message)

def on_error(ws, error):
    print(error)

def on_close(ws, close_status_code, close_msg):
    print("### closed ###")

def on_open(ws):
    def run(*args):
        time.sleep(1)
        ws.send(json.dumps({"jsonrpc": "2.0", "method": "tools/list", "id": 1}))
        time.sleep(1)
        ws.close()
    thread = threading.Thread(target=run)
    thread.start()

if __name__ == "__main__":
    ws = websocket.WebSocketApp("ws://127.0.0.1:40145",
                              header={"x-claude-code-ide-authorization": "35b20821-2914-48d4-9998-1bbc66e2c5a2"},
                              on_message=on_message,
                              on_error=on_error,
                              on_close=on_close)
    ws.on_open = on_open
    ws.run_forever()
