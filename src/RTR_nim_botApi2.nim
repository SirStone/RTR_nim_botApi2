import std/[os, locks, strutils, math]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schemas, Bot]

export Schemas, Bot

# globals
var botWorkerChan:Channel[string]
var skipped = 0

# proc to b eused as logging stuff in the stdout
proc log*(bot:Bot, msg:string) =
  stdout.writeLine "[" & bot.name & ".log] " & msg
  stdout.flushFile

proc console_log*(bot:Bot, msg:string) =
  stdout.writeLine msg
  stdout.flushFile
  bot.intent.stdOut.add(msg)

proc setConnectionParameters*(bot:Bot, serverConnectionURL:string, secret:string) =
  ## **Set the connection parameters**
  ## 
  ## This method is used to set the connection parameters for the bot to connect to the game server.
  ## 
  ## `serverConnectionURL` is the url of the game server
  ## 
  ## `secret` is the secret required by the server to connect
  ## 
  ## Example:
  ## 
  ## ```nim
  ## setConnectionParameters("ws://localhost:1234", "botsecretcode")
  ## ```
  ## 
  ## This method is optional. If not called the bot will use the default values of `ws://localhost` and `7654`
  ## 
  ## This method must be called before `startBot()`
  ## 
  ## This method is mostly used for testing
  bot.serverConnectionURL = serverConnectionURL
  bot.secret = secret

proc handleMessage(bot:Bot, json_message:string) =
  # Convert the json to a Message object
  let message = json2schema json_message

  # 'case' switch over type
  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message
    let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.name, version:bot.version, authors:bot.authors, secret:bot.secret, initialPosition:bot.initialPosition)
    {.locks: [messagesSeqLock].}: bot.messagesToSend.add(bot_handshake.toJson)
    # sendMessage_channel.send(bot_handshake.toJson)
    
    # signal the threads that the connection is ready
    bot.connected = true
    botWorkerChan.send("connected")

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    bot.gameSetup = game_started_event_for_bot.gameSetup
    bot.myId = game_started_event_for_bot.myId

    # activating the bot method
    bot.onGameStarted(game_started_event_for_bot)
    
    # send bot ready
    {.locks: [messagesSeqLock].}: bot.messagesToSend.add(BotReady(`type`:Type.botReady).toJson)
    # sendMessage_channel.send(BotReady(`type`:Type.botReady).toJson)

  of tickEventForBot:
    let tick_event_for_bot = (TickEventForBot)message

    if bot.first_tick:
      # Start the bot
      start bot

      turnRate_done = 0
      gunTurnRate_done = 0
      radarTurnRate_done = 0
      distance_done = 0

      # notify the bot that the round is started
      botWorkerChan.send("running")
    else:
      # if bot.name == "TEST BOT":
      #   echo "tick_event_for_bot.botState.direction: ", tick_event_for_bot.botState.direction, " bot.botState.direction: ", bot.botState.direction
      turnRate_done = tick_event_for_bot.botState.direction - bot.botState.direction
      turnRate_done = (turnRate_done + 540) mod 360 - 180

      gunTurnRate_done = tick_event_for_bot.botState.gunDirection - bot.botState.gunDirection
      gunTurnRate_done = (gunTurnRate_done + 540) mod 360 - 180

      radarTurnRate_done = tick_event_for_bot.botState.radarDirection - bot.botState.radarDirection
      radarTurnRate_done = (radarTurnRate_done + 540) mod 360 - 180

      distance_done = tick_event_for_bot.botState.speed

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
        # stop bot movement
        bot.setDistanceRemaining(0)

        bot.onHitWall(fromJson($event, BotHitWallEvent))
      of Type.bulletFiredEvent:
        bot.intent.firePower = 0 # Reset firepower so the bot stops firing continuously
        bot.onBulletFired(fromJson($event, BulletFiredEvent))
      of Type.bulletHitBotEvent:
        # conversion from BulletHitBotEvent to HitByBulletEvent
        let hit_by_bullet_event = fromJson($event, HitByBulletEvent)
        hit_by_bullet_event.`type` = Type.hitByBulletEvent
        bot.onHitByBullet(hit_by_bullet_event)
      of Type.bulletHitBulletEvent:
        # conversion from BulletHitBulletEvent to HitBulletEvent
        let bullet_hit_bullet_event = fromJson($event, BulletHitBulletEvent)
        bullet_hit_bullet_event.`type` = Type.bulletHitBulletEvent
        bot.onBulletHitBullet(bullet_hit_bullet_event)
      of Type.bulletHitWallEvent:
        # conversion from BulletHitWallEvent to HitWallByBulletEvent
        let bullet_hit_wall_event = fromJson($event, BulletHitWallEvent)
        bullet_hit_wall_event.`type` = Type.bulletHitWallEvent
        bot.onBulletHitWall(bullet_hit_wall_event)
      of Type.botHitBotEvent:
        # stop bot movement
        bot.setDistanceRemaining(0)

        bot.onHitBot(fromJson($event, BotHitBotEvent))
      of Type.scannedBotEvent:
        bot.onScannedBot(fromJson($event, ScannedBotEvent))
      of Type.wonRoundEvent:
        bot.onWonRound(fromJson($event, WonRoundEvent))     
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

    skipped += 1

  of roundEndedEventForBot:
    stop bot

    let round_ended_event_for_bot = json_message.fromJson(RoundEndedEventForBot)

    # activating the bot method
    bot.onRoundEnded(round_ended_event_for_bot)

  of roundStartedEvent:
    let round_started_event = (RoundStartedEvent)message

    # activating the bot method
    bot.onRoundStarted(round_started_event)

  else: echo "NOT HANDLED MESSAGE: ",json_message

