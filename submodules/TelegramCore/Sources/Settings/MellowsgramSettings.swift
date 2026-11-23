import Foundation
import Postbox
import SwiftSignalKit

/// Ghost Mode options exposed to UI modules. The runtime coordinator lives in
/// Postbox, so this module-level value keeps UI code independent of Postbox's
/// implementation types while preserving the same bit layout.
public struct MellowsgramGhostModePolicyOptions: OptionSet, Equatable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let dontReadMessages = MellowsgramGhostModePolicyOptions(rawValue: 1 << 0)
    public static let dontReadStories = MellowsgramGhostModePolicyOptions(rawValue: 1 << 1)
    public static let dontSendOnline = MellowsgramGhostModePolicyOptions(rawValue: 1 << 2)
    public static let dontSendTyping = MellowsgramGhostModePolicyOptions(rawValue: 1 << 3)
    public static let goOfflineAutomatically = MellowsgramGhostModePolicyOptions(rawValue: 1 << 4)
}

/// Bridges the app-wide Mellowsgram policy into the Postbox runtime without
/// exposing Postbox implementation types to TelegramUIPreferences.
public func updateMellowsgramGlobalGhostModeRuntime(
    enabled: Bool,
    dontReadMessages: Bool,
    dontReadStories: Bool,
    dontSendOnline: Bool,
    dontSendTyping: Bool,
    goOfflineAutomatically: Bool
) {
    var options = MellowsgramGhostModeOptions()
    if dontReadMessages {
        options.insert(.dontReadMessages)
    }
    if dontReadStories {
        options.insert(.dontReadStories)
    }
    if dontSendOnline {
        options.insert(.dontSendOnline)
    }
    if dontSendTyping {
        options.insert(.dontSendTyping)
    }
    if goOfflineAutomatically {
        options.insert(.goOfflineAutomatically)
    }
    MellowsgramGlobalGhostModeRuntime.shared.update(enabled: enabled, options: options)
}

/// Account-local settings for Mellowsgram features.
public struct MellowsgramSettings: Codable, Equatable {
    /// When true, Ghost Mode is inherited from the app-wide policy. An
    /// account can opt out and keep an independent override.
    public let usesGlobalGhostMode: Bool
    public let ghostMode: Bool
    // The global Ghost Mode switch controls the policy as a whole. These
    // account-scoped flags are the individual AyuGram-style safeguards that
    // the switch applies. Keeping them separately also lets a user opt out of
    // one side effect without losing the rest of the Ghost Mode setup.
    public let ghostDontReadMessages: Bool
    public let ghostDontReadStories: Bool
    public let ghostDontSendOnline: Bool
    public let ghostDontSendTyping: Bool
    public let ghostGoOfflineAutomatically: Bool
    public let ghostReadOnInteract: Bool
    public let ghostScheduleMessages: Bool
    public let ghostStoryModeAlert: Bool
    public let saveDeletedMessages: Bool
    public let saveEditedMessages: Bool
    public let showDeletedMessages: Bool
    /// Opacity of an archived deleted-message row, expressed as a percentage.
    /// 100 means fully opaque. The old Bool setting is decoded below for
    /// backwards compatibility (true -> 58%, false -> 100%).
    public let deletedMessageOpacity: Int32
    /// Keep regular cloud-chat media usable after Telegram's client-side
    /// autoremove/autoclear deadline. Secret and ephemeral messages are still
    /// excluded by the archive/privacy guards.
    public let ignoreAutoremoveTimers: Bool
    public static var defaultSettings: MellowsgramSettings {
        return MellowsgramSettings(
            usesGlobalGhostMode: true,
            ghostMode: false,
            ghostDontReadMessages: true,
            ghostDontReadStories: true,
            ghostDontSendOnline: true,
            ghostDontSendTyping: true,
            ghostGoOfflineAutomatically: true,
            ghostReadOnInteract: true,
            ghostScheduleMessages: false,
            ghostStoryModeAlert: true,
            saveDeletedMessages: true,
            saveEditedMessages: true,
            showDeletedMessages: true,
            deletedMessageOpacity: 100,
            ignoreAutoremoveTimers: true
        )
    }

    /// Compatibility view for older callers. New code should use
    /// `deletedMessageOpacity` directly.
    public var translucentDeletedMessages: Bool {
        return self.deletedMessageOpacity < 100
    }

