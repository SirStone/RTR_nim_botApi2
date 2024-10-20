import std/[os, strutils, math, atomics, tables, sets, hashes, tables, algorithm]
import ws, jsony, json, asyncdispatch
import RTR_nim_botApi2/[Schemas, Utils]

export Schemas

# method onCustomEvent
# method onTeamMeassge
#+++++++++ INTENT ++++++++++#
var sendIntent*: Atomic[bool]

#+++++++++ CONSTANTS ++++++++++#
const
  MAX_QUEUE_SIZE:int = 256
  MAX_EVENTS_AGE:int = 2
  MIN_VALUE:int = -2147483648

  # priorities for events
  WON_ROUND:int = 150
  SKIPPED_TURN:int = 140
  TICK:int = 130
  CUSTOM:int = 120
  TEAM_MESSAGE:int = 110
  BOT_DEATH:int = 100
  BULLET_HIT_WALL:int = 90
  BULLET_HIT_BULLET:int = 80
  BULLET_HIT_BOT:int = 70
  BULLET_FIRED:int = 60
  HIT_BY_BULLET:int = 50
  HIT_WALL:int = 40
  HIT_BOT:int = 30
  SCANNED_BOT:int = 20
  DEATH:int = 10

  # event priorities table
  EVENT_PRIORITIES = {
    Type.wonRoundEvent: WON_ROUND,
    Type.skippedTurnEvent: SKIPPED_TURN,
    Type.tickEventForBot: TICK,
    # Type.customEvent: CUSTOM, # TODO: Implement custom event
    Type.teamMessageEvent: TEAM_MESSAGE,
    Type.botDeathEvent: BOT_DEATH,
    Type.bulletHitWallEvent: BULLET_HIT_WALL,
    Type.bulletHitBulletEvent: BULLET_HIT_BULLET,
    Type.bulletHitBotEvent: BULLET_HIT_BOT,
    Type.bulletFiredEvent: BULLET_FIRED,
    Type.hitByBulletEvent: HIT_BY_BULLET,
    Type.botHitWallEvent: HIT_WALL,
    Type.botHitBotEvent: HIT_BOT,
    Type.scannedBotEvent: SCANNED_BOT,
    Type.botDeathEvent: DEATH
  }.toTable

  #++++++++ GAME PHYSICS ++++++++#
  # bots accelerate at the rate of 1 unit per turn but decelerate at the rate of 2 units per turn
  ACCELERATION: float = 1
  DECELERATION: float = 2

  # The speed can never exceed 8 units per turn
  MAX_SPEED: float = 8

  # If standing still (0 units/turn), the maximum rate is 10° per turn
  MAX_TURN_RATE: float = 10

  # The maximum rate of rotation is 20° per turn. This is added to the current rate of rotation of the bot
  MAX_GUN_TURN_RATE: float = 20

  # The maximum rate of rotation is 45° per turn. This is added to the current rate of rotation of the gun
  MAX_RADAR_TURN_RATE: float = 45

  # The maximum firepower is 3 and the minimum firepower is 0.1
  MAX_FIRE_POWER: float = 3
  MIN_FIRE_POWER: float = 0.1

type
  InterruptEventHandlerException* = object of CatchableError

  EventQueue = ref object of RootObj
    running: bool = false
    events: seq[Event] = @[]
    currentTopEvent: Event = nil
    currentTopEventPriority: int = MIN_VALUE
    interruptibles: HashSet[Event] = HashSet[Event]()
    
  BluePrint = ref object of RootObj
    # filled from JSON
    name: string = "BluePrint"
    version: string
    description: string
    homepage: string
    platform: string
    programmingLang: string
    gameTypes: seq[string]
    authors: seq[string]
    countryCodes: seq[string]

    # filled from the environment or during the run
    initialPosition: InitialPosition
    gameSetup: GameSetup
    myId: int
    tick: TickEventForBot
    intent: BotIntent = BotIntent(`type`: Type.botIntent)
    secret: string
    serverConnectionURL: string

    # usage during the games
    botReady: bool = false
    listenerReady: bool = false

    # event queue
    eventQueue = EventQueue()

  Bot* = ref object of BluePrint

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot: BluePrint) {.base gcsafe.} = discard
method onBulletFired*(bot: BluePrint, bulletFiredEvent: BulletFiredEvent) {.base gcsafe.} = discard
method onBulletHit*(bot: BluePrint,bulletHitBotEvent: BulletHitBotEvent) {.base gcsafe.} = discard
method onBulletHitBullet*(bot: BluePrint,bulletHitBulletEvent: BulletHitBulletEvent) {.base gcsafe.} = discard
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
method onBotDeath*(bot: BluePrint, botDeathEvent: BotDeathEvent) {.base gcsafe.} = discard
# method onDeath
method onConnected*(bot: BluePrint) {.base gcsafe.} = discard
# method onDisconnected
method onConnectionError*(bot: BluePrint, error: string) {.base gcsafe.} = discard
method onWonRound*(bot: BluePrint, wonRoundEvent: WonRoundEvent) {.base gcsafe.} = discard

