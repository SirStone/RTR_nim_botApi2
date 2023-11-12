# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
startBot newBot("TestBot.json") # start the bot
# --------------end, the rest is up to you--------------

import std/[os, random, parsecsv, parseutils]

type
  Test = object
    action:string
    value:float
    turn_start:int
    turn_end:int

let pool:array[16, char] = ['1','2','3','4','5','6','7','8','9','0','A','B','C','D','E','F']

proc randomColor():string =
  var color:string = "#"
  for i in 0..5:
    color &= pool[rand(15)]
  return color

# import tests
proc importTests():seq[Test] =
  var testsToDo = newSeq[Test]()
  var p:CsvParser
  try:
    p.open("testsToDo.csv", separator = '|')
    p.readHeaderRow()
    while p.readRow():
      let action = p.rowEntry("action")
      var value:float
      var turn_start, turn_end:int
      discard parseFloat(p.rowEntry("value"), value)
      discard parseInt(p.rowEntry("turn_start"), turn_start)
      discard parseInt(p.rowEntry("turn_end"), turn_end)
      testsToDo.add(Test(action: action, value: value, turn_start: turn_start, turn_end: turn_end))
    p.close()
  except CatchableError:
    echo "Error while reading testsToDo.csv", getCurrentExceptionMsg()
  return testsToDo

method run(bot:Bot) =
  # import the tests
  let testsToDo:seq[Test] = importTests()

  echo "[TestBot] run started "
  var test_index = 0
  
  # adjusting radar and gun movementsrelated to body movements
  bot.setAdjustGunForBodyTurn(true)
  bot.setAdjustRadarForGunTurn(true)
  bot.setAdjustRadarForBodyTurn(true)

  echo "[TestBot] " & bot.name & " run started, running for"

  while isRunning(bot) and test_index < testsToDo.len:
    # pick the next test
    let test = testsToDo[test_index]

    # check if is the right turn to do the test
    if test.turn_start == bot.getTurnNumber():
      # switch color for each test
      randomize()
      let color = randomColor()
      bot.setBodyColor(color)
      bot.setGunColor(color)
      bot.setRadarColor(color)
      bot.setBulletColor(color)
      bot.setScanColor(color)
      bot.setTracksColor(color)
      bot.setTurretColor(color)

      echo "[TestBot] running test ", test.action

      case test.action:
      of "turnLeft":
        bot.turnLeft(test.value)
      of "turnRight":
        bot.turnRight(test.value)
      of "turnGunLeft":
        bot.turnGunLeft(test.value)
      of "turnGunRight":
        bot.turnGunRight(test.value)
      of "turnRadarLeft":
        bot.turnRadarLeft(test.value)
      of "turnRadarRight":
        bot.turnRadarRight(test.value)
      of "forward":
        bot.forward(test.value)
      of "back":
        bot.back(test.value)
      
      echo "[TestBot] ",test.action," done ",test.value, " at turn ",bot.getTurnNumber()
      test_index = test_index + 1
    else:
      go bot

    # go bot # send the intent
    # current_go += 1
    # sleep 30

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