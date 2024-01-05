import std/[os, locks, strutils, math, locks]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schemas, Bot, Statics, Utils]

export Schemas, Bot, Condition

var
  botChannel:Channel[string]
  masterLock:Lock
  running {.guard: masterLock} :bool = false
  connected {.guard: masterLock} :bool = false
  nextTurn {.guard: masterLock} :bool = false

  #++++++++++++++ MAX RATES ++++++++++++++#
  max_turnRate:float = MAX_TURN_RATE
  max_gunTurnRate:float = MAX_GUN_TURN_RATE
  max_radarTurnRate:float = MAX_RADAR_TURN_RATE

  #++++++++ REMAININGS ++++++++#
  remaining_turnRate:float = 0
  remaining_turnGunRate:float = 0
  remaining_turnRadarRate:float = 0
  remaining_distance:float = 0

  #++++++++ BOT UPDATES ++++++++#
  turnRate_done*:float = 0
  gunTurnRate_done*:float = 0
  radarTurnRate_done*:float = 0
  distance_done*:float = 0

proc updateGunTurnRate(bot:Bot) = discard
proc updateRadarTurnRate(bot:Bot) = discard
proc updateTurnRate(bot:Bot) = discard
proc updateSpeed(bot:Bot) = discard     

proc updateIntentRates(bot:Bot) =
  updateGunTurnRate(bot)
  updateRadarTurnRate(bot)
  updateTurnRate(bot)
  updateSpeed(bot)

proc go*(bot:Bot) =
  updateIntentRates(bot)

  bot.send = bot.intent.toJson()

  stdout.write "-"
  stdout.flushFile()

  withLock masterLock:
    while connected and running:
      if not nextTurn: sleep(1)
      else: nextTurn = false

#++++++++++++++ CALLABLES ++++++++++++++#
proc setGunTurnRate*(bot:Bot, rate:float) =
  bot.intent.gunTurnRate = rate
  remaining_turnGunRate = toInfiniteValue(rate)

proc setRadarTurnRate*(bot:Bot, rate:float) =
  bot.intent.radarTurnRate = rate
  remaining_turnRadarRate = toInfiniteValue(rate)

proc setTurnRate*(bot:Bot, rate:float) =
  bot.intent.turnRate = rate
  remaining_turnRate = toInfiniteValue(rate)

proc fire*(bot:Bot, power:float) =
  bot.intent.firePower = clamp(power, MIN_FIRE_POWER, MAX_FIRE_POWER)
  echo "fire: " & $bot.intent.firePower
  go bot

proc handleServerHandshake(bot:Bot, msg:string) {.async.} =
  let server_handshake = msg.fromJson(ServerHandshake)
  let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.name, version:bot.version, authors:bot.authors, secret:bot.secret, initialPosition:bot.initialPosition)
  bot.send = bot_handshake.toJson()

proc handleGameStartedEventForBot(bot:Bot, packet:string) {.async.} =
  let gameStartedEventForBot = packet.fromJson(GameStartedEventForBot)
  bot.myId = gameStartedEventForBot.myId
  bot.gameSetup = gameStartedEventForBot.gameSetup
  bot.send = BotReady(`type`:Type.botReady).toJson()

proc handleRoundStartedEventForBot(bot:Bot, packet:string) =
  let roundStartedEvent = packet.fromJson(RoundStartedEvent)
  bot.onRoundStarted(roundStartedEvent)
  withLock masterLock: running = true
  botChannel.send("run")

proc handleBotDeathEvent(bot:Bot, packet:string) =
  let botDeathEvent = packet.fromJson(BotDeathEvent)
  bot.onDeath(botDeathEvent)
  withLock masterLock: running = false

proc handleBotHitWallEvent(bot:Bot, packet:string) =
  let botHitWallEvent = packet.fromJson(BotHitWallEvent)
  bot.onHitWall(botHitWallEvent)

proc handleBotHitBotEvent(bot:Bot, packet:string) =
  let botHitBotEvent = packet.fromJson(BotHitBotEvent)
  bot.onHitBot(botHitBotEvent)

proc handleBulletFiredEvent(bot:Bot, packet:string) =
  let bulletFiredEvent = packet.fromJson(BulletFiredEvent)
  bot.onBulletFired(bulletFiredEvent)

proc handleBulletHitBotEvent(bot:Bot, packet:string) =
  let bulletHitBotEvent = packet.fromJson(BulletHitBotEvent)
  bot.onBulletHitBot(bulletHitBotEvent)

proc handleBulletHitWallEvent(bot:Bot, packet:string) =
  let bulletHitWallEvent = packet.fromJson(BulletHitWallEvent)
  bot.onBulletHitWall(bulletHitWallEvent)

proc handleHitByBullet(bot:Bot, packet:string) =
  let hitByBulletEvent = packet.fromJson(HitByBulletEvent)
  bot.onHitByBullet(hitByBulletEvent)