# global variables
var
  bot:Bot # the bot instance
  webSocket: WebSocket # the websocket connection to the server
# threads
  events_handlerThread: Thread[Bot]
  botRunnerThread: Thread[Bot]
# channels
  out_queue: Channel[string]
  in_queue: Channel[string]
  bot_channel: Channel[string]
  events_queue: Channel[string]
# atomics
  running: Atomic[bool]
  first_tick: Atomic[bool] # used to detect if the bot have been stated at first tick
  waiting_for_next_turn: Atomic[bool]

proc hash(event:Event):Hash = hash(event.`type`)

proc clearEvents(q:EventQueue) =
  q.events = @[]

proc clear(q:EventQueue) =
  q.clearEvents()
  q.currentTopEventPriority = MIN_VALUE

proc addEvent*(q:EventQueue, event:Event) =
  if q.events.len < MAX_QUEUE_SIZE:
    q.events.add(event.deepCopy())
  else:
    echo "Event queue is full"

# proc addCustomEvent ## TODO: Implement custom event

proc setInterruptible*(q:EventQueue, event:Event, interuptible:bool) =
  if interuptible:
    q.interruptibles.incl(event)
  else:
    discard q.interruptibles.missingOrExcl(event)

proc setInterruptible(q:EventQueue, interruptible:bool) =
  q.setInterruptible(q.currentTopEvent, interruptible)

proc isInterruptible(q:EventQueue):bool =
  q.interruptibles.contains(q.currentTopEvent)

proc isNotOldOrIsCriticalEvent(botEvent:Event, turnNumber:int):bool =
  result = botEvent.turnNumber >= turnNumber - MAX_EVENTS_AGE or botEvent.isCritical

proc isOldAndNonCriticalEvent(event:Event, turnNumber:int):bool =
  result = event.turnNumber < turnNumber - MAX_EVENTS_AGE and not event.isCritical

proc removeOldEvents(bot:Bot, turnNumber:int) =
  var i = 0
  while i < bot.eventQueue.events.len:
    if isOldAndNonCriticalEvent(bot.eventQueue.events[i], turnNumber):
      bot.eventQueue.events.del(i)
    else:
      inc i

proc getPriority(event:Event):int =
  try:
    result = EVENT_PRIORITIES[event.`type`]
  except KeyError:
    # echo "Could not get the priority for the event: ", $event.`type`
    result = 0

proc eventsComparator(botEvent1, botEvent2:Event):int =
  # Critical must be placed before non-critical
  var diff = botEvent2.isCritical.int - botEvent1.isCritical.int
  if diff != 0: return diff
  
  # Lower (older) turn number must be placed before higher (newer) turn number
  diff = botEvent1.turnNumber - botEvent2.turnNumber
  if diff != 0: return diff

  # Higher priority must be placed before lower priority
  return botEvent2.getPriority() - botEvent1.getPriority()

proc sortEvents(bot:Bot) =
  bot.eventQueue.events.sort(eventsComparator, SortOrder.Descending)

proc isSameEvent(q:EventQueue, botEvent:Event):bool =
  result = botEvent.getPriority() == q.currentTopEventPriority and (q.currentTopEventPriority > MIN_VALUE and q.isInterruptible())

