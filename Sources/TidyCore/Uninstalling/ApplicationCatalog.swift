import Foundation

public protocol ApplicationBundleReading {
    func application(at bundleURL: URL) -> InstalledApplication?
}

public protocol ApplicationCatalog {
    func installedApplications() -> [InstalledApplication]
}

public struct InfoPlistApplicationReader: ApplicationBundleReading {
    private let propertyListReader: PropertyListReader
    private let entitlementsReader: any EntitlementsReading

    public init(fileSystem: any FileSystemReading, entitlementsReader: any EntitlementsReading) {
        self.propertyListReader = PropertyListReader(fileSystem: fileSystem)
        self.entitlementsReader = entitlementsReader
    }

    public func application(at bundleURL: URL) -> InstalledApplication? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let infoDictionary = propertyListReader.dictionary(at: infoPlistURL),
              let bundleIdentifier = infoDictionary["CFBundleIdentifier"] as? String
        else { return nil }

        let fileName = bundleURL.deletingPathExtension().lastPathComponent
        let declaredNames = ["CFBundleDisplayName", "CFBundleName"].compactMap { infoDictionary[$0] as? String }
        var uniqueNames: [String] = []
        for candidateName in [fileName] + declaredNames where !uniqueNames.contains(candidateName) {
            uniqueNames.append(candidateName)
        }

        return InstalledApplication(
            bundleURL: bundleURL,
            bundleIdentifier: bundleIdentifier,
            name: fileName,
            version: infoDictionary["CFBundleShortVersionString"] as? String,
            matchingNames: uniqueNames,
            applicationGroups: entitlementsReader.applicationGroups(of: bundleURL)
        )
    }
}

public struct DirectoryApplicationCatalog: ApplicationCatalog {
    private let searchDirectories: [URL]
    private let fileSystem: any FileSystemReading
    private let bundleReader: any ApplicationBundleReading

    public init(
        searchDirectories: [URL],
        fileSystem: any FileSystemReading,
        bundleReader: any ApplicationBundleReading
    ) {
        self.searchDirectories = searchDirectories
        self.fileSystem = fileSystem
        self.bundleReader = bundleReader
    }

    public func installedApplications() -> [InstalledApplication] {
        var seenBundleIdentifiers = Set<String>()
        return searchDirectories
            .flatMap { applicationBundles(in: $0) }
            .filter { !fileSystem.isOnReadOnlyVolume($0) }
            .compactMap { bundleReader.application(at: $0) }
            .filter { seenBundleIdentifiers.insert($0.bundleIdentifier).inserted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func applicationBundles(in directory: URL) -> [URL] {
        fileSystem.contentsOfDirectory(at: directory).flatMap { entry -> [URL] in
            if entry.pathExtension == "app" {
                return [entry]
            }
            guard fileSystem.isDirectory(at: entry) else { return [] }
            return fileSystem.contentsOfDirectory(at: entry).filter { $0.pathExtension == "app" }
        }
    }
}
