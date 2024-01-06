import Schemas

type
  BluePrint* = ref object of RootObj
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
    myId*:int
    gameSetup*:GameSetup
    tickEvent*:TickEventForBot
    intent*:BotIntent = BotIntent(`type`: Type.botIntent, fireAssist: true)

# the following section contains all the methods that are supposed to be overrided by the bot creator
method run*(bot:BluePrint) {.base gcsafe.} = discard # this method is called in a secondary thread
method onBulletFired*(bot:BluePrint, bulletFiredEvent:BulletFiredEvent) {.base gcsafe.} = discard
method onBulletHitBot*(bot:BluePrint, bulletHitBotEvent:BulletHitBotEvent) {.base gcsafe.} = discard
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
method onConnect*(bot:BluePrint) {.base gcsafe.} = discard
method onConnectionError*(bot:BluePrint, error:string) {.base gcsafe.} = discard
method onWonRound*(bot:BluePrint, wonRoundEvent:WonRoundEvent) {.base gcsafe.} = discard
method onCustomCondition*(bot:BluePrint, name:string) {.base gcsafe.} = discard