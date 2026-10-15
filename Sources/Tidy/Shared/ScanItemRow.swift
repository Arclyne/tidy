import AppKit
import SwiftUI
import TidyCore

struct ScanItemRow: View {
    let item: ScanItem
    @Binding var isSelected: Bool
    var onIgnore: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $isSelected)
                .labelsHidden()
                .toggleStyle(.checkbox)
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                Text(item.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Text(item.size.formattedByteCount)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            if let onIgnore {
                Button("Always Ignore", action: onIgnore)
            }
        }
    }
}

struct CategoryHeaderRow: View {
    let title: String
    let summary: String?
    let size: Int64
    let itemSelections: [Binding<Bool>]

    var body: some View {
        HStack(spacing: 10) {
            Toggle(sources: itemSelections, isOn: \.self) {
                EmptyView()
            }
            .labelsHidden()
            .toggleStyle(.checkbox)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            Text(size.formattedByteCount)
                .font(.headline)
                .monospacedDigit()
        }
    }
}
