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

    # filled from the environment
    secret*:string
    serverConnectionURL*:string

  Bot* = ref object of BluePrint

proc conf*(json_file: string): Bot =
  # read the config file from disk
  try:
    # build the bot from the json
    result = readFile(joinPath(getAppDir(),json_file)).fromJson(Bot)
  except IOError as e:
    echo "Error reading config file: ", e.msg
    quit(1)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot:BluePrint) {.base.} =
  dump("Bot " & bot.name & " is not running because the run method is not overrided")
method onGameAborted(bot:Bot, gameAbortedEvent:GameAbortedEvent) {.base.} = discard
method onGameEnded(bot:Bot, gameEndedEventForBot:GameEndedEventForBot) {.base.} = discard
method onGameStarted(bot:Bot, gameStartedEventForBot:GameStartedEventForBot) {.base.} = discard
method onHitByBullet(bot:Bot, hitByBulletEvent:HitByBulletEvent) {.base.} = discard
method onHitBot(bot:Bot, botHitBotEvent:BotHitBotEvent) {.base.} = discard
method onHitWall(bot:Bot, botHitWallEvent:BotHitWallEvent) {.base.} = discard
method onRoundEnded(bot:Bot, roundEndedEventForBot:RoundEndedEventForBot) {.base.} = discard
method onRoundStarted(bot:Bot, roundStartedEvent:RoundStartedEvent) {.base.} = discard
method onSkippedTurn(bot:Bot, skippedTurnEvent:SkippedTurnEvent) {.base.} = discard
method onScannedBot(bot:Bot, scannedBotEvent:ScannedBotEvent) {.base.} = discard
method onTick(bot:Bot, tickEventForBot:TickEventForBot) {.base.} = discard
method onDeath(bot:Bot, botDeathEvent:BotDeathEvent) {.base.} =  discard
method onConnected(bot:Bot, url:string) {.base.} = discard
method onConnectionError(bot:Bot, error:string) {.base.} = discard
