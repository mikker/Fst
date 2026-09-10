#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
tag="${1:?Usage: Scripts/release.sh v1.2.3}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected tag vX.Y.Z' >&2; exit 1; }
repo=mikker/Fst
[[ "$(git rev-parse HEAD)" == "$(git rev-list -n 1 "$tag")" ]] || { echo 'Checkout the release tag first' >&2; exit 1; }
mkdir -p dist
latest="$(gh release view -R "$repo" --json tagName --jq .tagName 2>/dev/null || true)"
# Published archives are immutable. A retry only repairs the tap from release assets.
if [[ "$(gh release view "$tag" -R "$repo" --json isDraft --jq .isDraft 2>/dev/null || true)" == false ]]; then
  [[ "$latest" == "$tag" ]] || { echo "Cannot republish an older version to Homebrew" >&2; exit 1; }
  gh release download "$tag" -R "$repo" -p fst.rb -D dist --clobber
  exit 0
fi
python3 - "$tag" "$latest" <<'PY'
import sys
version = lambda s: tuple(map(int, s.removeprefix('v').split('.')))
if sys.argv[2] and version(sys.argv[1]) <= version(sys.argv[2]):
    raise SystemExit('Release version must be greater than the current latest release')
PY
Scripts/package-release.sh "${tag#v}"
if ! gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  gh release create "$tag" -R "$repo" --verify-tag --draft --title "Fst ${tag#v}" --generate-notes
fi
gh release upload "$tag" -R "$repo" dist/Fst.app.zip dist/appcast.xml dist/fst.rb --clobber
gh release edit "$tag" -R "$repo" --draft=false --latest
