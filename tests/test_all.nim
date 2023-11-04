# unit test library
import unittest

# other libraries
import std/[os, osproc, random, threadpool]
import ws, asyncdispatch

# import the API
import ../src/RTR_nim_botApi2

type
  RunnerConfig = ref object of RootObj
    botName: string
    serverConnectionURL: string
    botSecret: string
    initialPosition: InitialPosition

# global variables
var
  serverProcess:Process
  booterProcess:Process
  port:string = "7654"
  serverConnectionURL:string = "ws://localhost:"&port

let
  assets_version = "0.21.0"
  botSecret = "testBotSecret"
  controllerSecret = "testControllerSecret"

proc runTankRoyaleServer() =
  echo "[runTankRoyaleServer] running server"
  try:
    # randomize()
    # port = $rand(1_000..65_535)
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

proc countTo(n:int) =
  echo "[countTo] ",n
  sleep(1_000)
  for i in 1..n:
    echo n-i
    sleep(1_000)

# proc runTestBot() =
#   echo "[runBot] running TEST BOT"
#   try:
#     let botArgs = ["run.sh", "-u", serverConnectionURL, "-s", botSecret]
#     booterProcess = startProcess(command="sh", workingDir="../tests/TestBot", args=botArgs, options={poUsePath, poParentStreams, poEchoCmd})
#   except CatchableError:
#     echo "error with TEST BOT:", getCurrentExceptionMsg()


proc runBot(config:RunnerConfig) {.thread.} =
  let bot = newBot(config.botName&"/"&config.botName&".json")
  bot.setConnectionParameters(config.serverConnectionURL, config.botSecret)
  bot.startBot(position=config.initialPosition)

proc buildBot(botName:string) =
  echo "[buildBot] building ", botName
  try:
    let botArgs = ["build.sh"]
    discard execProcess(command="sh", workingDir=botName, args=botArgs, options={poUsePath})
  except CatchableError:
    echo "error with ", botName, ":", getCurrentExceptionMsg()

suite "Life of a bot":
  setup:
    echo "run before each test"

  # test "creating a new bot":
  #   buildBot "TestBot"

  #   # create a new bot
  #   let bot = newBot("TestBot/TestBot.json")
    
  #   # some checks
  #   check bot != nil
  #   check bot.name == "TEST BOT"
  #   check bot is Bot

  test "Run server and join it":
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
    buildBot "TestBot"
    let testBotConfig = RunnerConfig(botName:"TestBot", serverConnectionURL:serverConnectionURL, botSecret:botSecret, initialPosition:InitialPosition(x:400,y:300,angle:0))
    spawn runBot(testBotConfig)

    # spawn a new SittinDuck bot
    buildBot "SittinDuck"
    let sittinDuckConfig = RunnerConfig(botName:"SittinDuck", serverConnectionURL:serverConnectionURL, botSecret:botSecret, initialPosition:InitialPosition(x:0,y:0,angle:0))
    spawn runBot(sittinDuckConfig)

    # sync()

    countTo 10

    echo "killing server"
    # kill processes
    while serverProcess.running:
      sleep(1)
      serverProcess.kill()