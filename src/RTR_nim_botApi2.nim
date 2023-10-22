import std/[os, locks, strutils]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schema, Bot]

export Schema, Bot

# globals
var
  botWorker_connectedLock:Lock
  intentWorker_connectedLock:Lock
  connectedCond:Cond
  runningLock:Lock
  runningCond:Cond
  messagesSeqLock:Lock

proc handleMessage(bot:Bot, json_message:string) =
  # Convert the json to a Message object
  let message = json2schema json_message

  # 'case' switch over type
  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message
    let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.name, version:bot.version, authors:bot.authors, secret:bot.secret, initialPosition:bot.initialPosition)
    # waitFor bot.gs_ws.send(bot_handshake.toJson)
    {.locks: [messagesSeqLock].}: bot.messagesToSend.add(bot_handshake.toJson)
    
    # signal the threads that the connection is ready
    bot.connected = true
    {.locks: [botWorker_connectedLock].}: broadcast connectedCond

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    bot.gameSetup = game_started_event_for_bot.gameSetup
    bot.myId = game_started_event_for_bot.myId

    # activating the bot method
    bot.onGameStarted(game_started_event_for_bot)
    
    # send bot ready
    # waitFor bot.gs_ws.send(BotReady(`type`:Type.botReady).toJson)
    {.locks: [messagesSeqLock].}: bot.messagesToSend.add(BotReady(`type`:Type.botReady).toJson)

  of tickEventForBot:
    let tick_event_for_bot = (TickEventForBot)message
    bot.botState = tick_event_for_bot.botState

    bot.turnNumber = tick_event_for_bot.turnNumber
    bot.roundNumber = tick_event_for_bot.roundNumber

    # activating the bot method
    bot.onTick(tick_event_for_bot)

    # for every event inside this tick call the relative event for the bot
    for event in tick_event_for_bot.events:
      case parseEnum[Type](event["type"].getStr()):
      of Type.botDeathEvent:
        # if the bot is dead we stop it
        stop bot

        # Notifiy the bot that it is dead
        bot.onDeath(fromJson($event, BotDeathEvent))
      of Type.botHitWallEvent:
        bot.onHitWall(fromJson($event, BotHitWallEvent))
      of Type.bulletHitBotEvent:
        # conversion from BulletHitBotEvent to HitByBulletEvent
        let hit_by_bullet_event = fromJson($event, HitByBulletEvent)
        hit_by_bullet_event.`type` = Type.hitByBulletEvent
        bot.onHitByBullet(hit_by_bullet_event)
      of Type.botHitBotEvent:
        bot.onHitBot(fromJson($event, BotHitBotEvent))
      of Type.scannedBotEvent:
        bot.onScannedBot(fromJson($event, ScannedBotEvent))        
      else:
        echo "NOT HANDLED BOT TICK EVENT: ", event

    
    # send intent
  of gameAbortedEvent:
    stop bot

    let game_aborted_event = (GameAbortedEvent)message

    # activating the bot method
    bot.onGameAborted(game_aborted_event)

  of gameEndedEventForBot:
    stop bot

    let game_ended_event_for_bot = (GameEndedEventForBot)message

    # activating the bot method
    bot.onGameEnded(game_ended_event_for_bot)

  of skippedTurnEvent:
    let skipped_turn_event = (SkippedTurnEvent)message
    
    # activating the bot method
    bot.onSkippedTurn(skipped_turn_event)

  of roundEndedEventForBot:
    stop bot

    let round_ended_event_for_bot = json_message.fromJson(RoundEndedEventForBot)

    # activating the bot method
    bot.onRoundEnded(round_ended_event_for_bot)

  of roundStartedEvent:
    # Start the bot
    start bot

    # notify the bot that the round is started
    {.locks: [runningLock].}: broadcast runningCond

    let round_started_event = (RoundStartedEvent)message

    # activating the bot method
    bot.onRoundStarted(round_started_event)

  else: echo "NOT HANDLED MESSAGE: ",json_message

# template `logout`* (bot:Bot, x:string) =
#   stdout.writeLine(x)
#   # stdout.flushFile
#   bot.intent.stdOut &= x & "\n"

# template `logerr`* (bot:Bot, x:string) =
#   stderr.writeLine(x)
#   # stderr.flushFile
#   bot.intent.stdErr &= x & "\n"

var lastIntent_turn:int = -1
proc go*(bot:Bot) =
  # Sending intent to server if the last turn we sent it is different from the current turn
  if bot.turnNumber == lastIntent_turn: return

  # update the last turn we sent the intent
  lastIntent_turn = bot.turnNumber

  # build the intent to send to the game server
  bot.intent = BotIntent(`type`: Type.botIntent)

  # signal to send the intent to the game server
  # {.locks: [intentLock].}: broadcast intentCond
  # waitFor bot.gs_ws.send(schema2json bot.intent)
  {.locks: [messagesSeqLock].}: bot.messagesToSend.add(bot.intent.toJson)

