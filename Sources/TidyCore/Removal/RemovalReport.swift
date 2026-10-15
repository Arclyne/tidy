import Foundation

public struct RemovalFailure: Identifiable, Sendable {
    public let item: ScanItem
    public let reason: String

    public var id: URL { item.url }

    public init(item: ScanItem, reason: String) {
        self.item = item
        self.reason = reason
    }
}

public struct RemovalReport: Sendable {
    public var removedItems: [ScanItem]
    public var failures: [RemovalFailure]

    public var freedBytes: Int64 { removedItems.totalSize }

    public init(removedItems: [ScanItem] = [], failures: [RemovalFailure] = []) {
        self.removedItems = removedItems
        self.failures = failures
    }

    public static func + (lhs: RemovalReport, rhs: RemovalReport) -> RemovalReport {
        RemovalReport(
            removedItems: lhs.removedItems + rhs.removedItems,
            failures: lhs.failures + rhs.failures
        )
    }
}
