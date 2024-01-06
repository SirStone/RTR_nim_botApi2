import std/[os, strutils]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schemas, BluePrints, Statics, Utils]

export Schemas, BluePrints

type Bot* = ref object of BluePrint
  eventsQueue:seq[Schema]
  send:string = ""
  running:bool = false
  connected:bool = false
  waiting:bool = false

var
  botChannel:Channel[string]
  methodsChannel:Channel[string]
  lastTurn:int = 0
  firstTick:bool = true

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

proc waitForNextTurn(bot:Bot) =
  bot.waiting = true
  while bot.running and bot.connected:
    if bot.tickEvent.turnNumber > lastTurn:
      lastTurn = bot.tickEvent.turnNumber
      break
    else: waitFor sleepAsync(1)
  bot.waiting = false

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
  if bot.waiting: return
  updateIntentRates(bot)
  bot.send = bot.intent.toJson()
  stdout.write("w")
  stdout.flushFile()
  waitForNextTurn(bot)

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
  go bot

proc write(bot:Bot, socket:WebSocket) {.async.} =
  while socket.readyState == Open:
    while bot.send.isEmptyOrWhitespace(): await sleepAsync(1)
    await socket.send(bot.send)
    stdout.write("-")
    stdout.flushFile()
    bot.send = ""

proc connectAndListen(bot:Bot) {.async.} =
  echo "[connectAndListen] connection url: ", bot.serverConnectionURL
  var socket = await newWebSocket(bot.serverConnectionURL)

  bot.connected = true

  asyncCheck write(bot, socket)

  while socket.readyState == Open:
    var msg:string = await socket.receiveStrPacket()
    if msg.isEmptyOrWhitespace: continue

    let `type` = msg.fromJson(Schema).`type`
    case `type`:
    of Type.serverHandshake:
      let server_handshake = msg.fromJson(ServerHandshake)
      let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.name, version:bot.version, authors:bot.authors, secret:bot.secret, initialPosition:bot.initialPosition)
      await socket.send bot_handshake.toJson()
    of Type.gameStartedEventForBot:
      let gameStartedEventForBot = msg.fromJson(GameStartedEventForBot)
      bot.myId = gameStartedEventForBot.myId
      bot.gameSetup = gameStartedEventForBot.gameSetup
      await socket.send BotReady(`type`:Type.botReady).toJson()
    of Type.roundStartedEvent:
      bot.running = true
      botChannel.send("run")
    of Type.tickEventForBot:
      stdout.write("+")
      stdout.flushFile()

      bot.tickEvent = msg.fromJson(TickEventForBot)

      if firstTick:
        firstTick = false
        bot.running = true
        botChannel.send("run")

      for event in bot.tickEvent.events:
        case parseEnum[Type](event["type"].getStr()):
        of Type.botDeathEvent:
          bot.eventsQueue.add(fromJson($event, BotDeathEvent))
          firstTick = true
          lastTurn = 0
          bot.running = false
        of Type.botHitWallEvent:
          bot.eventsQueue.add(fromJson($event, BotHitWallEvent))
        of Type.botHitBotEvent:
          bot.eventsQueue.add(fromJson($event, BotHitBotEvent))
        of Type.bulletFiredEvent:
          bot.eventsQueue.add(fromJson($event, BulletFiredEvent))
        of Type.bulletHitBotEvent:
          bot.eventsQueue.add(fromJson($event, BulletHitBotEvent))
        of Type.bulletHitWallEvent:
          bot.eventsQueue.add(fromJson($event, BulletHitWallEvent))
        of Type.hitByBulletEvent:
          bot.eventsQueue.add(fromJson($event, HitByBulletEvent))
        of Type.scannedBotEvent:
          bot.eventsQueue.add(fromJson($event, ScannedBotEvent))
        of Type.wonRoundEvent:
          bot.eventsQueue.add(fromJson($event, WonRoundEvent))
        else: echo "unknown event type: " & $event["type"].getStr()
    of Type.skippedTurnEvent:
      stdout.write("!")
      stdout.flushFile()
      bot.eventsQueue.add(fromJson(msg, SkippedTurnEvent))
    of Type.roundEndedEventForBot:
      bot.eventsQueue.add(fromJson(msg, RoundEndedEventForBot))
      firstTick = true
      lastTurn = 0
      bot.running = false
    of Type.gameAbortedEvent:
      bot.eventsQueue.add(fromJson(msg, GameAbortedEvent))
      firstTick = true
      lastTurn = 0
      bot.running = false
    of Type.gameEndedEventForBot:
      bot.eventsQueue.add(fromJson(msg, GameEndedEventForBot))
      firstTick = true
      lastTurn = 0
      bot.running = false
    else: echo "unknown packet type: ",`type`

  echo "[connectAndListen] socket closed"

proc eventsRunner(bot:Bot) {.thread.} =
  while true:
    if bot.eventsQueue.len > 0:
      let event:Schema = bot.eventsQueue.pop()
      case event.type:
      of Type.scannedBotEvent: bot.onScannedBot((ScannedBotEvent)event)
      of Type.skippedTurnEvent: bot.onSkippedTurn((SkippedTurnEvent)event)
      of Type.roundEndedEventForBot: bot.onRoundEnded((RoundEndedEventForBot)event)
      of Type.gameAbortedEvent: bot.onGameAborted((GameAbortedEvent)event)
      of Type.gameEndedEventForBot: bot.onGameEnded((GameEndedEventForBot)event)
      of Type.botDeathEvent: bot.onDeath((BotDeathEvent)event)
      of Type.botHitWallEvent: bot.onHitWall((BotHitWallEvent)event)
      of Type.botHitBotEvent: bot.onHitBot((BotHitBotEvent)event)
      of Type.bulletFiredEvent: bot.onBulletFired((BulletFiredEvent)event)
      of Type.bulletHitBotEvent: bot.onBulletHitBot((BulletHitBotEvent)event)
      of Type.bulletHitWallEvent: bot.onBulletHitWall((BulletHitWallEvent)event)
      of Type.hitByBulletEvent: bot.onHitByBullet((HitByBulletEvent)event)
      of Type.wonRoundEvent: bot.onWonRound((WonRoundEvent)event)
      else: echo "[eventsrunner] unknown event type: ", event.type
    else: sleep(1)

proc runBot(bot:Bot) {.thread.} =
  echo "[runBot] is online"
  while true:
    let msg = botChannel.recv()
    case msg:
    of "run":
      run bot
    
      while bot.running and bot.connected:
        go bot
    else: 
      echo "[runBot] quit"
      quit(0)

proc newBot(json_file: string): Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    let path:string = joinPath(getAppDir(),json_file)
    let content:string = readFile(path)
    let bot:Bot = fromJson(content, Bot)
    return bot
  except IOError:
    quit(1)

proc startBot*(json_file: string) =
  var bot = newBot(json_file)

  # secrets
  bot.serverConnectionURL = getEnv("SERVER_URL", DEFAULT_SERVER_URL)
  bot.secret = getEnv("SERVER_SECRET", DEFAULT_SERVER_SECRET)

  botChannel.open()
  methodsChannel.open()

  var botThr:Thread[Bot]
  var eventsThr:Thread[Bot]
  createThread botThr,runBot,bot
  createThread eventsThr,eventsRunner,bot

  waitFor connectAndListen(bot)

  joinThreads botThr, eventsThr

  botChannel.close()
  methodsChannel.close()