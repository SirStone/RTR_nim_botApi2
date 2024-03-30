import std/[os, math, atomics]
import jsony
import Schemas

type
  Condition* = object
    name*: string = "no name"
    test*: proc(bot: Bot): bool

  BluePrint = ref object of RootObj
    # filled from JSON
    name*: string = "BluePrint"
    version*: string
    description*: string
    homepage*: string
    platform*: string
    programmingLang*: string
    gameTypes*: seq[string]
    authors*: seq[string]
    countryCodes*: seq[string]

    # filled from the environment or during the run
    secret*: string
    serverConnectionURL*: string
    initialPosition*: InitialPosition
    gameSetup*: GameSetup
    myId*: int
    turnNumber*: int
    roundNumber*: int
    botState*: BotState
    intent*: BotIntent = BotIntent(`type`: Type.botIntent)
    first_tick*: bool = true # used to detect if the bot have been stated at first tick

    # usage during the games
    botReady*: bool = false
    listenerReady*: bool = false
    running: Atomic[bool]

  Bot* = ref object of BluePrint

proc newBot*(json_file: string): Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    let path: string = joinPath(getAppDir(), json_file)
    let content: string = readFile(path)
    let bot: Bot = fromJson(content, Bot)
    # maybe code here ...
    return bot
  except IOError:
    quit(1)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot: BluePrint) {.base gcsafe.} = discard
method onBulletFired*(bot: BluePrint, bulletFiredEvent: BulletFiredEvent) {.base gcsafe.} = discard
method onBulletHitBullet*(bot: BluePrint,
    bulletHitBulletEvent: BulletHitBulletEvent) {.base gcsafe.} = discard
method onBulletHitWall*(bot: BluePrint, bulletHitWallEvent: BulletHitWallEvent) {.base gcsafe.} = discard
method onGameAborted*(bot: BluePrint, gameAbortedEvent: GameAbortedEvent) {.base gcsafe.} = discard
method onGameEnded*(bot: BluePrint, gameEndedEventForBot: GameEndedEventForBot) {.base gcsafe.} = discard
method onGameStarted*(bot: BluePrint, gameStartedEventForBot: GameStartedEventForBot) {.base gcsafe.} = discard
method onHitByBullet*(bot: BluePrint, hitByBulletEvent: HitByBulletEvent) {.base gcsafe.} = discard
method onHitBot*(bot: BluePrint, botHitBotEvent: BotHitBotEvent) {.base gcsafe.} = discard
method onHitWall*(bot: BluePrint, botHitWallEvent: BotHitWallEvent) {.base gcsafe.} = discard
method onRoundEnded*(bot: BluePrint, roundEndedEventForBot: RoundEndedEventForBot) {.base gcsafe.} = discard
method onRoundStarted*(bot: BluePrint, roundStartedEvent: RoundStartedEvent) {.base gcsafe.} = discard
method onSkippedTurn*(bot: BluePrint, skippedTurnEvent: SkippedTurnEvent) {.base gcsafe.} = discard
method onScannedBot*(bot: BluePrint, scannedBotEvent: ScannedBotEvent) {.base gcsafe.} = discard
method onTick*(bot: BluePrint, tickEventForBot: TickEventForBot) {.base gcsafe.} = discard
method onDeath*(bot: BluePrint, botDeathEvent: BotDeathEvent) {.base gcsafe.} = discard
method onConnect*(bot: BluePrint) {.base gcsafe.} = discard
method onConnectionError*(bot: BluePrint, error: string) {.base gcsafe.} = discard
method onWonRound*(bot: BluePrint, wonRoundEvent: WonRoundEvent) {.base gcsafe.} = discard
method onCustomCondition*(bot: BluePrint, name: string) {.base gcsafe.} = discard

#+++++++++ INTENT ++++++++++#
var sendIntent*: Atomic[bool]

# channels
var botWorkerChan*: Channel[string]
var nextTurn*: Channel[string]
var eventsHandlerChan*: Channel[string]