    public init(
        usesGlobalGhostMode: Bool = true,
        ghostMode: Bool,
        ghostDontReadMessages: Bool = true,
        ghostDontReadStories: Bool = true,
        ghostDontSendOnline: Bool = true,
        ghostDontSendTyping: Bool = true,
        ghostGoOfflineAutomatically: Bool = true,
        ghostReadOnInteract: Bool = true,
        ghostScheduleMessages: Bool = false,
        ghostStoryModeAlert: Bool = true,
        saveDeletedMessages: Bool,
        saveEditedMessages: Bool,
        showDeletedMessages: Bool,
        deletedMessageOpacity: Int32 = 100,
        ignoreAutoremoveTimers: Bool = true
    ) {
        self.usesGlobalGhostMode = usesGlobalGhostMode
        self.ghostMode = ghostMode
        self.ghostDontReadMessages = ghostDontReadMessages
        self.ghostDontReadStories = ghostDontReadStories
        self.ghostDontSendOnline = ghostDontSendOnline
        self.ghostDontSendTyping = ghostDontSendTyping
        self.ghostGoOfflineAutomatically = ghostGoOfflineAutomatically
        self.ghostReadOnInteract = ghostReadOnInteract
        self.ghostScheduleMessages = ghostScheduleMessages
        self.ghostStoryModeAlert = ghostStoryModeAlert
        self.saveDeletedMessages = saveDeletedMessages
        self.saveEditedMessages = saveEditedMessages
        self.showDeletedMessages = showDeletedMessages
        self.deletedMessageOpacity = min(100, max(30, deletedMessageOpacity))
        self.ignoreAutoremoveTimers = ignoreAutoremoveTimers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        let ghostMode = (try container.decodeIfPresent(Int32.self, forKey: "ghostMode") ?? 0) != 0
        self.ghostMode = ghostMode
        // Missing keys are intentional here: older account preferences should
        // get the safe AyuGram-compatible defaults without a migration pass.
        let ghostDontReadMessages = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontReadMessages") ?? 1) != 0
        let ghostDontReadStories = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontReadStories") ?? 1) != 0
        let ghostDontSendOnline = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontSendOnline") ?? 1) != 0
        let ghostDontSendTyping = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontSendTyping") ?? 1) != 0
        let ghostGoOfflineAutomatically = (try container.decodeIfPresent(Int32.self, forKey: "ghostGoOfflineAutomatically") ?? 1) != 0
        self.ghostDontReadMessages = ghostDontReadMessages
        self.ghostDontReadStories = ghostDontReadStories
        self.ghostDontSendOnline = ghostDontSendOnline
        self.ghostDontSendTyping = ghostDontSendTyping
        self.ghostGoOfflineAutomatically = ghostGoOfflineAutomatically
        self.ghostReadOnInteract = (try container.decodeIfPresent(Int32.self, forKey: "ghostReadOnInteract") ?? 1) != 0
        self.ghostScheduleMessages = (try container.decodeIfPresent(Int32.self, forKey: "ghostScheduleMessages") ?? 0) != 0
        self.ghostStoryModeAlert = (try container.decodeIfPresent(Int32.self, forKey: "ghostStoryModeAlert") ?? 1) != 0
        self.saveDeletedMessages = (try container.decodeIfPresent(Int32.self, forKey: "saveDeletedMessages") ?? 1) != 0
        self.saveEditedMessages = (try container.decodeIfPresent(Int32.self, forKey: "saveEditedMessages") ?? 1) != 0
        self.showDeletedMessages = (try container.decodeIfPresent(Int32.self, forKey: "showDeletedMessages") ?? 1) != 0
        if let storedOpacity = try container.decodeIfPresent(Int32.self, forKey: "deletedMessageOpacity") {
            self.deletedMessageOpacity = min(100, max(30, storedOpacity))
        } else {
            let legacyTranslucent = (try container.decodeIfPresent(Int32.self, forKey: "translucentDeletedMessages") ?? 0) != 0
            self.deletedMessageOpacity = legacyTranslucent ? 58 : 100
        }
        if let storedUsesGlobal = try container.decodeIfPresent(Int32.self, forKey: "usesGlobalGhostMode") {
            self.usesGlobalGhostMode = storedUsesGlobal != 0
        } else {
            // Preserve an explicitly customised legacy account. Accounts that
            // still contain the old defaults safely inherit the new global
            // policy.
            let legacyDefaults = ghostMode == MellowsgramSettings.defaultSettings.ghostMode
                && ghostDontReadMessages == MellowsgramSettings.defaultSettings.ghostDontReadMessages
                && ghostDontReadStories == MellowsgramSettings.defaultSettings.ghostDontReadStories
                && ghostDontSendOnline == MellowsgramSettings.defaultSettings.ghostDontSendOnline
                && ghostDontSendTyping == MellowsgramSettings.defaultSettings.ghostDontSendTyping
                && ghostGoOfflineAutomatically == MellowsgramSettings.defaultSettings.ghostGoOfflineAutomatically
            self.usesGlobalGhostMode = legacyDefaults
        }
        self.ignoreAutoremoveTimers = (try container.decodeIfPresent(Int32.self, forKey: "ignoreAutoremoveTimers") ?? 1) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode((self.usesGlobalGhostMode ? 1 : 0) as Int32, forKey: "usesGlobalGhostMode")
        try container.encode((self.ghostMode ? 1 : 0) as Int32, forKey: "ghostMode")
        try container.encode((self.ghostDontReadMessages ? 1 : 0) as Int32, forKey: "ghostDontReadMessages")
        try container.encode((self.ghostDontReadStories ? 1 : 0) as Int32, forKey: "ghostDontReadStories")
        try container.encode((self.ghostDontSendOnline ? 1 : 0) as Int32, forKey: "ghostDontSendOnline")
        try container.encode((self.ghostDontSendTyping ? 1 : 0) as Int32, forKey: "ghostDontSendTyping")
        try container.encode((self.ghostGoOfflineAutomatically ? 1 : 0) as Int32, forKey: "ghostGoOfflineAutomatically")
        try container.encode((self.ghostReadOnInteract ? 1 : 0) as Int32, forKey: "ghostReadOnInteract")
        try container.encode((self.ghostScheduleMessages ? 1 : 0) as Int32, forKey: "ghostScheduleMessages")
        try container.encode((self.ghostStoryModeAlert ? 1 : 0) as Int32, forKey: "ghostStoryModeAlert")
        try container.encode((self.saveDeletedMessages ? 1 : 0) as Int32, forKey: "saveDeletedMessages")
        try container.encode((self.saveEditedMessages ? 1 : 0) as Int32, forKey: "saveEditedMessages")
        try container.encode((self.showDeletedMessages ? 1 : 0) as Int32, forKey: "showDeletedMessages")
        try container.encode(self.deletedMessageOpacity, forKey: "deletedMessageOpacity")
        // Keep the legacy field so an older Mellowsgram build does not lose
        // the user's visual preference when it reads this entry.
        try container.encode((self.translucentDeletedMessages ? 1 : 0) as Int32, forKey: "translucentDeletedMessages")
        try container.encode((self.ignoreAutoremoveTimers ? 1 : 0) as Int32, forKey: "ignoreAutoremoveTimers")
    }

