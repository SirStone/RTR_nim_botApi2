import std/[os, strutils, math]
import ws, jsony, json, asyncdispatch

import RTR_nim_botApi2/[Schema]
export Schema

#++++++++ TYPES ++++++++#
type
  BluePrint = ref object of RootObj
    # filled from JSON
    name*:string = "BluePrint"
    version*:string
    description*:string
    homepage*:string
    platform*:string
    programmingLang*:string
    gameTypes*:seq[string]
    authors*:seq[string]
    countryCodes*:seq[string]

  Bot* = ref object of BluePrint

#++++++++ CONSTANTS ++++++++#
let
  # bots accelerate at the rate of 1 unit per turn but decelerate at the rate of 2 units per turn
  ACCELERATION:float = 1
  DECELERATION:float = -2

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

#++++++++ GLOBALS ++++++++#
var
  bot:Bot
  chan:Channel[string]
  wsg:WebSocket
  secret:string
  serverConnectionURL:string
  initialPosition:InitialPosition
  botIntent:BotIntent
  connected:bool = false
  gameSetup:GameSetup
  botState:BotState
  myId:int
  first_tick:bool = true
  running:bool = false
  turnNumber:int
  roundNumber:int
  last_turn_we_sent_intent:int = 0
  botLocked*:bool = false
  current_maxSpeed:float = MAX_SPEED

  #++++++++ REMAININGS ++++++++#
  remaining_turnRate:float = 0
  remaining_turnGunRate:float = 0
  remaining_turnRadarRate:float = 0
  remaining_distance:float = 0

  #++++++++ DONE ++++++++#
  turnRate_done*:float = 0
  gunTurnRate_done*:float = 0
  radarTurnRate_done*:float = 0
  distance_done*:float = 0

  #++++++++ TARGETS ++++++++#
  target_turnRate:float = 0
  target_turnGunRate:float = 0
  target_turnRadarRate:float = 0
  target_targetSpeed:float = 0

#++++++++ BOT EVENTS METHODS ++++++++#
# the following section contains all the methods that are supposed to be overrided by the bot creator
method run(bot:BluePrint) {.base.} = discard # this method is called in a secondary thread
method onBulletFired(bot:BluePrint, bulletFiredEvent:BulletFiredEvent) {.base.} = discard
method onBulletHitBullet(bot:BluePrint, bulletHitBulletEvent:BulletHitBulletEvent) {.base.} = discard
method onBulletHitWall(bot:BluePrint, bulletHitWallEvent:BulletHitWallEvent) {.base.} = discard
method onGameAborted(bot:BluePrint, gameAbortedEvent:GameAbortedEvent) {.base.} = discard
method onGameEnded(bot:BluePrint, gameEndedEventForBot:GameEndedEventForBot) {.base.} = discard
method onGameStarted(bot:BluePrint, gameStartedEventForBot:GameStartedEventForBot) {.base.} = discard
method onHitByBullet(bot:BluePrint, hitByBulletEvent:HitByBulletEvent) {.base.} = discard
method onHitBot(bot:BluePrint, botHitBotEvent:BotHitBotEvent) {.base.} = discard
method onHitWall(bot:BluePrint, botHitWallEvent:BotHitWallEvent) {.base.} = discard
method onRoundEnded(bot:BluePrint, roundEndedEventForBot:RoundEndedEventForBot) {.base.} = discard
method onRoundStarted(bot:BluePrint, roundStartedEvent:RoundStartedEvent) {.base.} = discard
method onSkippedTurn(bot:BluePrint, skippedTurnEvent:SkippedTurnEvent) {.base.} = discard
method onScannedBot(bot:BluePrint, scannedBotEvent:ScannedBotEvent) {.base.} = discard
method onTick(bot:BluePrint, tickEventForBot:TickEventForBot) {.base.} = discard
method onDeath(bot:BluePrint, botDeathEvent:BotDeathEvent) {.base.} =  discard
method onConnect(bot:BluePrint) {.base.} = discard
method onConnectionError(bot:BluePrint, error:string) {.base.} = discard
method onWonRound(bot:BluePrint, wonRoundEvent:WonRoundEvent) {.base.} = discard
method onCustomCondition(bot:BluePrint, name:string) {.base.} = discard

