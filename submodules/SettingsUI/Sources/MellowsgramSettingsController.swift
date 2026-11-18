import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import LegacyComponents

private enum MellowsgramSettingsCategory: Int32, CaseIterable {
    case spyAndGhost
    case appearance
    case chatsAndTabs
    case stories
    case profilesAndCalls
    case translationAndVoice
    case mediaAndPerformance
    case contextMenu
    case messagesAndInput

    var title: String {
        switch self {
        case .spyAndGhost:
            return "Spy&Ghost"
        case .appearance:
            return "Appearance"
        case .chatsAndTabs:
            return "Chats & Tabs"
        case .stories:
            return "Stories"
        case .profilesAndCalls:
            return "Profiles & Calls"
        case .translationAndVoice:
            return "Translation & Voice"
        case .mediaAndPerformance:
            return "Media & Performance"
        case .contextMenu:
            return "Context Menu"
        case .messagesAndInput:
            return "Messages & Input"
        }
    }
}

private enum MellowsgramAccountSetting: CaseIterable, Equatable {
    case ghostMode
    case ghostDontReadMessages
    case ghostDontReadStories
    case ghostDontSendOnline
    case ghostDontSendTyping
    case ghostGoOfflineAutomatically
    case saveDeletedMessages
    case showDeletedMessages
    case saveEditedMessages
    case translucentDeletedMessages
    case backgroundNotifications
    case backgroundNotificationsAllAccounts

    var category: MellowsgramSettingsCategory {
        switch self {
        case .translucentDeletedMessages:
            return .appearance
        default:
            return .spyAndGhost
        }
    }

    var title: String {
        switch self {
        case .ghostMode: return "Ghost Mode"
        case .ghostDontReadMessages: return "Don't Read Messages"
        case .ghostDontReadStories: return "Don't Read Stories"
        case .ghostDontSendOnline: return "Don't Send Online"
        case .ghostDontSendTyping: return "Don't Send Typing"
        case .ghostGoOfflineAutomatically: return "Go Offline Automatically"
        case .saveDeletedMessages: return "Save Deleted Messages"
        case .showDeletedMessages: return "Show Deleted Messages"
        case .saveEditedMessages: return "Save Edits History"
        case .translucentDeletedMessages: return "Translucent Deleted Messages"
        case .backgroundNotifications: return "Background Notifications"
        case .backgroundNotificationsAllAccounts: return "All Accounts in Background"
        }
    }
}

private extension MellowsgramGlobalSettingKey {
    var mellowsgramCategory: MellowsgramSettingsCategory {
        switch self {
        case .accountColorsSaturation, .stickerSize, .showStickerTimestamp, .wideChannelPosts, .channelBottomPanel, .outgoingPhotoQuality, .sendHDPhotos:
            return .appearance
        case .hideTabBar, .showTabNames, .searchButton, .wideTabBar, .showContactsTab, .showCallsTab, .foldersAtBottom, .hideAllChats, .smallerFolderSpacing, .allChatsTitle, .openLastFolder, .compactChatList, .compactMessagePreview, .chatListSwipeOptions, .swipeToDeleteChat:
            return .chatsAndTabs
        case .hideStories, .disableSwipeToRecordStory, .askBeforeViewingStories, .repostToStory:
            return .stories
        case .showProfileId, .showDataCenter, .showRegistrationDate, .showChatCreationDate, .callConfirmation, .hidePhoneInSettings:
            return .profilesAndCalls
        case .translationService, .quickTranslateButton, .translateEntireChats, .transcriptionService, .forceDeviceMicrophone:
            return .translationAndVoice
        case .startRoundVideoWithRearCamera, .videoPipWithSwipe, .cameraInGallery, .cameraPreviewInGallery, .uploadBoost, .downloadBoost:
            return .mediaAndPerformance
        case .contextSaveToCloud, .contextHideSenderNames, .contextSelectFromAuthor, .contextRestrict, .contextReport, .contextReply, .contextPin, .contextSaveToFiles, .contextViewThread, .contextJSON:
            return .contextMenu
        case .secondsInMessages, .doubleTapToEdit, .voiceRecordingButton, .messageDeletionEffects, .sendAsButton, .pullToNextUnreadChannel, .pullToNextTopic, .hideReactions, .sendWithReturnKey, .emojiTabFirst, .standardEmojisFirst:
            return .messagesAndInput
        }
    }

