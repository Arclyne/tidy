import Foundation
import TidyCore

@MainActor
final class UninstallerViewModel: ObservableObject, ItemSelecting {
    @Published private(set) var applications: [InstalledApplication] = []
    @Published var searchText = ""
    @Published var selectedApplicationID: InstalledApplication.ID? {
        didSet {
            guard oldValue != selectedApplicationID else { return }
            loadResiduesForSelectedApplication()
        }
    }
    @Published private(set) var residueReport: ApplicationResidueReport?
    @Published var selectedItemIDs: Set<URL> = []
    @Published private(set) var isLoadingApplications = false
    @Published private(set) var isLoadingResidues = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var lastReport: RemovalReport?

    private let applicationCatalog: any ApplicationCatalog
    private let residueCollectorFactory: ResidueCollectorFactory
    private let uninstallCoordinator: UninstallCoordinator
    private var residueLoadingTask: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        applicationCatalog = dependencies.applicationCatalog
        residueCollectorFactory = dependencies.residueCollectorFactory
        uninstallCoordinator = dependencies.uninstallCoordinator
    }

    var filteredApplications: [InstalledApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return applications }
        return applications.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedItems: [ScanItem] {
        residueReport?.allItems.filter { selectedItemIDs.contains($0.id) } ?? []
    }

    var selectedSize: Int64 {
        selectedItems.totalSize
    }

    func loadApplicationsIfNeeded() {
        guard applications.isEmpty else { return }
        reloadApplications()
    }

    func reloadApplications() {
        guard !isLoadingApplications else { return }
        isLoadingApplications = true
        let catalog = applicationCatalog
        Task {
            let installedApplications = await Task.detached(priority: .userInitiated) {
                catalog.installedApplications()
            }.value
            applications = installedApplications
            isLoadingApplications = false
        }
    }

    func uninstallSelectedItems() {
        guard let report = residueReport, !isUninstalling else { return }
        let itemsToRemove = selectedItems
        guard !itemsToRemove.isEmpty else { return }
        isUninstalling = true
        Task {
            let removalReport = await uninstallCoordinator.uninstall(itemsToRemove, from: report)
            let removedIDs = Set(removalReport.removedItems.map(\.id))
            if removedIDs.contains(report.application.bundleURL) {
                applications.removeAll { $0.id == report.application.id }
            }
            residueReport = report.removing(removedIDs)
            selectedItemIDs.subtract(removedIDs)
            lastReport = removalReport
            isUninstalling = false
        }
    }

    private func loadResiduesForSelectedApplication() {
        residueLoadingTask?.cancel()
        residueReport = nil
        selectedItemIDs = []
        lastReport = nil
        isLoadingResidues = false

        guard let application = applications.first(where: { $0.id == selectedApplicationID }) else { return }
        isLoadingResidues = true
        let collector = residueCollectorFactory.makeCollector(installedApplications: applications)
        residueLoadingTask = Task {
            let report = await Task.detached(priority: .userInitiated) {
                collector.collect(for: application)
            }.value
            guard !Task.isCancelled else { return }
            residueReport = report
            selectedItemIDs = Set(report.allItems.map(\.id))
            isLoadingResidues = false
        }
    }
}

private extension ApplicationResidueReport {
    func removing(_ itemIDs: Set<URL>) -> ApplicationResidueReport {
        let remainingGroups = groups.compactMap { groupResult -> ResidueGroupResult? in
            let remainingItems = groupResult.items.filter { !itemIDs.contains($0.id) }
            return remainingItems.isEmpty ? nil : ResidueGroupResult(group: groupResult.group, items: remainingItems)
        }
        return ApplicationResidueReport(application: application, groups: remainingGroups)
    }
}
