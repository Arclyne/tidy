import AppKit
import SwiftUI
import TidyCore

enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case junk
    case uninstaller
    case leftovers

    var id: Self { self }

    var title: String {
        switch self {
        case .junk: return "Junk"
        case .uninstaller: return "Uninstaller"
        case .leftovers: return "Leftovers"
        }
    }

    var systemImage: String {
        switch self {
        case .junk: return "trash"
        case .uninstaller: return "xmark.app"
        case .leftovers: return "questionmark.folder"
        }
    }
}

struct RootView: View {
    @StateObject private var junkViewModel: JunkViewModel
    @StateObject private var uninstallerViewModel: UninstallerViewModel
    @StateObject private var leftoversViewModel: LeftoversViewModel
    @State private var selectedSection: SidebarSection? = .junk
    @State private var hasFullDiskAccess = true

    private let fullDiskAccessChecker: any FullDiskAccessChecking

    init(dependencies: AppDependencies) {
        _junkViewModel = StateObject(wrappedValue: JunkViewModel(dependencies: dependencies))
        _uninstallerViewModel = StateObject(wrappedValue: UninstallerViewModel(dependencies: dependencies))
        _leftoversViewModel = StateObject(wrappedValue: LeftoversViewModel(dependencies: dependencies))
        fullDiskAccessChecker = dependencies.fullDiskAccessChecker
    }

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            VStack(spacing: 0) {
                if !hasFullDiskAccess {
                    FullDiskAccessBanner()
                        .padding([.horizontal, .top])
                }
                selectedDetail
            }
        }
        .onAppear(perform: refreshFullDiskAccessStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshFullDiskAccessStatus()
        }
    }

    @ViewBuilder
    private var selectedDetail: some View {
        switch selectedSection ?? .junk {
        case .junk:
            JunkView(viewModel: junkViewModel)
        case .uninstaller:
            UninstallerView(viewModel: uninstallerViewModel)
        case .leftovers:
            LeftoversView(viewModel: leftoversViewModel)
        }
    }

    private func refreshFullDiskAccessStatus() {
        hasFullDiskAccess = fullDiskAccessChecker.hasFullDiskAccess()
    }
}
