import Foundation

public struct JunkRule: Codable, Hashable, Sendable {
    public enum Scope: String, Codable, Sendable {
        case itself
        case children
    }

    public let id: String
    public let category: JunkCategory
    public let path: String
    public let scope: Scope
    public let selectedByDefault: Bool
    public let excludedNames: [String]
    public let unselectedComponentPrefixes: [String]

    public init(
        id: String,
        category: JunkCategory,
        path: String,
        scope: Scope = .children,
        selectedByDefault: Bool = true,
        excludedNames: [String] = [],
        unselectedComponentPrefixes: [String] = []
    ) {
        self.id = id
        self.category = category
        self.path = path
        self.scope = scope
        self.selectedByDefault = selectedByDefault
        self.excludedNames = excludedNames
        self.unselectedComponentPrefixes = unselectedComponentPrefixes
    }

    public func isSelectedByDefault(_ url: URL) -> Bool {
        guard selectedByDefault else { return false }
        return !url.pathComponents.contains { component in
            unselectedComponentPrefixes.contains { component.hasPrefix($0) }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case category
        case path
        case scope
        case selectedByDefault
        case excludedNames
        case unselectedComponentPrefixes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        category = try container.decode(JunkCategory.self, forKey: .category)
        path = try container.decode(String.self, forKey: .path)
        scope = try container.decodeIfPresent(Scope.self, forKey: .scope) ?? .children
        selectedByDefault = try container.decodeIfPresent(Bool.self, forKey: .selectedByDefault) ?? true
        excludedNames = try container.decodeIfPresent([String].self, forKey: .excludedNames) ?? []
        unselectedComponentPrefixes = try container.decodeIfPresent([String].self, forKey: .unselectedComponentPrefixes) ?? []
    }
}
