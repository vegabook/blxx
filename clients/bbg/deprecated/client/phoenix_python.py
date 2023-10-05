# talk to phoenix channels from Python
# url: https://elixirforum.com/t/phoenix-channel-sending-messages-from-a-client-outside-the-project/1061/4
# another awesome resource for server side: https://github.com/dwyl/phoenix-chat-example

#!/usr/bin/env python
import asyncio
import websockets
import json

async def hello():
	async with websockets.connect('ws://127.0.0.1:4000/socket/websocket') as websocket:
		data = dict(topic="users:my_token", event="phx_join", payload={}, ref=None)
		await websocket.send(json.dumps(data))
		# print("joined")
		#greeting = await websocket.recv()
		print("Joined")
		while True:
			msg = dict(topic="users:my_token", event="shout", payload={"body":"tworitdash"}, ref=None)
			await websocket.send(json.dumps(msg))
			call = await websocket.recv()
			print("< {}".format(call))



if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(hello())
    asyncio.get_event_loop().run_forever()# talk to phoenix channels from Python