proc handleEvent(bot:Bot, botEvent:Event, turnNumber:int) =
  try:
    if isNotOldOrIsCriticalEvent(botEvent, turnNumber):
      # Handle the event
      case botEvent.`type`:
      of tickEventForBot:
        bot.onTick (TickEventForBot)botEvent
      of skippedTurnEvent:
        bot.onSkippedTurn (SkippedTurnEvent)botEvent
      of gameEndedEventForBot:
        bot.onGameEnded (GameEndedEventForBot)botEvent
      of gameAbortedEvent:
        bot.onGameAborted (GameAbortedEvent)botEvent
      of gameStartedEventForBot:
        bot.onGameStarted (GameStartedEventForBot)botEvent
      of roundStartedEvent:
        bot.onRoundStarted (RoundStartedEvent)botEvent
      of roundEndedEventForBot:
        bot.onRoundEnded (RoundEndedEventForBot)botEvent
      of bulletFiredEvent:
        bot.onBulletFired (BulletFiredEvent)botEvent
      of bulletHitBotEvent:
        let bullet_hit_bot_event = (BulletHitBotEvent)botEvent

        # from this event we need to find out if the bot was hit by a bullet
        # or if the bullet hit another bot
        if bullet_hit_bot_event.victimId == bot.myId: # check if our bot is the victim
          # create the HitByBulletEvent
          let hit_by_bullet_event = HitByBulletEvent(
            `type`:hitByBulletEvent,
            bullet: bullet_hit_bot_event.bullet,
            damage: bullet_hit_bot_event.damage,
            energy: bullet_hit_bot_event.energy
          )
          bot.onHitByBullet(hit_by_bullet_event)
        else:
          bot.onBulletHit(bullet_hit_bot_event)
      of bulletHitBulletEvent:
        bot.onBulletHitBullet (BulletHitBulletEvent)botEvent
      of bulletHitWallEvent:
        bot.onBulletHitWall (BulletHitWallEvent)botEvent
      of botHitBotEvent:
        bot.onHitBot (BotHitBotEvent)botEvent
      of botHitWallEvent:
        bot.onHitWall (BotHitWallEvent)botEvent
      of scannedBotEvent:
        bot.onScannedBot (ScannedBotEvent)botEvent
      of botDeathEvent:
        bot.onBotDeath (BotDeathEvent)botEvent
      of wonRoundEvent:
        bot.onWonRound (WonRoundEvent)botEvent
      else:
        echo "[events_handler] missing handler for ", event.`type`

    bot.eventQueue.setInterruptible(botEvent, false)
  except Exception:
    discard
  finally:
    bot.eventQueue.setInterruptible(botEvent, false)

proc getNextEvent(q:EventQueue):Event =
  try:
    result = q.events.pop()
  except IndexDefect:
    result = nil

proc dispatchEvents*(bot:Bot, turnNumber:int) =
  bot.removeOldEvents(turnNumber)
  bot.sortEvents()

  while bot.eventQueue.running:
    let currentEvent = bot.eventQueue.getNextEvent()
    if currentEvent == nil: 
      break
    
    if bot.eventQueue.isSameEvent(currentEvent):
      if bot.eventQueue.isInterruptible():
        bot.eventQueue.setInterruptible(currentEvent, false) # clear interruptible flag

        # We are already in an event handler, took action, and a new event was generated.
        # So we want to break out of the old handler to process the new event here.
        raise newException(InterruptEventHandlerException, "Interrupting event handler on purpose")
      break;

    let oldTopEventPriority = bot.eventQueue.currentTopEventPriority
    bot.eventQueue.currentTopEventPriority = currentEvent.getPriority()
    bot.eventQueue.currentTopEvent = currentEvent

    try:
      bot.handleEvent(currentEvent, turnNumber)
    except InterruptEventHandlerException:
      echo "Interrupting event handler on purpose"
      discard # Ignore the exception, expected when event handler is interrupted on purpose
    finally:
      bot.eventQueue.currentTopEventPriority = oldTopEventPriority

proc setRunning(value: bool) = running.store(value)
proc isRunning*(): bool = running.load()
proc isFirstTick(): bool = first_tick.load()
proc setFirstTick(value: bool) = first_tick.store(value)
proc isWaitingForNextTurn(): bool = waiting_for_next_turn.load()
proc setWaitingForNextTurn(value: bool) = waiting_for_next_turn.store(value)

#+++++++++ BOT ADJUSTABLES ++++++++++#
var current_maxSpeed: float = MAX_SPEED

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
var previousDirection: float = 0

proc log*(bot: Bot, items: varargs[string, `$`]) =
  var message:string = ""
  for x in items:
    message = message & x
  
  echo "[LOG] ", message
  bot.intent.stdOut.add(message & "\r\n")

proc error*(bot: Bot, items: varargs[string, `$`]) =
  var message:string = ""
  for x in items:
    message = message & x
  # echo "[ERROR] ", message
  bot.intent.stdErr.add(message & "\r\n")

proc newIntent(bot: Bot) =
  bot.intent = BotIntent(`type`: Type.botIntent)
  
  # set fire assist to true by default
  bot.intent.fireAssist = true

proc resetIntent(bot: Bot) =
  bot.intent.rescan = false
  bot.intent.stdOut = ""
  bot.intent.stdErr = ""
  # bot.intent.firePower = 0
  # bot.intent.targetSpeed = 0
  # bot.intent.turnRate = 0
  # bot.intent.gunTurnRate = 0
  # bot.intent.radarTurnRate = 0

