import Foundation
import Security

public protocol EntitlementsReading {
    func applicationGroups(of bundleURL: URL) -> [String]
}

public struct CodeSignatureEntitlementsReader: EntitlementsReading {
    private static let applicationGroupsEntitlement = "com.apple.security.application-groups"

    public init() {}

    public func applicationGroups(of bundleURL: URL) -> [String] {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode
        else { return [] }

        var signingInformation: CFDictionary?
        let signingFlags = SecCSFlags(rawValue: UInt32(kSecCSSigningInformation))
        guard SecCodeCopySigningInformation(staticCode, signingFlags, &signingInformation) == errSecSuccess,
              let information = signingInformation as? [String: Any],
              let entitlements = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        else { return [] }

        return entitlements[Self.applicationGroupsEntitlement] as? [String] ?? []
    }
}
