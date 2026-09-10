import AppKit
import UniformTypeIdentifiers

let launchStarted = ProcessInfo.processInfo.systemUptime

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

func colors(_ text: String, filename: String, budget: Int) -> [SyntaxLexer.Kind?] {
    let source = text as NSString
    var result = [SyntaxLexer.Kind?](repeating: nil, count: source.length)
    var offset = 0
    var state = SyntaxLexer.State.normal
    while offset < source.length {
        let chunk = SyntaxLexer.scan(source, from: offset, state: state, language: .detect(filename), budget: budget)
        expect(chunk.end > offset, "Lexer must advance")
        for token in chunk.tokens {
            expect(NSMaxRange(token.range) <= source.length, "Token outside text")
            for i in token.range.location..<NSMaxRange(token.range) { result[i] = token.kind }
        }
        offset = chunk.end
        state = chunk.state
    }
    return result
}

let fixtures = [
    ("test.swift", "let emoji = \"🐢\"\n/* a\n comment */\nfunc f() { return 0xff + 42.3 }"),
    ("test.py", "# comment\ndef greet():\n  return \"\"\"a\nlong string\"\"\"\n"),
    ("test.html", "<!-- long comment -->\n<div title=\"hello\">Hi</div>"),
    ("test.js", "const text = `multiline\ntext`; // hi\nlet value = 123;"),
    ("test.sql", "SELECT 'it\\'s ok' FROM things -- comment\nWHERE id = 1"),
]
for (filename, text) in fixtures {
    let reference = colors(text, filename: filename, budget: 8192)
    for budget in 1...24 { expect(colors(text, filename: filename, budget: budget) == reference, "Chunk boundary changed tokens: \(filename), \(budget)") }
}
expect(Language.detect("notes.txt").plain, "Plain text should stay plain")
expect(Language.detect("Gemfile").hashComments, "Extensionless Ruby detection")

