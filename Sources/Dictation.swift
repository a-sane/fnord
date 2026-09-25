import AppKit
import AVFoundation
import ScreenCaptureKit

enum DictationState: Equatable {
    case idle, recording, transcribing, failed(String)

    var icon: NSImage {
        switch self {
        case .idle: MenuBarIcon.image(.wave)
        case .recording: MenuBarIcon.image(.wave, filled: true)
        case .transcribing: MenuBarIcon.image(.dots)
        case .failed: MenuBarIcon.image(.bang)
        }
    }
}

@MainActor @Observable
final class Dictation {
    static let shared = Dictation()
    private(set) var state = DictationState.idle

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var pressedAt: Date? // non-nil while the trigger key is held down during recording
    @ObservationIgnored private var screenshot: Task<Data?, Never>?
    @ObservationIgnored private var appName: String?
    private let audioURL = FileManager.default.temporaryDirectory.appendingPathComponent("fnord.wav")

    func start() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        // Global monitor sees events aimed at other apps; the local one covers our own settings window.
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { e in
            MainActor.assumeIsolated { self.handle(e) }
        }
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { e in
            MainActor.assumeIsolated { self.handle(e) }
            return e
        }
    }

    // Hold the key = push-to-talk. Quick tap = hands-free until the next press. Esc cancels.
    private func handle(_ e: NSEvent) {
        if e.type == .keyDown {
            // Another key while the trigger is held means a shortcut like fn+← — not dictation.
            if pressedAt != nil || (e.keyCode == 53 && state == .recording) { cancel() }
            return
        }
        let key = TriggerKey.current
        guard e.keyCode == key.keyCode else { return }

        if e.modifierFlags.rawValue & key.mask != 0 {
            if state == .recording { finish() } else if state != .transcribing { begin() }
        } else if let t = pressedAt {
            pressedAt = nil
            if Date.now.timeIntervalSince(t) > 0.35 { finish() }
        }
    }

    private func begin() {
        guard Keychain.apiKey != nil else { SettingsWindow.show(); return }
        let format: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
        ]
        guard let r = try? AVAudioRecorder(url: audioURL, settings: format), r.record() else {
            return fail("Microphone unavailable")
        }
        recorder = r
        pressedAt = .now
        appName = NSWorkspace.shared.frontmostApplication?.localizedName
        screenshot = UserDefaults.standard.bool(forKey: "useContext") ? Task { await captureFrontWindow() } : nil
        set(.recording)
    }

    private func finish() {
        guard let r = recorder else { return }
        r.stop()
        recorder = nil
        pressedAt = nil
        let shot = screenshot
        screenshot = nil
        set(.transcribing)
        Task {
            do {
                let audio = try Data(contentsOf: audioURL)
                let text = try await Gemini.transcribe(wav: audio, screenshot: await shot?.value, appName: appName)
                if !text.isEmpty { paste(text) }
                set(.idle)
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    private func cancel() {
        recorder?.stop()
        recorder = nil
        pressedAt = nil
        screenshot?.cancel()
        screenshot = nil
        set(.idle)
    }

    private func fail(_ message: String) {
        set(.failed(message))
        Task {
            try? await Task.sleep(for: .seconds(4))
            if case .failed = state { set(.idle) }
        }
    }

    private func set(_ s: DictationState) {
        state = s
        HUD.update(s)
    }
}

/// Puts text on the clipboard, sends ⌘V to the focused app, then restores the previous clipboard.
@MainActor
private func paste(_ text: String) {
    let pb = NSPasteboard.general
    let saved: [NSPasteboardItem] = pb.pasteboardItems?.map { item in
        let copy = NSPasteboardItem()
        for type in item.types { if let d = item.data(forType: type) { copy.setData(d, forType: type) } }
        return copy
    } ?? []

    pb.clearContents()
    pb.setString(text, forType: .string)
    pb.setString("", forType: .init("org.nspasteboard.TransientType")) // tells clipboard managers to skip it
    let changeCount = pb.changeCount

    let source = CGEventSource(stateID: .combinedSessionState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: down) // kVK_ANSI_V
        e?.flags = .maskCommand
        e?.post(tap: .cghidEventTap)
    }

    Task {
        try? await Task.sleep(for: .milliseconds(500))
        guard pb.changeCount == changeCount else { return } // someone else wrote to the clipboard meanwhile
        pb.clearContents()
        pb.writeObjects(saved)
    }
}

/// JPEG of the frontmost app's frontmost window, long side capped at 1280pt.
@MainActor
private func captureFrontWindow() async -> Data? {
    guard CGPreflightScreenCaptureAccess(),
          let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
    // CGWindowList is ordered front-to-back; SCShareableContent isn't.
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let front = windows.first { info in
        info[kCGWindowOwnerPID as String] as? pid_t == pid && info[kCGWindowLayer as String] as? Int == 0
    }
    guard let id = front?[kCGWindowNumber as String] as? CGWindowID,
          let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true),
          let window = content.windows.first(where: { $0.windowID == id }) else { return nil }

    let config = SCStreamConfiguration()
    let scale = min(1, 1280 / max(window.frame.width, window.frame.height))
    config.width = Int(window.frame.width * scale)
    config.height = Int(window.frame.height * scale)
    guard let image = try? await SCScreenshotManager.captureImage(
        contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config) else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.7])
}
