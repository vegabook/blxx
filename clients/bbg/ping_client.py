import asyncio
import websockets
import time

async def ping_forever():
    uri = "ws://80.64.218.175:8080"
    async with websockets.connect(uri) as websocket:
        while True:
            start_time = time.time()  # Record the time before sending "ping"
            await websocket.send("ping")
            await websocket.recv()
            end_time = time.time()  # Record the time after receiving "pong"
            
            rtt = end_time - start_time
            print(f"Round-Trip Time: {rtt:.3f} seconds")
            
            # Wait a bit before sending the next ping to avoid overwhelming the server
            await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(ping_forever())