@MainActor
func testDocumentsAndEditing() throws {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let original = "let greeting = \"héllo 🐢\"\r\n"
    for encoding in [String.Encoding.utf8, .utf16] {
        let document = TextDocument()
        let data = original.data(using: encoding)!
        try document.read(from: data, ofType: "Text Document")
        let saved = try document.data(ofType: "Text Document")
        expect(String(data: saved, encoding: encoding) == original, "Encoding round trip")
    }
    let bom = Data([0xEF, 0xBB, 0xBF]) + original.data(using: .utf8)!
    let document = TextDocument()
    try document.read(from: bom, ofType: "Text Document")
    let savedBOM = try document.data(ofType: "Text Document")
    expect(savedBOM == bom, "UTF-8 BOM preservation")
    do {
        try TextDocument().read(from: Data([0, 1, 2, 255]), ofType: "Text Document")
        fatalError("Binary input accepted")
    } catch {}

    document.makeWindowControllers()
    let editor = document.windowControllers[0].contentViewController as! EditorViewController
    let text = editor.textView
    document.windowControllers[0].window?.displayIfNeeded()
    expect(editor.view.bounds.height >= 240, "Editor window must not collapse to the status bar")
    expect(text.enclosingScrollView!.frame.height >= 200, "Text area must have a usable initial height")
    expect(text.selectedRange().location == 0, "Files should open at the first line")
    let editorWindow = document.windowControllers[0].window!
    expect(editorWindow.styleMask.contains(.resizable), "Editor windows must permit resizing")
    for size in [NSSize(width: 1100, height: 800), NSSize(width: 600, height: 400), NSSize(width: 900, height: 680)] {
        editorWindow.setContentSize(size)
        editorWindow.displayIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        expect(editor.view.bounds.size == size, "Editor must keep the requested size after layout")
        expect(text.enclosingScrollView!.frame.height == size.height - 30, "Text area must resize while the status bar keeps its height")
    }

    text.setSelectedRange(NSRange(location: (text.string as NSString).length, length: 0))
    text.insertText("new", replacementRange: text.selectedRange())
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    expect(document.isDocumentEdited, "Typing must mark document dirty")
    expect(text.undoManager?.canUndo == true, "Typing must be undoable")
    text.undoManager?.undo()
    expect(text.string == original, "Undo must restore original text")
    editor.setText("  hello\r\n  world", filename: "test.swift")
    text.setSelectedRange(NSRange(location: (text.string as NSString).length, length: 0))
    text.insertNewline(nil)
    expect(text.string.hasSuffix("world\r\n  "), "Newline must preserve CRLF and indentation")
    print("PASS: chunk boundaries, encodings, binary rejection, document dirty state, undo, indentation")

    let bigEndianData = Data([0xFE, 0xFF]) + original.data(using: .utf16BigEndian)!
    let bigEndianDoc = TextDocument()
    try bigEndianDoc.read(from: bigEndianData, ofType: "Text Document")
    let bigEndianSaved = try bigEndianDoc.data(ofType: "Text Document")
    expect(bigEndianSaved == bigEndianData, "Preserve UTF-16 byte order")

    func waitForHighlighting() {
        let deadline = Date(timeIntervalSinceNow: 2)
        while editor.highlighter.highlightedLength < text.textStorage!.length && Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        expect(editor.highlighter.highlightedLength == text.textStorage!.length, "Highlighting must finish")
    }
    editor.setText("/* comment */ let value = 1", filename: "test.swift")
    waitForHighlighting()
    let layout = text.layoutManager!
    expect(layout.temporaryAttribute(.foregroundColor, atCharacterIndex: 3, effectiveRange: nil) != nil, "Highlight comment")
    text.setSelectedRange(NSRange(location: 0, length: 13))
    text.insertText("", replacementRange: text.selectedRange())
    waitForHighlighting()
    let color = layout.temporaryAttribute(.foregroundColor, atCharacterIndex: 1, effectiveRange: nil) as? NSColor
    expect(color == EditorTheme.current(for: text.effectiveAppearance).keyword, "Rehighlight after deleting comment")
    editor.setLanguage(filename: "notes.txt")
    waitForHighlighting()
    expect(layout.temporaryAttribute(.foregroundColor, atCharacterIndex: 1, effectiveRange: nil) == nil, "Clear coloring for plain text")
    print("PASS: UTF-16 byte order, incremental highlighting, plain text reset")

    let preferenceDocument = TextDocument()
    try preferenceDocument.read(from: Data("let value = 1\n".utf8), ofType: "Text Document")
    preferenceDocument.makeWindowControllers()
    let preferenceEditor = preferenceDocument.windowControllers[0].contentViewController as! EditorViewController
    let preferenceKeys = ["fontName", "fontSize", "lineHeight", "lightTheme", "darkTheme", "wrapLines"]
    let oldPreferences = preferenceKeys.map { UserDefaults.standard.object(forKey: $0) }
    defer {
        for (key, value) in zip(preferenceKeys, oldPreferences) {
            if let value { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        NotificationCenter.default.post(name: .editorPreferencesChanged, object: nil)
    }
    EditorPreferences.fontName = "Menlo"
    EditorPreferences.fontSize = 18
    EditorPreferences.lineHeight = 160
    EditorPreferences.lightTheme = "Snow"
    EditorPreferences.darkTheme = "Graphite"
    expect(preferenceEditor.textView.font?.pointSize == 18, "Font changes apply to open editors")
    expect(preferenceEditor.textView.defaultParagraphStyle?.lineHeightMultiple == 1.6, "Line-height percentage applies")
    expect(!preferenceDocument.isDocumentEdited, "Preferences must not dirty documents")
    let preferenceData = try preferenceDocument.data(ofType: "Text Document")
    expect(preferenceData == Data("let value = 1\n".utf8), "Preferences cannot change saved text")
    let wrappingDocument = TextDocument()
    let wrappingSource = String(repeating: "word ", count: 100) + "\nnext line"
    try wrappingDocument.read(from: Data(wrappingSource.utf8), ofType: "Text Document")
    wrappingDocument.makeWindowControllers()
    let wrappingWindow = wrappingDocument.windowControllers[0].window!
    let wrappingEditor = wrappingDocument.windowControllers[0].contentViewController as! EditorViewController
    let wrappingText = wrappingEditor.textView
    let wrappingLayout = wrappingText.layoutManager!
    func wrappedLineHeight(width: CGFloat) -> CGFloat {
        wrappingWindow.setContentSize(NSSize(width: width, height: 500))
        wrappingWindow.displayIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        wrappingLayout.ensureLayout(for: wrappingText.textContainer!)
        let glyph = wrappingLayout.glyphIndexForCharacter(at: 499)
        return wrappingLayout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
    }
    EditorPreferences.wrapLines = true
    let wideHeight = wrappedLineHeight(width: 900)
    let narrowHeight = wrappedLineHeight(width: 400)
    expect(wideHeight > 0 && narrowHeight > wideHeight, "Long lines wrap and reflow when the window narrows")
    expect(wrappingEditor.lineIndex.count == 2, "Soft wraps must preserve logical line numbers")
    expect(!wrappingText.enclosingScrollView!.hasHorizontalScroller, "Wrapped text doesn't need horizontal scrolling")
    EditorPreferences.wrapLines = false
    expect(wrappedLineHeight(width: 400) == 0, "Disabling wrapping restores a single visual line")
    expect(wrappingText.enclosingScrollView!.hasHorizontalScroller, "Unwrapped text supports horizontal scrolling")
    expect(!wrappingDocument.isDocumentEdited, "Wrapping must not dirty a document")
    let wrappingData = try wrappingDocument.data(ofType: "Text Document")
    expect(wrappingData == Data(wrappingSource.utf8), "Soft wraps must not insert newlines in saved files")
    wrappingWindow.close()
    print("PASS: wrapping, resize reflow, logical line numbers, and unchanged saved text")
    preferenceEditor.languagePicker.selectItem(at: 1)
    preferenceEditor.changeLanguage(preferenceEditor.languagePicker)
    preferenceEditor.setLanguage(filename: "file.swift")
    expect(preferenceEditor.languagePicker.indexOfSelectedItem == 1, "Explicit language overrides survive filename changes")
    expect(!preferenceDocument.isDocumentEdited, "Language selection must not dirty documents")

    let large = String(repeating: "let value = 123 // a line of code\n", count: 32_768)
    let largeDoc = TextDocument()
    let began = ProcessInfo.processInfo.systemUptime
    try largeDoc.read(from: Data(large.utf8), ofType: "Text Document")
    largeDoc.makeWindowControllers()
    largeDoc.windowControllers[0].window?.displayIfNeeded()
    let duration = ProcessInfo.processInfo.systemUptime - began
    print(String(format: "1 MiB document read → initial layout: %.0f ms", duration * 1000))
}

try testDocumentsAndEditing()

let supportedTypes = DefaultEditor.contentTypes
expect(!supportedTypes.contains(.data), "Never claim all data files")
expect(!supportedTypes.contains(.text), "Use specific types, not the broad text parent")
expect(!supportedTypes.contains { $0.conforms(to: .audiovisualContent) }, "Never claim video for .ts")
expect(!supportedTypes.contains(.html) && !supportedTypes.contains(.svg), "Never take over browser document types")
expect(!DefaultEditor.extensions.contains("txt") && DefaultEditor.extensions.contains("swift"), "Limit defaults to code extensions")
expect(Set(supportedTypes).count == supportedTypes.count, "Deduplicate shared content types")

var attempted: [UTType] = []
let partial = await DefaultEditor.register(types: [.plainText, .json, .html], isDefault: { _, _ in false }, setDefault: { _, type in
    attempted.append(type)
    if type == .json { throw CocoaError(.fileWriteNoPermission) }
})
expect(partial.updated == 2 && partial.failures.count == 1, "Report partial failures accurately")
expect(attempted.count == 3, "Continue after a non-cancellation error")
attempted = []
let cancelled = await DefaultEditor.register(types: [.plainText, .json, .html], isDefault: { _, _ in false }, setDefault: { _, type in
    attempted.append(type)
    throw CocoaError(.userCancelled)
})
expect(cancelled.cancelled && attempted.count == 1, "Stop asking after user cancellation")
print("PASS: default-editor type scope, partial failures, consent cancellation (mock registration)")

let indexed = NSMutableString(string: "a\r\nb\nc\r")
let index = LineIndex()
index.rebuild(indexed)
expect(index.starts == [0, 3, 5, 7], "CRLF and trailing newline line starts")
var seed: UInt64 = 42
func random(_ upper: Int) -> Int {
    seed = seed &* 6364136223846793005 &+ 1
    return Int((seed >> 32) % UInt64(max(upper, 1)))
}
let insertions = ["", "x", "\n", "\r", "\r\n", "hello\nworld", "\u{2028}"]
for _ in 0..<2000 {
    let location = random(indexed.length + 1)
    let length = random(min(8, indexed.length - location) + 1)
    let replacement = insertions[random(insertions.count)]
    indexed.replaceCharacters(in: NSRange(location: location, length: length), with: replacement)
    index.update(indexed, editedRange: NSRange(location: location, length: (replacement as NSString).length), delta: (replacement as NSString).length - length)
    let reference = LineIndex()
    reference.rebuild(indexed)
    expect(index.starts == reference.starts, "Incremental line index must match a rebuild")
    for offset in 0...indexed.length {
        expect(index.starts[index.line(at: offset)] <= offset, "Line lookup cannot pass caret")
    }
}
expect(LanguageMode.detectedName("file.tsx") == "TypeScript", "TypeScript detection")
expect(LanguageMode.detectedName("Gemfile") == "Ruby", "Extensionless language label")
expect(EditorTheme.current(for: NSAppearance(named: .aqua)!).background != EditorTheme.current(for: NSAppearance(named: .darkAqua)!).background, "Independent light/dark palettes")

let previewDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: previewDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: previewDirectory) }
for encoding in [String.Encoding.utf8, .utf16] {
    let file = previewDirectory.appendingPathComponent("preview.swift")
    let sample = "let greeting = \"héllo 🐢\"\r\n"
    try sample.data(using: encoding)!.write(to: file)
    let complete = try PreviewText.read(file)
    expect(complete.text == sample && !complete.truncated, "Quick Look encoding round trip")
    for limit in 8..<sample.data(using: encoding)!.count {
        let prefix = try PreviewText.read(file, limit: limit)
        expect(prefix.truncated, "Quick Look must disclose truncated previews")
        expect(sample.unicodeScalars.starts(with: prefix.text.unicodeScalars), "Quick Look must preserve complete Unicode scalars")
    }
}
let quickLookInfo = try Data(contentsOf: URL(fileURLWithPath: "FstQuickLook/Info.plist"))
let quickLookPlist = try PropertyListSerialization.propertyList(from: quickLookInfo, format: nil) as! [String: Any]
let extensionInfo = quickLookPlist["NSExtension"] as! [String: Any]
let quickLookTypes = (extensionInfo["NSExtensionAttributes"] as! [String: Any])["QLSupportedContentTypes"] as! [String]
let appPlist = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "Fst/Info.plist")), format: nil) as! [String: Any]
let appTypes = (appPlist["CFBundleDocumentTypes"] as! [[String: Any]])[0]["LSItemContentTypes"] as! [String]
expect(Set(quickLookTypes) == Set(appTypes).subtracting(["public.data"]), "Quick Look covers every declared supported type without all-data registration")
print("PASS: 2,000 incremental line edits, language modes, split themes, bounded Unicode previews, Quick Look type coverage")


