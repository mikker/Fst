import AppKit

@objc(TextDocument)
final class TextDocument: NSDocument {
    private var contents = ""
    private var encoding = String.Encoding.utf8
    private var byteOrderMark = Data()
    private var editor: EditorViewController?

    override class var autosavesInPlace: Bool { true }
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool { true }

    override func read(from data: Data, ofType typeName: String) throws {
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            byteOrderMark = Data([0xEF, 0xBB, 0xBF])
            encoding = .utf8
        } else if data.starts(with: [0xFF, 0xFE]) {
            byteOrderMark = Data([0xFF, 0xFE])
            encoding = .utf16LittleEndian
        } else if data.starts(with: [0xFE, 0xFF]) {
            byteOrderMark = Data([0xFE, 0xFF])
            encoding = .utf16BigEndian
        } else {
            byteOrderMark = Data()
            encoding = .utf8
        }
        guard let decoded = String(data: data.dropFirst(byteOrderMark.count), encoding: encoding),
              (decoded as NSString).range(of: "\0").location == NSNotFound else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        contents = decoded
        if let editor {
            editor.encodingName = encodingLabel
            editor.setText(contents, filename: fileURL?.lastPathComponent ?? "")
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        let text = editor?.textView.string ?? contents
        guard let data = text.data(using: encoding, allowLossyConversion: false) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return byteOrderMark + data
    }

    override var fileURL: URL? {
        didSet { editor?.setLanguage(filename: fileURL?.lastPathComponent ?? "") }
    }

    private var encodingLabel: String {
        encoding == .utf16LittleEndian ? "UTF-16 LE" : (encoding == .utf16BigEndian ? "UTF-16 BE" : "UTF-8")
    }

    override func makeWindowControllers() {
        let controller = EditorViewController()
        controller.loadViewIfNeeded()
        controller.encodingName = encodingLabel
        controller.setText(contents, filename: fileURL?.lastPathComponent ?? "")
        contents = ""
        editor = controller
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.contentViewController = controller
        window.minSize = NSSize(width: 320, height: 240)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Editor")
        window.tabbingMode = .disallowed
        addWindowController(NSWindowController(window: window))
        window.makeFirstResponder(controller.textView)
    }
}
