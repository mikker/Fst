import AppKit
import Darwin

func time<T>(_ operation: () throws -> T) rethrows -> (T, Double) {
    let started = ProcessInfo.processInfo.systemUptime
    let result = try operation()
    return (result, (ProcessInfo.processInfo.systemUptime - started) * 1000)
}

let args = CommandLine.arguments
if args.count != 3 { fatalError("Usage: profile <fixture> <result.json>") }
let url = URL(fileURLWithPath: args[1])
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.finishLaunching()
let document = TextDocument()
let (data, readMS) = try time { try Performance.measure("File read") { try Data(contentsOf: url) } }
let (_, decodeMS) = try time { try Performance.measure("Decode") { try document.read(from: data, ofType: "Text Document") } }
let (_, displayMS) = time {
    Performance.measure("First display") {
        document.makeWindowControllers()
        let window = document.windowControllers[0].window!
        window.makeKeyAndOrderFront(nil)
        window.displayIfNeeded()
    }
}
let editor = document.windowControllers[0].contentViewController as! EditorViewController
editor.setLanguage(filename: url.lastPathComponent)
let text = editor.textView
let window = document.windowControllers[0].window!
let firstHighlight = ProcessInfo.processInfo.systemUptime
while editor.highlighter.highlightedLength < min(8192, text.textStorage!.length) && ProcessInfo.processInfo.systemUptime - firstHighlight < 10 {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.005))
}
let firstHighlightMS = (ProcessInfo.processInfo.systemUptime - firstHighlight) * 1000
var edits: [Double] = []
var scrolls: [Double] = []
for fraction in [0.0, 0.5, 1.0] {
    let location = Int(Double(text.textStorage!.length) * fraction)
    // Align to a composed-character boundary for Unicode fixtures.
    let range = text.textStorage!.mutableString.rangeOfComposedCharacterSequences(for: NSRange(location: location, length: 0))
    let offset = min(range.location, text.textStorage!.length)
    let (_, scrollMS) = time {
        Performance.measure("Scroll") {
            text.setSelectedRange(NSRange(location: offset, length: 0))
            text.scrollRangeToVisible(text.selectedRange())
            window.displayIfNeeded()
        }
    }
    scrolls.append(scrollMS)
    for _ in 0..<10 {
        let (_, editMS) = time {
            Performance.measure("Edit and display") {
                text.undoManager?.beginUndoGrouping()
                text.insertText("x", replacementRange: text.selectedRange())
                text.undoManager?.endUndoGrouping()
                window.displayIfNeeded()
            }
        }
        edits.append(editMS)
        text.undoManager?.undo()
    }
}
var usage = rusage()
getrusage(RUSAGE_SELF, &usage)
let result: [String: Any] = [
    "fixture": url.lastPathComponent, "bytes": data.count, "lines": editor.lineIndex.count,
    "read_ms": readMS, "decode_ms": decodeMS, "first_display_ms": displayMS,
    "open_ms": readMS + decodeMS + displayMS, "first_highlight_ms": firstHighlightMS,
    "edit_ms": edits, "scroll_ms": scrolls, "peak_rss_bytes": usage.ru_maxrss,
    "viewport_width": text.enclosingScrollView!.contentSize.width, "viewport_height": text.enclosingScrollView!.contentSize.height,
    "font": EditorPreferences.fontName, "font_size": EditorPreferences.fontSize,
    "line_height_percent": EditorPreferences.lineHeight
]
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    .write(to: URL(fileURLWithPath: args[2]))
print("Profiled \(url.lastPathComponent)")
