import SwiftUI

@main
struct FnordApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Settings…") { SettingsWindow.show() }.keyboardShortcut(",")
            Divider()
            Button("Quit Fnord") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(nsImage: Dictation.shared.state.icon)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Dictation.shared.start()
        if Keychain.apiKey == nil { SettingsWindow.show() }
    }
}

@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "Fnord Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
