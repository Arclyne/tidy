import Foundation

public struct ChromiumCacheScanner: JunkScanner {
    private static let chromiumSignatureDirectoryNames = ["Code Cache", "GPUCache"]
    private static let cacheDirectoryNames = [
        "Cache",
        "Code Cache",
        "GPUCache",
        "DawnCache",
        "DawnGraphiteCache",
        "DawnWebGPUCache",
        "GrShaderCache",
        "Service Worker/CacheStorage",
        "Service Worker/ScriptCache"
    ]

    public let category: JunkCategory = .applicationCaches
    private let fileSystem: any FileSystemReading

    public init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
    }

    public func scan() async -> [ScanItem] {
        let applicationSupportDirectory = fileSystem.homeDirectory.appendingPathComponent("Library/Application Support")
        return fileSystem.contentsOfDirectory(at: applicationSupportDirectory)
            .filter { isChromiumDataDirectory($0) }
            .flatMap { cacheDirectories(in: $0) }
            .map { ScanItem(url: $0, size: fileSystem.allocatedSize(of: $0)) }
            .filter { $0.size > 0 }
    }

    private func isChromiumDataDirectory(_ url: URL) -> Bool {
        Self.chromiumSignatureDirectoryNames.contains { fileSystem.isDirectory(at: url.appendingPathComponent($0)) }
    }

    private func cacheDirectories(in dataDirectory: URL) -> [URL] {
        Self.cacheDirectoryNames
            .map { dataDirectory.appendingPathComponent($0) }
            .filter { fileSystem.isDirectory(at: $0) }
    }
}
