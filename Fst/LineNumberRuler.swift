import AppKit

final class LineNumberRuler: NSRulerView {
    let index: LineIndex
    private weak var editor: NSTextView?
    override var isFlipped: Bool { true }

    init(scrollView: NSScrollView, textView: NSTextView, index: LineIndex) {
        self.index = index
        editor = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48
        clipsToBounds = true
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var labelFont: NSFont {
        let font = editor?.font ?? EditorPreferences.font
        return NSFontManager.shared.convert(font, toSize: max(6, font.pointSize - 2))
    }

    func refresh() {
        let font = labelFont
        ruleThickness = max(44, (String(index.count) as NSString).size(withAttributes: [.font: font]).width + 22)
        needsDisplay = true
    }

    private static let baselineInsets: NSCache<NSFont, NSNumber> = {
        let cache = NSCache<NSFont, NSNumber>()
        cache.countLimit = 32
        return cache
    }()

    private static func baselineInset(for font: NSFont) -> CGFloat {
        if let cached = baselineInsets.object(forKey: font) { return CGFloat(cached.doubleValue) }
        let storage = NSTextStorage(string: "0", attributes: [.font: font])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 1000, height: 1000))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        layout.ensureLayout(for: container)
        let inset = layout.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil).maxY - layout.location(forGlyphAt: 0).y
        baselineInsets.setObject(NSNumber(value: Double(inset)), forKey: font)
        return inset
    }

    static func baseline(at position: Int, length: Int, layout: NSLayoutManager, font: NSFont) -> CGFloat {
        let fragment: NSRect
        if position == length {
            fragment = layout.extraLineFragmentRect
        } else {
            fragment = layout.lineFragmentRect(forGlyphAt: layout.glyphIndexForCharacter(at: position), effectiveRange: nil)
        }
        // Newline-only fragments have no text glyph baseline. Use the same font
        // metrics for all lines, including empty lines and the final extra fragment.
        return fragment.maxY - baselineInset(for: font)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        let theme = EditorTheme.current(for: effectiveAppearance)
        theme.background.setFill()
        bounds.fill()
        let origin = editor.textContainerOrigin
        let visible = editor.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)
        let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        let font = labelFont
        let editorFont = editor.font ?? font
        let labelBaseline = layout.defaultBaselineOffset(for: font)
        let selectedLine = index.line(at: editor.selectedRange().location)
        let length = editor.textStorage?.length ?? 0
        var line = index.line(at: characters.location)
        while line < index.count && index.starts[line] <= NSMaxRange(characters) {
            let position = index.starts[line]
            let baseline = Self.baseline(at: position, length: length, layout: layout, font: editorFont)
            let point = convert(NSPoint(x: 0, y: origin.y + baseline), from: editor)
            let label = String(line + 1) as NSString
            let attributes: [NSAttributedString.Key: Any] = [.font: font,
                .foregroundColor: line == selectedLine ? theme.foreground : (theme.lineNumber ?? NSColor.secondaryLabelColor)]
            let size = label.size(withAttributes: attributes)
            // Center the digits against the text's cap height. Paragraph line-height
            // spacing shifts its baseline, so the fragment's midpoint isn't enough.
            label.draw(at: NSPoint(x: ruleThickness - size.width - 10,
                                   y: point.y + (font.capHeight - editorFont.capHeight) / 2 - labelBaseline),
                       withAttributes: attributes)
            line += 1
        }
    }
}
