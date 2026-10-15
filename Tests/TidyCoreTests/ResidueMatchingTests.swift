import XCTest
@testable import TidyCore

final class ResidueMatchingTests: XCTestCase {
    private let visualStudioCode = InstalledApplication(
        bundleURL: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
        bundleIdentifier: "com.microsoft.VSCode",
        name: "Visual Studio Code",
        matchingNames: ["Visual Studio Code", "Code"]
    )

    func testBundleIdentifierMatcherAcceptsFilesNamedAfterTheBundle() {
        let matcher = BundleIdentifierMatcher()

        XCTAssertTrue(matcher.matches(fileName: "com.microsoft.VSCode.plist", application: visualStudioCode))
        XCTAssertTrue(matcher.matches(fileName: "com.microsoft.VSCode.ShipIt", application: visualStudioCode))
        XCTAssertTrue(matcher.matches(fileName: "com.microsoft.VSCode.savedState", application: visualStudioCode))
        XCTAssertTrue(matcher.matches(fileName: "com.microsoft.vscode.binarycookies", application: visualStudioCode))
    }

    func testBundleIdentifierMatcherRejectsLookalikeIdentifiers() {
        let matcher = BundleIdentifierMatcher()

        XCTAssertFalse(matcher.matches(fileName: "com.microsoft.VSCodeInsiders.plist", application: visualStudioCode))
        XCTAssertFalse(matcher.matches(fileName: "com.microsoft.plist", application: visualStudioCode))
    }

    func testNameWordsMatcherAcceptsExactJoinedAndVersionedNames() {
        let matcher = NameWordsMatcher()

        XCTAssertTrue(matcher.matches(fileName: "Code", application: visualStudioCode))
        XCTAssertTrue(matcher.matches(fileName: "Visual Studio Code", application: visualStudioCode))
        XCTAssertTrue(matcher.matches(fileName: "VisualStudioCode", application: visualStudioCode))
        XCTAssertTrue(matcher.matches(fileName: "Visual Studio Code 2", application: visualStudioCode))
    }

    func testNameWordsMatcherRejectsPartialAndIdentifierNames() {
        let matcher = NameWordsMatcher()

        XCTAssertFalse(matcher.matches(fileName: "Visual Studio", application: visualStudioCode))
        XCTAssertFalse(matcher.matches(fileName: "com.microsoft.VSCode", application: visualStudioCode))
        XCTAssertFalse(matcher.matches(fileName: "Code Helper Tools", application: visualStudioCode))
    }

    func testNameWordsMatcherIgnoresShortAndGenericNames() {
        let shortNamedApplication = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Go.app"),
            bundleIdentifier: "com.example.go",
            name: "Go"
        )
        let genericNamedApplication = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Google.app"),
            bundleIdentifier: "com.example.google",
            name: "Google"
        )
        let matcher = NameWordsMatcher()

        XCTAssertFalse(matcher.matches(fileName: "Go", application: shortNamedApplication))
        XCTAssertFalse(matcher.matches(fileName: "Google", application: genericNamedApplication))
    }

    func testExclusiveMatcherLeavesFilesOfMoreSpecificApplications() {
        let chrome = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            bundleIdentifier: "com.google.Chrome",
            name: "Google Chrome"
        )
        let canary = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Google Chrome Canary.app"),
            bundleIdentifier: "com.google.Chrome.canary",
            name: "Google Chrome Canary"
        )
        let matcher = ExclusiveResidueMatcher(matcher: BundleIdentifierMatcher(), installedApplications: [chrome, canary])

        XCTAssertTrue(matcher.matches(fileName: "com.google.Chrome.plist", application: chrome))
        XCTAssertFalse(matcher.matches(fileName: "com.google.Chrome.canary.plist", application: chrome))
        XCTAssertTrue(matcher.matches(fileName: "com.google.Chrome.canary.plist", application: canary))
    }
}
