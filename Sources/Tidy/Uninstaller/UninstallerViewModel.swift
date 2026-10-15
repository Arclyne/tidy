import SwiftUI
import TidyCore

struct ApplicationFilterSection: Identifiable {
    let title: String
    let filters: [ApplicationListFilter]

    var id: String { title }
}

@MainActor
final class UninstallerViewModel: ObservableObject, ItemSelecting {
    @Published private(set) var applications: [InstalledApplication] = []
    @Published var searchText = ""
    @Published var filter: ApplicationListFilter = .all
    @Published var checkedApplicationIDs: Set<URL> = []
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
    @Published private(set) var batchReport: RemovalReport?

    let filterSections: [ApplicationFilterSection] = [
        ApplicationFilterSection(title: "Show", filters: [.all, .unused, .checked]),
        ApplicationFilterSection(title: "Stores", filters: ApplicationSource.allCases.map { ApplicationListFilter.source($0) }),
        ApplicationFilterSection(title: "Vendors", filters: ApplicationVendor.allCases.map { ApplicationListFilter.vendor($0) })
    ]

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
        let referenceDate = Date()
        return applications.filter { application in
            guard filter.includes(application, checkedIDs: checkedApplicationIDs, referenceDate: referenceDate) else {
                return false
            }
            guard !query.isEmpty else { return true }
            return application.name.localizedCaseInsensitiveContains(query)
                || application.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var checkedApplications: [InstalledApplication] {
        applications.filter { checkedApplicationIDs.contains($0.id) }
    }

    var selectedItems: [ScanItem] {
        residueReport?.allItems.filter { selectedItemIDs.contains($0.id) } ?? []
    }

    var selectedSize: Int64 {
        selectedItems.totalSize
    }

    func applicationCount(for filter: ApplicationListFilter) -> Int {
        let referenceDate = Date()
        return applications.filter {
            filter.includes($0, checkedIDs: checkedApplicationIDs, referenceDate: referenceDate)
        }.count
    }

    func checkBinding(for application: InstalledApplication) -> Binding<Bool> {
        Binding(
            get: { [unowned self] in
                self.checkedApplicationIDs.contains(application.id)
            },
            set: { [unowned self] isChecked in
                if isChecked {
                    self.checkedApplicationIDs.insert(application.id)
                } else {
                    self.checkedApplicationIDs.remove(application.id)
                }
            }
        )
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
            checkedApplicationIDs.formIntersection(installedApplications.map(\.id))
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
            forgetApplications(removedIn: removedIDs)
            residueReport = report.removing(removedIDs)
            selectedItemIDs.subtract(removedIDs)
            lastReport = removalReport
            isUninstalling = false
        }
    }

    func uninstallCheckedApplications() {
        let applicationsToRemove = checkedApplications
        guard !applicationsToRemove.isEmpty, !isUninstalling else { return }
        isUninstalling = true
        batchReport = nil
        selectedApplicationID = nil
        let collector = residueCollectorFactory.makeCollector(installedApplications: applications)
        let coordinator = uninstallCoordinator
        Task {
            var combinedReport = RemovalReport()
            for application in applicationsToRemove {
                let residueReport = await Task.detached(priority: .userInitiated) {
                    collector.collect(for: application)
                }.value
                let applicationReport = await coordinator.uninstall(residueReport.allItems, from: residueReport)
                combinedReport = combinedReport + applicationReport
            }
            forgetApplications(removedIn: Set(combinedReport.removedItems.map(\.id)))
            batchReport = combinedReport
            isUninstalling = false
        }
    }

    private func forgetApplications(removedIn removedIDs: Set<URL>) {
        applications.removeAll { removedIDs.contains($0.bundleURL) }
        checkedApplicationIDs.subtract(removedIDs)
    }

    private func loadResiduesForSelectedApplication() {
        residueLoadingTask?.cancel()
        residueReport = nil
        selectedItemIDs = []
        lastReport = nil
        isLoadingResidues = false

        guard let application = applications.first(where: { $0.id == selectedApplicationID }) else { return }
        batchReport = nil
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
