import Foundation

public enum ApplicationSource: String, CaseIterable, Hashable, Sendable {
    case appStore
    case setapp
    case other

    public var title: String {
        switch self {
        case .appStore: return "App Store"
        case .setapp: return "Setapp"
        case .other: return "Other"
        }
    }
}

public enum ApplicationVendor: String, CaseIterable, Hashable, Sendable {
    case apple
    case microsoft
    case google
    case adobe
    case jetBrains
    case other

    private static let identifierPrefixes: [(prefix: String, vendor: ApplicationVendor)] = [
        ("com.apple.", .apple),
        ("com.microsoft.", .microsoft),
        ("com.google.", .google),
        ("com.adobe.", .adobe),
        ("com.jetbrains.", .jetBrains)
    ]

    public init(bundleIdentifier: String) {
        let lowercasedIdentifier = bundleIdentifier.lowercased()
        self = Self.identifierPrefixes.first { lowercasedIdentifier.hasPrefix($0.prefix) }?.vendor ?? .other
    }

    public var title: String {
        switch self {
        case .apple: return "Apple"
        case .microsoft: return "Microsoft"
        case .google: return "Google"
        case .adobe: return "Adobe"
        case .jetBrains: return "JetBrains"
        case .other: return "Other"
        }
    }
}

public struct ApplicationSourceDetector {
    private static let appStoreReceiptPath = "Contents/_MASReceipt/receipt"
    private static let setappPathComponent = "Setapp"
    private static let setappIdentifierSuffix = "-setapp"

    private let fileSystem: any FileSystemReading

    public init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
    }

    public func source(ofApplicationAt bundleURL: URL, bundleIdentifier: String) -> ApplicationSource {
        if fileSystem.fileExists(at: bundleURL.appendingPathComponent(Self.appStoreReceiptPath)) {
            return .appStore
        }
        if bundleURL.pathComponents.contains(Self.setappPathComponent)
            || bundleIdentifier.lowercased().hasSuffix(Self.setappIdentifierSuffix) {
            return .setapp
        }
        return .other
    }
}

public protocol ApplicationUsageReading {
    func lastUsedDate(ofApplicationAt bundleURL: URL) -> Date?
}

public enum ApplicationListFilter: Hashable, Identifiable, Sendable {
    case all
    case unused
    case checked
    case source(ApplicationSource)
    case vendor(ApplicationVendor)

    public static let unusedThreshold: TimeInterval = 182 * 24 * 60 * 60

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: return "All Applications"
        case .unused: return "Unused"
        case .checked: return "Selected"
        case .source(let source): return source.title
        case .vendor(let vendor): return vendor.title
        }
    }

    public func includes(_ application: InstalledApplication, checkedIDs: Set<URL>, referenceDate: Date) -> Bool {
        switch self {
        case .all:
            return true
        case .unused:
            guard let lastUsedDate = application.lastUsedDate else { return false }
            return referenceDate.timeIntervalSince(lastUsedDate) > Self.unusedThreshold
        case .checked:
            return checkedIDs.contains(application.id)
        case .source(let source):
            return application.source == source
        case .vendor(let vendor):
            return application.vendor == vendor
        }
    }
}
