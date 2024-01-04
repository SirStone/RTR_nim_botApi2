import Schemas
import ws

type
  BluePrint = ref object of RootObj
    # filled from JSON
    name:string = "BluePrint"
    version:string
    description:string
    homepage:string
    platform:string
    programmingLang:string
    gameTypes:seq[string]
    authors:seq[string]
    countryCodes:seq[string]

  Bot* = ref object of BluePrint
    botIntent:BotIntent
    tickEvent:TickEventForBot
    initialPosition:InitialPosition = InitialPosition(x:0, y:0, angle:0)
    connected:bool = false
    running:bool = false
    gameStartedEventForBot:GameStartedEventForBot

#++++++++ BOT METHODS ++++++++#
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
method onConnect*(bot:BluePrint, connectedEvent:ConnectedEvent) {.base gcsafe.} = discard
method onConnectionError*(bot:BluePrint, error:string) {.base gcsafe.} = discard
method onDisconnect*(bot:BluePrint, disconnectedEvent:DisconnectedEvent) {.base gcsafe.} = discard
method onWonRound*(bot:BluePrint, wonRoundEvent:WonRoundEvent) {.base gcsafe.} = discard
method onCustomCondition*(bot:BluePrint, name:string) {.base gcsafe.} = discard

#++++++++ BOT COMMANDS ++++++++#
proc getName*(bot:Bot):string = bot.name
proc getVersion*(bot:Bot):string = bot.version
proc getDescription*(bot:Bot):string = bot.description
proc getHomepage*(bot:Bot):string = bot.homepage
proc getPlatform*(bot:Bot):string = bot.platform
proc getProgrammingLang*(bot:Bot):string = bot.programmingLang
proc getGameTypes*(bot:Bot):seq[string] = bot.gameTypes
proc getAuthors*(bot:Bot):seq[string] = bot.authors
proc getCountryCodes*(bot:Bot):seq[string] = bot.countryCodes
proc getInitialPosition*(bot:Bot):InitialPosition = bot.initialPosition
proc getBotIntent*(bot:Bot):BotIntent = bot.botIntent
proc getTurn*(bot:Bot):int =
  if bot.tickEvent.isNil: 0
  else: bot.tickEvent.turnNumber

proc isConnected*(bot:Bot):bool = bot.connected
proc isRunning*(bot:Bot):bool = bot.running

proc setConnected*(bot:Bot, connected:bool) = bot.connected = connected
proc setRunning*(bot:Bot, running:bool) = bot.running = running
proc setGameStartedEventForBot*(bot:Bot, gameStartedEventForBot:GameStartedEventForBot) = bot.gameStartedEventForBot = gameStartedEventForBot
proc setTick*(bot:Bot, tickEvent:TickEventForBot) = bot.tickEvent = tickEvent

proc newIntent*(bot:Bot) = bot.botIntent = BotIntent(`type`:Type.botIntent)