proc isNearZero*(value: float): bool =
  return abs(value) < 0.00001

proc getMaxDeceleration(speed: float): float =
  let decelerationTime = speed / DECELERATION
  let accelerationTime = 1 - decelerationTime
  return min(1, decelerationTime) * DECELERATION + max(0, accelerationTime) * ACCELERATION

proc getMaxSpeed(distance: float): float =
  var decelerationTime = max(1, ceil((sqrt((4 * 2 / DECELERATION) * distance + 1) - 1) / 2))

  if decelerationTime == Inf: return MAX_SPEED

  var decelerationDistance = (decelerationTime / 2) * (decelerationTime - 1) * DECELERATION
  return ((decelerationTime - 1) * DECELERATION) + ((distance - decelerationDistance) / decelerationTime)

## Returns the new speed based on the current speed and distance to move.
## speed = current speed
## distance = distance to move
## return The new speed
## 
## Credits for this algorithm goes to Patrick Cupka (aka Voidious),
## Julian Kent (aka Skilgannon), and Positive for the original version:
## https://robowiki.net/wiki/User:Voidious/Optimal_Velocity#Hijack_2
proc getNewTargetSpeed(speed:float, distance:float): float =
  if distance < 0:
    return -getNewTargetSpeed(-speed, -distance)

  var targetSpeed = if distance == Inf: MAX_SPEED else: min(MAX_SPEED, getMaxSpeed(distance))

  return if speed >= 0:
    clamp(targetSpeed, speed - DECELERATION, speed + ACCELERATION)
  else:
    clamp(targetSpeed, speed - ACCELERATION, speed + getMaxDeceleration(-speed))

proc updateBodyTurning(bot:Bot) =
  if remaining_turn != 0:
    remaining_turn = remaining_turn - turn_done
    if (isNearZero(remaining_turn)):
      remaining_turn = 0
      bot.intent.turnRate = 0
    else:
      bot.intent.turnRate = clamp(remaining_turn, -MAX_TURN_RATE, MAX_TURN_RATE)
  
  # var delta = calcDeltaAngle(bot.tick.botState.direction, previousDirection)
  # previousDirection = bot.tick.botState.direction

  # if abs(remaining_turn) <= abs(delta):
  #   remaining_turn = 0
  # else:
  #   remaining_turn -= delta
  #   if isNearZero(remaining_turn):
  #     remaining_turn = 0
  # bot.intent.turnRate = remaining_turn


    echo "body turning -> done:", turn_done, " remaining:", remaining_turn, " intent:", bot.intent.turnRate 

proc updateGunTurning(bot:Bot) =
  if remaining_gunTurn != 0:
    remaining_gunTurn = remaining_gunTurn - gunTurn_done
    if (isNearZero(remaining_gunTurn)):
      remaining_gunTurn = 0
      bot.intent.gunTurnRate = 0
    else:
      bot.intent.gunTurnRate = clamp(remaining_gunTurn, -MAX_GUN_TURN_RATE, MAX_GUN_TURN_RATE)

proc updateRadarTurning(bot:Bot) =
  if remaining_radarTurn != 0:
    remaining_radarTurn = remaining_radarTurn - radarTurn_done
    if (isNearZero(remaining_radarTurn)):
      remaining_radarTurn = 0
      bot.intent.radarTurnRate = 0
    else:
      bot.intent.radarTurnRate = clamp(remaining_radarTurn, -MAX_RADAR_TURN_RATE, MAX_RADAR_TURN_RATE)

proc updateDistance(bot:Bot) =
  if remaining_distance != 0:
    remaining_distance = remaining_distance - distance_done
    if (isNearZero(remaining_distance)):
      remaining_distance = 0
      bot.intent.targetSpeed = 0
    else:
      bot.intent.targetSpeed = getNewTargetSpeed(bot.tick.botState.speed, remaining_distance)

#+++++++++++++ BOT ++++++++++++++#
proc getName*(bot:Bot): string =
  ## returns the name of the bot
  return bot.name

proc getId*(bot:Bot): int = 
  ## returns the id of the bot
  return bot.myId

proc getVersion*(bot:Bot): string =
  ## returns the version of the bot
  return bot.version

proc getDescription*(bot:Bot): string =
  ## returns the description of the bot
  return bot.description

proc getHomepage*(bot:Bot): string =
  ## returns the homepage of the bot
  return bot.homepage

