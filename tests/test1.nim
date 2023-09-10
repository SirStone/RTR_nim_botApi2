# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/[macros,strutils]
import unittest, yaml

import RTR_nim_botApi2

test "Can convert JSON message to native NIM object":
  let json_message = """{"sessionId":"7vh2reL+TaeyXxEnN4Ngbg","name":"Robocode Tank Royale server","variant":"Tank Royale","version":"0.17.4","gameTypes":["classic","1v1"],"type":"ServerHandshake"}"""
  let message:Message = RTR_nim_botApi2.json2message(json_message)
  assert message.`type` == "ServerHandshake"
  assert message.pippo == "pluto"
  # RTR_nim_botApi2.hello()

# test "Playing with macros":
#   for line in lines "assets/tank-royale/schema/schemas/server-handshake.yaml":
#     let exploded_line = line.split(":")
#     echo $exploded_line

