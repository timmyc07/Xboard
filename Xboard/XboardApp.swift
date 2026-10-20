import SwiftUI

@main
struct XboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra("Xboard", systemImage: "doc.on.clipboard") {
            Button {
                appState.showPanel()
            } label: {
                Label(String(localized: "Open history"), systemImage: "doc.on.clipboard")
            }

            Button {
                appState.ignoreNextCopy()
            } label: {
                Label(String(localized: "Ignore Next Copy"), systemImage: "eye.slash")
            }

            if appState.isHistoryPaused {
                Button(String(localized: "Resume History")) { appState.resumeHistory() }
            } else {
                Menu(String(localized: "Pause History")) {
                    ForEach(ClipboardPauseDuration.allCases) { duration in
                        Button(duration.title) { appState.pauseHistory(for: duration) }
                    }
                }
            }

            Divider()

            Menu(String(localized: "More tools")) {
                Button(String(localized: "Library…")) { appState.showFavorites() }
                Button(String(localized: "Capture and Annotate…")) { appState.captureAndAnnotate() }
                if appState.isRecordingGIF {
                    Button(String(localized: "Stop GIF Recording")) { appState.finishGIFRecording() }
                    Button(String(localized: "Cancel GIF Recording")) { appState.cancelGIFRecording() }
                } else {
                    Button(String(localized: "Record GIF…")) { appState.recordGIF() }
                }
                Button(String(localized: "Save Latest GIF…")) { appState.saveLatestGIF() }
                Divider()
                if appState.isCapturingStack {
                    Button(String(localized: "Finish Stack Capture (\(appState.clipboardStack.count))")) {
                        appState.finishClipboardStack()
                    }
                    Button(String(localized: "Cancel Stack Capture")) { appState.cancelClipboardStack() }
                } else {
                    Button(String(localized: "Start Clipboard Stack")) { appState.startClipboardStack() }
                }
                if !appState.isCapturingStack && !appState.clipboardStack.isEmpty {
                    Button(String(localized: "Paste Next Stack Item")) { appState.pasteNextStackItem() }
                    Button(String(localized: "Clear Clipboard Stack")) { appState.clearClipboardStack() }
                }
            }

            Divider()
            Button(String(localized: "Settings…")) { appState.showSettings() }
            Button(String(localized: "Quit Xboard")) { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(String(localized: "Open history")) { appState.showPanel() }
            }
            CommandGroup(replacing: .appSettings) {
                Button(String(localized: "Settings…")) { appState.showSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        AppState.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { AppState.shared.showSettings() }
        return true
    }
}
