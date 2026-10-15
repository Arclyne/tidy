import AppKit
import SwiftUI

final class TidyApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct TidyApp: App {
    @NSApplicationDelegateAdaptor(TidyApplicationDelegate.self) private var applicationDelegate
    private let dependencies = AppDependencies.live()

    var body: some Scene {
        WindowGroup("Tidy") {
            RootView(dependencies: dependencies)
                .frame(minWidth: 960, minHeight: 620)
        }
        .commands {
            SidebarCommands()
        }
    }
}
