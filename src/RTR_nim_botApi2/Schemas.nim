# This file is generated automatically by the 'schemas2nim' script
# Generated on: 2024-10-19T16:24:01Z (Italy time)
import jsony, json

type
  Type* = enum
    message = "Message"
    botAddress = "BotAddress"
    event = "Event"
    botDeathEvent = "BotDeathEvent"
    botHandshake = "BotHandshake"
    botHitBotEvent = "BotHitBotEvent"
    botHitWallEvent = "BotHitWallEvent"
    botInfo = "BotInfo"
    botIntent = "BotIntent"
    botListUpdate = "BotListUpdate"
    botReady = "BotReady"
    botStateWithId = "BotStateWithId"
    botState = "BotState"
    bulletFiredEvent = "BulletFiredEvent"
    bulletHitBotEvent = "BulletHitBotEvent"
    bulletHitBulletEvent = "BulletHitBulletEvent"
    bulletHitWallEvent = "BulletHitWallEvent"
    bulletState = "BulletState"
    changeTps = "ChangeTps"
    controllerHandshake = "ControllerHandshake"
    gameAbortedEvent = "GameAbortedEvent"
    gameEndedEventForBot = "GameEndedEventForBot"
    gameEndedEventForObserver = "GameEndedEventForObserver"
    gamePausedEventForObserver = "GamePausedEventForObserver"
    gameResumedEventForObserver = "GameResumedEventForObserver"
    gameSetup = "GameSetup"
    gameStartedEventForBot = "GameStartedEventForBot"
    gameStartedEventForObserver = "GameStartedEventForObserver"
    hitByBulletEvent = "HitByBulletEvent"
    initialPosition = "InitialPosition"
    nextTurn = "NextTurn"
    observerHandshake = "ObserverHandshake"
    participant = "Participant"
    pauseGame = "PauseGame"
    resultsForBot = "ResultsForBot"
    resultsForObserver = "ResultsForObserver"
    resumeGame = "ResumeGame"
    roundEndedEventForBot = "RoundEndedEventForBot"
    roundEndedEventForObserver = "RoundEndedEventForObserver"
    roundStartedEvent = "RoundStartedEvent"
    scannedBotEvent = "ScannedBotEvent"
    serverHandshake = "ServerHandshake"
    skippedTurnEvent = "SkippedTurnEvent"
    startGame = "StartGame"
    stopGame = "StopGame"
    teamMessageEvent = "TeamMessageEvent"
    teamMessage = "TeamMessage"
    tickEventForBot = "TickEventForBot"
    tickEventForObserver = "TickEventForObserver"
    tpsChangedEvent = "TpsChangedEvent"
    wonRoundEvent = "WonRoundEvent"

  Message* = ref object of RootObj
    ## Abstract message exchanged between server and client
    `type`*:Type

  BotAddress* = ref object of RootObj
    ## Bot address
    host*:string # Host name or IP address
    port*:int # Port number

  Event* = ref object of Message
    ## Abstract event occurring during a battle
    turnNumber*:int # The turn number in current round when event occurred

  BotDeathEvent* = ref object of Event
    ## Event occurring when a bot has died
    victimId*:int # id of the bot that has died

  BotHandshake* = ref object of Message
    ## Bot handshake
    sessionId*:string # Unique session id that must match the session id received from the server handshake
    name*:string # Name of bot, e.g. Killer Bee
    version*:string # Bot version, e.g. 1.0
    authors*:seq[string] # Name of authors, e.g. John Doe <john_doe@somewhere.net>
    description*:string # Short description of the bot, preferable a one-liner
    homepage*:string # URL to a home page for the bot
    countryCodes*:seq[string] # 2-letter country code(s) defined by ISO 3166-1, e.g. "GB"
    gameTypes*:seq[string] # Game types supported by this bot (defined elsewhere), e.g. "classic", "melee" and "1v1"
    platform*:string # Platform used for running the bot, e.g. JVM 17 or .NET 5
    programmingLang*:string # Language used for programming the bot, e.g. Java 17 or C# 10
    initialPosition*:InitialPosition # Initial start position of the bot used for debugging
    teamId*:int # Id of the team that this bot is a member of
    teamName*:string # Name of the team that this bot is a member of, e.g. Killer Bees
    teamVersion*:string # Team version, e.g. 1.0
    isDroid*:bool # Flag specifying if the bot is a Droid (team bot with 120 energy, but no scanner)
    secret*:string # Secret used for access control with the server

  BotHitBotEvent* = ref object of Event
    ## Event occurring when a bot has collided with another bot
    victimId*:int # id of the victim bot that got hit
    botId*:int # id of the bot that hit another bot
    energy*:float # Remaining energy level of the victim bot
    x*:float # X coordinate of victim bot
    y*:float # Y coordinate of victim bot
    rammed*:bool # Flag specifying, if the victim bot got rammed

  BotHitWallEvent* = ref object of Event
    ## Event occurring when a bot has hit a wall
    victimId*:int # id of the victim bot that hit the wall

  BotInfo* = ref object of BotHandshake
    ## Bot info
    host*:string # Host name or IP address
    port*:int # Port number

  BotIntent* = ref object of Message
    ## The intent (request) sent from a bot each turn for controlling the bot and provide the server with data.
    ## A field only needs to be set, if the value must be changed. Otherwise the server will use the field value from the
    ## last time the field was set.
    turnRate*:float # Turn rate of the body in degrees per turn (can be positive and negative)
    gunTurnRate*:float # Turn rate of the gun in degrees per turn (can be positive and negative)
    radarTurnRate*:float # Turn rate of the radar in degrees per turn (can be positive and negative)
    targetSpeed*:float # New target speed in units per turn (can be positive and negative)
    firepower*:float # Attempt to fire gun with the specified firepower
    adjustGunForBodyTurn*:bool # Flag indicating if the gun must be adjusted to compensate for the body turn. Default is false.
    adjustRadarForBodyTurn*:bool # Flag indicating if the radar must be adjusted to compensate for the body turn. Default is false.
    adjustRadarForGunTurn*:bool # Flag indicating if the radar must be adjusted to compensate for the gun turn. Default is false.
    rescan*:bool # Flag indicating if the bot should rescan with previous radar direction and scan sweep angle.
    fireAssist*:bool # Flag indication if fire assistance is enabled.
    bodyColor*:string # New color of the body
    turretColor*:string # New color of the cannon turret
    radarColor*:string # New color of the radar
    bulletColor*:string # New color of the bullet. Note. This will be the color of a bullet when it is fired
    scanColor*:string # New color of the scan arc
    tracksColor*:string # New color of the tracks
    gunColor*:string # New color of the gun
    stdOut*:string # New text received from standard output (stdout)
    stdErr*:string # New text received from standard error (stderr)
    teamMessages*:seq[TeamMessage] # Messages to send to one or more individual teammates or broadcast to the entire team

  BotListUpdate* = ref object of Message
    ## Bot list update
    bots*:seq[BotInfo] # List of bots

  BotReady* = ref object of Message
    ## Message from a bot that is ready to play a game

  BotStateWithId* = ref object of BotState
    ## Current state of a bot, which included an id
    id*:int # Unique display id of bot in the battle (like an index).
    sessionId*:string # Unique session id used for identifying the bot.
    stdOut*:string # Last data received for standard out (stdout)
    stdErr*:string # Last data received for standard err (stderr)

  BotState* = ref object of RootObj
    ## Current state of a bot, but without an id that must be kept secret from opponent bots
    isDroid*:bool # Flag specifying if the bot is a Droid (team bot with 120 energy, but no scanner)
    energy*:float # Energy level
    x*:float # X coordinate
    y*:float # Y coordinate
    direction*:float # Driving direction in degrees
    gunDirection*:float # Gun direction in degrees
    radarDirection*:float # Radar direction in degrees
    radarSweep*:float # Radar sweep angle in degrees, i.e. angle between previous and current radar direction
    speed*:float # Speed measured in units per turn
    turnRate*:float # Turn rate of the body in degrees per turn (can be positive and negative)
    gunTurnRate*:float # Turn rate of the gun in degrees per turn (can be positive and negative)
    radarTurnRate*:float # Turn rate of the radar in degrees per turn (can be positive and negative)
    gunHeat*:float # Gun heat
    bodyColor*:string # Current RGB color of the body, if changed
    turretColor*:string # New color of the gun turret, if changed
    radarColor*:string # New color of the radar, if changed
    bulletColor*:string # New color of the bullets, if changed.
    scanColor*:string # New color of the scan arc, if changed
    tracksColor*:string # New color of the tracks, if changed
    gunColor*:string # New color of gun, if changed

  BulletFiredEvent* = ref object of Event
    ## Event occurring when a bullet has been fired from a bot
    bullet*:BulletState # Bullet that was fired

  BulletHitBotEvent* = ref object of Event
    ## Event occurring when a bot has been hit by a bullet from another bot
    victimId*:int # id of the bot that got hit
    bullet*:BulletState # Bullet that hit the bot
    damage*:float # Damage inflicted by the bullet
    energy*:float # Remaining energy level of the bot that got hit

  BulletHitBulletEvent* = ref object of Event
    ## Event occurring when a bullet has hit another bullet
    bullet*:BulletState # Bullet that hit another bullet
    hitBullet*:BulletState # The other bullet that was hit by the bullet

  BulletHitWallEvent* = ref object of Event
    ## Event occurring when a bullet has hit a wall
    bullet*:BulletState # Bullet that has hit a wall

  BulletState* = ref object of RootObj
    ## Bullet state
    bulletId*:int # id of the bullet
    ownerId*:int # id of the bot that fired the bullet
    power*:float # Bullet firepower (between 0.1 and 3.0)
    x*:float # X coordinate
    y*:float # Y coordinate
    direction*:float # Direction in degrees
    color*:string # Color of the bullet

  ChangeTps* = ref object of Message
    ## Command to change the TPS (Turns Per Second), which is the number of turns displayed for an observer. TPS is similar to FPS, where a frame is equal to a turn.
    tps*:int # Turns per second (TPS). Typically a value from 0 to 999. -1 means maximum possible TPS speed.

  Color* = ref object of RootObj
    ## Represents a RGB color using hexadecimal format for web colors. Note that colors must have a leading number sign (#).
    ## See https://en.wikipedia.org/wiki/Web_colors.    ## Note that this type does not support RGBA colors with an alpha channel on purpose, as bots should be painted opaque.
    ## "#000",    // black
    ## "#FFF",    // white
    ## "#0F0",    // lime
    ## "#000000", // black
    ## "#FFFFFF", // white
    ## "#00FF00", // lime
    ## "#ffa07a", // light salmon
    ## "#9932cc"  // dark orchid
    ## ]

  ControllerHandshake* = ref object of Message
    ## Controller handshake
    sessionId*:string # Unique session id that must match the session id received from the server handshake.
    name*:string # Name of controller, e.g. Fancy Robocode Controller
    version*:string # Controller version, e.g. 1.0
    author*:string # Author name, e.g. John Doe (john_doe@somewhere.net)
    secret*:string # Secret used for access control with the server

  GameAbortedEvent* = ref object of Event
    ## Event occurring when game has been aborted. No score is available.

  GameEndedEventForBot* = ref object of Event
    ## Event occurring when game has ended. Gives all game results visible for a bot.
    numberOfRounds*:int # Number of rounds played
    results*:ResultsForBot # Bot results of the battle

  GameEndedEventForObserver* = ref object of Message
    ## Event occurring when game has ended. Gives all game results visible for an observer.
    numberOfRounds*:int # Number of rounds played
    results*:seq[ResultsForObserver] # Results of the battle for all bots

  GamePausedEventForObserver* = ref object of Message
    ## Event occurring when a game has been paused

  GameResumedEventForObserver* = ref object of Message
    ## Event occurring when a game is resumed from a previous pause

  GameSetup* = ref object of RootObj
    ## Game setup
    gameType*:string # Type of game
    arenaWidth*:int # Width of arena measured in units
    isArenaWidthLocked*:bool # Flag specifying if the width of arena is fixed for this game type
    arenaHeight*:int # Height of arena measured in units
    isArenaHeightLocked*:bool # Flag specifying if the height of arena is fixed for this game type
    minNumberOfParticipants*:int # Minimum number of bots participating in battle
    isMinNumberOfParticipantsLocked*:bool # Flag specifying if the minimum number of bots participating in battle
    maxNumberOfParticipants*:int # Maximum number of bots participating in battle (is optional)
    isMaxNumberOfParticipantsLocked*:bool # Flag specifying if the maximum number of bots participating in battle
    numberOfRounds*:int # Number of rounds in battle
    isNumberOfRoundsLocked*:bool # Flag specifying if the number-of-rounds is fixed for this game type
    gunCoolingRate*:float # Gun cooling rate. The gun needs to cool down to a gun heat of zero
    isGunCoolingRateLocked*:bool # Flag specifying if the gun cooling rate is fixed for this game type
    maxInactivityTurns*:int # Maximum number of inactive turns allowed, where a bot does not take
    isMaxInactivityTurnsLocked*:bool # Flag specifying if the inactive turns is fixed for this game type
    turnTimeout*:int # Turn timeout in microseconds (1 / 1,000,000 second) for sending intent
    isTurnTimeoutLocked*:bool # Flag specifying if the turn timeout is fixed for this game type
    readyTimeout*:int # Time limit in microseconds (1 / 1,000,000 second) for sending ready
    isReadyTimeoutLocked*:bool # Flag specifying if the ready timeout is fixed for this game type
    defaultTurnsPerSecond*:int # Default number of turns to show per second for an observer/UI

  GameStartedEventForBot* = ref object of Event
    ## Event occurring when a new game has started. Gives game info for a bot.
    myId*:int # My id is an unique id of this bot
    startX*:float # Start x coordinate
    startY*:float # Start y coordinate
    startDirection*:float # Direction of the body, gun, and radar in degrees
    teammateIds*:seq[int] # The IDs of the teammates in the team that this bot is a member of
    gameSetup*:GameSetup # Game setup

  GameStartedEventForObserver* = ref object of Message
    ## Event occurring when a new game has started. Gives game info for an observer.
    gameSetup*:GameSetup # Game setup
    participants*:seq[Participant] # List of bots participating in this battle

  HitByBulletEvent* = ref object of Event
    ## Event generate by API when your bot has been hit by a bullet from another bot
    bullet*:BulletState # Bullet that hit the bot
    damage*:float # Damage inflicted by the bullet
    energy*:float # Remaining energy level of the bot that got hit

  InitialPosition* = ref object of RootObj
    ## Initial start position of the bot used for debugging as a comma-separated format taking the x and y coordinates
    ## and shared starting direction of the body, gun, and radar.
    x*:float # The x coordinate. When it is not set, a random value will be used.
    y*:float # The y coordinate. When it is not set, a random value will be used.
    direction*:float # The shared direction of the body, gun, and radar. When it is not set, a random value will be used.

  NextTurn* = ref object of Message
    ## Command to make the next turn when the game is paused used for single stepping when debugging.

  ObserverHandshake* = ref object of Message
    ## Observer handshake
    sessionId*:string # Unique session id that must match the session id received from the server handshake.
    name*:string # Name of observer, e.g. Tron Neon 3D Window
    version*:string # Observer version, e.g. 1.0
    author*:string # Author name, e.g. John Doe (john_doe@somewhere.net)
    secret*:string # Secret used for access control with the server

  Participant* = ref object of RootObj
    ## Bot participating in a battle
    id*:int # Id of the bot participating in a battle
    sessionId*:string # Unique session id that must match the session id received from the server handshake
    name*:string # Name of bot, e.g. Killer Bee
    version*:string # Bot version, e.g. 1.0
    authors*:seq[string] # Name of authors, e.g. John Doe <john_doe@somewhere.net>
    description*:string # Short description of the bot, preferable a one-liner
    homepage*:string # URL to a home page for the bot
    countryCodes*:seq[string] # 2-letter country code(s) defined by ISO 3166-1, e.g. "GB"
    gameTypes*:seq[string] # Game types supported by this bot (defined elsewhere), e.g. "classic", "melee" and "1v1"
    platform*:string # Platform used for running the bot, e.g. JVM 17 or .NET 5
    programmingLang*:string # Language used for programming the bot, e.g. Java 17 or C# 10
    initialPosition*:InitialPosition # Initial start position of the bot used for debugging
    teamId*:int # Id of the team that this bot is a member of
    teamName*:string # Name of the team that this bot is a member of, e.g. Killer Bees
    teamVersion*:string # Team version, e.g. 1.0
    isDroid*:bool # Flag specifying if the bot is a Droid (team bot with 120 energy, but no scanner)

  PauseGame* = ref object of Message
    ## Command to pause a game

  ResultsForBot* = ref object of RootObj
    ## Individual participants results visible for a bot, where name and version is hidden.
    rank*:int # Rank/placement, where 1 is 1st place, 4 is 4th place etc.
    survival*:int # Survival score gained whenever another opponent is defeated
    lastSurvivorBonus*:int # Last survivor score as last survivor in a round
    bulletDamage*:int # Bullet damage given
    bulletKillBonus*:int # Bullet kill bonus
    ramDamage*:int # Ram damage given
    ramKillBonus*:int # Ram kill bonus
    totalScore*:int # Total score
    firstPlaces*:int # Number of 1st places
    secondPlaces*:int # Number of 2nd places
    thirdPlaces*:int # Number of 3rd places

  ResultsForObserver* = ref object of ResultsForBot
    ## Individual participant results visible for an observer, where id, name, and version is available as well.
    id*:int # Id of the participant
    name*:string # Name of participant, e.g. Killer Bee (bot) or Killer Bees (team)
    version*:string # version, e.g. 1.0

  ResumeGame* = ref object of Message
    ## Command to resume a game

  RoundEndedEventForBot* = ref object of Event
    ## Event occurring when a round has ended. Gives all game results visible for a bot.
    results*:ResultsForBot # The accumulated bot results by the end of the round.

  RoundEndedEventForObserver* = ref object of Message
    ## Event occurring when a round has ended. Gives all game results visible for an observer.
    roundNumber*:int # The current round number in the battle when event occurred
    turnNumber*:int # The current turn number in the round when event occurred
    results*:seq[ResultsForObserver] # The accumulated results for all bots by the end of the round.

  RoundStartedEvent* = ref object of Event
    ## Event occurring when a new round has started.
    roundNumber*:int # The current round number in the battle when event occurred

  ScannedBotEvent* = ref object of Event
    ## Event occurring when a bot has scanned another bot
    scannedByBotId*:int # id of the bot did the scanning
    scannedBotId*:int # id of the bot that was scanned
    energy*:float # Energy level of the scanned bot
    x*:float # X coordinate of the scanned bot
    y*:float # Y coordinate of the scanned bot
    direction*:float # Direction in degrees of the scanned bot
    speed*:float # Speed measured in units per turn of the scanned bot

  ServerHandshake* = ref object of Message
    ## Server handshake
    sessionId*:string # Unique session id used for identifying the caller client (bot, controller, observer) connection.
    name*:string # Name of server, e.g. John Doe's RoboRumble Server
    variant*:string # Game variant, e.g. 'Tank Royale' for Robocode Tank Royale
    version*:string
    gameTypes*:seq[string] # Game types running at this server, e.g. "melee" and "1v1"
    gameSetup*:GameSetup # Current game setup, if a game has been started and is running on the server.

  SkippedTurnEvent* = ref object of Event
    ## Event occurring when a bot has skipped a turn, meaning that no intent has reached the server for a specific turn

  StartGame* = ref object of Message
    ## Command to start a new game
    gameSetup*:GameSetup # Game setup
    botAddresses*:seq[BotAddress] # List of bot addresses

  StopGame* = ref object of Message
    ## Command to stop a running game

  TeamMessageEvent* = ref object of Event
    ## Event occurring when a message has been received from a teammate
    message*:string # The message to send, e.g. in JSON format
    messageType*:string # The message type, e.g. a class name
    senderId*:int # The id of the sender teammate

  TeamMessage* = ref object of RootObj
    ## Message sent between teammates
    message*:string # The received message, e.g. in JSON format
    messageType*:string # The message type, e.g. a class name
    receiverId*:int # The id of the receiver teammate. If omitted, the message is broadcast to all teammates

  TickEventForBot* = ref object of Event
    ## Event occurring for before each new turn in the battle. Gives internal bot details.
    roundNumber*:int # The current round number in the battle when event occurred
    enemyCount*:int # Number of enemies left in the current round
    botState*:BotState # Current state of this bot
    bulletStates*:seq[BulletState] # Current state of the bullets fired by this bot
    events*:JsonNode # Events occurring in the turn relevant for this bot

  TickEventForObserver* = ref object of Event
    ## Event occurring for before each new turn in the battle. Gives details for observers.
    roundNumber*:int # The current round number in the battle when event occurred
    botStates*:seq[BotStateWithId] # Current state of all bots
    bulletStates*:seq[BulletState] # Current state of all bullets
    events*:JsonNode # All events occurring at this tick

  TpsChangedEvent* = ref object of Message
    ## Event occurring when a controller has changed the TPS (Turns Per Second), which is the number of turns displayed for an observer. TPS is similar to FPS, where a frame is equal to a turn.
    tps*:int # Turns per second (TPS). Typically a value from 0 to 999. -1 means maximum possible TPS speed.

  WonRoundEvent* = ref object of Event
    ## Event occurring when a bot has won the round

