# unit test library
import unittest

# other libraries
import std/[os, osproc, random, threadpool, strutils, terminal, math]
import ws, asyncdispatch, jsony

# import the API
import ../src/RTR_nim_botApi2

type
  RunnerConfig = object
    botName: string
    serverConnectionURL: string
    botSecret: string
    initialPosition: InitialPosition
  
  Test = object
    action:string
    value:float

# global variables
var
  serverProcess:Process
  port:string = "7654"
  serverConnectionURL:string = "ws://localhost:"&port

let
  assets_version = "0.22.0"
  botSecret = "testBotSecret"
  controllerSecret = "testControllerSecret"
  possible_actions = @["turnLeft", "turnRight", "turnGunLeft", "turnGunRight", "turnRadarLeft", "turnRadarRight", "forward", "back"]
  # possible_actions = @["forward", "back"]
  numberOfTests = 10

proc createTheTests():seq[Test] =
  var testsToDo = newSeq[Test]()
  randomize()

  for i in 1..numberOfTests:
    # sample a random action
    let action = possible_actions[rand(0..possible_actions.high)]

    # sample a random value
    var value = rand(-360.0..360.0).round(4)

    if action == "forward" or action == "back":
      value = rand(-100.0..100.0).round(4)
    
    testsToDo.add(Test(action:action, value:value))

  # write the tests on the file for the bot
  let fileName = "../bin/tests/TestBot/testsToDo.csv"
  
  # remove the old file if it exists
  removeFile(fileName)

  # create the new test file in append mode
  var csv = open(fileName, fmAppend)

  # write the header
  csv.setFilePos(0)
  csv.writeLine("action|value")

  # write the tests
  for test in testsToDo:
    csv.writeLine(test.action & "|" & $(test.value) )
  # custom tests
  csv.writeLine("turnMod|90")
  csv.writeLine("turnRadarTo|0")

  csv.close()
  return testsToDo
  
proc runTankRoyaleServer() =
  echo "[runTankRoyaleServer] running server"
  try:
    randomize()
    port = $rand(1_000..65_535)
    serverConnectionURL = "ws://localhost:"&port
    let serverArgs = ["-jar", "robocode-tankroyale-server-"&assets_version&".jar", "--bot-secrets", botSecret, "--controller-secrets", controllerSecret, "--port", port, "--enable-initial-position"]
    serverProcess = startProcess(command="java", workingDir="../assets/RTR", args=serverArgs, options={poUsePath, poParentStreams, poEchoCmd})
  except CatchableError:
    echo "error with the server:", getCurrentExceptionMsg()

proc testServerIsRunning():bool =
  try:
    let ws = waitFor newWebSocket(serverConnectionURL)
    ws.close()
    return true
  except CatchableError:
    return false
    
# proc runBooter(bot:string) =
#   echo "[runBooter] running booter"
#   try:
#     let booterArgs = ["-jar", "robocode-tankroyale-booter-"&assets_version&".jar", "boot", bot]
#     booterProcess = startProcess(command="java", workingDir="../assets/RTR", args=booterArgs, options={poUsePath, poParentStreams, poEchoCmd})
#   except CatchableError:
#     echo "error with the booter:", getCurrentExceptionMsg()

# proc countTo(n:int) =
#   echo "[countTo] ",n
#   sleep(1_000)
#   for i in 1..n:
#     echo n-i
#     sleep(1_000)

proc runBot(config:RunnerConfig) {.thread.} =
  # let bot = newBot(config.botName&"/"&config.botName&".json")
  # bot.setConnectionParameters(config.serverConnectionURL, config.botSecret)
  # bot.startBot(position=config.initialPosition)

  echo "[runBot] running bot ", config
  try:
    let run_command = "../bin/tests/"&config.botName&"/"&config.botName&".sh -u "&config.serverConnectionURL&" -s "&config.botSecret
    discard startProcess(command=run_command, options={poUsePath, poParentStreams, poStdErrToStdOut, poEchoCmd, poEvalCommand})
  except CatchableError:
    echo "error with ", config.botName, ":", getCurrentExceptionMsg()

proc buildBot(botName:string) =
  echo "[buildBot] building ", botName
  try:
    let botArgs = ["build.sh"]
    discard execProcess(command="sh", workingDir=botName, args=botArgs, options={poUsePath})
  except CatchableError:
    echo "error with ", botName, ":", getCurrentExceptionMsg()

# proc actionCheck(actionType:string, value_start:seq[float], value_end:seq[float], expected:float):float =
#   echo "[TEST] ",actionType,"_start: [x:",value_start[0],",y:",value_start[1],"]"
#   echo "[TEST] ",actionType,"_end: [x:",value_end[0],",y:",value_end[1],"]"
#   return sqrt((value_end[0] - value_start[0]).pow(2) + (value_end[1] - value_start[1]).pow(2))

