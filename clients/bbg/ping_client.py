import asyncio
import websockets
import ssl
import time
import datetime as dt
import argparse

parser = argparse.ArgumentParser(description="Ping client")
parser.add_argument("--uri", type=str, default="ws://localhost:7008")
parser.add_argument("output_file", type=str, default="ping_times.txt")
args = parser.parse_args()
uri = string(args.uri)
output_file = string(args.output_file)


async def ping_forever():
    # open text file for writing
    with open(output_file, "w", buffering = 1) as file: # line level buffering
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
