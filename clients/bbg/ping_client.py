import asyncio
import websockets
import ssl
import time
import datetime as dt
import argparse
from sockauth import getKey

URLMASK = "wss://suprabonds.com/bbgws/{}/{}/websocket"

parser = argparse.ArgumentParser(description="Ping client")
parser.add_argument("--uri", type=str, default="ws://localhost:7008")
parser.add_argument("--output_file", type=str, default="ping_times.txt")
# interger milliseconds
parser.add_argument("--milliseconds", type=int, default=1000)
parser.add_argument("--sample_hours", type=float, default=12)
parser.add_argument("--blxx", action="store_true", default=False)
args = parser.parse_args()
uri = str(args.uri)
milliseconds = int(args.milliseconds)
sample_hours = float(args.sample_hours)
output_file = str(args.output_file)

async def ping_forever():
    # open text file for writing
    finish_time = dt.datetime.now() + dt.timedelta(hours = sample_hours)
    ping_times = []
    # if we are connecting to the elixir blxx server as opposed to pong_server then
    # we need to get a key and also an id
    if args.blxx:
        key = getKey(private = False,
                     keypath = None).public_numbers().n
        uri = URLMASK.format("blxx", key)
    else:
        uri = str(args.uri)
    print(f"Connecting to {uri}")
    async with websockets.connect(uri = uri) as websocket:
        while True:
            start_time = time.perf_counter()  # Record the time before sending "ping"
            await websocket.send("ping")
            await websocket.recv()
            end_time = time.perf_counter()  # Record the time after receiving "pong"

            rtt = end_time - start_time
            str1 = f"{dt.datetime.utcnow()} Round-Trip Time: {rtt:.5f} seconds, connection is {websocket.open}"
            print(str1)
            ping_times.append(str1)

            # Wait a bit before sending the next ping to avoid overwhelming the server
            await asyncio.sleep(milliseconds / 1000)
            if dt.datetime.now() > finish_time:
                break
    with open(output_file, "w", buffering = 1) as file: # line level buffering
        for ping in ping_times:
            write_string = f"{ping}\n"
            file.write(write_string)
    print(f"Output written to {output_file}")

if __name__ == "__main__":
    while True:
        try:
            asyncio.run(ping_forever())
        except Exception as e:
            print(e)
            time.sleep(5)
            continue

