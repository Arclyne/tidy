import Foundation

public struct BrokenPreferencesScanner: JunkScanner {
    private static let protectedPrefix = "com.apple."

    public let category: JunkCategory = .brokenPreferences
    private let fileSystem: any FileSystemReading
    private let propertyListReader: PropertyListReader

    public init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
        self.propertyListReader = PropertyListReader(fileSystem: fileSystem)
    }

    public func scan() async -> [ScanItem] {
        let preferencesDirectory = fileSystem.homeDirectory.appendingPathComponent("Library/Preferences")
        return fileSystem.contentsOfDirectory(at: preferencesDirectory)
            .filter { $0.pathExtension == "plist" && !$0.lastPathComponent.hasPrefix(Self.protectedPrefix) }
            .filter { !propertyListReader.isReadable(at: $0) }
            .map { ScanItem(url: $0, size: fileSystem.allocatedSize(of: $0)) }
    }
}
