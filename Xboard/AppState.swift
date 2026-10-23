import ApplicationServices
import AppKit
import Carbon.HIToolbox
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

enum HotKeyTarget: String, Equatable {
    case history
    case gif
    case stackStart
    case stackNext
}

enum ClipboardAppearance: String, CaseIterable, Hashable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

enum ClipboardMaterial: String, CaseIterable, Hashable, Identifiable {
    case liquidGlass
    case standard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liquidGlass: return String(localized: "Liquid Glass")
        case .standard: return String(localized: "Standard")
        }
    }
}

struct ClipboardApplication: Identifiable, Hashable {
    let bundleIdentifier: String
    let displayName: String

    var id: String { bundleIdentifier }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var hotKey: HotKeyConfiguration {
        didSet {
            defer { UserDefaults.standard.set(try? JSONEncoder().encode(hotKey), forKey: Keys.hotKey) }
            guard hasStarted else {
                oldHotKey = hotKey
                return
            }
            guard !isHotKeyInUse(hotKey, excluding: .history) else {
                statusMessage = String(localized: "Hotkeys must be different.")
                hotKey = oldHotKey
                return
            }
            if !hotKeyManager.register(hotKey) {
                statusMessage = String(localized: "Hotkey unavailable; previous configuration kept.")
                hotKey = oldHotKey
            } else {
                oldHotKey = hotKey
            }
        }
    }

    @Published var gifHotKey: HotKeyConfiguration? {
        didSet {
            defer { persistOptionalHotKey(gifHotKey, key: Keys.gifHotKey) }
            guard hasStarted else {
                oldGIFHotKey = gifHotKey
                return
            }
            guard !isHotKeyInUse(gifHotKey, excluding: .gif) else {
                statusMessage = String(localized: "Hotkeys must be different.")
                gifHotKey = oldGIFHotKey
                return
            }
            if !gifHotKeyManager.register(gifHotKey) {
                statusMessage = String(localized: "GIF hotkey unavailable; previous configuration kept.")
                gifHotKey = oldGIFHotKey
            } else {
                oldGIFHotKey = gifHotKey
            }
        }
    }

    @Published var stackStartHotKey: HotKeyConfiguration? {
        didSet {
            defer { persistOptionalHotKey(stackStartHotKey, key: Keys.stackStartHotKey) }
            guard hasStarted else {
                oldStackStartHotKey = stackStartHotKey
                return
            }
            guard !isHotKeyInUse(stackStartHotKey, excluding: .stackStart) else {
                statusMessage = String(localized: "That hotkey is already in use.")
                stackStartHotKey = oldStackStartHotKey
                return
            }
            if !stackStartHotKeyManager.register(stackStartHotKey) {
                statusMessage = String(localized: "Hotkey unavailable; previous configuration kept.")
                stackStartHotKey = oldStackStartHotKey
            } else {
                oldStackStartHotKey = stackStartHotKey
            }
        }
    }

    @Published var stackNextHotKey: HotKeyConfiguration? {
        didSet {
            defer { persistOptionalHotKey(stackNextHotKey, key: Keys.stackNextHotKey) }
            guard hasStarted else {
                oldStackNextHotKey = stackNextHotKey
                return
            }
            guard !isHotKeyInUse(stackNextHotKey, excluding: .stackNext) else {
                statusMessage = String(localized: "That hotkey is already in use.")
                stackNextHotKey = oldStackNextHotKey
                return
            }
            if !stackNextHotKeyManager.register(stackNextHotKey) {
                statusMessage = String(localized: "Hotkey unavailable; previous configuration kept.")
                stackNextHotKey = oldStackNextHotKey
            } else {
                oldStackNextHotKey = stackNextHotKey
            }
        }
    }

    @Published var historyLimit: Int {
        didSet {
            historyLimit = max(historyLimit, 10)
            UserDefaults.standard.set(historyLimit, forKey: Keys.historyLimit)
            store.setLimit(historyLimit)
        }
    }

    @Published var retention: ClipboardRetention {
        didSet {
            UserDefaults.standard.set(retention.rawValue, forKey: Keys.retention)
            store.setRetention(retention)
        }
    }

