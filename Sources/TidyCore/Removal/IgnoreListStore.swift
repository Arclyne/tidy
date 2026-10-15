import Foundation

public protocol IgnoreListStoring {
    func ignoredURLs() -> [URL]
    func ignore(_ url: URL)
    func stopIgnoring(_ url: URL)
}

extension IgnoreListStoring {
    public func isIgnored(_ url: URL) -> Bool {
        let candidatePath = url.standardizedFileURL.path
        return ignoredURLs().contains { ignoredURL in
            let ignoredPath = ignoredURL.standardizedFileURL.path
            return candidatePath == ignoredPath || candidatePath.hasPrefix(ignoredPath + "/")
        }
    }
}

public final class UserDefaultsIgnoreListStore: IgnoreListStoring {
    private let userDefaults: UserDefaults
    private let storageKey: String

    public init(userDefaults: UserDefaults = .standard, storageKey: String = "ignoredPaths") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    public func ignoredURLs() -> [URL] {
        storedPaths().map { URL(fileURLWithPath: $0) }
    }

    public func ignore(_ url: URL) {
        var paths = Set(storedPaths())
        paths.insert(url.standardizedFileURL.path)
        userDefaults.set(paths.sorted(), forKey: storageKey)
    }

    public func stopIgnoring(_ url: URL) {
        var paths = Set(storedPaths())
        paths.remove(url.standardizedFileURL.path)
        userDefaults.set(paths.sorted(), forKey: storageKey)
    }

    private func storedPaths() -> [String] {
        userDefaults.stringArray(forKey: storageKey) ?? []
    }
}
