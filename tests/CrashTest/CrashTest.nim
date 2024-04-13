
import ../../src/RTR_nim_botApi2    # import the bot api
startBot newBot("CrashTest.json") # start the bot
# --------------end, the rest is up to you--------------

var degrees:float = 0

method run(bot:Bot) =
  degrees = 99999
  while bot.isRunning():
    bot.setTurnGunLeft(degrees)
    bot.turnRight(degrees)
  
  bot.log "[",bot.name,"] stopping my run method now ", bot.getTurnNumber()

method onConnect(bot:Bot) =
  bot.log  "[",bot.name,"] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  bot.error "[",bot.name,"] Connection error:", error
  bot.error "[",bot.name,"] server url used:",bot.serverConnectionURL
  bot.error "[",bot.name,"] secret used:",bot.secret

method onHitByBullet(bot:Bot, e:HitByBulletEvent) =
  bot.log "[",bot.name,"] I was hit by a bullet from ", e.bullet.ownerId, " at turn ", bot.getTurnNumber
  bot.radarTurnLeft(90)