proc sendMsg(json_message:string) {.async.} =
  await wsg.send json_message

proc nearZero(number:float):bool =
  ## returns true if the number is near zero
  ## 
  ## `number` is the number to check
  ## `return` is true if the number is near zero
  return abs(number) < 0.000001

proc updateRemainings() =
  # body turn
  if target_turnRate != 0:
    botIntent.turnRate = target_turnRate
  elif not remaining_turnRate.nearZero():
    remaining_turnRate = remaining_turnRate - turnRate_done
    botIntent.turnRate = remaining_turnRate
  else:
    remaining_turnRate = 0
    botIntent.turnRate = 0

  # gun turn
  if target_turnGunRate != 0:
    botIntent.gunTurnRate = target_turnGunRate
  elif not remaining_turnGunRate.nearZero():
    remaining_turnGunRate = remaining_turnGunRate - gunTurnRate_done
    botIntent.gunTurnRate = remaining_turnGunRate
  else:
    remaining_turnGunRate = 0
    botIntent.gunTurnRate = 0

  # radar turn
  if target_turnRadarRate != 0:
    botIntent.radarTurnRate = target_turnRadarRate
  elif not remaining_turnRadarRate.nearZero():
    remaining_turnRadarRate = remaining_turnRadarRate - radarTurnRate_done
    botIntent.radarTurnRate = remaining_turnRadarRate
  else:
    remaining_turnRadarRate = 0
    botIntent.radarTurnRate = 0

  # target speed calculation
  if target_targetSpeed != 0:
    botIntent.targetSpeed = target_targetSpeed
  elif not remaining_distance.nearZero():
    remaining_distance = remaining_distance - distance_done
    botIntent.targetSpeed = remaining_distance
  else:
    remaining_distance = 0
    botIntent.targetSpeed = 0

  # echo "remaining_distance: ", remaining_distance, " remaining_turnRate: ", remaining_turnRate, " remaining_turnGunRate: ", remaining_turnGunRate, " remaining_turnRadarRate: ", remaining_turnRadarRate

#++++++++ BOT INTENT ++++++++#
proc go*() =
  ## **Send the bot intent**
  
  last_turn_we_sent_intent = turnNumber

  # update the remainings
  updateRemainings()

  stdout.write("-")
  stdout.flushFile()

  waitFor sendMsg toJson botIntent

  # wait for the next turn
  while turnNumber == last_turn_we_sent_intent and running:
    waitFor sleepAsync(1) # to make the dispatcher happy

#++++++++ END BOT INTENT ++++++++#

#++++++++ BOT HIT BOT EVENT ++++++++#
proc isRammed*(event:BotHitBotEvent):bool =
  ## returns true if the bot is ramming another bot
  return event.rammed
#++++++++ END BOT HIT BOT EVENT ++++++++#

#++++++++ BOT HEALTH ++++++++#
proc getEnergy*():float =
  ## returns the current energy of the bot
  return botState.energy

proc isRunning*():bool =
  ## returns `true` if the bot is running
  ## 
  ## **READ ONLY**
  return running

proc getGunHeat*():float =
  ## returns the current gun heat
  return botState.gunHeat
#++++++++ END BOT HEALTH ++++++++#

#++++++++ BOT SETUP +++++++++#
proc setAdjustGunForBodyTurn*(adjust:bool) =
  ## this is permanent, no need to call this multiple times
  ## 
  ## use ``true`` if the gun should turn independent from the body
  ## 
  ## use ``false`` if the gun should turn with the body
  botIntent.adjustGunForBodyTurn = adjust

proc setAdjustRadarForGunTurn*(adjust:bool) =
  ## this is permanent, no need to call this multiple times
  ## 
  ## use ``true`` if the radar should turn independent from the gun
  ## 
  ## use ``false`` if the radar should turn with the gun
  botIntent.adjustRadarForGunTurn = adjust

