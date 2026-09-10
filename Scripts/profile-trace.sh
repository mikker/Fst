#!/bin/zsh
set -eu
cd "${0:A:h:h}"
fixture=${1:-ten-mib.swift}
[[ -f "build/fixtures/$fixture" ]] || { print -u2 "Unknown fixture: $fixture"; exit 64; }
mkdir -p build/profiles
trace_dir=$(mktemp -d "$PWD/build/profiles/trace.XXXXXX")
xcrun xctrace record --template 'Time Profiler' --output "$trace_dir/time-profiler.trace" \
  --launch -- "$PWD/build/tools/fst-profile" "$PWD/build/fixtures/$fixture" "$trace_dir/metrics.json"
print "Trace: $trace_dir/time-profiler.trace"
