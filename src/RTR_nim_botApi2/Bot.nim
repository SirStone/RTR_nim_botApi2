import std/[os, locks, math]
import jsony
import Schemas

type
  # Condition object for custom conditons
  Condition* = ref object of RootObj
    name*: string # the condition name
    test*: proc (bot:Bot):bool # the condition function

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

    # filled from the environment or during the run
    secret*:string
    serverConnectionURL*:string
    initialPosition*:InitialPosition
    gameSetup*:GameSetup
    myId*:int
    turnNumber*:int
    roundNumber*:int
    botState*:BotState
    intent*:BotIntent = BotIntent(`type`: Type.botIntent)
    first_tick*:bool = true # used to detect if the bot have been stated at first tick

    # usage during the games
    botReady*:bool = false
    listenerReady*:bool = false
    intentReady*:bool = false
    running*:bool = false
    connected*:bool = false
    messagesToSend* = newSeq[string]()

  Bot* = ref object of BluePrint
  
proc newBot*(json_file: string): Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    let path:string = joinPath(getAppDir(),json_file)
    let content:string = readFile(path)
    let bot:Bot = fromJson(content, Bot)
    # maybe code here ...
    return bot
  except IOError:
    quit(1)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot:BluePrint) {.base gcsafe.} = discard # this method is called in a secondary thread
method onBulletFired*(bot:BluePrint, bulletFiredEvent:BulletFiredEvent) {.base gcsafe.} = discard
method onBulletHitBullet*(bot:BluePrint, bulletHitBulletEvent:BulletHitBulletEvent) {.base gcsafe.} = discard
method onBulletHitWall*(bot:BluePrint, bulletHitWallEvent:BulletHitWallEvent) {.base gcsafe.} = discard
method onGameAborted*(bot:BluePrint, gameAbortedEvent:GameAbortedEvent) {.base gcsafe.} = discard
method onGameEnded*(bot:BluePrint, gameEndedEventForBot:GameEndedEventForBot) {.base gcsafe.} = discard
method onGameStarted*(bot:BluePrint, gameStartedEventForBot:GameStartedEventForBot) {.base gcsafe.} = discard
method onHitByBullet*(bot:BluePrint, hitByBulletEvent:HitByBulletEvent) {.base gcsafe.} = discard
method onHitBot*(bot:BluePrint, botHitBotEvent:BotHitBotEvent) {.base gcsafe.} = discard
method onHitWall*(bot:BluePrint, botHitWallEvent:BotHitWallEvent) {.base gcsafe.} = discard
method onRoundEnded*(bot:BluePrint, roundEndedEventForBot:RoundEndedEventForBot) {.base gcsafe.} = discard
method onRoundStarted*(bot:BluePrint, roundStartedEvent:RoundStartedEvent) {.base gcsafe.} = discard
method onSkippedTurn*(bot:BluePrint, skippedTurnEvent:SkippedTurnEvent) {.base gcsafe.} = discard
method onScannedBot*(bot:BluePrint, scannedBotEvent:ScannedBotEvent) {.base gcsafe.} = discard
method onTick*(bot:BluePrint, tickEventForBot:TickEventForBot) {.base gcsafe.} = discard
method onDeath*(bot:BluePrint, botDeathEvent:BotDeathEvent) {.base gcsafe.} =  discard
method onConnect*(bot:BluePrint) {.base gcsafe.} = discard
method onConnectionError*(bot:BluePrint, error:string) {.base gcsafe.} = discard
method onWonRound*(bot:BluePrint, wonRoundEvent:WonRoundEvent) {.base gcsafe.} = discard
method onCustomCondition*(bot:BluePrint, name:string) {.base gcsafe.} = discard

#++++++++ system variables ++++++++#
var turningLocked*:bool = false
var radarLocked*:bool = false
var gunLocked*:bool = false
var movingLocked*:bool = false
var lastbotIntentTurn:int = -1
var messagesSeqLock*:Lock
var customConditionsLock*:Lock
var customConditions* = newSeq[Condition]()

#++++++++ GAME PHYSICS ++++++++#
# bots accelerate at the rate of 1 unit per turn but decelerate at the rate of 2 units per turn
let ACCELERATION:float = 1
let DECELERATION:float = -2

# The speed can never exceed 8 units per turn
let MAX_SPEED:float = 8
var current_maxSpeed:float = MAX_SPEED

