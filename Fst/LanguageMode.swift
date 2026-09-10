import Foundation

struct LanguageMode {
    let name: String
    let filename: String
    static let all: [LanguageMode] = [
        .init(name: "Plain Text", filename: "file.txt"),
        .init(name: "Bash / Shell", filename: "file.sh"), .init(name: "C", filename: "file.c"),
        .init(name: "C++", filename: "file.cpp"), .init(name: "C#", filename: "file.cs"),
        .init(name: "CSS", filename: "file.css"), .init(name: "Dart", filename: "file.dart"),
        .init(name: "Elixir", filename: "file.ex"), .init(name: "Go", filename: "file.go"),
        .init(name: "Haskell", filename: "file.hs"), .init(name: "HTML", filename: "file.html"),
        .init(name: "Java", filename: "file.java"), .init(name: "JavaScript", filename: "file.js"),
        .init(name: "JSON", filename: "file.json"), .init(name: "Kotlin", filename: "file.kt"),
        .init(name: "Lua", filename: "file.lua"), .init(name: "Markdown", filename: "file.md"),
        .init(name: "Objective-C", filename: "file.m"), .init(name: "Perl", filename: "file.pl"),
        .init(name: "PHP", filename: "file.php"), .init(name: "PowerShell", filename: "file.ps1"),
        .init(name: "Python", filename: "file.py"), .init(name: "R", filename: "file.r"),
        .init(name: "Ruby", filename: "file.rb"), .init(name: "Rust", filename: "file.rs"),
        .init(name: "Scala", filename: "file.scala"), .init(name: "SCSS", filename: "file.scss"),
        .init(name: "SQL", filename: "file.sql"), .init(name: "Svelte", filename: "file.svelte"),
        .init(name: "Swift", filename: "file.swift"), .init(name: "TOML", filename: "file.toml"),
        .init(name: "TypeScript", filename: "file.ts"), .init(name: "Vue", filename: "file.vue"),
        .init(name: "XML / SVG", filename: "file.xml"), .init(name: "YAML", filename: "file.yaml"),
        .init(name: "Configuration", filename: "file.conf")
    ]
    static func detectedName(_ filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        let aliases = ["h": "c", "cc": "cpp", "cxx": "cpp", "hpp": "cpp", "mm": "m", "jsx": "js", "mjs": "js", "cjs": "js", "tsx": "ts", "pyw": "py", "rake": "rb", "bash": "sh", "zsh": "sh", "fish": "sh", "yml": "yaml", "pm": "pl", "exs": "ex", "ini": "conf", "kts": "kt", "less": "css", "htm": "html", "svg": "xml", "markdown": "md", "jsonc": "json"]
        if let mode = all.first(where: { ($0.filename as NSString).pathExtension == (aliases[ext] ?? ext) }) { return mode.name }
        switch filename.lowercased() {
        case "gemfile", "rakefile": return "Ruby"
        case ".bashrc", ".zshrc": return "Bash / Shell"
        case "dockerfile", "makefile": return "Configuration"
        default: return "Plain Text"
        }
    }
}
