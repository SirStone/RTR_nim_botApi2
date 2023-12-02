# ----------------how to start a new bot----------------
import ../../../RTR_nim_botApi2    # import the bot api
startBot newBot("Walls.json") # start the bot
# --------------end, the rest is up to you--------------

import std/[math]

var peek:bool # Don't turn if there's a bot there
var moveAmount:float # How much to move

# Called when a new round is started -> initialize and do some movement
method run(bot:Bot) =
  # set colors
  bot.setBodyColor("#000000")
  bot.setTurretColor("#000000")
  bot.setRadarColor("#FFA500")
  bot.setBulletColor("#00FFFF")
  bot.setScanColor("#00FFFF")
  
  # Initialize moveAmount to the maximum possible for the arena
  moveAmount = max(bot.getArenaWidth(), bot.getArenaHeight()).float
  bot.console_log("moveAmount: " & $moveAmount)

  # Initialize peek to false
  peek = false

  # turn to face a wall.
  # getDirection() % 90` means the remainder of getDirection() divided by 90.

  bot.turnRight(bot.getDirection() mod 90.0)
  bot.forward(moveAmount)
  
  # Turn the gun to turn right 90 degrees.
  peek = true
  bot.turnGunRight(90)
  bot.turnRight(90)

  # Main loop
  while bot.isRunning():
    # Peek before we turn when forward() completes
    peek = true
    # Move up the wall
    bot.forward(moveAmount)
    # Don't peek now
    peek = false
    # Turn to the next wall
    bot.turnRight(90)

# We hit another bot -> move away a bit
method onHitBot(bot:Bot, bot_hit_bot_event:BotHitBotEvent) = 
  # If he's in front of us, set back up a bit.
  let bearing = bot.bearingTo(bot_hit_bot_event.x, bot_hit_bot_event.y)
  if bearing > -90 and bearing < 90:
    bot.back(100)
  else: # else he's in back of us, so set ahead a bit.
    bot.forward(100)

# We scanned another bot -> fire!
method onScannedBot(bot:Bot, scanned_bot_event:ScannedBotEvent) = 
  bot.fire(2)
  # Note that scan is called automatically when the bot is turning.
  # By calling it manually here, we make sure we generate another scan event if there's a bot
  # on the next wall, so that we do not start moving up it until it's gone.
  if peek:
    bot.rescan()