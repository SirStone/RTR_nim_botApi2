import std/[os, strutils, math]
import ws, json, jsony, asyncdispatch

import RTR_nim_botApi2/[Schemas, Utils, BotLib]
export Schemas, BotLib

#++++++++ CONSTANTS ++++++++#
let
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
  serverUrl:string = getEnv("SERVER_URL", DEFAULT_SERVER_URL)
  serverSecret:string = getEnv("SERVER_SECRET", DEFAULT_SERVER_SECRET)
  botRunner_channel:Channel[string]
  intent_channel:Channel[BotIntent]
  currentTurn:int = 0

proc go(bot:Bot) =
  intent_channel.send(bot.getBotIntent())
  currentTurn = bot.getTurn()

  stdout.write "-"
  stdout.flushFile()
  while bot.getTurn() <= currentTurn:
    waitFor sleepAsync(1)

proc botRunner(bot:Bot) {.thread.} =
  echo "botRunner started, waiting on channel"
  let msg:string = botRunner_channel.recv()
  case msg:
  of "connected":
    echo "[botRunner] 'connected' received"
    bot.newIntent()
    while bot.isConnected():
      let msg:string = botRunner_channel.recv()
      case msg:
      of "roundStarted":
        while bot.isRunning() and bot.isConnected():
          bot.go()
      echo "botRunner received message: ", msg
  of "disconnected":
    echo "[botRunner] 'disconnected' received"
  else:
    echo "botRunner received unknown message: ", msg
  echo "botRunner CLOSED"

proc connectAndListen(bot:Bot, serverUrl:string) {.async.} =
  var socket:WebSocket

  proc handleServerHandshake(bot:Bot, packet:string) {.async.} =
    let server_handshake = packet.fromJson(ServerHandshake)
    let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.getName(), version:bot.getVersion, authors:bot.getAuthors, secret:serverSecret, initialPosition:bot.getInitialPosition())
    await socket.send(bot_handshake.toJson())

  proc handleGameStartedEventForBot(bot:Bot, packet:string) {.async.} =
    let gameStartedEventForBot = packet.fromJson(GameStartedEventForBot)
    bot.setGameStartedEventForBot(gameStartedEventForBot)
    await socket.send(BotReady(`type`:Type.botReady).toJson)

  proc handleRoundStartedEventForBot(bot:Bot, packet:string) =
    let roundStartedEvent = packet.fromJson(RoundStartedEvent)
    bot.onRoundStarted(roundStartedEvent)
    bot.setRunning(true)
    botRunner_channel.send("roundStarted")

  proc handleTickEvent(bot:Bot, packet:string) =
    let tickEventForBot = packet.fromJson(TickEventForBot)
    bot.setTick(tickEventForBot)
    bot.onTick(tickEventForBot)
    stdout.write "+"
    stdout.flushFile()

  proc handleSkippedTurnEvent(bot:Bot, packet:string) =
    let skippedTurnEvent = packet.fromJson(SkippedTurnEvent)
    bot.onSkippedTurn(skippedTurnEvent)
    stdout.write("!")
    stdout.flushFile()

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

  proc handleMessage(bot:Bot, packet:string) {.async.} =
    let `type` = packet.fromJson(Schema).`type`
    case `type`:
    of serverHandshake: await handleServerHandshake(bot, packet)
    of gameStartedEventForBot: await handleGameStartedEventForBot(bot, packet)
    of roundStartedEvent: handleRoundStartedEventForBot(bot, packet)
    of tickEventForBot: handleTickEvent(bot, packet)
    of skippedTurnEvent: handleSkippedTurnEvent(bot, packet)
    of roundEndedEventForBot: handleRoundEndedEventForBot(bot, packet)
    of gameAbortedEvent: handleGameAbortedEvent(bot, packet)
    of gameEndedEventForBot: handleGameEndedEventForBot(bot, packet)
    else:
      echo "unknown packet type: " & $`type`

  proc connect() {.async.} =
    try:
      echo "[",bot.getName(),".connect] trying to connect to ", serverUrl
      socket = await newWebSocket(serverUrl)
    except WebSocketClosedError:
      botRunner_channel.send("disconnected")
      echo "Socket closed."
    except WebSocketProtocolMismatchError:
      botRunner_channel.send("disconnected")
      echo "Socket tried to use an unknown protocol: ", getCurrentExceptionMsg()
    except WebSocketError:
      botRunner_channel.send("disconnected")
      echo "Unexpected socket error: ", getCurrentExceptionMsg()
    botRunner_channel.send("connected")
    bot.setConnected(true)

  proc writer() {.async.} =
    while socket.readyState == Open:
      let data = intent_channel.tryRecv()
      if data.msg.isNil:
        await sleepAsync(1)
        continue
      
      await socket.send(data.msg.toJson)

  proc listen() {.async.} =
    try:
      echo "[",bot.getName(),".listen] listening..."
      while socket.readyState == Open:
        let packet = await socket.receiveStrPacket()
        if packet.isEmptyOrWhitespace: continue
        await handleMessage(bot, packet)
    except WebSocketClosedError:
      botRunner_channel.send("disconnected")
      echo "Socket closed."
    except WebSocketProtocolMismatchError:
      botRunner_channel.send("disconnected")
      echo "Socket tried to use an unknown protocol: ", getCurrentExceptionMsg()
    except WebSocketError:
      botRunner_channel.send("disconnected")
      echo "Unexpected socket error: ", getCurrentExceptionMsg()
    except:
      botRunner_channel.send("disconnected")
      echo "Unexpected error: ", getCurrentExceptionMsg()

  await connect()
  asyncCheck writer()
  waitFor listen()

proc start*(json_file:string) =
  try:
    # build the bot from the json
    let path:string = joinPath(getAppDir(),json_file)
    let content:string = readFile(path)
    let bot:Bot = content.fromJson(Bot)

    botRunner_channel.open()
    intent_channel.open()
    
    var botThread:Thread[Bot]

    createThread botThread, botRunner, bot
    waitFor connectAndListen(bot, serverUrl)

    botRunner_channel.close()
    intent_channel.close()
  except IOError:
    quit(1)