# If standing still (0 units/turn), the maximum rate is 10° per turn
let MAX_TURN_RATE:float = 10

# The maximum rate of rotation is 20° per turn. This is added to the current rate of rotation of the bot
let MAX_GUN_TURN_RATE:float = 20

# The maximum rate of rotation is 45° per turn. This is added to the current rate of rotation of the gun
let MAX_RADAR_TURN_RATE:float = 45

# The maximum firepower is 3 and the minimum firepower is 0.1
let MAX_FIRE_POWER:float = 3
let MIN_FIRE_POWER:float = 0.1

#++++++++ REMAININGS ++++++++#
var remaining_turnRate:float = 0
var remaining_turnGunRate:float = 0
var remaining_turnRadarRate:float = 0
var remaining_distance:float = 0

#++++++++ BOT UPDATES ++++++++#
var turnRate_done*:float = 0
var gunTurnRate_done*:float = 0
var radarTurnRate_done*:float = 0
var distance_done*:float = 0

proc resetIntent(bot:Bot) =
  bot.intent.turnRate = 0
  bot.intent.gunTurnRate = 0
  bot.intent.radarTurnRate = 0
  bot.intent.targetSpeed = 0
  bot.intent.rescan = false
  bot.intent.stdOut = ""
  bot.intent.stdErr = ""

proc updateRemainings(bot:Bot) =
  # body turn
  if remaining_turnRate != 0:
    remaining_turnRate = (remaining_turnRate - turnRate_done).round(13)
    bot.intent.turnRate = remaining_turnRate
  else:
    bot.intent.turnRate = 0

  # gun turn
  if remaining_turnGunRate != 0:
    remaining_turnGunRate = (remaining_turnGunRate - gunTurnRate_done).round(13)
    bot.intent.gunTurnRate = remaining_turnGunRate
  else:
    bot.intent.gunTurnRate = 0

  # radar turn
  if remaining_turnRadarRate != 0:
    remaining_turnRadarRate = (remaining_turnRadarRate - radarTurnRate_done).round(13)
    bot.intent.radarTurnRate = remaining_turnRadarRate
  else:
    bot.intent.radarTurnRate = 0

  # target speed calculation
  if remaining_distance != 0:
    remaining_distance = (remaining_distance - distance_done).round(13)
    bot.intent.targetSpeed = remaining_distance
  else:
    bot.intent.targetSpeed = 0

proc isRunning*(bot:Bot):bool = bot.running

proc stop*(bot:Bot) =
  bot.running = false
  bot.first_tick = true
  resetIntent bot

proc start*(bot:Bot) =
  bot.running = true
  bot.first_tick = false
  resetIntent bot

proc go*(bot:Bot) =
  sleep(1)
  # Sending intent to server if the last turn we sent it is different from the current turn
  if bot.turnNumber == lastbotIntentTurn: return

  # update the last turn we sent the intent
  lastbotIntentTurn = bot.turnNumber

  # update the reaminings
  updateRemainings bot

  # signal to send the intent to the game server
  {.locks: [messagesSeqLock].}: bot.messagesToSend.add(bot.intent.toJson)
  # reset the intent for the next turn
  resetIntent bot

#++++++++ BOT HIT BOT EVENT ++++++++#
proc isRammed*(event:BotHitBotEvent):bool =
  ## returns true if the bot is ramming another bot
  return event.rammed

#++++++++ CUSTOM CONDITIONS ++++++++#
proc waitFor*(bot:Bot, condition:Condition) =
  # go until the bot is not running or the remaining_turnRadarRate is 0
  {.gcsafe.}:
    while bot.isRunning and not condition.test(bot):
      go bot

#++++++++ BOT HEALTH ++++++++#
proc getEnergy*(bot:Bot):float =
  ## returns the current energy of the bot
  return bot.botState.energy

#++++++++ BOT SETUP +++++++++#
proc setAdjustGunForBodyTurn*(bot:Bot, adjust:bool) =
  ## this is permanent, no need to call this multiple times
  ## 
  ## use ``true`` if the gun should turn independent from the body
  ## 
  ## use ``false`` if the gun should turn with the body
  bot.intent.adjustGunForBodyTurn = adjust

