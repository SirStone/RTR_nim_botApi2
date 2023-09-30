import ../../src/RTR_nim_botApi2
# import std/[os, random, math]

type TestBot = ref object of Bot

let bot = TestBot()

bot.conf("TestBot.json")

method run(bot:TestBot) =
  echo "Bot", bot.name, " started"