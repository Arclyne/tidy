import AppKit
import SwiftUI
import TidyCore

struct UninstallerView: View {
    @ObservedObject var viewModel: UninstallerViewModel
    @State private var isConfirmingUninstall = false
    @State private var isConfirmingBatchUninstall = false

    var body: some View {
        HSplitView {
            applicationColumn
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 380)
            detail
                .frame(minWidth: 440, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Uninstaller")
        .onAppear { viewModel.loadApplicationsIfNeeded() }
        .confirmationDialog(
            "Uninstall \(viewModel.checkedApplications.count) applications?",
            isPresented: $isConfirmingBatchUninstall
        ) {
            Button("Move Everything to Trash", role: .destructive) {
                viewModel.uninstallCheckedApplications()
            }
        } message: {
            Text(batchConfirmationMessage)
        }
    }

    private var batchConfirmationMessage: String {
        let names = viewModel.checkedApplications.map(\.name).joined(separator: ", ")
        return "\(names) and all of their related files will be moved to the Trash. Running apps are quit first."
    }

    private var applicationColumn: some View {
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
            .padding([.horizontal, .top], 8)

            Picker("Show", selection: $viewModel.filter) {
                ForEach(viewModel.filterSections) { section in
                    Section(section.title) {
                        ForEach(section.filters) { filter in
                            Text("\(filter.title) (\(viewModel.applicationCount(for: filter)))")
                                .tag(filter)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .padding(8)

            if viewModel.isLoadingApplications && viewModel.applications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredApplications, selection: $viewModel.selectedApplicationID) { application in
                    ApplicationRow(application: application, isChecked: viewModel.checkBinding(for: application))
                }
            }

            if !viewModel.checkedApplicationIDs.isEmpty {
                Divider()
                HStack {
                    Text("\(viewModel.checkedApplicationIDs.count) selected")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { viewModel.checkedApplicationIDs.removeAll() }
                    Button("Uninstall") { isConfirmingBatchUninstall = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isUninstalling)
                }
                .padding(8)
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
        } else if viewModel.isUninstalling {
            ProgressView("Uninstalling applications…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let batchReport = viewModel.batchReport {
            VStack(alignment: .leading, spacing: 12) {
                RemovalSummaryView(report: batchReport, isDryRun: false)
                Spacer()
            }
            .padding()
        } else {
            PlaceholderView(
                systemImage: "xmark.app",
                title: "Select an application",
                message: "Tidy lists the app and every related file it finds so you can remove them together. Tick several apps to uninstall them at once."
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
                    Text(applicationDetails(for: report.application))
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
            Text("The app is quit first. Files owned by the system ask for your administrator password. You can restore everything from the Trash.")
        }
    }

    private func applicationDetails(for application: InstalledApplication) -> String {
        let details: [String?] = [
            application.version,
            application.bundleIdentifier,
            application.source == .other ? nil : application.source.title,
            application.lastUsedDate.map { "Last opened \($0.formatted(date: .abbreviated, time: .omitted))" }
        ]
        return details.compactMap { $0 }.joined(separator: " · ")
    }
}

private struct ApplicationRow: View {
    let application: InstalledApplication
    @Binding var isChecked: Bool

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $isChecked)
                .labelsHidden()
                .toggleStyle(.checkbox)
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.bundleURL.path))
                .resizable()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(application.name)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var subtitle: String {
        let lastOpened = application.lastUsedDate.map { "opened \($0.formatted(date: .abbreviated, time: .omitted))" }
        return [application.version, lastOpened].compactMap { $0 }.joined(separator: " · ")
    }
}