proc handleScannedBotEvent(bot:Bot, packet:string) =
  let scannedBotEvent = packet.fromJson(ScannedBotEvent)
  bot.onScannedBot(scannedBotEvent)

proc handleWonRoundEvent(bot:Bot, packet:string) =
  let wonRoundEvent = packet.fromJson(WonRoundEvent)
  bot.onWonRound(wonRoundEvent)

proc handleTickEvent(bot:Bot, packet:string) =
  withLock masterLock: nextTurn = true
  bot.tickEvent = packet.fromJson(TickEventForBot)
  bot.onTick(bot.tickEvent)

  # for every event inside this tick call the relative event for the bot
  for event in bot.tickEvent.events:
    case parseEnum[Type](event["type"].getStr()):
    of Type.botDeathEvent: handleBotDeathEvent(bot, $event)
    of Type.botHitWallEvent: handleBotHitWallEvent(bot, $event)
    of Type.botHitBotEvent: handleBotHitBotEvent(bot, $event)
    of Type.bulletFiredEvent: handleBulletFiredEvent(bot, $event)
    of Type.bulletHitBotEvent: handleBulletHitBotEvent(bot, $event)
    of Type.bulletHitWallEvent: handleBulletHitWallEvent(bot, $event)
    of Type.hitByBulletEvent: handleHitByBullet(bot, $event)
    of Type.scannedBotEvent: handleScannedBotEvent(bot, $event)
    of Type.wonRoundEvent: handleWonRoundEvent(bot, $event)
    else: echo "unknown event type: " & $event["type"].getStr()

  stdout.write "+"

proc handleSkippedTurnEvent(bot:Bot, packet:string) =
  let skippedTurnEvent = packet.fromJson(SkippedTurnEvent)
  bot.onSkippedTurn(skippedTurnEvent)

  stdout.write("!")
  stdout.flushFile()

proc handleRoundEndedEventForBot(bot:Bot, packet:string) =
  let roundEndedEventForBot = packet.fromJson(RoundEndedEventForBot)
  bot.onRoundEnded(roundEndedEventForBot)
  withLock masterLock: running = false

proc handleGameAbortedEvent(bot:Bot, packet:string) =
  let gameAbortedEvent = packet.fromJson(GameAbortedEvent)
  bot.onGameAborted(gameAbortedEvent)
  withLock masterLock: running = false

proc handleGameEndedEventForBot(bot:Bot, packet:string) =
  let gameEndedEventForBot = packet.fromJson(GameEndedEventForBot)
  bot.onGameEnded(gameEndedEventForBot)
  withLock masterLock: running = false

proc listen(bot:Bot, socket:WebSocket) {.async.} =
  while socket.readyState == Open:
    let msg = await socket.receiveStrPacket()
    if msg.isEmptyOrWhitespace: continue

    let `type` = msg.fromJson(Schema).`type`
    case `type`:
    of serverHandshake: await handleServerHandshake(bot, msg)
    of gameStartedEventForBot: await handleGameStartedEventForBot(bot, msg)
    of roundStartedEvent: handleRoundStartedEventForBot(bot, msg)
    of tickEventForBot: handleTickEvent(bot, msg)
    of skippedTurnEvent: handleSkippedTurnEvent(bot, msg)
    of roundEndedEventForBot: handleRoundEndedEventForBot(bot, msg)
    of gameAbortedEvent: handleGameAbortedEvent(bot, msg)
    of gameEndedEventForBot: handleGameEndedEventForBot(bot, msg)
    else:
      echo "unknown packet type: " & $`type`

proc write(bot:Bot, socket:WebSocket) {.async.} =
  while socket.readyState == Open:
    while bot.send.isEmptyOrWhitespace(): await sleepAsync(10)
    await socket.send(bot.send)
    bot.send = ""

proc connect(bot:Bot) {.thread.} =
  var socket = waitFor newWebSocket(bot.serverConnectionURL)
  withLock masterLock: connected = true
  bot.onConnect()

  asyncCheck listen(bot, socket)
  asyncCheck write(bot, socket)
  runForever()

proc runBot(bot:Bot) {.thread.} =
  echo "[runBot] is online"
  while true:
    let msg = botChannel.recv()
    case msg:
    of "run":
      run bot
    
      while running and connected:
        go bot
    else: 
      echo "[runBot] quit"
      quit(0)

proc startBot*(bot:Bot) =
  botChannel.open()

  # secrets
  bot.serverConnectionURL = getEnv("SERVER_URL", DEFAULT_SERVER_URL)
  bot.secret = getEnv("SERVER_SECRET", DEFAULT_SERVER_SECRET)

  var
    connectThread:Thread[bot.type]
    botThread:Thread[bot.type]

  createThread connectThread, connect, bot
  createThread botThread, runBot, bot

  joinThreads connectThread, botThread

  botChannel.close()