    var mellowsgramTitle: String {
        switch self {
        case .accountColorsSaturation: return "Account Colors Saturation"
        case .stickerSize: return "Stickers and Emoji Size"
        case .showStickerTimestamp: return "Show Timestamp"
        case .wideChannelPosts: return "Wide posts in channels"
        case .channelBottomPanel: return "Channel Bottom Panel"
        case .outgoingPhotoQuality: return "Outgoing Photo Quality"
        case .sendHDPhotos: return "Send HD Photos"
        case .hideTabBar: return "Hide Tab bar"
        case .showContactsTab: return "Show Contacts Tab"
        case .showCallsTab: return "Show Calls Tab"
        case .showTabNames: return "Show Tab Names"
        case .searchButton: return "Search Button"
        case .wideTabBar: return "Wide Tab bar"
        case .foldersAtBottom: return "Folders at Bottom"
        case .hideAllChats: return "Hide \"All Chats\""
        case .smallerFolderSpacing: return "Smaller spacing"
        case .allChatsTitle: return "\"All Chats\" title"
        case .openLastFolder: return "Open Last Folder"
        case .compactChatList: return "Compact Chat List"
        case .compactMessagePreview: return "Compact Message Preview"
        case .chatListSwipeOptions: return "Chat List Swipe Options"
        case .swipeToDeleteChat: return "Swipe to Delete Chat"
        case .hideStories: return "Hide Stories"
        case .disableSwipeToRecordStory: return "Disable Swipe to Record"
        case .askBeforeViewingStories: return "Ask Before Viewing"
        case .repostToStory: return "Repost to Story"
        case .showProfileId: return "Show Profile ID"
        case .showDataCenter: return "Show Data Center"
        case .showRegistrationDate: return "Show Registration Date"
        case .showChatCreationDate: return "Show Chat Creation Date"
        case .callConfirmation: return "Call Confirmation"
        case .hidePhoneInSettings: return "Hide Phone in Settings"
        case .translationService: return "Translation Service"
        case .quickTranslateButton: return "Quick Translate button"
        case .translateEntireChats: return "Translate Entire Chats"
        case .transcriptionService: return "Voice-to-Text Service"
        case .forceDeviceMicrophone: return "Force Device Microphone"
        case .startRoundVideoWithRearCamera: return "Start with Rear Camera"
        case .videoPipWithSwipe: return "Video PIP with Swipe"
        case .cameraInGallery: return "Camera in Gallery"
        case .cameraPreviewInGallery: return "Camera Preview in Gallery"
        case .uploadBoost: return "Upload Boost"
        case .downloadBoost: return "Download Boost"
        case .contextSaveToCloud: return "Save to Cloud"
        case .contextHideSenderNames: return "Hide Sender Names"
        case .contextSelectFromAuthor: return "Select from Author"
        case .contextRestrict: return "Restrict"
        case .contextReport: return "Report"
        case .contextReply: return "Reply"
        case .contextPin: return "Pin"
        case .contextSaveToFiles: return "Save to Files"
        case .contextViewThread: return "View Thread"
        case .contextJSON: return "JSON"
        case .secondsInMessages: return "Seconds in Messages"
        case .doubleTapToEdit: return "Double-tap to edit message"
        case .voiceRecordingButton: return "Voice Recording Button"
        case .messageDeletionEffects: return "Message Deletion Effects"
        case .sendAsButton: return "\"Send Message As…\" Button"
        case .pullToNextUnreadChannel: return "Pull to Next Unread Channel"
        case .pullToNextTopic: return "Pull to Next Topic"
        case .hideReactions: return "Hide Reactions"
        case .sendWithReturnKey: return "Send with \"return\" key"
        case .emojiTabFirst: return "Emoji tab first"
        case .standardEmojisFirst: return "Standard emojis first"
        }
    }

    var mellowsgramIsChoice: Bool {
        switch self {
        case .allChatsTitle, .translationService, .transcriptionService, .downloadBoost:
            return true
        default:
            return false
        }
    }

    var mellowsgramIsPercentageSlider: Bool {
        switch self {
        case .accountColorsSaturation, .stickerSize, .outgoingPhotoQuality:
            return true
        default:
            return false
        }
    }

    var mellowsgramChoices: [(String, String)] {
        switch self {
        case .allChatsTitle: return [("default", "Default"), ("short", "All"), ("long", "All Chats")]
        case .translationService:
            var values: [(String, String)] = [("telegram", "Telegram"), ("google", "Google Translate")]
            if #available(iOS 18.0, *) { values.append(("system", "iOS System")) }
            return values
        case .transcriptionService: return [("telegram", "Telegram"), ("apple", "Apple")]
        case .downloadBoost: return [("default", "None"), ("medium", "Medium"), ("maximum", "Maximum")]
        default: return []
        }
    }
}

private final class MellowsgramHeaderItem: ListViewItem, ItemListItem {
    let sectionId: ItemListSectionId
    let image: UIImage?

    init(sectionId: ItemListSectionId) {
        self.sectionId = sectionId
        // Telegram's resource bundle flattens this resource to its root name.
        // Keep the nested/name fallbacks for older generated bundles.
        self.image = UIImage(bundleImageName: "MellowsgramIcon")
            ?? UIImage(bundleImageName: "Mellowsgram/MellowsgramIcon")
            ?? UIImage(named: "MellowsgramIcon")
            ?? UIImage(named: "Mellowsgram/MellowsgramIcon")
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MellowsgramHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))

            node.contentSize = layout.contentSize
            node.insets = layout.insets

            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let nodeValue = node() as? MellowsgramHeaderItemNode else {
                assertionFailure()
                return
            }

            let makeLayout = nodeValue.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private final class MellowsgramHeaderItemNode: ListViewItemNode {
    private let imageNode: ASImageNode
    private var item: MellowsgramHeaderItem?

    init() {
        self.imageNode = ASImageNode()
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true

        super.init(layerBacked: false)

        self.addSubnode(self.imageNode)
    }

    func asyncLayout() -> (_ item: MellowsgramHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params, neighbors in
            let imageSize = CGSize(width: 92.0, height: 92.0)
            let contentSize = CGSize(width: params.width, height: 116.0)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            return (layout, { [weak self] in
                guard let self else {
                    return
                }

                self.item = item
                self.imageNode.image = item.image
                self.imageNode.frame = CGRect(
                    x: params.leftInset + floor((layout.size.width - params.leftInset - params.rightInset - imageSize.width) / 2.0),
                    y: 12.0,
                    width: imageSize.width,
                    height: imageSize.height
                )
            })
        }
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
    }
}

