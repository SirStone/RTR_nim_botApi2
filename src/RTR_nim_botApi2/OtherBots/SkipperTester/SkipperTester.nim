import os
import ../../../RTR_nim_botApi2    # import the bot api


startBot newBot("SkipperTester.json") # start the bot

var dead = false

method run(bot:Bot) =
  while bot.isRunning(): # <--- we want mantain the bot running to avoid the automatc go()
    sleep(1000) # <--- sleep for 1 second, doing nothing
    # bot.go() <--- not sending go, we want to skip every turn!

method onDeath(bot: Bot, e: BotDeathEvent) =
  echo "I'm dead: " & $e.turnNumber
  dead = true

method onSkippedTurn(bot: Bot, e: SkippedTurnEvent) =
  if not dead: echo "Skipped turn: " & $e.turnNumber
  else: echo "Skipped turn: " & $e.turnNumber & " (dead)"