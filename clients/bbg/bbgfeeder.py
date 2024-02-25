# bloomberg data feeder for elixir 

import time
import datetime as dt
import threading
from concurrent.futures import ProcessPoolExecutor
import msgpack
from queue import Queue, Empty
import asyncio
from websockets.client import connect as wsconnect
from websocket import create_connection
from argparse import ArgumentParser, RawTextHelpFormatter
import blpapi
import logging
import socket
import os
from sockauth import getKey
from collections import deque
import struct

from util.SubscriptionOptions import \
    addSubscriptionOptions, \
    setSubscriptionSessionOptions
from util.ConnectionAndAuthOptions import \
    addConnectionAndAuthOptions, \
    createSessionOptions
from concurrent.futures import TimeoutError as ConnectionTimeoutError

from colorama import Fore, Back, Style, init as colorinit; colorinit(autoreset=True)


# TODO ----------------------
# token auth websocket; paramterise websocket
# resubscribe every x hours
# change all snake case to camelcase
# check out MarketListSubscriptionExample

# -------------- global queues for communication between classes and handlers -------------

comq = Queue() # global que for commands
dataq = Queue() # global queue for data
stopevent = threading.Event() # will reset and retry
exitevent = threading.Event() # exits the program
subs = set()  # subscriptions
websocket = None # global websocket connection
buffdeque = deque([], maxlen = 100000)

# --------------- set logger ------------------------

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --------- dataq response message constants --------

RESP_INFO = "info"
RESP_REF = "refdata"
RESP_SUB = "subdata"
RESP_BAR = "bardata"
RESP_STATUS = "status"
RESP_ERROR = "error"
RESP_ACK = "ack"

# ------------- create default constants ------------

DEFAULT_QUEUE_SIZE = 10000
DEFAULT_SERVICE = "//blp/mktdata"
DEFAULT_TOPIC_PREFIX = "/ticker/"
DEFAULT_INTERVAL = 1 # change to number of seconds for slower 
DEFAULT_TOPIC = [] # put a ticker in here if you always want to receive it
DEFAULT_FIELDS = ["LAST_PRICE", "BID", "ASK"]
URLMASK = "wss://suprabonds.com/bbgws/{}/{}/websocket"

# ------------- debugging tools ---------------------
import functools

def intercept_await(coro, given_name):
    """Wrap a coroutine to intercept its await calls."""
    @functools.wraps(coro)
    async def wrapper(*args, **kwargs):
        # Perform actions before the original await
        print(f"Before await {given_name} {dt.datetime.now()}")

        # Await the original coroutine
        result = await coro(*args, **kwargs)

        # Perform actions after the original await
        print(f"After await {given_name} {dt.datetime.now()}")
        return result
    return wrapper

# can be used to wrap any async function to see when it's awaited
# if not await wrapped_ws_send("ping", retry_connect = True):

# ------------ parse the command line ---------------

def parseCmdLine():
    """Parse command line arguments"""
    parser=ArgumentParser(formatter_class=RawTextHelpFormatter,
                            description="Asynchronous subscription with event handler")
    addConnectionAndAuthOptions(parser)
    addSubscriptionOptions(parser)
    parser.add_argument(
        "-q",
        "--event-queue-size",
        dest="eventQueueSize",
        help="The maximum number of events that is buffered by the session (default: %(default)d)",
        type=int,
        metavar="eventQueueSize",
        default=DEFAULT_QUEUE_SIZE)
    parser.add_argument(
        "-k",
        "--keypath",
        dest="keypath",
        help="Fully qualified public key path",
        type=str)
    parser.add_argument(
        "--showkey",
        action="store_true",
        help=("Show public key in numeric format for auth. "
              "Must be put in BLXXKEY env variable on server"),
        default=False)
    options = parser.parse_args()
    options.options.append(f"interval={DEFAULT_INTERVAL}")
    return options

options = parseCmdLine()

# -------------- msgpack python datetime and time handler --------------

def datetime_packer(obj):
    """ converts dates and times tz aware for msgpack which needs tz """ 
    if isinstance(obj, (dt.datetime, dt.time)):
        # no timezone?
        if obj.tzinfo is None or obj.tzinfo.utcoffset(obj) is None:
            # add timezone
            obj = obj.replace(tzinfo=dt.timezone.utc)
        else:
            # convert to UTC
            obj = obj.astimezone(dt.timezone.utc)
    elif isinstance(obj, dt.date):
        obj=dt.datetime(obj.year, 
                          obj.month, 
                          obj.day, 
                          tzinfo=dt.timezone.utc)
    return obj

