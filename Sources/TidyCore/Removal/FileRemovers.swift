import Foundation

public protocol FileRemoving {
    func remove(_ items: [ScanItem]) async -> RemovalReport
}

public struct TrashFileRemover: FileRemoving {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        var report = RemovalReport()
        for item in items {
            do {
                try fileManager.trashItem(at: item.url, resultingItemURL: nil)
                report.removedItems.append(item)
            } catch {
                report.failures.append(RemovalFailure(item: item, error: error))
            }
        }
        return report
    }
}

public struct PermanentFileRemover: FileRemoving {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        var report = RemovalReport()
        for item in items {
            do {
                try fileManager.removeItem(at: item.url)
                report.removedItems.append(item)
            } catch {
                report.failures.append(RemovalFailure(item: item, error: error))
            }
        }
        return report
    }
}

public struct DryRunFileRemover: FileRemoving {
    public init() {}

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        RemovalReport(removedItems: items)
    }
}

public struct PolicyGuardedFileRemover: FileRemoving {
    private let policy: any RemovalPolicy
    private let remover: any FileRemoving

    public init(policy: any RemovalPolicy, remover: any FileRemoving) {
        self.policy = policy
        self.remover = remover
    }

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        var allowedItems: [ScanItem] = []
        var deniedItems: [RemovalFailure] = []
        for item in items {
            switch policy.verdict(for: item.url) {
            case .allowed:
                allowedItems.append(item)
            case .denied(let reason):
                deniedItems.append(RemovalFailure(item: item, reason: reason))
            }
        }
        let removalReport = await remover.remove(allowedItems)
        return removalReport + RemovalReport(failures: deniedItems)
    }
}

public struct TrashBinAwareFileRemover: FileRemoving {
    private let trashDirectory: URL
    private let trashedItemRemover: any FileRemoving
    private let regularItemRemover: any FileRemoving

    public init(
        trashDirectory: URL,
        trashedItemRemover: any FileRemoving,
        regularItemRemover: any FileRemoving
    ) {
        self.trashDirectory = trashDirectory
        self.trashedItemRemover = trashedItemRemover
        self.regularItemRemover = regularItemRemover
    }

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        let trashPathPrefix = trashDirectory.standardizedFileURL.path + "/"
        let itemsAlreadyInTrash = items.filter { $0.url.standardizedFileURL.path.hasPrefix(trashPathPrefix) }
        let itemsOutsideTrash = items.filter { !$0.url.standardizedFileURL.path.hasPrefix(trashPathPrefix) }

        let trashedItemsReport = await trashedItemRemover.remove(itemsAlreadyInTrash)
        let regularItemsReport = await regularItemRemover.remove(itemsOutsideTrash)
        return trashedItemsReport + regularItemsReport
    }
}

public struct EscalatingFileRemover: FileRemoving {
    private let primaryRemover: any FileRemoving
    private let escalatedRemover: any FileRemoving
    private let escalatableRootPaths: [String]

    public init(
        primaryRemover: any FileRemoving,
        escalatedRemover: any FileRemoving,
        escalatableRoots: [URL]
    ) {
        self.primaryRemover = primaryRemover
        self.escalatedRemover = escalatedRemover
        self.escalatableRootPaths = escalatableRoots.map { $0.standardizedFileURL.path + "/" }
    }

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        let primaryReport = await primaryRemover.remove(items)
        let escalatableFailures = primaryReport.failures.filter { isEscalatable($0) }
        guard !escalatableFailures.isEmpty else { return primaryReport }

        let escalatedIDs = Set(escalatableFailures.map(\.id))
        let remainingFailures = primaryReport.failures.filter { !escalatedIDs.contains($0.id) }
        let escalatedReport = await escalatedRemover.remove(escalatableFailures.map(\.item))
        return RemovalReport(removedItems: primaryReport.removedItems, failures: remainingFailures) + escalatedReport
    }

    private func isEscalatable(_ failure: RemovalFailure) -> Bool {
        let path = failure.item.url.standardizedFileURL.path
        return failure.isPermissionDenied && escalatableRootPaths.contains { path.hasPrefix($0) }
    }
}