# proc actionCheck(actionType:string, value_start:float, value_end:float, expected:float):float =
#   echo "[TEST] ",actionType,"_start: ",value_start
#   echo "[TEST] ",actionType,"_end: ",value_end

#   case actionType:
#   of "turnLeft":    
#     result = value_end - value_start
#   of "turnRight":
#     result = value_start - value_end
#   of "turnGunLeft":
#     result = value_end - value_start
#   of "turnGunRight":
#     result = value_start - value_end
#   of "turnRadarLeft":
#     result = value_end - value_start
#   of "turnRadarRight":
#     result = value_start - value_end
#   else:
#     result = 0

#   if expected >= 0:
#     if result < 0: result = result + 360.0
#   else:
#     if result > 0: result = result - 360.0

proc controller(testsToDo:seq[Test]) {.async.} =
  try:
    var ws = await newWebSocket(serverConnectionURL)
    echo "[controller] CONNECTED"

    proc connect() {.async.} =
      # open file for tests results
      let fileNameResults = "../bin/tests/TestBot/testsResults.csv"
      
      # remove the old file if it exists
      removeFile(fileNameResults)

      # create the new test file
      var csvResults = open(fileNameResults, fmAppend)

      # write the header
      csvResults.setFilePos(0)
      csvResults.writeLine("ROUND|ACTION|ACTION_START_VALUE|ACTION_END_VALUE|EXPECTED_VALUE|VALUE|OUTCOME")

      # some variables
      var
        currentTestIndex = 0
        botId = 0
        body_turn_start:float = -1
        gun_turn_start:float = -1
        radar_turn_start:float = -1
        x_start:float = -1
        y_start:float = -1

      # Loops while socket is open, looking for messages to read
      while ws.readyState == Open:
        # this blocks
        var packet = await ws.receiveStrPacket()

        if packet.isEmptyOrWhitespace(): continue

        let message = json2schema packet

        case message.`type`:
        of serverHandshake:
          let server_handshake = (ServerHandshake) message
          let controller_handshake = ControllerHandshake(`type`:Type.controllerHandshake, sessionId:server_handshake.sessionId, name:"Controller from test_all", version:"2.0.0", author:"SirStone", secret:controllerSecret)
          await ws.send(controller_handshake.toJson)
        of botListUpdate:
          let bot_list_update = (BotListUpdate) message
          stdout.write "[controller] bot list update:"
          for bot in bot_list_update.bots:
            stdout.write " ", bot.name
          stdout.write "\n"

          if bot_list_update.bots.len == 2:
            echo "[controller] bot list reached 2 bots..starting game"
            var botAddresses:seq[BotAddress] = @[]
            for bot in bot_list_update.bots:
              botAddresses.add( BotAddress(host:bot.host, port:bot.port) )

            let gameSetup = readFile("gameSetup.json").fromJson(GameSetup)

            let start_game = StartGame(`type`:Type.startGame, botAddresses:botAddresses, gameSetup:gameSetup)
            await ws.send(start_game.toJson)
        of gameStartedEventForObserver:
          let game_started_event_for_observer = (GameStartedEventForObserver) message
          echo "[controller] GAME STARTED"
          
          # search for the TestBot id
          for participant in game_started_event_for_observer.participants:
            if participant.name == "TEST BOT":
              botId = participant.id

        of roundStartedEvent:
          # let round_started_event = (RoundStartedEvent) message
          echo "[controller] ROUND STARTED"
          stdout.hideCursor()

          # reset some variables
          body_turn_start = -1
          gun_turn_start = -1
          radar_turn_start = -1
          x_start = -1
          y_start = -1
          currentTestIndex = 0

        of roundEndedEventForObserver:
          # let round_ended_event = (RoundEndedEventForObserver) message
          echo "[controller] ROUND ENDED"
          stdout.showCursor()
        of gameEndedEventForObserver:
          # let game_ended_event = (GameEndedEventForObserver) message
          echo "[controller] GAME ENDED"
          ws.close()
        of gameAbortedEvent:
          echo "[controller] GAME ABORTED"
          ws.close()
        of tickEventForObserver: discard
          # let tick_event_for_observer = (TickEventForObserver) message
          # if currentTestIndex < testsToDo.len:
          #   for botState in tick_event_for_observer.botStates:
          #     if botState.id == botId:
          #       if body_turn_start == -1:
          #         body_turn_start = botState.direction
          #       else:
          #         body_turn_end = botState.direction

          #       if gun_turn_start == -1:
          #         gun_turn_start = botState.gunDirection
          #       else:
          #         gun_turn_end = botState.gunDirection

          #       if radar_turn_start == -1:
          #         radar_turn_start = botState.radarDirection
          #       else:
          #         radar_turn_end = botState.radarDirection

          #       if x_start == -1:
          #         x_start = botState.x
          #       else:
          #         x_end = botState.x

          #       if y_start == -1:
          #         y_start = botState.y
          #       else:
          #         y_end = botState.y

          #       break # no need to check other bots

          #   var turn_start_value, turn_end_value, x_start_value, x_end_value, y_start_value, y_end_value:float
          #   let current_test = testsToDo[currentTestIndex]
          #   var isXY = false
          #   case current_test.action:
          #   of "turnLeft":
          #     turn_start_value = body_turn_start
          #     turn_end_value = body_turn_end
          #   of "turnRight":
          #     turn_start_value = body_turn_start
          #     turn_end_value = body_turn_end
          #   of "turnGunLeft":
          #     turn_start_value = gun_turn_start
          #     turn_end_value = gun_turn_end
          #   of "turnGunRight":
          #     turn_start_value = gun_turn_start
          #     turn_end_value = gun_turn_end
          #   of "turnRadarLeft":
          #     turn_start_value = radar_turn_start
          #     turn_end_value = radar_turn_end
          #   of "turnRadarRight":
          #     turn_start_value = radar_turn_start
          #     turn_end_value = radar_turn_end
          #   of "forward":
          #     x_start_value = x_start
          #     y_start_value = y_start
          #     x_end_value = x_end
          #     y_end_value = y_end
          #     isXY = true
          #   of "back":
          #     x_start_value = x_start
          #     y_start_value = y_start
          #     x_end_value = x_end
          #     y_end_value = y_end
          #     isXY = true

          #   if tick_event_for_observer.turnNumber == current_test.turn_end:
          #     var csv_start_value, csv_end_value:string
          #     var diff:float
          #     if isXY: 
          #       diff = actionCheck(current_test.action,@[x_start_value, y_start_value],@[x_end_value, y_end_value],current_test.value)
          #       csv_start_value = "x:" & $x_start_value & " y:" & $y_start_value
          #       csv_end_value = "x:" & $x_end_value & " y:" & $y_end_value
          #     else:
          #       diff = actionCheck(current_test.action,turn_start_value,turn_end_value,current_test.value)
          #       csv_start_value = $turn_start_value
          #       csv_end_value = $turn_end_value
          #     let outcome = diff.round.abs == current_test.value.round.abs
          #     check outcome

          #     # write results to file
          #     csvResults.writeLine($tick_event_for_observer.roundNumber & "|" & current_test.action & "|" & csv_start_value & "|" & csv_end_value & "|" & $current_test.value.abs & "|" & $diff.abs & "|" & $outcome)

          #     body_turn_start = body_turn_end
          #     gun_turn_start = gun_turn_end
          #     radar_turn_start = radar_turn_end
          #     x_start = x_end
          #     y_start = y_end
              
          #     currentTestIndex = currentTestIndex + 1
          # else:
          #   if tick_event_for_observer.turnNumber > testsToDo[testsToDo.high].turn_end:
          #     # echo "[controller] all tests done"

          #     # csvResults.close()
          #     let stop_game = StopGame(`type`:Type.stopGame)
          #     await ws.send(stop_game.toJson)

          # for key,botState in tick_event_for_observer.botStates:
          #   stdout.write key,":",botState.energy, " "
          # stdout.write "\n"
          # stdout.cursorUp(1)
        else:
          echo "[controller] received unknown message: ", packet

    # start a async fiber thingy
    await connect()

  except CatchableError:
    echo "[controller] QUIT or ERROR: ", getCurrentExceptionMsg()