proc getPlatform*(bot:Bot): string =
  ## returns the platform of the bot
  return bot.platform

proc getProgrammingLang*(bot:Bot): string =
  ## returns the programming language of the bot
  return bot.programmingLang

proc getGameTypes*(bot:Bot): seq[string] =
  ## returns the game types of the bot
  return bot.gameTypes

proc getAuthors*(bot:Bot): seq[string] =
  ## returns the authors of the bot
  return bot.authors

proc getCountryCodes*(bot:Bot): seq[string] =
  ## returns the country codes of the bot
  return bot.countryCodes

proc setInitialPosition*(bot:Bot, initialPosition: InitialPosition) =
  ## set the initial position of the bot
  bot.initialPosition = initialPosition

proc getSecret*(bot:Bot): string =
  ## returns the secret of the bot
  return bot.secret

proc setSecret*(bot:Bot, secret: string) =
  ## set the secret of the bot
  bot.secret = secret

proc getServerConnectionURL*(bot:Bot): string =
  ## returns the server connection URL of the bot
  return bot.serverConnectionURL

proc setServerConnectionURL*(bot:Bot, serverConnectionURL: string) =
  ## set the server connection URL of the bot
  bot.serverConnectionURL = serverConnectionURL

proc getInitialPosition*(bot:Bot): InitialPosition =
  ## returns the initial position of the bot
  return bot.initialPosition

proc setName*(bot:Bot, name: string) =
  ## set the name of the bot
  bot.name = name

proc setId*(bot:Bot, id: int) =
  ## set the id of the bot
  bot.myId = id

proc setVersion*(bot:Bot, version: string) =
  ## set the version of the bot
  bot.version = version

proc setDescription*(bot:Bot, description: string) =
  ## set the description of the bot
  bot.description = description

proc setHomepage*(bot:Bot, homepage: string) =
  ## set the homepage of the bot
  bot.homepage = homepage

proc setPlatform*(bot:Bot, platform: string) =
  ## set the platform of the bot
  bot.platform = platform

proc setProgrammingLang*(bot:Bot, programmingLang: string) =
  ## set the programming language of the bot
  bot.programmingLang = programmingLang

proc setGameTypes*(bot:Bot, gameTypes: seq[string]) =
  ## set the game types of the bot
  bot.gameTypes = gameTypes

proc setAuthors*(bot:Bot, authors: seq[string]) =
  ## set the authors of the bot
  bot.authors = authors

proc setCountryCodes*(bot:Bot, countryCodes: seq[string]) =
  ## set the country codes of the bot
  bot.countryCodes = countryCodes

#+++++++++++++ BOT TICK and INTENT ++++++++++++++#
proc getTick(bot: Bot): TickEventForBot =
  ## returns the current tick of the bot
  return bot.tick

proc setTick(bot: Bot, tick: TickEventForBot) =
  ## set the tick of the bot
  bot.tick = tick

#+++++++++++++ GAME ++++++++++++++#
proc getGameSetup*(bot: Bot): GameSetup =
  ## returns the game setup of the bot
  return bot.gameSetup

proc setGameSetup*(bot: Bot, gameSetup: GameSetup) =
  ## set the game setup of the bot
  bot.gameSetup = gameSetup

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
  if bot.tick.botState == nil:
    return 100
  else:
    return bot.tick.botState.energy

#+++++++++ GAME DATA ++++++++++#
proc getEnemyCount*(bot: Bot): int =
  ## returns the number of enemies in the game
  return bot.tick.enemyCount

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
  return bot.tick.roundNumber

proc getTurnNumber*(bot:Bot): int =
  ## returns the current turn number
  if bot.tick.isNil: return -1

  return bot.tick.turnNumber

proc getX*(bot: Bot): float =
  ## returns the bot's X position
  return bot.tick.botState.x

proc getY*(bot: Bot): float =
  ## returns the bot's Y position
  return bot.tick.botState.y

proc go*(bot: Bot) =
  echo "go for turn number:", bot.getTurnNumber()

  setWaitingForNextTurn(true)

  # dispatch the events
  bot.dispatchEvents(bot.getTurnNumber())

  # send the intent
  out_queue.send(bot.intent.toJson())

  # reset the intent
  resetIntent(bot)

  # wait for the next turn
  while isWaitingForNextTurn():
    sleep(1)

# proc waitFor(bot:Bot, test: proc():bool) =
#   while isRunning() or not test():
#     bot go()

#++++++++ TURNING RADAR +++++++++#
proc getRadarTurnRemaining*(bot: Bot): float =
  ## returns the remaining radar turn rate in degrees
  return remaining_radarTurn

