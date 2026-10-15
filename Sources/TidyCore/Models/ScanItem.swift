import Foundation

public struct ScanItem: Identifiable, Hashable, Sendable {
    public let url: URL
    public let size: Int64
    public let isSelectedByDefault: Bool

    public var id: URL { url }
    public var name: String { url.lastPathComponent }

    public init(url: URL, size: Int64, isSelectedByDefault: Bool = true) {
        self.url = url
        self.size = size
        self.isSelectedByDefault = isSelectedByDefault
    }
}

extension Sequence where Element == ScanItem {
    public var totalSize: Int64 {
        reduce(0) { $0 + $1.size }
    }
}
