# Fst

A small native Mac editor for individual files. Requires macOS 14 or later.

Open the Xcode project and run the Fst scheme. The window is just an AppKit text view: no project model, sidebar, web view, language server, linting, plugins, or network dependencies.

- New, Open, Save, Save As, Revert, and standard document close/quit protection.
- Native undo/redo, clipboard, selection, Find and Replace (⌘⌥F).
- Monospaced text, horizontal scrolling, and indentation carried onto new lines.
- Separate light/dark palettes, font family and size, and line-height percentage, and optional line wrapping in Settings (⌘,).
- Line numbers and a status bar with language selection, cursor position, encoding, line endings, and line count.
- UTF-8 and BOM-marked UTF-16, preserving byte order, BOM, and existing line endings. New lines follow the file's CRLF convention. Invalid encodings and binary data are rejected instead of decoded lossily.

## Custom themes

Fst supports VS Code color-theme `.json` and `.jsonc` files. In Settings, click **Open Themes Folder**, copy theme files there, then click **Reload Themes**. Choose each custom theme independently in the light and dark appearance menus. Opening Settings also refreshes the list. Edit a theme in Fst and reload to see changes in open editors.

Themes live in the app’s Application Support directory under `Fst/Themes`. In the sandboxed build this is `~/Library/Containers/com.mikker.Fst/Data/Library/Application Support/Fst/Themes`; the Settings button opens the correct location. Theme files remain the source of truth. Missing or invalid selected themes fall back to a built-in palette, with errors shown in Settings.

Supported colors: editor background/foreground, cursor, selection (including alpha), line numbers, and basic `tokenColors` for comments, strings, keywords/storage, and numeric constants. JSON comments and trailing commas are accepted. Relative `include` files are supported inside the Themes folder (up to eight levels, 2 MiB per file). Copy any included files alongside the theme. Themes are cached; built-in themes do not scan this folder during launch.

Fst maps general TextMate scopes in VS Code themes to its four token categories. Language/context-specific scopes, semantic tokens, font styles, extension bundles, and external `.tmTheme` references are not supported. Use the JSON color-theme file from an extension, or VS Code’s **Developer: Generate Color Theme from Current Settings** command to export one.

## Settings

Open **Fst → Settings…** (⌘,) to choose separate light/dark palettes, a font and size, or a line-height percentage (80–240%). Enable **Wrap lines to window width** to wrap long lines without changing file contents; wrapping is off by default. Changes apply immediately to open editors. You can also click **Make Fst the Default Editor**. The button sets the default app for supported code file extensions. Browser documents such as HTML and SVG, prose formats, and generic text files are excluded. Types already assigned to Fst are skipped. macOS may request consent for each remaining type; its current API provides no batch-confirmation option. The window reports partial failures and stops if you cancel a system prompt. Associations change only when you click the button.

The list follows the highlighter's programming and configuration extensions. Extensionless files, markup-only formats, generic data, and video types are excluded; TypeScript uses its text type even though `.ts` is also a video extension. Imported type declarations cover formats macOS does not otherwise recognize.

## Editor controls

The gutter numbers logical lines, including a final empty line. An incremental UTF-16 index keeps caret lookup fast and rescans only lines around edits; suffix offsets are adjusted after insertions/deletions. Columns count UTF-16 code units and tabs count as one, as noted in the status tooltip.

The language menu defaults to automatic filename detection. Select a language to override highlighting for that window, or choose Automatic again. The encoding and line-ending indicators are informational; changing syntax does not convert or modify file contents.

## Quick Look

Fst embeds a native, sandboxed Quick Look preview extension covering the same declared text/source types as the editor, including SVG. Previews show selectable, highlighted source text and follow system appearance. They use default preview typography, independent of the main app's settings. Files larger than 1 MiB get an explicitly truncated preview; the extension reads only the prefix and preserves complete Unicode scalars.