proc getRadarDirection*(bot: Bot): float =
  ## returns the current radar direction in degrees
  return bot.tick.botState.radarDirection

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

  # ask to radarTurn left for all degrees, the server will take care of radarTurning the bot the max amount of degrees allowed
  bot.setRadarTurnLeft(degrees)

  # go until the bot is not running or the remaining_radarTurnRate is 0
  while isRunning() and remaining_radarTurn != 0:
    go bot

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
  go bot

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

  # ask to gunTurn left for all degrees, the server will take care of gunTurning the bot the max amount of degrees allowed
  bot.setGunTurnLeft(degrees)

  # go until the bot is not running or the remaining_gunTurnRate is 0
  while isRunning() and remaining_gunTurn != 0:
    go bot


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
  return bot.tick.botState.gunDirection

proc getMaxGunTurnRate*(bot: Bot): float =
  return MAX_GUN_TURN_RATE

proc getGunHeat*(bot: Bot): float =
  ## returns the current gun heat
  return bot.tick.botState.gunHeat

#++++++++ TURNING BODY +++++++#
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
  echo "setTurnLeft -> remaining_turn:", remaining_turn 

proc setTurnRight*(bot: Bot, degrees: float) =
  ## set the body to turn right by `degrees` if the bot is not locked doing a blocking call
  ##bot.intent.fireAssist = true
  ## **OVERRIDES CURRENT VALUE**
  bot.setTurnLeft(-degrees)

proc turnLeft*(bot: Bot, degrees: float) =
  ## turn the body left by `degrees` if the bot is not locked doing another blocking call
  ##
  ## **BLOCKING CALL**
  
  # ask to turn left for all degrees, the server will take care of turning the bot the max amount of degrees allowed
  bot.setTurnLeft(degrees)

  # go until the bot is not running or the remaining_turnRate is 0
  while isRunning() and remaining_turn != 0:
    bot.go()

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
  return bot.tick.botState.direction

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

  # ask to move forward for all pixels (distance), the server will take care of moving the bot the max amount of pixels allowed
  bot.setForward(distance)

  # go until the bot is not running or the remaining_turnRate is 0
  while isRunning() and remaining_distance != 0:
    go bot

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
proc setFireAssist*(bot: Bot, assist: bool) =
  ## set the fire assist if the bot is not locked doing a blocking call
  ##
  ## **OVERRIDES CURRENT VALUE**
  bot.intent.fireAssist = assist

proc isFireAssist*(bot: Bot): bool =
  ## returns true if the fire assist is enabled
  return bot.intent.fireAssist

proc setFire*(bot: Bot, firepower: float): bool =
  ## set the firepower of the next shot if the bot is not locked doing a blocking call
  ##
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ##
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the intent of firing will not be added

  # clamp the value
  if bot.tick.botState.energy < firepower or bot.tick.botState.gunHeat > 0:
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
  # echo "[events_handler] event ", event[]

proc fire*(bot: Bot, firepower: float): bool =
  ## fire a shot with `firepower` if the bot is not locked doing another blocking call
  ##
  ## `firepower` can be any value between ``0.1`` and ``3``, any value outside this range will be clamped
  ##
  ## If the `gun heat` is not 0 or if the `energy` is less than `firepower` the shot will not be fired
  ##
  # check if the bot is not locked and the bot is able to shoot
  ## **BLOCKING CALL** false

  # lock the bot

  # ask to fire the shot
  if bot.setFire(firepower): go bot

proc getBotHandshake*(sessionId:string):BotHandshake =
  result = BotHandshake(
    `type`:botHandshake,
    sessionId: sessionId,
    name: bot.getName(),
    version: bot.getVersion(),
    authors: bot.getAuthors(),
    description: bot.getDescription(),
    homepage: bot.getHomepage(),
    countryCodes: bot.getCountryCodes(),
    gameTypes: bot.getGameTypes(),
    platform: bot.getPlatform(),
    programmingLang: bot.getProgrammingLang(),
    initialPosition: bot.getInitialPosition(),
    secret: bot.getSecret()
  )