proc setAdjustRadarForGunTurn*(bot:Bot, adjust:bool) =
  ## this is permanent, no need to call this multiple times
  ## 
  ## use ``true`` if the radar should turn independent from the gun
  ## 
  ## use ``false`` if the radar should turn with the gun
  bot.intent.adjustRadarForGunTurn = adjust

proc setAdjustRadarForBodyTurn*(bot:Bot, adjust:bool) =
  ## this is permanent, no need to call this multiple times
  ## 
  ## use ``true`` if the radar should turn independent from the body
  ## 
  ## use ``false`` if the radar should turn with the body
  bot.intent.adjustRadarForBodyTurn = adjust

proc isAdjustGunForBodyTurn*(bot:Bot):bool =
  ## returns true if the gun is turning independent from the body
  return bot.intent.adjustGunForBodyTurn

proc isAdjustRadarForGunTurn*(bot:Bot):bool =
  ## returns true if the radar is turning independent from the gun
  return bot.intent.adjustRadarForGunTurn

proc isAdjustRadarForBodyTurn*(bot:Bot):bool =
  ## returns true if the radar is turning independent from the body
  return bot.intent.adjustRadarForBodyTurn


#++++++++ COLORS HANDLING +++++++++#
proc setBodyColor*(bot:BluePrint, color:string) =
  ## set the body color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.bodyColor = color

proc setTurretColor*(bot:BluePrint, color:string) =
  ## set the turret color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.turretColor = color

proc setRadarColor*(bot:BluePrint, color:string) =
  ## set the radar color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.radarColor = color

proc setBulletColor*(bot:BluePrint, color:string) =
  ## set the bullet color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.bulletColor = color

proc setScanColor*(bot:BluePrint, color:string) =
  ## set the scan color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.scanColor = color

proc setTracksColor*(bot:BluePrint, color:string) =
  ## set the tracks color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.tracksColor = color

proc setGunColor*(bot:BluePrint, color:string) =
  ## set the gun color, permanently
  ## 
  ## use hex colors, like ``#FF0000``
  bot.intent.gunColor = color

proc getBodyColor*(bot:BluePrint):string =
  ## returns the body color
  return bot.intent.bodyColor

proc getTurretColor*(bot:BluePrint):string =
  ## returns the turret color
  return bot.intent.turretColor

proc getRadarColor*(bot:BluePrint):string =
  ## returns the radar color
  return bot.intent.radarColor

proc getBulletColor*(bot:BluePrint):string =
  ## returns the bullet color
  return bot.intent.bulletColor

proc getScanColor*(bot:BluePrint):string =
  ## returns the scan color
  return bot.intent.scanColor

proc getTracksColor*(bot:BluePrint):string =
  ## returns the tracks color
  return bot.intent.tracksColor

proc getGunColor*(bot:BluePrint):string =
  ## returns the gun color
  return bot.intent.gunColor

#++++++++ ARENA +++++++++#
proc getArenaHeight*(bot:Bot):int =
  ## returns the arena height (vertical)
  return bot.gameSetup.arenaHeight

proc getArenaWidth*(bot:Bot):int =
  ## returns the arena width (horizontal)
  return bot.gameSetup.arenaWidth

#++++++++ GAME AND BOT STATUS +++++++++#
proc getRoundNumber*(bot:Bot):int =
  ## returns the current round number
  return bot.roundNumber

proc getTurnNumber*(bot:Bot):int =
  ## returns the current turn number
  return bot.turnNumber

proc getX*(bot:Bot):float =
  ## returns the bot's X position
  return bot.botState.x

proc getY*(bot:Bot):float =
  ## returns the bot's Y position
  return bot.botState.y

#++++++++ TURNING RADAR +++++++++#
proc setRadarTurnRate*(bot:Bot, degrees:float) =
  ## set the radar turn rate if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_turnRadarRate = degrees

proc setTurnRadarLeft*(bot:Bot, degrees:float) =
  ## set the radar to turn left by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_turnRadarRate = degrees

proc setTurnRadarRight*(bot:Bot, degrees:float) =
  ## set the radar to turn right by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  bot.setTurnRadarLeft(-degrees)

proc turnRadarLeft*(bot:Bot, degrees:float) =
  ## turn the radar left by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  
  if not radarLocked:
    # ask to turnRadar left for all degrees, the server will take care of turnRadaring the bot the max amount of degrees allowed
    bot.setTurnRadarLeft(degrees)
    
    # lock the bot, no other actions must be done until the action is completed
    radarLocked = true

    # go until the bot is not running or the remaining_turnRadarRate is 0
    while bot.isRunning and remaining_turnRadarRate != 0:
      go bot

    # unlock the bot
    radarLocked = false