def dopack(obj):
    """ 
    non async msgpack runner func for pool 
    """
    pkd = msgpack.packb(obj, 
                        default=datetime_packer, 
                        use_bin_type=True, 
                        datetime=True)
    return pkd


async def msgpacker(obj, pool, trytimes = 3, dozetime = 0.01):
    """ 
    async msgpack using pool tries trytimes to pack data 
    otherwise returns None 
    """
    loop = asyncio.get_event_loop()
    tryi = 0
    while tryi < trytimes:
        try:
            datpacked = await loop.run_in_executor(pool, dopack, obj)
            return datpacked
        except Exception as e:
            tryi += 1
            logger.warn(f"Error packing data: {e} retry {tryi}")
            await asyncio.sleep(dozetime)
    logger.error(f"Could not msgpack {obj}")

    return None


def headerpack(msg: str, headerval: int):
    """
    prepends an 8-byte message header to msg. "Q" is C for 8 byte unsigned integer
    """
    return struct.pack("Q", headerval) + msg



# ---------------- check URL for localhost and display licence warning --------------------

def licenceCheck(url):
    hostname = url.split("://")[1].split("/")[0]
    ip = socket.gethostbyname(hostname)
    localip = socket.gethostbyname("localhost")
    if ip != localip:
        logger.warning((f"{Fore.MAGENTA}{Style.BRIGHT}\n"
                        f"{hostname=}\n"
                        f"{ip=}\n"
                        f"{localip=}{Fore.YELLOW}{Style.DIM}\n"
                        "-----------------------LICENCE WARNING------------------------\n"
                        "The websocket IP address provided is different from localhost.\n"
                        "The Bloomberg Terminal licence does not allow moving data off\n"
                        "the PC on which it is running. Please ensure that you have the\n"
                        "correct licence (BPIPE), or that the destination server is\n"
                        "running on a locally hosted virtual machine.\n"
                        "--------------------------------------------------------------"
                        f"{Style.RESET_ALL}"))


# ------------------------------- Sync Bloomberg Handlers ---------------------------------

def createSubscriptionList(tickers, fields, options):
    """
    create mktdata subscription list
    """
    subscriptions = blpapi.SubscriptionList()
    correls = {}
    fields_str = ",".join(fields)
    options_str = "&".join([f"{k.replace(' ', '_')}={v}" for k, v in options.items()])
    print(f"{options_str=}")
    print(f"{fields_str=}")
    for ticker in tickers:
        correlid = blpapi.CorrelationId(ticker)
        subscriptions.add(ticker, "LAST_PRICE", "interval=1", correlid)
        correls[ticker] = correlid
    return subscriptions, correls


class HistoricEventHandler(object):

    def getTimeStamp(self):
        return time.strftime("%Y-%m-%d %H:%M:%S")

    def processResponseEvent(self, event, partial):
        for msg in event:
            cid = msg.correlationId().value()
            logger.info((f"Received response to request {msg.getRequestId()} "
                        f"partial {partial}"))
            sendmsg = (RESP_REF, {"cid": cid, "partial": partial, "data": msg.toPy()})
            dataq.put(sendmsg)


    def processEvent(self, event, _session):
        eventType = event.eventType()
        # get request type from event

        if eventType == blpapi.Event.PARTIAL_RESPONSE:
            self.processResponseEvent(event, True)
        elif eventType == blpapi.Event.RESPONSE:
            self.processResponseEvent(event, False)
            done = True
        elif eventType == blpapi.Event.REQUEST_STATUS:
            for msg in event:
                if msg.messageType == blpapi.Names.REQUEST_FAILURE:
                    reason=msg.getElement("reason")
                    print(f"Request failed: {reason}")
                    done = True
            else:
                print("msg:", msg.messageType())


