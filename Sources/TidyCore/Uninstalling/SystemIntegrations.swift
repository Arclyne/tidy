import AppKit
import CoreServices
import Foundation

public struct SpotlightApplicationUsageReader: ApplicationUsageReading {
    public init() {}

    public func lastUsedDate(ofApplicationAt bundleURL: URL) -> Date? {
        guard let metadataItem = MDItemCreateWithURL(kCFAllocatorDefault, bundleURL as CFURL) else { return nil }
        return MDItemCopyAttribute(metadataItem, kMDItemLastUsedDate) as? Date
    }
}

public struct WorkspaceRunningApplicationsProvider: RunningApplicationsProviding {
    public init() {}

    public func runningBundleIdentifiers() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }
}

public struct WorkspaceApplicationLocator: ApplicationLocating {
    public init() {}

    public func isApplicationInstalled(bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
}

public struct RunningApplicationTerminator: ApplicationTerminating {
    private let pollIntervalNanoseconds: UInt64
    private let maximumPollCount: Int

    public init(pollIntervalNanoseconds: UInt64 = 250_000_000, maximumPollCount: Int = 40) {
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.maximumPollCount = maximumPollCount
    }

    public func terminate(_ application: InstalledApplication) async -> Bool {
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: application.bundleIdentifier)
        guard !runningInstances.isEmpty else { return true }

        for runningInstance in runningInstances {
            _ = runningInstance.terminate()
        }

        for _ in 0..<maximumPollCount {
            if runningInstances.allSatisfy(\.isTerminated) {
                return true
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        return runningInstances.allSatisfy(\.isTerminated)
    }
}

public struct LaunchctlAgentUnloader: LaunchAgentUnloading {
    private static let launchctlURL = URL(fileURLWithPath: "/bin/launchctl")

    public init() {}

    public func unload(plistURL: URL) async {
        let process = Process()
        process.executableURL = Self.launchctlURL
        process.arguments = ["bootout", "gui/\(getuid())", plistURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
    }
}

public protocol FullDiskAccessChecking {
    func hasFullDiskAccess() -> Bool
}

public struct ProtectedFileFullDiskAccessChecker: FullDiskAccessChecking {
    private let probeURL: URL

    public init(homeDirectory: URL) {
        probeURL = homeDirectory.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
    }

    public func hasFullDiskAccess() -> Bool {
        guard let probeHandle = try? FileHandle(forReadingFrom: probeURL) else { return false }
        try? probeHandle.close()
        return true
    }
}
