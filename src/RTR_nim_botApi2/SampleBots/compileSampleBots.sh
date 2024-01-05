# This script compiles all the sample bots in the SampleBots directory.

# if the first argument is "--run" botTocompile must be empty, otherwise it will be the first argument
if [ "$1" = "--run" ]; then
    botToCompile=""
else
    botToCompile="$1"
fi

# some checks
if [ -n "$botToCompile" ]; then
    # If the bot to compile is specified, check if it exists
    if [ ! -d "$botToCompile" ]; then
        echo "The bot to compile doesn't exists"
        exit 1
    fi
    # If the bot to compile is specified, check if the bot.nim file exists
    if [ ! -f "$botToCompile/$botToCompile.nim" ]; then
        echo "The bot.nim file doesn't exists"
        exit 1
    fi
    # If the bot to compile is specified, check if the bot.json file exists
    if [ ! -f "$botToCompile/$botToCompile.json" ]; then
        echo "The bot.json file doesn't exists"
        exit 1
    fi
    # If the bot to compile is specified, check if the bot.sh file exists
    if [ ! -f "$botToCompile/$botToCompile.sh" ]; then
        echo "The bot.sh file doesn't exists"
        exit 1
    fi
fi


run=false
# check if the flag "--run" in any position exists
if [[ "$@" =~ "--run" ]]; then
    run=true
fi

# compile funzion to call for each bot
compileBot() {
    botName=$(basename "$1")
    echo "Compiling $botName"
    sampleBotOutputDir="../../../bin/SampleBots/$botName"
    mkdir -p "$sampleBotOutputDir"
    # nim c -d:danger --outDir:"$sampleBotOutputDir" "./$botName/$botName.nim" #for release 
    nim c --outDir:"$sampleBotOutputDir" "./$botName/$botName.nim" #for debug
    
    # GOING FORWARD ONLY IF COMPILE IS OK
    if [ $? -eq 0 ]; then
        cp "./$botName/$botName.json" "$sampleBotOutputDir"
        cp "./$botName/$botName.sh" "$sampleBotOutputDir"
        chmod +x "$sampleBotOutputDir/$botName.sh"

        if [ "$run" = true ]; then
            echo "Running $botName"
            cd "$sampleBotOutputDir"

            if [[ "$@" =~ "--background" ]]; then
                bash "$botName.sh" &
            else
                bash "$botName.sh"
            fi
            cd -
        fi
    fi
}

if [ -n "$botToCompile" ]; then
    # If the bot to compile is specified, compile only that bot
    compileBot "$botToCompile"
else
    # If the bot to compile is not specified, compile all bots
    for bot in */; do
        compileBot "$bot" --background
    done
fi