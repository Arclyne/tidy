import Foundation
import TidyCore

struct AppDependencies {
    let junkScanService: JunkScanService
    let ignoreListStore: any IgnoreListStoring
    let liveRemover: any FileRemoving
    let dryRunRemover: any FileRemoving
    let applicationCatalog: any ApplicationCatalog
    let residueCollectorFactory: ResidueCollectorFactory
    let uninstallCoordinator: UninstallCoordinator
    let leftoverFinder: LeftoverFinder
    let fullDiskAccessChecker: any FullDiskAccessChecking

    static func live() -> AppDependencies {
        let fileSystem = LocalFileSystem()
        let homeDirectory = fileSystem.homeDirectory

        let emptyRuleDocument = Data(#"{"version":1,"rules":[]}"#.utf8)
        let ruleCatalog = (try? JSONRuleCatalog.bundled()) ?? JSONRuleCatalog(data: emptyRuleDocument)
        let scanners = (try? JunkScannerFactory(fileSystem: fileSystem, ruleCatalog: ruleCatalog).makeScanners()) ?? []

        let ignoreListStore = UserDefaultsIgnoreListStore()
        let removalPolicy = CompositeRemovalPolicy(policies: [
            ProtectedPathPolicy(homeDirectory: homeDirectory),
            IgnoreListPolicy(store: ignoreListStore),
            RunningApplicationPolicy(runningApplicationsProvider: WorkspaceRunningApplicationsProvider())
        ])

        let liveRemover = PolicyGuardedFileRemover(
            policy: removalPolicy,
            remover: TrashBinAwareFileRemover(
                trashDirectory: homeDirectory.appendingPathComponent(".Trash"),
                trashedItemRemover: PermanentFileRemover(),
                regularItemRemover: TrashFileRemover()
            )
        )
        let dryRunRemover = PolicyGuardedFileRemover(policy: removalPolicy, remover: DryRunFileRemover())

        let applicationCatalog = DirectoryApplicationCatalog(
            searchDirectories: [
                URL(fileURLWithPath: "/Applications"),
                homeDirectory.appendingPathComponent("Applications")
            ],
            fileSystem: fileSystem,
            bundleReader: InfoPlistApplicationReader(
                fileSystem: fileSystem,
                entitlementsReader: CodeSignatureEntitlementsReader()
            )
        )

        let uninstallCoordinator = UninstallCoordinator(
            terminator: RunningApplicationTerminator(),
            launchAgentUnloader: LaunchctlAgentUnloader(),
            remover: liveRemover
        )

        let leftoverFinder = LeftoverFinder(
            searchDirectories: LeftoverFinder.defaultSearchDirectories(homeDirectory: homeDirectory),
            applicationCatalog: applicationCatalog,
            applicationLocator: WorkspaceApplicationLocator(),
            fileSystem: fileSystem
        )

        return AppDependencies(
            junkScanService: JunkScanService(scanners: scanners),
            ignoreListStore: ignoreListStore,
            liveRemover: liveRemover,
            dryRunRemover: dryRunRemover,
            applicationCatalog: applicationCatalog,
            residueCollectorFactory: ResidueCollectorFactory(fileSystem: fileSystem),
            uninstallCoordinator: uninstallCoordinator,
            leftoverFinder: leftoverFinder,
            fullDiskAccessChecker: ProtectedFileFullDiskAccessChecker(homeDirectory: homeDirectory)
        )
    }
}
