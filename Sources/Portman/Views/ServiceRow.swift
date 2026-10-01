import SwiftUI

struct ServiceRow: View {
    let service: Service
    let onKill: () -> Void
    let onOpen: (() -> Void)?

    @State private var isHovering = false
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 0) {
            portBadge.frame(width: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(service.command)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if case .idleBurning(let min) = service.health {
                    HStack(spacing: 3) {
                        PhIcon.flameFill(size: 10)
                        Text("idle \(min)m · \(String(format: "%.1f", service.metrics.cpuPercent))% CPU")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                }
            }
            .padding(.leading, 8)

            Spacer()

            // Metrics — always visible
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    PhIcon.cpu(size: 9)
                    Text(String(format: "%.1f%%", service.metrics.cpuPercent))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                HStack(spacing: 3) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 8))
                    Text(formatRAM(service.metrics.memoryMB))
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
            }
            .foregroundStyle(metricsColor)
            .padding(.trailing, 6)

            // Hover actions
            Group {
                if isHovering {
                    HStack(spacing: 4) {
                        // Info button
                        Button {
                            showInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showInfo, arrowEdge: .trailing) {
                            InfoPopover(service: service)
                        }

                        // Kill button
                        Button(action: onKill) {
                            PhIcon.xCircleFill(size: 15)
                                .foregroundStyle(Color.red.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(width: isHovering ? 46 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.09) : Color.clear)
        )
        .onHover { isHovering = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }

    // MARK: - Sub-views

    private var portBadge: some View {
        Group {
            if let port = service.port {
                Text("\(port)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(portTextColor)
            } else {
                PhIcon.cubeFill(size: 18)
                    .foregroundStyle(portTextColor)
            }
        }
        .frame(width: 56)
    }

    // MARK: - Helpers

    private var portTextColor: Color {
        switch service.health {
        case .normal:      return .primary
        case .idleBurning: return .orange
        case .hotCPU:      return .red
        }
    }

    private var metricsColor: Color {
        switch service.health {
        case .hotCPU:      return .red.opacity(0.85)
        case .idleBurning: return .orange.opacity(0.85)
        case .normal:      return .secondary
        }
    }

    private func formatRAM(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1fG", mb / 1024) }
        if mb >= 1    { return String(format: "%.0fM", mb) }
        return "<1M"
    }
}

// MARK: - Info Popover

private struct InfoPopover: View {
    let service: Service

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                if let port = service.port {
                    Text(":\(port)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                } else {
                    PhIcon.cubeFill(size: 13)
                }
                Text(service.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)

            Divider()

            // Details grid
            VStack(alignment: .leading, spacing: 6) {
                infoRow(label: "Command", value: service.command)

                if !service.cwd.isEmpty {
                    infoRow(label: "Directory", value: tidyCWD(service.cwd))
                }

                if service.pid > 0 {
                    infoRow(label: "PID", value: "\(service.pid)")
                }

                if service.pgid > 0 && service.pgid != service.pid {
                    infoRow(label: "PGID", value: "\(service.pgid)")
                }

                infoRow(label: "CPU", value: String(format: "%.2f%%", service.metrics.cpuPercent))
                infoRow(label: "RAM", value: formatRAM(service.metrics.memoryMB))

                infoRow(label: "First seen", value: relativeTime(service.firstSeen))
                infoRow(label: "Last active", value: relativeTime(service.lastActiveAt))
            }
        }
        .padding(14)
        .frame(minWidth: 240, maxWidth: 300)
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func formatRAM(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1    { return String(format: "%.0f MB", mb) }
        return "< 1 MB"
    }

    private func tidyCWD(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func relativeTime(_ date: Date) -> String {
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60  { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}

// MARK: - CPU bar (kept for reference, no longer used in row)

struct CPUBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            let filled = min(percent / 30.0, 1.0)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(height: geo.size.height * filled)
            }
        }
    }

    private var barColor: Color {
        if percent > 25 { return .red }
        if percent > 5  { return .orange }
        return Color.green.opacity(0.7)
    }
}