proc botRunner(bot: Bot) {.thread.} =
  while true:
    ## wait on the channel for the start signal
    let message = bot_channel.recv()

    # if the message is "start" start the bot
    case message:
    of "start":
      # Rrun the bot 'run()' method, the one scripted by the bot creator
      # this could be going in loop until the bot is dead or could finish up quickly
      # or could be that is not implemented at all
      echo "[botRunner] starting..."
      # set the bot as running
      running.store(true)

      # run the custom bot code
      run bot

      # When the bot creator's 'run()' exits, if the bot is still runnning,
      # we send the intent automatically until the bot is stopped
      echo "[botRunner] starting the automatic go..."
      while isRunning():
        go bot
      echo "[botRunner] bot automatic go finished"
    of "quit":
      echo "[botRunner] quitting..."
      break
    else:
      # echo "[botRunner] got unhandled message ", message
      discard

  echo "[botRunner] QUIT"

proc stop() =
  setRunning(false)
  setWaitingForNextTurn(false)
  bot.eventQueue.running = false

proc start() =
  # reset the intent to default
  newIntent(bot)

  # set the first tick status to true
  setFirstTick(true) # == first tick never seen

  setRunning(true)

  bot.eventQueue.running = true

proc handle_message(json_message:string) =
  # get all the events from the in_queue and handle them
  # parse the json to a message
  let message:Message = json2message json_message

  if message.`type` != tickEventForBot:
    echo "handling_message ", message.`type`

  case message.`type`:
  of serverHandshake:
    let server_handshake = (ServerHandshake)message

    # We received a server handshake, we need to send the bot handshake
    let bot_handshake = getBotHandshake(server_handshake.sessionId)

    # send the bot handshake
    out_queue.send bot_handshake.toJson

  of gameStartedEventForBot:
    let game_started_event_for_bot = (GameStartedEventForBot)message

    # store the Game Setup for the bot usage
    bot.setGameSetup game_started_event_for_bot.gameSetup
    bot.setId game_started_event_for_bot.myId

    # add the botready event to the queue to send
    out_queue.send BotReady(`type`:botReady).toJson

    # start the bot
    start()

    # add the event to the events_queue
    # events_queue.send json_message
    bot.eventQueue.addEvent game_started_event_for_bot
  of roundStartedEvent:
    let round_started_event = (RoundStartedEvent)message

    # add the event to the events_queue
    # events_queue.send json_message
    bot.eventQueue.addEvent round_started_event
  of gameAbortedEvent:
    let game_aborted_event = (GameAbortedEvent)message
    # stop the bot
    stop()

    # add the event to the events_queue
    # events_queue.send json_message
    bot.eventQueue.addEvent game_aborted_event
  of botDeathEvent:
    let bot_death_event = (BotDeathEvent)message

    # stop the bot
    stop()

    # add the event to the events_queue
    # events_queue.send json_message
    bot.eventQueue.addEvent bot_death_event
  of tickEventForBot:
    waiting_for_next_turn.store(false) # lock the waiting threads

    let tick_event_for_bot = (TickEventForBot)message
    if isFirstTick():
      # init with the first tick data
      bot.setTick  tick_event_for_bot

      turn_done = 0
      gunTurn_done = 0
      radarTurn_done = 0
      distance_done = 0

      setFirstTick(false)

      # notifiy the bot worker to start
      bot_channel.send "start"
    else:
      turn_done = tick_event_for_bot.botState.direction - bot.getTick().botState.direction
      turn_done = (turn_done + 540) mod 360 - 180

      echo "new direction:", tick_event_for_bot.botState.direction, " - old direction:", bot.getTick().botState.direction, " => ", turn_done

      gunTurn_done = tick_event_for_bot.botState.gunDirection - bot.getTick().botState.gunDirection
      gunTurn_done = (gunTurn_done + 540) mod 360 - 180

      radarTurn_done = tick_event_for_bot.botState.radarDirection - bot.getTick().botState.radarDirection
      radarTurn_done = (radarTurn_done + 540) mod 360 - 180

      # adjust the gun turn by the body turn if the gun is not independent from the body
      if not bot.isAdjustGunForBodyTurn: gunTurn_done -= turn_done

      # adjust the radar turn by the body turn if the radar is not independent from the body
      if not bot.isAdjustRadarForGunTurn: radarTurn_done -= turn_done

      # adjust the radar turn by the gun turn if the radar is not independent from the gun
      if not bot.isAdjustRadarForGunTurn: radarTurn_done -= gunTurn_done

      distance_done = tick_event_for_bot.botState.speed
  
      # replace old data with new data
      bot.setTick  tick_event_for_bot

    # update the remainings of the actions based on the data received
    updateBodyTurning(bot)
    updateGunTurning(bot)
    updateRadarTurning(bot)
    updateDistance(bot)
      
    # add the event to the events_queue
    bot.eventQueue.addEvent tick_event_for_bot

    # for every event in the tick_event_for_bot.events add it to the bot's queue
    for event in tick_event_for_bot.events: # events are a JsonNode!!!
      let event_object = (Event)(json2message $event)
      case event_object.`type`:
      of botHitWallEvent:
        bot.setDistanceRemaining(0)
      else:
        # echo "unhandled tick.event ", event_object.`type`
        discard
      # convert the event to a json and send it to the events_queue
      # events_queue.send event.toJson
      bot.eventQueue.addEvent event_object
  else:
    echo "unhandled message ", json_message
    discard

