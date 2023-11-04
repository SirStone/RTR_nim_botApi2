# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
startBot newBot("TestBot.json") # start the bot
# --------------end, the rest is up to you--------------

import std/[os, random]

let pool:array[16, char] = ['1','2','3','4','5','6','7','8','9','0','A','B','C','D','E','F']

proc randomColor():string =
  var color:string = "#"
  for i in 0..5:
    color &= pool[rand(15)]
  return color

method run(bot:Bot) =
  let total_gos = 100
  var current_go = 1
  echo "[TestBot] " & bot.name & " run started, running for"

  # turn around
  bot.turnRight(360)

  current_go = 1
  while isRunning(bot) and current_go <= total_gos:
    randomize()
    bot.setBodyColor(randomColor())
    bot.setGunColor(randomColor())
    bot.setRadarColor(randomColor())
    bot.setBulletColor(randomColor())
    bot.setScanColor(randomColor())
    bot.setTracksColor(randomColor())
    bot.setTurretColor(randomColor())

    # go bot # send the intent
    # current_go += 1
    sleep 30

  # before exiting, set the colors to white  
  bot.setBodyColor("#FFFFFF")
  bot.setGunColor("#FFFFFF")
  bot.setRadarColor("#FFFFFF")
  bot.setBulletColor("#FFFFFF")
  bot.setScanColor("#FFFFFF")
  bot.setTracksColor("#FFFFFF")
  bot.setTurretColor("#FFFFFF")

  echo "[TestBot] ", bot.name, " run stopped"

method onConnect(bot:Bot) =
  echo  "[TestBot] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[TestBot]Connection error:", error
  echo "[TestBot] server url used:",bot.serverConnectionURL
  echo "[TestBot] secret used:",bot.secret

var skipped_turns = 0
method onSkippedTurn(bot:Bot, skippedTurnEvent:SkippedTurnEvent) =
  skipped_turns += 1
  if skipped_turns mod 100 == 0:
    echo "[TestBot]Skipped turns: ", skipped_turns
  stdout.write "*" # print a star for each skipped turn

method onHitByBullet(bot:Bot, hitByBulletEvent:HitByBulletEvent) =
  echo "[TestBot]Hit by bullet, OUCH! ", hitByBulletEvent.bullet.power

method onDeath(bot:Bot, botDeathEvent:BotDeathEvent) =
  echo "[TestBot]I'm dead! turn: ", botDeathEvent.turnNumber