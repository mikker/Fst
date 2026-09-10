import AppKit

final class SyntaxHighlighter: NSObject, NSTextStorageDelegate {
    var onEdit: ((NSTextStorage, NSRange, Int) -> Void)?
    private(set) var highlightedLength = 0
    var isFinished: Bool { highlightedLength >= (textView?.textStorage?.length ?? 0) }
    private weak var textView: NSTextView?
    private var language = Language.detect("")
    private var checkpoints: [Int: SyntaxLexer.State] = [0: .normal]
    private var offset = 0
    private var state = SyntaxLexer.State.normal
    private var generation = 0
    var theme: EditorTheme { didSet { restart(at: 0) } }

    init(textView: NSTextView) {
        self.textView = textView
        theme = EditorTheme.current(for: textView.effectiveAppearance)
        super.init()
        textView.textStorage?.delegate = self
    }

    func setLanguage(filename: String) {
        language = Language.detect(filename)
        restart(at: 0)
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        onEdit?(textStorage, editedRange, delta)
        restart(at: max(0, editedRange.location - 4))
    }

    private func restart(at location: Int) {
        generation += 1
        highlightedLength = 0
        let checkpoint = checkpoints.keys.filter { $0 <= min(location, offset) }.max() ?? 0
        offset = checkpoint
        state = checkpoints[checkpoint] ?? .normal
        checkpoints = checkpoints.filter { $0.key <= checkpoint }
        schedule(generation)
    }

    private func schedule(_ version: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) { [weak self] in self?.highlight(version) }
    }

    private func highlight(_ version: Int) {
        guard version == generation, let textView, let layout = textView.layoutManager,
              let source = textView.textStorage?.mutableString else { return }
        guard offset < source.length else { return }
        if language.plain {
            highlightedLength = source.length
            layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: 0, length: source.length))
            return
        }
        let result = Performance.measure("Highlight batch") {
            SyntaxLexer.scan(source, from: offset, state: state, language: language)
        }
        layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: NSRange(location: offset, length: result.end - offset))
        for token in result.tokens {
            let color: NSColor
            switch token.kind {
            case .comment: color = theme.comment
            case .string: color = theme.string
            case .keyword: color = theme.keyword
            case .number: color = theme.number
            }
            layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: token.range)
        }
        highlightedLength = result.end
        offset = result.end
        state = result.state
        checkpoints[offset] = state
        if offset < source.length { schedule(version) }
    }
}
