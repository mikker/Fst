#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?Usage: Scripts/release.sh 1.2.3}"
version="${version#v}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected version X.Y.Z' >&2; exit 1; }
tag="v$version"
repo=mikker/Fst
mkdir -p dist

update_tap() (
  local checkout
  checkout="$(mktemp -d "${TMPDIR:-/tmp}/fst-tap.XXXXXX")"
  trap 'rm -rf "$checkout"' EXIT
  git clone --quiet --depth 1 git@github.com:mikker/homebrew-tap.git "$checkout"
  cp dist/fst.rb "$checkout/Casks/fst.rb"
  git -C "$checkout" add Casks/fst.rb
  if ! git -C "$checkout" diff --cached --quiet; then
    git -C "$checkout" commit -m "Update Fst to $version"
    git -C "$checkout" pull --rebase
    git -C "$checkout" push
  fi
)

latest="$(gh release view -R "$repo" --json tagName --jq .tagName 2>/dev/null || true)"
# Retry a published release without rebuilding or replacing signed archives.
if [[ "$(gh release view "$tag" -R "$repo" --json isDraft --jq .isDraft 2>/dev/null || true)" == false ]]; then
  [[ "$latest" == "$tag" ]] || { echo 'Cannot republish an older version to Homebrew' >&2; exit 1; }
  gh release download "$tag" -R "$repo" -p fst.rb -D dist --clobber
  update_tap
  exit 0
fi
[[ "$(git branch --show-current)" == main ]] || { echo 'Release from main' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit your changes first' >&2; exit 1; }
git fetch origin main
head="$(git rev-parse HEAD)"
[[ "$head" == "$(git rev-parse origin/main)" ]] || { echo 'Push or pull main first' >&2; exit 1; }
if git rev-parse --verify "$tag" >/dev/null 2>&1; then
  [[ "$head" == "$(git rev-list -n 1 "$tag")" ]] || { echo 'Release tag points to another commit' >&2; exit 1; }
fi
python3 - "$tag" "$latest" <<'PY'
import sys
version = lambda s: tuple(map(int, s.removeprefix('v').split('.')))
if sys.argv[2] and version(sys.argv[1]) <= version(sys.argv[2]):
    raise SystemExit('Release version must be greater than the current latest release')
PY
Scripts/test.sh
Scripts/package-release.sh "$version"
[[ "$head" == "$(git rev-parse HEAD)" && -z "$(git status --porcelain)" ]] || { echo 'Source changed during packaging; retry the release' >&2; exit 1; }
if ! git rev-parse --verify "$tag" >/dev/null 2>&1; then
  git tag -a "$tag" -m "Release $version"
fi
git push origin "$tag"
if ! gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  gh release create "$tag" -R "$repo" --verify-tag --draft --title "Fst $version" --generate-notes
fi
gh release upload "$tag" -R "$repo" dist/Fst.app.zip dist/appcast.xml dist/fst.rb --clobber
gh release edit "$tag" -R "$repo" --draft=false --latest
update_tap
