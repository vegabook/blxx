# blxx

Access the Bloomberg API from Elixir. Live and historic data. Suitable for terminal and B-Pipe users.  

This is a heavy work in progress. The Elixir-side API is under heavy experimental development and is not stable. 
All Bloomberg functionality however is now present, and can be perused for inspiration. 

* Ticker data request (streaming prices)
* Bar data request (streaming OHLC)
* HistoricalDataRequest (daily data)
* IntradayTickRequest (tick-by-tick data)
* IntradayBarRequest (minute or other periodicity OHLC bars)
* ReferenceDataRequest (security metadata, or one off price snapshots)
* instrumentListRequest (lookup securities by name)
* curveListRequest  (lookup curves by names)
* FieldListRequest (fields for an instrument / curve etc)
* FieldInfoRequest (lookup fields by name)
* studyRequest (technical analysis)

See the [Bloomberg API manual](https://data.bloomberglp.com/professional/sites/10/2017/03/BLPAPI-Core-Developer-Guide.pdf) for further information on these request types. 

### Instructions and usage

#### Concepts
The client is a Windows computer running a licenced Bloomberg terminal or BPIPE. The server is a computer running Linux or MacOS. _Unless you are licensed for BPIPE, these should be the same computer (with either client or server in virtual machine).  

#### Keys
Run `bbgfeeder.py --showkey` on the Windows client running BLoomberg Terminal / BPIPE, ensuring that environment variable `BLXXKEY` on the server contains this value. This is used for basic authentication. The fully qualified public key path can be manually specified with the `keypath` command line argument. 
If you wish to authorise more than one key, they should be separated by a colon `:` in the BLXXKEY environment variable. 


### Implementation
Blxx implements a raw websocket server using Phoenix Transport in Elixir (example [here](https://furlough.merecomplexities.com/elixir/phoenix/tutorial/2021/02/19/binary-websockets-with-elixir-phoenix.html)), which is connected to by a python process [`bbgfeeder.py`](/clients/bbg/bbgfeeder.py). Elixir can send subscription and historical data requests, and receive the responses from 
python which runs the offical Bloomberg [blpapi](https://www.bloomberg.com/professional/support/api-library/) client. 

### WIP.....
