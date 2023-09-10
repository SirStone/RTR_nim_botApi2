# README for the Robocode Tank Royale API written in Nim version 2

Nim 2.0 is out and brings a lot of iprovements to the language. This is a rewrite of the Robocode Tank Royale API written in Nim to take advantage of the new features of the language.

[Nim 2.0 Changes](https://nim-lang.org//blog/2023/08/01/nim-v20-released.html)

## Some diagrams to help understand the architecture of the API

### Contexts

```mermaid
  C4Context
    
    Person_Ext(programmer, "Programmer", "imports the API nim library and uses it to create a bot")

    System(api, "API library in Nim", "Nim library that allows the programmer to create a bot")

    System_Ext(bot, "Bot", "The bot that the programmer creates")

    Boundary(robocode, "Robocode Tank Royale Components", "These are the software provided externnaly that we work with") {
      System_Ext(GUI, "Robocode GUI", "Java program that allows the users to setup battles and watch them")

      System_Ext(robocode, "Robocode Tank Royale", "Java engine of the game")

      System_Ext(booter, "Booter", "Java launcher for the bots")
    }

    Rel(robocode, booter, "use", "system")
    Rel(GUI, robocode, "use", "system")
    Rel(programmer, GUI, "use", "system")
    Rel(bot, api, "import", "Nim")
    Rel(programmer, bot, "code and compile", "Nim")
    BiRel(api, robocode, "interaction", "WebSocket")
```
