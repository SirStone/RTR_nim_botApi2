# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
startBot Bot.newBot("TestBot.json") # start the bot
# --------------end, the rest is up to you--------------

import std/[os]

method run(bot:Bot) =
  let total_gos = 50
  var current_go = 1
  echo "[TestBot] " & bot.name & " run started, running for"
  while bot.isRunning and current_go <= total_gos:
    if go bot:
      echo "[TestBot] running: ", $isRunning(bot), " turn number: ", $bot.turnNumber, " go: ", $current_go, " of ", $total_gos
      current_go += 1
    sleep 10
  echo "[TestBot] " & bot.name & " run stopped"

method onConnect(bot:Bot) =
  echo  "[TestBot] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[TestBot]Connection error:" & error

method onSkippedTurn(bot:Bot, skippedTurnEvent:SkippedTurnEvent) =
  echo "[TestBot]Skipped turn: " & $skippedTurnEvent.turnNumber

method onHitByBullet(bot:Bot, hitByBulletEvent:HitByBulletEvent) =
  echo "[TestBot]Hit by bullet, OUCH!"