private final class MellowsgramRootControllerArguments {
    let context: AccountContext
    let openCategory: (MellowsgramSettingsCategory, MellowsgramGlobalSettingKey?, MellowsgramAccountSetting?) -> Void
    let openExternalUrl: (String) -> Void
    let updateSearchQuery: (String) -> Void

    init(
        context: AccountContext,
        openCategory: @escaping (MellowsgramSettingsCategory, MellowsgramGlobalSettingKey?, MellowsgramAccountSetting?) -> Void,
        openExternalUrl: @escaping (String) -> Void,
        updateSearchQuery: @escaping (String) -> Void
    ) {
        self.context = context
        self.openCategory = openCategory
        self.openExternalUrl = openExternalUrl
        self.updateSearchQuery = updateSearchQuery
    }
}

private enum MellowsgramRootSection: Int32 {
    case categories
    case links
}

private enum MellowsgramRootControllerEntry: ItemListNodeEntry {
    case header
    case search(String)
    case categoriesHeader
    case category(MellowsgramSettingsCategory)
    case searchResultsHeader
    case searchResult(MellowsgramGlobalSettingKey)
    case searchAccountSettingResult(MellowsgramAccountSetting)
    case linksHeader
    case channel
    case github

    var section: ItemListSectionId {
        switch self {
        case .header, .search, .categoriesHeader, .category, .searchResultsHeader, .searchResult, .searchAccountSettingResult:
            return MellowsgramRootSection.categories.rawValue
        case .linksHeader, .channel, .github:
            return MellowsgramRootSection.links.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .search:
            return 1
        case .categoriesHeader:
            return 2
        case let .category(category):
            return 3 + category.rawValue
        case .searchResultsHeader:
            return 20
        case let .searchResult(key):
            return 100 + Int32(MellowsgramGlobalSettingKey.allCases.firstIndex(of: key) ?? 0)
        case let .searchAccountSettingResult(setting):
            return 200 + Int32(MellowsgramAccountSetting.allCases.firstIndex(of: setting) ?? 0)
        case .linksHeader:
            return 1000
        case .channel:
            return 1001
        case .github:
            return 1002
        }
    }

    static func < (lhs: MellowsgramRootControllerEntry, rhs: MellowsgramRootControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MellowsgramRootControllerArguments
        switch self {
        case .header:
            return MellowsgramHeaderItem(sectionId: self.section)
        case let .search(query):
            return ItemListSingleLineInputItem(
                context: arguments.context,
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: ""),
                text: query,
                placeholder: "Search Mellowsgram settings",
                clearType: .always,
                sectionId: self.section,
                textUpdated: arguments.updateSearchQuery,
                action: {}
            )
        case .categoriesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Categories", sectionId: self.section)
        case let .category(category):
            let icon: UIImage?
            switch category {
            case .spyAndGhost:
                icon = PresentationResourcesSettings.security
            case .appearance:
                icon = PresentationResourcesSettings.appearance
            default:
                icon = nil
            }
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: icon,
                title: category.title,
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openCategory(category, nil, nil)
                }
            )
        case .searchResultsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Search Results", sectionId: self.section)
        case let .searchResult(key):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: key.mellowsgramTitle,
                label: key.mellowsgramCategory.title,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openCategory(key.mellowsgramCategory, key, nil)
                }
            )
        case let .searchAccountSettingResult(setting):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: setting.title,
                label: setting.category.title,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openCategory(setting.category, nil, setting)
                }
            )
        case .linksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Links", sectionId: self.section)
        case .channel:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "Channel",
                label: "@mellowsgram",
                labelStyle: .coloredText(presentationData.theme.list.itemAccentColor),
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openExternalUrl("https://t.me/mellowsgram")
                }
            )
        case .github:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: "GitHub",
                label: "telegram.org",
                labelStyle: .coloredText(presentationData.theme.list.itemAccentColor),
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openExternalUrl("https://telegram.org")
                }
            )
        }
    }
}

private func mellowsgramRootControllerEntries(query: String) -> [MellowsgramRootControllerEntry] {
    var entries: [MellowsgramRootControllerEntry] = [.header, .search(query)]
    let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    if normalizedQuery.isEmpty {
        entries.append(.categoriesHeader)
        entries.append(contentsOf: MellowsgramSettingsCategory.allCases.map { .category($0) })
    } else {
        entries.append(.searchResultsHeader)
        entries.append(contentsOf: MellowsgramAccountSetting.allCases.filter { setting in
            setting.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(normalizedQuery)
                || setting.category.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(normalizedQuery)
        }.map { .searchAccountSettingResult($0) })
        entries.append(contentsOf: MellowsgramGlobalSettingKey.allCases.filter { key in
            key.mellowsgramTitle.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(normalizedQuery)
                || key.mellowsgramCategory.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).contains(normalizedQuery)
        }.map { .searchResult($0) })
    }
    entries.append(contentsOf: [.linksHeader, .channel, .github])
    return entries
}