class SubscriptionEventHandler(object):

    def __init__(self): 
        pass

    def getTimeStamp(self):
        return time.strftime("%Y-%m-%d %H:%M:%S")

    def processSubscriptionStatus(self, event):
        timeStamp = self.getTimeStamp()
        for msg in event:
            pymsg = msg.toPy()
            topic = msg.correlationId().value()
            if msg.messageType() == blpapi.Names.SUBSCRIPTION_FAILURE:
                sendmsg = (RESP_STATUS, (str(msg.messageType()), topic, pymsg))
            elif msg.messageType() == blpapi.Names.SUBSCRIPTION_TERMINATED:
                correl = msg.correlationId().value()
                subs.remove(correl)
                print(f"!!!!!!! sub terminated for {correl}") # DEBUG
                stopevent.set() # DEBUG
                sendmsg = (RESP_STATUS, (str(msg.messageType()), topic, pymsg))
            elif msg.messageType() == blpapi.Names.SUBSCRIPTION_STARTED:
                correl = msg.correlationId().value()
                subs.add(correl)
                sendmsg = (RESP_STATUS, (str(msg.messageType()), topic, pymsg))
            else:
                sendmsg = (RESP_STATUS, (str(msg.messageType()), topic, pymsg))
            dataq.put(sendmsg)

    def searchMsg(self, msg, fields):
        return [{"field": field, "value": msg[field]} 
                for field in fields if msg.hasElement(field)]

    def makeBarMessage(self, msg, msgtype, topic, interval):
        msgdict = {"msgtype": msgtype, "topic": topic, "interval": interval}
        for f, m in {"open": "OPEN", 
                     "high": "HIGH", 
                     "low": "LOW", 
                     "close": "CLOSE", 
                     "volume": "VOLUME", 
                     "numticks": "NUMBER_OF_TICKS",
                     "timestamp": "DATE_TIME"}.items():
            if msg.hasElement(m):
                msgdict[f] = msg[m]
            else:
                msgdict[f] = None

        return msgdict

    def processSubscriptionDataEvent(self, event):
        """ 
        process subsription data message and put on data queue 
        """
        timestamp = self.getTimeStamp()
        timestampdt = dt.datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S')
        for msg in event:
            fulltopic = msg.correlationId().value()
            topic = fulltopic.split("/")[-1] # just ticker
            msgtype = msg.messageType()
            # bars --->
            if msgtype in (blpapi.Name("MarketBarUpdate"),
                           blpapi.Name("MarketBarStart"),
                           blpapi.Name("MarketBarEnd"),
                           blpapi.Name("MarketBarIntervalEnd")):
                sendmsg = (RESP_BAR, self.makeBarMessage(msg, str(msgtype), 
                                                          topic, interval = 1))
                dataq.put(sendmsg)

            # subscription --->
            elif msgtype == blpapi.Name("MarketDataEvents"):
                # mktdata event type
                sendmsg = (RESP_SUB, 
                       {"timestamp": timestampdt, 
                       "topic": topic,
                       "prices": self.searchMsg(msg, DEFAULT_FIELDS)})
                dataq.put(sendmsg)

            # something else --->
            else:
                logger.warning(f"Unknown message type {msgtype}")
                breakpoint()

    def processMiscEvents(self, event):
        for msg in event:
            sendmsg = (RESP_STATUS, str(msg.messageType()))
            dataq.put(sendmsg) 

    def processEvent(self, event, _session):
        """ event processing selector """
        try:
            if event.eventType() == blpapi.Event.SUBSCRIPTION_DATA:
                self.processSubscriptionDataEvent(event)
            elif event.eventType() == blpapi.Event.SUBSCRIPTION_STATUS:
                self.processSubscriptionStatus(event)
            else:
                self.processMiscEvents(event)
        except blpapi.Exception as e:
            print(f"Failed to process event {event}: {e}")
        return False