proc setAdjustRadarForBodyTurn*(adjust:bool) =
  ## this is permanent, no need to call this multiple times
  ## 
  ## use ``true`` if the radar should turn independent from the body
  ## 
  ## use ``false`` if the radar should turn with the body
  botIntent.adjustRadarForBodyTurn = adjust

proc isAdjustGunForBodyTurn*(bot:Bot):bool =
  ## returns true if the gun is turning independent from the body
  return botIntent.adjustGunForBodyTurn

proc isAdjustRadarForGunTurn*(bot:Bot):bool =
  ## returns true if the radar is turning independent from the gun
  return botIntent.adjustRadarForGunTurn

proc isAdjustRadarForBodyTurn*(bot:Bot):bool =
  ## returns true if the radar is turning independent from the body
  return botIntent.adjustRadarForBodyTurn
#++++++++ END BOT SETUP +++++++++#

#++++++++ COLORS HANDLING +++++++++#
proc setBodyColor*(color:string) =
  ## set the body color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.bodyColor = color

proc setTurretColor*(color:string) =
  ## set the turret color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.turretColor = color

proc setRadarColor*(color:string) =
  ## set the radar color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.radarColor = color

proc setBulletColor*(color:string) =
  ## set the bullet color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.bulletColor = color

proc setScanColor*(color:string) =
  ## set the scan color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.scanColor = color

proc setTracksColor*(color:string) =
  ## set the tracks color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.tracksColor = color

proc setGunColor*(color:string) =
  ## set the gun color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  botIntent.gunColor = color

proc getBodyColor*():string =
  ## returns the body color
  return botIntent.bodyColor

proc getTurretColor*():string =
  ## returns the turret color
  return botIntent.turretColor

proc getRadarColor*():string =
  ## returns the radar color
  return botIntent.radarColor

proc getBulletColor*():string =
  ## returns the bullet color
  return botIntent.bulletColor

proc getScanColor*():string =
  ## returns the scan color
  return botIntent.scanColor

proc getTracksColor*():string =
  ## returns the tracks color
  return botIntent.tracksColor

proc getGunColor*():string =
  ## returns the gun color
  return botIntent.gunColor
#++++++++ END COLORS HANDLING +++++++++#

#++++++++ ARENA +++++++++#
proc getArenaHeight*():int =
  ## returns the arena height (vertical)
  return gameSetup.arenaHeight

proc getArenaWidth*():int =
  ## returns the arena width (horizontal)
  return gameSetup.arenaWidth
#++++++++ END ARENA +++++++++#

#++++++++ GAME AND BOT STATUS +++++++++#
proc getRoundNumber*():int =
  ## returns the current round number
  return roundNumber

proc getTurnNumber*():int =
  ## returns the current turn number
  return turnNumber

proc getX*():float =
  ## returns the bot's X position
  return botState.x

proc getY*():float =
  ## returns the bot's Y position
  return botState.y
#++++++++ END GAME AND BOT STATUS +++++++++#

#++++++++ TURNING RADAR +++++++++#
proc setRadarTurnRate*(target_degrees:float) =
  ## set the radar turn rate if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_turnRadarRate = target_degrees

proc setTurnRadarLeft*(degrees:float) =
  ## set the radar to turn left by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_turnRadarRate = 0
    remaining_turnRadarRate = degrees

proc setTurnRadarRight*(degrees:float) =
  ## set the radar to turn right by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  setTurnRadarLeft(-degrees)

proc turnRadarLeft*(degrees:float) =
  ## turn the radar left by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  if not botLocked:
    # ask to turnRadar left for all degrees, the server will take care of turnRadaring the bot the max amount of degrees allowed
    setTurnRadarLeft(degrees)
    
    # lock the bot, no other actions must be done until the action is completed
    botLocked = true

    # go until the bot is not running or the remaining_turnRadarRate is 0
    while isRunning() and remaining_turnRadarRate != 0:
      go()

    # unlock the bot
    botLocked = false

proc turnRadarRight*(degrees:float) =
  ## turn the radar right by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  turnRadarLeft(-degrees)

proc getRadarTurnRemaining*():float =
  ## returns the remaining radar turn rate in degrees
  return remaining_turnRadarRate

