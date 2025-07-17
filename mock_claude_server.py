import asyncio
import websockets
import json
import logging

logging.basicConfig(filename='mock_server.log', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

async def handler(websocket, path):
    logging.info("Connection opened")
    try:
        # Send a tools/list request upon connection
        await websocket.send(json.dumps({
            "jsonrpc": "2.0",
            "method": "tools/list",
            "id": 1,
            "result": {
                "tools": [
                    {"name": "getCurrentSelection", "description": "Get the current text selection in the active editor"},
                    {"name": "getOpenEditors", "description": "Get information about currently open editors"}
                ]
            }
        }))
        logging.info("Sent tools/list to client")

        # Wait for messages from the client
        async for message in websocket:
            logging.info(f"Received message: {message}")
            data = json.loads(message)
            if data.get("method") == "tools/list":
                await websocket.send(json.dumps({
                    "jsonrpc": "2.0",
                    "id": data["id"],
                    "result": {
                        "tools": [
                            {"name": "getCurrentSelection", "description": "Get the current text selection in the active editor"},
                            {"name": "getOpenEditors", "description": "Get information about currently open editors"}
                        ]
                    }
                }))
                logging.info("Responded to tools/list request")
            elif data.get("method") == "getCurrentSelection":
                # Simulate a response for getCurrentSelection
                await websocket.send(json.dumps({
                    "jsonrpc": "2.0",
                    "id": data["id"],
                    "result": {
                        "success": True,
                        "text": "mock selection",
                        "filePath": "/mock/path/file.txt",
                        "selection": {"start": {"line": 0, "character": 0}, "end": {"line": 0, "character": 14}, "isEmpty": False}
                    }
                }))
                logging.info("Responded to getCurrentSelection request")

    except websockets.exceptions.ConnectionClosed:
        logging.info("Connection closed")
    except Exception as e:
        logging.error(f"Error in handler: {e}")

async def main():
    logging.info("Starting mock WebSocket server on ws://localhost:8765")
    async with websockets.serve(handler, "localhost", 8765):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())