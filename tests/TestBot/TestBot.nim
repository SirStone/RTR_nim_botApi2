# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
let bot = newBot("TestBot.json")
let bot_initialPosition = InitialPosition(x:400,y:300,angle:0) 
startBot(bot, true, bot_initialPosition) # start the bot
# --------------end, the rest is up to you--------------

import std/[os, random, parsecsv, parseutils, math]

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
    p.open(joinPath(getAppDir(),"testsToDo.csv"), separator = '|')
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

proc actionCheck(actionType:string, value_start:seq[float], value_end:seq[float], expected:float):float =
  # echo "[TestBot] ",actionType,"_start: [x:",value_start[0],",y:",value_start[1],"]"
  # echo "[TestBot] ",actionType,"_end: [x:",value_end[0],",y:",value_end[1],"]"
  return sqrt((value_end[0] - value_start[0]).pow(2) + (value_end[1] - value_start[1]).pow(2))

proc actionCheck(actionType:string, value_start:float, value_end:float, expected:float):float =
  # echo "[TestBot] ",actionType,"_start: ",value_start
  # echo "[TestBot] ",actionType,"_end: ",value_end

  case actionType:
  of "turnLeft":    
    result = value_end - value_start
  of "turnRight":
    result = value_start - value_end
  of "turnGunLeft":
    result = value_end - value_start
  of "turnGunRight":
    result = value_start - value_end
  of "turnRadarLeft":
    result = value_end - value_start
  of "turnRadarRight":
    result = value_start - value_end
  else:
    result = 0

  if expected >= 0:
    if result < 0: result = result + 360.0
  else:
    if result > 0: result = result - 360.0

method run(bot:Bot) =
  # import the tests
  let testsToDo:seq[Test] = importTests()

  echo "[TestBot] run started "
  
  # adjusting radar and gun movementsrelated to body movements
  bot.setAdjustGunForBodyTurn(true)
  bot.setAdjustRadarForGunTurn(true)
  bot.setAdjustRadarForBodyTurn(true)

  # open file for tests results
  let fileNameResults = joinPath(getAppDir(),"testsResults_byTestBot.csv")
  
  # remove the old file if it exists
  removeFile(fileNameResults)

  # create the new test file
  var csvResults = open(fileNameResults, fmAppend)

  # write the header
  csvResults.setFilePos(0)
  csvResults.writeLine("ROUND|START TURN|END TURN|ACTION|VALUE|ACTION_START_VALUE|ACTION_END_VALUE|EXPECTED_DIFF|OBTAINED_DIFF|DISTANCE|CHECK_RESULT")

  echo "[TestBot] " & bot.name & " run started, running for"

  # run each test one after the other
  for test in testsToDo:
    if bot.isRunning():
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

      let starting_turn = bot.getTurnNumber()

      var
        body_turn_start:float
        gun_turn_start:float
        radar_turn_start:float
        x_start:float
        y_start:float
        action_start_value:string
        action_end_value:string
        expected_value:float
        current_value:float
        result:bool

      case test.action:
      of "turnLeft":
        body_turn_start = bot.getDirection()
        bot.turnLeft(test.value)
      of "turnRight":
        body_turn_start = bot.getDirection()
        bot.turnRight(test.value)
      of "turnGunLeft":
        gun_turn_start = bot.getGunDirection()
        bot.turnGunLeft(test.value)
      of "turnGunRight":
        gun_turn_start = bot.getGunDirection()
        bot.turnGunRight(test.value)
      of "turnRadarLeft":
        radar_turn_start = bot.getRadarDirection()
        bot.turnRadarLeft(test.value)
      of "turnRadarRight":
        radar_turn_start = bot.getRadarDirection()
        bot.turnRadarRight(test.value)
      of "forward":
        x_start = bot.getX()
        y_start = bot.getY()
        bot.forward(test.value)
      of "back":
        x_start = bot.getX()
        y_start = bot.getY()
        bot.back(test.value)


      echo "[TestBot] ",test.action," ",test.value, " COMPLETED at turn ",bot.getTurnNumber()

      case test.action:
      of "turnLeft":
        action_start_value = $body_turn_start.round(3)
        action_end_value = $bot.getDirection()
        expected_value = test.value.abs
        current_value = actionCheck(test.action,body_turn_start,bot.getDirection(),test.value).abs
        result = current_value.round.abs == expected_value.round.abs
      of "turnRight":
        action_start_value = $body_turn_start.round(3)
        action_end_value = $bot.getDirection()
        expected_value = test.value.abs
        current_value = actionCheck(test.action,body_turn_start,bot.getDirection(),test.value).abs
        result = current_value.round.abs == expected_value.round.abs
      of "turnGunLeft":
        action_start_value = $gun_turn_start.round(3)
        action_end_value = $bot.getGunDirection()
        expected_value = test.value.abs
        current_value = actionCheck(test.action,gun_turn_start,bot.getGunDirection(),test.value).abs
        result = current_value.round.abs == expected_value.round.abs
      of "turnGunRight":
        action_start_value = $gun_turn_start.round(3)
        action_end_value = $bot.getGunDirection()
        expected_value = test.value.abs
        current_value = actionCheck(test.action,gun_turn_start,bot.getGunDirection(),test.value).abs
        result = current_value.round.abs == expected_value.round.abs
      of "turnRadarLeft":
        action_start_value = $radar_turn_start.round(3)
        action_end_value = $bot.getRadarDirection()
        expected_value = test.value.abs
        current_value = actionCheck(test.action,radar_turn_start,bot.getRadarDirection(),test.value).abs
        result = current_value.round.abs == expected_value.round.abs
      of "turnRadarRight":
        action_start_value = $radar_turn_start.round(3)
        action_end_value = $bot.getRadarDirection()
        expected_value = test.value.abs
        current_value = actionCheck(test.action,radar_turn_start,bot.getRadarDirection(),test.value).abs
        result = current_value.round.abs == expected_value.round.abs
      of "forward":
        action_start_value = "(" & $x_start.toInt & "," & $y_start.toInt & ")"
        action_end_value = "(" & $bot.getX().toInt & "," & $bot.getY().toInt & ")"
        expected_value = test.value.abs
        current_value = actionCheck(test.action,@[x_start, y_start],@[bot.getX(), bot.getY()],test.value).round.abs
        result = current_value.round.abs == expected_value.round.abs
      of "back":
        action_start_value = "(" & $x_start.toInt & "," & $y_start.toInt & ")"
        action_end_value = "(" & $bot.getX().toInt & "," & $bot.getY().toInt & ")"
        expected_value = test.value.abs
        current_value = actionCheck(test.action,@[x_start, y_start],@[bot.getX(), bot.getY()],test.value).round.abs
        result = current_value.round.abs == expected_value.round.abs

      # write the results
      csvResults.writeLine($bot.getRoundNumber() & "|" & $starting_turn & "|" & $bot.getTurnNumber() & "|" & test.action & "|" & $test.value & "|" & action_start_value & "|" & action_end_value & "|" & $expected_value & "|" & $current_value & "|" & $(current_value - expected_value) & "|" & $result)

      for i in 0..60:
        sleep(1)
        go bot

  # close the file
  csvResults.close()

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
  echo "[TestBot ERR] Connection error:", error
  echo "[TestBot ERR] server url used:",bot.serverConnectionURL
  echo "[TestBot ERR] secret used:",bot.secret

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