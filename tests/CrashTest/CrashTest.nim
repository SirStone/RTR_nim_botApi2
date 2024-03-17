
import std/math
import ../../src/RTR_nim_botApi2    # import the bot api
startBot newBot("CrashTest.json") # start the bot
# --------------end, the rest is up to you--------------

method run(bot:Bot) =
  echo "[",bot.name,"] I'm a crash test bot, I will crash now", bot.getTurnNumber()

  # diameter is the shortest side of the battefield
  var diameter = bot.getBattlefieldWidth() 
  if bot.getBattlefieldWidth() > bot.getBattlefieldHeight():
    diameter = bot.getBattlefieldHeight()

  var radius = diameter / 2

  echo "[",bot.name,"] diameter: ",diameter
  echo "[",bot.name,"] radius: ",radius

  #turn face to 0
  var angle = bot.getDirection() mod 360
  if angle > 180:
    bot.turnLeft(360 - angle)
  else:
    bot.turnRight(angle)

  # move forward
  bot.setTargetSpeed(bot.getMaxSpeed())

  while bot.isRunning():
    bot.go()
  
  echo "[",bot.name,"] stopping my run method now ", bot.getTurnNumber()

method onConnect(bot:Bot) =
  echo  "[",bot.name,"] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[",bot.name,"]Connection error:", error
  echo "[",bot.name,"] server url used:",bot.serverConnectionURL
  echo "[",bot.name,"] secret used:",bot.secret

# method onSkippedTurn(bot:Bot, e:SkippedTurnEvent) =
#   echo "[",bot.name,"] I skipped a turn ", e.turnNumber, " my energy:", bot.getEnergy()

method onHitWall(bot:Bot, e:BotHitWallEvent) =
  echo "[",bot.name,"] Wall hitted ", e.turnNumber, " my energy:", bot.getEnergy()

  # stop forwarding
  echo "[",bot.name,"] stopping forwarding"
  bot.setTargetSpeed(0)

  # turn 90 degrees to the right
  echo "[",bot.name,"] turning right 90 degrees"
  bot.turnRight(90)

  # start moving forward again
  echo "[",bot.name,"] moving forward again ", bot.getMaxSpeed()
  bot.setTargetSpeed(bot.getMaxSpeed())