import jsony, malebolgia/lockers
import Schemas

type
  Condition* = object
    name*: string = "no name"
    test*: proc(bot: Bot):bool

  BluePrint = ref object of RootObj
    name*: string = "BluePrint"
    version*: string
    description*: string
    homepage*: string
    platform*: string
    programmingLang*: string
    gameTypes*: seq[string]
    authors*: seq[string]
    countryCodes*: seq[string]

  Bot* = ref object of BluePrint # required for Nim overloading capabilities

var bot* = initLocker Bot() # the MAIN bot instance

proc json2bot*(json: string) =
  unprotected bot as b:
    b = jsony.fromJson(json, Bot)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot: BluePrint) {.base gcsafe.} = discard
method onBulletFired*(bot: BluePrint, bulletFiredEvent: BulletFiredEvent) {.base gcsafe.} = discard
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
method onDeath*(bot: BluePrint, botDeathEvent: BotDeathEvent) {.base gcsafe.} = discard
method onConnect*(bot: BluePrint) {.base gcsafe.} = discard
method onConnectionError*(bot: BluePrint, error: string) {.base gcsafe.} = discard
method onWonRound*(bot: BluePrint, wonRoundEvent: WonRoundEvent) {.base gcsafe.} = discard
method onCustomCondition*(bot: BluePrint, name: string) {.base gcsafe.} = discard

proc getName*(): string = lock bot as b: return b.name
proc getVersion*(): string = lock bot as b: return b.version
proc getDescription*(): string = lock bot as b: return b.description
proc getHomepage*(): string = lock bot as b: return b.homepage
proc getPlatform*(): string = lock bot as b: return b.platform
proc getProgrammingLang*(): string = lock bot as b: return b.programmingLang
proc getGameTypes*(): seq[string] = lock bot as b: return b.gameTypes
proc getAuthors*(): seq[string] = lock bot as b: return b.authors
proc getCountryCodes*(): seq[string] = lock bot as b: return b.countryCodes