proc main() {.async.} =
  try:

    echo "[main] connection url: ", bot.getServerConnectionURL()

    # connect to the server
    webSocket = await newWebSocket(bot.getServerConnectionURL())

    # open the channels for queues
    open out_queue
    open in_queue
    open events_queue
    open bot_channel # this is used to communicate with the botRunner thread

    # start the botRunner thread
    createThread botRunnerThread, botRunner, bot

    proc listen_messages() {.async.} =
      # Loops while socket is open, looking for messages to read
      while webSocket.readyState == Open:

        # this blocks
        var packet = await webSocket.receiveStrPacket()

        # ignore pings
        if packet.isEmptyOrWhitespace(): continue

        # print packet for debug
        # echo "IN=>", packet

        # send the packet to the in_queue
        in_queue.send packet

    proc send_messages() {.async.} =
      # Loops while socket is open, looking for messages to write
      while webSocket.readyState == Open:# send the message to the server
        # get the next message
        let data = out_queue.tryRecv()
        if data.dataAvailable:
          let message = data.msg
          # echo ""
          # echo bot.getTurnNumber(),"=>", message
          await webSocket.send message # send the message to the server
        await sleepAsync(0.001) # sleep for less than 1ms, required to avoid blocking the event loop

    proc message_handler() {.async.} =
      # Loops forever untile "stop" command is received
      while true:
        # get the next message
        let data = in_queue.tryRecv()
        if data.dataAvailable:
          let message = data.msg
          if message == "stop":
            break
          handle_message(message)
        await sleepAsync(0.001) # sleep for less than 1ms, required to avoid blocking the event loop

    # start a async fiber thingy
    asyncCheck send_messages()
    asyncCheck listen_messages()
    waitFor message_handler()

    # notify the bot worker to stop
    bot_channel.send "quit"

    # wait for the bot worker to finish
    joinThreads botRunnerThread, events_handlerThread

    # close all the channels
    close out_queue
    close in_queue
    close events_queue
    close bot_channel

  except CatchableError:
    echo "main catched error:",getCurrentExceptionMsg()

proc newBot(json_file: string):Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    let path: string = joinPath(getAppDir(), json_file)
    let content: string = readFile(path)
    return fromJson(content, Bot)
  except CatchableError:
    echo "ERROR: ",getCurrentExceptionMsg()
    quit(1)

proc startBot*(json_file: string, connect: bool = true, position: InitialPosition = InitialPosition(x: 0, y: 0, direction: 0)) =
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
  
  # create the bot
  bot = newBot(json_file)

  # set the initial position, is the server that will decide to use it or not
  bot.setInitialPosition(position)

  # create the empty intent
  bot.newIntent()

  echo "[", bot.getName(), ".startBot]starting bot..."

  # connect to the Game Server
  if(connect):
    if bot.getSecret == "": bot.setSecret  getEnv("SERVER_SECRET", "")

    if bot.getServerConnectionURL == "": bot.setServerConnectionURL getEnv("SERVER_URL", "ws://localhost:7654")

    # start the connection handler and wait for it undefinitely
    waitFor main()

  echo "[", bot.getName(), ".startBot]connection ended and bot thread finished. Bye!"

  #++++++++++++++ UTILS ++++++++++++++#
proc distanceTo*(bot: Bot, x, y: float): float =
  ## returns the distance from the bot's coordinates to the point (x,y)
  ##
  ## `x` and `y` are the coordinates of the point
  ## `return` is the distance to the point x,y
  return hypot(x-bot.tick.botState.x, y-bot.tick.botState.y)

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
  result = normalizeAbsoluteAngle(radToDeg(arctan2(y-bot.tick.botState.y, x-bot.tick.botState.x)))

proc bearingTo*(bot: Bot, x, y: float): float =
  ## returns the bearing to the point (x,y) in degrees
  ##
  ## `x` and `y` are the coordinates of the point
  ## `return` is the bearing to the point x,y in degrees in the range [-180,180]
  result = normalizeRelativeAngle(bot.directionTo(x, y) -
      bot.tick.botState.direction)