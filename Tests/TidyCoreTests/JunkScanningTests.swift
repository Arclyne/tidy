import XCTest
@testable import TidyCore

final class JunkScanningTests: XCTestCase {
    private var home: TemporaryHome!

    override func setUpWithError() throws {
        home = try TemporaryHome()
    }

    override func tearDown() {
        home.remove()
        home = nil
    }

    func testPathRuleScannerListsChildrenAndSkipsExcludedNames() async throws {
        try home.createFile("Library/Caches/com.example.app/cache.db")
        try home.createFile("Library/Caches/CloudKit/records.db")
        try home.createFile("Library/Caches/.DS_Store")
        let rule = JunkRule(id: "user-caches", category: .userCaches, path: "~/Library/Caches", excludedNames: ["CloudKit"])
        let scanner = PathRuleScanner(category: .userCaches, rules: [rule], fileSystem: home.fileSystem)

        let items = await scanner.scan()

        XCTAssertEqual(items.map(\.name), ["com.example.app"])
        XCTAssertGreaterThan(items.first?.size ?? 0, 0)
    }

    func testPathRuleScannerResolvesWildcardComponents() async throws {
        try home.createFile("Library/Containers/com.example.one/Data/Library/Caches/first.bin")
        try home.createFile("Library/Containers/com.example.two/Data/Library/Caches/second.bin")
        try home.createFile("Library/Containers/com.example.three/Data/Library/Preferences/settings.plist")
        let rule = JunkRule(id: "container-caches", category: .containerCaches, path: "~/Library/Containers/*/Data/Library/Caches")
        let scanner = PathRuleScanner(category: .containerCaches, rules: [rule], fileSystem: home.fileSystem)

        let items = await scanner.scan()

        XCTAssertEqual(Set(items.map(\.name)), ["first.bin", "second.bin"])
    }

    func testPathRuleScannerKeepsTheDefaultSelectionOfItsRule() async throws {
        try home.createFile("Library/Developer/Xcode/Archives/2026-10-14/App.xcarchive/Info.plist")
        let rule = JunkRule(
            id: "xcode-archives",
            category: .developerJunk,
            path: "~/Library/Developer/Xcode/Archives",
            selectedByDefault: false
        )
        let scanner = PathRuleScanner(category: .developerJunk, rules: [rule], fileSystem: home.fileSystem)

        let items = await scanner.scan()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.isSelectedByDefault, false)
    }

    func testPathRuleScannerLeavesSystemCachesUnselected() async throws {
        try home.createFile("Library/Caches/com.apple.Safari/cache.db")
        try home.createFile("Library/Caches/familycircled/cache.db")
        try home.createFile("Library/Caches/com.spotify.client/cache.db")
        try home.createFile("Library/Containers/com.apple.Photos/Data/Library/Caches/thumbs.db")
        let rules = [
            JunkRule(
                id: "user-caches",
                category: .userCaches,
                path: "~/Library/Caches",
                unselectedComponentPrefixes: ["com.apple.", "familycircled"]
            ),
            JunkRule(
                id: "container-caches",
                category: .userCaches,
                path: "~/Library/Containers/*/Data/Library/Caches",
                unselectedComponentPrefixes: ["com.apple."]
            )
        ]
        let scanner = PathRuleScanner(category: .userCaches, rules: rules, fileSystem: home.fileSystem)

        let items = await scanner.scan()
        let selectedNames = Set(items.filter(\.isSelectedByDefault).map(\.name))

        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(selectedNames, ["com.spotify.client"])
    }

    func testBrokenPreferencesScannerFlagsUnreadablePropertyLists() async throws {
        try home.createFile("Library/Preferences/com.example.valid.plist", contents: propertyListData(["key": "value"]))
        try home.createFile(
            "Library/Preferences/com.example.broken.plist",
            contents: Data("<?xml version=\"1.0\"?><plist><dict><key>broken".utf8)
        )

        let items = await BrokenPreferencesScanner(fileSystem: home.fileSystem).scan()

        XCTAssertEqual(items.map(\.name), ["com.example.broken.plist"])
    }

    func testBrokenLaunchAgentScannerFlagsMissingExecutables() async throws {
        try home.createFile(
            "Library/LaunchAgents/com.example.gone.plist",
            contents: propertyListData([
                "Label": "com.example.gone",
                "ProgramArguments": ["/Applications/Gone.app/Contents/MacOS/Gone", "--background"]
            ])
        )
        try home.createFile(
            "Library/LaunchAgents/com.example.healthy.plist",
            contents: propertyListData(["Label": "com.example.healthy", "Program": "/bin/ls"])
        )

        let items = await BrokenLaunchAgentScanner(fileSystem: home.fileSystem).scan()

        XCTAssertEqual(items.map(\.name), ["com.example.gone.plist"])
    }

    func testChromiumCacheScannerOnlyLooksInsideChromiumDataFolders() async throws {
        try home.createFile("Library/Application Support/Slack/Code Cache/js/index")
        try home.createFile("Library/Application Support/Slack/Cache/Cache_Data/data_0")
        try home.createFile("Library/Application Support/Notes Keeper/Cache/notes.db")

        let items = await ChromiumCacheScanner(fileSystem: home.fileSystem).scan()
        let foundPaths = Set(items.map { "\($0.url.deletingLastPathComponent().lastPathComponent)/\($0.name)" })

        XCTAssertEqual(foundPaths, ["Slack/Code Cache", "Slack/Cache"])
    }

    func testScanServiceGroupsResultsByCategoryInDeclaredOrder() async throws {
        try home.createFile("Library/Logs/example.log")
        try home.createFile("Library/Caches/com.example.app/cache.db")
        let rules = [
            JunkRule(id: "logs", category: .userLogs, path: "~/Library/Logs"),
            JunkRule(id: "caches", category: .userCaches, path: "~/Library/Caches")
        ]
        let scanners = try JunkScannerFactory(
            fileSystem: home.fileSystem,
            ruleCatalog: StaticRuleCatalog(storedRules: rules)
        ).makeScanners()

        let results = await JunkScanService(scanners: scanners).scan()

        XCTAssertEqual(results.map(\.category), [.userCaches, .userLogs])
    }

    func testBundledRuleCatalogDecodes() throws {
        let rules = try JSONRuleCatalog.bundled().rules()

        XCTAssertFalse(rules.isEmpty)
        XCTAssertTrue(rules.contains { $0.id == "user-caches" && $0.excludedNames.contains("CloudKit") })
        XCTAssertTrue(rules.contains { $0.id == "xcode-archives" && !$0.selectedByDefault })
    }
}
