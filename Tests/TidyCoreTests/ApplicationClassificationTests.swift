import XCTest
@testable import TidyCore

final class ApplicationClassificationTests: XCTestCase {
    private var home: TemporaryHome!

    override func setUpWithError() throws {
        home = try TemporaryHome()
    }

    override func tearDown() {
        home.remove()
        home = nil
    }

    func testVendorComesFromTheBundleIdentifier() {
        XCTAssertEqual(ApplicationVendor(bundleIdentifier: "com.apple.Keynote"), .apple)
        XCTAssertEqual(ApplicationVendor(bundleIdentifier: "com.microsoft.Word"), .microsoft)
        XCTAssertEqual(ApplicationVendor(bundleIdentifier: "com.google.Chrome"), .google)
        XCTAssertEqual(ApplicationVendor(bundleIdentifier: "com.jetbrains.intellij"), .jetBrains)
        XCTAssertEqual(ApplicationVendor(bundleIdentifier: "com.codeweavers.CrossOver"), .other)
    }

    func testSourceDetectorRecognizesAppStoreAndSetappApplications() throws {
        let appStoreBundle = try home.createApplication(named: "Pages", bundleIdentifier: "com.apple.iWork.Pages")
        try home.createFile("Applications/Pages.app/Contents/_MASReceipt/receipt")
        let setappBundle = try home.createApplication(named: "Setapp/CleanShot X", bundleIdentifier: "pl.maketheweb.cleanshotx-setapp")
        let directBundle = try home.createApplication(named: "CrossOver", bundleIdentifier: "com.codeweavers.CrossOver")
        let detector = ApplicationSourceDetector(fileSystem: home.fileSystem)

        XCTAssertEqual(detector.source(ofApplicationAt: appStoreBundle, bundleIdentifier: "com.apple.iWork.Pages"), .appStore)
        XCTAssertEqual(detector.source(ofApplicationAt: setappBundle, bundleIdentifier: "pl.maketheweb.cleanshotx-setapp"), .setapp)
        XCTAssertEqual(detector.source(ofApplicationAt: directBundle, bundleIdentifier: "com.codeweavers.CrossOver"), .other)
    }

    func testApplicationReaderFillsSourceAndLastUsedDate() throws {
        let lastUsedDate = Date(timeIntervalSince1970: 1_760_000_000)
        let bundleURL = try home.createApplication(named: "Pages", bundleIdentifier: "com.apple.iWork.Pages")
        try home.createFile("Applications/Pages.app/Contents/_MASReceipt/receipt")
        let reader = InfoPlistApplicationReader(
            fileSystem: home.fileSystem,
            entitlementsReader: NoEntitlementsReader(),
            usageReader: StaticUsageReader(lastUsedDate: lastUsedDate)
        )

        let application = try XCTUnwrap(reader.application(at: bundleURL))

        XCTAssertEqual(application.source, .appStore)
        XCTAssertEqual(application.lastUsedDate, lastUsedDate)
        XCTAssertEqual(application.vendor, .apple)
    }

    func testListFiltersMatchUsageSourceVendorAndChecks() {
        let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)
        let oldDate = referenceDate.addingTimeInterval(-ApplicationListFilter.unusedThreshold - 60)
        let recentDate = referenceDate.addingTimeInterval(-60)
        let unusedApplication = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Old.app"),
            bundleIdentifier: "com.microsoft.Old",
            name: "Old",
            source: .appStore,
            lastUsedDate: oldDate
        )
        let recentApplication = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Recent.app"),
            bundleIdentifier: "com.example.recent",
            name: "Recent",
            lastUsedDate: recentDate
        )
        let neverTrackedApplication = InstalledApplication(
            bundleURL: URL(fileURLWithPath: "/Applications/Unknown.app"),
            bundleIdentifier: "com.example.unknown",
            name: "Unknown"
        )
        let checkedIDs: Set<URL> = [recentApplication.id]

        func matches(_ filter: ApplicationListFilter) -> [String] {
            [unusedApplication, recentApplication, neverTrackedApplication]
                .filter { filter.includes($0, checkedIDs: checkedIDs, referenceDate: referenceDate) }
                .map(\.name)
        }

        XCTAssertEqual(matches(.all), ["Old", "Recent", "Unknown"])
        XCTAssertEqual(matches(.unused), ["Old"])
        XCTAssertEqual(matches(.checked), ["Recent"])
        XCTAssertEqual(matches(.source(.appStore)), ["Old"])
        XCTAssertEqual(matches(.vendor(.microsoft)), ["Old"])
        XCTAssertEqual(matches(.vendor(.other)), ["Recent", "Unknown"])
    }
}
