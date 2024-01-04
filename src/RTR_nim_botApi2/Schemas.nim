# import 3rd party libraries
import json

type
  Type* = enum
    botHandshake = "BotHandshake"
    botIntent = "BotIntent"
    botReady = "BotReady"
    gameStartedEventForBot = "GameStartedEventForBot"
    gameEndedEventForBot = "GameEndedEventForBot"
    gameEndedEventForObserver = "GameEndedEventForObserver"
    gameAbortedEvent = "GameAbortedEvent"
    roundStartedEvent = "RoundStartedEvent"
    roundEndedEvent = "RoundEndedEvent"
    roundEndedEventForBot = "RoundEndedEventForBot"
    botDeathEvent = "BotDeathEvent"
    botHitBotEvent = "BotHitBotEvent"
    botHitWallEvent = "BotHitWallEvent"
    botInfo = "BotInfo"
    botListUpdate = "BotListUpdate"
    bulletFiredEvent = "BulletFiredEvent"
    bulletHitBotEvent = "BulletHitBotEvent"
    bulletHitBulletEvent = "BulletHitBulletEvent"
    connectedEvent = "ConnectedEvent"
    controllerHandshake = "ControllerHandshake"
    disconnectedEvent = "DisconnectedEvent"
    bulletHitWallEvent = "BulletHitWallEvent"
    hitByBulletEvent = "HitByBulletEvent"
    gameStartedEventForObserver = "GameStartedEventForObserver"
    roundEndedEventForObserver = "RoundEndedEventForObserver"
    scannedBotEvent = "ScannedBotEvent"
    serverHandshake = "ServerHandshake"
    skippedTurnEvent = "SkippedTurnEvent"
    startGame = "StartGame"
    stopGame = "StopGame"
    teamMessage = "TeamMessage"
    teamMessageEvent = "TeamMessageEvent"
    tickEventForBot = "TickEventForBot"
    tickEventForObserver = "TickEventForObserver"
    tpsChangedEvent = "TpsChangedEvent"
    wonRoundEvent = "WonRoundEvent"
  
  Schema* = ref object of RootObj
    `type`*: Type

  InitialPosition* = ref object of RootObj
    x*,y*,angle*: float #The x,y and angle coordinate. When it is not set, a random value will be used

  Event* = ref object of Schema
    turnNumber*: int #The turn number in current round when event occurred

  BotAddress* = ref object of RootObj
    host*: string #Host name or IP address
    port*: int #Port number

  BotDeathEvent* = ref object of Event
    victimId*: int #ID of the bot that has died

  BotHandshake* = ref object of Schema
    sessionId*: string #Unique session id that must match the session id received from the server handshake
    name*: string #Name of bot, e.g. Killer Bee
    version*: string #Bot version, e.g. 1.0
    authors*: seq[string] #Name of authors, e.g. John Doe (john_doe@somewhere.net)
    description*: string #Short description of the bot, preferable a one-liner
    homepage*: string #URL to a home page for the bot
    countryCodes*: seq[string] #2-letter country code(s) defined by ISO 3166-1, e.g. "UK"
    gameTypes*: seq[string] #Game types supported by this bot (defined elsewhere), e.g. "classic", "melee" and "1v1"
    platform*: string #Platform used for running the bot, e.g. JVM 17 or .NET 5
    programmingLang*: string #Language used for programming the bot, e.g. Java 17 or C# 10
    initialPosition*: InitialPosition #Initial start position of the bot used for debugging
    secret*: string #Secret used for access control with the server

  BotHitBotEvent* = ref object of Event
    victimId*: int #ID of the victim bot that got hit
    botId*: int #ID of the bot that hit another bot
    energy*: float #Remaining energy level of the victim bot
    x*: float #X coordinate of victim bot
    y*: float #Y coordinate of victim bot
    rammed*: bool #Flag specifying, if the victim bot got rammed
  
  BotHitWallEvent* = ref object of Event
    victimId*: int #ID of the victim bot that hit the wall

  BotInfo* = ref object of BotHandshake
    host*: string #Host name or IP address
    port*: int #Port number

  BotIntent* = ref object of Schema
    turnRate*: float #Turn rate of the body in degrees per turn (can be positive and negative)
    gunTurnRate*: float #Turn rate of the gun in degrees per turn (can be positive and negative)
    radarTurnRate*: float #Turn rate of the radar in degrees per turn (can be positive and negative)
    targetSpeed*: float #New target speed in units per turn (can be positive and negative)
    firepower*: float #Attempt to fire gun with the specified firepower
    adjustGunForBodyTurn*: bool #Flag indicating if the gun must be adjusted to compensate for the body turn. Default is false.
    adjustRadarForBodyTurn*: bool #Flag indicating if the radar must be adjusted to compensate for the body turn. Default is false.
    adjustRadarForGunTurn*: bool #Flag indicating if the radar must be adjusted to compensate for the gun turn. Default is false.
    rescan*: bool #Flag indicating if the bot should rescan with previous radar direction and scan sweep angle.
    fireAssist*: bool #Flag indication if fire assistance is enabled.
    bodyColor*: string #New color of the body
    turretColor*: string #New color of the cannon turret
    radarColor*: string #New color of the radar
    bulletColor*: string #New color of the bullet. Note. This will be the color of a bullet when it is fired
    scanColor*: string #New color of the scan arc
    tracksColor*: string #New color of the tracks
    gunColor*: string #New color of the gun
    stdOut*: string #New text received from standard output (stdout)
    stdErr*: string #New text received from standard error (stderr)
    teamMessages*: seq[TeamMessage] #Messages to send to one or more individual teammates or broadcast to the entire team

  BotListUpdate* = ref object of Schema
    bots*: seq[BotInfo] #List of bots

  BotReady* = ref object of Schema

  BotResultsForBot* = ref object of RootObj
    rank*: int #Rank/placement of the bot, where 1 is 1st place, 4 is 4th place etc.
    survival*: int #Survival score gained whenever another bot is defeated
    lastSurvivorBonus*: int #Last survivor score as last survivor in a round
    bulletDamage*: int #Bullet damage given
    bulletKillBonus*: int #Bullet kill bonus
    ramDamage*: int #Ram damage given
    ramKillBonus*: int #Ram kill bonus
    totalScore*: int #Total score
    firstPlaces*: int #Number of 1st places
    secondPlaces*: int #Number of 2nd places
    thirdPlaces*: int #Number of 3rd places

  BotResultsForObserver* = ref object of BotResultsForBot
    id*: int #ID of the bot
    name*: string #Name of the bot
    version*: string #Version of the bot

  BotState* = ref object of RootObj
    energy*: float #Energy level
    x*: float #X coordinate
    y*: float #Y coordinate
    direction*: float #Driving direction in degrees
    gunDirection*: float #Gun direction in degrees
    radarDirection*: float #Radar direction in degrees
    radarSweep*: float #Radar sweep angle in degrees, i.e. angle between previous and current radar direction
    speed*: float #Speed measured in units per turn
    turnRate*: float #Turn rate of the body in degrees per turn (can be positive and negative)
    gunTurnRate*: float #Turn rate of the gun in degrees per turn (can be positive and negative)
    radarTurnRate*: float #Turn rate of the radar in degrees per turn (can be positive and negative)
    gunHeat*: float #Gun heat
    bodyColor*: string #Current RGB color of the body
    turretColor*: string #Current color of the cannon turret
    radarColor*: string #Current color of the radar
    bulletColor*: string #Current color of the bullet. Note. This will be the color of a bullet when it is fired
    scanColor*: string #Current color of the scan arc
    tracksColor*: string #Current color of the tracks
    gunColor*: string #Current color of the gun

  BotStateWithId* = ref object of BotState
    id*: int #Unique display id of bot in the battle (like an index)
    sessionId*: string #Unique session id used for identifying the bot
    stdOut*: string #Last data received for standard out (stdout)
    stdErr*: string #Last data received for standard error (stderr)

  BulletFiredEvent* = ref object of Event
    bullet*: BulletState #Bullet that was fired

  BulletHitBotEvent* = ref object of Event
    victimId*: int #ID of the bot that got hit
    bullet*: BulletState #Bullet that hit the bot
    damage*: float #Damage inflicted by the bullet
    energy*: float #Remaining energy level of the bot that got hit

  BulletHitBulletEvent* = ref object of Event
    bullet*: BulletState #Bullet that hit another bullet
    hitBullet*: BulletState #The other bullet that was hit by the bullet

  BulletHitWallEvent* = ref object of Event
    bullet*: BulletState #Bullet that has hit a wall

  BulletState* = ref object of RootObj
    bulletId*: int #ID of the bullet
    ownerId*: int #ID of the bot that fired the bullet
    power*: float #Bullet firepower (between 0.1 and 3.0)
    x*: float #X coordinate
    y*: float #Y coordinate
    direction*: float #Direction in degrees
    color*: string #Color of the bullet

  ConnectedEvent* = ref object of Event
    serverUri*:string #The URI of the server

  ControllerHandshake* = ref object of Schema
    sessionId*: string #Unique session id that must match the session id received from the server handshake.
    name*: string #Name of the controller
    version*: string #Version of the controller
    author*: string #Author of the controller
    secret*: string #Secret used for access control with the server

  DisconnectedEvent* = ref object of Event
    serverUri*:string #The URI of the server
    remote*:bool #Flag indicating if the disconnection was initiated by the remote server
    statusCode*:int #The status code of the disconnection
    reason*:string #The reason for the disconnection

  GameSetup* = ref object of RootObj
    gameType*: string #Type of game
    arenaWidth*: int #Width of arena measured in units
    isArenaWidthLocked*: bool #Flag specifying if the width of arena is fixed for this game type
    arenaHeight*: int #Height of arena measured in units
    isArenaHeightLocked*: bool #Flag specifying if the height of arena is fixed for this game type
    minNumberOfParticipants*: int #Minimum number of bots participating in battle
    isMinNumberOfParticipantsLocked*: bool #Flag specifying if the minimum number of bots participating in battle
    maxNumberOfParticipants*: int #Maximum number of bots participating in battle
    isMaxNumberOfParticipantsLocked*: bool #Flag specifying if the maximum number of bots participating in battle
    numberOfRounds*: int #Number of rounds in battle
    isNumberOfRoundsLocked*: bool #Flag specifying if the number-of-rounds is fixed for this game type
    gunCoolingRate*: float #Gun cooling rate. The gun needs to cool down to a gun heat of zero
    isGunCoolingRateLocked*: bool #Flag specifying if the gun cooling rate is fixed for this game type
    maxInactivityTurns*: int #Maximum number of inactive turns allowed, where a bot does not take
    isMaxInactivityTurnsLocked*: bool #Flag specifying if the inactive turns is fixed for this game type
    turnTimeout*: int #Turn timeout in microseconds (1 / 1,000,000 second) for sending intent after having received 'tick' Message
    isTurnTimeoutLocked*: bool #Flag specifying if the turn timeout is fixed for this game type
    readyTimeout*: int #Time limit in microseconds (1 / 1,000,000 second) for sending ready
    isReadyTimeoutLocked*: bool #Flag specifying if the ready timeout is fixed for this game type
    defaultTurnsPerSecond*: int #Default number of turns to show per second for an observer/UI

  GameAbortedEvent* = ref object of Schema

  GameEndedEventForBot* = ref object of Schema
    numberOfRounds*: int #Number of rounds played
    results*: BotResultsForObserver #Results of the battle for all bots

  GameEndedEventForObserver* = ref object of Schema
    numberOfRounds*: int #Number of rounds played
    results*: seq[BotResultsForObserver] #Results of the battle for all bots

  GameStartedEventForBot* = ref object of Schema
    myId*: int #My ID is an unique identifier for this bot
    gameSetup*: GameSetup #Game setup

  GameStartedEventForObserver* = ref object of Schema
    gameSetup*: GameSetup #Game setup
    participants*:seq[Participant]

  HitByBulletEvent* = ref object of Event
    bullet*: BulletState #Bullet that has hit the bot
    damage*: float #Damage inflicted by the bullet
    energy*: float #Remaining energy level of the bot after the damage was inflicted

  Participant* = ref object of RootObj
    id*: int #Identifier for the participant in a battle
    sessionId*: string #Unique session id that must match the session id received from the server handshake
    name*: string #Name of bot, e.g. Killer Bee
    version*: string #Version of bot, e.g. 1.0
    authors*: seq[string] #Authors of bot, e.g. John Doe
    description*: string #Short description of the bot, preferable a one-liner
    homepage*: string #URL to homepage of bot
    countryCodes*: seq[string] #2-letter country code(s) defined by ISO 3166-1, e.g.  "GB"
    gameTypes*: seq[string] #Game types supported by this bot (defined elsewhere), e.g. "classic", "melee" and "1v1"
    platform*: string #Platform used for running the bot, e.g. JVM 17 or .NET 5
    programmingLang*: string #Programming language the bot is written in, e.g. "Java", "C#" or "C++"
    initialPosition*: InitialPosition #Initial position of the bot

  RoundStartedEvent* = ref object of Schema
    roundNumber*: int #The current round number in the battle when event occurred

  RoundEndedEventForBot* = ref object of Schema
    roundNumber*: int #The current round number in the battle when event occurred
    turnNumber*: int #The current turn number in the round when event occurred
    results*: BotResultsForBot #The accumulated bot results by the end of the round.

  RoundEndedEventForObserver* = ref object of Schema
    roundNumber*: int #The current round number in the battle when event occurred
    turnNumber*: int #The current turn number in the round when event occurred
    results*: seq[BotResultsForObserver] #The accumulated bot results by the end of the round.

  ScannedBotEvent* = ref object of Event
    scannedByBotId*: int #ID of the bot did the scanning
    scannedBotId*: int #ID of the bot that was scanned
    energy*: float #Energy level of the scanned bot
    x*: float #X coordinate of the scanned bot
    y*: float #Y coordinate of the scanned bot
    direction*: float #Direction in degrees of the scanned bot
    speed*: float #Speed measured in units per turn of the scanned bot

  ServerHandshake* = ref object of Schema
    sessionId*: string #Unique session id used for identifying the caller client (bot, controller, observer) connection.
    name*: string #Name of server, e.g. John Doe's RoboRumble Server
    variant*: string #Game variant, e.g. 'Tank Royale' for Robocode Tank Royale
    version*: string #Game version, e.g. '1.0.0' using Semantic Versioning (https://semver.org/)
    gameTypes*: seq[string] #Game types running at this server, e.g. "melee" and "1v1"

  StartGame* = ref object of Schema
    gameSetup*: GameSetup #Game setup
    botAddresses*: seq[BotAddress] #List of bot addresses

  SkippedTurnEvent* = ref object of Event

  StopGame* = ref object of Schema

  TeamMessage* = ref object of Schema
    receiverId*: int #The id of the receiver teammate. If omitted, the Message is broadcast to all teammates
    description*: string #Message sent between teammates

  TickEventForBot* = ref object of Event
    roundNumber*: int #The current round number in the battle when event occurred
    enemyCount*: int #Number of enemies left in the current round
    botState*: BotState #Current state of this bot
    bulletStates*: seq[BulletState] #Current state of the bullets fired by this bot
    events*: JsonNode #Events occurring in the turn relevant for this bot

  TickEventForObserver* = ref object of Event
    roundNumber*: int #The current round number in the battle when event occurred
    botStates*: seq[BotStateWithId] #Current state of all bots
    bulletStates*: seq[BulletState] #Current state of all bullets
    events*: seq[Event] #All events occurring at this tick

  WonRoundEvent* = ref object of Event