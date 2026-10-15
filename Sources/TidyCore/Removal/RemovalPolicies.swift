import Foundation

public enum RemovalVerdict: Equatable, Sendable {
    case allowed
    case denied(reason: String)
}

public protocol RemovalPolicy {
    func verdict(for url: URL) -> RemovalVerdict
}

public struct CompositeRemovalPolicy: RemovalPolicy {
    private let policies: [any RemovalPolicy]

    public init(policies: [any RemovalPolicy]) {
        self.policies = policies
    }

    public func verdict(for url: URL) -> RemovalVerdict {
        for policy in policies {
            let verdict = policy.verdict(for: url)
            if verdict != .allowed {
                return verdict
            }
        }
        return .allowed
    }
}

public struct ProtectedPathPolicy: RemovalPolicy {
    private static let protectedSystemPaths = [
        "/",
        "/Applications",
        "/Applications/Utilities",
        "/Library",
        "/Library/Application Support",
        "/Library/Caches",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        "/Library/Logs",
        "/Library/Preferences",
        "/Library/PrivilegedHelperTools",
        "/System",
        "/Users",
        "/Volumes",
        "/private",
        "/usr"
    ]
    private static let protectedSystemPrefixes = ["/System/", "/usr/", "/bin/", "/sbin/", "/private/var/db/", "/Library/Apple/"]
    private static let protectedHomeSubpaths = [
        "",
        "Library",
        "Library/Application Support",
        "Library/Caches",
        "Library/Containers",
        "Library/Group Containers",
        "Library/LaunchAgents",
        "Library/Logs",
        "Library/Preferences",
        "Library/Saved Application State",
        "Applications",
        "Desktop",
        "Documents",
        "Downloads",
        "Movies",
        "Music",
        "Pictures",
        ".Trash"
    ]

    private let protectedPaths: Set<String>

    public init(homeDirectory: URL) {
        let homePaths = Self.protectedHomeSubpaths.map { subpath in
            homeDirectory.appendingPathComponent(subpath).standardizedFileURL.path
        }
        protectedPaths = Set(Self.protectedSystemPaths + homePaths)
    }

    public func verdict(for url: URL) -> RemovalVerdict {
        let path = url.standardizedFileURL.path
        if protectedPaths.contains(path) {
            return .denied(reason: "Protected location")
        }
        if Self.protectedSystemPrefixes.contains(where: { path.hasPrefix($0) }) {
            return .denied(reason: "System location")
        }
        return .allowed
    }
}

public struct IgnoreListPolicy: RemovalPolicy {
    private let store: any IgnoreListStoring

    public init(store: any IgnoreListStoring) {
        self.store = store
    }

    public func verdict(for url: URL) -> RemovalVerdict {
        store.isIgnored(url) ? .denied(reason: "In your ignore list") : .allowed
    }
}

public protocol RunningApplicationsProviding {
    func runningBundleIdentifiers() -> Set<String>
}

public struct RunningApplicationPolicy: RemovalPolicy {
    private let runningApplicationsProvider: any RunningApplicationsProviding

    public init(runningApplicationsProvider: any RunningApplicationsProviding) {
        self.runningApplicationsProvider = runningApplicationsProvider
    }

    public func verdict(for url: URL) -> RemovalVerdict {
        let lowercasedComponents = url.pathComponents.map { $0.lowercased() }
        let runningOwner = runningApplicationsProvider.runningBundleIdentifiers().first { bundleIdentifier in
            let lowercasedIdentifier = bundleIdentifier.lowercased()
            return lowercasedComponents.contains { component in
                component == lowercasedIdentifier || component.hasPrefix(lowercasedIdentifier + ".")
            }
        }
        guard let runningOwner else { return .allowed }
        return .denied(reason: "\(runningOwner) is running")
    }
}
