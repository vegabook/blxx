import asyncio
import websockets

async def echo(websocket):
    async for message in websocket:
        if message == "ping":
            await websocket.send("pong")

async def main():
    async with websockets.serve(echo, "127.0.0.1", 4002):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())

