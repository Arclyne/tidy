import Foundation

public protocol JunkScanner {
    var category: JunkCategory { get }
    func scan() async -> [ScanItem]
}
