# blxx

Access the Bloomberg API from Elixir. Live and historic data. Suitable for terminal and B-Pipe users.  

This is a heavy work in progress. However it does now handle live subscriptions which show up as constantly updating streams. Also all the historic reference request types are catered for amongst others:

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
Full documentation incoming. 

### Implementation
Blxx implements a raw websocket server using Phoenix Transport in Elixir (example [here](https://furlough.merecomplexities.com/elixir/phoenix/tutorial/2021/02/19/binary-websockets-with-elixir-phoenix.html)), which is connected to by a python process [`bbgfeeder.py`](/clients/bbg/bbgfeeder.py). Elixir can send subscription and historical data requests, and receive the responses from 
python which runs the offical Bloomberg [blpapi](https://www.bloomberg.com/professional/support/api-library/) client. 


