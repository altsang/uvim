import Foundation

/// What vim does in one app: engage where a textual field proves itself
/// (`auto`), never (`off`), or bind the app itself when no accessibility
/// surface exists (`forced` — lane-C chords, explicit opt-in only).
public enum VimPolicy: String, CaseIterable, Sendable {
    case auto, off, forced
}

/// The key that enters Normal mode: ⌃[ always does, and `escape` adds Esc.
public enum NormalModeKey: String, CaseIterable, Sendable {
    case controlBracket, escape
}

/// The neutral Prefs store — Core's UserDefaults-backed configuration
/// surface. First resident: the per-app vim policy, consulted by the
/// runtime at *binding* time (never per keystroke).
public enum Prefs {
    static let disabledIDsKey = "disabledBundleIDs"
    static let disabledPrefixesKey = "disabledBundleIDPrefixes"
    static let enabledIDsKey = "enabledBundleIDs"
    static let forcedIDsKey = "forcedBundleIDs"
    static let normalModeKeyKey = "normalModeKey"
    // Fork settings.
    static let allowedIDsKey = "allowedBundleIDs"
    static let appScopeKey = "appScope"
    static let clipboardModeKey = "clipboardMode"
    static let clipboardOverridesKey = "clipboardOverrides"
    static let appliedSeedsKey = "appliedSeedBundleIDs"
    static let toggleShortcutKey = "toggleShortcutEnabled"
    static let escapeToAppIDsKey = "escapeToAppBundleIDs"
    /// Apps where Esc stops work in progress, so it reaches them and ⌃[ enters Normal mode.
    static let seedEscapeToAppIDs = ["com.anthropic.claudefordesktop"]
    static let hasEngagedKey = "hasEngagedNormalMode"

    /// Where every setting lives; tests swap in a private suite.
    nonisolated(unsafe) static var store = UserDefaults.standard

