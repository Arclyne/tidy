import Foundation

public protocol FileSystemReading {
    var homeDirectory: URL { get }
    func fileExists(at url: URL) -> Bool
    func isDirectory(at url: URL) -> Bool
    func isOnReadOnlyVolume(_ url: URL) -> Bool
    func contentsOfDirectory(at url: URL) -> [URL]
    func contents(of url: URL) -> Data?
    func allocatedSize(of url: URL) -> Int64
}
