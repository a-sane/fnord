import SwiftUI
import AVFoundation

struct SettingsView: View {
    @State private var apiKey = Keychain.apiKey ?? ""
    @AppStorage("triggerKey") private var triggerKey = TriggerKey.fn
    @AppStorage("vocabulary") private var vocabulary = ""
    @AppStorage("useContext") private var useContext = false

    var body: some View {
        Form {
            Section("Gemini") {
                SecureField("API key", text: $apiKey)
                    .onChange(of: apiKey) { Keychain.apiKey = $1.trimmingCharacters(in: .whitespacesAndNewlines) }
                Link("Get a key in Google AI Studio", destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
            }

            Section("Hotkey") {
                Picker("Trigger key", selection: $triggerKey) {
                    ForEach(TriggerKey.allCases) { Text($0.label).tag($0) }
                }
                caption("Hold to talk, release to insert. Tap once for hands-free, tap again to insert. Esc cancels.")
                if triggerKey == .fn {
                    caption("Set System Settings › Keyboard › “Press 🌐 key to” → Do Nothing, or taps will open the emoji picker.")
                }
            }

            Section("Custom vocabulary") {
                TextEditor(text: $vocabulary)
                    .font(.body.monospaced())
                    .frame(height: 110)
                caption("One term per line: names, jargon, product names.")
            }

            Section("App context") {
                Toggle("Send a screenshot of the active window", isOn: $useContext)
                    .onChange(of: useContext) { if $1 { CGRequestScreenCaptureAccess() } }
                caption("Helps with names and terms visible on screen. Uses \(Gemini.contextModel) instead of \(Gemini.transcribeModel).")
            }

            Section("Permissions") {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    permission("Microphone", AVCaptureDevice.authorizationStatus(for: .audio) == .authorized, pane: "Microphone")
                    permission("Accessibility (hotkey + typing)", AXIsProcessTrusted(), pane: "Accessibility")
                    if useContext {
                        permission("Screen Recording (context)", CGPreflightScreenCaptureAccess(), pane: "ScreenCapture")
                    }
                }
                caption("Relaunch Fnord after granting Accessibility or Screen Recording.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func permission(_ name: String, _ granted: Bool, pane: String) -> some View {
        LabeledContent(name) {
            if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Grant…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)")!)
                }
            }
        }
    }
}

enum TriggerKey: String, CaseIterable, Identifiable {
    case fn, rightOption, rightCommand, rightControl

    var id: Self { self }
    static var current: Self { Self(rawValue: UserDefaults.standard.string(forKey: "triggerKey") ?? "") ?? .fn }

    var label: String {
        switch self {
        case .fn: "fn / 🌐"
        case .rightOption: "Right ⌥ Option"
        case .rightCommand: "Right ⌘ Command"
        case .rightControl: "Right ⌃ Control"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        }
    }

    /// Device-dependent flag bit, so e.g. right ⌥ is distinguished from left ⌥.
    var mask: UInt {
        switch self {
        case .fn: NSEvent.ModifierFlags.function.rawValue
        case .rightOption: 0x40 // NX_DEVICERALTKEYMASK
        case .rightCommand: 0x10 // NX_DEVICERCMDKEYMASK
        case .rightControl: 0x2000 // NX_DEVICERCTLKEYMASK
        }
    }
}

enum Keychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.sane.fnord.gemini-api-key",
    ]

    static var apiKey: String? {
        get {
            var q = query
            q[kSecReturnData as String] = true
            var out: AnyObject?
            guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            SecItemDelete(query as CFDictionary)
            guard let newValue, !newValue.isEmpty else { return }
            var q = query
            q[kSecValueData as String] = Data(newValue.utf8)
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}
