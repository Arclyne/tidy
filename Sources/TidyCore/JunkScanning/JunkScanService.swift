import Foundation

public struct JunkScanService {
    private let scanners: [any JunkScanner]

    public init(scanners: [any JunkScanner]) {
        self.scanners = scanners
    }

    public func scan() async -> [JunkCategoryResult] {
        let scannedItemsByCategory = await withTaskGroup(of: (JunkCategory, [ScanItem]).self) { group -> [JunkCategory: [ScanItem]] in
            for scanner in scanners {
                group.addTask {
                    (scanner.category, await scanner.scan())
                }
            }

            var itemsByCategory: [JunkCategory: [ScanItem]] = [:]
            for await (category, items) in group {
                itemsByCategory[category, default: []].append(contentsOf: items)
            }
            return itemsByCategory
        }

        return JunkCategory.allCases.compactMap { category in
            guard let items = scannedItemsByCategory[category], !items.isEmpty else { return nil }
            return JunkCategoryResult(category: category, items: items.sorted { $0.size > $1.size })
        }
    }
}
