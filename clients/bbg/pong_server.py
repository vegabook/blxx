import asyncio
import websockets
import time

async def echo(websocket):
    async for message in websocket:
        if message == "ping":
            print("Received ping", time.time())
            await websocket.send("pong")

async def main():
    async with websockets.serve(echo, "", 7008):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())

