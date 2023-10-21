import std/[strutils, locks]
import Bot, Schema
import jsony, json, whisky

# globals
var
  botWorker_connectedLock*:Lock
  intentWorker_connectedLock*:Lock
  connectedCond*:Cond
  runningLock*:Lock
  runningCond*:Cond
  intentLock*:Lock
  intentCond*:Cond

# proc intentSenderWorker*(intentSenderObj:IntentSenderObj) {.thread.} =
#   while true:
#     echo "[intentSender] waiting for intent signal"
#     # wait for the intent
#     wait intentCond, intentLock

#     echo "[intentSender] intent signal received, sending intent"
#     # send the intent
#     waitFor intentSenderObj.gs_ws.send(intentSenderObj.bot.intent.toJson)
#     echo "[intentSender] intent sent for turn ", intentSenderObj.bot.turnNumber

proc handleMessage*(bot:Bot, json_message:string) =
  # Convert the json to a Message object
  let message = json2schema json_message

  bot.lastMessageType = message.`type`

  # 'case' switch over type
  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message
    let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.name, version:bot.version, authors:bot.authors, secret:bot.secret, initialPosition:bot.initialPosition)
    bot.gs_ws.send(bot_handshake.toJson)

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    bot.gameSetup = game_started_event_for_bot.gameSetup
    bot.myId = game_started_event_for_bot.myId

    # activating the bot method
    bot.onGameStarted(game_started_event_for_bot)
    
    # send bot ready
    bot.gs_ws.send(BotReady(`type`:Type.botReady).toJson)

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
    withLock runningLock: signal runningCond

    let round_started_event = (RoundStartedEvent)message

    # activating the bot method
    bot.onRoundStarted(round_started_event)

  else: echo "NOT HANDLED MESSAGE: ",json_message