    public func withUpdatedGhostMode(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostMode: value)
    }

    public func withUpdatedUsesGlobalGhostMode(_ value: Bool) -> MellowsgramSettings {
        return self.copy(usesGlobalGhostMode: value)
    }

    public func withUpdatedGhostDontReadMessages(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostDontReadMessages: value)
    }

    public func withUpdatedGhostDontReadStories(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostDontReadStories: value)
    }

    public func withUpdatedGhostDontSendOnline(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostDontSendOnline: value)
    }

    public func withUpdatedGhostDontSendTyping(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostDontSendTyping: value)
    }

    public func withUpdatedGhostGoOfflineAutomatically(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostGoOfflineAutomatically: value)
    }

    public func withUpdatedGhostReadOnInteract(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostReadOnInteract: value)
    }

    public func withUpdatedGhostScheduleMessages(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostScheduleMessages: value)
    }

    public func withUpdatedGhostStoryModeAlert(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostStoryModeAlert: value)
    }

    public func withUpdatedSaveDeletedMessages(_ value: Bool) -> MellowsgramSettings {
        return self.copy(saveDeletedMessages: value)
    }

    public func withUpdatedSaveEditedMessages(_ value: Bool) -> MellowsgramSettings {
        return self.copy(saveEditedMessages: value)
    }

    public func withUpdatedShowDeletedMessages(_ value: Bool) -> MellowsgramSettings {
        return self.copy(showDeletedMessages: value)
    }

    public func withUpdatedTranslucentDeletedMessages(_ value: Bool) -> MellowsgramSettings {
        return self.copy(deletedMessageOpacity: value ? 58 : 100)
    }

    public func withUpdatedDeletedMessageOpacity(_ value: Int32) -> MellowsgramSettings {
        return self.copy(deletedMessageOpacity: value)
    }

    public func withUpdatedIgnoreAutoremoveTimers(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ignoreAutoremoveTimers: value)
    }

    public var ghostModeOptions: MellowsgramGhostModePolicyOptions {
        var result = MellowsgramGhostModePolicyOptions()
        if self.ghostDontReadMessages {
            result.insert(.dontReadMessages)
        }
        if self.ghostDontReadStories {
            result.insert(.dontReadStories)
        }
        if self.ghostDontSendOnline {
            result.insert(.dontSendOnline)
        }
        if self.ghostDontSendTyping {
            result.insert(.dontSendTyping)
        }
        if self.ghostGoOfflineAutomatically {
            result.insert(.goOfflineAutomatically)
        }
        return result
    }

    private func copy(
        usesGlobalGhostMode: Bool? = nil,
        ghostMode: Bool? = nil,
        ghostDontReadMessages: Bool? = nil,
        ghostDontReadStories: Bool? = nil,
        ghostDontSendOnline: Bool? = nil,
        ghostDontSendTyping: Bool? = nil,
        ghostGoOfflineAutomatically: Bool? = nil,
        ghostReadOnInteract: Bool? = nil,
        ghostScheduleMessages: Bool? = nil,
        ghostStoryModeAlert: Bool? = nil,
        saveDeletedMessages: Bool? = nil,
        saveEditedMessages: Bool? = nil,
        showDeletedMessages: Bool? = nil,
        deletedMessageOpacity: Int32? = nil,
        ignoreAutoremoveTimers: Bool? = nil
    ) -> MellowsgramSettings {
        return MellowsgramSettings(
            usesGlobalGhostMode: usesGlobalGhostMode ?? self.usesGlobalGhostMode,
            ghostMode: ghostMode ?? self.ghostMode,
            ghostDontReadMessages: ghostDontReadMessages ?? self.ghostDontReadMessages,
            ghostDontReadStories: ghostDontReadStories ?? self.ghostDontReadStories,
            ghostDontSendOnline: ghostDontSendOnline ?? self.ghostDontSendOnline,
            ghostDontSendTyping: ghostDontSendTyping ?? self.ghostDontSendTyping,
            ghostGoOfflineAutomatically: ghostGoOfflineAutomatically ?? self.ghostGoOfflineAutomatically,
            ghostReadOnInteract: ghostReadOnInteract ?? self.ghostReadOnInteract,
            ghostScheduleMessages: ghostScheduleMessages ?? self.ghostScheduleMessages,
            ghostStoryModeAlert: ghostStoryModeAlert ?? self.ghostStoryModeAlert,
            saveDeletedMessages: saveDeletedMessages ?? self.saveDeletedMessages,
            saveEditedMessages: saveEditedMessages ?? self.saveEditedMessages,
            showDeletedMessages: showDeletedMessages ?? self.showDeletedMessages,
            deletedMessageOpacity: deletedMessageOpacity ?? self.deletedMessageOpacity,
            ignoreAutoremoveTimers: ignoreAutoremoveTimers ?? self.ignoreAutoremoveTimers
        )
    }
}

