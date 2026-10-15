import AppKit
import SwiftUI
import TidyCore

struct RemovalSummaryView: View {
    let report: RemovalReport
    let isDryRun: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(headline, systemImage: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(report.failures.isEmpty ? Color.green : Color.orange)
            if !report.failures.isEmpty {
                DisclosureGroup("\(report.failures.count) items could not be removed") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(report.failures) { failure in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(failure.item.url.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text(failure.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var headline: String {
        let verb = isDryRun ? "Would free" : "Freed"
        return "\(verb) \(report.freedBytes.formattedByteCount) from \(report.removedItems.count) items"
    }
}

struct FullDiskAccessBanner: View {
    private static let privacySettingsAddress = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Full Disk Access is off")
                    .font(.headline)
                Text("Tidy can't see app containers, the Trash or other protected folders without it. Grant it to Tidy, or to Xcode or Terminal if you run Tidy from there.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings", action: openPrivacySettings)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func openPrivacySettings() {
        guard let settingsURL = URL(string: Self.privacySettingsAddress) else { return }
        NSWorkspace.shared.open(settingsURL)
    }
}

struct PlaceholderView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
