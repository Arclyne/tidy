import Foundation

public struct JunkScannerFactory {
    private let fileSystem: any FileSystemReading
    private let ruleCatalog: any RuleCatalog

    public init(fileSystem: any FileSystemReading, ruleCatalog: any RuleCatalog) {
        self.fileSystem = fileSystem
        self.ruleCatalog = ruleCatalog
    }

    public func makeScanners() throws -> [any JunkScanner] {
        let rules = try ruleCatalog.rules()
        let categoriesWithRules = Set(rules.map(\.category))

        let ruleBasedScanners: [any JunkScanner] = JunkCategory.allCases
            .filter { categoriesWithRules.contains($0) }
            .map { PathRuleScanner(category: $0, rules: rules, fileSystem: fileSystem) as any JunkScanner }

        let specializedScanners: [any JunkScanner] = [
            ChromiumCacheScanner(fileSystem: fileSystem),
            BrokenPreferencesScanner(fileSystem: fileSystem),
            BrokenLaunchAgentScanner(fileSystem: fileSystem)
        ]

        return ruleBasedScanners + specializedScanners
    }
}
