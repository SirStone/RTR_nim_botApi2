# Package

version       = "0.0.1"
author        = "SirStone"
description   = "Version2 of this library, for nim2.0"
license       = "GPL-3.0-only"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"

# Robocode Tank Royale Version/Tag
let RTR_Version = "v0.19.3"

# Robocode Tank Royale git repo
let RTR_git = "https://github.com/robocode-dev/tank-royale.git"

# Tasks

# before build we need to download the Robocode Tank Royale git repo
before build:
  echo("Robocode Tank Royale Version: ",RTR_Version)
  
  # Check if the Robocode Tank Royale git repo of the RTR_Version is cloned in the 'assets' folder
  let RTR_git_folder = "assets/tank-royale"
  if not fileExists(RTR_git_folder & "/README.md"):
    # Cloning Robocode Tank Royale git repo...
    exec "git clone " & RTR_git & " " & RTR_git_folder
  else:
    echo("Robocode Tank Royale git repo already cloned")

    # check if the RTR_Version is already checked out
    let (current_tag, errCode) = gorgeEx "cd " & RTR_git_folder & " && git describe --tag"
    if errCode == 0:
      if current_tag == RTR_Version:
        echo("Robocode Tank Royale git repo already checked out to the version " & RTR_Version)
      else:
        echo("Robocode Tank Royale git repo already cloned but not checked out to the version " & RTR_Version)
        echo("Current tag: ", current_tag)
        echo("RTR_Version: ", RTR_Version)
        echo("Switching the repo to the RTR_Version tag")
        exec "cd " & RTR_git_folder & " && git checkout tags/" & RTR_Version
    else:
      echo("Error code: ", errCode)