# connection
var connected: bool = false

# actions lock
var locked: Atomic[bool]

#++++++++ GAME PHYSICS ++++++++#
# bots accelerate at the rate of 1 unit per turn but decelerate at the rate of 2 units per turn
let ACCELERATION: float = 1
let DECELERATION: float = -2

# The speed can never exceed 8 units per turn
let MAX_SPEED: float = 8
var current_maxSpeed: float = MAX_SPEED

# If standing still (0 units/turn), the maximum rate is 10° per turn
let MAX_TURN_RATE: float = 10

# The maximum rate of rotation is 20° per turn. This is added to the current rate of rotation of the bot
let MAX_GUN_TURN_RATE: float = 20

# The maximum rate of rotation is 45° per turn. This is added to the current rate of rotation of the gun
let MAX_RADAR_TURN_RATE: float = 45

# The maximum firepower is 3 and the minimum firepower is 0.1
let MAX_FIRE_POWER: float = 3
let MIN_FIRE_POWER: float = 0.1

#++++++++ REMAININGS ++++++++#
var remaining_turn: float = 0
var remaining_gunTurn: float = 0
var remaining_radarTurn: float = 0
var remaining_distance: float = 0

#++++++++ BOT UPDATES ++++++++#
var turn_done*: float = 0
var gunTurn_done*: float = 0
var radarTurn_done*: float = 0
var distance_done*: float = 0

proc console_log*(bot: Bot, msg: string) =
  bot.intent.stdOut.add(msg & "\r\n")

proc resetIntent*(bot: Bot) =
  bot.intent.rescan = false
  bot.intent.stdOut = ""
  bot.intent.stdErr = ""

proc isNearZero(value: float): bool =
  return abs(value) < 0.00001

proc notifyNextTurn*() =
  ## This method is used to notify the bot that the next turn is ready
  nextTurn.send("")

proc updateRemainings*(bot: Bot) =
  # set fire aasist to true
  bot.intent.fireAssist = true

  # body turn
  if remaining_turn != 0:
    remaining_turn = remaining_turn - turn_done
    if (isNearZero(remaining_turn)):
      remaining_turn = 0
      bot.intent.turnRate = 0
    else:
      bot.intent.turnRate = clamp(remaining_turn, -MAX_TURN_RATE, MAX_TURN_RATE)

  # gun turn
  if remaining_gunTurn != 0:
    remaining_gunTurn = remaining_gunTurn - gunTurn_done
    if (isNearZero(remaining_gunTurn)):
      remaining_gunTurn = 0
      bot.intent.gunTurnRate = 0
    else:
      bot.intent.gunTurnRate = clamp(remaining_gunTurn, -MAX_GUN_TURN_RATE, MAX_GUN_TURN_RATE)

  # radar turn
  if remaining_radarTurn != 0:
    remaining_radarTurn = remaining_radarTurn - radarTurn_done
    if (isNearZero(remaining_radarTurn)):
      remaining_radarTurn = 0
      bot.intent.radarTurnRate = 0
    else:
      bot.intent.radarTurnRate = clamp(remaining_radarTurn, -MAX_RADAR_TURN_RATE, MAX_RADAR_TURN_RATE)

  # target speed calculation
  if remaining_distance != 0:
    remaining_distance = remaining_distance - distance_done
    if (isNearZero(remaining_distance)):
      remaining_distance = 0
      bot.intent.targetSpeed = 0
    else:
      bot.intent.targetSpeed = clamp(remaining_distance, -current_maxSpeed, current_maxSpeed)

proc isRunning*(bot: Bot): bool = bot.running.load()

proc stop*(bot: Bot) =
  bot.running.store(false)

  # reset the intent to defualt
  bot.intent = BotIntent(`type`: Type.botIntent)

  notifyNextTurn() # this notify any hanged go() to remain in waiting

proc start*(bot: Bot) =
  bot.intent = BotIntent(`type`: Type.botIntent)
  
  bot.running.store(true)
  locked.store(false)
  sendIntent.store(false)
  bot.first_tick = true

