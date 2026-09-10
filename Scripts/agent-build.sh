#!/usr/bin/env bash
set -eo pipefail

if [ $# -eq 0 ]; then
  echo "usage: $(basename "$0") <xcodebuild args...>" >&2
  exit 64
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$repo_root/build"
derived_data="$build_dir/dd"
log_dir="$build_dir/xcodebuild"
mkdir -p "$log_dir"

timestamp="$(date +%Y-%m-%d-%H-%M-%S)"
action="$1"
safe_action="$(printf '%s' "$action" | tr -c '[:alnum:]-' '_')"
log_stub="$(mktemp "$log_dir/xcodebuild-${safe_action}-${timestamp}.XXXXXX")"
log_file="$log_stub.log"
mv "$log_stub" "$log_file"

use_xcsift=0
if command -v xcsift >/dev/null 2>&1; then
  use_xcsift=1
fi

set +e
if [ "$use_xcsift" -eq 1 ]; then
  xcsift_args=(--format toon)
  if [ "$action" != "test" ]; then
    xcsift_args+=(--quiet)
  fi

  xcodebuild -derivedDataPath "$derived_data" "$@" 2>&1 \
    | tee "$log_file" \
    | xcsift "${xcsift_args[@]}"

  pipe_status=("${PIPESTATUS[@]}")
  xcodebuild_exit="${pipe_status[0]}"
  xcsift_exit="${pipe_status[2]}"
  exit_code="$xcodebuild_exit"
  if [ "$xcodebuild_exit" -eq 0 ] && [ "$xcsift_exit" -ne 0 ]; then
    echo "Warning: xcsift formatting failed (exit code: $xcsift_exit); xcodebuild succeeded." >&2
  fi
else
  xcodebuild -derivedDataPath "$derived_data" "$@" &> "$log_file"
  exit_code=$?
fi
set -e

echo "xcodebuild output saved to: $log_file"
if [ $exit_code -eq 0 ]; then
  echo "Status: SUCCESS"
else
  echo "Status: FAILED (exit code: $exit_code)"
  if [ "$use_xcsift" -ne 1 ]; then
    echo "Last 40 log lines:"
    tail -n 40 "$log_file" | sed 's/^/  /'
  fi
fi

echo "Tip: tail -n 40 $log_file"
exit $exit_code
