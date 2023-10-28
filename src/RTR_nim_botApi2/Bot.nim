import std/[os]
import jsony
import Schema

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

    # filled from the environment or during the run
    secret*:string
    serverConnectionURL*:string
    initialPosition*:InitialPosition
    gameSetup*:GameSetup
    myId*:int
    turnNumber*:int
    roundNumber*:int
    botState*:BotState
    remainingDistance*:float # The remaining distance to cover
    intent*:BotIntent = BotIntent(`type`: Type.botIntent)

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
  except IOError as e:
    echo "[conf] Error reading config file: ", e.msg
    quit(1)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot:BluePrint) {.base gcsafe.} = discard # this method is called in a secondary thread
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

proc isRunning*(bot:BluePrint):bool = bot.running

proc stop*(bot:BluePrint) =
  bot.running = false

proc start*(bot:BluePrint) =
  bot.running = true

#++++++++ COLORS +++++++++#
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
