# SampleBots
I'm planning to recreate all the Sample Bots from Robocode Tank Royale using Nim and my library.

If all the Sample bots work as expected will be a proof that my API is working and ready for the world

The script `compileSampleBots.sh` will compile all valid Sample Bots in the folder src/RTR_nim_botApi2/SampleBots.

Can be run passing a single bot name as an argument to compile only that bot. example: `compileSampleBots.sh Target`.

If `--run` is passed as an argument the script will compile and run the Sample Bots (or the single bot) instead of just compiling them. Example: `compileSampleBots.sh Target --run`.
