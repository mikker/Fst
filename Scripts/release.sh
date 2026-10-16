#!/bin/bash
# Prepares, tests, packages, tags and publishes a GitHub release from a clean, pushed main, then updates the
# cask in mikker/homebrew-tap. Usage: Scripts/release.sh [X.Y]   (run again to retry a failed release)
# Without a version it bumps the latest tag by 0.1. Preparing turns CHANGELOG.md's `## Unreleased` into
# `## X.Y` and commits and pushes "Release X.Y"; a rerun reuses that commit.
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:-}"
version="${version#v}"
repo=mikker/Fst

# Puts dist/fst.rb into the tap through a temporary clone, so a local tap checkout is left alone.
update_tap() (
  local checkout
  checkout="$(mktemp -d "${TMPDIR:-/tmp}/fst-tap.XXXXXX")"
  trap 'rm -rf "$checkout"' EXIT
  git clone --quiet --depth 1 git@github.com:mikker/homebrew-tap.git "$checkout"
  cp dist/fst.rb "$checkout/Casks/fst.rb"
  git -C "$checkout" add Casks/fst.rb
  if ! git -C "$checkout" diff --cached --quiet; then
    git -C "$checkout" commit -q -m "Update Fst to $version"
    git -C "$checkout" pull -q --rebase
    git -C "$checkout" push -q
  fi
  echo "==> tap: Fst $version"
)

# Prints the body of a `## ` section of CHANGELOG.md, without surrounding blank lines.
changelog_section() {
  awk -v heading="## $1" '
    $0 == heading { found = 1; next }
    found && /^## / { exit }
    found { print }
  ' CHANGELOG.md | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}'
}

[[ "$(git branch --show-current)" == main ]] || { echo 'Release from main' >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo 'Commit your changes first' >&2; exit 1; }
git fetch -q origin main
latest="$(gh release view -R "$repo" --json tagName --jq .tagName 2>/dev/null || true)"

prepared="$(git log -1 --format=%s | sed -n 's/^Release \([0-9][0-9]*\.[0-9][0-9]*\)$/\1/p')"
if [[ -n "$prepared" ]]; then
  [[ -z "$version" || "$version" == "$prepared" ]] || { echo "HEAD prepares $prepared, not $version" >&2; exit 1; }
  version="$prepared"
  if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
    [[ "$(git rev-parse HEAD^)" == "$(git rev-parse origin/main)" ]] || { echo 'Push or pull main first' >&2; exit 1; }
    git push -q origin HEAD:main
  fi
else
  [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo 'Push or pull main first' >&2; exit 1; }
  if [[ -z "$version" ]]; then
    last="$(git tag --list 'v*' --sort=-v:refname | head -1)"
    [[ -n "$last" ]] || { echo 'No v* tag to bump; pass a version' >&2; exit 1; }
    version="$(python3 -c 'import sys; m, n = sys.argv[1][1:].split(".")[:2]; print(f"{m}.{int(n) + 1}")' "$last")"
  fi
fi
[[ "$version" =~ ^[0-9]+\.[0-9]+$ ]] || { echo 'Expected version X.Y' >&2; exit 1; }
tag="v$version"
if [[ -n "$latest" && "$latest" != "$tag" ]]; then
  python3 - "$tag" "$latest" <<'PY'
import sys
v = lambda s: tuple(int(x) for x in s.removeprefix('v').split('.'))
if v(sys.argv[1]) <= v(sys.argv[2]): raise SystemExit(f'{sys.argv[1]} is not newer than the latest release {sys.argv[2]}')
PY
fi

if [[ -z "$prepared" ]]; then
  [[ "$(grep -cx '## Unreleased' CHANGELOG.md || true)" == 1 ]] || { echo 'CHANGELOG.md needs one ## Unreleased section' >&2; exit 1; }
  [[ -n "$(changelog_section Unreleased)" ]] || { echo 'The ## Unreleased section of CHANGELOG.md is empty' >&2; exit 1; }
  git rev-parse --verify -q "$tag" >/dev/null && { echo "Tag $tag already exists" >&2; exit 1; }
  echo "==> Testing before preparing $version"
  Scripts/test.sh
  sed -i '' "s/^## Unreleased\$/## $version/" CHANGELOG.md
  git commit -q -m "Release $version" CHANGELOG.md
  git push -q origin HEAD:main
  echo "==> Prepared and pushed Release $version"
fi

head="$(git rev-parse HEAD)"
if git rev-parse --verify -q "$tag" >/dev/null; then
  [[ "$head" == "$(git rev-list -n 1 "$tag")" ]] || { echo "Tag $tag points to another commit" >&2; exit 1; }
fi
mkdir -p dist
changelog_section "$version" > dist/release-notes.md
[[ -s dist/release-notes.md ]] || { echo "CHANGELOG.md has no notes under ## $version" >&2; exit 1; }

# A published release only gets its tap update retried; its archive is never replaced.
if [[ "$(gh release view "$tag" -R "$repo" --json isDraft --jq .isDraft 2>/dev/null || true)" == false ]]; then
  [[ "$latest" == "$tag" ]] || { echo "$tag is already published and is not the latest release" >&2; exit 1; }
  gh release download "$tag" -R "$repo" -p fst.rb -D dist --clobber
  update_tap
  exit 0
fi

[[ -n "$prepared" ]] && Scripts/test.sh
Scripts/package-release.sh "$version"
[[ "$head" == "$(git rev-parse HEAD)" && -z "$(git status --porcelain)" ]] || { echo 'Source changed during packaging; retry' >&2; exit 1; }

git rev-parse --verify -q "$tag" >/dev/null || git tag -a "$tag" -m "Release $version"
git push origin "$tag"
if gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
  gh release edit "$tag" -R "$repo" --notes-file dist/release-notes.md
else
  gh release create "$tag" -R "$repo" --verify-tag --draft --title "Fst $version" --notes-file dist/release-notes.md
fi
gh release upload "$tag" -R "$repo" dist/Fst.app.zip dist/appcast.xml dist/fst.rb --clobber
gh release edit "$tag" -R "$repo" --draft=false --latest
echo "==> https://github.com/$repo/releases/tag/$tag"
update_tap
