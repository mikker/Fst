import AppKit
import UniformTypeIdentifiers

struct DefaultEditor {
    struct Result {
        var updated = 0
        var alreadyDefault = 0
        var failures: [String] = []
        var cancelled = false
    }

    static let extensions = Set(Language.hashExtensions + Language.slashExtensions + Language.sqlExtensions + Language.dataExtensions)

    static var contentTypes: [UTType] {
        // Constrain lookup to text: .ts also identifies an MPEG transport stream.
        let types = extensions.sorted().compactMap {
            UTType(filenameExtension: $0, conformingTo: .text)
        }
        return Array(Set(types)).sorted { $0.identifier < $1.identifier }
    }

    @MainActor
    static func register(
        types: [UTType] = contentTypes,
        applicationURL: URL = Bundle.main.bundleURL,
        isDefault: (URL, UTType) -> Bool = { app, type in
            guard let current = NSWorkspace.shared.urlForApplication(toOpen: type) else { return false }
            if let expectedID = Bundle(url: app)?.bundleIdentifier,
               let currentID = Bundle(url: current)?.bundleIdentifier {
                return expectedID == currentID
            }
            return current.resolvingSymlinksInPath() == app.resolvingSymlinksInPath()
        },
        setDefault: (URL, UTType) async throws -> Void = { app, type in
            try await NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type)
        }
    ) async -> Result {
        var result = Result()
        for type in types {
            if isDefault(applicationURL, type) {
                result.alreadyDefault += 1
                continue
            }
            do {
                try await setDefault(applicationURL, type)
                result.updated += 1
            } catch {
                let failure = error as NSError
                if (failure.domain == NSCocoaErrorDomain && failure.code == NSUserCancelledError)
                    || (failure.domain == NSOSStatusErrorDomain && failure.code == -128)
                    || error is CancellationError {
                    result.cancelled = true
                    break
                }
                result.failures.append("\(type.localizedDescription ?? type.identifier): \(error.localizedDescription)")
            }
        }
        return result
    }
}