var changedDefaults: [UTType] = []
let skippedDefaults = await DefaultEditor.register(types: [.plainText, .json, .html], isDefault: { _, type in
    type != .json
}, setDefault: { _, type in
    changedDefaults.append(type)
})
expect(skippedDefaults.alreadyDefault == 2 && skippedDefaults.updated == 1, "Count existing and new defaults separately")
expect(changedDefaults == [.json], "Only request consent for file types that still need changing")
let allAlreadyDefault = await DefaultEditor.register(types: [.plainText, .json], isDefault: { _, _ in true }, setDefault: { _, _ in
    fatalError("Already-default types must never request another change")
})
expect(allAlreadyDefault.alreadyDefault == 2 && allAlreadyDefault.updated == 0, "Repeated clicks must not request changes again")
print("PASS: existing file defaults are skipped without requesting consent again")

func testCustomThemes() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    func write(_ name: String, _ content: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(content.utf8).write(to: url)
        return url
    }
    _ = try write("base.json", ##"{"colors":{"editor.background":"#123","editor.foreground":"#abcdef"},"tokenColors":[{"scope":"comment","settings":{"foreground":"#456"}}]}"##)
    let url = try write("custom.json", ##"""
    {
      // VS Code themes commonly contain comments and trailing commas.
      "include": "base.json",
      "colors": { "editorCursor.foreground": "#ff0000", "editor.selectionBackground": "#12345680", },
      "tokenColors": [
        {"scope": ["string", "constant.numeric"], "settings": {"foreground": "#fedcba"}},
        {"scope": "keyword, storage.type", "settings": {"foreground": "#654321"}},
        {"scope": "comment", "settings": {"foreground": "#789"}},
        {"scope": "source.python comment", "settings": {"foreground": "#fff"}},
      ],
    }
    """##)
    let theme = try CustomThemes.parse(url: url, root: root)
    expect(theme.background == CustomThemes.hex("#112233"), "Theme includes inherit background colors")
    expect(theme.comment == CustomThemes.hex("#778899"), "Child token rules override inherited rules; contextual selectors are ignored")
    expect(theme.string == CustomThemes.hex("#fedcba") && theme.number == theme.string, "Scope arrays map to lexical categories")
    expect(theme.keyword == CustomThemes.hex("#654321"), "Comma-separated scope selectors work")
    expect(abs(theme.selection!.alphaComponent - 128.0 / 255) < 0.001, "Eight-digit hex retains selection transparency")
    expect(theme.caret == CustomThemes.hex("#f00"), "Cursor theme colors load")
    for value in ["red", "#zzzzzz", "#12", "#123456789"] { expect(CustomThemes.hex(value) == nil, "Malformed colors are ignored") }
    for (name, content) in [("invalid.json", "{}"), ("cycle.json", "{\"include\":\"cycle.json\"}"),
                            ("escape.json", "{\"include\":\"../outside.json\"}"), ("broken.json", "{")] {
        let file = try write(name, content)
        do { _ = try CustomThemes.parse(url: file, root: root); fatalError("Invalid theme was accepted: \(name)") }
        catch {}
    }
    let partial = try write("partial.json", ##"{"type":"light","colors":{"editor.background":"#ffffff"}}"##)
    let fallback = try CustomThemes.parse(url: partial, root: root)
    expect(fallback.keyword == EditorTheme.builtin(dark: false).keyword, "Partial themes use readable appearance defaults")
    print("PASS: VS Code JSONC themes, includes, token mapping, alpha colors, invalid files, and fallbacks")
}
try testCustomThemes()

func testGutterBaselines() {
    for family in ["Menlo", "Monaco"] {
        for height in [0.8, 1.0, 1.2, 1.6, 2.4] {
            for newline in ["\n", "\r\n", "\r", "\u{2028}"] {
                let font = NSFont(name: family, size: 18)!
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineHeightMultiple = height
                let source = "abc" + newline + newline + "def" + newline
                let storage = NSTextStorage(string: source, attributes: [.font: font, .paragraphStyle: paragraph])
                let layout = NSLayoutManager()
                let container = NSTextContainer(size: NSSize(width: 500, height: 1000))
                storage.addLayoutManager(layout)
                layout.addTextContainer(container)
                layout.ensureLayout(for: container)
                let first = layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
                let textBaseline = first.minY + layout.location(forGlyphAt: 0).y
                let inset = first.maxY - textBaseline
                let newlineLength = (newline as NSString).length
                let starts = [0, 3 + newlineLength, 3 + 2 * newlineLength, storage.length]
                for (line, position) in starts.enumerated() {
                    let baseline = LineNumberRuler.baseline(at: position, length: storage.length, layout: layout, font: font)
                    let fragment = position == storage.length ? layout.extraLineFragmentRect
                        : layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: position), effectiveRange: nil)
                    expect(abs(baseline - (fragment.maxY - inset)) < 0.01,
                           "Gutter spacing must match text across blank and trailing lines: \(family), \(height), \(line)")
                }
            }
        }
    }
    print("PASS: uniform gutter baselines across empty lines, line endings, fonts, and line heights")
}
testGutterBaselines()
