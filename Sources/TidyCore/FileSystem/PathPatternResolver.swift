import Foundation

public struct PathPatternResolver {
    private static let wildcardComponent = "*"

    private let fileSystem: any FileSystemReading

    public init(fileSystem: any FileSystemReading) {
        self.fileSystem = fileSystem
    }

    public func resolve(_ pattern: String) -> [URL] {
        let patternComponents = expandingHomeDirectory(in: pattern)
            .split(separator: "/")
            .map(String.init)

        return patternComponents.reduce([URL(fileURLWithPath: "/")]) { matchedURLs, component in
            matchedURLs.flatMap { baseURL in
                matches(of: component, in: baseURL)
            }
        }
    }

    private func matches(of component: String, in baseURL: URL) -> [URL] {
        if component == Self.wildcardComponent {
            return fileSystem.contentsOfDirectory(at: baseURL).filter { fileSystem.isDirectory(at: $0) }
        }
        let candidateURL = baseURL.appendingPathComponent(component)
        return fileSystem.fileExists(at: candidateURL) ? [candidateURL] : []
    }

    private func expandingHomeDirectory(in pattern: String) -> String {
        guard pattern.hasPrefix("~") else { return pattern }
        return fileSystem.homeDirectory.path + pattern.dropFirst()
    }
}
