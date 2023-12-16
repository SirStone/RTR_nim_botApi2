# ----------------how to start a new bot----------------
import ../../../RTR_nim_botApi2    # import the bot api
startBot newBot("Crazy.json") # start the bot
# --------------end, the rest is up to you--------------

## ------------------------------------------------------------------
## Crazy NIM
## ------------------------------------------------------------------
##
## This bot moves around in a crazy pattern.
## ------------------------------------------------------------------

var movingForward:bool
# Called when a new round is started -> initialize and do some movement
method run(bot:Bot) =
  # set colors
  bot.setBodyColor("#00C800") #lime
  bot.setTurretColor("#009632") #green
  bot.setRadarColor("#006464") #dark cyan
  bot.setBulletColor("#FFFF64") #yellow
  bot.setScanColor("#FFC8C8") #light red
  
  # Loop while as long as the bot is running
  while bot.isRunning():
    # Tell the game we will want to move ahead 40000 -- some large number
    bot.setForward(4000)
    movingForward = true

    # Tell the game we will want to turn right 90
    bot.setTurnRight(90)

    # At this point, we have indicated to the game that *when we do something*,
    # we will want to move ahead and turn right.  That's what "set" means.
    # It is important to realize we have not done anything yet!
    # In order to actually move, we'll want to call a method that
    # takes real time, such as waitFor.
    # waitFor actually starts the action -- we start moving and turning.
    # It will not return until we have finished turning.
    let turnCompleteCondition = Condition(test:proc(bot:Bot):bool = bot.getTurnRemaining() == 0)
    bot.waitFor(turnCompleteCondition)
    # Note:  We are still moving ahead now, but the turn is complete.
    # Now we'll turn the other way...
    bot.setTurnLeft(180)
    # ... and wait for the turn to finish ...
    bot.waitFor(turnCompleteCondition)
    # ... then the other way ...
    bot.setTurnRight(180)
    # .. and wait for that turn to finish.
    bot.waitFor(turnCompleteCondition)
    # then back to the top to do it all again

proc reverseDirection(bot:Bot) =
  if movingForward:
    bot.setBack(4000)
    movingForward = false
  else:
    bot.setForward(4000)
    movingForward = true

method onHitWall(bot:Bot, event:BotHitWallEvent) =
  # Bounce off!
  reverseDirection(bot);

# We scanned another bot -> fire!
method onScannedBot(bot:Bot, event:ScannedBotEvent) =
  bot.fire(1)

# We were hit by another bot -> back up!
method onHitBot(bot:Bot, event:BotHitBotEvent) =
  # If we're moving into the other bot, reverse!
  if event.isRammed():
    reverseDirection(bot)
