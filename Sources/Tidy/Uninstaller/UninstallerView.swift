import AppKit
import SwiftUI
import TidyCore

struct UninstallerView: View {
    @ObservedObject var viewModel: UninstallerViewModel
    @State private var isConfirmingUninstall = false

    var body: some View {
        HSplitView {
            applicationList
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            detail
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Uninstaller")
        .onAppear { viewModel.loadApplicationsIfNeeded() }
    }

    private var applicationList: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search applications", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.reloadApplications()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Reload applications")
                .disabled(viewModel.isLoadingApplications)
            }
            .padding(8)

            if viewModel.isLoadingApplications && viewModel.applications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredApplications, selection: $viewModel.selectedApplicationID) { application in
                    ApplicationRow(application: application)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let report = viewModel.residueReport {
            residueDetail(for: report)
        } else if viewModel.isLoadingResidues {
            ProgressView("Looking for related files…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PlaceholderView(
                systemImage: "xmark.app",
                title: "Select an application",
                message: "Tidy lists the app and every related file it finds in your Library so you can remove them together."
            )
        }
    }

    private func residueDetail(for report: ApplicationResidueReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: report.application.bundleURL.path))
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.application.name)
                        .font(.title2.bold())
                    Text([report.application.version, report.application.bundleIdentifier].compactMap { $0 }.joined(separator: " · "))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Uninstall") { isConfirmingUninstall = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedItemIDs.isEmpty || viewModel.isUninstalling)
            }

            Text("\(viewModel.selectedSize.formattedByteCount) selected of \(report.totalSize.formattedByteCount)")
                .foregroundStyle(.secondary)

            if let lastReport = viewModel.lastReport {
                RemovalSummaryView(report: lastReport, isDryRun: false)
            }

            List {
                ForEach(report.groups) { groupResult in
                    Section {
                        ForEach(groupResult.items) { item in
                            ScanItemRow(item: item, isSelected: viewModel.selectionBinding(for: item))
                        }
                    } header: {
                        CategoryHeaderRow(
                            title: groupResult.group.title,
                            summary: nil,
                            size: groupResult.totalSize,
                            itemSelections: viewModel.selectionBindings(for: groupResult.items)
                        )
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding()
        .confirmationDialog("Uninstall \(report.application.name)?", isPresented: $isConfirmingUninstall) {
            Button("Move \(viewModel.selectedItems.count) items to Trash", role: .destructive) {
                viewModel.uninstallSelectedItems()
            }
        } message: {
            Text("The app is quit first. You can restore everything from the Trash.")
        }
    }
}

private struct ApplicationRow: View {
    let application: InstalledApplication

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.bundleURL.path))
                .resizable()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(application.name)
                    .lineLimit(1)
                if let version = application.version {
                    Text(version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