private final class MellowsgramCategoryControllerArguments {
    let updateGhostMode: (Bool) -> Void
    let updateGhostDontReadMessages: (Bool) -> Void
    let updateGhostDontReadStories: (Bool) -> Void
    let updateGhostDontSendOnline: (Bool) -> Void
    let updateGhostDontSendTyping: (Bool) -> Void
    let updateGhostGoOfflineAutomatically: (Bool) -> Void
    let updateSaveDeletedMessages: (Bool) -> Void
    let updateSaveEditedMessages: (Bool) -> Void
    let updateShowDeletedMessages: (Bool) -> Void
    let updateTranslucentDeletedMessages: (Bool) -> Void
    let updateBackgroundNotificationsEnabled: (Bool) -> Void
    let updateBackgroundNotificationsAllAccounts: (Bool) -> Void
    let updateGlobalSetting: (MellowsgramGlobalSettingKey, String) -> Void
    let selectGlobalSetting: (MellowsgramGlobalSettingKey, String) -> Void

    init(
        updateGhostMode: @escaping (Bool) -> Void,
        updateGhostDontReadMessages: @escaping (Bool) -> Void,
        updateGhostDontReadStories: @escaping (Bool) -> Void,
        updateGhostDontSendOnline: @escaping (Bool) -> Void,
        updateGhostDontSendTyping: @escaping (Bool) -> Void,
        updateGhostGoOfflineAutomatically: @escaping (Bool) -> Void,
        updateSaveDeletedMessages: @escaping (Bool) -> Void,
        updateSaveEditedMessages: @escaping (Bool) -> Void,
        updateShowDeletedMessages: @escaping (Bool) -> Void,
        updateTranslucentDeletedMessages: @escaping (Bool) -> Void,
        updateBackgroundNotificationsEnabled: @escaping (Bool) -> Void,
        updateBackgroundNotificationsAllAccounts: @escaping (Bool) -> Void,
        updateGlobalSetting: @escaping (MellowsgramGlobalSettingKey, String) -> Void,
        selectGlobalSetting: @escaping (MellowsgramGlobalSettingKey, String) -> Void
    ) {
        self.updateGhostMode = updateGhostMode
        self.updateGhostDontReadMessages = updateGhostDontReadMessages
        self.updateGhostDontReadStories = updateGhostDontReadStories
        self.updateGhostDontSendOnline = updateGhostDontSendOnline
        self.updateGhostDontSendTyping = updateGhostDontSendTyping
        self.updateGhostGoOfflineAutomatically = updateGhostGoOfflineAutomatically
        self.updateSaveDeletedMessages = updateSaveDeletedMessages
        self.updateSaveEditedMessages = updateSaveEditedMessages
        self.updateShowDeletedMessages = updateShowDeletedMessages
        self.updateTranslucentDeletedMessages = updateTranslucentDeletedMessages
        self.updateBackgroundNotificationsEnabled = updateBackgroundNotificationsEnabled
        self.updateBackgroundNotificationsAllAccounts = updateBackgroundNotificationsAllAccounts
        self.updateGlobalSetting = updateGlobalSetting
        self.selectGlobalSetting = selectGlobalSetting
    }
}

private struct MellowsgramSettingsSnapshot {
    let global: MellowsgramGlobalSettings
    let callList: CallListSettings
    let experimentalUI: ExperimentalUISettings
    let translation: TranslationSettings

    func value(for key: MellowsgramGlobalSettingKey) -> String {
        switch key {
        case .showContactsTab:
            return self.callList.showContactsTab ? "true" : "false"
        case .showCallsTab:
            return self.callList.showTab ? "true" : "false"
        case .foldersAtBottom:
            return self.experimentalUI.foldersTabAtBottom ? "true" : "false"
        case .translateEntireChats:
            return self.translation.translateChats ? "true" : "false"
        default:
            return self.global.value(for: key)
        }
    }
}

private enum MellowsgramCategorySection: Int32 {
    case settings
}

private enum MellowsgramCategoryControllerEntry: ItemListNodeEntry {
    case spyAndGhostHeader
    case ghostMode(Bool, Int32)
    case ghostDontReadMessages(Bool)
    case ghostDontReadStories(Bool)
    case ghostDontSendOnline(Bool)
    case ghostDontSendTyping(Bool)
    case ghostGoOfflineAutomatically(Bool)
    case ghostEssentialsFooter
    case spyEssentialsHeader
    case saveDeletedMessages(Bool)
    case showDeletedMessages(Bool)
    case saveEditedMessages(Bool)
    case spyAndGhostFooter
    case backgroundNotifications(Bool)
    case backgroundNotificationsAllAccounts(Bool, Bool)
    case backgroundNotificationsFooter
    case appearanceHeader
    case translucentDeletedMessages(Bool)
    case appearanceFooter
    case globalSettingsHeader(String)
    case globalSetting(MellowsgramGlobalSettingKey, String, Bool)

