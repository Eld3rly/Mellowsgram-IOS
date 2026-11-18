import Foundation
import Postbox
import SwiftSignalKit

/// Account-local settings for Mellowsgram features.
public struct MellowsgramSettings: Codable, Equatable {
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
    public let translucentDeletedMessages: Bool
    /// Keep regular cloud-chat media usable after Telegram's client-side
    /// autoremove/autoclear deadline. Secret and ephemeral messages are still
    /// excluded by the archive/privacy guards.
    public let ignoreAutoremoveTimers: Bool
    /// Keep selected account connections alive while the app is backgrounded
    /// so incoming Telegram updates can be converted into local notifications.
    /// This is deliberately opt-in because it has a measurable battery cost.
    public let backgroundNotificationsEnabled: Bool
    /// When enabled, apply background notifications to every signed-in
    /// account. Otherwise only the primary account is kept active.
    public let backgroundNotificationsAllAccounts: Bool

    public static var defaultSettings: MellowsgramSettings {
        return MellowsgramSettings(
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
            translucentDeletedMessages: false,
            ignoreAutoremoveTimers: true,
            backgroundNotificationsEnabled: false,
            backgroundNotificationsAllAccounts: false
        )
    }

    public init(
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
        translucentDeletedMessages: Bool,
        ignoreAutoremoveTimers: Bool = true,
        backgroundNotificationsEnabled: Bool = false,
        backgroundNotificationsAllAccounts: Bool = false
    ) {
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
        self.translucentDeletedMessages = translucentDeletedMessages
        self.ignoreAutoremoveTimers = ignoreAutoremoveTimers
        self.backgroundNotificationsEnabled = backgroundNotificationsEnabled
        self.backgroundNotificationsAllAccounts = backgroundNotificationsAllAccounts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.ghostMode = (try container.decodeIfPresent(Int32.self, forKey: "ghostMode") ?? 0) != 0
        // Missing keys are intentional here: older account preferences should
        // get the safe AyuGram-compatible defaults without a migration pass.
        self.ghostDontReadMessages = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontReadMessages") ?? 1) != 0
        self.ghostDontReadStories = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontReadStories") ?? 1) != 0
        self.ghostDontSendOnline = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontSendOnline") ?? 1) != 0
        self.ghostDontSendTyping = (try container.decodeIfPresent(Int32.self, forKey: "ghostDontSendTyping") ?? 1) != 0
        self.ghostGoOfflineAutomatically = (try container.decodeIfPresent(Int32.self, forKey: "ghostGoOfflineAutomatically") ?? 1) != 0
        self.ghostReadOnInteract = (try container.decodeIfPresent(Int32.self, forKey: "ghostReadOnInteract") ?? 1) != 0
        self.ghostScheduleMessages = (try container.decodeIfPresent(Int32.self, forKey: "ghostScheduleMessages") ?? 0) != 0
        self.ghostStoryModeAlert = (try container.decodeIfPresent(Int32.self, forKey: "ghostStoryModeAlert") ?? 1) != 0
        self.saveDeletedMessages = (try container.decodeIfPresent(Int32.self, forKey: "saveDeletedMessages") ?? 1) != 0
        self.saveEditedMessages = (try container.decodeIfPresent(Int32.self, forKey: "saveEditedMessages") ?? 1) != 0
        self.showDeletedMessages = (try container.decodeIfPresent(Int32.self, forKey: "showDeletedMessages") ?? 1) != 0
        self.translucentDeletedMessages = (try container.decodeIfPresent(Int32.self, forKey: "translucentDeletedMessages") ?? 0) != 0
        self.ignoreAutoremoveTimers = (try container.decodeIfPresent(Int32.self, forKey: "ignoreAutoremoveTimers") ?? 1) != 0
        self.backgroundNotificationsEnabled = (try container.decodeIfPresent(Int32.self, forKey: "backgroundNotificationsEnabled") ?? 0) != 0
        self.backgroundNotificationsAllAccounts = (try container.decodeIfPresent(Int32.self, forKey: "backgroundNotificationsAllAccounts") ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
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
        try container.encode((self.translucentDeletedMessages ? 1 : 0) as Int32, forKey: "translucentDeletedMessages")
        try container.encode((self.ignoreAutoremoveTimers ? 1 : 0) as Int32, forKey: "ignoreAutoremoveTimers")
        try container.encode((self.backgroundNotificationsEnabled ? 1 : 0) as Int32, forKey: "backgroundNotificationsEnabled")
        try container.encode((self.backgroundNotificationsAllAccounts ? 1 : 0) as Int32, forKey: "backgroundNotificationsAllAccounts")
    }

    public func withUpdatedGhostMode(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ghostMode: value)
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
        return self.copy(translucentDeletedMessages: value)
    }

    public func withUpdatedIgnoreAutoremoveTimers(_ value: Bool) -> MellowsgramSettings {
        return self.copy(ignoreAutoremoveTimers: value)
    }

    public func withUpdatedBackgroundNotificationsEnabled(_ value: Bool) -> MellowsgramSettings {
        return self.copy(backgroundNotificationsEnabled: value)
    }

    public func withUpdatedBackgroundNotificationsAllAccounts(_ value: Bool) -> MellowsgramSettings {
        return self.copy(backgroundNotificationsAllAccounts: value)
    }

    public var ghostModeOptions: MellowsgramGhostModeOptions {
        var result = MellowsgramGhostModeOptions()
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
        translucentDeletedMessages: Bool? = nil,
        ignoreAutoremoveTimers: Bool? = nil,
        backgroundNotificationsEnabled: Bool? = nil,
        backgroundNotificationsAllAccounts: Bool? = nil
    ) -> MellowsgramSettings {
        return MellowsgramSettings(
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
            translucentDeletedMessages: translucentDeletedMessages ?? self.translucentDeletedMessages,
            ignoreAutoremoveTimers: ignoreAutoremoveTimers ?? self.ignoreAutoremoveTimers,
            backgroundNotificationsEnabled: backgroundNotificationsEnabled ?? self.backgroundNotificationsEnabled,
            backgroundNotificationsAllAccounts: backgroundNotificationsAllAccounts ?? self.backgroundNotificationsAllAccounts
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
