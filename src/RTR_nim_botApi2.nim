import RTR_nim_botApi2/[Message, Bot]

export Message, Bot

proc worker(bot:Bot) {.thread.} =
  run bot

proc start*(bot:Bot) =
  echo "Starting bot..."

  var runner: Thread[bot.type]
  createThread runner, worker , bot

  echo "Bot started and waiting for the end of the run"
  joinThread runner
