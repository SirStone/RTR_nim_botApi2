
import ../../src/RTR_nim_botApi2    # import the bot api
startBot(json_file="CrashTest.json", position=InitialPosition(x:400, y:300, direction:45)) # start the bot with the initial position
# --------------end, the rest is up to you--------------

var degrees:float = 0

method run(bot:Bot) =
  # degrees = 99999
  # while isRunning():
  #   bot.setGunTurnLeft(degrees)
  #   bot.turnRight(degrees)
  
  bot.log "[",bot.getName,"] stopping my run method now ", bot.getTurnNumber()

method onConnect(bot:Bot) =
  bot.log  "[",bot.getName,"] I'm connected! Yuppy!"

method onHitByBullet(bot:Bot, e:HitByBulletEvent) =
  bot.log "[",bot.getName,"] I was hit by a bullet from ", e.bullet.ownerId, " at turn ", bot.getTurnNumber
  bot.radarTurnLeft(90)

method onSkippedTurn(bot:Bot, e:SkippedTurnEvent) =
  bot.log "[",bot.getName,"] I skipped a turn at ", e.turnNumber