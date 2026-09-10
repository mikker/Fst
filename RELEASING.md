# Releases

Run `just release 0.1.1` from a clean, up-to-date `main` checkout. Like Moves, releases run on your Mac using your existing Keychain credentials. The command tests, builds a universal app, signs with Developer ID, notarizes and staples it, signs the ZIP with Sparkle, creates a version tag, publishes the GitHub release and appcast, and updates `mikker/homebrew-tap`.

You need Xcode 26+, Python 3.11+, `gh`, GitHub SSH access, your Developer ID Application identity, the `TunaNotary` notarization profile, and Fst’s Sparkle key (Keychain account `com.mikker.Fst`). These are already configured on this Mac. Override `NOTARYTOOL_PROFILE` to use another profile. No GitHub Actions secrets are required. CI only builds and tests pull requests and main.

Release versions are `X.Y.Z` and must increase. The supplied version sets both app version fields. Packaging completes before the tag is pushed. ZIP and appcast assets are uploaded to a draft and published together; published archives are never replaced. Run the same command again to retry a failed release or finish a failed tap update. Do not move published tags.

The tap update uses a temporary checkout and your normal SSH credentials, leaving your existing tap checkout untouched. Keep a secure backup of the Sparkle key and renew the Developer ID certificate before expiry.

`Scripts/package-release.sh 0.1.1` builds and notarizes without publishing. Output is in ignored `dist/`.

Sparkle’s feed is the `appcast.xml` asset of the latest GitHub release; no Pages deployment or separate appcast repository is needed.
