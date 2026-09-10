import Foundation

/// UTF-16 line starts for TextKit. Edits scan their surrounding lines, not the file.
final class LineIndex {
    private(set) var starts = [0]
    var count: Int { starts.count }

    func rebuild(_ source: NSString) {
        starts = Performance.measure("Line index") { [0] + Self.breaks(in: source, from: 0, to: source.length) }
    }

    func line(at offset: Int) -> Int {
        max(0, upperBound(offset) - 1)
    }

    func update(_ source: NSString, editedRange: NSRange, delta: Int) {
        let first = line(at: max(0, editedRange.location - 1))
        let oldEnd = NSMaxRange(editedRange) - delta
        let suffix = upperBound(oldEnd + 1)
        let newEnd = suffix < starts.count ? starts[suffix] + delta : source.length
        let newStarts = Self.breaks(in: source, from: starts[first], to: newEnd)
        var result = Array(starts[...first])
        result.append(contentsOf: newStarts)
        if suffix < starts.count {
            for oldStart in starts[suffix...] {
                let shifted = oldStart + delta
                if result.last != shifted { result.append(shifted) }
            }
        }
        starts = result
    }

    private func upperBound(_ offset: Int) -> Int {
        var low = 0, high = starts.count
        while low < high {
            let middle = (low + high) / 2
            if starts[middle] <= offset { low = middle + 1 } else { high = middle }
        }
        return low
    }

    private static func breaks(in source: NSString, from start: Int, to end: Int) -> [Int] {
        var result: [Int] = []
        var offset = start
        while offset < end {
            var lineEnd = 0, contentsEnd = 0
            source.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd,
                                for: NSRange(location: offset, length: 0))
            guard lineEnd > offset else { break }
            if contentsEnd < lineEnd && lineEnd <= end { result.append(lineEnd) }
            offset = lineEnd
        }
        return result
    }
}
