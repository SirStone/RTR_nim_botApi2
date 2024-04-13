# ----------------how to start a new bot----------------
import random
import ../../../RTR_nim_botApi2    # import the bot api
startBot newBot("Corners.json") # start the bot
# --------------end, the rest is up to you--------------

##` ------------------------------------------------------------------
##` Corners
##` ------------------------------------------------------------------
##` A sample bot original made for Robocode by Mathew Nelson.
##` Ported to Robocode Tank Royale by Flemming N. Larsen.
##`
##` This bot moves to a corner, then swings the gun back and forth.
##` If it dies, it tries a new corner in the next round.
##` ------------------------------------------------------------------


proc randomCorner():int =
  randomize()
  return 90 * rand(4) # Random number is between 0-3

var enemies:int # Number of enemy bots in the game
var corner:int = randomCorner() # Which corner we are currently heading using, set to random corner
var stopWhenSeeEnemy:bool = false # see goCorner()

## A very inefficient way to get to a corner.
## Can you do better as an home exercise? :)
proc goCorner(bot:Bot) =
  # We don't want to stop when we're just turning...
  stopWhenSeeEnemy = false;
  # Turn to face the wall towards our desired corner
  bot.turnLeft(bot.calcBearing(corner.float))
  # Ok, now we don't want to crash into any bot in our way...
  stopWhenSeeEnemy = true
  # Move to that wall
  bot.forward(5000)
  # Turn to face the corner
  bot.turnRight(90)
  # Move to the corner
  bot.forward(5000)
  # Turn gun to starting point
  bot.turnGunRight(90)

## Custom fire method that determines firepower based on distance.
## distance: The distance to the bot to fire at.
proc smartFire(bot:Bot, distance:float) =
  if distance > 200 or bot.getEnergy() < 15:
    bot.fire(1)
  elif distance > 50:
    bot.fire(2)
  else:
    bot.fire(3)

# Called when a new round is started -> initialize and do some movement
method run(bot:Bot) {.gcsafe.} =
  # set colors
  bot.setBodyColor("#FF0000")
  bot.setTurretColor("#000000")
  bot.setRadarColor("#FFFF00")
  bot.setBulletColor("#00FF00")
  bot.setScanColor("#00FF00")
  
  # save number of ither bots
  enemies = bot.getEnemyCount()

  # move to a corner
  bot.goCorner()

  # Initialize gun turn speed to 3
  var gunIncrement:int = 3

  # Spin gun back and forth
  while bot.isRunning():
    for i in 0..30:
      bot.turnGunRight(gunIncrement.float)
    gunIncrement *= -1

method onScannedBot(bot: Bot, e:ScannedBotEvent) =
  bot.log "Scanned bot ", e.scannedBotId
  var distance = bot.distanceTo(e.x, e.y)

  # Should we stop, or just fire?
  if stopWhenSeeEnemy:
    # stop movement
    bot.stop()
    # Call our custom firing method
    bot.smartFire(distance)
    # Rescan for another bot
    bot.rescan()
    # This line will not be reached when scanning another bot.
    # So we did not scan another bot -> resume movement
    bot.resume()
  else:
    bot.smartFire(distance)
  
## We died -> figure out if we need to switch to another corner
method onDeath(bot: Bot, e:BotDeathEvent) =
  # Well, others should never be 0, but better safe than sorry.
  if enemies == 0:
    return

  # If 75% of the bots are still alive when we die, we'll switch corners.
  if bot.getEnemyCount().float >= enemies.float * 0.75:
    corner += 90 # Next corner
    corner = corner mod 360 # Make sure it's in the 0-359 range
    
    bot.console_log("I died and did poorly... switching corner to " & $corner)
  else:
    bot.console_log("I died but did well. I will still use corner " & $corner)