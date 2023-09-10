import macros

type
  Message* = ref object of RootObj
    sessionId*:string
    `type`*:string

# macro gen_message(): untyped =
#   le 
