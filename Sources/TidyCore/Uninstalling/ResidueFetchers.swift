import Foundation

public protocol ResidueFetcher {
    var group: ResidueGroup { get }
    func residues(of application: InstalledApplication) -> [URL]
}

public struct DirectoryResidueFetcher: ResidueFetcher {
    public let group: ResidueGroup
    private let directories: [URL]
    private let matcher: any ResidueMatching
    private let fileSystem: any FileSystemReading

    public init(
        group: ResidueGroup,
        directories: [URL],
        matcher: any ResidueMatching,
        fileSystem: any FileSystemReading
    ) {
        self.group = group
        self.directories = directories
        self.matcher = matcher
        self.fileSystem = fileSystem
    }

    public func residues(of application: InstalledApplication) -> [URL] {
        directories.flatMap { directory in
            fileSystem.contentsOfDirectory(at: directory)
                .filter { matcher.matches(fileName: $0.lastPathComponent, application: application) }
        }
    }
}

public struct GroupContainerResidueFetcher: ResidueFetcher {
    public let group: ResidueGroup = .groupContainer
    private let groupContainersDirectory: URL
    private let installedApplications: [InstalledApplication]
    private let fileSystem: any FileSystemReading

    public init(
        groupContainersDirectory: URL,
        installedApplications: [InstalledApplication],
        fileSystem: any FileSystemReading
    ) {
        self.groupContainersDirectory = groupContainersDirectory
        self.installedApplications = installedApplications
        self.fileSystem = fileSystem
    }

    public func residues(of application: InstalledApplication) -> [URL] {
        let groupsSharedWithOtherApplications = Set(
            installedApplications
                .filter { $0.bundleIdentifier != application.bundleIdentifier }
                .flatMap(\.applicationGroups)
        )
        return application.applicationGroups
            .filter { !groupsSharedWithOtherApplications.contains($0) }
            .map { groupContainersDirectory.appendingPathComponent($0) }
            .filter { fileSystem.fileExists(at: $0) }
    }
}

public struct LaunchAgentResidueFetcher: ResidueFetcher {
    public let group: ResidueGroup = .launchAgents
    private let launchAgentsDirectory: URL
    private let matcher: any ResidueMatching
    private let launchAgentReader: LaunchAgentReader
    private let fileSystem: any FileSystemReading

    public init(
        launchAgentsDirectory: URL,
        matcher: any ResidueMatching,
        fileSystem: any FileSystemReading
    ) {
        self.launchAgentsDirectory = launchAgentsDirectory
        self.matcher = matcher
        self.launchAgentReader = LaunchAgentReader(fileSystem: fileSystem)
        self.fileSystem = fileSystem
    }

    public func residues(of application: InstalledApplication) -> [URL] {
        fileSystem.contentsOfDirectory(at: launchAgentsDirectory)
            .filter { $0.pathExtension == "plist" }
            .filter { belongs($0, to: application) }
    }

    private func belongs(_ plistURL: URL, to application: InstalledApplication) -> Bool {
        if matcher.matches(fileName: plistURL.lastPathComponent, application: application) {
            return true
        }
        guard let definition = launchAgentReader.definition(at: plistURL) else { return false }
        if definition.associatedBundleIdentifiers.contains(application.bundleIdentifier) {
            return true
        }
        if let label = definition.label, matcher.matches(fileName: label, application: application) {
            return true
        }
        let applicationPathPrefix = application.bundleURL.standardizedFileURL.path + "/"
        return definition.executableURL?.standardizedFileURL.path.hasPrefix(applicationPathPrefix) ?? false
    }
}
