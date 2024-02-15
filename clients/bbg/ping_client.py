import asyncio
import websockets
import ssl
import time
import datetime as dt
import argparse

parser = argparse.ArgumentParser(description="Ping client")
parser.add_argument("--uri", type=str, default="ws://localhost:7008")
parser.add_argument("--output_file", type=str, default="ping_times.txt")
# interger milliseconds
parser.add_argument("--milliseconds", type=int, default=1000)
parser.add_argument("--sample_hours", type=float, default=12)
args = parser.parse_args()
uri = str(args.uri)
milliseconds = int(args.milliseconds)
sample_hours = float(args.sample_hours)
output_file = str(args.output_file)

async def ping_forever():
    # open text file for writing
    finish_time = dt.datetime.now() + dt.timedelta(hours = sample_hours)
    ping_times = []
    async with websockets.connect(uri = uri) as websocket:
        while True:
            start_time = time.perf_counter()  # Record the time before sending "ping"
            await websocket.send("ping")
            await websocket.recv()
            end_time = time.perf_counter()  # Record the time after receiving "pong"

            rtt = end_time - start_time
            str1 = f"{dt.datetime.utcnow()} Round-Trip Time: {rtt:.5f} seconds"
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
    asyncio.run(ping_forever())