    /// Apps where engaging vim is destructive by default: terminals (Esc
    /// must reach the shell, or the real vim running inside) and editors
    /// whose users run their own vim emulation.
    static let seedDisabledIDs = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "com.apple.dt.Xcode",
        "dev.zed.Zed",
        "com.qvacua.VimR",
        "com.neovide.neovide",
        // Fork additions: more editors whose users run their own Vim emulation.
        "com.microsoft.VSCodeInsiders",
        "com.vscodium",
        "com.exafunction.windsurf",
    ]
    /// Display names for the built-in list, for when the app is not installed and macOS cannot name it.
    public static let builtInNames: [String: String] = [
        "com.apple.Terminal": "Terminal", "com.googlecode.iterm2": "iTerm", "net.kovidgoyal.kitty": "kitty",
        "org.alacritty": "Alacritty", "com.github.wez.wezterm": "WezTerm", "com.mitchellh.ghostty": "Ghostty",
        "dev.warp.Warp-Stable": "Warp", "com.microsoft.VSCode": "Visual Studio Code",
        "com.todesktop.230313mzl4w4u92": "Cursor", "com.apple.dt.Xcode": "Xcode", "dev.zed.Zed": "Zed",
        "com.qvacua.VimR": "VimR", "com.neovide.neovide": "Neovide",
        "com.microsoft.VSCodeInsiders": "VS Code Insiders", "com.vscodium": "VSCodium",
        "com.exafunction.windsurf": "Windsurf",
    ]

    /// Whether an app is on the built-in Off list.
    public static func isBuiltInOff(_ bundleID: String) -> Bool {
        seedDisabledIDs.contains(bundleID)
    }

    /// The seeds upstream shipped, which an install that predates seed tracking already has.
    static let upstreamSeedCount = 13
    static let seedDisabledPrefixes = ["com.jetbrains."]

    /// Seeds apply until the user writes a key; a written key then owns its
    /// value, so removals of seeded entries persist. Seeds added in a later
    /// build still reach it: `applyNewSeeds` writes each one once, unless the
    /// user already chose a setting for that app.
    public static func registerDefaults() {
        store.register(defaults: [
            disabledIDsKey: seedDisabledIDs,
            disabledPrefixesKey: seedDisabledPrefixes,
            enabledIDsKey: [String](),
            forcedIDsKey: [String](),   // forced is opt-in: never seeded
            allowedIDsKey: [String](),
            escapeToAppIDsKey: seedEscapeToAppIDs,
        ])
        applyNewSeeds()
    }

    static func applyNewSeeds() {
        let applied = store.stringArray(forKey: appliedSeedsKey)
            ?? Array(seedDisabledIDs.prefix(upstreamSeedCount))
        let chosen = Set(stringArray(allowedIDsKey) + stringArray(forcedIDsKey) + stringArray(enabledIDsKey))
        for id in seedDisabledIDs where !applied.contains(id) && !chosen.contains(id) {
            setDisabled(true, for: id)
        }
        store.set(seedDisabledIDs, forKey: appliedSeedsKey)
    }

    public static var normalModeKey: NormalModeKey {
        get {
            store.string(forKey: normalModeKeyKey).flatMap(NormalModeKey.init(rawValue:))
                ?? .escape
        }
        set { store.set(newValue.rawValue, forKey: normalModeKeyKey) }
    }

    /// ⌃⌥⌘V turns Vim Mode on or off from any app; on until the user turns it off.
    public static var toggleShortcutEnabled: Bool {
        get { store.object(forKey: toggleShortcutKey) as? Bool ?? true }
        set { store.set(newValue, forKey: toggleShortcutKey) }
    }

    /// Whether Normal mode was ever entered: until then the panel teaches the first Esc.
    public static var hasEngaged: Bool {
        get { store.object(forKey: hasEngagedKey) as? Bool ?? false }
        set { store.set(newValue, forKey: hasEngagedKey) }
    }

    /// Everywhere but Off apps (upstream), or only apps set to Auto or Force.
    public static var appScope: AppScope {
        get { store.string(forKey: appScopeKey).flatMap(AppScope.init(rawValue:)) ?? .everywhere }
        set { store.set(newValue.rawValue, forKey: appScopeKey) }
    }

    /// The clipboard setting for apps without their own: yanks reach it.
    public static var clipboardMode: ClipboardMode {
        get { store.string(forKey: clipboardModeKey).flatMap(ClipboardMode.init(rawValue:)) ?? .yank }
        set { store.set(newValue.rawValue, forKey: clipboardModeKey) }
    }

    /// One app's own clipboard setting; nil follows `clipboardMode`.
    public static func clipboardOverride(for bundleID: String) -> ClipboardMode? {
        clipboardOverrides[bundleID].flatMap(ClipboardMode.init(rawValue:))
    }

    public static func setClipboardOverride(_ mode: ClipboardMode?, for bundleID: String) {
        var overrides = clipboardOverrides
        overrides[bundleID] = mode?.rawValue
        store.set(overrides, forKey: clipboardOverridesKey)
    }

    public static func clipboardMode(for bundleID: String) -> ClipboardMode {
        clipboardOverride(for: bundleID) ?? clipboardMode
    }

    /// Whether Esc goes to this app even when Esc enters Normal mode elsewhere (⌃[ still does here).
    public static func escapeReachesApp(_ bundleID: String) -> Bool {
        escapeToAppIDs.contains(bundleID)
    }

    public static func setEscapeReachesApp(_ reaches: Bool, for bundleID: String) {
        var ids = escapeToAppIDs.filter { $0 != bundleID }
        if reaches { ids.append(bundleID) }
        store.set(ids, forKey: escapeToAppIDsKey)
    }

    public static var escapeToAppIDs: [String] { stringArray(escapeToAppIDsKey) }

    /// A built-in Esc entry nobody changed and nothing else set for the app: its row can hide while the app is missing.
    public static func isUntouchedEscapeSeed(_ bundleID: String) -> Bool {
        seedEscapeToAppIDs.contains(bundleID) && escapeReachesApp(bundleID) && clipboardOverride(for: bundleID) == nil
            && ![disabledIDsKey, enabledIDsKey, forcedIDsKey, allowedIDsKey].contains { stringArray($0).contains(bundleID) }
    }

    private static var clipboardOverrides: [String: String] {
        store.dictionary(forKey: clipboardOverridesKey) as? [String: String] ?? [:]
    }

    /// Every app with a setting of its own, for the Apps window: seeded,
    /// chosen in the menu or the window, or given a clipboard setting.
    public static func configuredApps() -> [String] {
        let ids = stringArray(disabledIDsKey) + stringArray(enabledIDsKey) + stringArray(forcedIDsKey)
            + stringArray(allowedIDsKey) + Array(clipboardOverrides.keys) + escapeToAppIDs
        return Array(Set(ids)).sorted()
    }

    /// The prefix families that start Off (JetBrains), for the Apps window's note.
    public static var disabledPrefixes: [String] { stringArray(disabledPrefixesKey) }

    /// Drops every setting of one app: it then follows the app scope like any app never set.
    public static func forget(bundleID: String) {
        for key in [disabledIDsKey, enabledIDsKey, forcedIDsKey, allowedIDsKey] {
            store.set(stringArray(key).filter { $0 != bundleID }, forKey: key)
        }
        setClipboardOverride(nil, for: bundleID)
        setEscapeReachesApp(false, for: bundleID)
    }

    /// Back to the built-in Off list: every app's setting goes; the global ones stay.
    public static func resetApps() {
        for key in [disabledIDsKey, disabledPrefixesKey, enabledIDsKey, forcedIDsKey, allowedIDsKey,
                    clipboardOverridesKey, escapeToAppIDsKey] {
            store.removeObject(forKey: key)
        }
        store.set(seedDisabledIDs, forKey: appliedSeedsKey)
    }

    public static func policy(for bundleID: String) -> VimPolicy {
        if stringArray(forcedIDsKey).contains(bundleID) { return .forced }
        if isDisabled(bundleID: bundleID) { return .off }
        if appScope == .onlyAllowed, !stringArray(allowedIDsKey).contains(bundleID) { return .off }
        return .auto
    }

    /// Invariant: `setPolicy(p, for: id)` ⟹ `policy(for: id) == p` — even
    /// for seeded or prefix-family apps (the picker must never show a lie).
    public static func setPolicy(_ policy: VimPolicy, for bundleID: String) {
        var forced = stringArray(forcedIDsKey)
        // Allowed records an explicit Auto, which "only these apps" reads.
        var allowed = stringArray(allowedIDsKey)
        switch policy {
        case .forced:
            if !forced.contains(bundleID) { forced.append(bundleID) }
            setDisabled(false, for: bundleID)
        case .off:
            forced.removeAll { $0 == bundleID }
            allowed.removeAll { $0 == bundleID }
            setDisabled(true, for: bundleID)
        case .auto:
            forced.removeAll { $0 == bundleID }
            if !allowed.contains(bundleID) { allowed.append(bundleID) }
            setDisabled(false, for: bundleID)
        }
        store.set(forced, forKey: forcedIDsKey)
        store.set(allowed, forKey: allowedIDsKey)
    }

    public static func isDisabled(bundleID: String) -> Bool {
        matches(bundleID,
                exact: stringArray(disabledIDsKey),
                prefixes: stringArray(disabledPrefixesKey),
                exceptions: stringArray(enabledIDsKey))
    }

    public static func setDisabled(_ disabled: Bool, for bundleID: String) {
        var exact = stringArray(disabledIDsKey)
        var exceptions = stringArray(enabledIDsKey)
        if disabled {
            exceptions.removeAll { $0 == bundleID }
            if !exact.contains(bundleID) { exact.append(bundleID) }
        } else {
            exact.removeAll { $0 == bundleID }
            // A prefix-disabled app (JetBrains family) can only be re-enabled
            // by exception — the prefix itself stays.
            if stringArray(disabledPrefixesKey).contains(where: { bundleID.hasPrefix($0) }),
               !exceptions.contains(bundleID) {
                exceptions.append(bundleID)
            }
        }
        store.set(exact, forKey: disabledIDsKey)
        store.set(exceptions, forKey: enabledIDsKey)
    }

    /// The pure matching core: exceptions override prefix families, never an
    /// exact entry (`setDisabled` keeps an ID out of both lists anyway).
    static func matches(_ id: String, exact: [String], prefixes: [String], exceptions: [String]) -> Bool {
        if exact.contains(id) { return true }
        if exceptions.contains(id) { return false }
        return prefixes.contains { id.hasPrefix($0) }
    }

    private static func stringArray(_ key: String) -> [String] {
        store.stringArray(forKey: key) ?? []
    }
}
