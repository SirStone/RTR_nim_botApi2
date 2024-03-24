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
    u) export SERVER_URL="ws://${OPTARG}" ;;
    s) export SERVER_SECRET="${OPTARG}" ;;
    *) print_usage
       exit 1 ;;
  esac
done

# Remove the extension from the file name
bot_name=${script_name%.*}

compiled_file="$script_dir/$bot_name"
source_file="$script_dir/$bot_name.nim"

# Check that the compiled_file exists
if [ ! -f "$compiled_file" ]; then
  # Check that the source_file exists
  if [ ! -f "$source_file" ]; then
    echo "Error: nor the compiled file nor the source file exists. exiting..."
    echo "Compiled file: $compiled_file"
    echo "Source file: $source_file"
    exit 1
  else
    # run the file from source
    nim c -r -d:release $source_file
    rm $compiled_file
  fi
else
  # compiled file exists, run it
  $compiled_file
fi
