import RTR_nim_botApi2/[Message, Bot]

export Message, Bot


proc start*(bot:Bot) =
  echo "Starting bot..."

  run bot