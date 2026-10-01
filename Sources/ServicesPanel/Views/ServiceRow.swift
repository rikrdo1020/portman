import SwiftUI

struct ServiceRow: View {
    let service: Service
    let onKill: () -> Void
    let onOpen: (() -> Void)?

    @State private var isHovering = false

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

            CPUBar(percent: service.metrics.cpuPercent)
                .frame(width: 4, height: 28)

            Group {
                if isHovering {
                    Button(action: onKill) {
                        PhIcon.xCircleFill(size: 15)
                            .foregroundStyle(Color.red.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(width: 22)
            .padding(.leading, 6)
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
    }

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

    private var portTextColor: Color {
        switch service.health {
        case .normal:      return .primary
        case .idleBurning: return .orange
        case .hotCPU:      return .red
        }
    }
}

// MARK: - CPU bar

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
