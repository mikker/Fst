---
name: fst-release
description: Review Fst changes, docs, and changelog notes since the last release, then publish with `just release`.
---

# Fst release

`RELEASING.md` is the canonical release procedure; read it before publishing.

## Readiness

Review the delta from the newest `v*` tag:

```bash
git log --format='%h %s%n%b' "$(git tag --list 'v*' --sort=-v:refname | head -1)"..origin/main
git diff --stat "$(git tag --list 'v*' --sort=-v:refname | head -1)"..origin/main
```

Include local commits that are not yet pushed, and ask before pushing them.

Review the documentation against the delta, not just the changelog. For every changed behavior,
menu item, shortcut, setting, default, and file type, check `README.md` and `Development.md` and fix
stale text before release. Docs come before the changelog and before approval: don't draft release
notes for a change the docs don't describe yet. Commit doc fixes along with the changelog, and in the
approval question list each doc you checked and what you changed (or "no change needed").

Run `just check`. Open GitHub issues closed by the delta should be mentioned in the notes where that
helps a user recognise their report.

## Changelog

`CHANGELOG.md` must have an accurate `## Unreleased` section for the delta. Write it as end-user
release notes: user-visible effects from the user's viewpoint, no implementation details, nothing
purely internal (release tooling, refactors, tests, doc reorganizations). Bullets may accumulate
during development; before approval, consolidate them into short, direct bullets, grouped under `###`
headings by area only when there are enough to need it, with fixes last under `### Fixes`. Put a plain
upgrade note first when the user must do something after updating, such as clicking Make Default
again.

## Approval

Show the final `## Unreleased` section verbatim with the version it will ship as, and get approval for
that concrete release unless it was already given in this conversation for the same version and notes.
Ask again only if the version or notes materially change. Put the notes in the approval question itself,
since text before the question may not be visible while the user answers. A readiness review alone
does not authorize publication.

## Publish

```bash
just release          # latest tag + 0.1
just release 1.0      # explicit version
```

Start from a clean local `main` that exactly matches `origin/main`. The command tests, turns
`## Unreleased` into `## X.Y`, commits and pushes `Release X.Y`, then packages, notarizes, tags,
publishes the GitHub release with that changelog section as its notes and as the embedded Sparkle
notes, and updates the Homebrew tap. After a failure, rerun the same command without adding commits;
it reuses the prepared commit. Signing and notarization need the local keychain, so run it on the
release Mac.
