# interaction between threads
This should describe what I think should be (or help me find out) the best way to implement the Bot Library interaction with the user code and the game server.

```mermaid
sequenceDiagram
    participant SERVER
    participant LIB
    activate SERVER
    Note over BOT: the user starts the bot <br> by activating the library
    activate BOT

    BOT->>LIB: start(json)
    deactivate BOT

    activate LIB
    Note over LIB: connection with the server
    Note over LIB: listening for events <br> from the server

    SERVER--)LIB: roundStarted-event
    activate LIB

    LIB--)BOT: onRoundStarted(event)
    activate BOT
    deactivate BOT

    LIB--)THREAD: create a new thread
    deactivate LIB
    activate THREAD

    THREAD->>BOT: run()
    activate BOT
    
    loop Every turn/tick <br> loops indefenitely while bot is RUNNING
        BOT->>LIB:go()
        activate LIB
        LIB--)SERVER: bot intent
        Note over LIB: wait until NEXT_TURN before returning
        LIB->>BOT: Go() return
        deactivate LIB
    end


    BOT->>THREAD: run() return
    deactivate BOT

    loop Every turn/tick <br> loops definitely while bot is RUNNING
        THREAD->>LIB: Go()
        activate LIB
        LIB--)SERVER: bot intent
        Note over LIB: wait until NEXT_TURN before returning
        LIB->>THREAD: Go() return
        deactivate LIB
    end
    deactivate THREAD    
    Note over THREAD: @bot is NOT RUNNING<br>EXIT

    SERVER--)LIB: tick-event (NEXT_TURN arrived)

    SERVER--)LIB: bot-death-event <br> won-round-event <br> game-aborted-event <br> game-ended-event <br> round-ended-event
    LIB--)BOT: onDeath(event) <br> onRoundWon(event) <br> onGameAborted(event) <br> onGameEnded(event) <br> onRoundEnded(event)
    activate BOT
    deactivate BOT
    Note over LIB: all these end the bot RUNNING

    opt Generic event
        SERVER--)LIB: generic-event
        LIB--)BOT: onGenericMethod(generic-event)
        activate BOT
    deactivate BOT
    end

    deactivate LIB
    deactivate SERVER

    Note over LIB: @any moment<br>as the connection is lost<br>the bot will leave the game and will close
```
