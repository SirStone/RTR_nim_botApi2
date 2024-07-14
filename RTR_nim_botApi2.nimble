import streams

# Package
version       = "0.21.3"
author        = "SirStone"
description   = "Version2 of this library, for nim2.0"
license       = "GPL-3.0-only"
srcDir        = "src"
binDir        = "bin"

# Dependencies
requires "nim >= 2.0.0"
requires "jsony >= 0.1.0"
requires "ws >= 0.5.0"
requires "trick >= 0.1.7"

# Robocode Tank Royale Version/Tag
let RTR_Version = "v0.24.1"

# Robocode Tank Royale github repo
let RTR_repo = "robocode-dev/tank-royale"

# Robocode Tank Royale git
let RTR_git = "https://github.com/" & RTR_repo & ".git"

# Robocode Tank Royale API repos
let RTR_api_repos = "https://api.github.com/repos/" & RTR_repo

# Asset folder
let asset_folder = "assets/tank-royale/schema/schemas"

# Schemas.nim folder
let schemas_nim = "src/RTR_nim_botApi2"

# assets2nim bin
let assets2nim_bin_folder = "bin/assets_tools"

# runnable assets folder
let runnable_assets_folder = "assets/RTR"

# server secret for bots
let server_secret = "ciao"

# server port
let server_port = "7654"

# Tasks
task download_asset_tankRoyale, "checks and downloads the asset tank-royale":
  echo("Robocode Tank Royale Version: ",RTR_Version)

  # Check if the 'assets' folder exists
  if not fileExists("assets"):
    exec "mkdir -p assets"
  
  # Check if the Robocode Tank Royale git repo of the RTR_Version is cloned in the 'assets' folder
  let RTR_git_folder = "assets/tank-royale"
  if not fileExists(RTR_git_folder & "/README.md"):
    # Cloning Robocode Tank Royale git repo...
    exec "git clone " & RTR_git & " " & RTR_git_folder

    # Switching the repo to the RTR_Version tag
    let (outStr, errCode) = gorgeEx "cd " & RTR_git_folder & " && git checkout tags/" & RTR_Version
    # echo outStr # uncomeent for debugging
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
        let (outStr, errCode) = gorgeEx "cd " & RTR_git_folder & " && git fetch && git checkout tags/" & RTR_Version
        # echo outStr # uncomeent for debugging
    else:
      echo("Error code: ", errCode)

# task download_asset_schemas, "checks and downloads the asset schemas":
#   echo("Robocode Tank Royale Version: ",RTR_Version)

#   # Dowlete the folder if the folder exists
#   if fileExists(asset_folder):
#     exec "rm -r " & asset_folder

#   # Recreate the empty folder
#   exec "mkdir -p " & asset_folder

#   # Download the schemas from the RTR_api_repos
#   # echo "curl " & RTR_api_repos & "/contents/schema/schemas " & "| grep download_url | cut -d'\"' -f4 >> " & download_list
#   exec "curl " & RTR_api_repos & "/contents/schema/schemas " & "| grep download_url | cut -d'\"' -f4 | xargs wget -q -nH --cut-dirs=4 --directory-prefix=" & asset_folder

#   # Remove all files that don't have the .yaml extension
#   exec "find " & asset_folder & " -type f ! -name '*.yaml' -delete"

task build_schemas, "builds the Schemas.nim file from yaml assets":
  # Make sure that the asset_tools folder exists
  if not fileExists(assets2nim_bin_folder):
    exec "mkdir -p " & assets2nim_bin_folder

  # Compile the schemas2nim.nim file inside the bin folder
  exec "nim c --run -d:release --deepcopy:on --outdir:" & assets2nim_bin_folder & "/schemas2nim src/RTR_nim_botApi2/assets_tools/schemas2nim.nim " & asset_folder & " " & schemas_nim

