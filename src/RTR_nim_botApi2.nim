import std/[os, strutils, math]
import whisky, json, jsony, malebolgia, malebolgia/ticketlocks

import RTR_nim_botApi2/[Schemas, Utils, BotLib]
export Schemas, BotLib

#++++++++ CONSTANTS ++++++++#
const
  # bots accelerate at the rate of 1 unit per turn but decelerate at the rate of 2 units per turn
  ACCELERATION:float = 1
  DECELERATION:float = -2
  ABS_DECELERATION:float = abs(DECELERATION)

  # The speed can never exceed 8 units per turn
  MAX_SPEED:float = 8

  # If standing still (0 units/turn), the maximum rate is 10° per turn
  MAX_TURN_RATE:float = 10

  # The maximum rate of rotation is 20° per turn. This is added to the current rate of rotation of the bot
  MAX_GUN_TURN_RATE:float = 20

  # The maximum rate of rotation is 45° per turn. This is added to the current rate of rotation of the gun
  MAX_RADAR_TURN_RATE:float = 45

  # The maximum firepower is 3 and the minimum firepower is 0.1
  MAX_FIRE_POWER:float = 3
  MIN_FIRE_POWER:float = 0.1

  # default server url and secret
  DEFAULT_SERVER_URL:string = "ws://localhost:7654"
  DEFAULT_SERVER_SECRET:string = "serversecret"

#++++++++ TYPES ++++++++#
type
  Condition* = ref object of RootObj
    name*:string
    test*: proc():bool

#++++++++ GLOBALS ++++++++#
var
  botRunner_channel:Channel[string]

proc go*(bot:Bot) =
  if bot.getTurn() == bot.getLastTurn(): return
  bot.setLastTurn(bot.getTurn())
  bot.eventsQueue.add(bot.botIntent.toJson())

  bot.botIntent.firepower = 0

  while bot.getTurn() == bot.getLastTurn(): discard

proc botRunner(bot:ptr Bot) =
  echo "botRunner started, waiting on channel"
  let msg:string = botRunner_channel.recv()
  case msg:
  of "connected":
    echo "[botRunner] 'connected' received"
    bot[].newIntent()
    while bot[].isConnected():
      let msg:string = botRunner_channel.recv()
      case msg:
      of "run":
        bot[].run()
        while bot[].isRunning() and bot[].isConnected():
          bot[].go()
  of "disconnected":
    echo "[botRunner] 'disconnected' received"
  else:
    echo "botRunner received unknown message: ", msg
  echo "botRunner CLOSED"

#++++++++ REMAININGS ++++++++#
var gunTurnRemaining:float = 0
var radarTurnRemaining:float = 0
var turnRemaining:float = 0
var distanceRemaining:float = 0

proc setGunTurnRate*(bot:Bot, rate:float) =
  gunTurnRemaining = toInfiniteValue(rate)
  bot.botIntent.gunTurnRate = clamp(rate, -MAX_GUN_TURN_RATE, MAX_GUN_TURN_RATE)

proc setRadarTurnRate*(bot:Bot, rate:float) =
  radarTurnRemaining = toInfiniteValue(rate)
  bot.botIntent.radarTurnRate = clamp(rate, -MAX_RADAR_TURN_RATE, MAX_RADAR_TURN_RATE)

proc setTurnRate*(bot:Bot, rate:float) =
  turnRemaining = toInfiniteValue(rate)
  bot.botIntent.turnRate = clamp(rate, -MAX_TURN_RATE, MAX_TURN_RATE)

proc setTargetSpeed*(bot:Bot, speed:float) =
  distanceRemaining = toInfiniteValue(speed)
  bot.botIntent.targetSpeed = clamp(speed, -MAX_SPEED, MAX_SPEED)

proc setFire*(bot:Bot, power:float):bool =
  if bot.tickEvent.botState.gunHeat > 0: return false
  bot.botIntent.firePower = clamp(power, MIN_FIRE_POWER, MAX_FIRE_POWER)
  return true

proc fire*(bot:Bot, power:float) =
  if setFire(bot, power): bot.go()

proc getGunTurnRate*(bot:Bot):float = bot.botIntent.gunTurnRate
proc getRadarTurnRate*(bot:Bot):float = bot.botIntent.radarTurnRate
proc getTurnRate*(bot:Bot):float = bot.botIntent.turnRate
proc getTargetSpeed*(bot:Bot):float = bot.botIntent.targetSpeed

proc handleServerHandshake(bot:Bot, packet:string, socket:WebSocket) =
  let server_handshake = packet.fromJson(ServerHandshake)
  let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.getName(), version:bot.getVersion, authors:bot.getAuthors, secret:bot.getServerSecret, initialPosition:bot.getInitialPosition())
  socket.send(bot_handshake.toJson())

proc handleGameStartedEventForBot(bot:Bot, packet:string, socket:WebSocket) =
  let gameStartedEventForBot = packet.fromJson(GameStartedEventForBot)
  bot.setGameStartedEventForBot(gameStartedEventForBot)
  socket.send(BotReady(`type`:Type.botReady).toJson)

proc handleRoundStartedEventForBot(bot:Bot, packet:string) =
  let roundStartedEvent = packet.fromJson(RoundStartedEvent)
  bot.onRoundStarted(roundStartedEvent)

proc handleBotDeathEvent(bot:Bot, packet:string) =
  let botDeathEvent = packet.fromJson(BotDeathEvent)
  bot.onDeath(botDeathEvent)
  bot.setRunning(false)

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
  if bulletHitBotEvent.victimId == bot.getMyId():
    let hitByBulletEvent = HitByBulletEvent(`type`:Type.hitByBulletEvent, bullet:bulletHitBotEvent.bullet, damage:bulletHitBotEvent.damage, energy:bulletHitBotEvent.energy)
    bot.onHitByBullet(hitByBulletEvent)
  else:
    bot.onBulletHitBot(bulletHitBotEvent)

