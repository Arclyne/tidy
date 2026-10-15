import XCTest
@testable import TidyCore

final class UninstallingTests: XCTestCase {
    private var home: TemporaryHome!

    override func setUpWithError() throws {
        home = try TemporaryHome()
    }

    override func tearDown() {
        home.remove()
        home = nil
    }

    func testApplicationCatalogReadsBundlesInNestedFoldersAndSkipsDuplicates() throws {
        try home.createApplication(named: "Alpha", bundleIdentifier: "com.example.alpha")
        try home.createApplication(named: "Utilities/Beta", bundleIdentifier: "com.example.beta")
        try home.createApplication(named: "Alpha Copy", bundleIdentifier: "com.example.alpha")
        let catalog = DirectoryApplicationCatalog(
            searchDirectories: [home.url.appendingPathComponent("Applications")],
            fileSystem: home.fileSystem,
            bundleReader: InfoPlistApplicationReader(fileSystem: home.fileSystem, entitlementsReader: NoEntitlementsReader())
        )

        let applications = catalog.installedApplications()

        XCTAssertEqual(applications.map(\.bundleIdentifier).sorted(), ["com.example.alpha", "com.example.beta"])
    }

    func testResidueCollectorGathersRelatedFilesFromTheLibrary() throws {
        let bundleURL = try home.createApplication(named: "Example", bundleIdentifier: "com.example.Example")
        try home.createFile("Library/Preferences/com.example.Example.plist")
        try home.createFile("Library/Application Support/Example/data.db")
        try home.createFile("Library/Caches/com.example.Example/cache.db")
        try home.createFile("Library/Containers/com.example.Example/Data/file")
        try home.createFile("Library/Saved Application State/com.example.Example.savedState/window.data")
        try home.createFile("Library/Application Support/Unrelated/data.db")
        let application = InstalledApplication(bundleURL: bundleURL, bundleIdentifier: "com.example.Example", name: "Example")
        let collector = ResidueCollectorFactory(fileSystem: home.fileSystem)
            .makeCollector(installedApplications: [application])

        let report = collector.collect(for: application)

        XCTAssertEqual(report.items(in: .application).map(\.name), ["Example.app"])
        XCTAssertEqual(report.items(in: .preferences).map(\.name), ["com.example.Example.plist"])
        XCTAssertEqual(report.items(in: .applicationSupport).map(\.name), ["Example"])
        XCTAssertEqual(report.items(in: .caches).map(\.name), ["com.example.Example"])
        XCTAssertEqual(report.items(in: .container).map(\.name), ["com.example.Example"])
        XCTAssertEqual(report.items(in: .savedState).map(\.name), ["com.example.Example.savedState"])
        XCTAssertFalse(report.allItems.contains { $0.name == "Unrelated" })
    }

    func testCrashReportsNamedAfterTheApplicationAreCollected() throws {
        let bundleURL = try home.createApplication(named: "CrossOver", bundleIdentifier: "com.codeweavers.CrossOver")
        try home.createFile("Library/Application Support/CrashReporter/CrossOver_EEF2DE7A-3C8F-5B1D-9A3E-1F2C3D4E5F60.plist")
        try home.createFile("Library/Logs/DiagnosticReports/CrossOver-2026-10-14-101010.ips")
        try home.createFile("Library/Logs/DiagnosticReports/CrossOverHelper-2026-10-14-101010.ips")
        try home.createFile("Library/Logs/DiagnosticReports/Safari-2026-10-14-101010.ips")
        let application = InstalledApplication(bundleURL: bundleURL, bundleIdentifier: "com.codeweavers.CrossOver", name: "CrossOver")

        let report = ResidueCollectorFactory(fileSystem: home.fileSystem)
            .makeCollector(installedApplications: [application])
            .collect(for: application)

        XCTAssertEqual(
            Set(report.items(in: .crashReports).map(\.name)),
            ["CrossOver_EEF2DE7A-3C8F-5B1D-9A3E-1F2C3D4E5F60.plist", "CrossOver-2026-10-14-101010.ips"]
        )
    }