proc go*(bot: Bot) =
  if sendIntent.load() or not bot.isRunning(): return # if the bot is already sending an intent, return
  # send the intent
  sendIntent.store(true)

  # wait for next turn
  discard nextTurn.recv()
  sendIntent.store(false)

#+++++++++++++ BATTLEFIELD ++++++++++++++#
proc getBattlefieldHeight*(bot: Bot): float =
  ## returns the battlefield height (vertical)
  return (float)bot.gameSetup.arenaHeight

proc getBattlefieldWidth*(bot: Bot): float =
  ## returns the battlefield width (horizontal)
  return (float)bot.gameSetup.arenaWidth

#++++++++ BOT HIT BOT EVENT ++++++++#
proc isRammed*(event: BotHitBotEvent): bool =
  ## returns true if the bot is ramming another bot
  return event.rammed

#++++++++ BOT HEALTH ++++++++#
proc getEnergy*(bot: Bot): float =
  ## returns the current energy of the bot
  if bot.botState == nil:
    return 100
  else:
    return bot.botState.energy

#++++++++ CONNECTION ++++++++#
proc isConnected*(): bool =
  ## returns true if the bot is connected to the server
  return connected

proc setConnected*(isConnected: bool) =
  ## set the connection status
  connected = isConnected

#++++++++ BOT SETUP +++++++++#
proc setAdjustGunForBodyTurn*(bot: Bot, adjust: bool) =
  ## this is permanent, no need to call this multiple times
  ##
  ## use ``true`` if the gun should turn independent from the body
  ##
  ## use ``false`` if the gun should turn with the body
  bot.intent.adjustGunForBodyTurn = adjust

proc setAdjustRadarForGunTurn*(bot: Bot, adjust: bool) =
  ## this is permanent, no need to call this multiple times
  ##
  ## use ``true`` if the radar should turn independent from the gun
  ##
  ## use ``false`` if the radar should turn with the gun
  bot.intent.adjustRadarForGunTurn = adjust

proc setAdjustRadarForBodyTurn*(bot: Bot, adjust: bool) =
  ## this is permanent, no need to call this multiple times
  ##
  ## use ``true`` if the radar should turn independent from the body
  ##
  ## use ``false`` if the radar should turn with the body
  bot.intent.adjustRadarForBodyTurn = adjust

proc isAdjustGunForBodyTurn*(bot: Bot): bool =
  ## returns true if the gun is turning independent from the body
  return bot.intent.adjustGunForBodyTurn

proc isAdjustRadarForGunTurn*(bot: Bot): bool =
  ## returns true if the radar is turning independent from the gun
  return bot.intent.adjustRadarForGunTurn

proc isAdjustRadarForBodyTurn*(bot: Bot): bool =
  ## returns true if the radar is turning independent from the body
  return bot.intent.adjustRadarForBodyTurn


#++++++++ COLORS HANDLING +++++++++#
proc setBodyColor*(bot: BluePrint, color: string) =
  ## set the body color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.bodyColor = color

proc setTurretColor*(bot: BluePrint, color: string) =
  ## set the turret color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.turretColor = color

proc setRadarColor*(bot: BluePrint, color: string) =
  ## set the radar color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.radarColor = color

proc setBulletColor*(bot: BluePrint, color: string) =
  ## set the bullet color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.bulletColor = color

proc setScanColor*(bot: BluePrint, color: string) =
  ## set the scan color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.scanColor = color

proc setTracksColor*(bot: BluePrint, color: string) =
  ## set the tracks color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.tracksColor = color

proc setGunColor*(bot: BluePrint, color: string) =
  ## set the gun color, permanently
  ##
  ## use hex colors, like ``#FF0000``
  bot.intent.gunColor = color

proc getBodyColor*(bot: BluePrint): string =
  ## returns the body color
  return bot.intent.bodyColor

proc getTurretColor*(bot: BluePrint): string =
  ## returns the turret color
  return bot.intent.turretColor

