import asyncio
import websockets
import ssl
import time
import datetime as dt

async def ping_forever():
    uri = "ws://80.64.218.175:7008"
    # open text file for writing
    with open("ping_times_direct_logicLHR_from_Win11.txt", "w", buffering = 1) as file: # line level buffering
        async with websockets.connect(uri = uri) as websocket:
            while True:
                start_time = time.perf_counter()  # Record the time before sending "ping"
                await websocket.send("ping")
                await websocket.recv()
                end_time = time.perf_counter()  # Record the time after receiving "pong"

                rtt = end_time - start_time
                str1 = f"{dt.datetime.utcnow()} Round-Trip Time: {rtt:.5f} seconds"
                print(str1)
                file.write(str1 + "\n")

                # Wait a bit before sending the next ping to avoid overwhelming the server
                await asyncio.sleep(1)

if __name__ == "__main__":
    asyncio.run(ping_forever())
