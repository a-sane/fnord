import SwiftUI

/// Small floating pill at the bottom of the screen showing recording / transcribing / error state.
@MainActor
enum HUD {
    private static let size = NSSize(width: 420, height: 56)

    private static let panel: NSPanel = {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.nonactivatingPanel, .borderless],
                        backing: .buffered, defer: true)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: HUDView())
        return p
    }()

    static func update(_ state: DictationState) {
        guard state != .idle else { return panel.orderOut(nil) }
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let f = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.minY + 24))
        }
        panel.orderFrontRegardless()
    }
}

private struct HUDView: View {
    var body: some View {
        HStack(spacing: 8) {
            switch Dictation.shared.state {
            case .recording:
                Image(systemName: "mic.fill").foregroundStyle(.red).symbolEffect(.pulse)
                Text("Listening…")
            case .transcribing:
                ProgressView().controlSize(.small)
                Text("Transcribing…")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                Text(message).lineLimit(1)
            case .idle:
                EmptyView()
            }
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