    var section: ItemListSectionId {
        return MellowsgramCategorySection.settings.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .spyAndGhostHeader:
            return 0
        case .ghostMode:
            return 1
        case .ghostDontReadMessages:
            return 2
        case .ghostDontReadStories:
            return 3
        case .ghostDontSendOnline:
            return 4
        case .ghostDontSendTyping:
            return 5
        case .ghostGoOfflineAutomatically:
            return 6
        case .ghostEssentialsFooter:
            return 7
        case .spyEssentialsHeader:
            return 8
        case .saveDeletedMessages:
            return 9
        case .showDeletedMessages:
            return 10
        case .saveEditedMessages:
            return 11
        case .spyAndGhostFooter:
            return 12
        case .backgroundNotifications:
            return 13
        case .backgroundNotificationsAllAccounts:
            return 14
        case .backgroundNotificationsFooter:
            return 15
        case .appearanceHeader:
            return 16
        case .translucentDeletedMessages:
            return 17
        case .appearanceFooter:
            return 18
        case .globalSettingsHeader:
            return 30
        case let .globalSetting(key, _, _):
            return 40 + Int32(MellowsgramGlobalSettingKey.allCases.firstIndex(of: key) ?? 0)
        }
    }

    static func < (lhs: MellowsgramCategoryControllerEntry, rhs: MellowsgramCategoryControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MellowsgramCategoryControllerArguments
        switch self {
        case .spyAndGhostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Ghost essentials", sectionId: self.section)
        case let .ghostMode(value, enabledCount):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Ghost Mode \(enabledCount)/5", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateGhostMode)
        case let .ghostDontReadMessages(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "Don't Read Messages", style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontReadMessages(!value)
            })
        case let .ghostDontReadStories(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "Don't Read Stories", style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontReadStories(!value)
            })
        case let .ghostDontSendOnline(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "Don't Send Online", style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontSendOnline(!value)
            })
        case let .ghostDontSendTyping(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "Don't Send Typing", style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontSendTyping(!value)
            })
        case let .ghostGoOfflineAutomatically(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: "Go Offline Automatically", style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostGoOfflineAutomatically(!value)
            })
        case .ghostEssentialsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Toggle each safeguard independently. Ghost Mode applies only to the selected options."), sectionId: self.section)
        case .spyEssentialsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Spy essentials", sectionId: self.section)
        case let .saveDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Save Deleted Messages", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateSaveDeletedMessages)
        case let .showDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Show Deleted Messages", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateShowDeletedMessages)
        case let .saveEditedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Save Edits History", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateSaveEditedMessages)
        case .spyAndGhostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Ghost Mode скрывает сетевые receipts, а архив хранится только локально на этом аккаунте."), sectionId: self.section)
        case let .backgroundNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Background Notifications", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateBackgroundNotificationsEnabled)
        case let .backgroundNotificationsAllAccounts(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "All Accounts in Background", value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: arguments.updateBackgroundNotificationsAllAccounts)
        case .backgroundNotificationsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Держит выбранные Telegram-сессии активными в фоне для локальных уведомлений. Это расходует батарею; после принудительного закрытия приложения iOS остановит соединение."), sectionId: self.section)
        case .appearanceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Appearance", sectionId: self.section)
        case let .translucentDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Translucent Deleted Messages", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateTranslucentDeletedMessages)
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Изменяет только отображение локальных строк удалённых сообщений."), sectionId: self.section)
        case let .globalSettingsHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .globalSetting(key, value, enabled):
            if key.mellowsgramIsPercentageSlider {
                return MellowsgramPercentageSliderItem(
                    theme: presentationData.theme,
                    value: Int32(value) ?? Int32(key.defaultValue) ?? 0,
                    sectionId: self.section,
                    updated: { updatedValue in
                        arguments.updateGlobalSetting(key, "\(updatedValue)")
                    }
                )
            } else if key.mellowsgramIsChoice {
                let title: String
                if let selected = key.mellowsgramChoices.first(where: { $0.0 == value }) {
                    title = selected.1
                } else {
                    title = value
                }
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: key.mellowsgramTitle, enabled: enabled, label: title, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.selectGlobalSetting(key, value)
                })
            }
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: key.mellowsgramTitle, value: value == "true", enabled: enabled, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateGlobalSetting(key, updatedValue ? "true" : "false")
            })
        }
    }
}

private final class MellowsgramPercentageSliderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let value: Int32
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void

    init(theme: PresentationTheme, value: Int32, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.theme = theme
        self.value = min(100, max(0, value))
        self.sectionId = sectionId
        self.updated = updated
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MellowsgramPercentageSliderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? MellowsgramPercentageSliderItemNode else {
                assertionFailure()
                return
            }
            let makeLayout = node.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                Queue.mainQueue().async {
                    completion(layout, { _ in apply() })
                }
            }
        }
    }
}

private final class MellowsgramPercentageSliderItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let maskNode: ASImageNode
    private let minimumTextNode: ImmediateTextNode
    private let valueTextNode: ImmediateTextNode
    private let maximumTextNode: ImmediateTextNode
    private var sliderView: TGPhotoEditorSliderView?
    private var item: MellowsgramPercentageSliderItem?

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        self.maskNode = ASImageNode()
        self.minimumTextNode = ImmediateTextNode()
        self.valueTextNode = ImmediateTextNode()
        self.maximumTextNode = ImmediateTextNode()
        super.init(layerBacked: false)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topStripeNode)
        self.addSubnode(self.bottomStripeNode)
        self.addSubnode(self.maskNode)
        self.addSubnode(self.minimumTextNode)
        self.addSubnode(self.valueTextNode)
        self.addSubnode(self.maximumTextNode)
    }

    override func didLoad() {
        super.didLoad()
        let sliderView = TGPhotoEditorSliderView()
        sliderView.enableEdgeTap = true
        sliderView.enablePanHandling = true
        sliderView.trackCornerRadius = 1.0
        sliderView.lineSize = 4.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = 1.0
        sliderView.startValue = 0.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.displayEdges = true
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        sliderView.addTarget(self, action: #selector(self.sliderEditingEnded), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        self.view.addSubview(sliderView)
        self.sliderView = sliderView
    }

    func asyncLayout() -> (_ item: MellowsgramPercentageSliderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        return { [weak self] item, params, neighbors in
            let themeUpdated = currentItem?.theme !== item.theme
            let contentSize = CGSize(width: params.width, height: 88.0)
            let insets = itemListNeighborsGroupedInsets(neighbors, params)
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            return (layout, { [weak self] in
                guard let self else {
                    return
                }
                self.item = item
                let separatorHeight = UIScreenPixel
                let hasCorners = itemListHasRoundedBlockLayout(params)
                let hasTopCorners: Bool
                switch neighbors.top {
                case .sameSection(false):
                    hasTopCorners = false
                    self.topStripeNode.isHidden = true
                default:
                    hasTopCorners = true
                    self.topStripeNode.isHidden = hasCorners
                }
                let hasBottomCorners: Bool
                switch neighbors.bottom {
                case .sameSection(false):
                    hasBottomCorners = false
                    self.bottomStripeNode.isHidden = false
                default:
                    hasBottomCorners = true
                    self.bottomStripeNode.isHidden = hasCorners
                }
                self.backgroundNode.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                self.topStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                self.bottomStripeNode.backgroundColor = item.theme.list.itemBlocksSeparatorColor
                self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: true) : nil
                self.backgroundNode.frame = CGRect(x: 0.0, y: -min(insets.top, separatorHeight), width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight))
                self.maskNode.frame = self.backgroundNode.frame.inset(by: UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset))
                self.topStripeNode.frame = CGRect(x: 0.0, y: -min(insets.top, separatorHeight), width: params.width, height: separatorHeight)
                let separatorInset: CGFloat
                switch neighbors.bottom {
                case .sameSection(false):
                    separatorInset = params.leftInset + 16.0
                default:
                    separatorInset = 0.0
                }
                self.bottomStripeNode.frame = CGRect(x: separatorInset, y: contentSize.height - separatorHeight, width: params.width - separatorInset, height: separatorHeight)

                let secondaryColor = item.theme.list.itemSecondaryTextColor
                self.minimumTextNode.attributedText = NSAttributedString(string: "0%", font: Font.regular(13.0), textColor: secondaryColor)
                self.valueTextNode.attributedText = NSAttributedString(string: "\(item.value)%", font: Font.regular(15.0), textColor: item.theme.list.itemPrimaryTextColor)
                self.maximumTextNode.attributedText = NSAttributedString(string: "100%", font: Font.regular(13.0), textColor: secondaryColor)
                let minimumSize = self.minimumTextNode.updateLayout(CGSize(width: 100.0, height: 30.0))
                let valueSize = self.valueTextNode.updateLayout(CGSize(width: 120.0, height: 30.0))
                let maximumSize = self.maximumTextNode.updateLayout(CGSize(width: 100.0, height: 30.0))
                self.minimumTextNode.frame = CGRect(x: params.leftInset + 18.0, y: 14.0, width: minimumSize.width, height: minimumSize.height)
                self.valueTextNode.frame = CGRect(x: floor((params.width - valueSize.width) / 2.0), y: 12.0, width: valueSize.width, height: valueSize.height)
                self.maximumTextNode.frame = CGRect(x: params.width - params.rightInset - 18.0 - maximumSize.width, y: 14.0, width: maximumSize.width, height: maximumSize.height)

                if let sliderView = self.sliderView {
                    if themeUpdated || sliderView.backgroundColor == nil {
                        sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
                        sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
                        sliderView.trackColor = item.theme.list.itemAccentColor
                        sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
                    }
                    sliderView.value = CGFloat(item.value) / 100.0
                    sliderView.accessibilityLabel = "\(item.value)%"
                    sliderView.accessibilityValue = "\(item.value)%"
                    sliderView.frame = CGRect(x: params.leftInset + 18.0, y: 36.0, width: params.width - params.leftInset - params.rightInset - 36.0, height: 44.0)
                }
            })
        }
    }

    @objc private func sliderValueChanged() {
        guard let sliderView = self.sliderView, let item = self.item else {
            return
        }
        let value = Int32((sliderView.value * 100.0).rounded())
        self.valueTextNode.attributedText = NSAttributedString(string: "\(value)%", font: Font.regular(15.0), textColor: item.theme.list.itemPrimaryTextColor)
        let valueSize = self.valueTextNode.updateLayout(CGSize(width: 120.0, height: 30.0))
        self.valueTextNode.frame = CGRect(x: floor((self.bounds.width - valueSize.width) / 2.0), y: 12.0, width: valueSize.width, height: valueSize.height)
        sliderView.accessibilityLabel = "\(value)%"
        sliderView.accessibilityValue = "\(value)%"
    }

    @objc private func sliderEditingEnded() {
        guard let sliderView = self.sliderView else {
            return
        }
        self.item?.updated(Int32((sliderView.value * 100.0).rounded()))
    }
}

