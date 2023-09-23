import std/[macros, sugar]
import jsony

macro gen_message*(): untyped = 
  result = nnkStmtList.newTree()

  var typeSection = nnkTypeSection.newTree()

  var typeDef = nnkTypeDef.newTree()
  var postfix = nnkPostfix.newTree()
  postfix.add newIdentNode("*")
  postfix.add newIdentNode("Message")
  typeDef.add postfix
  typeDef.add newEmptyNode()

  var refTy = nnkRefTy.newTree()
  var objectTy = nnkObjectTy.newTree()
  objectTy.add newEmptyNode()
  objectTy.add nnkOfInherit.newTree(newIdentNode("RootObj"))
  var recList = nnkRecList.newTree()
  var identDefs = nnkIdentDefs.newTree()
  postfix = nnkPostfix.newTree()
  postfix.add newIdentNode("*")
  postfix.add newIdentNode("sessionId")
  identDefs.add postfix
  identDefs.add newIdentNode("string")
  identDefs.add newEmptyNode()
  recList.add identDefs
  
  identDefs = nnkIdentDefs.newTree()
  postfix = nnkPostfix.newTree()
  postfix.add newIdentNode("*")
  postfix.add nnkAccQuoted.newTree(newIdentNode("type"))
  identDefs.add postfix
  identDefs.add newIdentNode("string")
  identDefs.add newEmptyNode()
  recList.add identDefs

  identDefs = nnkIdentDefs.newTree()
  postfix = nnkPostfix.newTree()
  postfix.add newIdentNode("*")
  postfix.add newIdentNode("pippo")
  identDefs.add postfix
  identDefs.add newIdentNode("string")
  identDefs.add newLit("pluto")
  recList.add identDefs

  objectTy.add recList
  refTy.add objectTy
  typeDef.add refTy
  typeSection.add typeDef
  result.add typeSection

  hint("AST-->",result)
  
gen_message()

proc json2message*(json_message:string):Message =
  result = json_message.fromJson(Message)
  
