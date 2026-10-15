import Foundation

public enum ResidueGroup: String, CaseIterable, Sendable {
    case application
    case container
    case groupContainer
    case preferences
    case applicationSupport
    case caches
    case logs
    case crashReports
    case savedState
    case webData
    case launchAgents
    case privilegedHelpers

    public var title: String {
        switch self {
        case .application: return "Application"
        case .container: return "Container"
        case .groupContainer: return "Group Containers"
        case .preferences: return "Preferences"
        case .applicationSupport: return "Application Support"
        case .caches: return "Caches"
        case .logs: return "Logs"
        case .crashReports: return "Crash Reports"
        case .savedState: return "Saved State"
        case .webData: return "Web Data & Cookies"
        case .launchAgents: return "Launch Agents & Daemons"
        case .privilegedHelpers: return "Privileged Helpers"
        }
    }
}

public struct ResidueGroupResult: Identifiable, Sendable {
    public let group: ResidueGroup
    public let items: [ScanItem]

    public var id: ResidueGroup { group }
    public var totalSize: Int64 { items.totalSize }

    public init(group: ResidueGroup, items: [ScanItem]) {
        self.group = group
        self.items = items
    }
}

public struct ApplicationResidueReport: Sendable {
    public let application: InstalledApplication
    public let groups: [ResidueGroupResult]

    public var allItems: [ScanItem] { groups.flatMap(\.items) }
    public var totalSize: Int64 { allItems.totalSize }

    public init(application: InstalledApplication, groups: [ResidueGroupResult]) {
        self.application = application
        self.groups = groups
    }

    public func items(in group: ResidueGroup) -> [ScanItem] {
        groups.first { $0.group == group }?.items ?? []
    }
}
