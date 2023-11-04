#!/bin/bash

test_selector="Life of a bot::*"

# first argument, if present, is the test selector
if [ $# -eq 1 ]; then
  test_selector="$1"
fi

# save script directory name
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# push script directory to cd
pushd $script_dir

# compile and run the test
nim c --outDir:"../bin/tests/" -r test_all "$test_selector"

# exit from pushd
popd