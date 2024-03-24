import std/[os, locks, strutils, math, random]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schemas, Bot]

export Schemas, Bot, Condition 

# proc to b eused as logging stuff in the stdout
proc log*(bot: Bot, msg: string) =
  stdout.writeLine "[" & bot.name & ".log] " & msg
  stdout.flushFile

proc console_log*(bot: Bot, msg: string) =
  stdout.writeLine msg
  stdout.flushFile
  bot.intent.stdOut.add(msg)

proc notifyNextTurn() =
  ## This method is used to notify the bot that the next turn is ready
  nextTurn.send("")

proc setConnectionParameters*(bot: Bot, serverConnectionURL: string,
    secret: string) =
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
  ## This method is optional. If not called the bot will use the default values of `ws://localhost`
# ## and `7654`
  ##
  ## This method must be called before `startBot()`
  ##
  ## This method is mostly used for testing
  bot.serverConnectionURL = serverConnectionURL
  bot.secret = secret

proc botWorker(bot: Bot) {.thread.} =
  while true:
    let message = botWorkerChan.recv()

    case message:
    of "close": break
    of "run":
      # Rrun the bot 'run()' method, the one scripted by the bot creator
      # this could be going in loop until the bot is dead or could finish up quickly
      # or could be that is not implemented at all
      run bot

      # When the bot creator's 'run()' exits, if the bot is still runnning,
      # we send the intent automatically until the bot is stopped
      while bot.isRunning():
        go bot

proc methodWorker(bot: Bot)  {.thread.} =
  # random id for the thread
  var id = rand(1..1000)

  while true:
    # echo "[", bot.name, ".methodWorker] waiting for message...", id
    # wait for the next available event
    let message = eventsHandlerChan.recv()

    case message:
    of "close": break
    else:
      # echo "[", bot.name, ".methodWorker] received event: ", message, " in thread ", id
      let event = json2schema message
      case event.`type`:
      of botHitWallEvent:
        bot.onHitWall((BotHitWallEvent)event)
      of bulletFiredEvent:
        bot.onBulletFired((BulletFiredEvent)event)
      of bulletHitBotEvent:
        let bulletHitBotEvent = (BulletHitBotEvent)event
        let hitByBulletEvent = HitByBulletEvent(
          `type`: Type.hitByBulletEvent,
          bullet: bulletHitBotEvent.bullet,
          damage: bulletHitBotEvent.damage,
          energy: bulletHitBotEvent.energy
        )
        bot.onHitByBullet(hitByBulletEvent)
      of bulletHitBulletEvent:
        bot.onBulletHitBullet((BulletHitBulletEvent)event)
      of bulletHitWallEvent:
        bot.onBulletHitWall((BulletHitWallEvent)event)
      of botHitBotEvent:
        bot.onHitBot((BotHitBotEvent)event)
      of scannedBotEvent:
        bot.onScannedBot((ScannedBotEvent)event)
      of wonRoundEvent:
        bot.onWonRound((WonRoundEvent)event)
      of botDeathEvent:
        bot.onDeath((BotDeathEvent)event)
      else:
        echo "[", bot.name, ".methodWorker] event: not handled ", event.`type`, " in thread ", id
  echo "[", bot.name, ".methodWorker] method worker EXIT ", id

