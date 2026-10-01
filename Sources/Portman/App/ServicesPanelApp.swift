import SwiftUI

@main
struct ServicesPanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // MenuBarExtra removed — AppDelegate owns the NSStatusItem + NSPopover
        // Settings scene still provides ⌘, and the openSettings() environment action
        Settings {
            SettingsView()
        }
    }
}