task download_asset_runnables, "downloads the SERVER, GUI and SampleRobots in the assets/RTR folder":
  # make sure that the assets/RTR folder exists
  if not fileExists(runnable_assets_folder):
    exec "mkdir -p " & runnable_assets_folder

  let version_without_v = RTR_Version.replace("v", "")

  # target files to download
  let
    target_server_file = "robocode-tankroyale-server-" & version_without_v & ".jar"
    target_gui_file = "robocode-tankroyale-gui-" & version_without_v & ".jar"
    target_booter_file = "robocode-tankroyale-booter-" & version_without_v & ".jar"
    target_sample_robots_file = "sample-bots-java-" & version_without_v & ".zip"

  # urls
  let
    repo_url = "https://github.com/robocode-dev/tank-royale/releases/download/" & RTR_Version
    server_url = repo_url & "/" & target_server_file
    gui_url = repo_url & "/" & target_gui_file
    booter_url = repo_url & "/" & target_booter_file
    sample_robots_url = repo_url & "/" & target_sample_robots_file

  # curl commands
  let
    curl_server = "curl --output-dir " & runnable_assets_folder & "  -LJO " & server_url
    curl_gui = "curl --output-dir " & runnable_assets_folder & "  -LJO " & gui_url
    curl_booter = "curl --output-dir " & runnable_assets_folder & "  -LJO " & booter_url
    curl_sample_robots = "curl --output-dir " & runnable_assets_folder & "  -LJO " & sample_robots_url

  # output files
  let
    output_server_file = runnable_assets_folder & "/" & target_server_file
    output_gui_file = runnable_assets_folder & "/" & target_gui_file
    output_booter_file = runnable_assets_folder & "/" & target_booter_file
    output_sample_robots_file = runnable_assets_folder & "/" & target_sample_robots_file

  # remove file if exists
  if fileExists(output_server_file): exec "rm " & output_server_file
  if fileExists(output_gui_file): exec "rm " & output_gui_file
  if fileExists(output_booter_file): exec "rm " & output_booter_file
  if fileExists(output_sample_robots_file): exec "rm " & output_sample_robots_file

  # download the files
  let (outStr_server, errCode_server) = gorgeEx curl_server
  let (outStr_gui, errCode_gui) = gorgeEx curl_gui
  let (outStr_booter, errCode_booter) = gorgeEx curl_booter
  let (outStr_sample_robots, errCode_sample_robots) = gorgeEx curl_sample_robots

  # sample bots are zipped, so we need to unzip them
  if errCode_sample_robots == 0:
    # create the folder for the sample bots
    exec "mkdir -p " & runnable_assets_folder & "/sample-bots-java-" & version_without_v

    # unzip the sample bots in the folder
    exec "unzip -q -o " & output_sample_robots_file & " -d " & runnable_assets_folder & "/sample-bots-java-" & version_without_v

    # remove the zip file
    exec "rm " & output_sample_robots_file

task download_asset_all, "downloads all the assets":
  let (tr_output, tr_error) = gorgeEx "nimble download_asset_tankRoyale"
  # let (as_output, as_error) = gorgeEx "nimble download_asset_schemas"
  let (dr_output, dr_error) = gorgeEx "nimble download_asset_runnables"

task run_server, "runs the Robocode Tank Royale server (current version: " & RTR_Version & ")":
  let version_with_v = RTR_Version.replace("v", "")
  let output_server_file = runnable_assets_folder & "/robocode-tankroyale-server-" & version_with_v & ".jar"
  # exec "java -jar " & output_server_file & " -p " & server_port
  # export the server secret
  let (export_output, export_error) = gorgeEx "export SERVER_SECRET=" & server_secret
  echo "export_output: ", export_output

  #export the server url
  exec "export SERVER_URL=ws://localhost:" & server_port

  echo "Server secret: ", server_secret

  # run the server
  exec "java -jar " & output_server_file & " -p " & server_port & " -b " & server_secret

task run_gui, "runs the Robocode Tank Royale GUI (current version: " & RTR_Version & ")":
  let version_with_v = RTR_Version.replace("v", "")
  let output_gui_file = runnable_assets_folder & "/robocode-tankroyale-gui-" & version_with_v & ".jar"
  exec "java -jar " & output_gui_file
  rmFile("config.properties")
  rmFile("server.properties")
  rmFile("games.properties")

# before build we need...
# before build:
  # ...to check and download the asset tank-royale
  # download_asset_tankRoyaleTask() //not required
  # asset_schemasTask() //not required

# before test:
  # asset_schemasTask() //not required