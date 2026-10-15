import Foundation

public protocol ApplicationLocating {
    func isApplicationInstalled(bundleIdentifier: String) -> Bool
}

public struct LeftoverFinder {
    private static let protectedIdentifierPrefixes = ["com.apple.", "group.com.apple.", "systemgroup.com.apple."]
    private static let groupPrefix = "group."
    private static let teamIdentifierLength = 10

    private let searchDirectories: [URL]
    private let applicationCatalog: any ApplicationCatalog
    private let applicationLocator: any ApplicationLocating
    private let fileSystem: any FileSystemReading

    public init(
        searchDirectories: [URL],
        applicationCatalog: any ApplicationCatalog,
        applicationLocator: any ApplicationLocating,
        fileSystem: any FileSystemReading
    ) {
        self.searchDirectories = searchDirectories
        self.applicationCatalog = applicationCatalog
        self.applicationLocator = applicationLocator
        self.fileSystem = fileSystem
    }

    public static func defaultSearchDirectories(homeDirectory: URL) -> [URL] {
        [
            "Library/Application Support",
            "Library/Caches",
            "Library/Containers",
            "Library/Group Containers",
            "Library/HTTPStorages",
            "Library/Logs",
            "Library/Preferences",
            "Library/Saved Application State",
            "Library/WebKit"
        ].map { homeDirectory.appendingPathComponent($0) }
    }

    public func findLeftovers() -> [ScanItem] {
        let installedIdentifiers = applicationCatalog.installedApplications().map { $0.bundleIdentifier.lowercased() }
        let installedVendorPrefixes = Set(installedIdentifiers.compactMap(Self.vendorPrefix(of:)))

        return searchDirectories
            .flatMap { fileSystem.contentsOfDirectory(at: $0) }
            .filter { candidateURL in
                guard let candidateIdentifier = Self.bundleIdentifier(inFileName: candidateURL.lastPathComponent) else { return false }
                return isOrphaned(
                    candidateIdentifier,
                    installedIdentifiers: installedIdentifiers,
                    installedVendorPrefixes: installedVendorPrefixes
                )
            }
            .map { ScanItem(url: $0, size: fileSystem.allocatedSize(of: $0), isSelectedByDefault: false) }
            .sorted { $0.size > $1.size }
    }

    private func isOrphaned(
        _ candidateIdentifier: String,
        installedIdentifiers: [String],
        installedVendorPrefixes: Set<String>
    ) -> Bool {
        let lowercasedCandidate = candidateIdentifier.lowercased()
        if Self.protectedIdentifierPrefixes.contains(where: { lowercasedCandidate.hasPrefix($0) }) {
            return false
        }

        let ownerIdentifier = Self.removingGroupAndTeamPrefixes(from: lowercasedCandidate)
        let isOwnedByInstalledApplication = installedIdentifiers.contains { installedIdentifier in
            ownerIdentifier == installedIdentifier
                || ownerIdentifier.hasPrefix(installedIdentifier + ".")
                || installedIdentifier.hasPrefix(ownerIdentifier + ".")
        }
        if isOwnedByInstalledApplication {
            return false
        }

        if let vendorPrefix = Self.vendorPrefix(of: ownerIdentifier), installedVendorPrefixes.contains(vendorPrefix) {
            return false
        }

        return !applicationLocator.isApplicationInstalled(bundleIdentifier: ownerIdentifier)
    }

    static func bundleIdentifier(inFileName fileName: String) -> String? {
        let candidate = BundleIdentifierMatcher.identifierCandidate(from: fileName)
        let components = candidate.split(separator: ".", omittingEmptySubsequences: false)
        let isWellFormed = components.count >= 3 && components.allSatisfy { component in
            !component.isEmpty && component.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }
        return isWellFormed ? candidate : nil
    }

    static func removingGroupAndTeamPrefixes(from identifier: String) -> String {
        var components = identifier.split(separator: ".").map(String.init)
        if components.first == String(groupPrefix.dropLast()) {
            components.removeFirst()
        }
        if let firstComponent = components.first,
           firstComponent.count == teamIdentifierLength,
           firstComponent.allSatisfy({ $0.isLetter || $0.isNumber }),
           firstComponent.contains(where: { $0.isNumber }) {
            components.removeFirst()
        }
        return components.joined(separator: ".")
    }

    static func vendorPrefix(of identifier: String) -> String? {
        let components = identifier.split(separator: ".")
        guard components.count >= 3 else { return nil }
        return components.prefix(2).joined(separator: ".")
    }
}
