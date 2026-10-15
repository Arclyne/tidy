import Foundation

public enum JunkCategory: String, Codable, CaseIterable, Sendable {
    case userCaches
    case containerCaches
    case applicationCaches
    case userLogs
    case containerLogs
    case developerJunk
    case trash
    case brokenPreferences
    case brokenLaunchAgents

    public var title: String {
        switch self {
        case .userCaches: return "User Caches"
        case .containerCaches: return "App Container Caches"
        case .applicationCaches: return "Browser & Electron Caches"
        case .userLogs: return "User Logs"
        case .containerLogs: return "App Container Logs"
        case .developerJunk: return "Xcode Junk"
        case .trash: return "Trash"
        case .brokenPreferences: return "Broken Preferences"
        case .brokenLaunchAgents: return "Broken Launch Agents"
        }
    }

    public var summary: String {
        switch self {
        case .userCaches: return "Files apps keep to load faster. They are rebuilt when needed."
        case .containerCaches: return "Caches stored inside sandboxed app containers."
        case .applicationCaches: return "Chromium and Electron caches such as Code Cache and GPUCache."
        case .userLogs: return "Activity and crash logs written by your apps."
        case .containerLogs: return "Logs stored inside sandboxed app containers."
        case .developerJunk: return "Derived data, simulator caches, archives and device support files."
        case .trash: return "Items already in your Trash. These are deleted permanently."
        case .brokenPreferences: return "Preference files that can no longer be read."
        case .brokenLaunchAgents: return "Launch agents that point to programs that no longer exist."
        }
    }
}

public struct JunkCategoryResult: Identifiable, Sendable {
    public let category: JunkCategory
    public let items: [ScanItem]

    public var id: JunkCategory { category }
    public var totalSize: Int64 { items.totalSize }

    public init(category: JunkCategory, items: [ScanItem]) {
        self.category = category
        self.items = items
    }
}
