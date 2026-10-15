import XCTest
@testable import TidyCore

final class AdministratorRemovalTests: XCTestCase {
    private let trashDirectory = URL(fileURLWithPath: "/Users/tester/.Trash")

    func testScriptMovesItemsIntoTheTrashWithUniqueNamesAndOwnership() {
        let script = AdministratorRemovalScript(trashDirectory: trashDirectory, ownerIdentifier: 501, uniqueSuffix: "20261014-221000")

        let command = script.command(for: [URL(fileURLWithPath: "/Applications/Pages.app")])

        XCTAssertEqual(
            command,
            "/bin/mv '/Applications/Pages.app' '/Users/tester/.Trash/Pages 20261014-221000-0.app'; "
                + "/usr/sbin/chown -R 501 '/Users/tester/.Trash/Pages 20261014-221000-0.app'"
        )
    }

    func testScriptBootsOutSystemLaunchDaemonsBeforeMovingThem() {
        let script = AdministratorRemovalScript(trashDirectory: trashDirectory, ownerIdentifier: 501, uniqueSuffix: "s")

        let command = script.command(for: [URL(fileURLWithPath: "/Library/LaunchDaemons/com.example.helper.plist")])

        XCTAssertTrue(command.hasPrefix("/bin/launchctl bootout system '/Library/LaunchDaemons/com.example.helper.plist' 2>/dev/null; "))
    }

    func testScriptQuotesSingleQuotesInPaths() {
        XCTAssertEqual(AdministratorRemovalScript.quoted("/Applications/Angel's App.app"), "'/Applications/Angel'\\''s App.app'")
    }

    func testAdministratorRemoverReportsItemsThatStillExist() async throws {
        let home = try TemporaryHome()
        defer { home.remove() }
        let removedURL = home.url.appendingPathComponent("Applications/Gone.app")
        let remainingURL = try home.createFile("Applications/Stays.app/Contents/Info.plist").deletingLastPathComponent().deletingLastPathComponent()
        let runner = RecordingCommandRunner { _ in true }
        let remover = AdministratorFileRemover(
            commandRunner: runner,
            trashDirectory: home.url.appendingPathComponent(".Trash"),
            fileSystem: home.fileSystem
        )

        let report = await remover.remove([
            ScanItem(url: removedURL, size: 10),
            ScanItem(url: remainingURL, size: 20)
        ])

        XCTAssertEqual(runner.receivedCommands.count, 1)
        XCTAssertEqual(report.removedItems.map(\.url), [removedURL])
        XCTAssertEqual(report.failures.map(\.item.url), [remainingURL])
    }

    func testEscalatingRemoverOnlyRetriesDeniedItemsUnderEscalatableRoots() async {
        let applicationItem = ScanItem(url: URL(fileURLWithPath: "/Applications/Pages.app"), size: 100)
        let userItem = ScanItem(url: URL(fileURLWithPath: "/Users/tester/Library/Caches/com.example"), size: 5)
        let escalatedRecorder = RecordingFileRemover()
        let remover = EscalatingFileRemover(
            primaryRemover: FailingFileRemover(isPermissionDenied: true),
            escalatedRemover: escalatedRecorder,
            escalatableRoots: [URL(fileURLWithPath: "/Applications")]
        )

        let report = await remover.remove([applicationItem, userItem])

        XCTAssertEqual(escalatedRecorder.receivedItems, [applicationItem])
        XCTAssertEqual(report.removedItems, [applicationItem])
        XCTAssertEqual(report.failures.map(\.item), [userItem])
    }

    func testEscalatingRemoverIgnoresFailuresThatAreNotPermissionProblems() async {
        let applicationItem = ScanItem(url: URL(fileURLWithPath: "/Applications/Pages.app"), size: 100)
        let escalatedRecorder = RecordingFileRemover()
        let remover = EscalatingFileRemover(
            primaryRemover: FailingFileRemover(isPermissionDenied: false),
            escalatedRemover: escalatedRecorder,
            escalatableRoots: [URL(fileURLWithPath: "/Applications")]
        )

        let report = await remover.remove([applicationItem])

        XCTAssertTrue(escalatedRecorder.receivedItems.isEmpty)
        XCTAssertEqual(report.failures.map(\.item), [applicationItem])
    }

    func testPermissionErrorsAreRecognized() {
        let cocoaError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        let wrappedPOSIXError = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteUnknownError,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))]
        )
        let unrelatedError = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)

        XCTAssertTrue(RemovalFailure.isPermissionError(cocoaError))
        XCTAssertTrue(RemovalFailure.isPermissionError(wrappedPOSIXError))
        XCTAssertFalse(RemovalFailure.isPermissionError(unrelatedError))
    }
}
