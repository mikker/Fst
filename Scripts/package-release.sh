#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?Usage: Scripts/package-release.sh 1.2.3}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected version X.Y.Z' >&2; exit 1; }
# Sparkle compares numeric versions; use the release version as the build version too.
mkdir -p dist
Scripts/agent-build.sh archive -project Fst.xcodeproj -scheme Fst -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$PWD/build/Fst.xcarchive" \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$version" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Developer ID Application' \
  ONLY_ACTIVE_ARCH=NO
xcodebuild -exportArchive -archivePath build/Fst.xcarchive -exportPath build/export \
  -exportOptionsPlist Scripts/ExportOptions.plist
app="$PWD/build/export/Fst.app"
codesign --verify --deep --strict "$app"
for arch in arm64 x86_64; do lipo "$app/Contents/MacOS/Fst" -verify_arch "$arch"; done
ditto -c -k --sequesterRsrc --keepParent "$app" dist/notary.zip
xcrun notarytool submit dist/notary.zip --wait --keychain-profile "${NOTARYTOOL_PROFILE:-TunaNotary}" \
  --output-format json > dist/notary-result.json
python3 -c 'import json; d=json.load(open("dist/notary-result.json")); assert d["status"] == "Accepted", d'
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute "$app"
rm -f dist/Fst.app.zip
ditto -c -k --sequesterRsrc --keepParent "$app" dist/Fst.app.zip
signer=build/dd/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$signer" --ed-key-file - -p dist/Fst.app.zip > dist/signature.txt
else
  "$signer" --account com.mikker.Fst -p dist/Fst.app.zip > dist/signature.txt
fi
python3 Scripts/release-metadata.py "$version"
