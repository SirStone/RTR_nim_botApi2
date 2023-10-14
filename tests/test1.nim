# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[os, times]
import unittest
import json

import RTR_nim_botApi2

suite "RTR_bim_api tests":
  test "Can convert JSON message to native NIM object":
    # dumpAstGen:
    #   type
    #     MessageTest* = ref object of RootObj
    #       sessionId*:string
    #       `type`*:string
    #       pippo*:string = "pluto"

    let json_message = """{"sessionId":"7vh2reL+TaeyXxEnN4Ngbg","name":"Robocode Tank Royale server","variant":"Tank Royale","version":"0.17.4","gameTypes":["classic","1v1"],"type":"ServerHandshake"}"""
    # let message:Message = RTR_nim_botApi2.json2message(json_message)
    # assert message.`type` == "ServerHandshake"
    # assert message.pippo == "pluto"

    let message:Message = RTR_nim_botApi2.json2message(json_message)

    check(message.`type` is Type)
    check(message.`type` == Type.serverHandshake)

  test "JSONY method used is faster than JSON":
    let json_message = """{"sessionId":"7vh2reL+TaeyXxEnN4Ngbg","name":"Robocode Tank Royale server","variant":"Tank Royale","version":"0.17.4","gameTypes":["classic","1v1"],"type":"ServerHandshake"}"""

    let times = 10
    # jsony
    var startt_jsony = cpuTime()
    for i in 1..times:
      discard RTR_nim_botApi2.json2message(json_message)
    var endt_jsony = cpuTime() - startt_jsony

    # json
    var startt_json = cpuTime()
    for i in 1..times:
      discard parseJson(json_message)
    var endt_json = cpuTime() - startt_json

    check(endt_jsony < endt_json)

    let percent = 100 * endt_jsony / endt_json
    echo "JSONY method is " & $percent & "% times faster than standard JSON"

  test "Bot creation":
    var testBot = Bot.conf("../../tests/TestBot/TestBot.json")
    startBot testBot
    logout testBot,"Bot created and started"
    check testBot.intent.stdOut == "Bot created and started\n"
    logerr testBot,"FAKE ERROR"
    check testBot.intent.stdErr == "FAKE ERROR\n"

method run(bot:Bot) =
  logout bot,"Running bot " & bot.name
  check bot.name == "TestBot"
  check bot.authors[0] == "SirStone"

  bot.secret = "secret"

  check bot.secret == "secret"

  echo "Running bot"
  go bot
  var i = 1
  while bot.running:
    sleep 1000
    echo "Running...",i
    go bot
    i += 1