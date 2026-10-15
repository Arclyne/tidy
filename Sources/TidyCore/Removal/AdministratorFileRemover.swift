import Foundation

public protocol PrivilegedCommandRunning {
    func run(shellCommand: String) async -> Bool
}

public struct AppleScriptPrivilegedCommandRunner: PrivilegedCommandRunning {
    private static let osascriptURL = URL(fileURLWithPath: "/usr/bin/osascript")

    public init() {}

    public func run(shellCommand: String) async -> Bool {
        let appleScriptLiteral = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let process = Process()
        process.executableURL = Self.osascriptURL
        process.arguments = ["-e", "do shell script \"\(appleScriptLiteral)\" with administrator privileges"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}

struct AdministratorRemovalScript {
    private static let systemLaunchDaemonsPrefix = "/Library/LaunchDaemons/"

    let trashDirectory: URL
    let ownerIdentifier: uid_t
    let uniqueSuffix: String

    func command(for urls: [URL]) -> String {
        urls.enumerated()
            .flatMap { index, url in steps(moving: url, to: trashDestination(for: url, index: index)) }
            .joined(separator: "; ")
    }

    func trashDestination(for url: URL, index: Int) -> URL {
        let baseName = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        let suffixedName = "\(baseName) \(uniqueSuffix)-\(index)"
        let fileName = pathExtension.isEmpty ? suffixedName : "\(suffixedName).\(pathExtension)"
        return trashDirectory.appendingPathComponent(fileName)
    }

    private func steps(moving url: URL, to destination: URL) -> [String] {
        var steps: [String] = []
        if url.path.hasPrefix(Self.systemLaunchDaemonsPrefix) {
            steps.append("/bin/launchctl bootout system \(Self.quoted(url.path)) 2>/dev/null")
        }
        steps.append("/bin/mv \(Self.quoted(url.path)) \(Self.quoted(destination.path))")
        steps.append("/usr/sbin/chown -R \(ownerIdentifier) \(Self.quoted(destination.path))")
        return steps
    }

    static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

public struct AdministratorFileRemover: FileRemoving {
    private static let suffixFormat = "yyyyMMdd-HHmmss"

    private let commandRunner: any PrivilegedCommandRunning
    private let trashDirectory: URL
    private let fileSystem: any FileSystemReading

    public init(
        commandRunner: any PrivilegedCommandRunning,
        trashDirectory: URL,
        fileSystem: any FileSystemReading
    ) {
        self.commandRunner = commandRunner
        self.trashDirectory = trashDirectory
        self.fileSystem = fileSystem
    }

    public func remove(_ items: [ScanItem]) async -> RemovalReport {
        guard !items.isEmpty else { return RemovalReport() }

        let script = AdministratorRemovalScript(
            trashDirectory: trashDirectory,
            ownerIdentifier: getuid(),
            uniqueSuffix: Self.uniqueSuffix()
        )
        let wasApproved = await commandRunner.run(shellCommand: script.command(for: items.map(\.url)))
        let failureReason = wasApproved
            ? "Could not be moved to the Trash even with administrator rights"
            : "Administrator approval was not given"

        var report = RemovalReport()
        for item in items {
            if fileSystem.fileExists(at: item.url) {
                report.failures.append(RemovalFailure(item: item, reason: failureReason))
            } else {
                report.removedItems.append(item)
            }
        }
        return report
    }

    private static func uniqueSuffix() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = suffixFormat
        return formatter.string(from: Date())
    }
}
