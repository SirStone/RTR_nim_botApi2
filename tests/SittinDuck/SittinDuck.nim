# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
startBot("SittinDuck.json") # start the bot
# --------------end, the rest is up to you--------------

method run(bot:Bot) =
  echo "[SittinDuck] run started, running for"

  setBodyColor("#32CD32")
  setGunColor("#32CD32")
  setRadarColor("#32CD32")
  setBulletColor("#32CD32")
  setScanColor("#32CD32")
  setTracksColor("#32CD32")
  setTurretColor("#32CD32")

  while isRunning():
    go()

  echo "[SittinDuck] run ended"

method onConnect(bot:Bot) =
  echo  "[SittinDuck] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[SittinDuck]Connection error:", error
  # echo "[SittinDuck] server url used:",bot.serverConnectionURL
  # echo "[SittinDuck] secret used:",bot.secret