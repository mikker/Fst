# Releases

Versions are `X.Y`, bumped by 0.1 each release. User-visible changes go in `CHANGELOG.md` under `## Unreleased` as they land, written for users; the `fst-release` skill in `.agents/skills` reviews the delta, the docs and those notes before a release.

Run `just release` from a clean `main` that matches `origin/main` (or `just release 1.0` to pick the version). Releases run on your Mac using your existing Keychain credentials. The command runs the tests, renames `## Unreleased` to `## 0.3`, commits and pushes `Release 0.3`, builds a universal app, signs it with Developer ID, notarizes and staples it, signs the ZIP with Sparkle, writes `dist/appcast.xml` with the `## 0.3` section of the changelog, rendered by GitHub, as the notes the update window shows, writes the cask, tags `v0.3`, creates a draft GitHub release whose notes are that same section, uploads the ZIP, the appcast and the cask, publishes it as latest, and updates `mikker/homebrew-tap` through a temporary clone. Running it again without adding commits reuses the `Release 0.3` commit and retries a failed release or tap update; a published archive is never replaced. Do not move published tags.

You need Xcode 26+, Python 3.11+, `gh`, GitHub SSH access, your Developer ID Application identity, the `TunaNotary` notarization profile, and Fst’s Sparkle key (Keychain account `com.mikker.Fst`). These are already configured on this Mac. Override `NOTARYTOOL_PROFILE` to use another profile. No GitHub Actions secrets are required. CI only builds and tests pull requests and main.

`Scripts/package-release.sh 0.3` builds and notarizes without publishing; it needs a `## 0.3` section in `CHANGELOG.md` for the appcast. Output is in ignored `dist/`.

Sparkle’s feed is the `appcast.xml` asset of the latest GitHub release; no Pages deployment or separate appcast repository is needed. Keep a secure backup of the Sparkle key and renew the Developer ID certificate before expiry.