class BbgRunner():
    """
    parses commands and dispatches requests
    """

    def __init__(self):

        self.subservices = {"services": {"Subscribe": "//blp/mktdata",
                                         "UnSubscribe": "//blp/mktdata",
                                         "BarSubscribe": "//blp/mktbar",
                                         "BarUnSubscribe": "//blp/mktbar",
                                         "TaSubscribe": "//blp/tasvc"}}
        self.refservices = {"services": {"HistoricalDataRequest": "//blp/refdata",
                                         "IntradayBarRequest": "//blp/refdata",
                                         "IntradayTickRequest": "//blp/refdata",
                                         "ReferenceDataRequest": "//blp/refdata",
                                         "instrumentListRequest": "//blp/instruments", # terminal SECF
                                         "curveListRequest": "//blp/instruments",      # terminal CRVF
                                         "govtListRequest": "//blp/instruments",
                                         "FieldListRequest": "//blp/apiflds",
                                         "FieldSearchRequest": "//blp/apiflds",
                                         "FieldInfoRequest": "//blp/apiflds",
                                         "CategorizedFieldSearchRequest": "//blp/apiflds",
                                         "studyRequest": "//blp/tasvc",
                                         "SnapshotRequest": "//blp/mktlist"}} # mktlist I think is a sub TODO

        options.topics = [] # options was parsed globally
        options.fields = DEFAULT_FIELDS

        # ---------- subscription data session -----------------
        sessionOptions = createSessionOptions(options)
        setSubscriptionSessionOptions(sessionOptions, options)
        sessionOptions.setMaxEventQueueSize(options.eventQueueSize)
        sessionOptions.setDefaultSubscriptionService("//blp/mktdata")
        handler = SubscriptionEventHandler()
        self.subservices["session"] = blpapi.Session(sessionOptions, 
                                                     eventHandler=handler.processEvent)

        if not self.subservices["session"].start():
            logger.error("Failed to start subdata session.")
            stopevent.set()
            return

        for servstring in set(self.subservices["services"].values()):
            if not self.subservices["session"].openService(servstring):
                logger.error(f"Failed to open {servstring} service.")
                stopevent.set()
                exitevent.set()
                return
            logger.info(f"Started {servstring} service.")

        # ----------- reference and instruments data session -----------
        roptions = sessionOptions # copy command line options 
        roptions.setDefaultSubscriptionService("//blp/refdata")
        # run a dispatcher with 3 threads as some refdata messages are large
        self.rdispatcher = blpapi.EventDispatcher(numDispatcherThreads=3) 
        self.rdispatcher.start()
        rhandler = HistoricEventHandler()
        self.refservices["session"] = blpapi.Session(roptions, 
                                                     eventHandler=rhandler.processEvent, 
                                                     eventDispatcher=self.rdispatcher)

        if not self.refservices["session"].start():
            logger.error("Failed to start refdata session.")
            stopevent.set()
            return

        for servstring in set(self.refservices["services"].values()):
            if not self.refservices["session"].openService(servstring):
                logger.error(f"Failed to open {servstring} service.")
                stopevent.set()
                return
            logger.info(f"Started {servstring} service.")


    def sendInfo(self, command, request):
        """ sends back structure information about the request """
        desc = request.asElement().elementDefinition()
        strdesc = desc.toString()
        sendmsg = (RESP_INFO, {"request_type": command, "structure": strdesc})
        dataq.put(sendmsg)

    def sendAck(self, cid):
        sendmsg = (RESP_ACK, {"cid": cid})
        dataq.put(sendmsg)


    def sendError(self, command, payld, errmsg, errdetail = None):
        sendmsg = (RESP_ERROR, {"command": command,
                                "payld": payld,
                                "error": (errmsg, errdetail)})
        dataq.put(sendmsg)


    def commandErrors(self, com):
        try:
            command, cid_l, payld = com
            cid = tuple(cid_l)
        except:
            return ("error", "Could not parse command or payload")
        if type(command) != str:
            return ("error", "Command must be a string")
        if command not in self.subservices["services"] \
                and command not in self.refservices["services"]:
            return ("error", f"Unknown command {command}")
        return None


    def payldErrs(self, command, payld):
        if command in ("Subscribe", "BarSubscribe"):
            if len(payld) != 3:
                return ("error", "Subscription payload must have 3 elements")
            topics, fields, options = (payld["topics"], payld["fields"], payld["options"])
            # check for lists
            if type(topics) != type([]):
                return ("error", "First item (topics) must be a list")
            if type(fields) != type([]):
                return ("error", "Second item (fields) must be a list")
            if type(options) != type({}):
                return ("error", "Third item (options) must be a map")
            if command == "BarSubscribe":
                if len(fields) != 1 or fields[0] != "LAST_PRICE":
                    return ("error", ("For BarSubscribe fields must contain "
                    "one element LAST_PRICE"))
        return None


    def listServices(self):
        """ list all services across session """
        services = {}
        for s in [self.subservices, self.refservices]:
            session = s["session"]
            for servstring in set(s["services"].values()):
                services[servstring] = []
                service = session.getService(servstring)
                for operation in service.operations():
                    services[servstring].append(operation.name())
        return services


    def comloop(self):
        """ command handling main loop """
        global subs # allow re-assignment to empty set
        logger.info(f"{Fore.GREEN}Running bbg feeder{Style.RESET_ALL}")
        try:
            # continuously monitor command queue
            while not stopevent.is_set():      
                try:
                    com = comq.get(timeout = 0.5)
                    logger.info(f"Bloomberg thread received command {com}")
                except Empty:
                    continue

                # check msg for errors 
                if (comerr := self.commandErrors(com)) is not None:
                    self.sendError(None, None, comerr[1])
                    continue

                command, cid, payld = com

                # check payload for errors 
                if (perr := self.payldErrs(command, payld)) is not None:
                    self.sendError(command, payld, perr[1])
                    continue

                # ---------------- subscription -------------

                if command in ("Subscribe", "BarSubscribe"):
                    # parse the command and check validity
                    topics, fields, options = (payld["topics"], payld["fields"], payld["options"])
                    if command == "Subscribe":
                        # add qualifiers if full topic not provided
                        strtopics = [topic if "//" in topic else "//blp/mktdata/ticker/" + topic 
                                     for topic in topics]
                    elif command == "BarSubscribe":
                        strtopics = [topic if "//" in topic else "//blp/mktbar/ticker/" + topic 
                                     for topic in topics]

                    # check no duplicate subs and subscribe
                    us = [s.upper() for s in subs]
                    newsubs = [t for t in strtopics if t.upper() not in us]
                    alreadysubs = [t for t in strtopics if t.upper() in us]
                    if newsubs:
                        logger.info(f"Subscribing to {newsubs}")
                        sub, correls = createSubscriptionList(newsubs, fields, options)
                        self.subservices["session"].subscribe(sub)
                    else:
                        logger.info(f"No new subscriptions in {payld}")
                    if alreadysubs:
                        logger.info(f"Already subscribed to {alreadysubs}")
                        for t in alreadysubs:
                            self.sendError(command, payld, "Duplicate subscription", t)


                elif command == "ListSubscriptions":
                    sendmsg = (RESP_INFO, {"Subscriptions": list(subs)})
                    dataq.put(sendmsg)
                
                elif command == "UnSubscribeAll":
                    # TODO fix fields and options here
                    if subs:
                        unss = blpapi.SubscriptionList()
                        for c in subs:
                            unss.add(c)
                        self.subservices["session"].unsubscribe(unss)
                        subs = set()
                        logger.info("Unsubscribed all")
                    else:
                        logger.info("No subscriptions to unsubscribe")
                        self.sendError(command, payld, "No subscriptions to unsubscribe")


                # ---------------- request/response ----------------

                elif command in self.refservices["services"]:
                    self.sendAck(cid)
                    rservice = self.refservices["session"] \
                            .getService(self.refservices["services"][command])
                    rrequest = rservice.createRequest(command)
                    if payld == "info": 
                        self.sendInfo(command, rrequest)
                    else:
                        try: 
                            rrequest.fromPy(payld)
                            cid_bbg = blpapi.CorrelationId(cid)
                            # bid = rrequest.getRequestId() # not used for now
                            self.refservices["session"].sendRequest(rrequest, correlationId=cid_bbg)
                        except Exception as e:
                            logger.error(e)
                            self.sendError(command, payld, str(e))

                else:
                    logger.error("Unrecognised request")
                    self.sendError(command, payld, "Unrecognised request")

        except KeyboardInterrupt:
            stopevent.set()
        finally:
            stopevent.set() # if we're ending here, everything must end
            self.subservices["session"].stop()
            self.refservices["session"].stop()
            self.rdispatcher.stop()
            logger.info(f"{Fore.RED}{Style.BRIGHT}Closed bbg sessions.{Style.RESET_ALL}")


