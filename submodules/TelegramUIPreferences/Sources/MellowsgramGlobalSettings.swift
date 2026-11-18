import Foundation
import TelegramCore
import SwiftSignalKit

/// App-wide Mellowsgram preferences. Settings that already belong to a native
/// Telegram preference model are intentionally not stored here.
public enum MellowsgramGlobalSettingKey: String, CaseIterable {
    case accountColorsSaturation
    case stickerSize
    case showStickerTimestamp
    case wideChannelPosts
    case channelBottomPanel
    case outgoingPhotoQuality
    case sendHDPhotos

    case hideTabBar
    case showTabNames
    case searchButton
    case wideTabBar
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

    case showProfileId
    case showDataCenter
    case showRegistrationDate
    case showChatCreationDate
    case callConfirmation
    case hidePhoneInSettings

    case translationService
    case quickTranslateButton
    case transcriptionService
    case forceDeviceMicrophone

    case startRoundVideoWithRearCamera
    case videoPipWithSwipe
    case cameraInGallery
    case cameraPreviewInGallery
    case uploadBoost
    case downloadBoost

    case contextSaveToCloud
    case contextHideSenderNames
    case contextSelectFromAuthor
    case contextRestrict
    case contextReport
    case contextReply
    case contextPin
    case contextSaveToFiles
    case contextViewThread
    case contextJSON

    case secondsInMessages
    case doubleTapToEdit
    case voiceRecordingButton
    case messageDeletionEffects
    case sendAsButton
    case pullToNextUnreadChannel
    case pullToNextTopic
    case hideReactions
    case sendWithReturnKey
    case emojiTabFirst
    case standardEmojisFirst

    /// These values are owned by Telegram shared preferences and are surfaced
    /// in this enum only so the Mellowsgram settings list has one stable key set.
    case showContactsTab
    case showCallsTab
    case foldersAtBottom
    case translateEntireChats

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
             .sendAsButton, .translateEntireChats:
            return "true"
        case .translationService, .transcriptionService:
            return "telegram"
        case .allChatsTitle:
            return "default"
        case .downloadBoost:
            return "medium"
        case .hideTabBar, .wideTabBar, .wideChannelPosts, .sendHDPhotos,
             .hideAllChats, .smallerFolderSpacing, .openLastFolder,
             .compactChatList, .compactMessagePreview,
             .hideStories, .askBeforeViewingStories,
             .quickTranslateButton, .forceDeviceMicrophone,
             .startRoundVideoWithRearCamera, .cameraInGallery,
             .contextSaveToFiles, .pullToNextUnreadChannel, .pullToNextTopic,
             .secondsInMessages, .doubleTapToEdit, .hideReactions, .sendWithReturnKey,
             .emojiTabFirst, .standardEmojisFirst, .foldersAtBottom:
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
        return self.values[key.rawValue] ?? key.defaultValue
    }

    public func bool(for key: MellowsgramGlobalSettingKey) -> Bool {
        return self.value(for: key) == "true"
    }

    public func integer(for key: MellowsgramGlobalSettingKey) -> Int {
        return Int(self.value(for: key)) ?? Int(key.defaultValue) ?? 0
    }

    public func withUpdatedValue(_ value: String, for key: MellowsgramGlobalSettingKey) -> MellowsgramGlobalSettings {
        guard !key.isTelegramPreference else {
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

    private enum CodingKeys: String, CodingKey {
        case values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedValues = try container.decodeIfPresent([String: String].self, forKey: .values) ?? [:]
        var values = MellowsgramGlobalSettings.defaultSettings.values
        values.merge(decodedValues, uniquingKeysWith: { _, new in new })
        self.values = values
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.values, forKey: .values)
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
        // TelegramCore cannot depend on TelegramUIPreferences without creating
        // a module cycle. These two values are mirrored for its network layer;
        // AccountManager remains the persistence source of truth.
        UserDefaults.standard.set(settings.bool(for: .uploadBoost), forKey: "mellowsgram.global.uploadBoost")
        UserDefaults.standard.set(settings.value(for: .downloadBoost), forKey: "mellowsgram.global.downloadBoost")
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