proc getRadarTurnRate*():float =
  ## returns the current radar turn rate in degrees
  return botIntent.radarTurnRate

proc getRadarDirection*():float =
  ## returns the current radar direction in degrees
  return botState.radarDirection

proc getMaxRadarTurnRate*():float =
  ## returns the maximum turn rate of the radar in degrees
  return MAX_RADAR_TURN_RATE

proc setRescan*() =
  ## set the radar to rescan if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  botIntent.rescan = true

proc rescan*() =
  ## rescan the radar if the bot is not locked doing another blocking call
  
  # ask to rescan
  setRescan()
#++++++++ END TURNING RADAR +++++++++#

#++++++++ TURNING GUN +++++++++#
proc setGunTurnRate*(degrees:float) =
  ## set the gun turn rate if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_turnGunRate = degrees

proc setTurnGunLeft*(degrees:float) =
  ## set the gun to turn left by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_turnGunRate = 0
    remaining_turnGunRate = degrees

proc setTurnGunRight*(degrees:float) =
  ## set the gun to turn right by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  setTurnGunLeft(-degrees)

proc turnGunLeft*(degrees:float) =
  ## turn the gun left by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**

  # ask to turnGun left for all degrees, the server will take care of turnGuning the bot the max amount of degrees allowed
  if not botLocked:
    setTurnGunLeft(degrees)
    
    # lock the bot, no other actions must be done until the action is completed
    botLocked = true

    # go until the bot is not running or the remaining_turnGunRate is 0
    while isRunning() and remaining_turnGunRate != 0:
      go()

    # unlock the bot
    botLocked = false

proc turnGunRight*(degrees:float) =
  ## turn the gun right by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  turnGunLeft(-degrees)

proc getGunTurnRemaining*():float =
  ## returns the remaining gun turn rate in degrees
  return remaining_turnGunRate

proc getGunDirection*():float =
  ## returns the current gun direction in degrees
  return botState.gunDirection

proc getGunTurnRate*():float =
  ## returns the current gun turn rate in degrees
  return botIntent.gunTurnRate

proc getMaxGunTurnRate*():float =
  return MAX_GUN_TURN_RATE
#++++++++ END TURNING GUN +++++++++#

#++++++++ TURNING BODY +++++++#
proc setTurnRate*(degrees:float) =
  ## set the body turn rate if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_turnRate = degrees

proc setTurnLeft*(degrees:float) =
  ## set the body to turn left by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_turnRate = 0
    remaining_turnRate = degrees

proc setTurnRight*(degrees:float) =
  ## set the body to turn right by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  setTurnLeft(-degrees)

proc turnLeft*(degrees:float) =
  ## turn the body left by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**

  if not botLocked:
    # ask to turn left for all degrees, the server will take care of turning the bot the max amount of degrees allowed
    setTurnLeft(degrees)
    
    # lock the bot, no other actions must be done until the action is completed
    botLocked = true

    # go until the bot is not running or the remaining_turnRate is 0
    while isRunning() and remaining_turnRate != 0:
      go()

    # unlock the bot
    botLocked = false

proc turnRight*(degrees:float) =
  ## turn the body right by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  turnLeft(-degrees)

proc getTurnRemaining*():float =
  ## returns the remaining body turn rate in degrees
  return remaining_turnRate

proc getTurnRate*():float =
  ## returns the current body turn rate in degrees
  return botIntent.turnRate

proc getDirection*():float =
  ## returns the current body direction in degrees
  return botState.direction

proc getMaxTurnRate*():float =
  ## returns the maximum turn rate of the body in degrees
  return MAX_TURN_RATE
#++++++++ END TURNING +++++++#

#++++++++ MOVING +++++++++#
proc setTargetSpeed*(speed:float) =
  ## set the target speed of the bot if the bot is not locked doing a blocking call
  ## 
  ## `speed` can be any value between ``-current max speed`` and ``+current max speed``, any value outside this range will be clamped
  ## 
  ## by default ``max speed`` is ``8 pixels per turn``
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    if speed > 0:
      target_targetSpeed = min(speed, current_maxSpeed)
    elif speed < 0:
      target_targetSpeed = max(speed, -current_maxSpeed)
    else:
      target_targetSpeed = speed