    @Published var ignoredBundleIdentifiers: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(ignoredBundleIdentifiers).sorted(), forKey: Keys.ignoredBundleIdentifiers)
            monitor.ignoredBundleIdentifiers = ignoredBundleIdentifiers
            refreshAvailableApplications()
        }
    }

    @Published private(set) var availableApplications: [ClipboardApplication] = []
    @Published private(set) var isHistoryPaused = false
    @Published private(set) var isCapturingStack = false
    @Published private(set) var clipboardStack = ClipboardStack()
    @Published private(set) var requireAuthenticationForPrivateViews = false

    @Published var appearance: ClipboardAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance(appearance, to: settingsWindow)
            applyAppearance(appearance, to: favoritesWindow)
            panelController.setAppearance(appearance)
        }
    }

    @Published var material: ClipboardMaterial {
        didSet {
            UserDefaults.standard.set(material.rawValue, forKey: Keys.material)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard !isUpdatingLaunchAtLogin else { return }
            let requestedValue = launchAtLogin
            do {
                if requestedValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                UserDefaults.standard.set(requestedValue, forKey: Keys.launchAtLogin)
            } catch {
                isUpdatingLaunchAtLogin = true
                launchAtLogin = !requestedValue
                isUpdatingLaunchAtLogin = false
                statusMessage = String(localized: "Launch at login could not be changed.")
            }
        }
    }

    @Published private(set) var isAccessibilityTrusted = AXIsProcessTrusted()
    @Published private(set) var isRecordingHotKey = false
    @Published private(set) var isCapturingScreenshot = false
    @Published private(set) var isRecordingGIF = false
    @Published var statusMessage: String?
    @Published private(set) var isLoadingStorage = false

    let store: ClipboardStore
    let snippetStore: SnippetStore

    var isDeviceAuthenticationAvailable: Bool {
        authenticationService.isAvailable
    }

    private let monitor = PasteboardMonitor()
    private let hotKeyManager = GlobalHotKeyManager(identifier: 1)
    private let gifHotKeyManager = GlobalHotKeyManager(identifier: 2)
    private let stackStartHotKeyManager = GlobalHotKeyManager(identifier: 3)
    private let stackNextHotKeyManager = GlobalHotKeyManager(identifier: 4)
    private let panelController = ClipboardPanelController()
    private let screenshotCaptureService = ScreenshotCaptureService()
    private let screenGIFRecorder = ScreenGIFRecorder()
    private let quickLookPreview = ClipboardQuickLookPreview()
    private let annotationEditorController = AnnotationEditorController()
    private let authenticationService = DeviceAuthenticationService()
    private var settingsWindow: NSWindow?
    private var favoritesWindow: NSWindow?
    private var targetApplication: NSRunningApplication?
    private var pasteTask: Task<Void, Never>?
    private var recordingMonitor: Any?
    private var accessibilityTimer: Timer?
    private var hasStarted = false
    private var isUpdatingLaunchAtLogin = false
    private var isAuthenticatingPrivateView = false
    private var oldHotKey: HotKeyConfiguration
    private var oldGIFHotKey: HotKeyConfiguration?
    private var oldStackStartHotKey: HotKeyConfiguration?
    private var oldStackNextHotKey: HotKeyConfiguration?
    private var recordingHotKeyTarget: HotKeyTarget?
    private enum Keys {
        static let hotKey = "xboard.hotKey"
        static let gifHotKey = "xboard.gifHotKey"
        static let stackStartHotKey = "xboard.stackStartHotKey"
        static let stackNextHotKey = "xboard.stackNextHotKey"
        static let historyLimit = "xboard.historyLimit"
        static let retention = "xboard.retention"
        static let ignoredBundleIdentifiers = "xboard.ignoredBundleIdentifiers"
        static let appearance = "xboard.appearance"
        static let material = "xboard.material"
        static let launchAtLogin = "xboard.launchAtLogin"
        static let requireAuthenticationForPrivateViews = "xboard.requireAuthenticationForPrivateViews"
    }

    private init() {
        let savedHistoryLimit = UserDefaults.standard.integer(forKey: Keys.historyLimit)
        let savedRetention = UserDefaults.standard.string(forKey: Keys.retention)
            .flatMap(ClipboardRetention.init(rawValue:)) ?? .never
        store = ClipboardStore(
            limit: savedHistoryLimit == 0 ? 200 : savedHistoryLimit,
            retention: savedRetention,
            loadImmediately: false
        )
        snippetStore = SnippetStore(loadImmediately: false)
        let savedHotKey = (UserDefaults.standard.data(forKey: Keys.hotKey).flatMap { try? JSONDecoder().decode(HotKeyConfiguration.self, from: $0) }) ?? .default
        let savedGIFHotKey = (UserDefaults.standard.data(forKey: Keys.gifHotKey).flatMap { try? JSONDecoder().decode(HotKeyConfiguration.self, from: $0) })
        let savedStackStartHotKey = UserDefaults.standard.data(forKey: Keys.stackStartHotKey)
            .flatMap { try? JSONDecoder().decode(HotKeyConfiguration.self, from: $0) }
        let savedStackNextHotKey = UserDefaults.standard.data(forKey: Keys.stackNextHotKey)
            .flatMap { try? JSONDecoder().decode(HotKeyConfiguration.self, from: $0) }
        let savedIgnoredBundleIdentifiers = Set(UserDefaults.standard.stringArray(forKey: Keys.ignoredBundleIdentifiers) ?? [])
        let savedAppearance = UserDefaults.standard.string(forKey: Keys.appearance)
            .flatMap(ClipboardAppearance.init(rawValue:)) ?? .system
        let savedMaterial = UserDefaults.standard.string(forKey: Keys.material)
            .flatMap(ClipboardMaterial.init(rawValue:)) ?? .liquidGlass
        hotKey = savedHotKey
        oldHotKey = savedHotKey
        gifHotKey = savedGIFHotKey
        oldGIFHotKey = savedGIFHotKey
        stackStartHotKey = savedStackStartHotKey
        oldStackStartHotKey = savedStackStartHotKey
        stackNextHotKey = savedStackNextHotKey
        oldStackNextHotKey = savedStackNextHotKey
        historyLimit = store.limit
        retention = savedRetention
        ignoredBundleIdentifiers = savedIgnoredBundleIdentifiers
        appearance = savedAppearance
        material = savedMaterial
        launchAtLogin = SMAppService.mainApp.status == .enabled
        requireAuthenticationForPrivateViews = UserDefaults.standard.bool(
            forKey: Keys.requireAuthenticationForPrivateViews
        )

        hotKeyManager.onHotKey = { [weak self] in
            self?.showPanel()
        }
        gifHotKeyManager.onHotKey = { [weak self] in
            self?.toggleGIFRecording()
        }
        stackStartHotKeyManager.onHotKey = { [weak self] in
            self?.startClipboardStack()
        }
        stackNextHotKeyManager.onHotKey = { [weak self] in
            self?.pasteNextStackItem()
        }
        monitor.ignoredBundleIdentifiers = savedIgnoredBundleIdentifiers
        monitor.onSnapshot = { [weak self] snapshot, sourceApplication in
            guard let self else { return }
            self.store.ingest(snapshot, sourceApplication: sourceApplication)
            guard self.isCapturingStack,
                  let item = self.store.items.first(where: { $0.fingerprint == snapshot.fingerprint })
            else { return }
            self.clipboardStack.append(item.id)
        }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        retryStorageAccess()
        if !UserDefaults.standard.bool(forKey: "xboard.hasOpenedSettings") {
            UserDefaults.standard.set(true, forKey: "xboard.hasOpenedSettings")
            DispatchQueue.main.async { self.showSettings() }
        }
        refreshAvailableApplications()
        monitor.ignoredBundleIdentifiers = ignoredBundleIdentifiers
        monitor.start()
        oldHotKey = hotKey
        oldGIFHotKey = gifHotKey
        oldStackStartHotKey = stackStartHotKey
        oldStackNextHotKey = stackNextHotKey
        if !hotKeyManager.register(hotKey) {
            statusMessage = String(localized: "Could not register \(hotKey.displayString).")
        }
        if !gifHotKeyManager.register(gifHotKey), let gifHotKey {
            statusMessage = String(localized: "Could not register \(gifHotKey.displayString) for GIF recording.")
        }
        _ = stackStartHotKeyManager.register(stackStartHotKey)
        _ = stackNextHotKeyManager.register(stackNextHotKey)
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isAccessibilityTrusted = AXIsProcessTrusted()
                self?.refreshPauseState()
            }
        }
    }

    func stop() {
        pasteTask?.cancel()
        monitor.stop()
        hotKeyManager.stop()
        gifHotKeyManager.stop()
        stackStartHotKeyManager.stop()
        stackNextHotKeyManager.stop()
        screenGIFRecorder.cancel()
        annotationEditorController.close()
        quickLookPreview.close()
        favoritesWindow?.orderOut(nil)
        isCapturingStack = false
        clipboardStack.removeAll()
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
        stopRecordingHotKey()
    }

    func retryStorageAccess() {
        guard !isLoadingStorage else { return }
        isLoadingStorage = true
        // Keychain authorization can wait for user interaction; keep it off the UI thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try LocalDataKeychain.shared.keyData() }
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success = result {
                    self.store.load()
                    self.snippetStore.load()
                } else {
                    let message = String(localized: "Keychain access was not granted. Saved data was preserved; new items stay in memory.")
                    self.store.suspendPersistence(message: message)
                    self.snippetStore.suspendPersistence(message: message)
                }
                self.isLoadingStorage = false
            }
        }
    }

    func showPanel() {
        guard !panelController.isVisible else { return }
        pasteTask?.cancel()
        quickLookPreview.close()
        let currentProcessIdentifier = NSRunningApplication.current.processIdentifier
        let resolvedTargetApplication = panelController.targetApplication(
            excluding: currentProcessIdentifier
        )

        guard requireAuthenticationForPrivateViews else {
            presentPanel(targetApplication: resolvedTargetApplication)
            return
        }
        authenticatePrivateView(reason: String(localized: "Open clipboard history")) { [weak self] in
            self?.presentPanel(targetApplication: resolvedTargetApplication)
        }
    }

    private func presentPanel(targetApplication resolvedTargetApplication: NSRunningApplication?) {
        targetApplication = resolvedTargetApplication


        panelController.show(
            store: store,
            targetApplication: targetApplication,
            appearance: appearance,
            material: material,
            onPaste: { [weak self] item, format in self?.paste(item, format: format) },
            onTogglePin: { [weak self] item in self?.togglePin(item) },
            onPreview: { [weak self] item in self?.preview(item) },
            onEdit: { [weak self] item in self?.editImage(item) },
            onExtractText: { [weak self] item in self?.extractText(item) },
            onSaveGIF: { [weak self] item in self?.saveGIF(item) },
            onSaveFavorite: { [weak self] item in self?.saveAsFavorite(item) },
            onDelete: { [weak self] item in self?.deleteItem(item) },
            onEnableAutomaticPaste: { [weak self] in self?.openAccessibilitySettings() }
        )
    }

    func editImage(_ item: ClipboardItem) {
        guard item.hasImage, !item.isGIF, let imageData = item.imageData,
              let image = NSImage(data: imageData) else {
            statusMessage = String(localized: "This item cannot be edited.")
            return
        }

        panelController.close()
        annotationEditorController.show(
            image: image,
            appearance: appearance,
            material: material,
            onCopy: { [weak self] data in self?.copyAnnotatedScreenshot(data) }
        )
    }

    func extractText(_ item: ClipboardItem) {
        guard item.canExtractText, let imageData = item.imageData else {
            statusMessage = String(localized: "Text extraction is available for static images only.")
            return
        }

        panelController.close()
        statusMessage = String(localized: "Extracting text…")
        let storedOCRText = item.ocrText

        Task { [weak self] in
            let recognizedText: String?
            if let storedOCRText {
                recognizedText = storedOCRText
            } else {
                recognizedText = await Task.detached(priority: .userInitiated) {
                    LocalOCRService.recognize(imageData: imageData)
                }.value
            }

            guard let self else { return }
            guard let recognizedText, !recognizedText.isEmpty else {
                self.statusMessage = String(localized: "No text was detected in the image.")
                return
            }

            self.copyExtractedText(recognizedText, sourceApplication: item.sourceApplication)
        }
    }

    private func copyExtractedText(_ text: String, sourceApplication: ClipboardSourceApplication? = nil) {
        let pasteboard = NSPasteboard.general
        monitor.suppressCapture()
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            statusMessage = String(localized: "The extracted text could not be copied.")
            return
        }

        store.ingest(ClipboardSnapshot(
            text: text,
            richTextData: nil,
            imageData: nil,
            imageType: nil,
            fileURLs: []
        ), sourceApplication: sourceApplication)
        statusMessage = String(localized: "Extracted text copied to the clipboard.")
    }

    func preview(_ item: ClipboardItem) {
        panelController.close()
        guard quickLookPreview.show(item: item) else {
            statusMessage = String(localized: "No preview is available for this item.")
            return
        }
        statusMessage = nil
    }

    func togglePin(_ item: ClipboardItem) {
        let shouldPin = !item.isPinned
        _ = store.setPinned(item.id, pinned: shouldPin)
    }

    func deleteItem(_ item: ClipboardItem) {
        guard store.remove(item.id) else { return }
        statusMessage = String(localized: "Item deleted.")
    }

    func saveAsFavorite(_ item: ClipboardItem) {
        guard let text = item.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = String(localized: "Only text items can be saved to the Library.")
            return
        }
        _ = snippetStore.add(text: text)
        statusMessage = String(localized: "Saved to Library.")
    }

    func showFavorites() {
        pasteTask?.cancel()
        panelController.close()
        let resolvedTargetApplication = panelController.targetApplication(
            excluding: NSRunningApplication.current.processIdentifier
        )

        guard requireAuthenticationForPrivateViews else {
            presentFavorites(targetApplication: resolvedTargetApplication)
            return
        }
        authenticatePrivateView(reason: String(localized: "Open the clipboard Library")) { [weak self] in
            self?.presentFavorites(targetApplication: resolvedTargetApplication)
        }
    }

    private func presentFavorites(targetApplication resolvedTargetApplication: NSRunningApplication?) {
        targetApplication = resolvedTargetApplication

        if favoritesWindow == nil {
            let favoritesSize = NSSize(width: 520, height: 430)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: favoritesSize),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.appearance = appearance.nsAppearance
            window.setContentSize(favoritesSize)
            window.minSize = NSSize(width: 420, height: 320)
            window.title = String(localized: "Library — Xboard")
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let rootView = FavoritesView(
                store: snippetStore,
                material: material,
                onPaste: { [weak self] snippet in self?.pasteSnippet(snippet) },
                onClose: { [weak self] in self?.favoritesWindow?.orderOut(nil) }
            )
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.view.frame = NSRect(origin: .zero, size: favoritesSize)
            hostingController.view.autoresizingMask = [.width, .height]
            window.contentViewController = hostingController

            window.center()
            favoritesWindow = window
        }

        applyAppearance(appearance, to: favoritesWindow)
        favoritesWindow?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        favoritesWindow?.orderFrontRegardless()
        favoritesWindow?.makeKey()
    }

    func setPrivateViewAuthenticationEnabled(_ enabled: Bool) {
        guard enabled else {
            requireAuthenticationForPrivateViews = false
            UserDefaults.standard.set(false, forKey: Keys.requireAuthenticationForPrivateViews)
            statusMessage = String(localized: "History and Library authentication disabled.")
            return
        }

        guard authenticationService.isAvailable else {
            statusMessage = String(localized: "Touch ID or Mac authentication is unavailable.")
            return
        }

        authenticatePrivateView(reason: String(localized: "Protect clipboard history and Library")) { [weak self] in
            guard let self else { return }
            self.requireAuthenticationForPrivateViews = true
            UserDefaults.standard.set(true, forKey: Keys.requireAuthenticationForPrivateViews)
            self.statusMessage = String(localized: "History and Library authentication enabled.")
        }
    }

    private func authenticatePrivateView(reason: String, onSuccess: @escaping () -> Void) {
        guard !isAuthenticatingPrivateView else { return }
        isAuthenticatingPrivateView = true
        authenticationService.authenticate(reason: reason) { [weak self] success in
            guard let self else { return }
            self.isAuthenticatingPrivateView = false
            if success {
                onSuccess()
            } else {
                self.statusMessage = String(localized: "Authentication was cancelled or failed.")
            }
        }
    }

    func showSettings() {
        pasteTask?.cancel()
        panelController.close()
        refreshAvailableApplications()

        if settingsWindow == nil {
            let settingsSize = NSSize(width: 520, height: 500)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: settingsSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.appearance = appearance.nsAppearance
            window.setContentSize(settingsSize)
            window.minSize = settingsSize
            window.title = String(localized: "Settings — Xboard")
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.standardWindowButton(.closeButton)?.isEnabled = true
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = true

            let rootView = SettingsView()
                .environmentObject(self)
                .frame(width: settingsSize.width, height: settingsSize.height, alignment: .top)
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.view.frame = NSRect(origin: .zero, size: settingsSize)
            hostingController.view.autoresizingMask = [.width, .height]
            window.contentViewController = hostingController

            window.center()
            settingsWindow = window
        }

        applyAppearance(appearance, to: settingsWindow)
        settingsWindow?.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.orderFrontRegardless()
        settingsWindow?.makeKey()
    }

    private func applyAppearance(_ appearance: ClipboardAppearance, to window: NSWindow?) {
        window?.appearance = appearance.nsAppearance
        window?.contentView?.appearance = appearance.nsAppearance
        window?.backgroundColor = .windowBackgroundColor
        window?.contentView?.needsDisplay = true
    }

    func clearHistory() {
        store.clear()
        statusMessage = String(localized: "History cleared.")
    }

    func clearUnpinnedHistory() {
        let removedCount = store.clearUnpinned()
        statusMessage = removedCount == 0
            ? String(localized: "No unpinned items to clear.")
            : String(localized: "Cleared \(removedCount) unpinned items.")
    }

    func pauseHistory(for duration: ClipboardPauseDuration) {
        monitor.pauseHistory(for: duration)
        isHistoryPaused = true
        statusMessage = String(localized: "History capture paused.")
    }

    func resumeHistory() {
        monitor.resumeHistory()
        isHistoryPaused = false
        statusMessage = String(localized: "History capture resumed.")
    }

    func refreshPauseState() {
        guard isHistoryPaused else { return }
        if !monitor.isPaused {
            isHistoryPaused = false
            statusMessage = String(localized: "History capture resumed.")
        }
    }

    func refreshAvailableApplications() {
        let currentProcessIdentifier = NSRunningApplication.current.processIdentifier
        var applications = NSWorkspace.shared.runningApplications
            .filter {
                $0.processIdentifier != currentProcessIdentifier &&
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != nil
            }
            .compactMap { application -> ClipboardApplication? in
                guard let bundleIdentifier = application.bundleIdentifier else { return nil }
                return ClipboardApplication(
                    bundleIdentifier: bundleIdentifier,
                    displayName: application.localizedName ?? bundleIdentifier
                )
            }

        let knownBundleIdentifiers = Set(applications.map(\.bundleIdentifier))
        applications.append(contentsOf: ignoredBundleIdentifiers
            .subtracting(knownBundleIdentifiers)
            .map { ClipboardApplication(bundleIdentifier: $0, displayName: $0) })
        availableApplications = applications.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    func isApplicationIgnored(_ bundleIdentifier: String) -> Bool {
        ignoredBundleIdentifiers.contains(bundleIdentifier)
    }

    func setApplicationIgnored(_ bundleIdentifier: String, ignored: Bool) {
        var updated = ignoredBundleIdentifiers
        if ignored {
            updated.insert(bundleIdentifier)
        } else {
            updated.remove(bundleIdentifier)
        }
        ignoredBundleIdentifiers = updated
    }

    func startClipboardStack() {
        clipboardStack.removeAll()
        targetApplication = nil
        isCapturingStack = true
        statusMessage = String(localized: "Stack capture started. Copy the items you want to paste in sequence.")
    }

    func finishClipboardStack() {
        isCapturingStack = false
        if clipboardStack.isEmpty {
            statusMessage = String(localized: "Stack capture finished without items.")
        } else {
            statusMessage = String(localized: "Stack ready: \(clipboardStack.count) items queued.")
        }
    }

    func cancelClipboardStack() {
        isCapturingStack = false
        clipboardStack.removeAll()
        targetApplication = nil
        statusMessage = String(localized: "Stack cleared.")
    }

    func clearClipboardStack() {
        clipboardStack.removeAll()
        targetApplication = nil
        statusMessage = String(localized: "Stack cleared.")
    }

    func pasteNextStackItem() {
        guard !isCapturingStack else {
            statusMessage = String(localized: "Finish stack capture before pasting.")
            return
        }

        while let firstID = clipboardStack.itemIDs.first,
              store.item(withID: firstID) == nil {
            _ = clipboardStack.removeFirst()
        }

        guard let firstID = clipboardStack.itemIDs.first,
              let item = store.item(withID: firstID)
        else {
            targetApplication = nil
            statusMessage = String(localized: "The clipboard stack is empty.")
            return
        }

        let currentProcessIdentifier = NSRunningApplication.current.processIdentifier
        targetApplication = panelController.targetApplication(excluding: currentProcessIdentifier) ?? targetApplication
        let canPasteAutomatically = AXIsProcessTrusted() && targetApplication != nil
        guard paste(item, targetApplicationOverride: targetApplication) else { return }
        _ = clipboardStack.removeFirst()

        if clipboardStack.isEmpty {
            targetApplication = nil
            statusMessage = canPasteAutomatically
                ? String(localized: "Last stack item pasted.")
                : String(localized: "Last stack item is on the clipboard. Press ⌘V to paste.")
        } else {
            statusMessage = canPasteAutomatically
                ? String(localized: "Stack item pasted. (\(clipboardStack.count)) remaining.")
                : String(localized: "Stack item ready on the clipboard. Press ⌘V, then paste the next item.")
        }
    }

    func ignoreNextCopy() {
        monitor.ignoreNextCopy()
        statusMessage = String(localized: "Next clipboard copy will be ignored.")
    }

    func beginRecordingHotKey() {
        beginRecordingHotKey(for: .history)
    }

    func beginRecordingHotKey(for target: HotKeyTarget) {
        stopRecordingHotKey()
        recordingHotKeyTarget = target
        isRecordingHotKey = true
        let prompt: String
        switch target {
        case .history: prompt = String(localized: "Press a new history combination…")
        case .gif: prompt = String(localized: "Press a new GIF combination…")
        case .stackStart: prompt = String(localized: "Press a new stack start combination…")
        case .stackNext: prompt = String(localized: "Press a new paste next combination…")
        }
        statusMessage = prompt
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.stopRecordingHotKey()
                return nil
            }
            let modifiers = HotKeyConfiguration.modifiers(from: event.modifierFlags)
            guard modifiers != 0 else { return event }
            let candidate = HotKeyConfiguration(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            guard !self.isHotKeyInUse(candidate, excluding: target) else {
                self.statusMessage = String(localized: "That hotkey is already in use.")
                return nil
            }
            let registered: Bool
            switch target {
            case .history:
                registered = self.hotKeyManager.register(candidate)
                if registered {
                    self.oldHotKey = self.hotKey
                    self.hotKey = candidate
                }
            case .gif:
                registered = self.gifHotKeyManager.register(candidate)
                if registered {
                    self.oldGIFHotKey = self.gifHotKey
                    self.gifHotKey = candidate
                }
            case .stackStart:
                registered = self.stackStartHotKeyManager.register(candidate)
                if registered {
                    self.oldStackStartHotKey = self.stackStartHotKey
                    self.stackStartHotKey = candidate
                }
            case .stackNext:
                registered = self.stackNextHotKeyManager.register(candidate)
                if registered {
                    self.oldStackNextHotKey = self.stackNextHotKey
                    self.stackNextHotKey = candidate
                }
            }
            if registered {
                self.statusMessage = String(localized: "Hotkey set: \(candidate.displayString)")
            } else {
                self.statusMessage = String(localized: "Combination unavailable.")
            }
            self.stopRecordingHotKey()
            return nil
        }
    }

    func stopRecordingHotKey() {
        if let recordingMonitor { NSEvent.removeMonitor(recordingMonitor) }
        recordingMonitor = nil
        let shouldClearPrompt = isRecordingHotKey
        recordingHotKeyTarget = nil
        isRecordingHotKey = false
        if shouldClearPrompt {
            statusMessage = nil
        }
    }

    func isRecordingHotKey(for target: HotKeyTarget) -> Bool {
        isRecordingHotKey && recordingHotKeyTarget == target
    }

    func clearHotKey(for target: HotKeyTarget) {
        switch target {
        case .stackStart:
            stackStartHotKey = nil
            statusMessage = String(localized: "Stack start hotkey cleared.")
        case .stackNext:
            stackNextHotKey = nil
            statusMessage = String(localized: "Paste next hotkey cleared.")
        case .gif:
            gifHotKey = nil
            statusMessage = String(localized: "GIF recording hotkey cleared.")
        case .history:
            break
        }
    }

    private func persistOptionalHotKey(_ configuration: HotKeyConfiguration?, key: String) {
        guard let configuration else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(try? JSONEncoder().encode(configuration), forKey: key)
    }

    private func isHotKeyInUse(_ candidate: HotKeyConfiguration?, excluding target: HotKeyTarget) -> Bool {
        guard let candidate else { return false }
        let configured: [(HotKeyTarget, HotKeyConfiguration?)] = [
            (.history, hotKey),
            (.gif, gifHotKey),
            (.stackStart, stackStartHotKey),
            (.stackNext, stackNextHotKey)
        ]
        return configured.contains { configuredTarget, configuration in
            configuredTarget != target && configuration == candidate
        }
    }

    func openAccessibilitySettings() {
        panelController.close()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func captureAndAnnotate() {
        guard !isCapturingScreenshot else {
            statusMessage = String(localized: "A screen capture is already in progress.")
            return
        }

        panelController.close()
        annotationEditorController.close()
        settingsWindow?.orderOut(nil)
        isCapturingScreenshot = true
        statusMessage = String(localized: "Select an area to capture…")

        screenshotCaptureService.captureSelection { [weak self] result in
            guard let self else { return }
            self.isCapturingScreenshot = false
            switch result {
            case .success(let image):
                self.statusMessage = nil
                self.annotationEditorController.show(
                    image: image,
                    appearance: self.appearance,
                    material: self.material,
                    onCopy: { [weak self] data in self?.copyAnnotatedScreenshot(data) }
                )
            case .failure(.cancelled):
                self.statusMessage = nil
            case .failure(let error):
                self.statusMessage = error.localizedDescription
            }
        }
    }

    private func copyAnnotatedScreenshot(_ data: Data) {
        let pasteboard = NSPasteboard.general
        monitor.suppressCapture()
        pasteboard.clearContents()
        guard pasteboard.setData(data, forType: .png) else {
            statusMessage = String(localized: "The annotated screenshot could not be copied.")
            return
        }
        store.ingest(ClipboardSnapshot(
            text: nil,
            richTextData: nil,
            imageData: data,
            imageType: NSPasteboard.PasteboardType.png.rawValue,
            fileURLs: []
        ))
        statusMessage = String(localized: "Annotated screenshot copied to the clipboard.")
    }

    func recordGIF() {
        guard !isRecordingGIF else {
            statusMessage = String(localized: "A GIF recording is already in progress.")
            return
        }

        panelController.close()
        annotationEditorController.close()
        settingsWindow?.orderOut(nil)
        isRecordingGIF = true
        statusMessage = String(localized: "Drag to select an area. Release to start recording.")

        screenGIFRecorder.start { [weak self] result in
            guard let self else { return }
            self.isRecordingGIF = false
            switch result {
            case .success(let data):
                self.copyGIFToClipboard(data)
            case .failure(.cancelled):
                self.statusMessage = nil
            case .failure(let error):
                self.statusMessage = error.localizedDescription
            }
        }
    }

    func toggleGIFRecording() {
        if isRecordingGIF {
            finishGIFRecording()
        } else {
            recordGIF()
        }
    }

    func cancelGIFRecording() {
        guard isRecordingGIF else { return }
        statusMessage = String(localized: "Cancelling GIF recording…")
        screenGIFRecorder.cancel()
    }

    func finishGIFRecording() {
        guard isRecordingGIF else { return }
        statusMessage = String(localized: "Finishing GIF recording…")
        screenGIFRecorder.finish()
    }

    func saveLatestGIF() {
        guard let item = store.items.first(where: { $0.isGIF }) else {
            statusMessage = String(localized: "No GIF is available to save.")
            return
        }
        saveGIF(item)
    }

    func saveGIF(_ item: ClipboardItem) {
        guard item.isGIF, let data = item.imageData else {
            statusMessage = String(localized: "This item is not a GIF.")
            return
        }

        panelController.close()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.gif]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = GIFFileExporter.defaultFilename()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let outputURL = try GIFFileExporter.write(data, to: url)
                self?.statusMessage = String(localized: "GIF saved to \(outputURL.lastPathComponent).")
            } catch {
                self?.statusMessage = String(localized: "The GIF could not be saved.")
            }
        }
    }

    private func pasteSnippet(_ snippet: ClipboardSnippet) {
        favoritesWindow?.orderOut(nil)
        let item = ClipboardItem(
            fingerprint: "snippet-\(snippet.id.uuidString)",
            text: snippet.text,
            richTextData: nil,
            imageData: nil,
            imageType: nil,
            files: []
        )
        _ = paste(item, targetApplicationOverride: targetApplication)
    }

    private func copyGIFToClipboard(_ data: Data) {
        let pasteboard = NSPasteboard.general
        let gifType = NSPasteboard.PasteboardType(UTType.gif.identifier)
        monitor.suppressCapture()
        pasteboard.clearContents()
        guard pasteboard.setData(data, forType: gifType) else {
            statusMessage = String(localized: "The GIF could not be copied to the clipboard.")
            return
        }

        store.ingest(ClipboardSnapshot(
            text: nil,
            richTextData: nil,
            imageData: data,
            imageType: gifType.rawValue,
            fileURLs: []
        ))
        statusMessage = String(localized: "GIF copied to the clipboard. Press ⌘V to paste.")
    }

    @discardableResult
    private func paste(
        _ item: ClipboardItem,
        format: ClipboardPasteFormat = .original,
        targetApplicationOverride: NSRunningApplication? = nil
    ) -> Bool {
        guard let payload = ClipboardPasteFormatter.payload(for: item, format: format) else {
            statusMessage = String(localized: "\(format.title) is unavailable for this item.")
            return false
        }

        pasteTask?.cancel()
        panelController.close()
        let pasteboard = NSPasteboard.general
        monitor.suppressCapture()
        pasteboard.clearContents()

        if let text = payload.text { pasteboard.setString(text, forType: .string) }
        if let richTextData = payload.richTextData { pasteboard.setData(richTextData, forType: .rtf) }
        if let imageData = payload.imageData, let imageType = payload.imageType {
            pasteboard.setData(imageData, forType: NSPasteboard.PasteboardType(imageType))
        }
        let urls = payload.fileURLs
        if !urls.isEmpty { pasteboard.writeObjects(urls as [NSURL]) }

        guard let destination = targetApplicationOverride ?? targetApplication else {
            statusMessage = String(localized: "Item restored to the clipboard. Press ⌘V to paste.")
            return true
        }
        isAccessibilityTrusted = AXIsProcessTrusted()
        guard isAccessibilityTrusted else {
            statusMessage = String(localized: "Item restored to the clipboard. Press ⌘V to paste.")
            let alert = NSAlert()
            alert.messageText = String(localized: "Automatic paste needs Accessibility access.")
            alert.informativeText = String(localized: "The item is on the clipboard. Enable Xboard in Accessibility to paste automatically. If it is already enabled, turn its permission off and on, then reopen Xboard.")
            alert.addButton(withTitle: String(localized: "Open System Settings"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn {
                openAccessibilitySettings()
            } else {
                NSApp.yieldActivation(to: destination)
                _ = destination.activate(from: .current, options: [])
            }
            return true
        }

        statusMessage = nil
        let handoff = ClipboardPasteHandoff(
            destinationPID: destination.processIdentifier,
            sourcePID: NSRunningApplication.current.processIdentifier,
            restoredChangeCount: pasteboard.changeCount,
            deadline: Date().addingTimeInterval(1.5)
        )
        NSApp.yieldActivation(to: destination)
        guard destination.activate(from: .current, options: []) else {
            statusMessage = String(localized: "Item restored to the clipboard. Press ⌘V to paste.")
            return true
        }
        pasteTask = Task { [weak self] in
            while !Task.isCancelled {
                switch handoff.decision(
                    frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                    changeCount: pasteboard.changeCount,
                    isTrusted: AXIsProcessTrusted(),
                    now: Date()
                ) {
                case .paste:
                    let source = CGEventSource(stateID: .privateState)
                    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
                    else {
                        self?.statusMessage = String(localized: "Item restored to the clipboard. Press ⌘V to paste.")
                        return
                    }
                    keyDown.flags = .maskCommand
                    keyUp.flags = .maskCommand
                    keyDown.post(tap: .cghidEventTap)
                    keyUp.post(tap: .cghidEventTap)
                    return
                case .cancel:
                    self?.statusMessage = String(localized: "Item restored to the clipboard. Press ⌘V to paste.")
                    return
                case .wait:
                    do { try await Task.sleep(for: .milliseconds(20)) }
                    catch { return }
                }
            }
        }
        return true
    }
}
