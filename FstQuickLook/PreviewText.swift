import Foundation

struct PreviewText {
    let text: String
    let truncated: Bool

    static func read(_ url: URL, limit: Int = 1_048_576) throws -> PreviewText {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        let truncated = data.count > limit
        var body = Data(data.prefix(limit))
        let encoding: String.Encoding
        if body.starts(with: [0xFF, 0xFE]) { encoding = .utf16LittleEndian; body.removeFirst(2) }
        else if body.starts(with: [0xFE, 0xFF]) { encoding = .utf16BigEndian; body.removeFirst(2) }
        else {
            encoding = .utf8
            if body.starts(with: [0xEF, 0xBB, 0xBF]) { body.removeFirst(3) }
        }
        // A bounded read can split a UTF-8 scalar or UTF-16 surrogate pair.
        for trim in 0...(truncated ? min(3, body.count) : 0) {
            if let text = String(data: body.dropLast(trim), encoding: encoding), (text as NSString).range(of: "\0").location == NSNotFound {
                return PreviewText(text: text, truncated: truncated)
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
}
