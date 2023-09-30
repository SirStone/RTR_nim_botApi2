import ../../src/RTR_nim_botApi2
# import std/[os, random, math]


let testBot = Bot.conf("TestBot.json")

start testBot

method run(bot:Bot) =
  echo "Bot", bot.name, " started"