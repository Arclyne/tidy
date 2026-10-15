import XCTest
@testable import TidyCore

final class RemovalTests: XCTestCase {
    private let homeDirectory = URL(fileURLWithPath: "/Users/tester")

    func testProtectedPathPolicyDeniesRootsButAllowsTheirChildren() {
        let policy = ProtectedPathPolicy(homeDirectory: homeDirectory)

        XCTAssertNotEqual(policy.verdict(for: homeDirectory), .allowed)
        XCTAssertNotEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library/Caches")), .allowed)
        XCTAssertNotEqual(policy.verdict(for: URL(fileURLWithPath: "/System/Library/CoreServices")), .allowed)
        XCTAssertNotEqual(policy.verdict(for: URL(fileURLWithPath: "/Applications")), .allowed)
        XCTAssertEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library/Caches/com.example.app")), .allowed)
        XCTAssertEqual(policy.verdict(for: URL(fileURLWithPath: "/Applications/Example.app")), .allowed)
    }

    func testRunningApplicationPolicyProtectsFilesOfRunningApps() {
        let policy = RunningApplicationPolicy(
            runningApplicationsProvider: StaticRunningApplications(identifiers: ["com.example.app"])
        )

        XCTAssertNotEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library/Caches/com.example.app")), .allowed)
        XCTAssertNotEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library/Preferences/com.example.app.helper.plist")), .allowed)
        XCTAssertEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library/Caches/com.example.application")), .allowed)
    }

    func testCompositePolicyReturnsTheFirstDenial() {
        let policy = CompositeRemovalPolicy(policies: [
            ProtectedPathPolicy(homeDirectory: homeDirectory),
            RunningApplicationPolicy(runningApplicationsProvider: StaticRunningApplications(identifiers: ["com.example.app"]))
        ])

        XCTAssertEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library")), .denied(reason: "Protected location"))
        XCTAssertEqual(policy.verdict(for: homeDirectory.appendingPathComponent("Library/Logs/other.log")), .allowed)
    }

    func testPolicyGuardedRemoverReportsDeniedItemsAsFailures() async {
        let allowedItem = ScanItem(url: homeDirectory.appendingPathComponent("Library/Caches/com.example.app"), size: 10)
        let deniedItem = ScanItem(url: homeDirectory.appendingPathComponent("Library/Caches"), size: 20)
        let remover = PolicyGuardedFileRemover(
            policy: ProtectedPathPolicy(homeDirectory: homeDirectory),
            remover: DryRunFileRemover()
        )

        let report = await remover.remove([allowedItem, deniedItem])

        XCTAssertEqual(report.removedItems, [allowedItem])
        XCTAssertEqual(report.failures.map(\.item), [deniedItem])
        XCTAssertEqual(report.freedBytes, 10)
    }

    func testTrashBinAwareRemoverRoutesItemsAlreadyInTheTrash() async {
        let trashDirectory = homeDirectory.appendingPathComponent(".Trash")
        let trashedItem = ScanItem(url: trashDirectory.appendingPathComponent("old.zip"), size: 5)
        let regularItem = ScanItem(url: homeDirectory.appendingPathComponent("Library/Logs/app.log"), size: 7)
        let trashedItemRecorder = RecordingFileRemover()
        let regularItemRecorder = RecordingFileRemover()
        let remover = TrashBinAwareFileRemover(
            trashDirectory: trashDirectory,
            trashedItemRemover: trashedItemRecorder,
            regularItemRemover: regularItemRecorder
        )

        let report = await remover.remove([trashedItem, regularItem])

        XCTAssertEqual(trashedItemRecorder.receivedItems, [trashedItem])
        XCTAssertEqual(regularItemRecorder.receivedItems, [regularItem])
        XCTAssertEqual(report.freedBytes, 12)
    }

    func testIgnoreListStoreMatchesNestedPaths() throws {
        let suiteName = "TidyTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsIgnoreListStore(userDefaults: userDefaults)
        let ignoredFolder = homeDirectory.appendingPathComponent("Library/Caches/com.example.app")

        store.ignore(ignoredFolder)

        XCTAssertTrue(store.isIgnored(ignoredFolder.appendingPathComponent("blob")))
        XCTAssertFalse(store.isIgnored(homeDirectory.appendingPathComponent("Library/Caches/com.example.application")))

        store.stopIgnoring(ignoredFolder)

        XCTAssertFalse(store.isIgnored(ignoredFolder))
    }
}