proc setForward*(distance:float) =
  ## set the bot to move forward by `distance` if the bot is not locked doing a blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if not botLocked:
    target_targetSpeed = 0
    remaining_distance = distance

proc setBack*(distance:float) =
  ## set the bot to move back by `distance` if the bot is not locked doing a blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **OVERRIDES CURRENT VALUE**
  setForward(-distance)

proc forward*(distance:float) =
  ## move the bot forward by `distance` if the bot is not locked doing another blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **BLOCKING CALL**

  if not botLocked:
    # ask to move forward for all pixels (distance), the server will take care of moving the bot the max amount of pixels allowed
    setForward(distance)
    
    # lock the bot, no other actions must be done until the action is completed
    botLocked = true

    # go until the bot is not running or the remaining_turnRate is 0
    while isRunning() and remaining_distance != 0:
      go()

    # unlock the bot
    botLocked = false

proc back*(distance:float) =
  ## move the bot back by `distance` if the bot is not locked doing another blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **BLOCKING CALL**
  forward(-distance)

proc getDistanceRemaining*():float =
  ## returns the remaining distance to move in pixels
  return remaining_distance

proc setDistanceRemaining*(distance:float) =
  ## overrides the remaining distance to move
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_distance = distance

proc getTargetSpeed*():float =
  ## returns the current target speed
  return botIntent.targetSpeed

proc getAcceleration*():float =
  ## returns the acceleration of the bot
  return ACCELERATION

proc getDeceleration*():float =
  ## returns the deceleration of the bot
  return DECELERATION
#++++++++ END MOVING +++++++++#

#++++++++++++++ FIRE! ++++++++++++++#
proc setFire*(firepower:float):bool =
  ## set the firepower of the next shot if the bot is not locked doing a blocking call
  ## 
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ## 
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the intent of firing will not be added

  # clamp the value
  if botState.energy < firepower or botState.gunHeat > 0:
    return false # cannot fire yet
  else:
    botIntent.firePower = firepower
    return true

proc getMaxFirePower*():float =
  ## returns the maximum firepower
  return MAX_FIRE_POWER

proc getMinFirePower*():float =
  ## returns the minimum firepower
  return MIN_FIRE_POWER

proc fire*(firepower:float) =
  ## fire a shot with `firepower` if the bot is not locked doing another blocking call
  ## 
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ## 
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the shot will not be fired
  ## 
  # check if the bot is not locked and the bot is able to shoot
  # if not botLocked:
  #   botLocked = true
  if setFire(firepower):
    go()
    # botLocked = false

proc setFireAssist*(enable:bool) =
  ## enable or disable the autofire
  ## 
  ## **OVERRIDES CURRENT VALUE**
  botIntent.fireAssist = enable
#++++++++++++++ END FIRE! ++++++++++++++#

#++++++++++++++ UTILS ++++++++++++++#
proc normalizeAbsoluteAngle*(angle:float):float =
  ## normalize the angle to an absolute angle into the range [0,360]
  ## 
  ## `angle` is the angle to normalize
  ## `return` is the normalized absolute angle
  let angle_mod = angle.toInt mod 360
  if angle_mod >= 0:
    return angle_mod.toFloat
  else:
    return (angle_mod + 360).toFloat

proc normalizeRelativeAngle*(angle:float):float =
  ## normalize the angle to the range [-180,180]
  ## 
  ## `angle` is the angle to normalize
  ## `return` is the normalized angle
  let angle_mod = angle.toInt mod 360
  return if angle_mod >= 0:
    if angle_mod < 180: angle_mod.toFloat
    else: (angle_mod - 360).toFloat
  else:
    if angle_mod >= -180: angle_mod.toFloat
    else: (angle_mod + 360).toFloat

proc directionTo*(x,y:float):float =
  ## returns the direction (angle) from the bot's coordinates to the point (x,y).
  ## 
  ## `x` and `y` are the coordinates of the point
  ## `return` is the direction to the point x,y in degrees in the range [0,360]
  result = normalizeAbsoluteAngle(radToDeg(arctan2(y-botState.y, x-botState.x)))

