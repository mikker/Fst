# Releases

Push a version tag, or run `just release 0.1.0` from a clean, up-to-date `main` checkout. The GitHub **Release** workflow runs the native tests, builds a universal app, signs with Developer ID, notarizes and staples it, signs the ZIP with Sparkle, publishes a GitHub release and appcast, and updates `mikker/homebrew-tap`.

Release versions are `X.Y.Z` and must increase. The tag determines both app version fields. The ZIP and appcast are published together from a draft; published archives are never replaced. Use **Run workflow** with the same tag to retry a failed release or finish a failed tap update. Do not move published tags. CI builds pull requests and main without release credentials.

## Credentials

Actions secrets on `mikker/Fst`:

- `DEVELOPER_ID_P12`: base64-encoded Developer ID Application identity.
- `DEVELOPER_ID_PASSWORD`: password protecting that identity.
- `NOTARY_APPLE_ID` and `NOTARY_PASSWORD`: Apple ID and app-specific notarization password for team `DDB8SQMXS9`.
- `SPARKLE_PRIVATE_KEY`: Fst’s Ed25519 key. Its public key is in `Fst/Info.plist`. Keep this key stable across releases.
- `HOMEBREW_TAP_SSH_KEY`: deploy key with write access only to `mikker/homebrew-tap`.

The certificate is imported into a temporary runner keychain, removed after the job. Secrets are never needed for pull request checks. Renew the Developer ID certificate before expiry; keep a secure backup of the Sparkle key (also stored locally under the `com.mikker.Fst` keychain account).

## Local verification

`Scripts/package-release.sh 0.1.0` builds and notarizes without publishing, using the `TunaNotary` keychain profile and Fst’s Sparkle key. Override `NOTARYTOOL_PROFILE` as needed. Output is in ignored `dist/`. This requires Xcode 26 or newer, Python 3.11+, a Developer ID identity, and notarization credentials.

The updater initializes after the initial window display. Its feed is the `appcast.xml` asset of the latest GitHub release; no Pages deployment or separate appcast repository is needed.
