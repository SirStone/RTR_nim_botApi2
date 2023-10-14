import ../../src/RTR_nim_botApi2
import std/[os]

let testBot = Bot.conf("TestBot.json")

startBot testBot

method run(bot:Bot) =
  logout bot,"[TestBot]Bot" & bot.name & " started"
  var i = 1
  while isRunning bot:
    logout bot,"[TestBot]Running.." & $i
    i += 1
    go bot
    sleep 1000

method onConnect(bot:Bot) =
  logout bot, bot.name & "[TestBot] Connected"

method onConnectionError(bot:Bot, error:string) =
  logerr bot,"Connection error:" & error

method onSkippedTurn(bot:Bot, skippedTurnEvent:SkippedTurnEvent) =
  logerr bot,"Skipped turn: " & $skippedTurnEvent.turnNumber