proc bearingTo*(x,y:float):float =
  ## returns the bearing to the point (x,y) in degrees
  ## 
  ## `x` and `y` are the coordinates of the point
  ## `return` is the bearing to the point x,y in degrees in the range [-180,180]
  result = normalizeRelativeAngle(directionTo(x,y) - botState.direction)
#++++++++++++++ END UTILS ++++++++++++++#

proc resetIntent() =
  botIntent.turnRate = 0
  botIntent.gunTurnRate = 0
  botIntent.radarTurnRate = 0
  botIntent.targetSpeed = 0
  botIntent.rescan = false
  botIntent.stdOut = ""
  botIntent.stdErr = ""

  target_targetSpeed = 0
  target_turnRate = 0
  target_turnGunRate = 0
  target_turnRadarRate = 0

  remaining_turnRate = 0
  remaining_turnGunRate = 0
  remaining_turnRadarRate = 0
  remaining_distance = 0

proc stopBot() =
  running = false
  first_tick = true
  resetIntent()

proc startBot() =
  running = true
  resetIntent()
  
proc handleMessage(json_message:string) {.async.} =
  # Convert the json to a Message object
  let message = json2schema json_message

  # 'case' switch over type
  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message
    let bot_handshake = BotHandshake(`type`:Type.botHandshake, sessionId:server_handshake.sessionId, name:bot.name, version:bot.version, authors:bot.authors, secret:secret, initialPosition:initialPosition)
    await sendMsg bot_handshake.toJson
    
    # signal that the connection is ready
    connected = true
    chan.send("connected")
    bot.onConnect()

    # initializing the bot intent
    botIntent = BotIntent(`type`:Type.botIntent, fireAssist:true)

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    gameSetup = game_started_event_for_bot.gameSetup
    myId = game_started_event_for_bot.myId

    # activating the bot method
    bot.onGameStarted(game_started_event_for_bot)
    
    # send bot ready
    await sendMsg BotReady(`type`:Type.botReady).toJson

  of tickEventForBot:
    stdout.write("+")
    stdout.flushFile()

    let tick_event_for_bot = (TickEventForBot)message
    if first_tick:
      turnRate_done = 0
      gunTurnRate_done = 0
      radarTurnRate_done = 0
      distance_done = 0

      # notify the bot that the round is started
      chan.send("run")

      first_tick = false
    else:
      turnRate_done = tick_event_for_bot.botState.direction - botState.direction
      turnRate_done = (turnRate_done + 540) mod 360 - 180

      gunTurnRate_done = tick_event_for_bot.botState.gunDirection - botState.gunDirection
      gunTurnRate_done = (gunTurnRate_done + 540) mod 360 - 180

      radarTurnRate_done = tick_event_for_bot.botState.radarDirection - botState.radarDirection
      radarTurnRate_done = (radarTurnRate_done + 540) mod 360 - 180

      distance_done = tick_event_for_bot.botState.speed
      
    botState = tick_event_for_bot.botState
    turnNumber = tick_event_for_bot.turnNumber
    roundNumber = tick_event_for_bot.roundNumber
    # activating the bot method
    bot.onTick(tick_event_for_bot)
    # for every event inside this tick call the relative event for the bot
    for event in tick_event_for_bot.events:
      case parseEnum[Type](event["type"].getStr()):
      of Type.botDeathEvent:
        # if the bot is dead we stop it
        stopBot()

        # Notifiy the bot that it is dead
        bot.onDeath(fromJson($event, BotDeathEvent))
      of Type.botHitWallEvent:
        # stop bot movement
        setDistanceRemaining(0)

        bot.onHitWall(fromJson($event, BotHitWallEvent))
      of Type.bulletFiredEvent:
        botIntent.firePower = 0 # Reset firepower so the bot stops firing continuously
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
        setDistanceRemaining(0)

        bot.onHitBot(fromJson($event, BotHitBotEvent))
      of Type.scannedBotEvent:
        bot.onScannedBot(fromJson($event, ScannedBotEvent))
      of Type.wonRoundEvent:
        bot.onWonRound(fromJson($event, WonRoundEvent))     
      else:
        echo "NOT HANDLED BOT TICK EVENT: ", event
    
  of gameAbortedEvent:
    stopBot()

    let game_aborted_event = (GameAbortedEvent)message

    # activating the bot method
    bot.onGameAborted(game_aborted_event)

  of gameEndedEventForBot:
    stopBot()

    let game_ended_event_for_bot = (GameEndedEventForBot)message

    # activating the bot method
    bot.onGameEnded(game_ended_event_for_bot)

  of skippedTurnEvent:
    let skipped_turn_event = (SkippedTurnEvent)message
    
    # activating the bot method
    bot.onSkippedTurn(skipped_turn_event)

  of roundEndedEventForBot:
    stopBot()

    let round_ended_event_for_bot = json_message.fromJson(RoundEndedEventForBot)

    # activating the bot method
    bot.onRoundEnded(round_ended_event_for_bot)

  of roundStartedEvent:
    # Start the bot
    startBot()
    
    # activating the bot method
    let round_started_event = (RoundStartedEvent)message
    bot.onRoundStarted(round_started_event)

  else: echo "NOT HANDLED MESSAGE: ",json_message