proc getRadarColor*(bot: BluePrint): string =
  ## returns the radar color
  return bot.intent.radarColor

proc getBulletColor*(bot: BluePrint): string =
  ## returns the bullet color
  return bot.intent.bulletColor

proc getScanColor*(bot: BluePrint): string =
  ## returns the scan color
  return bot.intent.scanColor

proc getTracksColor*(bot: BluePrint): string =
  ## returns the tracks color
  return bot.intent.tracksColor

proc getGunColor*(bot: BluePrint): string =
  ## returns the gun color
  return bot.intent.gunColor

#++++++++ ARENA +++++++++#
proc getArenaHeight*(bot: Bot): int =
  ## returns the arena height (vertical)
  return bot.gameSetup.arenaHeight

proc getArenaWidth*(bot: Bot): int =
  ## returns the arena width (horizontal)
  return bot.gameSetup.arenaWidth

#++++++++ GAME AND BOT STATUS +++++++++#
proc getRoundNumber*(bot: Bot): int =
  ## returns the current round number
  return bot.roundNumber

proc getTurnNumber*(bot: Bot): int =
  ## returns the current turn number
  return bot.turnNumber

proc getX*(bot: Bot): float =
  ## returns the bot's X position
  return bot.botState.x

proc getY*(bot: Bot): float =
  ## returns the bot's Y position
  return bot.botState.y

#++++++++ TURNING RADAR +++++++++#
proc getRadarTurnRemaining*(bot: Bot): float =
  ## returns the remaining radar turn rate in degrees
  return remaining_radarTurn

proc getRadarDirection*(bot: Bot): float =
  ## returns the current radar direction in degrees
  return bot.botState.radarDirection

proc getMaxRadarTurnRate*(bot: Bot): float =
  ## returns the maximum turn rate of the radar in degrees
  return MAX_RADAR_TURN_RATE

proc setRadarTurnRate*(bot: Bot, degrees: float) =
  ## set the radar turn rate if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.radarTurnRate = degrees

proc setRadarTurnLeft*(bot: Bot, degrees: float) =
  ## set the radar to turn left by `degrees` if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  remaining_radarTurn = degrees

proc setRadarTurnRight*(bot: Bot, degrees: float) =
  ## set the radar to turn right by `degrees` if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.setRadarTurnLeft(-degrees)

proc radarTurnLeft*(bot: Bot, degrees: float) =
  ## turn the radar left by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  
  # if bot is locked the bot can't do other actions
  if locked.load(): return

  # else we lock it
  locked.store(true)

  # ask to radarTurn left for all degrees, the server will take care of radarTurning the bot the max amount of degrees allowed
  bot.setRadarTurnLeft(degrees)

  # go until the bot is not running or the remaining_radarTurnRate is 0
  while bot.isRunning and bot.getRadarTurnRemaining != 0:
    go bot

  # unlock the bot
  locked.store(false)

proc radarTurnRight*(bot: Bot, degrees: float) =
  ## turn the radar right by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  bot.radarTurnLeft(-degrees)

proc setRescan*(bot: Bot) =
  ## set the radar to rescan if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.rescan = true

proc rescan*(bot: Bot) =
  ## rescan the radar if the bot is not locked doing another blocking call

  # ask to rescan
  bot.setRescan()

#++++++++ TURNING GUN +++++++++#
proc setGunTurnRate*(bot: Bot, degrees: float) =
  ## set the gun turn rate if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.gunTurnRate = degrees

proc setGunTurnLeft*(bot: Bot, degrees: float) =
  ## set the gun to turn left by `degrees` if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  remaining_gunTurn = degrees

proc setGunTurnRight*(bot: Bot, degrees: float) =
  ## set the gun to turn right by `degrees` if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.setGunTurnLeft(-degrees)

