import Message
import std/[os, sugar]
import jsony

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
    connected*:bool = false
    initialPosition*:InitialPosition
    gameSetup*:GameSetup
    myId*:int
    turnNumber*:int
    roundNumber*:int
    botState*:BotState
    remainingDistance*:float # The remianing distance to cover
    intent*:BotIntent = BotIntent(`type`: Type.botIntent)

    # usage during the games
    running*:bool = false

  Bot* = ref object of BluePrint

proc conf*(json_file: string): Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    let bot = readFile(joinPath(getAppDir(),json_file)).fromJson(Bot)
    # maybe code here ...
    return bot
  except IOError as e:
    echo "Error reading config file: ", e.msg
    quit(1)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot:BluePrint) {.base gcsafe.} = discard # this method is called in a secondary thread
method onGameAborted*(bot:BluePrint, gameAbortedEvent:GameAbortedEvent) {.base.} = discard
method onGameEnded*(bot:BluePrint, gameEndedEventForBot:GameEndedEventForBot) {.base.} = discard
method onGameStarted*(bot:BluePrint, gameStartedEventForBot:GameStartedEventForBot) {.base.} = discard
method onHitByBullet*(bot:BluePrint, hitByBulletEvent:HitByBulletEvent) {.base.} = discard
method onHitBot*(bot:BluePrint, botHitBotEvent:BotHitBotEvent) {.base.} = discard
method onHitWall*(bot:BluePrint, botHitWallEvent:BotHitWallEvent) {.base.} = discard
method onRoundEnded*(bot:BluePrint, roundEndedEventForBot:RoundEndedEventForBot) {.base.} = discard
method onRoundStarted*(bot:BluePrint, roundStartedEvent:RoundStartedEvent) {.base.} = discard
method onSkippedTurn*(bot:BluePrint, skippedTurnEvent:SkippedTurnEvent) {.base.} = discard
method onScannedBot*(bot:BluePrint, scannedBotEvent:ScannedBotEvent) {.base.} = discard
method onTick*(bot:BluePrint, tickEventForBot:TickEventForBot) {.base.} = discard
method onDeath*(bot:BluePrint, botDeathEvent:BotDeathEvent) {.base.} =  discard
method onConnected*(bot:BluePrint, url:string) {.base.} = discard
method onConnectionError*(bot:BluePrint, error:string) {.base.} = discard

proc isRunning*(bot:BluePrint):bool = bot.running

proc stop*(bot:BluePrint) =
  bot.running = false

proc start*(bot:BluePrint) =
  bot.running = true