    func testLaunchAgentRunningFromInsideTheBundleIsCollected() throws {
        let bundleURL = try home.createApplication(named: "Syncer", bundleIdentifier: "io.syncer.app")
        try home.createFile(
            "Library/LaunchAgents/io.syncer.helper.plist",
            contents: propertyListData([
                "Label": "io.syncer.helper",
                "Program": bundleURL.appendingPathComponent("Contents/MacOS/Syncer").path
            ])
        )
        let application = InstalledApplication(bundleURL: bundleURL, bundleIdentifier: "io.syncer.app", name: "Syncer")

        let report = ResidueCollectorFactory(fileSystem: home.fileSystem)
            .makeCollector(installedApplications: [application])
            .collect(for: application)

        XCTAssertEqual(report.items(in: .launchAgents).map(\.name), ["io.syncer.helper.plist"])
    }

    func testGroupContainersSharedWithOtherApplicationsAreKept() throws {
        try home.createFile("Library/Group Containers/TEAM123456.com.example.shared/file")
        try home.createFile("Library/Group Containers/TEAM123456.com.example.word/file")
        let word = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Word.app"),
            bundleIdentifier: "com.example.word",
            name: "Word",
            applicationGroups: ["TEAM123456.com.example.shared", "TEAM123456.com.example.word"]
        )
        let excel = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Excel.app"),
            bundleIdentifier: "com.example.excel",
            name: "Excel",
            applicationGroups: ["TEAM123456.com.example.shared"]
        )
        let fetcher = GroupContainerResidueFetcher(
            groupContainersDirectory: home.url.appendingPathComponent("Library/Group Containers"),
            installedApplications: [word, excel],
            fileSystem: home.fileSystem
        )

        XCTAssertEqual(fetcher.residues(of: word).map(\.lastPathComponent), ["TEAM123456.com.example.word"])
    }

    func testUninstallCoordinatorStopsWhenTheApplicationKeepsRunning() async {
        let application = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Stubborn.app"),
            bundleIdentifier: "com.example.stubborn",
            name: "Stubborn"
        )
        let item = ScanItem(url: application.bundleURL, size: 100)
        let report = ApplicationResidueReport(application: application, groups: [ResidueGroupResult(group: .application, items: [item])])
        let remover = RecordingFileRemover()
        let coordinator = UninstallCoordinator(
            terminator: StubbornApplicationTerminator(),
            launchAgentUnloader: IgnoringLaunchAgentUnloader(),
            remover: remover
        )

        let removalReport = await coordinator.uninstall([item], from: report)

        XCTAssertTrue(remover.receivedItems.isEmpty)
        XCTAssertEqual(removalReport.failures.map(\.item), [item])
    }

    func testLeftoverFinderReportsOnlyOrphanedIdentifiers() throws {
        try home.createFile("Library/Preferences/com.removed.tool.plist")
        try home.createFile("Library/Preferences/com.example.alpha.plist")
        try home.createFile("Library/Preferences/com.example.alpha-helper.plist")
        try home.createFile("Library/Preferences/com.apple.finder.plist")
        try home.createFile("Library/Preferences/com.registered.agent.plist")
        try home.createFile("Library/Preferences/loginwindow.plist")
        let alpha = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Alpha.app"),
            bundleIdentifier: "com.example.alpha",
            name: "Alpha"
        )
        let finder = LeftoverFinder(
            searchDirectories: [home.url.appendingPathComponent("Library/Preferences")],
            applicationCatalog: StaticApplicationCatalog(applications: [alpha]),
            applicationLocator: StaticApplicationLocator(installedIdentifiers: ["com.registered.agent"]),
            fileSystem: home.fileSystem
        )

        let leftovers = finder.findLeftovers()

        XCTAssertEqual(leftovers.map(\.name), ["com.removed.tool.plist"])
        XCTAssertFalse(leftovers.contains { $0.isSelectedByDefault })
    }

    func testLeftoverFinderNormalizesGroupAndTeamPrefixes() {
        XCTAssertEqual(LeftoverFinder.removingGroupAndTeamPrefixes(from: "group.com.example.shared"), "com.example.shared")
        XCTAssertEqual(LeftoverFinder.removingGroupAndTeamPrefixes(from: "ubf8t346g9.com.microsoft.office"), "com.microsoft.office")
        XCTAssertEqual(LeftoverFinder.removingGroupAndTeamPrefixes(from: "com.example.app"), "com.example.app")
    }
}

private struct StubbornApplicationTerminator: ApplicationTerminating {
    func terminate(_ application: InstalledApplication) async -> Bool {
        false
    }
}

private struct IgnoringLaunchAgentUnloader: LaunchAgentUnloading {
    func unload(plistURL: URL) async {}
}
