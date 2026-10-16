#!/bin/bash
# Write dist/notes.md (Markdown) and dist/notes.html (GitHub-rendered) for a release.
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?Usage: Scripts/release-notes.sh v0.2 [previous-tag]}"
previous="${2:-}"
mkdir -p dist
{
  git log --format='- %s' "${previous:+$previous..}${tag}" 2>/dev/null || git log --format='- %s' "${previous:+$previous..}HEAD"
  if [[ -n "$previous" ]]; then
    echo
    echo "**Full Changelog**: https://github.com/mikker/Fst/compare/$previous...$tag"
  fi
} > dist/notes.md
gh api /markdown -f mode=gfm -f context=mikker/Fst -F text=@dist/notes.md > dist/notes.html