proc handleBulletHitBulletEvent(bot:Bot, packet:string) =
  let bulletHitBulletEvent = packet.fromJson(BulletHitBulletEvent)
  bot.onBulletHitBullet(bulletHitBulletEvent)

proc handleBulletHitWallEvent(bot:Bot, packet:string) =
  let bulletHitWallEvent = packet.fromJson(BulletHitWallEvent)
  bot.onBulletHitWall(bulletHitWallEvent)

proc handleScannedBotEvent(bot:Bot, packet:string) =
  let scannedBotEvent = packet.fromJson(ScannedBotEvent)
  bot.onScannedBot(scannedBotEvent)

proc handleWonRoundEvent(bot:Bot, packet:string) =
  let wonRoundEvent = packet.fromJson(WonRoundEvent)
  bot.onWonRound(wonRoundEvent)
  bot.setRunning(false)

proc handleTickEvent(bot:Bot, packet:string) =
  let tickEventForBot = packet.fromJson(TickEventForBot)

  bot.onTick(tickEventForBot)
  for event in tickEventForBot.events:
    let `type` = parseEnum[Type](event["type"].getStr())
    case `type`:
    of Type.botDeathEvent: handleBotDeathEvent(bot, $event)
    of Type.botHitWallEvent: handleBotHitWallEvent(bot, $event)
    of Type.botHitBotEvent: handleBotHitBotEvent(bot, $event)
    of Type.bulletFiredEvent: handleBulletFiredEvent(bot, $event)
    of Type.bulletHitBotEvent: handleBulletHitBotEvent(bot, $event)
    of Type.bulletHitBulletEvent: handleBulletHitBulletEvent(bot, $event)
    of Type.bulletHitWallEvent: handleBulletHitWallEvent(bot, $event)
    of Type.scannedBotEvent: handleScannedBotEvent(bot, $event)
    of Type.wonRoundEvent: handleWonRoundEvent(bot, $event)
    else: echo "unknown event type: " & $event["type"].getStr()

  bot.tickEvent = tickEventForBot

  if bot.isFirstTick():
    bot.setRunning(true)
    botRunner_channel.send("run")
  
proc handleSkippedTurnEvent(bot:Bot, packet:string) =
  let skippedTurnEvent = packet.fromJson(SkippedTurnEvent)
  bot.onSkippedTurn(skippedTurnEvent)

proc handleRoundEndedEventForBot(bot:Bot, packet:string) =
  let roundEndedEventForBot = packet.fromJson(RoundEndedEventForBot)
  bot.onRoundEnded(roundEndedEventForBot)
  bot.setRunning(false)

proc handleGameAbortedEvent(bot:Bot, packet:string) =
  let gameAbortedEvent = packet.fromJson(GameAbortedEvent)
  bot.onGameAborted(gameAbortedEvent)
  bot.setRunning(false)

proc handleGameEndedEventForBot(bot:Bot, packet:string) =
  let gameEndedEventForBot = packet.fromJson(GameEndedEventForBot)
  bot.onGameEnded(gameEndedEventForBot)
  bot.setRunning(false)

proc messageHandler(bot: ptr Bot, socket: ptr WebSocket, L:ptr TicketLock) {.gcsafe.} =
  var packet:string=""
  while true:
    try:
      withLock L[]:
        packet = bot[].eventsQueue.pop()
      let `type` = packet.fromJson(Schema).`type`
      case `type`:
      of serverHandshake: handleServerHandshake(bot[], packet, socket[])
      of gameStartedEventForBot: handleGameStartedEventForBot(bot[], packet, socket[])
      of roundStartedEvent: handleRoundStartedEventForBot(bot[], packet)
      of tickEventForBot: handleTickEvent(bot[], packet)
      of skippedTurnEvent: handleSkippedTurnEvent(bot[], packet)
      of roundEndedEventForBot: handleRoundEndedEventForBot(bot[], packet)
      of gameAbortedEvent: handleGameAbortedEvent(bot[], packet)
      of gameEndedEventForBot: handleGameEndedEventForBot(bot[], packet)
      of botIntent: socket[].send(packet)
      else:
        echo "unknown packet type: " & $`type`
    except IndexDefect: continue

proc start*(json_file:string) =
  try:
    # build the bot from the json
    let path:string = joinPath(getAppDir(),json_file)
    let content:string = readFile(path)
    let bot = content.fromJson(Bot)
    var L = initTicketLock()

    botRunner_channel.open()
    
    var m = createMaster()
    m.awaitAll:
      m.spawn botRunner(addr bot)

      bot.setServerUrl getEnv("SERVER_URL", DEFAULT_SERVER_URL)
      bot.setServerSecret getEnv("SERVER_SECRET", DEFAULT_SERVER_SECRET)
  
      let socket = newWebSocket(bot.getServerUrl())
      bot.setConnected(true)
      botRunner_channel.send("connected")

      m.spawn messageHandler(addr bot, addr socket, addr L)

      while true:
        let packet = socket.receiveMessage()
        if packet.isSome():
          let msg = packet.get()
          case msg.kind:
          of Ping:
            socket.send("",Pong)
          of TextMessage:
            withLock L:
              bot.eventsQueue.add(msg.data)
          else:
            echo "unhandled message kind: ", msg.kind

    botRunner_channel.close()
  except IOError:
    quit(1)