```sh
just quicklook-register                    # Signed build, register, and enable the extension
just quicklook-preview path/to/source.go   # Preview through Quick Look
```

Finder can then preview supported files with Space. Quick Look uses macOS content-type resolution; competing providers and ambiguous extensions (notably `.ts`) can affect provider selection. Fst deliberately registers text/source types rather than taking over video or generic data. The development signing commands use the Xcode project's configured team and require a matching local certificate. Unsigned build commands remain available for ordinary editor development; rebuild/register the signed extension after an unsigned Debug build before testing Finder integration.

## Highlighting

A small stateful lexer recognizes common extensions: Swift, C/C++, Objective-C, C#, Java, Kotlin, Scala, Go, Rust, JavaScript/TypeScript, Python, Ruby, shells, PHP, Dart, Elixir, R, Perl, PowerShell, SQL, Lua, Haskell, HTML/XML/SVG, CSS/SCSS, Vue/Svelte, Markdown, JSON, YAML, TOML, and configuration files. It also recognizes common extensionless filenames such as Dockerfile, Makefile, and Gemfile. Unknown files remain plain text.

This is basic lexical highlighting, not full language grammars. Keyword vocabulary is shared; embedded languages, regex literals, heredocs, nested comments, and language-specific raw strings are not fully modeled. Markdown currently gets string/comment/number coloring, not heading/emphasis styling.

Highlighting starts after window creation. It scans approximately 8K UTF-16 units per batch, retains multiline lexical state, yields between batches, and cancels stale work after edits. Edits restart at the preceding checkpoint and recolor the remaining suffix. Temporary layout attributes keep highlighting out of saved text and undo history. File text is held in memory; this is not a memory-mapped huge-file editor.

## Performance

See [Profiling/README.md](Profiling/README.md) for generated large-file fixtures, repeatable open/edit/scroll/RSS measurements, baseline comparisons, and Instruments traces. Start with `just profile`; results are retained under `build/profiles`. The initial baseline records the known 10 MiB single-line JSON timeout rather than hiding it.

## Local development

Requires Xcode with its command-line tools selected, `just`, and Python 3. Optional `xcsift` formats Xcode output; raw logs are always retained.

```sh
just                 # Build Debug (the default recipe)
just run             # Build, quit the previous local app, and launch
just launch          # Launch the existing Debug build
just launch file.py  # Open a file in the local build
just test            # Native editor and lexer regression checks
just check           # Debug build + tests
just benchmark       # Release build + five timed launches
just open            # Open the project in Xcode
just log-tail        # Read the latest build log
just clean           # Clean build products, retain logs
just --list          # Show all commands
```

Like Spellbook and Snailblaze, `Scripts/agent-build.sh` puts derived data in `build/dd` and timestamped logs in `build/xcodebuild`. Local builds disable code signing, so no development certificate is required. `just kill` requests a normal quit of the local Debug app; it never force-kills an editor with unsaved work. A cancelled quit also stops `just run`.

The test harness runs directly through `Scripts/test.sh` because this project has no Xcode test target. The benchmark can also be run directly with `python3 Scripts/benchmark-launch.py [path-to-binary]`; its default is this repository's Release build.

Tests exercise chunk-boundary equivalence, Unicode, encoding/BOM round trips, binary rejection, document dirty tracking, undo, CRLF indentation, and recoloring after edits. They also report a 1 MiB document's read-to-initial-layout duration.

The launch benchmark disables window restoration for its processes, starts five separate Release processes, and measures process spawn to the first editor's display callback. It includes an opt-in main-to-display timestamp. The benchmark fails if any sample takes one second or longer. It terminates only the processes it starts; run it without making edits in those benchmark windows.

Initial local measurement: 264–506 ms, median 278 ms. This is a local repeated-launch measurement with warm filesystem caches, not a cold-boot, Finder/Gatekeeper, or arbitrary-file-size guarantee. Use Instruments and representative files for further startup, responsiveness, and memory profiling.