proc gunTurnLeft*(bot: Bot, degrees: float) =
  ## turn the gun left by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  
  # if bot is locked the bot can't do other actions
  if locked.load(): return

  # else we lock it
  locked.store(true)

  # ask to gunTurn left for all degrees, the server will take care of gunTurning the bot the max amount of degrees allowed
  bot.setGunTurnLeft(degrees)

  # go until the bot is not running or the remaining_gunTurnRate is 0
  while bot.isRunning and remaining_gunTurn != 0:
    go bot

  # unlock the bot
  locked.store(false)

proc gunTurnRight*(bot: Bot, degrees: float) =
  ## turn the gun right by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  bot.gunTurnLeft(-degrees)

proc getGunTurnRemaining*(bot: Bot): float =
  ## returns the remaining gun turn rate in degrees
  return remaining_gunTurn

proc getGunDirection*(bot: Bot): float =
  ## returns the current gun direction in degrees
  return bot.botState.gunDirection

proc getMaxGunTurnRate*(bot: Bot): float =
  return MAX_GUN_TURN_RATE

proc getGunHeat*(bot: Bot): float =
  ## returns the current gun heat
  return bot.botState.gunHeat

#++++++++ TURNING BODY +++++++#
## TODO: maybe this needs some rethink
proc setTurnRate*(bot:Bot, degrees:float) =
  ## set the body turn rate if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.turnRate = degrees

proc setTurnLeft*(bot: Bot, degrees: float) =
  ## set the body to turn left by `degrees` if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  remaining_turn = degrees

proc setTurnRight*(bot: Bot, degrees: float) =
  ## set the body to turn right by `degrees` if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.setTurnLeft(-degrees)

proc turnLeft*(bot: Bot, degrees: float) =
  ## turn the body left by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  
  # if bot is locked the bot can't do other actions
  if locked.load(): return

  # else we lock it
  locked.store(true)

  # ask to turn left for all degrees, the server will take care of turning the bot the max amount of degrees allowed
  bot.setTurnLeft(degrees)

  # go until the bot is not running or the remaining_turnRate is 0
  while bot.isRunning() and remaining_turn != 0:
    bot.go()

  # unlock the bot
  locked.store(false)

proc turnRight*(bot: Bot, degrees: float) =
  ## turn the body right by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  bot.turnLeft(-degrees)

proc getTurnRemaining*(bot: Bot): float =
  ## returns the remaining body turn rate in degrees
  return remaining_turn

proc getDirection*(bot: Bot): float =
  ## returns the current body direction in degrees
  return bot.botState.direction

proc getMaxTurnRate*(bot: Bot): float =
  ## returns the maximum turn rate of the body in degrees
  return MAX_TURN_RATE

#++++++++ MOVING +++++++++#
proc setTargetSpeed*(bot: Bot, speed: float) =
  ## set the target speed of the bot if the bot is not locked doing a blocking call
  ##
  ## `speed` can be any value between ``-current max speed`` and ``+current max speed``, any value outside this range will be clamped
  ##
  ## by default ``max speed`` is ``8 pixels per turn``
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.targetSpeed = clamp(speed, -current_maxSpeed, current_maxSpeed)

proc getTargetSpeed*(bot: Bot): float =
  ## returns the target speed of the bot
  return bot.intent.targetSpeed

proc getMaxSpeed*(bot: Bot): float =
  ## returns the maximum speed of the bot
  return MAX_SPEED

proc getCurrentMaxSpeed*(bot: Bot): float =
  ## returns the current maximum speed of the bot
  return current_maxSpeed

proc setCurrentMaxSpeed*(bot: Bot, speed: float) =
  ## set the current maximum speed of the bot
  ##
  ## `speed` can be any value between ``0`` and ``+MAX_SPEED``, any value outside this range will be clamped
  ##
  ## **OVERRIDES CURRENT VALUE**
  current_maxSpeed = clamp(speed, 0, MAX_SPEED)

proc setForward*(bot: Bot, distance: float) =
  ## set the bot to move forward by `distance` if the bot is not locked doing a blocking call
  ##
  ## `distance` is in pixels
  ##
  ## **OVERRIDES CURRENT VALUE**
  remaining_distance = distance

