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

# Remove the extension from the file name
bot_name="VelocityBot"

# nim c -d:release -d:danger --run $script_dir/$bot_name.nim
nim c --run $script_dir/$bot_name.nim
rm $script_dir/$bot_name