# ------------------------------ Async area ------------------------------------


async def com_dispatcher():
    """ 
    listens to websocket and dispatches commands
    """
    logger.info("Hello com_dispatcher")
    loop = asyncio.get_event_loop()
    while not stopevent.is_set():
        try:
            compack = await asyncio.wait_for(websocket.recv(), timeout=1)
        except: 
            compack = None
        if compack is not None:
            try:
                # unpack doesn't use pool because commands are small
                # compare to data_forwarder 
                command = msgpack.unpackb(compack, timestamp=3)
            except:
                logger.error("Msgpack command deserialization failed")
                command = None
            if command is not None:
                if command[0] == "pong":
                    pass
                else:
                    logger.info(f"{Fore.YELLOW}Command {Style.BRIGHT}{command}{Style.RESET_ALL}")
                    await loop.run_in_executor(None, comq.put, command) # async put in sync queue


async def data_forwarder(pool):
    """ 
    returns messages back through websocket from bbgrunner, and event handlers
    """
    logger.info("Hello data_forwarder")
    loop = asyncio.get_event_loop()
    while not stopevent.is_set():
        try:
            # defaul thread pool executor (None) means can await non async queue
            dat = await loop.run_in_executor(None, dataq.get, True, 1)
            tag = dat[0]
        except Empty:
            dat = None
        if dat is not None:
            # potentially expensive msgpack operation in process pool
            datpacked = await msgpacker(dat, pool)
            if datpacked is not None:
                # Add message header to communicate if it's a large reference response
                if tag == RESP_REF or tag == RESP_ACK:
                    headerpacked = headerpack(datpacked, 1)
                else:
                    headerpacked = headerpack(datpacked, 2)
                await ws_send(headerpacked, retry_connect = False) # retry_connect handled by ping


