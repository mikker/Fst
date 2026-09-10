import AppKit

// Only the selected theme is read on launch. Folder discovery happens in Settings.
enum CustomThemes {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fst/Themes", isDirectory: true)
    }
    private static var cache: [String: Result<EditorTheme, Error>] = [:]

    struct ThemeError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func files() throws -> [String] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { ["json", "jsonc"].contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func reload() { cache.removeAll() }

    static func load(filename: String) throws -> EditorTheme {
        if let cached = cache[filename] { return try cached.get() }
        guard (filename as NSString).lastPathComponent == filename else {
            throw ThemeError(message: "Theme must be in the Themes folder.")
        }
        let result = Result { try parse(url: directory.appendingPathComponent(filename), root: directory) }
        cache[filename] = result
        return try result.get()
    }

    static func parse(url: URL, root: URL) throws -> EditorTheme {
        let object = try read(url: url, root: root, depth: 0)
        let colors = (object["colors"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String }
        let rules = object["tokenColors"] as? [[String: Any]] ?? []
        let global = rules.filter { $0["scope"] == nil || ($0["scope"] as? String) == "" }
            .compactMap { $0["settings"] as? [String: String] }
            .reduce(into: [String: String]()) { $0.merge($1) { _, new in new } }
        let background = hex(colors["editor.background"] ?? global["background"])
        let dark: Bool
        if let type = object["type"] as? String {
            dark = !["light", "hcLight"].contains(type)
        } else if let rgb = background?.usingColorSpace(.sRGB) {
            dark = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent < 0.5
        } else { dark = true }
        let fallback = EditorTheme.builtin(dark: dark)
        func token(_ scopes: [String], fallback: NSColor) -> NSColor {
            var result = fallback
            var best = -1
            for rule in rules {
                guard let settings = rule["settings"] as? [String: String], let color = hex(settings["foreground"]) else { continue }
                let selectors = (rule["scope"] as? [String]) ?? [(rule["scope"] as? String) ?? ""]
                for selector in selectors.flatMap({ $0.components(separatedBy: ",") }) {
                    let scope = selector.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Match general token scopes; contextual/language-specific selectors
                    // cannot be represented by Fst's four lexical token categories.
                    guard !scope.isEmpty, scopes.contains(where: { $0 == scope || $0.hasPrefix(scope + ".") }) else { continue }
                    if scope.count >= best { result = color; best = scope.count }
                }
            }
            return result
        }
        return EditorTheme(background: background ?? fallback.background,
                           foreground: hex(colors["editor.foreground"] ?? global["foreground"]) ?? fallback.foreground,
                           comment: token(["comment", "comment.line", "comment.block"], fallback: fallback.comment),
                           string: token(["string", "string.quoted", "string.quoted.double"], fallback: fallback.string),
                           keyword: token(["keyword", "keyword.control", "storage.type", "storage.modifier"], fallback: fallback.keyword),
                           number: token(["constant.numeric"], fallback: fallback.number),
                           caret: hex(colors["editorCursor.foreground"] ?? global["caret"]),
                           selection: hex(colors["editor.selectionBackground"] ?? global["selection"]),
                           lineNumber: hex(colors["editorLineNumber.foreground"]))
    }

    private static func read(url: URL, root: URL, depth: Int) throws -> [String: Any] {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.resolvingSymlinksInPath().standardizedFileURL.path + "/"
        guard depth < 8, resolved.path.hasPrefix(prefix) else {
            throw ThemeError(message: "Theme includes must stay inside the Themes folder and cannot form a cycle.")
        }
        let handle = try FileHandle(forReadingFrom: resolved)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 2 * 1024 * 1024 + 1) ?? Data()
        guard data.count <= 2 * 1024 * 1024 else { throw ThemeError(message: "Theme files must be smaller than 2 MiB.") }
        guard let object = try JSONSerialization.jsonObject(with: data, options: [.json5Allowed]) as? [String: Any],
              object["colors"] is [String: Any] || object["tokenColors"] is [[String: Any]] || object["include"] is String else {
            throw ThemeError(message: "Expected a VS Code color theme with colors or tokenColors.")
        }
        if object["tokenColors"] is String {
            throw ThemeError(message: "Use a VS Code JSON theme with inline tokenColors, rather than a TextMate file reference.")
        }
        guard let include = object["include"] as? String else { return object }
        var merged = try read(url: resolved.deletingLastPathComponent().appendingPathComponent(include), root: root, depth: depth + 1)
        let colors = (merged["colors"] as? [String: Any] ?? [:]).merging(object["colors"] as? [String: Any] ?? [:]) { _, new in new }
        let rules = (merged["tokenColors"] as? [[String: Any]] ?? []) + (object["tokenColors"] as? [[String: Any]] ?? [])
        merged.merge(object) { _, new in new }
        merged["colors"] = colors
        merged["tokenColors"] = rules
        return merged
    }

    static func hex(_ value: String?) -> NSColor? {
        guard let value, value.hasPrefix("#") else { return nil }
        var digits = String(value.dropFirst())
        if digits.count == 3 || digits.count == 4 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard [6, 8].contains(digits.count), let number = UInt32(digits, radix: 16) else { return nil }
        let rgba = digits.count == 6 ? (number << 8) | 255 : number
        return NSColor(srgbRed: CGFloat((rgba >> 24) & 255) / 255,
                       green: CGFloat((rgba >> 16) & 255) / 255,
                       blue: CGFloat((rgba >> 8) & 255) / 255,
                       alpha: CGFloat(rgba & 255) / 255)
    }
}
