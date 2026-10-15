import Foundation
import TidyCore

@MainActor
final class LeftoversViewModel: ObservableObject, ItemSelecting {
    @Published private(set) var leftovers: [ScanItem] = []
    @Published var selectedItemIDs: Set<URL> = []
    @Published var isDryRun = false
    @Published private(set) var isScanning = false
    @Published private(set) var isRemoving = false
    @Published private(set) var hasScanned = false
    @Published private(set) var lastReport: RemovalReport?
    @Published private(set) var lastReportWasDryRun = false

    private let leftoverFinder: LeftoverFinder
    private let liveRemover: any FileRemoving
    private let dryRunRemover: any FileRemoving

    init(dependencies: AppDependencies) {
        leftoverFinder = dependencies.leftoverFinder
        liveRemover = dependencies.liveRemover
        dryRunRemover = dependencies.dryRunRemover
    }

    var totalSize: Int64 {
        leftovers.totalSize
    }

    var selectedItems: [ScanItem] {
        leftovers.filter { selectedItemIDs.contains($0.id) }
    }

    var selectedSize: Int64 {
        selectedItems.totalSize
    }

    var isBusy: Bool {
        isScanning || isRemoving
    }

    func scan() {
        guard !isBusy else { return }
        isScanning = true
        lastReport = nil
        let finder = leftoverFinder
        Task {
            let foundLeftovers = await Task.detached(priority: .userInitiated) {
                finder.findLeftovers()
            }.value
            leftovers = foundLeftovers
            selectedItemIDs = Set(foundLeftovers.filter(\.isSelectedByDefault).map(\.id))
            hasScanned = true
            isScanning = false
        }
    }

    func removeSelectedItems() {
        let itemsToRemove = selectedItems
        guard !itemsToRemove.isEmpty, !isBusy else { return }
        isRemoving = true
        let isSimulatedRemoval = isDryRun
        let remover = isSimulatedRemoval ? dryRunRemover : liveRemover
        Task {
            let report = await remover.remove(itemsToRemove)
            lastReport = report
            lastReportWasDryRun = isSimulatedRemoval
            if !isSimulatedRemoval {
                let removedIDs = Set(report.removedItems.map(\.id))
                leftovers.removeAll { removedIDs.contains($0.id) }
                selectedItemIDs.subtract(removedIDs)
            }
            isRemoving = false
        }
    }
}
