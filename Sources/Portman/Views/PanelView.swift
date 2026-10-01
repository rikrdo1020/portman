import SwiftUI
import AppKit

struct PanelView: View {
    @EnvironmentObject var store: ServicesStore
    @Environment(\.openSettings) private var openSettings
    @State private var showNonDev = false
    @State private var showKillAllConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.18)
            scrollContent
            Divider().opacity(0.18)
            footer
        }
        .background(.clear)
        .frame(width: 340)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("SERVICES")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                DispatchQueue.main.async {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
            } label: {
                PhIcon.fadersHorizontal(size: 14)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preferences")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if !store.portServices.isEmpty {
                    sectionHeader("PORTS")
                    ForEach(store.portServices) { svc in
                        ServiceRow(service: svc, onKill: { store.killService(svc) }) {
                            if let url = svc.localhostURL {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                if store.dockerDaemonDown {
                    dockerDownRow
                } else if !store.containerServices.isEmpty {
                    sectionHeader("DOCKER")
                    ForEach(store.containerServices) { svc in
                        ServiceRow(service: svc, onKill: { store.killService(svc) }, onOpen: nil)
                    }
                }

                if !store.nonDevServices.isEmpty {
                    sectionHeader("OTHER", toggleState: $showNonDev)
                    if showNonDev {
                        ForEach(store.nonDevServices) { svc in
                            ServiceRow(service: svc, onKill: { store.killService(svc) }, onOpen: nil)
                        }
                    }
                }

                if store.portServices.isEmpty
                    && store.containerServices.isEmpty
                    && !store.dockerDaemonDown {
                    emptyState
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 420)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if showKillAllConfirm {
                Text("Kill everything?")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { showKillAllConfirm = false }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Kill all") {
                    store.killAllDev()
                    showKillAllConfirm = false
                }
                .font(.system(size: 11, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            } else {
                let devCount = store.portServices.count + store.containerServices.count
                Button {
                    if devCount > 0 { showKillAllConfirm = true }
                } label: {
                    HStack(spacing: 5) {
                        PhIcon.prohibit(size: 11)
                        Text("Kill all")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(devCount == 0
                        ? Color.secondary.opacity(0.4)
                        : Color.red.opacity(0.75))
                }
                .buttonStyle(.plain)
                .disabled(devCount == 0)

                Spacer()

                if store.totalDevCPU > 0.3 {
                    HStack(spacing: 4) {
                        PhIcon.cpu(size: 10)
                        Text(String(format: "%.1f%%", store.totalDevCPU))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(_ title: String, toggleState: Binding<Bool>? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.quaternary)
            Spacer()
            if let binding = toggleState {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        binding.wrappedValue.toggle()
                    }
                } label: {
                    Group {
                        if binding.wrappedValue {
                            PhIcon.caretUp(size: 10)
                        } else {
                            PhIcon.caretDown(size: 10)
                        }
                    }
                    .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 44, height: 44)
                PhIcon.checkCircle(size: 22)
                    .foregroundStyle(Color.green.opacity(0.65))
            }
            VStack(spacing: 3) {
                Text("No services running")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.7))
                Text("Your battery thanks you")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Docker down

    private var dockerDownRow: some View {
        HStack(spacing: 8) {
            PhIcon.warningFill(size: 12)
                .foregroundStyle(Color.orange.opacity(0.8))
            Text("Docker is not running")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
