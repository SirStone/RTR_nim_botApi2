import std/[os, strutils, math, random, atomics]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schemas, Bot]

export Schemas, Bot, Condition

# constants
const numberOfThreads = 1 # number of threads for event handling

var webSocket: WebSocket
var lastIntentTurn: int = -1

# custom conditions
var customConditionsQueue:seq[Condition] # list of conditions

proc addCustomCondition*(bot:Bot, customCondition: Condition) =
  ## add a custom condition to the bot
  ##
  ## `name` is the name of the condition
  ## `test` is the condition function
  {.gcsafe.}:
    customConditionsQueue.add(customCondition)

proc setConnectionParameters*(bot: Bot, serverConnectionURL: string, secret: string) =
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
  ## and `7654`
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
    # wait for the next available event
    let message = eventsHandlerChan.recv()

    # if bot is dead, we ignore the event
    if not bot.isRunning():
      # echo "bot is not running, ignoring event: ", message
      continue

    case message:
    of "close": break
    else:
      try:
        let event = (Event)(json2schema message)

        # echo "turn of the message vs current turn: ", event.turnNumber, " vs ", bot.turnNumber, ": ", event.`type`

        if event.turnNumber != 0 and abs(event.turnNumber - bot.getTurnNumber) > 2:
          echo "event rejected: ", event.`type`
          continue

        case event.`type`:
        of botHitWallEvent:
          bot.setDistanceRemaining(0) # zero the distance remaining
          bot.onHitWall((BotHitWallEvent)event) # activating the bot method
        of bulletFiredEvent:
          bot.intent.firePower = 0 # reset the firepower
          bot.onBulletFired((BulletFiredEvent)event) # activating the bot method
        of bulletHitBotEvent:
          let bulletHitBotEvent = (BulletHitBotEvent)event # cast the event to the right type
          echo "id victim: ", bulletHitBotEvent.victimId, " my id: ", bot.myId
          if bulletHitBotEvent.victimId == bot.myId: # check if my bot is the victim
            # creating the HitByBulletEvent from the BulletHitBotEvent
            let hitByBulletEvent = HitByBulletEvent(
              `type`: Type.hitByBulletEvent,
              bullet: bulletHitBotEvent.bullet,
              damage: bulletHitBotEvent.damage,
              energy: bulletHitBotEvent.energy
            )
            bot.onHitByBullet(hitByBulletEvent) # activating the bot method
          else: # the bot hit someone else
            bot.onBulletHit(bulletHitBotEvent) # activating the bot method       
        of bulletHitBulletEvent:
          bot.onBulletHitBullet((BulletHitBulletEvent)event) # activating the bot method
        of bulletHitWallEvent:
          bot.onBulletHitWall((BulletHitWallEvent)event) # activating the bot method
        of botHitBotEvent:
          bot.setDistanceRemaining(0) # zero the distance remaining
          bot.onHitBot((BotHitBotEvent)event) # activating the bot method
        of scannedBotEvent:
          bot.onScannedBot((ScannedBotEvent)event) # activating the bot method
        of wonRoundEvent:
          bot.onWonRound((WonRoundEvent)event) # activating the bot method
        of botDeathEvent:
          bot.onDeath((BotDeathEvent)event) # activating the bot method
        of gameAbortedEvent:
          bot.onGameAborted((GameAbortedEvent)event) # activating the bot method
        of roundEndedEventForBot:
          bot.onRoundEnded((RoundEndedEventForBot)event) # activating the bot method
        of roundStartedEvent: # activating the bot method
          bot.onRoundStarted((RoundStartedEvent)event) # activating the bot method
        of gameStartedEventForBot:
          bot.onGameStarted((GameStartedEventForBot)event) # activating the bot method
        of serverHandshake: discard
        of skippedTurnEvent:
          bot.onSkippedTurn((SkippedTurnEvent)event) # activating the bot method
        of tickEventForBot:
          bot.onTick((TickEventForBot)event) # activating the bot method
        else:
          echo "[", bot.name, ".methodWorker] event: not handled ", event.`type`, " in thread ", id
      except jsony.JsonError:
        bot.onCustomCondition(message) # activating the bot method
      