suite "Life of a bot":
  # build the bots before running the tests
  buildBot "TestBot"
  buildBot "SittinDuck"
  
  # setup:
  #   echo "run before each test"
    
  # teardown:
  #   echo "run after each test"

  test "creating a new bot":
    # create a new bot
    let bot = newBot("TestBot/TestBot.json")
    
    # some checks
    check bot != nil
    check bot.name == "TEST BOT"
    check bot is Bot

  test "Run server and join it":
    # create a new set of tests
    let testsToDo = createTheTests()

    # start the server
    runTankRoyaleServer()

    # checks
    check(not serverProcess.isNil and serverProcess.running)

    # wait for the server to start completely
    var maxWait = 10_000
    var currentWait = 0
    while not testServerIsRunning() and currentWait < maxWait:
      sleep(1)
      currentWait += 1

    # build and spawn the bots
    let testBotConfig = RunnerConfig(botName:"TestBot", serverConnectionURL:serverConnectionURL, botSecret:botSecret, initialPosition:InitialPosition(x:400,y:300,angle:0))
    spawn runBot(testBotConfig)

    # spawn a new SittinDuck bot
    let sittinDuckConfig = RunnerConfig(botName:"SittinDuck", serverConnectionURL:serverConnectionURL, botSecret:botSecret, initialPosition:InitialPosition(x:0,y:0,angle:90))
    spawn runBot(sittinDuckConfig)

    # start a controller in async mode
    waitFor controller(testsToDo)

    # countTo 5

    echo "killing server"
    # kill processes
    while serverProcess.running:
      sleep(1)
      serverProcess.kill()