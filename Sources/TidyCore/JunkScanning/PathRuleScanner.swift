import Foundation

public struct PathRuleScanner: JunkScanner {
    private static let ignoredFileNames: Set<String> = [".DS_Store", ".localized"]

    public let category: JunkCategory
    private let rules: [JunkRule]
    private let fileSystem: any FileSystemReading
    private let pathResolver: PathPatternResolver

    public init(category: JunkCategory, rules: [JunkRule], fileSystem: any FileSystemReading) {
        self.category = category
        self.rules = rules.filter { $0.category == category }
        self.fileSystem = fileSystem
        self.pathResolver = PathPatternResolver(fileSystem: fileSystem)
    }

    public func scan() async -> [ScanItem] {
        rules.flatMap { items(matching: $0) }
    }

    private func items(matching rule: JunkRule) -> [ScanItem] {
        let excludedNames = Set(rule.excludedNames).union(Self.ignoredFileNames)
        let resolvedRoots = pathResolver.resolve(rule.path)

        let candidateURLs: [URL]
        switch rule.scope {
        case .itself:
            candidateURLs = resolvedRoots
        case .children:
            candidateURLs = resolvedRoots.flatMap { fileSystem.contentsOfDirectory(at: $0) }
        }

        return candidateURLs
            .filter { !excludedNames.contains($0.lastPathComponent) }
            .map { ScanItem(url: $0, size: fileSystem.allocatedSize(of: $0), isSelectedByDefault: rule.isSelectedByDefault($0)) }
            .filter { $0.size > 0 }
    }
}
