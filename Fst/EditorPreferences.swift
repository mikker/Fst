import AppKit

extension Notification.Name {
    static let editorPreferencesChanged = Notification.Name("editorPreferencesChanged")
}

struct EditorPreferences {
    static var wrapLines: Bool {
        get { UserDefaults.standard.bool(forKey: "wrapLines") }
        set { set(newValue, for: "wrapLines") }
    }
    static var fontName: String {
        get { UserDefaults.standard.string(forKey: "fontName") ?? "System Mono" }
        set { set(newValue, for: "fontName") }
    }
    static var fontSize: Double {
        get { number("fontSize", default: 14, range: 6...48) }
        set { set(min(max(newValue, 6), 48), for: "fontSize") }
    }
    static var lineHeight: Double {
        get { number("lineHeight", default: 120, range: 80...240) }
        set { set(min(max(newValue, 80), 240), for: "lineHeight") }
    }
    static var lightTheme: String {
        get { UserDefaults.standard.string(forKey: "lightTheme") ?? "Paper" }
        set { set(newValue, for: "lightTheme") }
    }
    static var darkTheme: String {
        get { UserDefaults.standard.string(forKey: "darkTheme") ?? "Midnight" }
        set { set(newValue, for: "darkTheme") }
    }
    static var font: NSFont {
        if fontName == "System Mono" { return .monospacedSystemFont(ofSize: fontSize, weight: .regular) }
        return NSFont(name: fontName, size: fontSize)
            ?? NSFontManager.shared.font(withFamily: fontName, traits: [], weight: 5, size: fontSize)
            ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeight / 100
        style.defaultTabInterval = font.maximumAdvancement.width * 4
        style.tabStops = []
        return style
    }
    private static func number(_ key: String, default fallback: Double, range: ClosedRange<Double>) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        let value = UserDefaults.standard.double(forKey: key)
        return value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
    private static func set(_ value: Any, for key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: .editorPreferencesChanged, object: nil)
    }
}
