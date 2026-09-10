import Foundation

struct Language {
    let hashComments: Bool
    let slashComments: Bool
    let markup: Bool
    let sql: Bool
    let plain: Bool
    static let hashExtensions = ["py", "pyw", "rb", "rake", "sh", "bash", "zsh", "fish", "yml", "yaml", "toml", "r", "pl", "pm", "ps1", "ex", "exs", "conf", "ini"]
    static let slashExtensions = ["swift", "c", "h", "m", "mm", "cc", "cpp", "cxx", "hpp", "cs", "java", "kt", "kts", "scala", "go", "rs", "js", "jsx", "mjs", "cjs", "ts", "tsx", "php", "dart", "css", "scss", "less", "vue", "svelte"]
    static let markupExtensions = ["html", "htm", "xml", "svg", "vue", "svelte", "jsx", "tsx", "md", "markdown"]
    static let sqlExtensions = ["sql", "lua", "hs"]
    static let dataExtensions = ["json", "jsonc"]
    static let supportedExtensions = Set(hashExtensions + slashExtensions + markupExtensions + sqlExtensions + dataExtensions + ["txt", "text", "log"])

    static func detect(_ filename: String) -> Language {
        let ext = (filename as NSString).pathExtension.lowercased()
        let name = filename.lowercased()
        let hash = hashExtensions.contains(ext) || ["dockerfile", "makefile", "gemfile", "rakefile", ".bashrc", ".zshrc"].contains(name)
        let slash = slashExtensions.contains(ext)
        let markup = markupExtensions.contains(ext)
        let sql = sqlExtensions.contains(ext)
        return Language(hashComments: hash, slashComments: slash, markup: markup, sql: sql,
                        plain: !(hash || slash || markup || sql || dataExtensions.contains(ext)))
    }
}

struct SyntaxLexer {
    enum Kind { case comment, string, keyword, number }
    enum State: Equatable {
        case normal, lineComment, blockComment, htmlComment
        case quoted(UInt16, triple: Bool, escaped: Bool)
    }
    struct Token { let range: NSRange; let kind: Kind }
    static let keywords: Set<String> = Set("""
    actor abstract alias and as assert async await auto begin bool boolean break case catch char class const continue data def default defer delete do double elif else elseif end enum except export extends extension extern false False final finally float fn for foreach from fun func function get global guard if impl import in include init inline instanceof int interface internal is lambda let local long match module mut namespace new nil None nonlocal not null nullptr object of on open operator or override package pass private protected protocol public raise readonly record ref repeat require rescue return select self Self set short signed sizeof some static string struct subscript super switch synchronized template then this throw throws trait true True try type typealias typedef typeof union unless unsigned until use using val var virtual void volatile when where while with yield SELECT FROM WHERE INSERT INTO UPDATE DELETE CREATE TABLE JOIN LEFT RIGHT INNER OUTER ON AS AND OR NOT NULL VALUES SET GROUP ORDER BY LIMIT DISTINCT PRIMARY KEY REFERENCES ALTER DROP UNION HAVING
    """.split(whereSeparator: { $0.isWhitespace }).map(String.init))

    // Bounded chunks retain lexical state, including multiline comments and strings.
    static func scan(_ source: NSString, from start: Int, state initial: State, language: Language,
                     budget: Int = 8192) -> (end: Int, state: State, tokens: [Token]) {
        let end = min(source.length, start + budget)
        var i = start
        var state = initial
        var tokens: [Token] = []
        func matches(_ text: [UInt16], at position: Int) -> Bool {
            guard position + text.count <= source.length else { return false }
            return text.enumerated().allSatisfy { source.character(at: position + $0.offset) == $0.element }
        }
        func word(_ c: UInt16) -> Bool { c == 95 || c >= 128 || (65...90).contains(c) || (97...122).contains(c) || (48...57).contains(c) }
        while i < end {
            let begin = i
            let c = source.character(at: i)
            var kind: Kind?
            switch state {
            case .lineComment:
                while i < end && source.character(at: i) != 10 && source.character(at: i) != 13 { i += 1 }
                kind = .comment
                if i < end { state = .normal; i += 1 }
            case .blockComment, .htmlComment:
                let closing: [UInt16] = state == .htmlComment ? [45, 45, 62] : [42, 47]
                while i < end {
                    if matches(closing, at: i) { i += closing.count; state = .normal; break }
                    i += 1
                }
                kind = .comment
            case let .quoted(quote, triple, escaped):
                var escape = escaped
                while i < end {
                    let current = source.character(at: i)
                    if escape { escape = false; i += 1; continue }
                    if current == 92 { escape = true; i += 1; continue }
                    if current == quote && (!triple || matches([quote, quote, quote], at: i)) {
                        i += triple ? 3 : 1; state = .normal; break
                    }
                    i += 1
                }
                if state != .normal { state = .quoted(quote, triple: triple, escaped: escape) }
                kind = .string
            case .normal:
                if language.markup && matches([60, 33, 45, 45], at: i) {
                    state = .htmlComment; i += 4; kind = .comment
                } else if language.slashComments && matches([47, 42], at: i) {
                    state = .blockComment; i += 2; kind = .comment
                } else if (language.hashComments && c == 35) || (language.slashComments && matches([47, 47], at: i)) || (language.sql && matches([45, 45], at: i)) {
                    state = .lineComment; i += 1; kind = .comment
                } else if c == 34 || c == 39 || c == 96 {
                    let triple = matches([c, c, c], at: i)
                    state = .quoted(c, triple: triple, escaped: false)
                    i += triple ? 3 : 1; kind = .string
                } else if (48...57).contains(c) {
                    i += 1
                    while i < source.length && i - begin < 1024 && (word(source.character(at: i)) || source.character(at: i) == 46) { i += 1 }
                    kind = .number
                } else if word(c) {
                    i += 1
                    while i < source.length && word(source.character(at: i)) && i - begin < 1024 { i += 1 }
                    if keywords.contains(source.substring(with: NSRange(location: begin, length: i - begin))) { kind = .keyword }
                } else { i += 1 }
            }
            if let kind { tokens.append(Token(range: NSRange(location: begin, length: i - begin), kind: kind)) }
        }
        return (i, state, tokens)
    }
}
