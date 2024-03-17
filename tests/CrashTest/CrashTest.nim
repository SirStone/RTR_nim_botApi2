
import math
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

  # move on the perimeter of the circle with the radius given
  var distance_h = bot.getBattlefieldWidth() - bot.getX() - bot.getBattlefieldWidth() / 2 + radius  
  bot.forward(distance_h)

  # start circling around the center
  var turning_angle = 5.0
  var speed = 5.0
  bot.setTurnRate(turning_angle)
  bot.setTargetSpeed(speed)

  while bot.isRunning():
    
    bot.go()
  
  echo "[",bot.name,"] stopping my run method now ", bot.getTurnNumber()

method onConnect(bot:Bot) =
  echo  "[",bot.name,"] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[",bot.name,"]Connection error:", error
  echo "[",bot.name,"] server url used:",bot.serverConnectionURL
  echo "[",bot.name,"] secret used:",bot.secret

method onSkippedTurn(bot:Bot, e:SkippedTurnEvent) =
  echo "[",bot.name,"] I skipped a turn ", e.turnNumber, " my energy:", bot.getEnergy()