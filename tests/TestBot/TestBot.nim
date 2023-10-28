# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
startBot Bot.newBot("TestBot.json") # start the bot
# --------------end, the rest is up to you--------------

import std/[os]

method run(bot:Bot) =
  let total_gos = 100
  var current_go = 1
  echo "[TestBot] " & bot.name & " run started, running for"
  while isRunning(bot) and current_go <= total_gos:
    go bot # send the intent
    echo "[TestBot] running: ", $isRunning(bot), " turn number: ", $bot.turnNumber, " go: ", $current_go, " of ", $total_gos
    current_go += 1
    sleep 30
  echo "[TestBot] " & bot.name & " run stopped"

method onConnect(bot:Bot) =
  echo  "[TestBot] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[TestBot]Connection error:" & error

var skipped_turns = 0
method onSkippedTurn(bot:Bot, skippedTurnEvent:SkippedTurnEvent) =
  skipped_turns += 1
  if skipped_turns mod 100 == 0:
    echo "[TestBot]Skipped turns: ", skipped_turns
  stdout.write "*" # print a star for each skipped turn

method onHitByBullet(bot:Bot, hitByBulletEvent:HitByBulletEvent) =
  echo "[TestBot]Hit by bullet, OUCH!"

method onDeath(bot:Bot, botDeathEvent:BotDeathEvent) =
  echo "[TestBot]I'm dead, I'm dead, I'm dead! turn: " & $botDeathEvent.turnNumber