import std/[os]
import jsony, whisky
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
    talkerReady*:bool = false
    running*:bool = false
    connected*:bool = false
    lastMessageType*:Type
    gs_ws*:WebSocket

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
method onConnect*(bot:BluePrint) {.base.} = discard
method onConnectionError*(bot:BluePrint, error:string) {.base.} = discard

proc isRunning*(bot:BluePrint):bool = bot.running

proc stop*(bot:BluePrint) =
  bot.running = false

proc start*(bot:BluePrint) =
  bot.running = true