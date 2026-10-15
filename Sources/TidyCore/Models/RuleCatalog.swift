import Foundation

public protocol RuleCatalog {
    func rules() throws -> [JunkRule]
}

public enum RuleCatalogError: Error {
    case missingBundledRules
}

public struct JSONRuleCatalog: RuleCatalog {
    private struct RuleDocument: Decodable {
        let version: Int
        let rules: [JunkRule]
    }

    private let data: Data

    public init(data: Data) {
        self.data = data
    }

    public static func bundled() throws -> JSONRuleCatalog {
        if let applicationRulesURL = Bundle.main.url(forResource: "rules", withExtension: "json") {
            return JSONRuleCatalog(data: try Data(contentsOf: applicationRulesURL))
        }
        guard let packageRulesURL = Bundle.module.url(forResource: "rules", withExtension: "json") else {
            throw RuleCatalogError.missingBundledRules
        }
        return JSONRuleCatalog(data: try Data(contentsOf: packageRulesURL))
    }

    public func rules() throws -> [JunkRule] {
        try JSONDecoder().decode(RuleDocument.self, from: data).rules
    }
}
