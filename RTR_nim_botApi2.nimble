import streams

# Package
version       = "0.0.1"
author        = "SirStone"
description   = "Version2 of this library, for nim2.0"
license       = "GPL-3.0-only"
srcDir        = "src"

# Dependencies
requires "nim >= 2.0.0"
requires "yaml >= 0.1.0"
requires "jsony >= 1.1.3"

# Robocode Tank Royale Version/Tag
let RTR_Version = "v0.19.3"

# Robocode Tank Royale github repo
let RTR_repo = "robocode-dev/tank-royale"

# Robocode Tank Royale git
let RTR_git = "https://github.com/" & RTR_repo & ".git"

# Robocode Tank Royale API repos
let RTR_api_repos = "https://api.github.com/repos/" & RTR_repo

# Tasks
task asset_tankRoyale, "checks and downloads the asset tank-royale":
  echo("Robocode Tank Royale Version: ",RTR_Version)
  
  # Check if the Robocode Tank Royale git repo of the RTR_Version is cloned in the 'assets' folder
  let RTR_git_folder = "assets/tank-royale"
  if not fileExists(RTR_git_folder & "/README.md"):
    # Cloning Robocode Tank Royale git repo...
    exec "git clone " & RTR_git & " " & RTR_git_folder

    # Switching the repo to the RTR_Version tag
    exec "cd " & RTR_git_folder & " && git checkout tags/" & RTR_Version
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

        # Switching the repo to the RTR_Version tag
        exec "cd " & RTR_git_folder & " && git checkout tags/" & RTR_Version
    else:
      echo("Error code: ", errCode)

task asset_schemas, "checks and downloads the asset schemas":
  echo("Robocode Tank Royale Version: ",RTR_Version)

  # Check if the Robocode Tank Royale schemas version is present in the 'assets' folder
  let asset_folder = "assets/schemas"
  
  # Make sure that the asset folder exists
  if not fileExists(asset_folder):
    exec "mkdir -p " & asset_folder

  if not fileExists(asset_folder & "/README.md"):
    # name of the file containing the list of the files to download
    let download_list = asset_folder & "/download_list.txt"

    # make sure the download list is empty
    exec "echo '' > " & download_list

    # Getting the file lists of the schamas folder from the Robocode Tank Royale git repo
    echo "curl " & RTR_api_repos & "/contents/schema/schemas " & "| grep download_url | cut -d'\"' -f4 >> " & download_list

# before build we need...
before build:
  # ...to check and download the asset tank-royale
  # asset_tankRoyaleTask()
  asset_schemasTask()