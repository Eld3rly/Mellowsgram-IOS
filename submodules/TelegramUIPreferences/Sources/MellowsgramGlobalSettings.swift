import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import UIKitRuntimeUtils

public func mellowsgramLocalizedString(english: String, russian: String, languageCode: String) -> String {
    let primaryLanguageCode = languageCode
        .lowercased()
        .split(whereSeparator: { $0 == "-" || $0 == "_" })
        .first
    return primaryLanguageCode == "ru" ? russian : english
}

/// Persisted global Ghost Mode policy. The individual keys in
/// `MellowsgramGlobalSettings` remain the on-disk compatibility format, while
/// this value type gives the runtime and UI one coherent policy to pass around.
public struct MellowsgramGlobalGhostModeSettings: Codable, Equatable {
    public let enabled: Bool
    public let dontReadMessages: Bool
    public let dontReadStories: Bool
    public let dontSendOnline: Bool
    public let dontSendTyping: Bool
    public let goOfflineAutomatically: Bool

    public init(
        enabled: Bool,
        dontReadMessages: Bool,
        dontReadStories: Bool,
        dontSendOnline: Bool,
        dontSendTyping: Bool,
        goOfflineAutomatically: Bool
    ) {
        self.enabled = enabled
        self.dontReadMessages = dontReadMessages
        self.dontReadStories = dontReadStories
        self.dontSendOnline = dontSendOnline
        self.dontSendTyping = dontSendTyping
        self.goOfflineAutomatically = goOfflineAutomatically
    }

    public static let defaultSettings = MellowsgramGlobalGhostModeSettings(
        enabled: false,
        dontReadMessages: true,
        dontReadStories: true,
        dontSendOnline: true,
        dontSendTyping: true,
        goOfflineAutomatically: true
    )
}

/// App-wide Mellowsgram preferences. Settings that already belong to a native
/// Telegram preference model are intentionally not stored here.
public enum MellowsgramGlobalSettingKey: String, CaseIterable {
    // Appearance: chat, channels, tabs, folders, list and stories.
    case appFont
    case accountColorsSaturation
    case stickerSize
    case showStickerTimestamp
    case wideChannelPosts
    case channelBottomPanel
    case showContactsTab
    case showCallsTab
    case showTabNames
    case searchButton
    case wideTabBar
    case foldersAtBottom
    case hideAllChats
    case smallerFolderSpacing
    case allChatsTitle
    case openLastFolder
    case compactChatList
    case compactMessagePreview
    case chatListSwipeOptions
    case swipeToDeleteChat

    case hideStories
    case disableSwipeToRecordStory
    case askBeforeViewingStories
    case repostToStory

    // Message controls and context actions.
    case secondsInMessages
    case doubleTapToEdit
    case voiceRecordingButton
    case messageDeletionEffects
    case sendAsButton
    case sendWithReturnKey
    case emojiTabFirst
    case standardEmojisFirst
    case pullToNextUnreadChannel
    case pullToNextTopic
    case hideReactions
    case contextReply
    case contextPin
    case contextSaveToCloud
    case contextSaveToFiles
    case contextHideSenderNames
    case contextSelectFromAuthor
    case contextRestrict
    case contextReport
    case contextViewThread
    case contextJSON

    // Media, voice, translation and transfers.
    case outgoingPhotoQuality
    case sendHDPhotos
    case startRoundVideoWithRearCamera
    case videoPipWithSwipe
    case cameraInGallery
    case cameraPreviewInGallery
    case transcriptionService
    case forceDeviceMicrophone
    case translationService
    case quickTranslateButton
    case translateEntireChats
    case uploadBoost
    case downloadBoost

    // Profile and calls.
    case showProfileId
    case showDataCenter
    case showRegistrationDate
    case showChatCreationDate
    case hidePhoneInSettings
    case callConfirmation