proc botWorker(bot:Bot) {.thread.} =
  bot.botReady = true
  echo "[",bot.name,".botWorker] READY!"

  # While the bot is connected to the server the bot thread should live
  echo "[",bot.name,".botWorker] waiting for connection"
  var msg = botWorkerChan.recv()

  case msg:
  of "QUIT":
    echo "[",bot.name,".botWorker] QUIT"
    return
  else:
    echo "[",bot.name,".botWorker] connection aknowledged"

    while bot.connected:
      echo "[",bot.name,".botWorker] waiting for running"
      # First is waiting doing nothing for the bot to be in running state
      msg = botWorkerChan.recv()

      case msg:
      of "QUIT":
        echo "[",bot.name,".botWorker] QUIT"
        return
      else:
        echo "[",bot.name,".botWorker] running the custom bot run() method"

        # Second run the bot 'run()' method, the one scripted by the bot creator
        # this could be going in loop until the bot is dead or could finish up quickly or could be that is not implemented at all
        run bot

        echo "[",bot.name,".botWorker] automatic GO started"
        # Third, when the bot creator's 'run()' exits, if the bot is still runnning, we send the intent automatically
        while isRunning(bot):
          go bot

        echo "[",bot.name,".botWorker] automatic GO ended"

proc conectionHandler(bot:Bot) {.async.} =
  try:
    echo "[",bot.name,".conectionHandler] trying to connect to ", bot.serverConnectionURL
    var ws = await newWebSocket(bot.serverConnectionURL)
    echo "[",bot.name,".conectionHandler] connected..."

    proc writer() {.async.} =
      ## Loops while socket is open, looking for messages to write
      while ws.readyState == Open:
        # if there are chat message we have not sent yet
        # send them
        {.locks: [messagesSeqLock].}:
          while bot.messagesToSend.len > 0:
            let message = bot.messagesToSend.pop()
            # echo "[API.writer.",bot.name,"] sending message: ", message, " for turn ", bot.turnNumber
            await ws.send(message)

        # keep the async stuff happy we need to sleep some times
        await sleepAsync(1)

        # # peek the channel to not block
        # while sendMessage_channel.peek() == 0:
        #   await sleepAsync(1)
        
        # # wait over the channel for a message to send
        # var msg = sendMessage_channel.recv()

        # # send the message right away
        # await ws.send(msg)

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

  except CatchableError:
    bot.onConnectionError(getCurrentExceptionMsg())
    botWorkerChan.send("QUIT")

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

  initLock messagesSeqLock

  # init channels
  botWorkerChan.open()
  # sendMessage_channel.open()

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
    createThread botRunner, botWorker, bot

    # wait for the threads to be ready
    echo "[",bot.name,".startBot] waiting for bot and intent threads to be ready"
    while not bot.botReady: sleep(100)
    echo "[",bot.name,".startBot] bot threads are ready: ", bot.botReady

    # connect to the server
    waitFor conectionHandler bot

    # Waiting for the bot thread to finish
    joinThreads botRunner

  deinitLock messagesSeqLock
  # close channels
  botWorkerChan.close()
  # sendMessage_channel.close()
    
  echo "[",bot.name,".startBot]connection ended and bot thread finished. Bye!"
  echo "[",bot.name,".startBot] skipped turns: ", skipped
