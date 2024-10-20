#!/bin/sh

# Get the directory and base name of the script
script_dir=$(dirname "$0")
script_name=$(basename "$0")

# create ENVs if provided
print_usage() {
  printf "Usage: [-u IP:PORT] [-s BOT-SECRET]"
}

while getopts 'u:s:' flag; do
  case "${flag}" in
    u) export SERVER_URL="${OPTARG}" ;;
    s) export SERVER_SECRET="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

# if no ENVs provided, use default
if [ -z "$SERVER_URL" ]; then
  export SERVER_URL="ws://localhost:7654"
fi

if [ -z "$SERVER_SECRET" ]; then
  export SERVER_SECRET="botSecret"
fi

# print ENVs
echo "SERVER_URL: $SERVER_URL"
echo "SERVER_SECRET: $SERVER_SECRET"

# Remove the extension from the file name
bot_name=${script_name%.*}

$script_dir/$bot_name