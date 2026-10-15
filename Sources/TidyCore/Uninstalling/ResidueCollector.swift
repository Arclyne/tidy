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
    private let systemLibraryDirectory: URL

    public init(
        fileSystem: any FileSystemReading,
        systemLibraryDirectory: URL = URL(fileURLWithPath: "/Library")
    ) {
        self.fileSystem = fileSystem
        self.systemLibraryDirectory = systemLibraryDirectory
    }

    public func makeCollector(installedApplications: [InstalledApplication]) -> ResidueCollector {
        let userLibraryDirectory = fileSystem.homeDirectory.appendingPathComponent("Library")
        let bundleIdentifierMatcher = ExclusiveResidueMatcher(
            matcher: BundleIdentifierMatcher(),
            installedApplications: installedApplications
        )
        let bundleIdentifierOrNameMatcher = CompositeResidueMatcher(
            matchers: [bundleIdentifierMatcher, NameWordsMatcher()]
        )

        func userFolder(_ relativePath: String) -> URL {
            userLibraryDirectory.appendingPathComponent(relativePath)
        }

        func systemFolder(_ relativePath: String) -> URL {
            systemLibraryDirectory.appendingPathComponent(relativePath)
        }

        let fetchers: [any ResidueFetcher] = [
            DirectoryResidueFetcher(
                group: .container,
                directories: [userFolder("Containers")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            GroupContainerResidueFetcher(
                groupContainersDirectory: userFolder("Group Containers"),
                installedApplications: installedApplications,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .preferences,
                directories: [userFolder("Preferences"), userFolder("Preferences/ByHost"), systemFolder("Preferences")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .applicationSupport,
                directories: [userFolder("Application Support"), systemFolder("Application Support")],
                matcher: bundleIdentifierOrNameMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .caches,
                directories: [userFolder("Caches"), systemFolder("Caches")],
                matcher: bundleIdentifierOrNameMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .logs,
                directories: [userFolder("Logs"), systemFolder("Logs")],
                matcher: bundleIdentifierOrNameMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .crashReports,
                directories: [
                    userFolder("Logs/DiagnosticReports"),
                    userFolder("Logs/DiagnosticReports/Retired"),
                    userFolder("Application Support/CrashReporter")
                ],
                matcher: CrashReportMatcher(),
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .savedState,
                directories: [userFolder("Saved Application State")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .webData,
                directories: [userFolder("HTTPStorages"), userFolder("WebKit"), userFolder("Cookies")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            LaunchAgentResidueFetcher(
                launchAgentDirectories: [
                    userFolder("LaunchAgents"),
                    systemFolder("LaunchAgents"),
                    systemFolder("LaunchDaemons")
                ],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            ),
            DirectoryResidueFetcher(
                group: .privilegedHelpers,
                directories: [systemFolder("PrivilegedHelperTools")],
                matcher: bundleIdentifierMatcher,
                fileSystem: fileSystem
            )
        ]

        return ResidueCollector(fetchers: fetchers, fileSystem: fileSystem)
    }
}
