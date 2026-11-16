import AppKit
import Core
import SwiftUI
import UniformTypeIdentifiers

/// The Settings window (fork redesign), opened with ⌘, from the panel: a standard `Settings`
/// scene with one grouped form per topic, applied at once.
enum SettingsTab: String, CaseIterable {
    case general, apps, clipboard, permissions, advanced
}

// One name per idea, used by the panel, Settings and tooltips alike.
extension ClipboardMode {
    var label: String {
        switch self {
        case .off: "Off"
        case .yank: "Yanks"
        case .unnamed: "Yanks and Deletes"
        }
    }

    var explanation: String {
        switch self {
        case .off: "Yanks and deletes stay inside uvim. \"+y still copies to the clipboard."
        case .yank: "y copies to the clipboard; d, c and x stay inside uvim."
        case .unnamed: "y, d, c and x all copy to the clipboard, like Vim's unnamedplus."
        }
    }
}

extension VimPolicy {
    var label: String {
        switch self {
        case .auto: "Auto"
        case .off: "Off"
        case .forced: "Send Keys Without Reading the Field"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    let updater: Updater?
    @AppStorage("settingsTab") private var tab = SettingsTab.general

    var body: some View {
        TabView(selection: $tab) {
            GeneralTab(model: model, updater: updater)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            AppsTab(model: model)
                .tabItem { Label("Apps", systemImage: "square.grid.2x2") }
                .tag(SettingsTab.apps)
            ClipboardTab(model: model)
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
                .tag(SettingsTab.clipboard)
            PermissionsTab(model: model)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
            AdvancedTab(model: model)
                .tabItem { Label("Advanced", systemImage: "gearshape.2") }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 520)
        .onAppear { model.refresh() }
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var model: AppModel
    let updater: Updater?

    var body: some View {
        Form {
            Section {
                Toggle("Turn Vim Mode on or off with ⌃⌥⌘V", isOn: $model.toggleShortcutEnabled)
                    .controlSize(.mini)
                Picker("Normal-mode key", selection: $model.normalModeKey) {
                    Text("Esc or ⌃[").tag(NormalModeKey.escape)
                    Text("⌃[ only, so Esc reaches the app").tag(NormalModeKey.controlBracket)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Vim Mode")
            }
            Section {
                Toggle("Start uvim at login", isOn: Binding(
                    get: { model.loginItem == .on },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .controlSize(.mini)
                if model.loginItem == .blocked {
                    LabeledContent("macOS is holding the login item for approval") {
                        Button("Open Login Items…") { model.openLoginItemsSettings() }
                    }
                }
            } header: {
                Text("Startup")
            }
            if let updater {
                UpdatesSection(updater: updater)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Its own view so the form observes `Updater`, which `AppModel` does not own.
private struct UpdatesSection: View {
    @ObservedObject var updater: Updater

    var body: some View {
        Section {
            Toggle("Check for updates automatically", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticallyChecksForUpdates($0) }
            ))
            .controlSize(.mini)
            LabeledContent(updater.pendingVersion.map { "uvim \($0) is available" } ?? "Updates") {
                Button(updater.pendingVersion == nil ? "Check for Updates…" : "Update…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        } header: {
            Text("Updates")
        }
    }
}

// MARK: - Apps

private struct AppsTab: View {
    @ObservedObject var model: AppModel
    @State private var selection: Set<String> = []
    @State private var search = ""
    @State private var removed: [AppModel.AppSnapshot] = []

    private var rows: [AppModel.AppRow] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.apps }
        return model.apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Where uvim runs", selection: $model.appScope) {
                    Text("Every app except those set to Off").tag(AppScope.everywhere)
                    Text("Only apps set to Auto").tag(AppScope.onlyAllowed)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text("Where uvim runs")
            } footer: {
                Text(model.appScope == .everywhere
                    ? "Terminals and editors with their own Vim mode start Off."
                    : "uvim stays out of every app until you set it to Auto here or in the panel.")
            }

            Section {
                TextField("Search apps", text: $search, prompt: Text("Search apps"))
                    .labelsHidden()
                table
                HStack(spacing: 0) {
                    addMenu
                    Button {
                        remove(selection)
                    } label: {
                        Image(systemName: "minus").frame(width: 22, height: 18)
                    }
                    .disabled(selection.isEmpty)
                    .help("Remove the selected apps from the list (⌫)")
                    Spacer()
                    if !removed.isEmpty {
                        Text(removedSummary).foregroundStyle(.secondary)
                        Button("Undo") { undo() }
                            .keyboardShortcut("z", modifiers: .command)
                            .padding(.leading, 8)
                    }
                }
                .buttonStyle(.borderless)
            } header: {
                Text("Apps")
            } footer: {
                if !footnote.isEmpty { Text(footnote) }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.reloadApps() }
    }

    private var table: some View {
        Table(rows, selection: $selection) {
            TableColumn("App") { row in
                HStack(spacing: 6) {
                    Image(nsImage: row.icon).resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                    Text(row.name).lineLimit(1).truncationMode(.middle)
                }
                .help(row.installed ? row.id : "\(row.id), not installed")
            }
            TableColumn("Vim") { row in
                Picker("Vim in \(row.name)", selection: Binding(
                    get: { row.policy },
                    set: { model.setPolicy($0, for: row.id) }
                )) {
                    Text(VimPolicy.auto.label).tag(VimPolicy.auto)
                    Text(VimPolicy.off.label).tag(VimPolicy.off)
                    Divider()
                    Text(VimPolicy.forced.label).tag(VimPolicy.forced)
                }
                .labelsHidden()
                .help("Choose whether uvim handles keys in \(row.name)")
            }
            .width(min: 80, ideal: 90)
            TableColumn("Clipboard") { row in
                Picker("Clipboard in \(row.name)", selection: Binding(
                    get: { row.clipboard },
                    set: { model.setClipboard($0, for: row.id) }
                )) {
                    Text("Same as Everywhere").tag(ClipboardMode?.none)
                    Divider()
                    ForEach(ClipboardMode.allCases, id: \.self) { Text($0.label).tag(ClipboardMode?.some($0)) }
                }
                .labelsHidden()
                .opacity(row.policy == .off ? 0 : 1)
                .disabled(row.policy == .off)
                .help(row.policy == .off ? "Not used while Vim is Off in \(row.name)"
                    : "Choose what yanks and deletes copy in \(row.name)")
            }
            .width(min: 140, ideal: 160)
        }
        .frame(height: 240)
        .contextMenu(forSelectionType: String.self) { ids in
            if !ids.isEmpty {
                Button("Set Vim to Auto") { ids.forEach { model.setPolicy(.auto, for: $0) } }
                Button("Set Vim to Off") { ids.forEach { model.setPolicy(.off, for: $0) } }
                Button(VimPolicy.forced.label) { ids.forEach { model.setPolicy(.forced, for: $0) } }
                Divider()
                Button(ids.count == 1 ? "Remove from List" : "Remove \(ids.count) Apps from List") { remove(ids) }
            }
        }
        .onDeleteCommand { remove(selection) }
        .onKeyPress(.delete) {
            guard !selection.isEmpty else { return .ignored }
            remove(selection)
            return .handled
        }
    }

    private var addMenu: some View {
        Menu {
            let running = model.runningApps
            if !running.isEmpty {
                Section("Running Now") {
                    ForEach(running) { app in
                        Button(app.name) { model.addApp(app.id) }
                    }
                }
            }
            Button("Choose from Applications…") { model.chooseApps() }
        } label: {
            Image(systemName: "plus").frame(width: 22, height: 18)
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Add an app to the list")
    }

    /// What the list leaves out: built-in apps not installed here, and prefix families.
    private var footnote: String {
        var parts: [String] = []
        let hidden = model.hiddenBuiltIns
        if !hidden.isEmpty {
            parts.append("Also Off if you install them: \(hidden.joined(separator: ", ")).")
        }
        if model.appPrefixes.contains("com.jetbrains.") {
            parts.append("JetBrains IDEs are Off unless listed here.")
        }
        return parts.joined(separator: " ")
    }

    private var removedSummary: String {
        removed.count == 1 ? "Removed \(removed[0].name)" : "Removed \(removed.count) apps"
    }

    private func remove(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        removed = model.removeApps(ids)
        selection = []
    }

    private func undo() {
        model.restore(removed)
        selection = Set(removed.map(\.id))
        removed = []
    }
}

// MARK: - Clipboard

private struct ClipboardTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                Picker("What reaches the clipboard", selection: $model.clipboardMode) {
                    ForEach(ClipboardMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.label)
                            Text(mode.explanation).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            } header: {
                Text("What reaches the clipboard")
            } footer: {
                Text("Text you copy in another app becomes what p puts. Each app can have its own setting in Apps.")
            }
            Section {
                Text("In fields macOS cannot read, uvim deletes with ⌘X, so deletes reach the clipboard whatever you choose here.")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Fields uvim cannot read")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Permissions

private struct PermissionsTab: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                permission(
                    "Accessibility", detail: "Reads the caret and selection in text fields.",
                    allowed: model.accessibilityTrusted, pane: "Privacy_Accessibility"
                )
                permission(
                    "Input Monitoring", detail: "Sees Esc and your Vim keys. Relaunch uvim after allowing it.",
                    allowed: model.inputMonitoringGranted, pane: "Privacy_ListenEvent"
                )
                LabeledContent("Keyboard listener") {
                    Text(model.tap == .installed ? "Running" : "Not running")
                        .foregroundStyle(model.tap == .installed ? .primary : .secondary)
                }
            } header: {
                Text("Permissions")
            } footer: {
                Text("Nothing you type is recorded or sent anywhere. uvim's only network traffic is the update check.")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func permission(_ name: String, detail: String, allowed: Bool, pane: String) -> some View {
        LabeledContent {
            if allowed {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
            } else {
                Button("Open System Settings…") { model.openPrivacyPane(pane) }
            }
        } label: {
            Text(name)
            Text(detail)
        }
    }
}

// MARK: - Advanced

private struct AdvancedTab: View {
    @ObservedObject var model: AppModel
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Button("Open Beliefs File") { model.openBeliefsFile() }
                } label: {
                    Text("What uvim learned about fields")
                    if !model.beliefsReadable {
                        Text("The file is unreadable; the last good version is in use.")
                    }
                }
            } header: {
                Text("Field Capabilities")
            }
            Section {
                LabeledContent {
                    Button("Reset App List…", role: .destructive) { confirmingReset = true }
                } label: {
                    Text("Go back to the built-in list")
                    Text("Removes every per-app Vim and clipboard setting.")
                }
            } header: {
                Text("Reset")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .confirmationDialog("Reset the app list to uvim's built-in list?", isPresented: $confirmingReset) {
            Button("Reset App List", role: .destructive) { model.resetApps() }
        } message: {
            Text("Every app's Vim and clipboard setting is removed. Settings that apply everywhere stay.")
        }
    }
}
