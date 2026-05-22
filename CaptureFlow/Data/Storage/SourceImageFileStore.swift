import Foundation

struct SourceImageFileStore: Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager

    init(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws {
        self.fileManager = fileManager
        self.baseDirectory = try baseDirectory ?? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("CaptureFlow", isDirectory: true)
    }

    func saveImageData(_ data: Data) throws -> String {
        let directory = sourceImagesDirectory
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let filename = "\(UUID().uuidString).jpg"
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return "SourceImages/\(filename)"
    }

    func resolvedPath(for storedPath: String?) -> String? {
        guard let storedPath,
              !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let expandedPath = (storedPath as NSString).expandingTildeInPath
        if fileManager.fileExists(atPath: expandedPath) {
            return expandedPath
        }

        if expandedPath.hasPrefix("/") {
            let filename = URL(fileURLWithPath: expandedPath).lastPathComponent
            let migratedURL = sourceImagesDirectory.appendingPathComponent(filename)
            return fileManager.fileExists(atPath: migratedURL.path) ? migratedURL.path : nil
        }

        let relativeURL = baseDirectory.appendingPathComponent(storedPath)
        if fileManager.fileExists(atPath: relativeURL.path) {
            return relativeURL.path
        }

        let filename = URL(fileURLWithPath: storedPath).lastPathComponent
        let fallbackURL = sourceImagesDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fallbackURL.path) ? fallbackURL.path : nil
    }

    private var sourceImagesDirectory: URL {
        baseDirectory.appendingPathComponent("SourceImages", isDirectory: true)
    }
}
