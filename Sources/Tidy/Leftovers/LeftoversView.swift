import SwiftUI
import TidyCore

struct LeftoversView: View {
    @ObservedObject var viewModel: LeftoversViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let report = viewModel.lastReport {
                RemovalSummaryView(report: report, isDryRun: viewModel.lastReportWasDryRun)
            }
            content
        }
        .padding()
        .navigationTitle("Leftovers")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Leftovers")
                    .font(.title2.bold())
                Text(headerSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Dry run", isOn: $viewModel.isDryRun)
                .toggleStyle(.switch)
            Button("Scan") { viewModel.scan() }
                .disabled(viewModel.isBusy)
            Button(viewModel.isDryRun ? "Simulate Removal" : "Move to Trash") { viewModel.removeSelectedItems() }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedItemIDs.isEmpty || viewModel.isBusy)
        }
    }

    private var headerSubtitle: String {
        guard viewModel.hasScanned else {
            return "Files left behind by apps that are no longer installed."
        }
        return "\(viewModel.totalSize.formattedByteCount) found · \(viewModel.selectedSize.formattedByteCount) selected · nothing is selected by default"
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning {
            ProgressView("Looking for leftovers…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.hasScanned {
            PlaceholderView(
                systemImage: "questionmark.folder",
                title: "Find app leftovers",
                message: "Tidy looks for preferences, caches and containers named after apps that are no longer on your Mac. Review each one before removing it."
            )
        } else if viewModel.leftovers.isEmpty {
            PlaceholderView(
                systemImage: "checkmark.seal",
                title: "No leftovers found",
                message: "Every file Tidy checked belongs to an installed app."
            )
        } else {
            List {
                CategoryHeaderRow(
                    title: "Orphaned files",
                    summary: "Named after bundle identifiers that no installed app uses",
                    size: viewModel.totalSize,
                    itemSelections: viewModel.selectionBindings(for: viewModel.leftovers)
                )
                ForEach(viewModel.leftovers) { item in
                    ScanItemRow(item: item, isSelected: viewModel.selectionBinding(for: item))
                }
            }
            .listStyle(.inset)
        }
    }
}
