# ----------------how to start a new bot----------------
import ../../src/RTR_nim_botApi2    # import the bot api
startBot newBot("SittinDuck.json") # start the bot
# --------------end, the rest is up to you--------------

method run(bot:Bot) =
  echo "[",bot.name,"] run started, running for"

  bot.setBodyColor("#32CD32")
  bot.setGunColor("#32CD32")
  bot.setRadarColor("#32CD32")
  bot.setBulletColor("#32CD32")
  bot.setScanColor("#32CD32")
  bot.setTracksColor("#32CD32")
  bot.setTurretColor("#32CD32")

method onConnect(bot:Bot) =
  echo  "[",bot.name,"] I'm connected! Yuppy!"

method onConnectionError(bot:Bot, error:string) =
  echo "[",bot.name,"]Connection error:", error
  echo "[",bot.name,"] server url used:",bot.serverConnectionURL
  echo "[",bot.name,"] secret used:",bot.secret