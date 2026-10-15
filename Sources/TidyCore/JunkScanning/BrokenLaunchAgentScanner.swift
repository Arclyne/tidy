import Foundation

public struct BrokenLaunchAgentScanner: JunkScanner {
    private static let externalVolumesPrefix = "/Volumes/"

    public let category: JunkCategory = .brokenLaunchAgents
    private let fileSystem: any FileSystemReading
    private let launchAgentReader: LaunchAgentReader

    public init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
        self.launchAgentReader = LaunchAgentReader(fileSystem: fileSystem)
    }

    public func scan() async -> [ScanItem] {
        let launchAgentsDirectory = fileSystem.homeDirectory.appendingPathComponent("Library/LaunchAgents")
        return fileSystem.contentsOfDirectory(at: launchAgentsDirectory)
            .filter { $0.pathExtension == "plist" }
            .compactMap { launchAgentReader.definition(at: $0) }
            .filter { pointsToMissingExecutable($0) }
            .map { ScanItem(url: $0.plistURL, size: fileSystem.allocatedSize(of: $0.plistURL)) }
    }

    private func pointsToMissingExecutable(_ definition: LaunchAgentDefinition) -> Bool {
        guard let executableURL = definition.executableURL,
              !executableURL.path.hasPrefix(Self.externalVolumesPrefix)
        else { return false }
        return !fileSystem.fileExists(at: executableURL)
    }
}
