import std/[macros, sugar]
import jsony

macro gen_message*(): untyped = 
  result = newNimNode(nnkTypeSection)
  result.add(newNimNode(nnkTypeDef))
  result[0].add(newNimNode(nnkPostfix))
  result[0].add(ident("*"),ident("Message"))

  hint("AST-->",result)
  
gen_message()

proc json2message*(json_message:string):Message =
  result = json_message.fromJson(Message)

# dumpAstGen:
#   type
#     Message* = ref object of RootObj
#       sessionId*:string
#       `type`*:string
#       pippo*:string = "pluto"
  
