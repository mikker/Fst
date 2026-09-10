#!/bin/zsh
set -eu
cd "${0:A:h:h}"
mkdir -p build/tools
sources=(Fst/*.swift)
sources=(${sources:#Fst/MyApp.swift})
xcrun swiftc -O -g "${sources[@]}" Profiling/main.swift -o build/tools/fst-profile

shasum -a 256 "${sources[@]}" Profiling/main.swift > build/tools/profile-source.sha256
