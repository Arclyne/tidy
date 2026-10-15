import Foundation

public protocol ApplicationTerminating {
    func terminate(_ application: InstalledApplication) async -> Bool
}

public protocol LaunchAgentUnloading {
    func unload(plistURL: URL) async
}

public struct UninstallCoordinator {
    private let terminator: any ApplicationTerminating
    private let launchAgentUnloader: any LaunchAgentUnloading
    private let remover: any FileRemoving

    public init(
        terminator: any ApplicationTerminating,
        launchAgentUnloader: any LaunchAgentUnloading,
        remover: any FileRemoving
    ) {
        self.terminator = terminator
        self.launchAgentUnloader = launchAgentUnloader
        self.remover = remover
    }

    public func uninstall(_ selectedItems: [ScanItem], from report: ApplicationResidueReport) async -> RemovalReport {
        guard !selectedItems.isEmpty else { return RemovalReport() }

        guard await terminator.terminate(report.application) else {
            let reason = "\(report.application.name) is still running. Quit it and try again."
            return RemovalReport(failures: selectedItems.map { RemovalFailure(item: $0, reason: reason) })
        }

        let launchAgentURLs = Set(report.items(in: .launchAgents).map(\.url))
        for item in selectedItems where launchAgentURLs.contains(item.url) {
            await launchAgentUnloader.unload(plistURL: item.url)
        }

        return await remover.remove(selectedItems)
    }
}
