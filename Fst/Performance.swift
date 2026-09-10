import Foundation
import os.signpost

enum Performance {
    static var launchStarted = ProcessInfo.processInfo.systemUptime
    static let log = OSLog(subsystem: "dev.fst", category: .pointsOfInterest)

    static func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id)
        defer { os_signpost(.end, log: log, name: name, signpostID: id) }
        return try work()
    }
}
