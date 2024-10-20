#!/bin/sh

# Get the directory, base name of the script and name of the bot
script_dir=$(dirname "$0")
script_name=$(basename "$0")
bot_name=$(basename "$(pwd)")

# create ENVs if provided
print_usage() {
  printf "You can force connection parameters with: [-u IP:PORT] [-s BOT-SECRET]"
}

while getopts 'u:s:' flag; do
  case "${flag}" in
    u) export SERVER_URL="${OPTARG}" ;;
    s) export SERVER_SECRET="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [ -z "$SERVER_URL" ]; then
  echo "SERVER_URL is not found"
  print_usage
  exit 1
fi

if [ -z "$SERVER_SECRET" ]; then
  echo "SERVER_SECRET is not found"
  print_usage
  exit 1
fi

echo "Running $bot_name"
echo "SERVER_URL: $SERVER_URL"
echo "SERVER_SECRET: $SERVER_SECRET"

SERVER_URL=$SERVER_URL SERVER_SECRET=$SERVER_SECRET nim c --deepcopy:on --run $script_dir/$bot_name.nim
rm $script_dir/$bot_name 2>/dev/null