    // Privacy, push and global Ghost Mode.
    case protectScreenshots
    case barkNotificationsEnabled
    case barkAllAccounts
    case liveContainerNotificationLinks
    case ghostGlobalMode
    case ghostGlobalDontReadMessages
    case ghostGlobalDontReadStories
    case ghostGlobalDontSendOnline
    case ghostGlobalDontSendTyping
    case ghostGlobalGoOfflineAutomatically

    // Decoding compatibility for old installations. The UI no longer offers it.
    case hideTabBar

    public var defaultValue: String {
        switch self {
        case .accountColorsSaturation, .stickerSize:
            return "100"
        case .outgoingPhotoQuality:
            return "100"
        case .showStickerTimestamp, .channelBottomPanel,
             .showTabNames, .searchButton, .showContactsTab, .showCallsTab,
             .chatListSwipeOptions, .swipeToDeleteChat,
             .showProfileId, .showDataCenter, .showRegistrationDate, .showChatCreationDate,
             .callConfirmation, .hidePhoneInSettings,
             .videoPipWithSwipe, .repostToStory, .disableSwipeToRecordStory,
             .cameraPreviewInGallery,
             .contextSaveToCloud, .contextHideSenderNames,
             .contextSelectFromAuthor, .contextRestrict, .contextReport,
             .contextReply, .contextPin, .contextViewThread,
             .contextJSON, .voiceRecordingButton, .messageDeletionEffects,
             .sendAsButton, .translateEntireChats,
             .ghostGlobalDontReadMessages, .ghostGlobalDontReadStories,
             .ghostGlobalDontSendOnline, .ghostGlobalDontSendTyping,
             .ghostGlobalGoOfflineAutomatically:
            return "true"
        case .translationService, .transcriptionService:
            return "telegram"
        case .appFont:
            return "system"
        case .allChatsTitle:
            return "default"
        case .downloadBoost:
            return "medium"
        case .hideTabBar, .wideTabBar, .wideChannelPosts, .sendHDPhotos,
             .protectScreenshots,
             .hideAllChats, .smallerFolderSpacing, .openLastFolder,
             .compactChatList, .compactMessagePreview,
             .hideStories, .askBeforeViewingStories,
             .quickTranslateButton, .forceDeviceMicrophone,
             .startRoundVideoWithRearCamera, .cameraInGallery,
             .contextSaveToFiles, .pullToNextUnreadChannel, .pullToNextTopic,
             .secondsInMessages, .doubleTapToEdit, .hideReactions, .sendWithReturnKey,
             .emojiTabFirst, .standardEmojisFirst, .foldersAtBottom,
             .ghostGlobalMode:
            return "false"
        case .barkNotificationsEnabled, .barkAllAccounts, .liveContainerNotificationLinks:
            return "false"
        case .uploadBoost:
            return "true"
        }
    }

    public var isTelegramPreference: Bool {
        switch self {
        case .showContactsTab, .showCallsTab, .foldersAtBottom, .translateEntireChats:
            return true
        default:
            return false
        }
    }
}

public struct MellowsgramGlobalSettings: Codable, Equatable {
    private var values: [String: String]

    public static var defaultSettings: MellowsgramGlobalSettings {
        let values = Dictionary(uniqueKeysWithValues: MellowsgramGlobalSettingKey.allCases
            .filter { !$0.isTelegramPreference }
            .map { ($0.rawValue, $0.defaultValue) })
        return MellowsgramGlobalSettings(values: values)
    }

    private init(values: [String: String]) {
        self.values = values
    }

    public func value(for key: MellowsgramGlobalSettingKey) -> String {
        if key == .hideTabBar {
            // Retain the legacy key for decoding old settings, but never hide
            // the only navigation bar after removing its control from the UI.
            return "false"
        }
        return self.values[key.rawValue] ?? key.defaultValue
    }

    public func bool(for key: MellowsgramGlobalSettingKey) -> Bool {
        return self.value(for: key) == "true"
    }

