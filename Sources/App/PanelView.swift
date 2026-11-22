import AppKit
import Core
import SwiftUI

/// The panel the menu-bar icon opens (fork redesign): one status line, what applies to the app in
/// front, the two settings people change often, and the way to Settings. Everything else lives in
/// the Settings window. System fonts, sizes and colours throughout, so dark mode and Increase
/// Contrast come for free.
struct PanelView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @AppStorage("settingsTab") private var settingsTab = SettingsTab.general

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let warning = model.setupWarning {
                setup(warning)
            }
            if model.vimEnabled, let front = model.frontApp {
                Divider()
                frontAppSection(front)
            }
            Divider()
            everywhere
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { model.refresh() }
        .onExitCommand { NSApp.keyWindow?.close() }
    }

    // One line says where Vim stands: the icon already shows the mode's shape.
    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("uvim").font(.headline)
                Text(model.statusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Toggle("Vim Mode", isOn: $model.vimEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(model.toggleShortcutEnabled
                    ? "Turn Vim keys on or off in every app (⌃⌥⌘V)"
                    : "Turn Vim keys on or off in every app")
        }
    }

    private func setup(_ warning: AppModel.SetupWarning) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(warning.message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.primary)
            if let action = warning.action {
                Button(action.title) { model.perform(action) }
            }
        }
    }

    private func frontAppSection(_ front: AppModel.FrontApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In \(front.name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if model.frontAppPolicy == .off {
                Text("Every key, Esc included, goes to \(front.name).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Picker("Vim", selection: Binding(
                get: { model.frontAppPolicy },
                set: { model.setFrontAppPolicy($0) }
            )) {
                Text(VimPolicy.auto.label).tag(VimPolicy.auto)
                Text(VimPolicy.off.label).tag(VimPolicy.off)
                Divider()
                Text(VimPolicy.forced.label).tag(VimPolicy.forced)
            }
            .help("Choose whether uvim handles keys in \(front.name)")
            Picker("Clipboard", selection: Binding(
                get: { model.frontAppClipboard },
                set: { model.setFrontAppClipboard($0) }
            )) {
                Text("Same as Everywhere (\(model.clipboardMode.label))").tag(ClipboardMode?.none)
                Divider()
                ForEach(ClipboardMode.allCases, id: \.self) { Text($0.label).tag(ClipboardMode?.some($0)) }
            }
            .disabled(model.frontAppPolicy == .off)
            .help("Choose what yanks and deletes copy in \(front.name)")
            if model.frontAppPolicy != .off, model.normalModeKey == .escape {
                Toggle("Esc goes to \(front.name); ⌃[ enters Normal mode", isOn: Binding(
                    get: { model.frontAppEscapeToApp },
                    set: { model.setFrontAppEscapeToApp($0) }
                ))
                .help("For apps where Esc stops or cancels something, such as Claude")
            }
            if model.frontAppPolicy != .off {
                CapabilitiesItem(
                    title: "Field Capabilities", menu: model.capabilities,
                    choose: model.setCapabilityOverride, forget: model.forget, clear: model.clearOverrides
                )
                .help("See and change what uvim detected about \(model.surfaceLabel)")
            }
        }
    }

    private var everywhere: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Everywhere")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Clipboard", selection: $model.clipboardMode) {
                ForEach(ClipboardMode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .help("Choose what yanks and deletes copy to the clipboard")
            Picker("Normal-mode key", selection: $model.normalModeKey) {
                Text("Esc").tag(NormalModeKey.escape)
                Text("⌃[").tag(NormalModeKey.controlBracket)
            }
            .pickerStyle(.segmented)
            .help("Choose the key that enters Normal mode; ⌃[ always works, and apps set to pass Esc through keep it")
        }
    }

    private var footer: some View {
        HStack {
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Spacer()
            Button("Quit uvim") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
    }
}
