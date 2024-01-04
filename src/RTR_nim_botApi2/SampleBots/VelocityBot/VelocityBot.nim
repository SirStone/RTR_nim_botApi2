# ----------------how to start a new bot----------------
import ../../../RTR_nim_botApi2    # import the bot api
start("VelocityBot.json") # start the bot
# --------------end, the rest is up to you--------------

## ------------------------------------------------------------------
## VelocityBot NIM
## ------------------------------------------------------------------
##
## Example bot of how to use turn rates
## ------------------------------------------------------------------

# var turnCounter:int
# # Called when a new round is started -> initialize and do some movement
# method run(bot:Bot) {.gcsafe.} =
#   turnCounter = 0
#   bot.setGunTurnRate(15)

#   while bot.isRunning():
#     if (turnCounter mod 64 == 0):
#       # Straighten out, if we were hit by a bullet (ends turning)
#       bot.setTurnRate(0)
#       # Go forward with a target speed of 4
#       bot.setTargetSpeed(4)
#     if (turnCounter mod 64 == 32):
#       # Go backwards, faster
#       bot.setTargetSpeed(-6)
#     turnCounter += 1
#     bot.go()

# # We scanned another bot -> fire!
# method onScannedBot(bot:Bot, event:ScannedBotEvent) =
#   bot.fire(1)

# # We were hit by a bullet -> set turn rate
# method onHitByBullet(bot:Bot, event:HitByBulletEvent) =
#   # Turn to confuse the other bots
#   bot.setTurnRate(5)

# # We hit a wall -> move in the opposite direction
# method onHitWall(bot:Bot, event:BotHitWallEvent) =
#   # Move away from the wall by reversing the target speed.
#   # Note that current speed is 0 as the bot just hit the wall.
#   bot.setTargetSpeed(-1 * bot.getTargetSpeed())