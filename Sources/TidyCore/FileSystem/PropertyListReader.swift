import Foundation

struct PropertyListReader {
    private let fileSystem: any FileSystemReading

    init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
    }

    func dictionary(at url: URL) -> [String: Any]? {
        guard let data = fileSystem.contents(of: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }

    func isReadable(at url: URL) -> Bool {
        guard let data = fileSystem.contents(of: url) else { return true }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil
    }
}
