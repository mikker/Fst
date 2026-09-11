set dotenv-load := true

project := "Fst.xcodeproj"
scheme := "Fst"
derived_data := "build/dd"
app := justfile_directory() + "/" + derived_data + "/Build/Products/Debug/Fst.app"

# Build the local Debug app.
default: build

# List available Xcode schemes and targets.
list:
  xcodebuild -list -project {{project}}

# Build without requiring a signing certificate for local development.
build:
  Scripts/agent-build.sh build -project {{project}} -scheme {{scheme}} -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Build the optimized app used for performance measurements.
build-release:
  Scripts/agent-build.sh build -project {{project}} -scheme {{scheme}} -configuration Release -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

# Run the native editor and lexer regression checks.
test:
  Scripts/test.sh

# Build and test before considering a change ready.
check: build test

# Rebuild, quit the previous local app normally, and run it in the foreground.
run: build kill
  '{{app}}/Contents/MacOS/Fst'

# Open the existing Debug build, optionally with files (no rebuild).
[positional-arguments]
launch *files:
  open -a '{{app}}' "$@"

# Ask the local Debug app to quit, preserving save prompts.
kill:
  Scripts/quit.sh '{{app}}'

# Measure five Release launches; fail if any takes >= 1 second.
benchmark: build-release
  python3 Scripts/benchmark-launch.py

# Remove Xcode build products while retaining build logs.
clean:
  Scripts/agent-build.sh clean -project {{project}} -scheme {{scheme}} CODE_SIGNING_ALLOWED=NO

# Open the project in Xcode.
open:
  open '{{project}}'

# Show the last 80 lines of the newest build log.
log-tail:
  #!/bin/zsh
  logs=(build/xcodebuild/*.log(Nom))
  if (( ${#logs} )); then
    tail -n 80 "$logs[1]"
  else
    print 'No build logs yet.'
  fi

# Generate deterministic source fixtures, from 64 KiB to 50 MiB.
fixtures:
  python3 Scripts/generate-fixtures.py

# Record native open/edit/scroll/RSS measurements; optional --compare baseline.json.
[positional-arguments]
profile *args: fixtures
  Scripts/build-profiler.sh
  python3 Scripts/profile.py "$@"

# Record an Instruments Time Profiler trace for one fixture.
profile-trace fixture="ten-mib.swift": fixtures
  Scripts/build-profiler.sh
  Scripts/profile-trace.sh {{quote(fixture)}}

# Register the embedded Quick Look extension after a signed local build.
quicklook-register: build-signed
  pluginkit -a '{{app}}/Contents/PlugIns/FstQuickLook.appex'
  pluginkit -e use -i com.mikker.Fst.QuickLook
  pluginkit -m -v -i com.mikker.Fst.QuickLook

# Build with the project's development signing settings for Quick Look testing.
build-signed:
  Scripts/agent-build.sh build -project {{project}} -scheme {{scheme}} -configuration Debug -destination 'platform=macOS'

# Open a Finder-style Quick Look preview using the registered extension.
quicklook-preview file="build/fixtures/small.swift": fixtures quicklook-register
  qlmanage -p {{quote(file)}}

# Build, sign, and notarize locally, then publish to GitHub and update Homebrew.
release version:
  Scripts/release.sh {{quote(version)}}
