#!/bin/bash
set -euo pipefail
: "${DEVELOPER_ID_P12:?Missing DEVELOPER_ID_P12}"
: "${DEVELOPER_ID_PASSWORD:?Missing DEVELOPER_ID_PASSWORD}"
: "${NOTARY_APPLE_ID:?Missing NOTARY_APPLE_ID}"
: "${NOTARY_PASSWORD:?Missing NOTARY_PASSWORD}"
keychain="$RUNNER_TEMP/fst-signing.keychain-db"
password="$(openssl rand -base64 32)"
echo "::add-mask::$password"
certificate="$RUNNER_TEMP/fst-certificate.p12"
trap 'rm -f "$certificate"' EXIT
printf '%s' "$DEVELOPER_ID_P12" | base64 --decode > "$certificate"
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$certificate" -P "$DEVELOPER_ID_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" login.keychain-db
security default-keychain -d user -s "$keychain"
xcrun notarytool store-credentials FstCI --apple-id "$NOTARY_APPLE_ID" --password "$NOTARY_PASSWORD" --team-id "$NOTARY_TEAM_ID" --keychain "$keychain"