private func mellowsgramCategoryControllerEntries(category: MellowsgramSettingsCategory, settings: MellowsgramSettings, snapshot: MellowsgramSettingsSnapshot, onlySetting: MellowsgramGlobalSettingKey?, onlyAccountSetting: MellowsgramAccountSetting?) -> [MellowsgramCategoryControllerEntry] {
    var entries: [MellowsgramCategoryControllerEntry]
    switch category {
    case .spyAndGhost:
        let enabledCount = [
            settings.ghostDontReadMessages,
            settings.ghostDontReadStories,
            settings.ghostDontSendOnline,
            settings.ghostDontSendTyping,
            settings.ghostGoOfflineAutomatically
        ].filter { $0 }.count
        entries = [
            .spyAndGhostHeader,
            .ghostMode(settings.ghostMode, Int32(enabledCount)),
            .ghostDontReadMessages(settings.ghostDontReadMessages),
            .ghostDontReadStories(settings.ghostDontReadStories),
            .ghostDontSendOnline(settings.ghostDontSendOnline),
            .ghostDontSendTyping(settings.ghostDontSendTyping),
            .ghostGoOfflineAutomatically(settings.ghostGoOfflineAutomatically),
            .ghostEssentialsFooter,
            .spyEssentialsHeader,
            .saveDeletedMessages(settings.saveDeletedMessages),
            .showDeletedMessages(settings.showDeletedMessages),
            .saveEditedMessages(settings.saveEditedMessages),
            .spyAndGhostFooter,
            .backgroundNotifications(settings.backgroundNotificationsEnabled),
            .backgroundNotificationsAllAccounts(settings.backgroundNotificationsAllAccounts, settings.backgroundNotificationsEnabled),
            .backgroundNotificationsFooter
        ]
    case .appearance:
        entries = [
            .appearanceHeader,
            .translucentDeletedMessages(settings.translucentDeletedMessages),
            .appearanceFooter
        ]
    default:
        entries = []
    }

    let globalKeys = MellowsgramGlobalSettingKey.allCases.filter { key in
        key.mellowsgramCategory == category && (onlySetting == nil || onlySetting == key)
    }
    if !globalKeys.isEmpty {
        if category == .appearance && onlySetting == nil {
            entries.removeLast()
        }
        if category != .appearance || onlySetting != nil {
            entries.append(.globalSettingsHeader(category.title))
        }
        entries.append(contentsOf: globalKeys.map { key in
            let enabled: Bool
            switch key {
            case .showContactsTab, .showCallsTab, .showTabNames, .searchButton, .wideTabBar:
                enabled = !snapshot.global.bool(for: .hideTabBar)
            case .swipeToDeleteChat:
                enabled = snapshot.global.bool(for: .chatListSwipeOptions)
            case .cameraPreviewInGallery:
                enabled = snapshot.global.bool(for: .cameraInGallery)
            case .allChatsTitle:
                enabled = !snapshot.global.bool(for: .hideAllChats)
            default:
                enabled = true
            }
            return .globalSetting(key, snapshot.value(for: key), enabled)
        })
    }

    if let onlySetting = onlySetting {
        entries = entries.filter { entry in
            switch entry {
            case .globalSetting(let key, _, _):
                return key == onlySetting
            case .globalSettingsHeader:
                return true
            default:
                return false
            }
        }
    }
    if let onlyAccountSetting = onlyAccountSetting {
        entries = entries.filter { entry in
            switch onlyAccountSetting {
            case .ghostMode:
                if case .ghostMode = entry { return true }
            case .ghostDontReadMessages:
                if case .ghostDontReadMessages = entry { return true }
            case .ghostDontReadStories:
                if case .ghostDontReadStories = entry { return true }
            case .ghostDontSendOnline:
                if case .ghostDontSendOnline = entry { return true }
            case .ghostDontSendTyping:
                if case .ghostDontSendTyping = entry { return true }
            case .ghostGoOfflineAutomatically:
                if case .ghostGoOfflineAutomatically = entry { return true }
            case .saveDeletedMessages:
                if case .saveDeletedMessages = entry { return true }
            case .showDeletedMessages:
                if case .showDeletedMessages = entry { return true }
            case .saveEditedMessages:
                if case .saveEditedMessages = entry { return true }
            case .translucentDeletedMessages:
                if case .translucentDeletedMessages = entry { return true }
            case .backgroundNotifications:
                if case .backgroundNotifications = entry { return true }
            case .backgroundNotificationsAllAccounts:
                if case .backgroundNotificationsAllAccounts = entry { return true }
            }
            return false
        }
    }
    return entries
}

private func mellowsgramGlobalSettingsSnapshot(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<MellowsgramSettingsSnapshot, NoError> {
    return accountManager.sharedData(keys: [
        ApplicationSpecificSharedDataKeys.mellowsgramGlobalSettings,
        ApplicationSpecificSharedDataKeys.callListSettings,
        ApplicationSpecificSharedDataKeys.experimentalUISettings,
        ApplicationSpecificSharedDataKeys.translationSettings
    ])
    |> map { sharedData in
        return MellowsgramSettingsSnapshot(
            global: sharedData.entries[ApplicationSpecificSharedDataKeys.mellowsgramGlobalSettings]?.get(MellowsgramGlobalSettings.self) ?? .defaultSettings,
            callList: sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) ?? .defaultSettings,
            experimentalUI: sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) ?? .defaultSettings,
            translation: sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) ?? .defaultSettings
        )
    }
}