public func updateMellowsgramSettingsInteractively(postbox: Postbox, _ f: @escaping (MellowsgramSettings) -> MellowsgramSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.mellowsgramSettings, { entry in
            let currentSettings = entry?.get(MellowsgramSettings.self) ?? MellowsgramSettings.defaultSettings
            return PreferencesEntry(f(currentSettings))
        })
    }
}

public func mellowsgramSettings(postbox: Postbox) -> Signal<MellowsgramSettings, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.mellowsgramSettings])
    |> map { view in
        return view.values[PreferencesKeys.mellowsgramSettings]?.get(MellowsgramSettings.self) ?? MellowsgramSettings.defaultSettings
    }
    |> distinctUntilChanged
}

/// Engine-facing account-local settings access for consumer modules.
public func updateMellowsgramSettingsInteractively(engine: TelegramEngine, _ f: @escaping (MellowsgramSettings) -> MellowsgramSettings) -> Signal<Never, NoError> {
    return engine.preferences.update(id: PreferencesKeys.mellowsgramSettings, { entry in
        let currentSettings = entry?.get(MellowsgramSettings.self) ?? MellowsgramSettings.defaultSettings
        return PreferencesEntry(f(currentSettings))
    })
}

/// Engine-facing account-local settings signal for consumer modules.
public func mellowsgramSettings(engine: TelegramEngine) -> Signal<MellowsgramSettings, NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.mellowsgramSettings))
    |> map { entry in
        return entry?.get(MellowsgramSettings.self) ?? MellowsgramSettings.defaultSettings
    }
    |> distinctUntilChanged
}
