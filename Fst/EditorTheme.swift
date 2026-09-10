import AppKit

struct EditorTheme {
    static let lightNames = ["Paper", "Snow"]
    static let darkNames = ["Midnight", "Graphite"]
    let background: NSColor
    let foreground: NSColor
    let comment: NSColor
    let string: NSColor
    let keyword: NSColor
    let number: NSColor
    var caret: NSColor? = nil
    var selection: NSColor? = nil
    var lineNumber: NSColor? = nil

    static func current(for appearance: NSAppearance) -> EditorTheme {
        let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let selected = dark ? EditorPreferences.darkTheme : EditorPreferences.lightTheme
        if selected.hasPrefix("file:"), let theme = try? CustomThemes.load(filename: String(selected.dropFirst(5))) {
            return theme
        }
        return builtin(dark: dark, name: selected)
    }

    static func builtin(dark: Bool, name: String = "") -> EditorTheme {
        if dark {
            return EditorTheme(background: color(name == "Graphite" ? 0x242424 : 0x191C22), foreground: color(0xD9DEE8),
                               comment: color(0x8993A5), string: color(0xA8CC8C),
                               keyword: color(0xC5A3EB), number: color(0xE7B77F))
        }
        return EditorTheme(background: color(name == "Snow" ? 0xFFFFFF : 0xFAF9F6), foreground: color(0x292C33),
                           comment: color(0x777D72), string: color(0x407341),
                           keyword: color(0x8653A4), number: color(0xA05B26))
    }

    private static func color(_ rgb: Int) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }
}
