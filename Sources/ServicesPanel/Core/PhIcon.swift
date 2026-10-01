import SwiftUI
import AppKit

/// Thin wrapper for Phosphor SVG icons bundled in Resources/Icons/.
/// macOS 12+ renders SVG natively via NSImage.
struct PhIcon: View {
    let name: String
    var size: CGFloat = 16

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private var image: Image {
        // Icons are copied to Contents/Resources/Icons/ by bundle.sh
        let iconsDir = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/Icons")
        let url = iconsDir.appendingPathComponent("\(name).svg")

        if let ns = NSImage(contentsOf: url) {
            ns.size = NSSize(width: 64, height: 64)  // hint for rasterizer
            return Image(nsImage: ns)
        }
        // Dev fallback: look next to executable (swift run / debug builds)
        let devURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Icons/\(name).svg")
        if let ns = NSImage(contentsOf: devURL) {
            ns.size = NSSize(width: 64, height: 64)
            return Image(nsImage: ns)
        }
        return Image(systemName: "questionmark.circle")
    }
}

// MARK: - Named constants (typed so the compiler catches typos)
extension PhIcon {
    static func terminalWindow(size: CGFloat = 16) -> PhIcon { PhIcon(name: "terminal-window", size: size) }
    static func warningCircleFill(size: CGFloat = 16) -> PhIcon { PhIcon(name: "warning-circle-fill", size: size) }
    static func xCircleFill(size: CGFloat = 16) -> PhIcon { PhIcon(name: "x-circle-fill", size: size) }
    static func checkCircle(size: CGFloat = 16) -> PhIcon { PhIcon(name: "check-circle", size: size) }
    static func fadersHorizontal(size: CGFloat = 16) -> PhIcon { PhIcon(name: "faders-horizontal", size: size) }
    static func cpu(size: CGFloat = 16) -> PhIcon { PhIcon(name: "cpu", size: size) }
    static func cubeFill(size: CGFloat = 16) -> PhIcon { PhIcon(name: "cube-fill", size: size) }
    static func flameFill(size: CGFloat = 16) -> PhIcon { PhIcon(name: "flame-fill", size: size) }
    static func warningFill(size: CGFloat = 16) -> PhIcon { PhIcon(name: "warning-fill", size: size) }
    static func caretUp(size: CGFloat = 16) -> PhIcon { PhIcon(name: "caret-up", size: size) }
    static func caretDown(size: CGFloat = 16) -> PhIcon { PhIcon(name: "caret-down", size: size) }
    static func prohibit(size: CGFloat = 16) -> PhIcon { PhIcon(name: "prohibit", size: size) }
}