    public var ghostMode: MellowsgramGlobalGhostModeSettings {
        return MellowsgramGlobalGhostModeSettings(
            enabled: self.bool(for: .ghostGlobalMode),
            dontReadMessages: self.bool(for: .ghostGlobalDontReadMessages),
            dontReadStories: self.bool(for: .ghostGlobalDontReadStories),
            dontSendOnline: self.bool(for: .ghostGlobalDontSendOnline),
            dontSendTyping: self.bool(for: .ghostGlobalDontSendTyping),
            goOfflineAutomatically: self.bool(for: .ghostGlobalGoOfflineAutomatically)
        )
    }

    public func withUpdatedGhostMode(_ policy: MellowsgramGlobalGhostModeSettings) -> MellowsgramGlobalSettings {
        var result = self
        result = result.withUpdatedValue(policy.enabled ? "true" : "false", for: .ghostGlobalMode)
        result = result.withUpdatedValue(policy.dontReadMessages ? "true" : "false", for: .ghostGlobalDontReadMessages)
        result = result.withUpdatedValue(policy.dontReadStories ? "true" : "false", for: .ghostGlobalDontReadStories)
        result = result.withUpdatedValue(policy.dontSendOnline ? "true" : "false", for: .ghostGlobalDontSendOnline)
        result = result.withUpdatedValue(policy.dontSendTyping ? "true" : "false", for: .ghostGlobalDontSendTyping)
        return result.withUpdatedValue(policy.goOfflineAutomatically ? "true" : "false", for: .ghostGlobalGoOfflineAutomatically)
    }

    public func integer(for key: MellowsgramGlobalSettingKey) -> Int {
        return Int(self.value(for: key)) ?? Int(key.defaultValue) ?? 0
    }

    public func withUpdatedValue(_ value: String, for key: MellowsgramGlobalSettingKey) -> MellowsgramGlobalSettings {
        guard !key.isTelegramPreference && key != .hideTabBar else {
            return self
        }
        var values = self.values
        values[key.rawValue] = value
        return MellowsgramGlobalSettings(values: values)
    }

    public func lastFolderId(accountKey: String) -> Int32? {
        guard let value = self.values["lastFolder.\(accountKey)"] else {
            return nil
        }
        return Int32(value)
    }

    public func withUpdatedLastFolderId(_ id: Int32, accountKey: String) -> MellowsgramGlobalSettings {
        var values = self.values
        values["lastFolder.\(accountKey)"] = "\(id)"
        return MellowsgramGlobalSettings(values: values)
    }

