import Foundation

public struct LaunchAgentDefinition: Sendable {
    public let plistURL: URL
    public let label: String?
    public let executableURL: URL?
    public let associatedBundleIdentifiers: [String]
}

public struct LaunchAgentReader {
    private let propertyListReader: PropertyListReader

    public init(fileSystem: any FileSystemReading) {
        propertyListReader = PropertyListReader(fileSystem: fileSystem)
    }

    public func definition(at plistURL: URL) -> LaunchAgentDefinition? {
        guard let propertyList = propertyListReader.dictionary(at: plistURL) else { return nil }

        let programPath = (propertyList["Program"] as? String)
            ?? (propertyList["ProgramArguments"] as? [String])?.first
        let executableURL = programPath
            .flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0) : nil }

        return LaunchAgentDefinition(
            plistURL: plistURL,
            label: propertyList["Label"] as? String,
            executableURL: executableURL,
            associatedBundleIdentifiers: Self.associatedBundleIdentifiers(in: propertyList)
        )
    }

    private static func associatedBundleIdentifiers(in propertyList: [String: Any]) -> [String] {
        let associatedValue = propertyList["AssociatedBundleIdentifiers"]
        if let identifiers = associatedValue as? [String] {
            return identifiers
        }
        if let identifier = associatedValue as? String {
            return [identifier]
        }
        return []
    }
}
