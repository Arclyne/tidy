import Foundation

public struct LocalFileSystem: FileSystemReading {
    private static let sizeResourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey
    ]

    public let homeDirectory: URL
    private let fileManager: FileManager

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
    }

    public func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    public func isDirectory(at url: URL) -> Bool {
        var isDirectoryFlag: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectoryFlag) && isDirectoryFlag.boolValue
    }

    public func isOnReadOnlyVolume(_ url: URL) -> Bool {
        let resourceValues = try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        return resourceValues?.volumeIsReadOnly ?? false
    }

    public func contentsOfDirectory(at url: URL) -> [URL] {
        (try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    public func contents(of url: URL) -> Data? {
        fileManager.contents(atPath: url.path)
    }

    public func allocatedSize(of url: URL) -> Int64 {
        guard let rootValues = try? url.resourceValues(forKeys: Self.sizeResourceKeys),
              rootValues.isSymbolicLink != true
        else { return 0 }

        guard rootValues.isDirectory == true else {
            return Self.allocatedSize(from: rootValues)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(Self.sizeResourceKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var accumulatedSize: Int64 = 0
        for case let nestedURL as URL in enumerator {
            guard let nestedValues = try? nestedURL.resourceValues(forKeys: Self.sizeResourceKeys),
                  nestedValues.isRegularFile == true
            else { continue }
            accumulatedSize += Self.allocatedSize(from: nestedValues)
        }
        return accumulatedSize
    }

    private static func allocatedSize(from resourceValues: URLResourceValues) -> Int64 {
        Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
    }
}