    private struct CodingKeyValue: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            return nil
        }
    }

    private static let legacyValuesKey = "values"
    private static let lastFolderAccountKeysKey = "lastFolderAccountKeys"
    private static let lastFolderIdsKey = "lastFolderIds"

    private static func storedInteger(for key: String, value: String) -> Int32? {
        if value == "true" { return 1 }
        if value == "false" { return 0 }
        if let integer = Int32(value) { return integer }

        guard let setting = MellowsgramGlobalSettingKey(rawValue: key) else {
            return nil
        }
        switch setting {
        case .appFont:
            return ["system": 0, "monocraft": 1][value]
        case .allChatsTitle:
            return ["default": 0, "short": 1, "long": 2][value]
        case .translationService:
            return ["telegram": 0, "google": 1, "system": 2][value]
        case .transcriptionService:
            return ["telegram": 0, "apple": 1][value]
        case .downloadBoost:
            return ["default": 0, "none": 0, "medium": 1, "maximum": 2][value]
        default:
            return nil
        }
    }

    private static func decodedValue(for key: String, integer: Int32) -> String {
        guard let setting = MellowsgramGlobalSettingKey(rawValue: key) else {
            return "\(integer)"
        }
        if setting.defaultValue == "true" || setting.defaultValue == "false" {
            return integer == 0 ? "false" : "true"
        }
        switch setting {
        case .appFont:
            return integer == 1 ? "monocraft" : "system"
        case .allChatsTitle:
            return ["default", "short", "long"].dropFirst(max(0, Int(integer))).first ?? setting.defaultValue
        case .translationService:
            return ["telegram", "google", "system"].dropFirst(max(0, Int(integer))).first ?? setting.defaultValue
        case .transcriptionService:
            return ["telegram", "apple"].dropFirst(max(0, Int(integer))).first ?? setting.defaultValue
        case .downloadBoost:
            return ["default", "medium", "maximum"].dropFirst(max(0, Int(integer))).first ?? setting.defaultValue
        default:
            return "\(integer)"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeyValue.self)
        var values = MellowsgramGlobalSettings.defaultSettings.values
        if let legacyKey = CodingKeyValue(stringValue: Self.legacyValuesKey),
           let legacyValues = try container.decodeIfPresent(EngineAdaptedPostboxDecoder.RawObjectData.self, forKey: legacyKey) {
            // Dictionary.Decodable asks the keyed container for `allKeys`, which
            // Postbox deliberately does not implement. Read the known legacy
            // setting keys directly from the raw Postbox object instead.
            for key in MellowsgramGlobalSettingKey.allCases where !key.isTelegramPreference {
                let legacyDecoder = EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: legacyValues.data))
                if let value = legacyDecoder.decodeOptionalStringForKey(key.rawValue) {
                    values[key.rawValue] = value
                }
            }
        }
        for key in MellowsgramGlobalSettingKey.allCases where !key.isTelegramPreference {
            guard let codingKey = CodingKeyValue(stringValue: key.rawValue),
                  let integer = try container.decodeIfPresent(Int32.self, forKey: codingKey) else {
                continue
            }
            values[key.rawValue] = Self.decodedValue(for: key.rawValue, integer: integer)
        }
        if let accountKeysCodingKey = CodingKeyValue(stringValue: Self.lastFolderAccountKeysKey),
           let folderIdsCodingKey = CodingKeyValue(stringValue: Self.lastFolderIdsKey),
           let accountKeys = try container.decodeIfPresent([String].self, forKey: accountKeysCodingKey),
           let folderIds = try container.decodeIfPresent([Int32].self, forKey: folderIdsCodingKey) {
            for (accountKey, folderId) in zip(accountKeys, folderIds) {
                values["lastFolder.\(accountKey)"] = "\(folderId)"
            }
        }
        self.values = values
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeyValue.self)
        for key in self.values.keys.sorted() {
            guard !key.hasPrefix("lastFolder.") else {
                continue
            }
            guard let value = self.values[key], let integer = Self.storedInteger(for: key, value: value),
                  let codingKey = CodingKeyValue(stringValue: key) else {
                continue
            }
            try container.encode(integer, forKey: codingKey)
        }

        let lastFolderEntries = self.values
            .compactMap { key, value -> (accountKey: String, folderId: Int32)? in
                guard key.hasPrefix("lastFolder."), let folderId = Int32(value) else {
                    return nil
                }
                return (String(key.dropFirst("lastFolder.".count)), folderId)
            }
            .sorted { $0.accountKey < $1.accountKey }
        if !lastFolderEntries.isEmpty,
           let accountKeysCodingKey = CodingKeyValue(stringValue: Self.lastFolderAccountKeysKey),
           let folderIdsCodingKey = CodingKeyValue(stringValue: Self.lastFolderIdsKey) {
            try container.encode(lastFolderEntries.map { $0.accountKey }, forKey: accountKeysCodingKey)
            try container.encode(lastFolderEntries.map { $0.folderId }, forKey: folderIdsCodingKey)
        }
    }
}

/// A read-only in-memory snapshot for UI code that needs synchronous access
/// while laying out components. AccountManager remains the persistent source.
public final class MellowsgramGlobalSettingsRuntime {
    public static let shared = MellowsgramGlobalSettingsRuntime()

    private let settings = Atomic(value: MellowsgramGlobalSettings.defaultSettings)
    private let nativeValues = Atomic<[String: String]>(value: [:])
    private let settingsPromise = ValuePromise(MellowsgramGlobalSettings.defaultSettings, ignoreRepeated: false)

    public var signal: Signal<MellowsgramGlobalSettings, NoError> {
        return self.settingsPromise.get()
    }

    private init() {
    }