async def connected(urlmask = URLMASK, reconnection_count = 3, wait_time = 1):
    """ authenticate with server side websocket
    * send public key pem encoded from usual location on Windows or Linux 
    * wait for challenge string encoded with public key from remote
    * decode challenge 
    * send it back
    * wait to see if authed. 
    """
    global websocket
    id = os.getlogin().replace(" ", "_")
    key = getKey(private = False,
                 keypath = options.keypath).public_numbers().n
    url = urlmask.format(id, key)
    connection_count = reconnection_count
    while True:
        try:
            websocket = await asyncio.wait_for(wsconnect(url), 1) # timeout 1 second
            logger.info(f"Connected")
            return True
        except asyncio.TimeoutError:
            connection_count -= 1
            logger.warning(f"Connection attempt timed out. Reconnection attempts left: {connection_count}")
            await asyncio.sleep(wait_time)
        except Exception as e:
            connection_count -= 1
            logger.warning(f"Connection attempt failed with error {e}. Reconnection attempts left: {connection_count}")
            await asyncio.sleep(wait_time)
        if connection_count == 0:
            return False


async def ws_send(msg, retry_connect = False):
    """
    send a message to the websocket and if it fails
    try to reconnect
    """
    buffdeque.appendleft(msg) 
    while len(buffdeque) > 0:
        if not websocket.open:
            if retry_connect:
                await connected(URLMASK, 20, 3)
            else:
                success = False
                break
        try:
            await websocket.send(buffdeque.pop())
            success = True
        except Exception as e:
            buffdeque.clear()
            logger.warning(f"Websocket send failed with error {e}. Buffer cleared")
            success = False
    return success


async def main():
    """
    * Setup all async tasks, processs pool, bloomberg threads.
    * Continuously try to connect out.
    * If connected break on ping fail or bloomberg thread fail then retrsdf:1y
    connection
    """
    global subs
    global websocket
    licenceCheck(URLMASK)
    while not exitevent.is_set():
        buffdeque.clear() # empty buffer
        subs = set() # empty subscriptions
        stopevent.clear() # ensure stopevent unset
        with ProcessPoolExecutor(max_workers=3) as pool:
            # connect and auth
            con_success = await connected(URLMASK, 3, 1)
            while not con_success:
                logger.info("Failed to connect, retrying")
                await asyncio.sleep(1)
                con_success = await connected(URLMASK, 3, 1)
            # when success on getting a websocket, now create all the tasks
            comtask = asyncio.create_task(com_dispatcher())
            datatask = asyncio.create_task(data_forwarder(pool))
            bbgrunner = BbgRunner()
            bbgthread = threading.Thread(target=bbgrunner.comloop, args=(), daemon=True)
            bbgthread.start()
            # ping loop
            try:
                while True:
                    await asyncio.sleep(0.5) # ping every x seconds
                    if not await ws_send("ping", retry_connect = True): 
                        logger.error("ping failed")
                        break
                    if not bbgthread.is_alive():
                        logger.error("Bloomberg thread died")
                        break
            except Exception as e:
                logger.error(f"ping loop error {e}")
                break
            finally: 
                stopevent.set()
                await websocket.close()
                await comtask
                await datatask
                bbgthread.join()
        await asyncio.sleep(1)


if __name__ == "__main__":
    if options.showkey:
        print(getKey(private = False, 
                     keypath = options.keypath).public_numbers().n)
    else:
        asyncio.run(main())

    

