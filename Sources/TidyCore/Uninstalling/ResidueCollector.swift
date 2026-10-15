import Foundation

public struct ResidueCollector {
    private let fetchers: [any ResidueFetcher]
    private let fileSystem: any FileSystemReading

    public init(fetchers: [any ResidueFetcher], fileSystem: any FileSystemReading) {
        self.fetchers = fetchers
        self.fileSystem = fileSystem
    }

    public func collect(for application: InstalledApplication) -> ApplicationResidueReport {
        var collectedPaths: Set<String> = [application.bundleURL.standardizedFileURL.path]
        var itemsByGroup: [ResidueGroup: [ScanItem]] = [
            .application: [ScanItem(url: application.bundleURL, size: fileSystem.allocatedSize(of: application.bundleURL))]
        ]

        for fetcher in fetchers {
            let newItems = fetcher.residues(of: application)
                .filter { collectedPaths.insert($0.standardizedFileURL.path).inserted }
                .map { ScanItem(url: $0, size: fileSystem.allocatedSize(of: $0)) }
            itemsByGroup[fetcher.group, default: []].append(contentsOf: newItems)
        }

        let groups = ResidueGroup.allCases.compactMap { group -> ResidueGroupResult? in
            guard let items = itemsByGroup[group], !items.isEmpty else { return nil }
            return ResidueGroupResult(group: group, items: items.sorted { $0.size > $1.size })
        }
        return ApplicationResidueReport(application: application, groups: groups)
    }
}

public struct ResidueCollectorFactory {
    private let fileSystem: any FileSystemReading

    public init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
    }

    public func makeCollector(installedApplications: [InstalledApplication]) -> ResidueCollector {
        let libraryDirectory = fileSystem.homeDirectory.appendingPathComponent("Library")
        let bundleIdentifierMatcher = ExclusiveResidueMatcher(
            matcher: BundleIdentifierMatcher(),
            installedApplications: installedApplications
        )
        let bundleIdentifierOrNameMatcher = CompositeResidueMatcher(
            matchers: [bundleIdentifierMatcher, NameWordsMatcher()]
        )

        func libraryFolder(_ relativePath: String) -> URL {
            libraryDirectory.appendingPathComponent(relativePath)
        }

        let fetchers: [any ResidueFetcher] = [
            DirectoryResidueFetcher(
                group: .container,
                directories: [libraryFolder("Containers")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            GroupContainerResidueFetcher(
                groupContainersDirectory: libraryFolder("Group Containers"),
                installedApplications: installedApplications,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .preferences,
                directories: [libraryFolder("Preferences"), libraryFolder("Preferences/ByHost")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .applicationSupport,
                directories: [libraryFolder("Application Support")],
                matcher: bundleIdentifierOrNameMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .caches,
                directories: [libraryFolder("Caches")],
                matcher: bundleIdentifierOrNameMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .logs,
                directories: [libraryFolder("Logs")],
                matcher: bundleIdentifierOrNameMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .crashReports,
                directories: [
                    libraryFolder("Logs/DiagnosticReports"),
                    libraryFolder("Logs/DiagnosticReports/Retired"),
                    libraryFolder("Application Support/CrashReporter")
                ],
                matcher: CrashReportMatcher(),
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .savedState,
                directories: [libraryFolder("Saved Application State")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .webData,
                directories: [libraryFolder("HTTPStorages"), libraryFolder("WebKit"), libraryFolder("Cookies")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            LaunchAgentResidueFetcher(
                launchAgentsDirectory: libraryFolder("LaunchAgents"),
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            )
        ]

        return ResidueCollector(fetchers: fetchers, fileSystem: fileSystem)
    }
}
