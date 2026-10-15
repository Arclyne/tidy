import Foundation

public struct RemovalFailure: Identifiable, Sendable {
    public let item: ScanItem
    public let reason: String
    public let isPermissionDenied: Bool

    public var id: URL { item.url }

    public init(item: ScanItem, reason: String, isPermissionDenied: Bool = false) {
        self.item = item
        self.reason = reason
        self.isPermissionDenied = isPermissionDenied
    }

    public init(item: ScanItem, error: Error) {
        self.init(
            item: item,
            reason: error.localizedDescription,
            isPermissionDenied: Self.isPermissionError(error)
        )
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let permissionCocoaCodes = [NSFileWriteNoPermissionError, NSFileReadNoPermissionError]
        let permissionPOSIXCodes = [Int(EPERM), Int(EACCES)]
        let failure = error as NSError
        if failure.domain == NSCocoaErrorDomain && permissionCocoaCodes.contains(failure.code) {
            return true
        }
        if failure.domain == NSPOSIXErrorDomain && permissionPOSIXCodes.contains(failure.code) {
            return true
        }
        guard let underlyingFailure = failure.userInfo[NSUnderlyingErrorKey] as? NSError else { return false }
        return underlyingFailure.domain == NSPOSIXErrorDomain && permissionPOSIXCodes.contains(underlyingFailure.code)
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