proc setBack*(bot: Bot, distance: float) =
  ## set the bot to move back by `distance` if the bot is not locked doing a blocking call
  ##
  ## `distance` is in pixels
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.setForward(-distance)

proc forward*(bot: Bot, distance: float) =
  ## move the bot forward by `distance` if the bot is not locked doing another blocking call
  ##
  ## `distance` is in pixels
  ##
  ## **BLOCKING CALL**
  
  # if bot is locked the bot can't do other actions
  if locked.load(): return

  # else we lock it
  locked.store(true)

  # ask to move forward for all pixels (distance), the server will take care of moving the bot the max amount of pixels allowed
  bot.setForward(distance)

  # go until the bot is not running or the remaining_turnRate is 0
  while bot.isRunning and remaining_distance != 0:
    go bot

  # unlock the bot
  locked.store(false)

proc back*(bot: Bot, distance: float) =
  ## move the bot back by `distance` if the bot is not locked doing another blocking call
  ##
  ## `distance` is in pixels
  ##
  ## **BLOCKING CALL**
  bot.forward(-distance)

proc getDistanceRemaining*(bot: Bot): float =
  ## returns the remaining distance to move in pixels
  return remaining_distance

proc setDistanceRemaining*(bot: Bot, distance: float) =
  ## overrides the remaining distance to move
  ##
  ## **OVERRIDES CURRENT VALUE**
  remaining_distance = distance

proc getAcceleration*(bot: Bot): float =
  ## returns the acceleration of the bot
  return ACCELERATION

proc getDeceleration*(bot: Bot): float =
  ## returns the deceleration of the bot
  return DECELERATION

#++++++++++++++ FIRE! ++++++++++++++#
proc setFire*(bot: Bot, firepower: float): bool =
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

proc getMaxFirePower*(bot: Bot): float =
  ## returns the maximum firepower
  return MAX_FIRE_POWER

proc getMinFirePower*(bot: Bot): float =
  ## returns the minimum firepower
  return MIN_FIRE_POWER

proc fire*(bot: Bot, firepower: float) =
  ## fire a shot with `firepower` if the bot is not locked doing another blocking call
  ##
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ##
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the shot will not be fired
  ##
  # check if the bot is not locked and the bot is able to shoot

  # TODO does fire() ignores locked movements?
  if bot.setFire(firepower):
    go bot

#++++++++++++++ CUSTOM CONDITIONS ++++++++++++++#
proc waitFor*(bot: Bot, condition: Condition) {.gcsafe.} =
  ## wait for a custom condition to be true
  ##
  ## `condition` is the condition to wait for
  ##
  ## **BLOCKING CALL**
  {.gcsafe.}:
    while not condition.test(bot) and bot.isRunning():
      go bot
  
#++++++++++++++ UTILS ++++++++++++++#
proc normalizeAbsoluteAngle*(angle: float): float =
  ## normalize the angle to an absolute angle into the range [0,360]
  ##
  ## `angle` is the angle to normalize
  ## `return` is the normalized absolute angle
  let angle_mod = angle.toInt mod 360
  if angle_mod >= 0:
    return angle_mod.toFloat
  else:
    return (angle_mod + 360).toFloat

proc normalizeRelativeAngle*(angle: float): float =
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

proc directionTo*(bot: Bot, x, y: float): float =
  ## returns the direction (angle) from the bot's coordinates to the point (x,y).
  ##
  ## `x` and `y` are the coordinates of the point
  ## `return` is the direction to the point x,y in degrees in the range [0,360]
  result = normalizeAbsoluteAngle(radToDeg(arctan2(y-bot.botState.y,
      x-bot.botState.x)))

proc bearingTo*(bot: Bot, x, y: float): float =
  ## returns the bearing to the point (x,y) in degrees
  ##
  ## `x` and `y` are the coordinates of the point
  ## `return` is the bearing to the point x,y in degrees in the range [-180,180]
  result = normalizeRelativeAngle(bot.directionTo(x, y) -
      bot.botState.direction)
