import Foundation

public enum GroqKeyStoreError: LocalizedError {
    case fileStorage(String)

    public var errorDescription: String? {
        switch self {
        case .fileStorage(let message):
            return message
        }
    }
}

/// Stores the Groq credential separately from profile JSON and FitBar backups.
/// This intentionally avoids protected credential APIs so the app does not
/// trigger system password prompts when reading or saving the key.
public struct GroqKeyStore: Sendable {
    private let directory: URL
    private let fileName = "groq-api-key.local"

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("FitBar", isDirectory: true)
        }
    }

    private var fileURL: URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let key = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    public func save(_ key: String) throws {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            try delete()
            return
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(value.utf8).write(to: fileURL, options: .atomic)
        } catch {
            throw GroqKeyStoreError.fileStorage(error.localizedDescription)
        }
    }

    public func delete() throws {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                return
            }
            throw GroqKeyStoreError.fileStorage(error.localizedDescription)
        }
    }
}