proc communications() {.async.} =
  while wsg.readyState == Open:
    let msg = await wsg.receiveStrPacket()

    if msg.isEmptyOrWhitespace(): continue
    
    await handleMessage(msg)

proc processor() {.async.} =
  # the connections is still not established here, lets wait for the signal
  while true:
    var msg = chan.tryRecv()
    if msg.dataAvailable:
      case msg.msg:
      of "connected":
        echo "[processor] aknowledged connection"

        # wait for the bot to be ready to run
        while connected:
          msg = chan.tryRecv()
          if msg.dataAvailable:
            case msg.msg:
            of "run":
              echo "[processor] run command received"
              # first we run the custom bot method
              run bot

              # after we send the intent automatically
              while isRunning() and connected:
                go()
            else:
              echo "[processor] unhandled message 2: ", msg
          else:
            await sleepAsync(1)

      of "abort":
        echo "[processor] aborting..."
      else:
        echo "[processor] unhandled message 1: ", msg
        return
    else:
      await sleepAsync(1)

proc startEngine() {.async.} =
  try:
    wsg = await newWebSocket(serverConnectionURL)

    # start the bot processor
    asyncCheck processor()

    # start the communication interface
    waitFor communications()
  except Exception as e:
    echo "[startEngine] error: ", e.msg
  
proc newBot(json_file: string): Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    let path:string = joinPath(getAppDir(),json_file)
    let content:string = readFile(path)
    let bot = fromJson(content, Bot)
    # maybe code here ...
    return bot
  except IOError as e:
    echo "[conf] Error reading config file: ", e.msg
    quit(1)

proc startBot*(json_file:string, connect:bool = true, position:InitialPosition = InitialPosition(x:0,y:0,angle:0)) =
  ## **Start the bot**
  ## 
  ## This method is used to start the bot instance. This coincide with asking the bot to connect to the game server
  ## 
  ## `json_file` is the bot json file path that will be used to configure the  The file must be in the same folder of the executable.
  ## 
  ## `connect` (can be omitted) is a boolean value that if `true` (default) will ask the bot to connect to the game server.
  ## If `false` the bot will not connect to the game server. Mostly used for testing.
  ## 
  ## `position` (can be omitted) is the initial position of the  If not specified the bot will be placed at the center of the map.
  ## This custom position will work if the server is configured to use the custom initial positions
  
  # create the bot instance
  bot = newBot(json_file)

  # set the initial position, is the server that will decide to use it or not
  initialPosition = position

  # open channels
  open chan

  # connect to the Game Server
  if(connect):
    if secret == "":
      secret = getEnv("SERVER_SECRET", "serversecret")

    if serverConnectionURL == "": 
      serverConnectionURL = getEnv("SERVER_URL", "ws://localhost:7654")

    # start the engine of the bot
    waitFor startEngine()

  # close channels
  close chan
  echo "[startBot] bot is powered off. Bye!"
