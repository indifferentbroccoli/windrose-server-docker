#!/bin/bash

#================
# Log Definitions
#================
export LINE='\n'                        # Line Break
export RESET='\033[0m'                  # Text Reset
export WhiteText='\033[0;37m'           # White

# Bold
export RedBoldText='\033[1;31m'         # Red
export GreenBoldText='\033[1;32m'       # Green
export YellowBoldText='\033[1;33m'      # Yellow
export CyanBoldText='\033[1;36m'        # Cyan
#================
# End Log Definitions
#================

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"

  local src
  src=$(basename "${BASH_SOURCE[-1]}")

  printf "$color%s$RESET$LINE" "[$src] $prefix$message$suffix"
}

install() {
  LogAction "Starting server install"
  LogInfo "Installing Windrose Dedicated Server"

  /depotdownloader/DepotDownloader \
    -app 4129620 \
    -dir /home/steam/server-files \
    -validate

  LogSuccess "Server install complete"
}

# Attempt to shutdown the server gracefully
# Returns 0 if it is shutdown
# Returns 1 if it is not able to be shutdown
shutdown_server() {
  LogAction "Attempting graceful server shutdown"

  local pid
  pid=$(pgrep -x "wineserver" | head -1)
  if [ -z "$pid" ]; then
    LogWarn "Server process is not running"
    return 1
  fi

  # wineserver -k sends SIGINT (triggers shutdown_master_socket()), then SIGKILL,
  # if needed, and returns once wineserver has exited.
  # Must run as the user that owns the wineprefix, so wineserver can find the socket.
  if ! su steam -c 'WINEPREFIX=/home/steam/.wine wineserver -k' > /dev/null 2>&1; then
    LogWarn "wineserver -k returned non-zero"
  fi

  # Sanity check, wineserver should not be alive at this point due to wineserver -k.
  if kill -0 "$pid" 2>/dev/null; then
    LogWarn "wineserver still present after -k"
    return 1
  fi

  LogSuccess "Server shutdown gracefully"
  return 0
}