proc botWorker(bot:Bot) {.thread.} =
  bot.botReady = true
  echo "[botWorker] READY!"

  # While the bot is connected to the server the bot thread should live
  echo "[botWorker] waiting for connection"
  wait connectedCond, botWorker_connectedLock

  while bot.connected:
    echo "[botWorker] waiting for running"
    # First is waiting doing nothing for the bot to be in running state
    wait runningCond, runningLock

    # Second run the bot 'run()' method, the one scripted by the bot creator
    # this could be going in loop until the bot is dead or could finish up quickly or could be that is not implemented at all
    run bot

    echo "[botWorker] automatic GO started"
    # Third, when the bot creator's 'run()' exits, if the bot is still runnning, we send the intent automatically
    while isRunning(bot):
      go bot
    echo "[botWorker] isRunning(bot): ", isRunning(bot)
    echo "[botWorker] bot.connected: ", bot.connected

    echo "[botWorker] automatic GO ended"
  echo "[botWorker] QUIT"

proc conectionHandler(bot:Bot) {.async.} =
  try:
    var ws = await newWebSocket(bot.serverConnectionURL)
    echo "[conectionHandler] connected..."

    proc writer() {.async.} =
      ## Loops while socket is open, looking for messages to write
      while ws.readyState == Open:
        # if there are chat message we have not sent yet
        # send them
        {.locks: [messagesSeqLock].}:
          while bot.messagesToSend.len > 0:
            let message = bot.messagesToSend.pop()
            await ws.send(message)

        # keep the async stuff happy we need to sleep some times
        await sleepAsync(1)

    proc reader() {.async.} =
      # Loops while socket is open, looking for messages to read
      while ws.readyState == Open:
        # this blocks
        var packet = await ws.receiveStrPacket()

        if packet.isEmptyOrWhitespace(): continue

        handleMessage(bot, packet)

    # start a async fiber thingy
    asyncCheck writer()
    await reader()

  except WebSocketClosedError:
    echo "Socket closed. "
  except WebSocketProtocolMismatchError:
    echo "Socket client tried to use an unknown protocol: ",
        getCurrentExceptionMsg()
  except WebSocketError:
    echo "Unexpected socket error: ", getCurrentExceptionMsg()

# proc conectionHandler(bot:Bot) {.async.} =
#   try:
#     bot.gs_ws = await newWebSocket(bot.serverConnectionURL)

#     echo "[conectionHandler] starting the connection handler loop"
#     while bot.gs_ws.readyState == Open:
#       echo "[conectionHandler] waiting for message"
#       let json_message = await bot.gs_ws.receiveStrPacket()
#       echo "[conectionHandler] message received"  
      
#       # GATE:as the message is received we if is empty or similar useless message
#       if json_message.isEmptyOrWhitespace(): continue

#       asyncCheck handleMessage(bot, json_message)
#       await sleepAsync(1)
#   except CatchableError:
#     echo "[conectionHandler] WebSocketError: ", getCurrentExceptionMsg()

proc startBot*(bot:Bot, connect:bool = true, position:InitialPosition = InitialPosition(x:0,y:0,angle:0)) =
  ## **Start the bot**
  ## 
  ## This method is used to start the bot instance. This coincide with asking the bot to connect to the game server
  ## 
  ## `bot` is the new and current bot istance
  ## 
  ## `connect` (can be omitted) is a boolean value that if `true` (default) will ask the bot to connect to the game server.
  ## If `false` the bot will not connect to the game server. Mostly used for testing.
  ## 
  ## `position` (can be omitted) is the initial position of the bot. If not specified the bot will be placed at the center of the map.
  ## This custom position will work if the server is configured to use the custom initial positions
  
  # set the initial position, is the server that will decide to use it or not
  bot.initialPosition = position

  # init the locks and conditions
  initLock botWorker_connectedLock
  initLock intentWorker_connectedLock
  initCond connectedCond
  initLock runningLock
  initCond runningCond
  initLock messagesSeqLock

  # connect to the Game Server
  if(connect):
    if bot.secret == "":
      bot.secret = getEnv("SERVER_SECRET", "serversecret")

    if bot.serverConnectionURL == "": 
      bot.serverConnectionURL = getEnv("SERVER_URL", "ws://localhost:7654")

    # runners for the 3 main threads
    var
      botRunner: Thread[bot.type]

    # create the threads
    {.locks: [botWorker_connectedLock, runningLock].}: createThread botRunner, botWorker, bot

    # wait for the threads to be ready
    echo "[startBot] waiting for bot and intent threads to be ready"
    while not bot.botReady and not bot.intentReady: sleep(100)
    echo "[startBot] bot threads are ready: ", bot.botReady, " ", bot.intentReady

    # connect to the server
    waitFor conectionHandler bot

    # Waiting for the bot thread to finish
    joinThreads botRunner

  deinitLock botWorker_connectedLock
  deinitLock intentWorker_connectedLock
  deinitCond connectedCond
  deinitLock runningLock
  deinitCond runningCond
  deinitLock messagesSeqLock
    
  echo "[startBot]connection ended and bot thread finished. Bye!"
