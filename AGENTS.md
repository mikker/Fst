# Project notes

Fst is a small native Mac text editor for single files. `Development.md` describes the app, the build (`just`), the tests (`just test`, `just check`) and profiling; `RELEASING.md` describes releases.

## Changelog

- `CHANGELOG.md` covers user-visible changes to the Fst app itself. Omit release tooling, CI, tests, docs, and other repository maintenance unless they change the installed app's behavior.
- Add a brief entry under `## Unreleased` in the same change as the user-facing work. Write it for end users, from their viewpoint: what they can now do or what no longer goes wrong, not how it was implemented.
- Before releasing, review `## Unreleased`, prune anything out of scope, consolidate related entries, and get approval; `just release` renames the section to the version. The `fst-release` skill in `.agents/skills` walks through this.
