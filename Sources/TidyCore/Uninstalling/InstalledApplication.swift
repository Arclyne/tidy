import Foundation

public struct InstalledApplication: Identifiable, Hashable, Sendable {
    public let bundleURL: URL
    public let bundleIdentifier: String
    public let name: String
    public let version: String?
    public let matchingNames: [String]
    public let applicationGroups: [String]
    public let source: ApplicationSource
    public let lastUsedDate: Date?

    public var id: URL { bundleURL }
    public var isAppleApplication: Bool { vendor == .apple }
    public var vendor: ApplicationVendor { ApplicationVendor(bundleIdentifier: bundleIdentifier) }

    public init(
        bundleURL: URL,
        bundleIdentifier: String,
        name: String,
        version: String? = nil,
        matchingNames: [String] = [],
        applicationGroups: [String] = [],
        source: ApplicationSource = .other,
        lastUsedDate: Date? = nil
    ) {
        self.bundleURL = bundleURL
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.version = version
        self.matchingNames = matchingNames.isEmpty ? [name] : matchingNames
        self.applicationGroups = applicationGroups
        self.source = source
        self.lastUsedDate = lastUsedDate
    }
}
