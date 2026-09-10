#!/bin/zsh
set -eu
cd "${0:A:h:h}"
test_dir=$(mktemp -d /tmp/Fst-tests.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT
sources=(Fst/*.swift)
sources=(${sources:#Fst/MyApp.swift})
swiftc -O FstQuickLook/PreviewText.swift "${sources[@]}" Tests/main.swift -o "$test_dir/tests"
"$test_dir/tests"
