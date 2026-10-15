import Foundation
@testable import TidyCore

final class TemporaryHome {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TidyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    var fileSystem: LocalFileSystem {
        LocalFileSystem(homeDirectory: url)
    }

    @discardableResult
    func createFile(_ relativePath: String, contents: Data = Data(repeating: 1, count: 2048)) throws -> URL {
        let fileURL = url.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: fileURL)
        return fileURL
    }

    @discardableResult
    func createApplication(named relativeName: String, bundleIdentifier: String) throws -> URL {
        let bundleRelativePath = "Applications/\(relativeName).app"
        let executableName = URL(fileURLWithPath: relativeName).lastPathComponent
        let infoDictionary: [String: String] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": executableName,
            "CFBundleExecutable": executableName,
            "CFBundleShortVersionString": "1.0"
        ]
        let infoPlist = try PropertyListSerialization.data(fromPropertyList: infoDictionary, format: .xml, options: 0)
        try createFile("\(bundleRelativePath)/Contents/Info.plist", contents: infoPlist)
        try createFile("\(bundleRelativePath)/Contents/MacOS/\(executableName)")
        return url.appendingPathComponent(bundleRelativePath)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

struct StaticRuleCatalog: RuleCatalog {
    let storedRules: [JunkRule]

    func rules() -> [JunkRule] {
        storedRules
    }
}

struct StaticRunningApplications: RunningApplicationsProviding {
    let identifiers: Set<String>

    func runningBundleIdentifiers() -> Set<String> {
        identifiers
    }
}

struct StaticApplicationCatalog: ApplicationCatalog {
    let applications: [InstalledApplication]

    func installedApplications() -> [InstalledApplication] {
        applications
    }
}

struct StaticApplicationLocator: ApplicationLocating {
    let installedIdentifiers: Set<String>

    func isApplicationInstalled(bundleIdentifier: String) -> Bool {
        installedIdentifiers.contains(bundleIdentifier.lowercased())
    }
}

struct NoEntitlementsReader: EntitlementsReading {
    func applicationGroups(of bundleURL: URL) -> [String] {
        []
    }
}

final class RecordingFileRemover: FileRemoving {
    private(set) var receivedItems: [ScanItem] = []

    func remove(_ items: [ScanItem]) async -> RemovalReport {
        receivedItems.append(contentsOf: items)
        return RemovalReport(removedItems: items)
    }
}

func propertyListData(_ propertyList: [String: Any]) throws -> Data {
    try PropertyListSerialization.data(fromPropertyList: propertyList, format: .xml, options: 0)
}

struct StaticUsageReader: ApplicationUsageReading {
    let lastUsedDate: Date?

    func lastUsedDate(ofApplicationAt bundleURL: URL) -> Date? {
        lastUsedDate
    }
}

final class RecordingCommandRunner: PrivilegedCommandRunning {
    private(set) var receivedCommands: [String] = []
    private let onRun: (String) -> Bool

    init(onRun: @escaping (String) -> Bool) {
        self.onRun = onRun
    }

    func run(shellCommand: String) async -> Bool {
        receivedCommands.append(shellCommand)
        return onRun(shellCommand)
    }
}

struct FailingFileRemover: FileRemoving {
    let isPermissionDenied: Bool

    func remove(_ items: [ScanItem]) async -> RemovalReport {
        RemovalReport(failures: items.map {
            RemovalFailure(item: $0, reason: "Denied", isPermissionDenied: isPermissionDenied)
        })
    }
}