proc json2message*(json_message:string):Message =
  let `type` = json_message.fromJson(Message).`type`
  case `type`:
    of Type.event:
      result = json_message.fromJson(Event)
    of Type.botDeathEvent:
      result = json_message.fromJson(BotDeathEvent)
    of Type.botHandshake:
      result = json_message.fromJson(BotHandshake)
    of Type.botHitBotEvent:
      result = json_message.fromJson(BotHitBotEvent)
    of Type.botHitWallEvent:
      result = json_message.fromJson(BotHitWallEvent)
    of Type.botIntent:
      result = json_message.fromJson(BotIntent)
    of Type.botListUpdate:
      result = json_message.fromJson(BotListUpdate)
    of Type.botReady:
      result = json_message.fromJson(BotReady)
    of Type.bulletFiredEvent:
      result = json_message.fromJson(BulletFiredEvent)
    of Type.bulletHitBotEvent:
      result = json_message.fromJson(BulletHitBotEvent)
    of Type.bulletHitBulletEvent:
      result = json_message.fromJson(BulletHitBulletEvent)
    of Type.bulletHitWallEvent:
      result = json_message.fromJson(BulletHitWallEvent)
    of Type.changeTps:
      result = json_message.fromJson(ChangeTps)
    of Type.controllerHandshake:
      result = json_message.fromJson(ControllerHandshake)
    of Type.gameAbortedEvent:
      result = json_message.fromJson(GameAbortedEvent)
    of Type.gameEndedEventForBot:
      result = json_message.fromJson(GameEndedEventForBot)
    of Type.gameEndedEventForObserver:
      result = json_message.fromJson(GameEndedEventForObserver)
    of Type.gamePausedEventForObserver:
      result = json_message.fromJson(GamePausedEventForObserver)
    of Type.gameResumedEventForObserver:
      result = json_message.fromJson(GameResumedEventForObserver)
    of Type.gameStartedEventForBot:
      result = json_message.fromJson(GameStartedEventForBot)
    of Type.gameStartedEventForObserver:
      result = json_message.fromJson(GameStartedEventForObserver)
    of Type.hitByBulletEvent:
      result = json_message.fromJson(HitByBulletEvent)
    of Type.nextTurn:
      result = json_message.fromJson(NextTurn)
    of Type.observerHandshake:
      result = json_message.fromJson(ObserverHandshake)
    of Type.pauseGame:
      result = json_message.fromJson(PauseGame)
    of Type.resumeGame:
      result = json_message.fromJson(ResumeGame)
    of Type.roundEndedEventForBot:
      result = json_message.fromJson(RoundEndedEventForBot)
    of Type.roundEndedEventForObserver:
      result = json_message.fromJson(RoundEndedEventForObserver)
    of Type.roundStartedEvent:
      result = json_message.fromJson(RoundStartedEvent)
    of Type.scannedBotEvent:
      result = json_message.fromJson(ScannedBotEvent)
    of Type.serverHandshake:
      result = json_message.fromJson(ServerHandshake)
    of Type.skippedTurnEvent:
      result = json_message.fromJson(SkippedTurnEvent)
    of Type.startGame:
      result = json_message.fromJson(StartGame)
    of Type.stopGame:
      result = json_message.fromJson(StopGame)
    of Type.teamMessageEvent:
      result = json_message.fromJson(TeamMessageEvent)
    of Type.tickEventForBot:
      result = json_message.fromJson(TickEventForBot)
    of Type.tickEventForObserver:
      result = json_message.fromJson(TickEventForObserver)
    of Type.tpsChangedEvent:
      result = json_message.fromJson(TpsChangedEvent)
    of Type.wonRoundEvent:
      result = json_message.fromJson(WonRoundEvent)
    else:
      result = json_message.fromJson(Message)

proc isCritical*(event:Event):bool = false