private func mellowsgramCategoryController(context: AccountContext, category: MellowsgramSettingsCategory, onlySetting: MellowsgramGlobalSettingKey?, onlyAccountSetting: MellowsgramAccountSetting?) -> ViewController {
    let updateGlobalSetting: (MellowsgramGlobalSettingKey, String) -> Void = { key, rawValue in
        switch key {
        case .showContactsTab:
            let _ = updateCallListSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                settings.withUpdatedShowContactsTab(rawValue == "true")
            }.start()
        case .showCallsTab:
            let _ = updateCallListSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                settings.withUpdatedShowTab(rawValue == "true")
            }.start()
        case .foldersAtBottom:
            let _ = updateExperimentalUISettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                var settings = settings
                settings.foldersTabAtBottom = rawValue == "true"
                return settings
            }.start()
        case .translateEntireChats:
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                settings.withUpdatedTranslateChats(rawValue == "true")
            }.start()
        default:
            let _ = updateMellowsgramGlobalSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                settings.withUpdatedValue(rawValue, for: key)
            }.start()
        }
    }

    let arguments = MellowsgramCategoryControllerArguments(
        updateGhostMode: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                // The master switch changes the active policy only. Keep the
                // five safeguards account-scoped so an individual option is
                // not silently overwritten every time the master is toggled.
                return settings.withUpdatedGhostMode(value)
            }.start()
        },
        updateGhostDontReadMessages: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedGhostDontReadMessages(value)
            }.start()
        },
        updateGhostDontReadStories: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedGhostDontReadStories(value)
            }.start()
        },
        updateGhostDontSendOnline: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedGhostDontSendOnline(value)
            }.start()
        },
        updateGhostDontSendTyping: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedGhostDontSendTyping(value)
            }.start()
        },
        updateGhostGoOfflineAutomatically: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedGhostGoOfflineAutomatically(value)
            }.start()
        },
        updateSaveDeletedMessages: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedSaveDeletedMessages(value)
            }.start()
        },
        updateSaveEditedMessages: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedSaveEditedMessages(value)
            }.start()
        },
        updateShowDeletedMessages: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedShowDeletedMessages(value)
            }.start()
        },
        updateTranslucentDeletedMessages: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedTranslucentDeletedMessages(value)
            }.start()
        },
        updateBackgroundNotificationsEnabled: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedBackgroundNotificationsEnabled(value)
            }.start()
        },
        updateBackgroundNotificationsAllAccounts: { value in
            let _ = updateMellowsgramSettingsInteractively(engine: context.engine) { settings in
                return settings.withUpdatedBackgroundNotificationsAllAccounts(value)
            }.start()
        },
        updateGlobalSetting: updateGlobalSetting,
        selectGlobalSetting: { key, selectedValue in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            let options = key.mellowsgramChoices.map { rawValue, title in
                let title = rawValue == selectedValue ? "✓  \(title)" : title
                return ActionSheetButtonItem(title: title, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    updateGlobalSetting(key, rawValue)
                })
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: options),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })])
            ])
            context.sharedContext.presentGlobalController(actionSheet, nil)
        }
    )

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, mellowsgramSettings(engine: context.engine), mellowsgramGlobalSettingsSnapshot(accountManager: context.sharedContext.accountManager))
    |> deliverOnMainQueue
    |> map { presentationData, settings, snapshot -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(category.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: mellowsgramCategoryControllerEntries(category: category, settings: settings, snapshot: snapshot, onlySetting: onlySetting, onlyAccountSetting: onlyAccountSetting),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    return ItemListController(context: context, state: signal)
}

private func openMellowsgramExternalUrl(context: AccountContext, url: String, navigationController: NavigationController?) {
    context.sharedContext.openExternalUrl(
        context: context,
        urlContext: .generic,
        url: url,
        forceExternal: false,
        presentationData: context.sharedContext.currentPresentationData.with { $0 },
        navigationController: navigationController,
        dismissInput: {}
    )
}

public func mellowsgramSettingsController(context: AccountContext) -> ViewController {
    var openCategoryImpl: ((MellowsgramSettingsCategory, MellowsgramGlobalSettingKey?, MellowsgramAccountSetting?) -> Void)?
    var openExternalUrlImpl: ((String) -> Void)?
    let searchQuery = ValuePromise("", ignoreRepeated: true)
    let searchQueryValue = Atomic(value: "")

    let arguments = MellowsgramRootControllerArguments(
        context: context,
        openCategory: { category, setting, accountSetting in
            openCategoryImpl?(category, setting, accountSetting)
        },
        openExternalUrl: { url in
            openExternalUrlImpl?(url)
        },
        updateSearchQuery: { query in
            searchQueryValue.swap(query)
            searchQuery.set(query)
        }
    )

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, searchQuery.get())
    |> deliverOnMainQueue
    |> map { presentationData, query -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Mellowsgram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: mellowsgramRootControllerEntries(query: query),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    openCategoryImpl = { [weak controller] category, setting, accountSetting in
        guard let navigationController = controller?.navigationController as? NavigationController else {
            return
        }
        navigationController.pushViewController(mellowsgramCategoryController(context: context, category: category, onlySetting: setting, onlyAccountSetting: accountSetting))
    }
    openExternalUrlImpl = { [weak controller] url in
        openMellowsgramExternalUrl(context: context, url: url, navigationController: controller?.navigationController as? NavigationController)
    }
    return controller
}
