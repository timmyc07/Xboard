import ApplicationServices
import SwiftUI

extension View {
    @ViewBuilder
    func clipboardGlassSurface<S: Shape>(in shape: S, material: ClipboardMaterial = .liquidGlass) -> some View {
        if material == .liquidGlass, #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }

    @ViewBuilder
    func clipboardGlassButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    func clipboardGlassEntranceTransition(material: ClipboardMaterial = .liquidGlass) -> some View {
        if material == .liquidGlass, #available(macOS 26.0, *) {
            glassEffectTransition(.materialize)
        } else {
            self
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showingClearConfirmation = false
    @State private var showingClearUnpinnedConfirmation = false

    var body: some View {
        let storageError = appState.store.persistenceErrorMessage ?? appState.snippetStore.persistenceErrorMessage
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OptionV")
                        .font(.title2.bold())
                    Text(String(localized: "Your clipboard history, free and stored only on this Mac."))
                    Text(String(localized: "Press \(appState.hotKey.displayString) to search copied text, images, and files."))
                        .font(.callout)
                    Text(String(localized: "Select an item to paste. Without Accessibility permission, select it and press ⌘V in the destination app."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Allow clipboard access when macOS asks so OptionV can save your copied items."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                settingsSection(String(localized: "Hotkeys")) {
                    Text(String(localized: "Option-based shortcuts may be blocked in password fields. Change the shortcut if it conflicts with your input method."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    settingsCard {
                        VStack(spacing: 0) {
                            hotKeyRow(
                                title: String(localized: "Open history"),
                                configuration: appState.hotKey,
                                target: .history
                            )

                            Divider()
                                .padding(.vertical, 12)

                            hotKeyRow(
                                title: String(localized: "Record GIF"),
                                configuration: appState.gifHotKey,
                                target: .gif
                            )

                            Divider()
                                .padding(.vertical, 12)

                            hotKeyRow(
                                title: String(localized: "Start Clipboard Stack"),
                                configuration: appState.stackStartHotKey,
                                target: .stackStart
                            )

                            Divider()
                                .padding(.vertical, 12)

                            hotKeyRow(
                                title: String(localized: "Paste Next Stack Item"),
                                configuration: appState.stackNextHotKey,
                                target: .stackNext
                            )
                        }
                    }
                }

                settingsSection(String(localized: "History")) {
                    settingsCard {
                        VStack(spacing: 0) {
                            HStack {
                                Text(String(localized: "Recent unpinned items"))
                                Spacer()
                                TextField(String(localized: "History limit"), value: $appState.historyLimit, format: .number.grouping(.never))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 85)
                                .controlSize(.small)
                            }
                            Text(String(localized: "Choose any count of 10 or more. Pinned items do not count toward this limit. Large image histories use more memory and disk space."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)

                            Divider()
                                .padding(.vertical, 12)

                            HStack {
                                Button(String(localized: "Clear history"), role: .destructive) {
                                    showingClearConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }

                            Divider()
                                .padding(.vertical, 12)

                            HStack {
                                Button(String(localized: "Clear unpinned"), role: .destructive) {
                                    showingClearUnpinnedConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Spacer()
                            }

                            Divider()
                                .padding(.vertical, 12)

                            HStack {
                                Text(String(localized: "Retention"))
                                Spacer()
                                Picker(String(localized: "Retention"), selection: $appState.retention) {
                                    ForEach(ClipboardRetention.allCases) { option in
                                        Text(option.title).tag(option)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .controlSize(.small)
                            }

                            Text(String(localized: "Unpinned items older than this are removed automatically. Pinned items are kept."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                    }
                }

                settingsSection(String(localized: "Privacy")) {
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(
                                    appState.isHistoryPaused ? String(localized: "History paused") : String(localized: "History capture"),
                                    systemImage: appState.isHistoryPaused ? "pause.circle.fill" : "record.circle"
                                )
                                Spacer()
                                if appState.isHistoryPaused {
                                    Button(String(localized: "Resume")) { appState.resumeHistory() }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                } else {
                                    Menu(String(localized: "Pause")) {
                                        ForEach(ClipboardPauseDuration.allCases) { duration in
                                            Button(duration.title) {
                                                appState.pauseHistory(for: duration)
                                            }
                                        }
                                    }
                                    .controlSize(.small)
                                }
                            }

                            Divider()

                            Text(String(localized: "Ignore applications"))
                                .font(.subheadline.weight(.semibold))

                            if appState.availableApplications.isEmpty {
                                Text(String(localized: "No other running applications found."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(appState.availableApplications) { application in
                                    Toggle(isOn: Binding(
                                        get: { appState.isApplicationIgnored(application.bundleIdentifier) },
                                        set: { appState.setApplicationIgnored(application.bundleIdentifier, ignored: $0) }
                                    )) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(application.displayName)
                                            Text(application.bundleIdentifier)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }

                            Text(String(localized: "Copies made while an ignored application is active are not stored."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                settingsSection(String(localized: "Local security")) {
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(String(localized: "Encrypted storage"), systemImage: "lock.shield.fill")
                                Spacer()
                                Text(appState.isLoadingStorage ? String(localized: "Waiting for Keychain access…") : storageError == nil ? String(localized: "Active") : String(localized: "Unavailable"))
                                    .foregroundStyle(storageError == nil && !appState.isLoadingStorage ? .green : .orange)
                            }

                            Text(String(localized: "History and Library files are encrypted with AES-GCM. The key is stored in this Mac's Keychain and is not synced or uploaded."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider()

                            Toggle(isOn: Binding(
                                get: { appState.requireAuthenticationForPrivateViews },
                                set: { appState.setPrivateViewAuthenticationEnabled($0) }
                            )) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(String(localized: "Protect History and Library"))
                                    Text(String(localized: "Require Touch ID or the Mac password each time either private view is opened."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(localized: "Clipboard capture continues in the background."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .disabled(
                                !appState.isDeviceAuthenticationAvailable
                                && !appState.requireAuthenticationForPrivateViews
                            )

                            if !appState.isDeviceAuthenticationAvailable {
                                Text(String(localized: "Device authentication is unavailable on this Mac."))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }

                            if let storageError = appState.store.persistenceErrorMessage
                                ?? appState.snippetStore.persistenceErrorMessage {
                                Label(storageError, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            if appState.isLoadingStorage {
                                Text(String(localized: "Complete the macOS Keychain prompt. Until then, new items remain in memory."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if storageError != nil {
                                Button(String(localized: "Retry storage access")) { appState.retryStorageAccess() }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                settingsSection(String(localized: "Startup")) {
                    settingsCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(String(localized: "Launch at login"), isOn: $appState.launchAtLogin)
                            Text(String(localized: "Start OptionV automatically after you sign in."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                settingsSection(String(localized: "Appearance")) {
                    settingsCard {
                        VStack(alignment: .leading, spacing: 0) {
                            appearancePicker(
                                title: String(localized: "Color scheme"),
                                selection: $appState.appearance,
                                options: ClipboardAppearance.allCases
                            )

                            Divider()
                                .padding(.vertical, 10)

                            appearancePicker(
                                title: String(localized: "Material"),
                                selection: $appState.material,
                                options: ClipboardMaterial.allCases
                            )

                            Text(String(localized: "Liquid Glass uses the native glass surface on macOS 26 or later and a material fallback on earlier versions."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 12)
                        }
                    }
                }

                settingsSection(String(localized: "Automatic paste")) {
                    settingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(
                                    String(localized: "Accessibility"),
                                    systemImage: appState.isAccessibilityTrusted
                                        ? "checkmark.circle.fill"
                                        : "exclamationmark.triangle.fill"
                                )
                                Spacer()
                                Text(appState.isAccessibilityTrusted ? String(localized: "Active") : String(localized: "Required"))
                                    .foregroundStyle(appState.isAccessibilityTrusted ? .green : .orange)
                            }

                            if !appState.isAccessibilityTrusted {
                                Text(String(localized: "Grant access to paste into the previous app automatically. History and manual paste work without it."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(String(localized: "Open System Settings")) {
                                    appState.openAccessibilitySettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                if let statusMessage = appState.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(22)
        }
        .frame(width: 520, height: 500)
        .confirmationDialog(String(localized: "Clear history?"), isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button(String(localized: "Clear"), role: .destructive) { appState.clearHistory() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Removes text, images, and references stored by the app."))
        }
        .confirmationDialog(String(localized: "Clear unpinned history?"), isPresented: $showingClearUnpinnedConfirmation, titleVisibility: .visible) {
            Button(String(localized: "Clear unpinned"), role: .destructive) { appState.clearUnpinnedHistory() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Pinned items and original files remain untouched."))
        }
        .task {
            appState.refreshAvailableApplications()
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(14)
            .background(
                Color.primary.opacity(0.065),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }

    private func hotKeyRow(
        title: String,
        configuration: HotKeyConfiguration?,
        target: HotKeyTarget
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            Text(appState.isRecordingHotKey(for: target) ? String(localized: "Press a new combination…") : configuration?.displayString ?? String(localized: "Not set"))
                .monospaced()
                .foregroundStyle(.secondary)
            Button(appState.isRecordingHotKey(for: target) ? String(localized: "Cancel") : configuration == nil ? String(localized: "Set") : String(localized: "Change")) {
                if appState.isRecordingHotKey(for: target) {
                    appState.stopRecordingHotKey()
                } else {
                    appState.beginRecordingHotKey(for: target)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if target != .history && configuration != nil && !appState.isRecordingHotKey(for: target) {
                Button(String(localized: "Clear")) {
                    appState.clearHotKey(for: target)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }

    private func appearancePicker<Option: Hashable & Identifiable>(
        title: String,
        selection: Binding<Option>,
        options: [Option]
    ) -> some View where Option.ID == String {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(optionTitle(option)).tag(option)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
        }
    }

    private func optionTitle<Option>(_ option: Option) -> String {
        if let appearance = option as? ClipboardAppearance { return appearance.title }
        if let material = option as? ClipboardMaterial { return material.title }
        return String(describing: option)
    }
}