proc handleMessage(bot: Bot, json_message: string) =
  # Convert the json to a Message object
  let message = json2schema json_message

  # if message.`type` == Type.tickEventForBot:
  #   stdout.write("+")
  #   stdout.flushFile()
  # elif message.`type` == Type.skippedTurnEvent:
  #   stdout.write("!")
  #   stdout.flushFile()

  # 'case' switch over type
  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message
    let bot_handshake = BotHandshake(`type`: Type.botHandshake,
        sessionId: server_handshake.sessionId, name: bot.name,
        version: bot.version, authors: bot.authors, secret: bot.secret,
        initialPosition: bot.initialPosition)
    asyncCheck webSocket.send(bot_handshake.toJson)

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    bot.gameSetup = game_started_event_for_bot.gameSetup
    bot.myId = game_started_event_for_bot.myId

    # send bot ready
    asyncCheck webSocket.send(BotReady(`type`: Type.botReady).toJson)

    bot.onGameStarted(game_started_event_for_bot) # activating the bot method

  of roundStartedEvent:
    # empty the custom conditions
    customConditionsQueue = @[]

    start bot # start the bot

    # send the message to the method worker threads
    eventsHandlerChan.send(json_message)

  of botDeathEvent:
    let botDeathEvent = (BotDeathEvent)message
    if botDeathEvent.victimId == bot.myId: # check if my bot is dead
      stop bot # stop the bot

      bot.onDeath(botDeathEvent) # activating the bot method
    else:
      eventsHandlerChan.send(json_message)
  
  of gameAbortedEvent:
    stop bot # stop the bot

    bot.onGameAborted((GameAbortedEvent)message) # activating the bot method

  of roundEndedEventForBot:
    stop bot # stop the bot

    bot.onRoundEnded((RoundEndedEventForBot)message) # activating the bot method

  of gameEndedEventForBot:
    bot.onGameEnded((GameEndedEventForBot)message) # activating the bot method

  of tickEventForBot:
    let tick_event_for_bot = (TickEventForBot)message

    if bot.first_tick:
      # init with the first tick data
      bot.tick = tick_event_for_bot

      # notify the botWorker to run
      botWorkerChan.send("run")

      turn_done = 0
      gunTurn_done = 0
      radarTurn_done = 0
      distance_done = 0

      bot.first_tick = false
    else:
      turn_done = tick_event_for_bot.botState.direction - bot.tick.botState.direction
      turn_done = (turn_done + 540) mod 360 - 180

      gunTurn_done = tick_event_for_bot.botState.gunDirection - bot.tick.botState.gunDirection
      gunTurn_done = (gunTurn_done + 540) mod 360 - 180

      radarTurn_done = tick_event_for_bot.botState.radarDirection - bot.tick.botState.radarDirection
      radarTurn_done = (radarTurn_done + 540) mod 360 - 180

      # adjust the gun turn by the body turn if the gun is not independent from the body
      if not bot.isAdjustGunForBodyTurn: gunTurn_done -= turn_done

      # adjust the radar turn by the body turn if the radar is not independent from the body
      if not bot.isAdjustRadarForGunTurn: radarTurn_done -= turn_done

      # adjust the radar turn by the gun turn if the radar is not independent from the gun
      if not bot.isAdjustRadarForGunTurn: radarTurn_done -= gunTurn_done

      distance_done = tick_event_for_bot.botState.speed

      # replace old data with new data
      bot.tick = tick_event_for_bot

      eventsHandlerChan.send(json_message)

      notifyNextTurn()
    
    # for every event inside this tick call the relative event for the bot
    for event in tick_event_for_bot.events:
      eventsHandlerChan.send($event) # send the event to the method worker threads

    # start a thread for every condition check
    for condition in customConditionsQueue:
      if condition.test(bot):
        eventsHandlerChan.send(condition.name)

  else: eventsHandlerChan.send(json_message)

proc conectionHandler(bot: Bot) {.async.} =
  try:
    webSocket = await newWebSocket(bot.serverConnectionURL)

    # signal the threads that the connection is ready
    bot.setConnected(true)

    proc writer() {.async.} =
      ## Loops while socket is open, looking for messages to write
      while webSocket.readyState == Open:

        # continuoslly check if intent must be sent
        if sendIntent.load() and bot.getTurnNumber != lastIntentTurn:
          # update the reaminings
          bot.updateRemainings()

          let json_intent = bot.intent.toJson

          await webSocket.send(json_intent)

          # reset some intent values
          bot.resetIntent()
          
          # update the last turn we sent the intent
          lastIntentTurn = bot.getTurnNumber

          # stdout.write("-")
          # stdout.flushFile()

        # keep the async dispatcher happy
        await sleepAsync(1)

    proc reader() {.async.} =
      # Loops while socket is open, looking for messages to read
      while webSocket.readyState == Open:
        # this blocks
        var packet = await webSocket.receiveStrPacket()

        if packet.isEmptyOrWhitespace(): continue
        
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
    var methodWorkerThreads: array[numberOfThreads, Thread[bot.type]]
    for i in 0..numberOfThreads-1:
      createThread methodWorkerThreads[i], methodWorker, bot

    # start the connection handler and wait for it undefinitely
    waitFor conectionHandler(bot)

    # send closing signal to the bot thread
    botWorkerChan.send("close")

    # send closing signal to the method worker threads
    for i in 0..numberOfThreads-1:
      eventsHandlerChan.send("close")

    # wait for the bot thread to finish
    joinThread botRunner
    joinThreads methodWorkerThreads

    # close the channels
    botWorkerChan.close()
    nextTurn.close()
    eventsHandlerChan.close()

  echo "[", bot.name, ".startBot]connection ended and bot thread finished. Bye!"
