import std/[os, sugar]
import RTR_nim_botApi2/[Message, Bot]

export Message, Bot


template stdout* (bot:Bot, x:string) =
  stdout.writeLine(x)
  # stdout.flushFile
  bot.intent.stdOut &= x & "\n"

template stderr* (bot:Bot, x:string) =
  stderr.writeLine(x)
  # stderr.flushFile
  bot.intent.stdErr &= x & "\n"

proc go*(bot:Bot) =
  # Sending intent to server
  echo "Sending intent to server"

  # build the intent to send to the game server
  let intent = BotIntent(`type`: Type.botIntent)

  # send the intent to the game server
  echo intent[]

proc botWorker(bot:Bot) {.thread.} =
  # While the bot is connected to the server the bot thread should live
  while bot.connected:
    # First is waiting doing nothing for the bot to be in running state
    while not isRunning(bot) and bot.connected: discard

    # Second run the bot 'run()' method, the one scripted by the bot creator
    # this could be going in loop until the bot is dead or could finish up quckly or could be that is not implemented at all
    run bot

    # Third, when the bot creator's 'run()' exits, if the bot is still runnning, we send the intent automatically
    while isRunning(bot) and bot.connected:
      go bot
  echo "[botWorker]bot is not connected. Bye!"

proc startBot*(bot:Bot, connect:bool = true, position:InitialPosition = InitialPosition(x:0,y:0,angle:0)) =
  ## **Start the bot**
  ## 
  ## This method is used to start the bot instance. This coincide with asking the bot to connect to the game server
  ## 
  ## `bot` is the new and current bot istance
  ## 
  ## `connect` (can be omitted) is a boolean value that if `true` (default) will ask the bot to connect to the game server.
  ## If `false` the bot will not connect to the game server. Mostly used for testing.
  ## 
  ## `position` (can be omitted) is the initial position of the bot. If not specified the bot will be placed at the center of the map.
  ## This custom position will work if the server is configured to use the custom initial positions
  
  # set the initial position, is the server that will decide to use it or not
  bot.initialPosition = position

  # connect to the Game Server
  if(connect):
    if bot.secret == "":
      bot.secret = getEnv("SERVER_SECRET", "serversecret")

    if bot.serverConnectionURL == "": 
      bot.serverConnectionURL = getEnv("SERVER_URL", "ws://localhost:7654")

    # run the bot thread
    # This thread runs untile the bot is disconnected from the server so
    # logically the connection must happen before this point
    var botRunner: Thread[bot.type]
    createThread botRunner, botWorker, bot
    
    # Waiting for the bot thread to finish
    joinThread botRunner
    echo "[startBot]connection ended and bot thread finished. Bye!"
