import AppKit
import QuickLookUI

private final class PreviewEditorView: NSTextView {
    var appearanceChanged: (() -> Void)?
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        appearanceChanged?()
    }
}

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let textView = PreviewEditorView()
    private let note = NSTextField(labelWithString: "")
    private var highlighter: SyntaxHighlighter!
    private var request = 0

    override func loadView() {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        textView.isEditable = false
        textView.isRichText = false
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = textView.maxSize
        textView.layoutManager?.allowsNonContiguousLayout = true
        scroll.documentView = textView
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        for child in [scroll, note] { child.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(child) }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor), scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: note.topAnchor, constant: -4),
            note.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16), note.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            note.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
        highlighter = SyntaxHighlighter(textView: textView)
        textView.appearanceChanged = { [weak self] in self?.applyTheme() }
        applyTheme()
    }

    private func applyTheme() {
        let theme = EditorTheme.current(for: view.effectiveAppearance)
        textView.backgroundColor = theme.background
        textView.textColor = theme.foreground
        highlighter.theme = theme
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        request += 1
        let current = request
        Task { @MainActor in
            do {
                let preview = try await Task.detached(priority: .userInitiated) { try PreviewText.read(url) }.value
                guard current == request else { handler(CocoaError(.userCancelled)); return }
                loadViewIfNeeded()
                textView.string = preview.text
                highlighter.setLanguage(filename: url.lastPathComponent)
                note.stringValue = preview.truncated ? "Preview limited to the first 1 MiB." : url.lastPathComponent
                preferredContentSize = NSSize(width: 800, height: 600)
                handler(nil)
            } catch { handler(error) }
        }
    }
}
