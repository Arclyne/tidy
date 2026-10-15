import Foundation

public struct InstalledApplication: Identifiable, Hashable, Sendable {
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let name: String
    public let version: String?
    public let matchingNames: [String]
    public let applicationGroups: [String]

    public var id: URL { bundleURL }
    public var isAppleApplication: Bool { bundleIdentifier.hasPrefix("com.apple.") }

    public init(
        bundleURL: URL,
        bundleIdentifier: String,
        name: String,
        version: String? = nil,
        matchingNames: [String] = [],
        applicationGroups: [String] = []
    ) {
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.matchingNames = matchingNames.isEmpty ? [name] : matchingNames
        self.applicationGroups = applicationGroups
    }
}