proc turnRadarRight*(bot:Bot, degrees:float) =
  ## turn the radar right by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  bot.turnRadarLeft(-degrees)

proc getRadarTurnRemaining*(bot:Bot):float =
  ## returns the remaining radar turn rate in degrees
  return remaining_turnRadarRate

proc getRadarDirection*(bot:Bot):float =
  ## returns the current radar direction in degrees
  return bot.botState.radarDirection

proc getMaxRadarTurnRate*(bot:Bot):float =
  ## returns the maximum turn rate of the radar in degrees
  return MAX_RADAR_TURN_RATE

proc setRescan*(bot:Bot) =
  ## set the radar to rescan if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.rescan = true

proc rescan*(bot:Bot) =
  ## rescan the radar if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  
  # ask to rescan
  bot.setRescan()


#++++++++ TURNING GUN +++++++++#
proc setGunTurnRate*(bot:Bot, degrees:float) =
  ## set the gun turn rate if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_turnGunRate = degrees

proc setTurnGunLeft*(bot:Bot, degrees:float) =
  ## set the gun to turn left by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_turnGunRate = degrees

proc setTurnGunRight*(bot:Bot, degrees:float) =
  ## set the gun to turn right by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  bot.setTurnGunLeft(-degrees)

proc turnGunLeft*(bot:Bot, degrees:float) =
  ## turn the gun left by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**

  # ask to turnGun left for all degrees, the server will take care of turnGuning the bot the max amount of degrees allowed
  if not gunLocked:
    bot.setTurnGunLeft(degrees)
    
    # lock the bot, no other actions must be done until the action is completed
    gunLocked = true

    # go until the bot is not running or the remaining_turnGunRate is 0
    while bot.isRunning and remaining_turnGunRate != 0:
      go bot

    # unlock the bot
    gunLocked = false

proc turnGunRight*(bot:Bot, degrees:float) =
  ## turn the gun right by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  bot.turnGunLeft(-degrees)

proc getGunTurnRemaining*(bot:Bot):float =
  ## returns the remaining gun turn rate in degrees
  return remaining_turnGunRate

proc getGunDirection*(bot:Bot):float =
  ## returns the current gun direction in degrees
  return bot.botState.gunDirection

proc getMaxGunTurnRate*(bot:Bot):float =
  return MAX_GUN_TURN_RATE

proc getGunHeat*(bot:Bot):float =
  ## returns the current gun heat
  return bot.botState.gunHeat


#++++++++ TURNING BODY +++++++#
# proc setTurnRate(bot:Bot, degrees:float) =
#   ## set the body turn rate if the bot is not locked doing a blocking call
#   ## 
#   ## **OVERRIDES CURRENT VALUE**
#   if not botLocked:
#     remaining_turnRate = degrees

proc setTurnLeft*(bot:Bot, degrees:float) =
  ## set the body to turn left by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_turnRate = degrees

proc setTurnRight*(bot:Bot, degrees:float) =
  ## set the body to turn right by `degrees` if the bot is not locked doing a blocking call
  ## 
  ## **OVERRIDES CURRENT VALUE**
  bot.setTurnLeft(-degrees)

proc turnLeft*(bot:Bot, degrees:float) =
  ## turn the body left by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**

  if not turningLocked:
    # ask to turn left for all degrees, the server will take care of turning the bot the max amount of degrees allowed
    bot.setTurnLeft(degrees)
    
    # lock the bot, no other actions must be done until the action is completed
    turningLocked = true

    # go until the bot is not running or the remaining_turnRate is 0
    while bot.isRunning and remaining_turnRate != 0:
      go bot

    # unlock the bot
    turningLocked = false

proc turnRight*(bot:Bot, degrees:float) =
  ## turn the body right by `degrees` if the bot is not locked doing another blocking call
  ## 
  ## **BLOCKING CALL**
  bot.turnLeft(-degrees)

proc getTurnRemaining*(bot:Bot):float =
  ## returns the remaining body turn rate in degrees
  return remaining_turnRate

proc getDirection*(bot:Bot):float =
  ## returns the current body direction in degrees
  return bot.botState.direction

