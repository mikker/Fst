#!/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <app path>" >&2
  exit 64
fi

[ -d "$1" ] || exit 0

# AppleScript targets this build by its absolute path. Never force-terminate an
# editor: cancellation of a save prompt must also cancel `just run`.
app_path="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
osascript - "$app_path" <<'APPLESCRIPT'
on run argv
    set appPath to item 1 of argv
    if application appPath is running then
        tell application appPath to quit
        repeat 100 times
            if not (application appPath is running) then return
            delay 0.1
        end repeat
        error "Fst is still running. Finish or cancel the save dialog before relaunching."
    end if
end run
APPLESCRIPT
