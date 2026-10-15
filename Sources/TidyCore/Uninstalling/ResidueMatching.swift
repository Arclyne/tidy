import Foundation

public protocol ResidueMatching {
    func matches(fileName: String, application: InstalledApplication) -> Bool
}

public struct BundleIdentifierMatcher: ResidueMatching {
    private static let strippableExtensions: Set<String> = ["plist", "savedState", "binarycookies", "log"]

    public init() {}

    public func matches(fileName: String, application: InstalledApplication) -> Bool {
        let candidateIdentifier = Self.identifierCandidate(from: fileName).lowercased()
        let bundleIdentifier = application.bundleIdentifier.lowercased()
        return candidateIdentifier == bundleIdentifier || candidateIdentifier.hasPrefix(bundleIdentifier + ".")
    }

    static func identifierCandidate(from fileName: String) -> String {
        var candidate = fileName
        while let separatorRange = candidate.range(of: ".", options: .backwards),
              strippableExtensions.contains(String(candidate[separatorRange.upperBound...])) {
            candidate = String(candidate[..<separatorRange.lowerBound])
        }
        return candidate
    }
}

public struct NameWordsMatcher: ResidueMatching {
    private static let minimumNormalizedNameLength = 4
    private static let strippableExtensions: Set<String> = ["plist", "savedState", "binarycookies", "log", "app"]
    private static let genericNames: Set<String> = [
        "adobe", "agent", "apple", "cache", "caches", "data", "electron", "google",
        "helper", "launcher", "logs", "microsoft", "update", "updater"
    ]

    public init() {}

    public func matches(fileName: String, application: InstalledApplication) -> Bool {
        let fileWords = Self.words(in: Self.removingKnownExtension(from: fileName))
        guard !fileWords.isEmpty else { return false }

        return application.matchingNames.contains { applicationName in
            let applicationWords = Self.words(in: applicationName)
            let normalizedApplicationName = applicationWords.joined()
            guard normalizedApplicationName.count >= Self.minimumNormalizedNameLength,
                  !Self.genericNames.contains(normalizedApplicationName)
            else { return false }

            return fileWords == applicationWords
                || fileWords.joined() == normalizedApplicationName
                || Self.isVersionedVariant(fileWords: fileWords, applicationWords: applicationWords)
        }
    }

    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func isVersionedVariant(fileWords: [String], applicationWords: [String]) -> Bool {
        guard fileWords.count > applicationWords.count,
              Array(fileWords.prefix(applicationWords.count)) == applicationWords
        else { return false }
        return fileWords.dropFirst(applicationWords.count).allSatisfy { word in
            word.allSatisfy { $0.isNumber }
        }
    }

    private static func removingKnownExtension(from fileName: String) -> String {
        guard let separatorRange = fileName.range(of: ".", options: .backwards),
              strippableExtensions.contains(String(fileName[separatorRange.upperBound...]))
        else { return fileName }
        return String(fileName[..<separatorRange.lowerBound])
    }
}

public struct CrashReportMatcher: ResidueMatching {
    private static let minimumNameLength = 3
    private static let reportNameSeparators: Set<Character> = ["_", "-", "."]

    public init() {}

    public func matches(fileName: String, application: InstalledApplication) -> Bool {
        let lowercasedFileName = fileName.lowercased()
        return application.matchingNames.contains { applicationName in
            let lowercasedApplicationName = applicationName.lowercased()
            guard lowercasedApplicationName.count >= Self.minimumNameLength,
                  lowercasedFileName.hasPrefix(lowercasedApplicationName),
                  let separator = lowercasedFileName.dropFirst(lowercasedApplicationName.count).first
            else { return false }
            return Self.reportNameSeparators.contains(separator)
        }
    }
}

public struct CompositeResidueMatcher: ResidueMatching {
    private let matchers: [any ResidueMatching]

    public init(matchers: [any ResidueMatching]) {
        self.matchers = matchers
    }

    public func matches(fileName: String, application: InstalledApplication) -> Bool {
        matchers.contains { $0.matches(fileName: fileName, application: application) }
    }
}

public struct ExclusiveResidueMatcher: ResidueMatching {
    private let matcher: any ResidueMatching
    private let installedApplications: [InstalledApplication]

    public init(matcher: any ResidueMatching, installedApplications: [InstalledApplication]) {
        self.matcher = matcher
        self.installedApplications = installedApplications
    }

    public func matches(fileName: String, application: InstalledApplication) -> Bool {
        guard matcher.matches(fileName: fileName, application: application) else { return false }
        return !installedApplications.contains { otherApplication in
            otherApplication.bundleIdentifier != application.bundleIdentifier
                && otherApplication.bundleIdentifier.count > application.bundleIdentifier.count
                && matcher.matches(fileName: fileName, application: otherApplication)
        }
    }
}