proc getMaxTurnRate*(bot:Bot):float =
  ## returns the maximum turn rate of the body in degrees
  return MAX_TURN_RATE

#++++++++ MOVING +++++++++#
proc setTargetSpeed*(bot:Bot, speed:float) =
  ## set the target speed of the bot if the bot is not locked doing a blocking call
  ## 
  ## `speed` can be any value between ``-current max speed`` and ``+current max speed``, any value outside this range will be clamped
  ## 
  ## by default ``max speed`` is ``8 pixels per turn``
  ## 
  ## **OVERRIDES CURRENT VALUE**
  if speed > 0:
    bot.intent.targetSpeed = min(speed, current_maxSpeed)
  elif speed < 0:
    bot.intent.targetSpeed = max(speed, -current_maxSpeed)
  else:
    bot.intent.targetSpeed = speed

proc setForward*(bot:Bot, distance:float) =
  ## set the bot to move forward by `distance` if the bot is not locked doing a blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_distance = distance

proc setBack*(bot:Bot, distance:float) =
  ## set the bot to move back by `distance` if the bot is not locked doing a blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **OVERRIDES CURRENT VALUE**
  bot.setForward(-distance)

proc forward*(bot:Bot, distance:float) =
  ## move the bot forward by `distance` if the bot is not locked doing another blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **BLOCKING CALL**

  if not movingLocked:
    # ask to move forward for all pixels (distance), the server will take care of moving the bot the max amount of pixels allowed
    bot.setForward(distance)
    
    # lock the bot, no other actions must be done until the action is completed
    movingLocked = true

    # go until the bot is not running or the remaining_turnRate is 0
    while bot.isRunning and remaining_distance != 0:
      go bot

    # unlock the bot
    movingLocked = false

proc back*(bot:Bot, distance:float) =
  ## move the bot back by `distance` if the bot is not locked doing another blocking call
  ## 
  ## `distance` is in pixels
  ## 
  ## **BLOCKING CALL**
  bot.forward(-distance)

proc getDistanceRemaining*(bot:Bot):float =
  ## returns the remaining distance to move in pixels
  return remaining_distance

proc setDistanceRemaining*(bot:Bot, distance:float) =
  ## overrides the remaining distance to move
  ## 
  ## **OVERRIDES CURRENT VALUE**
  remaining_distance = distance

proc getAcceleration*(bot:Bot):float =
  ## returns the acceleration of the bot
  return ACCELERATION

proc getDeceleration*(bot:Bot):float =
  ## returns the deceleration of the bot
  return DECELERATION

#++++++++++++++ FIRE! ++++++++++++++#
proc setFire*(bot:Bot, firepower:float):bool =
  ## set the firepower of the next shot if the bot is not locked doing a blocking call
  ## 
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ## 
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the intent of firing will not be added

  # clamp the value
  if bot.botState.energy < firepower or bot.botState.gunHeat > 0:
    return false # cannot fire yet
  else:
    bot.intent.firePower = firepower
    return true

proc getMaxFirePower*(bot:Bot):float =
  ## returns the maximum firepower
  return MAX_FIRE_POWER

proc getMinFirePower*(bot:Bot):float =
  ## returns the minimum firepower
  return MIN_FIRE_POWER

proc fire*(bot:Bot, firepower:float) =
  ## fire a shot with `firepower` if the bot is not locked doing another blocking call
  ## 
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ## 
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the shot will not be fired
  ## 
  # check if the bot is not locked and the bot is able to shoot
  if not gunLocked:
    gunLocked = true
    if bot.setFire(firepower):
      go bot
    gunLocked = false

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

proc directionTo*(bot:Bot, x,y:float):float =
  ## returns the direction (angle) from the bot's coordinates to the point (x,y).
  ## 
  ## `x` and `y` are the coordinates of the point
  ## `return` is the direction to the point x,y in degrees in the range [0,360]
  result = normalizeAbsoluteAngle(radToDeg(arctan2(y-bot.botState.y, x-bot.botState.x)))

proc bearingTo*(bot:Bot, x,y:float):float =
  ## returns the bearing to the point (x,y) in degrees
  ## 
  ## `x` and `y` are the coordinates of the point
  ## `return` is the bearing to the point x,y in degrees in the range [-180,180]
  result = normalizeRelativeAngle(bot.directionTo(x,y) - bot.botState.direction)
