import SwiftUI
import TidyCore

struct JunkView: View {
    @ObservedObject var viewModel: JunkViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let report = viewModel.lastReport {
                RemovalSummaryView(report: report, isDryRun: viewModel.lastReportWasDryRun)
            }
            content
        }
        .padding()
        .navigationTitle("Junk")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Junk")
                    .font(.title2.bold())
                Text(headerSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Dry run", isOn: $viewModel.isDryRun)
                .toggleStyle(.switch)
                .help("Simulate the cleanup without deleting anything")
            Button("Scan") { viewModel.scan() }
                .disabled(viewModel.isBusy)
            Button(viewModel.isDryRun ? "Simulate Cleanup" : "Clean") { viewModel.cleanSelectedItems() }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItemIDs.isEmpty || viewModel.isBusy)
        }
    }

    private var headerSubtitle: String {
        guard viewModel.hasScanned else {
            return "Scan your Mac for caches, logs and other files you can safely remove."
        }
        return "\(viewModel.totalSize.formattedByteCount) found · \(viewModel.selectedSize.formattedByteCount) selected"
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning {
            ProgressView("Looking for junk…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.hasScanned {
            PlaceholderView(
                systemImage: "sparkles",
                title: "Ready to scan",
                message: "Nothing is deleted until you press Clean. Items go to the Trash, except those already in it."
            )
        } else if viewModel.results.isEmpty {
            PlaceholderView(
                systemImage: "checkmark.seal",
                title: "Your Mac is tidy",
                message: "No junk was found in the locations Tidy checks."
            )
        } else {
            List {
                ForEach(viewModel.results) { result in
                    DisclosureGroup {
                        ForEach(result.items) { item in
                            ScanItemRow(
                                item: item,
                                isSelected: viewModel.selectionBinding(for: item),
                                onIgnore: { viewModel.ignore(item) }
                            )
                        }
                    } label: {
                        CategoryHeaderRow(
                            title: result.category.title,
                            summary: result.category.summary,
                            size: result.totalSize,
                            itemSelections: viewModel.selectionBindings(for: result.items)
                        )
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}