    public func update(_ settings: MellowsgramGlobalSettings, nativeValues: [MellowsgramGlobalSettingKey: String] = [:]) {
        _ = self.settings.swap(settings)
        _ = self.nativeValues.swap(Dictionary(uniqueKeysWithValues: nativeValues.map { ($0.key.rawValue, $0.value) }))
        let appFont = Font.ApplicationStyle(rawValue: settings.value(for: .appFont)) ?? .system
        Font.setApplicationStyle(appFont)
        UserDefaults.standard.set(appFont.rawValue, forKey: "mellowsgram.global.appFont")
        // TelegramCore cannot depend on TelegramUIPreferences without creating
        // a module cycle. These two values are mirrored for its network layer;
        // AccountManager remains the persistence source of truth.
        UserDefaults.standard.set(settings.bool(for: .uploadBoost), forKey: "mellowsgram.global.uploadBoost")
        UserDefaults.standard.set(settings.value(for: .downloadBoost), forKey: "mellowsgram.global.downloadBoost")
        setMellowsgramScreenshotProtectionEnabled(settings.bool(for: .protectScreenshots))
        let ghostMode = settings.ghostMode
        updateMellowsgramGlobalGhostModeRuntime(
            enabled: ghostMode.enabled,
            dontReadMessages: ghostMode.dontReadMessages,
            dontReadStories: ghostMode.dontReadStories,
            dontSendOnline: ghostMode.dontSendOnline,
            dontSendTyping: ghostMode.dontSendTyping,
            goOfflineAutomatically: ghostMode.goOfflineAutomatically
        )
        self.settingsPromise.set(settings)
    }

    public func updateNativeValue(_ value: String, for key: MellowsgramGlobalSettingKey) {
        guard key.isTelegramPreference else {
            return
        }
        _ = self.nativeValues.modify { current in
            var current = current
            current[key.rawValue] = value
            return current
        }
        self.settingsPromise.set(self.settings.with { $0 })
    }

    public func value(for key: MellowsgramGlobalSettingKey) -> String {
        if key.isTelegramPreference, let value = self.nativeValues.with({ $0[key.rawValue] }) {
            return value
        }
        return self.settings.with { $0.value(for: key) }
    }

    public func bool(for key: MellowsgramGlobalSettingKey) -> Bool {
        return self.value(for: key) == "true"
    }

    public func integer(for key: MellowsgramGlobalSettingKey) -> Int {
        return Int(self.value(for: key)) ?? Int(key.defaultValue) ?? 0
    }

    public func lastFolderId(accountKey: String) -> Int32? {
        return self.settings.with { $0.lastFolderId(accountKey: accountKey) }
    }
}

public func mellowsgramGlobalSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<MellowsgramGlobalSettings, NoError> {
    return accountManager.sharedData(keys: [
        ApplicationSpecificSharedDataKeys.mellowsgramGlobalSettings,
        ApplicationSpecificSharedDataKeys.callListSettings,
        ApplicationSpecificSharedDataKeys.experimentalUISettings,
        ApplicationSpecificSharedDataKeys.translationSettings
    ])
    |> map { sharedData in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.mellowsgramGlobalSettings]?.get(MellowsgramGlobalSettings.self) ?? .defaultSettings
        let callList = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) ?? .defaultSettings
        let experimentalUI = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? .defaultSettings
        let translation = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) ?? .defaultSettings
        MellowsgramGlobalSettingsRuntime.shared.update(settings, nativeValues: [
            .showContactsTab: callList.showContactsTab ? "true" : "false",
            .showCallsTab: callList.showTab ? "true" : "false",
            .foldersAtBottom: experimentalUI.foldersTabAtBottom ? "true" : "false",
            .translateEntireChats: translation.translateChats ? "true" : "false"
        ])
        return settings
    }
}

public func updateMellowsgramGlobalSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (MellowsgramGlobalSettings) -> MellowsgramGlobalSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.mellowsgramGlobalSettings, { entry in
            let current = entry?.get(MellowsgramGlobalSettings.self) ?? .defaultSettings
            return SharedPreferencesEntry(f(current))
        })
    }
}
