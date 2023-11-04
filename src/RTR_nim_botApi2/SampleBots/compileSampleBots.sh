# This script compiles all the sample bots in the SampleBots directory.

# For each bot directory in the src SampleBots directory, compile the bot.nim file ina corresponding directory in the bin SampleBots directory
for botDir in $(ls -d */); do
    botName=$(basename "$botDir")
    sampleBotOutputDir="../../../bin/SampleBots/$botName"
    mkdir -p "$sampleBotOutputDir"
    nim c -d:release --outDir:"$sampleBotOutputDir" "./$botName/$botName.nim"
    
    # GOING FORWARD ONLY IF COMPILE IS OK
    if [ $? -eq 0 ]; then
        cp "./$botName/$botName.json" "$sampleBotOutputDir"
        cp "./$botName/$botName.sh" "$sampleBotOutputDir"
        chmod +x "$sampleBotOutputDir/$botName.sh"
    fi
done