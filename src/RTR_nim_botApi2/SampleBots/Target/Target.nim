# ----------------how to start a new bot----------------
import ../../../RTR_nim_botApi2    # import the bot api
startBot newBot("Target.json") # start the bot
# --------------end, the rest is up to you--------------

## ------------------------------------------------------------------
## Target NIM
## ------------------------------------------------------------------
##
## Sits still. Moves every time energy drops by 20.
## This bot demonstrates custom events.
## ------------------------------------------------------------------

var trigger:int # Keeps track of when to move

# Called when a new round is started -> initialize and do some movement
method run(bot:Bot) {.gcsafe.} =
  # set colors
  bot.setBodyColor("#FFFFFF")
  bot.setTurretColor("#FFFFFF")
  bot.setRadarColor("#FFFFFF")
  
  # Initially, we'll move when energy passes 80
  trigger = 80

  # Add a custom event named "trigger-hit"
  bot.addCustomCondition(Condition(name:"trigger-hit", test: proc(bot:Bot): bool = bot.getEnergy() <= trigger.float))

method onCustomCondition(bot:Bot, name:string) =
  # Check if our custom event "trigger-hit" went off
  if name == "trigger-hit":
    # Adjust the trigger value, or else the event will fire again and again and again...
    trigger -= 20

    # Print out energy level
    bot.log "Ouch, down to ", (bot.getEnergy() + 0.5), " energy."

    # Move around a bit
    bot.turnLeft(65);
    bot.forward(100);