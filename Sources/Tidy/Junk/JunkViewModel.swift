import Foundation
import TidyCore

@MainActor
final class JunkViewModel: ObservableObject, ItemSelecting {
    @Published private(set) var results: [JunkCategoryResult] = []
    @Published var selectedItemIDs: Set<URL> = []
    @Published var isDryRun = false
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var hasScanned = false
    @Published private(set) var lastReport: RemovalReport?
    @Published private(set) var lastReportWasDryRun = false

    private let scanService: JunkScanService
    private let ignoreListStore: any IgnoreListStoring
    private let liveRemover: any FileRemoving
    private let dryRunRemover: any FileRemoving

    init(dependencies: AppDependencies) {
        scanService = dependencies.junkScanService
        ignoreListStore = dependencies.ignoreListStore
        liveRemover = dependencies.liveRemover
        dryRunRemover = dependencies.dryRunRemover
    }

    var totalSize: Int64 {
        results.reduce(0) { $0 + $1.totalSize }
    }

    var selectedItems: [ScanItem] {
        results.flatMap(\.items).filter { selectedItemIDs.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.totalSize
    }

    var isBusy: Bool {
        isScanning || isCleaning
    }

    func scan() {
        guard !isBusy else { return }
        isScanning = true
        lastReport = nil
        Task {
            let scannedResults = await scanService.scan()
            results = removingIgnoredItems(from: scannedResults)
            selectedItemIDs = Set(results.flatMap(\.items).filter(\.isSelectedByDefault).map(\.id))
            hasScanned = true
            isScanning = false
        }
    }

    func cleanSelectedItems() {
        let itemsToRemove = selectedItems
        guard !itemsToRemove.isEmpty, !isBusy else { return }
        isCleaning = true
        let isSimulatedCleanup = isDryRun
        let remover = isSimulatedCleanup ? dryRunRemover : liveRemover
        Task {
            let report = await remover.remove(itemsToRemove)
            lastReport = report
            lastReportWasDryRun = isSimulatedCleanup
            if !isSimulatedCleanup {
                dropFromResults(Set(report.removedItems.map(\.id)))
            }
            isCleaning = false
        }
    }

    func ignore(_ item: ScanItem) {
        ignoreListStore.ignore(item.url)
        dropFromResults([item.id])
    }

    private func dropFromResults(_ itemIDs: Set<URL>) {
        results = results.compactMap { result in
            let remainingItems = result.items.filter { !itemIDs.contains($0.id) }
            return remainingItems.isEmpty ? nil : JunkCategoryResult(category: result.category, items: remainingItems)
        }
        selectedItemIDs.subtract(itemIDs)
    }

    private func removingIgnoredItems(from scannedResults: [JunkCategoryResult]) -> [JunkCategoryResult] {
        let ignoredURLs = ignoreListStore.ignoredURLs()
        guard !ignoredURLs.isEmpty else { return scannedResults }
        return scannedResults.compactMap { result in
            let visibleItems = result.items.filter { !ignoreListStore.isIgnored($0.url) }
            return visibleItems.isEmpty ? nil : JunkCategoryResult(category: result.category, items: visibleItems)
        }
    }
}