proc handleMessage(bot: Bot, json_message: string) =
  # Convert the json to a Message object
  let message = json2schema json_message

  if message.`type` == Type.tickEventForBot:
    stdout.write("+")
    stdout.flushFile()
  elif message.`type` == Type.skippedTurnEvent:
    stdout.write("!")
    stdout.flushFile()
  else:
    echo "[", bot.name, ".handleMessage] received event: ", message.`type`

  # 'case' switch over type
  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message
    let bot_handshake = BotHandshake(`type`: Type.botHandshake,
        sessionId: server_handshake.sessionId, name: bot.name,
        version: bot.version, authors: bot.authors, secret: bot.secret,
        initialPosition: bot.initialPosition)
    {.locks: [messagesSeqLock].}: bot.messagesToSend.add(bot_handshake.toJson)
    # sendMessage_channel.send(bot_handshake.toJson)

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    bot.gameSetup = game_started_event_for_bot.gameSetup
    bot.myId = game_started_event_for_bot.myId

    # activating the bot method
    bot.onGameStarted(game_started_event_for_bot)

    # send bot ready
    {.locks: [messagesSeqLock].}: bot.messagesToSend.add(BotReady(`type`: Type.botReady).toJson)
    # sendMessage_channel.send(BotReady(`type`:Type.botReady).toJson)

  of tickEventForBot:
    let tick_event_for_bot = (TickEventForBot)message

    if bot.first_tick:
      # initi with the first tick data
      bot.botState = tick_event_for_bot.botState
      bot.turnNumber = tick_event_for_bot.turnNumber
      bot.roundNumber = tick_event_for_bot.roundNumber

      # notify the botWorker to run
      botWorkerChan.send("run")

      turn_done = 0
      gunTurn_done = 0
      radarTurn_done = 0
      distance_done = 0

      bot.first_tick = false
    else:
      turn_done = tick_event_for_bot.botState.direction -
          bot.botState.direction
      turn_done = (turn_done + 540) mod 360 - 180

      gunTurn_done = tick_event_for_bot.botState.gunDirection -
          bot.botState.gunDirection
      gunTurn_done = (gunTurn_done + 540) mod 360 - 180

      radarTurn_done = tick_event_for_bot.botState.radarDirection -
          bot.botState.radarDirection
      radarTurn_done = (radarTurn_done + 540) mod 360 - 180

      distance_done = tick_event_for_bot.botState.speed

      # replace old data with new data
      bot.botState = tick_event_for_bot.botState
      bot.turnNumber = tick_event_for_bot.turnNumber
      bot.roundNumber = tick_event_for_bot.roundNumber

      notifyNextTurn()

    # activating the bot method
    bot.onTick(tick_event_for_bot)

    # for every event inside this tick call the relative event for the bot
    for event in tick_event_for_bot.events:
      case parseEnum[Type](event["type"].getStr()):
      of Type.botDeathEvent:
        # if the bot is dead we stop it
        stop bot

        eventsHandlerChan.send($event)
      of Type.botHitWallEvent:
        # zero the distance remaining
        bot.setDistanceRemaining(0)

        # bot.onHitWall(fromJson($event, BotHitWallEvent))
        eventsHandlerChan.send($event)
      of Type.bulletFiredEvent:
        bot.intent.firePower = 0 # Reset firepower so the bot stops firing continuously
        eventsHandlerChan.send($event)
      of Type.bulletHitBotEvent:
        # conversion from BulletHitBotEvent to HitByBulletEvent
        eventsHandlerChan.send($event)
      of Type.bulletHitBulletEvent:
        eventsHandlerChan.send($event)
      of Type.bulletHitWallEvent:
        eventsHandlerChan.send($event)
      of Type.botHitBotEvent:
        # zero the distance remaining
        bot.setDistanceRemaining(0)

        eventsHandlerChan.send($event)
      of Type.scannedBotEvent:
        eventsHandlerChan.send($event)
      of Type.wonRoundEvent:
        eventsHandlerChan.send($event)
      else:
        echo "NOT HANDLED BOT TICK EVENT: ", event

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
    start bot

    let round_started_event = (RoundStartedEvent)message

    # activating the bot method
    bot.onRoundStarted(round_started_event)

  else: echo "NOT HANDLED MESSAGE: ", json_message

proc conectionHandler(bot: Bot) {.async.} =
  try:
    echo "[", bot.name, ".conectionHandler] trying to connect to ",
        bot.serverConnectionURL
    var ws = await newWebSocket(bot.serverConnectionURL)
    echo "[", bot.name, ".conectionHandler] connected..."

    # signal the threads that the connection is ready
    setConnected(true)

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

    proc reader() {.async.} =
      # Loops while socket is open, looking for messages to read
      while ws.readyState == Open:
        # this blocks
        var packet = await ws.receiveStrPacket()

        if packet.isEmptyOrWhitespace(): continue
        
        # echo "[API.reader.",bot.name,"] received message: ", packet

        handleMessage(bot, packet)

    # start a async fiber thingy
    asyncCheck writer()
    await reader()

  except CatchableError:
    bot.onConnectionError(getCurrentExceptionMsg())

proc startBot*(bot: Bot, connect: bool = true,
    position: InitialPosition = InitialPosition(x: 0, y: 0, angle: 0)) =
  ## **Start the bot**
  ##
  ## This method is used to start the bot instance. This coincide with asking the bot to connect to the
  ## game server
  ##
  ## `bot` is the new and current bot istance
  ##
  ## `connect` (can be omitted) is a boolean value that if `true` (default) will ask the bot to connect to
  ## the game server.
  ## If `false` the bot will not connect to the game server. Mostly used for testing.
  ##
  ## `position` (can be omitted) is the initial position of the bot. If not specified the bot will be
  ## placed at the center of the map.
  ## This custom position will work if the server is configured to use the custom initial positions

  # set the initial position, is the server that will decide to use it or not
  bot.initialPosition = position

  initLock messagesSeqLock
  initLock runningLock
  initLock eventsQueueLock

  # connect to the Game Server
  if(connect):
    if bot.secret == "":
      bot.secret = getEnv("SERVER_SECRET", "serversecret")

    if bot.serverConnectionURL == "":
      bot.serverConnectionURL = getEnv("SERVER_URL", "ws://localhost:7654")

    # open channels
    botWorkerChan.open()
    nextTurn.open()
    eventsHandlerChan.open()

    # start the bot thread
    var botRunner: Thread[bot.type]
    createThread botRunner, botWorker, bot

    # start multiple copies of the event handler
    var methodWorkerThreads: array[3, Thread[bot.type]]
    for i in 0..2:
      createThread methodWorkerThreads[i], methodWorker, bot

    # start the connection handler and wait for it undefinitely
    waitFor conectionHandler(bot)

    # send closing signal to the bot thread
    botWorkerChan.send("close")

    # send closing signal to the method worker threads
    for i in 0..2:
      eventsHandlerChan.send("close")

    # wait for the bot thread to finish
    joinThread botRunner
    joinThreads methodWorkerThreads

    # close the channels
    botWorkerChan.close()
    nextTurn.close()
    eventsHandlerChan.close()

    # deinit locks
    deinitLock messagesSeqLock
    deinitLock runningLock
    deinitLock eventsQueueLock
    
  echo "[", bot.name, ".startBot]connection ended and bot thread finished. Bye!"
