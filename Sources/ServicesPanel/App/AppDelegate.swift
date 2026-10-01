import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let store = ServicesStore()

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        store.start()
        observeStore()

        // Watch system appearance changes (light ↔ dark)
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(updateMenuBarIcon),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil)
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }

        button.image = loadMenuBarImage()
        button.image?.size = NSSize(width: 22, height: 22)
        button.imagePosition = .imageLeft

        // Respond to BOTH left and right click
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self

        updateCPUTitle()
    }

    @objc private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        button.image = loadMenuBarImage()
        button.image?.size = NSSize(width: 22, height: 22)
    }

    /// Picks light or dark variant based on current appearance.
    private func loadMenuBarImage() -> NSImage? {
        let iconsDir = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/Icons")

        let isDark = NSApp.effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]) == .darkAqua

        let name = isDark ? "menubar-dark" : "menubar-light"

        if let img = NSImage(contentsOf: iconsDir.appendingPathComponent("\(name)@2x.png")) {
            img.isTemplate = false
            return img
        }
        // Fallback: Phosphor terminal icon from SF
        return NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
    }

    private func updateCPUTitle() {
        statusItem.button?.title = ""
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else {
            openPopover(from: sender)
        }
    }

    private func openPopover(from button: NSStatusBarButton) {
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        store.isPanelOpen = true
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
        store.isPanelOpen = false
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PanelView().environmentObject(store)
        )
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPanelOpen = false
    }

    // MARK: - Reactive updates

    private func observeStore() {
        store.$hasIdleBurning
            .combineLatest(store.$totalDevCPU)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] idle, cpu in
                self?.updateMenuBarIcon()
                self?.updateCPUTitle()
            }
            .store(in: &cancellables)
    }
}
