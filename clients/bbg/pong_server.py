import asyncio
import websockets
import time
import argparse

parser = argparse.ArgumentParser(description="Pong server")
parser.add_argument("--port", type=int, default=7008)
args = parser.parse_args()
port = int(args.port)


async def echo(websocket):
    async for message in websocket:
        if message == "ping":
            print("Received ping", time.time())
            await websocket.send("pong")

async def main():
    async with websockets.serve(echo, "", port):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    while True:
        try:
            asyncio.run(main())
        except Exception as e:
            print(e)
            time.sleep(5)
            continue

