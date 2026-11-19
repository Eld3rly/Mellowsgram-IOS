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

private func mellowsgramText(_ english: String, _ russian: String, languageCode: String) -> String {
    return mellowsgramLocalizedString(english: english, russian: russian, languageCode: languageCode)
}

private enum MellowsgramSettingsCategory: Int32, CaseIterable {
    case spyAndGhost
    case appearance
    case profilesAndCalls
    case mediaAndVoice
    case messagesAndContext

    func title(languageCode: String) -> String {
        switch self {
        case .spyAndGhost:
            return mellowsgramText("Spy&Ghost", "Шпионаж и невидимость", languageCode: languageCode)
        case .appearance:
            return mellowsgramText("Appearance", "Внешний вид", languageCode: languageCode)
        case .profilesAndCalls:
            return mellowsgramText("Profiles & Calls", "Профили и звонки", languageCode: languageCode)
        case .mediaAndVoice:
            return mellowsgramText("Media & Voice", "Медиа и голос", languageCode: languageCode)
        case .messagesAndContext:
            return mellowsgramText("Messages & Context", "Сообщения и меню", languageCode: languageCode)
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

    func title(languageCode: String) -> String {
        switch self {
        case .ghostMode: return mellowsgramText("Ghost Mode", "Режим невидимки", languageCode: languageCode)
        case .ghostDontReadMessages: return mellowsgramText("Don't Read Messages", "Не отмечать сообщения прочитанными", languageCode: languageCode)
        case .ghostDontReadStories: return mellowsgramText("Don't Read Stories", "Не отмечать истории просмотренными", languageCode: languageCode)
        case .ghostDontSendOnline: return mellowsgramText("Don't Send Online", "Не отправлять статус «в сети»", languageCode: languageCode)
        case .ghostDontSendTyping: return mellowsgramText("Don't Send Typing", "Не отправлять статус «печатает»", languageCode: languageCode)
        case .ghostGoOfflineAutomatically: return mellowsgramText("Go Offline Automatically", "Автоматически уходить в офлайн", languageCode: languageCode)
        case .saveDeletedMessages: return mellowsgramText("Save Deleted Messages", "Сохранять удалённые сообщения", languageCode: languageCode)
        case .showDeletedMessages: return mellowsgramText("Show Deleted Messages", "Показывать удалённые сообщения", languageCode: languageCode)
        case .saveEditedMessages: return mellowsgramText("Save Edits History", "Сохранять историю изменений", languageCode: languageCode)
        case .translucentDeletedMessages: return mellowsgramText("Translucent Deleted Messages", "Полупрозрачные удалённые сообщения", languageCode: languageCode)
        case .backgroundNotifications: return mellowsgramText("Background Notifications", "Уведомления в фоне", languageCode: languageCode)
        case .backgroundNotificationsAllAccounts: return mellowsgramText("All Accounts in Background", "Все аккаунты в фоне", languageCode: languageCode)
        }
    }
}

private extension MellowsgramGlobalSettingKey {
    var mellowsgramCategory: MellowsgramSettingsCategory {
        switch self {
        case .accountColorsSaturation, .stickerSize, .showStickerTimestamp, .wideChannelPosts, .channelBottomPanel,
             .hideTabBar, .showTabNames, .searchButton, .wideTabBar, .showContactsTab, .showCallsTab,
             .foldersAtBottom, .hideAllChats, .smallerFolderSpacing, .allChatsTitle, .openLastFolder,
             .compactChatList, .compactMessagePreview, .chatListSwipeOptions, .swipeToDeleteChat,
             .hideStories, .disableSwipeToRecordStory, .askBeforeViewingStories, .repostToStory:
            return .appearance
        case .showProfileId, .showDataCenter, .showRegistrationDate, .showChatCreationDate, .callConfirmation, .hidePhoneInSettings:
            return .profilesAndCalls
        case .outgoingPhotoQuality, .sendHDPhotos, .translationService, .quickTranslateButton, .translateEntireChats,
             .transcriptionService, .forceDeviceMicrophone, .startRoundVideoWithRearCamera, .videoPipWithSwipe,
             .cameraInGallery, .cameraPreviewInGallery, .uploadBoost, .downloadBoost:
            return .mediaAndVoice
        case .contextSaveToCloud, .contextHideSenderNames, .contextSelectFromAuthor, .contextRestrict, .contextReport,
             .contextReply, .contextPin, .contextSaveToFiles, .contextViewThread, .contextJSON,
             .secondsInMessages, .doubleTapToEdit, .voiceRecordingButton, .messageDeletionEffects, .sendAsButton,
             .pullToNextUnreadChannel, .pullToNextTopic, .hideReactions, .sendWithReturnKey, .emojiTabFirst, .standardEmojisFirst:
            return .messagesAndContext
        }
    }

    func mellowsgramTitle(languageCode: String) -> String {
        switch self {
        case .accountColorsSaturation: return mellowsgramText("Account Colors Saturation", "Насыщенность цветов аккаунтов", languageCode: languageCode)
        case .stickerSize: return mellowsgramText("Stickers and Emoji Size", "Размер стикеров и эмодзи", languageCode: languageCode)
        case .showStickerTimestamp: return mellowsgramText("Show Timestamp", "Показывать время", languageCode: languageCode)
        case .wideChannelPosts: return mellowsgramText("Wide posts in channels", "Широкие публикации в каналах", languageCode: languageCode)
        case .channelBottomPanel: return mellowsgramText("Channel Bottom Panel", "Нижняя панель канала", languageCode: languageCode)
        case .outgoingPhotoQuality: return mellowsgramText("Outgoing Photo Quality", "Качество отправляемых фото", languageCode: languageCode)
        case .sendHDPhotos: return mellowsgramText("Send HD Photos", "Отправлять фото в HD", languageCode: languageCode)
        case .hideTabBar: return mellowsgramText("Hide Tab Bar", "Скрыть панель вкладок", languageCode: languageCode)
        case .showContactsTab: return mellowsgramText("Show Contacts Tab", "Показывать вкладку контактов", languageCode: languageCode)
        case .showCallsTab: return mellowsgramText("Show Calls Tab", "Показывать вкладку звонков", languageCode: languageCode)
        case .showTabNames: return mellowsgramText("Show Tab Names", "Показывать названия вкладок", languageCode: languageCode)
        case .searchButton: return mellowsgramText("Search Button", "Кнопка поиска", languageCode: languageCode)
        case .wideTabBar: return mellowsgramText("Wide Tab Bar", "Растянуть панель вкладок", languageCode: languageCode)
        case .foldersAtBottom: return mellowsgramText("Folders at Bottom", "Папки внизу", languageCode: languageCode)
        case .hideAllChats: return mellowsgramText("Hide \"All Chats\"", "Скрыть «Все чаты»", languageCode: languageCode)
        case .smallerFolderSpacing: return mellowsgramText("Smaller Spacing", "Уменьшить расстояние между папками", languageCode: languageCode)
        case .allChatsTitle: return mellowsgramText("\"All Chats\" Title", "Название «Все чаты»", languageCode: languageCode)
        case .openLastFolder: return mellowsgramText("Open Last Folder", "Открывать последнюю папку", languageCode: languageCode)
        case .compactChatList: return mellowsgramText("Compact Chat List", "Компактный список чатов", languageCode: languageCode)
        case .compactMessagePreview: return mellowsgramText("Compact Message Preview", "Компактный предпросмотр сообщений", languageCode: languageCode)
        case .chatListSwipeOptions: return mellowsgramText("Chat List Swipe Options", "Действия при свайпе по чату", languageCode: languageCode)
        case .swipeToDeleteChat: return mellowsgramText("Swipe to Delete Chat", "Удалять чат свайпом", languageCode: languageCode)
        case .hideStories: return mellowsgramText("Hide Stories", "Скрыть истории", languageCode: languageCode)
        case .disableSwipeToRecordStory: return mellowsgramText("Disable Swipe to Record", "Отключить свайп для записи", languageCode: languageCode)
        case .askBeforeViewingStories: return mellowsgramText("Ask Before Viewing", "Спрашивать перед просмотром", languageCode: languageCode)
        case .repostToStory: return mellowsgramText("Repost to Story", "Публиковать в истории", languageCode: languageCode)
        case .showProfileId: return mellowsgramText("Show Profile ID", "Показывать ID профиля", languageCode: languageCode)
        case .showDataCenter: return mellowsgramText("Show Data Center", "Показывать дата-центр", languageCode: languageCode)
        case .showRegistrationDate: return mellowsgramText("Show Registration Date", "Показывать дату регистрации", languageCode: languageCode)
        case .showChatCreationDate: return mellowsgramText("Show Chat Creation Date", "Показывать дату создания чата", languageCode: languageCode)
        case .callConfirmation: return mellowsgramText("Call Confirmation", "Подтверждать звонки", languageCode: languageCode)
        case .hidePhoneInSettings: return mellowsgramText("Hide Phone in Settings", "Скрывать номер в настройках", languageCode: languageCode)
        case .translationService: return mellowsgramText("Translation Service", "Сервис перевода", languageCode: languageCode)
        case .quickTranslateButton: return mellowsgramText("Quick Translate Button", "Кнопка быстрого перевода", languageCode: languageCode)
        case .translateEntireChats: return mellowsgramText("Translate Entire Chats", "Переводить весь чат", languageCode: languageCode)
        case .transcriptionService: return mellowsgramText("Voice-to-Text Service", "Сервис расшифровки голосовых", languageCode: languageCode)
        case .forceDeviceMicrophone: return mellowsgramText("Force Device Microphone", "Использовать микрофон устройства", languageCode: languageCode)
        case .startRoundVideoWithRearCamera: return mellowsgramText("Start with Rear Camera", "Начинать с задней камеры", languageCode: languageCode)
        case .videoPipWithSwipe: return mellowsgramText("Video PiP with Swipe", "Открывать видео в PiP свайпом", languageCode: languageCode)
        case .cameraInGallery: return mellowsgramText("Camera in Gallery", "Камера в галерее", languageCode: languageCode)
        case .cameraPreviewInGallery: return mellowsgramText("Camera Preview in Gallery", "Предпросмотр камеры в галерее", languageCode: languageCode)
        case .uploadBoost: return mellowsgramText("Upload Boost", "Ускорение отправки", languageCode: languageCode)
        case .downloadBoost: return mellowsgramText("Download Boost", "Ускорение загрузки", languageCode: languageCode)
        case .contextSaveToCloud: return mellowsgramText("Save to Saved Messages", "Сохранить в Избранное", languageCode: languageCode)
        case .contextHideSenderNames: return mellowsgramText("Hide Sender Names", "Скрыть имена отправителей", languageCode: languageCode)
        case .contextSelectFromAuthor: return mellowsgramText("Select from Author", "Выбрать сообщения автора", languageCode: languageCode)
        case .contextRestrict: return mellowsgramText("Restrict", "Ограничить пользователя", languageCode: languageCode)
        case .contextReport: return mellowsgramText("Report", "Пожаловаться", languageCode: languageCode)
        case .contextReply: return mellowsgramText("Reply", "Ответить", languageCode: languageCode)
        case .contextPin: return mellowsgramText("Pin", "Закрепить", languageCode: languageCode)
        case .contextSaveToFiles: return mellowsgramText("Save to Files", "Сохранить в Файлы", languageCode: languageCode)
        case .contextViewThread: return mellowsgramText("View Thread", "Открыть ветку", languageCode: languageCode)
        case .contextJSON: return mellowsgramText("JSON", "JSON", languageCode: languageCode)
        case .secondsInMessages: return mellowsgramText("Seconds in Messages", "Секунды во времени сообщений", languageCode: languageCode)
        case .doubleTapToEdit: return mellowsgramText("Double-tap to Edit Message", "Изменять сообщение двойным касанием", languageCode: languageCode)
        case .voiceRecordingButton: return mellowsgramText("Voice Recording Button", "Кнопка записи голосового", languageCode: languageCode)
        case .messageDeletionEffects: return mellowsgramText("Message Deletion Effects", "Анимация удаления сообщений", languageCode: languageCode)
        case .sendAsButton: return mellowsgramText("\"Send Message As…\" Button", "Кнопка «Отправить как…»", languageCode: languageCode)
        case .pullToNextUnreadChannel: return mellowsgramText("Pull to Next Unread Channel", "Свайп к следующему непрочитанному каналу", languageCode: languageCode)
        case .pullToNextTopic: return mellowsgramText("Pull to Next Topic", "Свайп к следующей теме", languageCode: languageCode)
        case .hideReactions: return mellowsgramText("Hide Reactions", "Скрыть реакции", languageCode: languageCode)
        case .sendWithReturnKey: return mellowsgramText("Send with Return Key", "Отправлять клавишей Return", languageCode: languageCode)
        case .emojiTabFirst: return mellowsgramText("Emoji Tab First", "Сначала вкладка эмодзи", languageCode: languageCode)
        case .standardEmojisFirst: return mellowsgramText("Standard Emojis First", "Сначала обычные эмодзи", languageCode: languageCode)
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

    func mellowsgramSliderLimits(languageCode: String) -> (minimum: String, maximum: String) {
        switch self {
        case .accountColorsSaturation:
            return (mellowsgramText("No color", "Без цвета", languageCode: languageCode), mellowsgramText("Full color", "Полная насыщенность", languageCode: languageCode))
        case .stickerSize:
            return (mellowsgramText("Small", "Маленький", languageCode: languageCode), mellowsgramText("Large", "Большой", languageCode: languageCode))
        case .outgoingPhotoQuality:
            return (mellowsgramText("More compression", "Сильнее сжатие", languageCode: languageCode), mellowsgramText("Higher quality", "Выше качество", languageCode: languageCode))
        default:
            return ("0%", "100%")
        }
    }

    func mellowsgramChoices(languageCode: String) -> [(String, String)] {
        switch self {
        case .allChatsTitle: return [("default", mellowsgramText("Default", "По умолчанию", languageCode: languageCode)), ("short", mellowsgramText("All", "Все", languageCode: languageCode)), ("long", mellowsgramText("All Chats", "Все чаты", languageCode: languageCode))]
        case .translationService:
            var values: [(String, String)] = [("telegram", "Telegram"), ("google", mellowsgramText("Google Translate", "Google Переводчик", languageCode: languageCode))]
            if #available(iOS 18.0, *) { values.append(("system", mellowsgramText("iOS System", "Система iOS", languageCode: languageCode))) }
            return values
        case .transcriptionService: return [("telegram", "Telegram"), ("apple", "Apple")]
        case .downloadBoost: return [("default", mellowsgramText("None", "Нет", languageCode: languageCode)), ("medium", mellowsgramText("Medium", "Среднее", languageCode: languageCode)), ("maximum", mellowsgramText("Maximum", "Максимальное", languageCode: languageCode))]
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
    let openCategory: (MellowsgramSettingsCategory, MellowsgramGlobalSettingKey?, MellowsgramAccountSetting?) -> Void
    let openExternalUrl: (String) -> Void

    init(
        openCategory: @escaping (MellowsgramSettingsCategory, MellowsgramGlobalSettingKey?, MellowsgramAccountSetting?) -> Void,
        openExternalUrl: @escaping (String) -> Void
    ) {
        self.openCategory = openCategory
        self.openExternalUrl = openExternalUrl
    }
}

private enum MellowsgramRootSection: Int32 {
    case categories
    case links
}

private enum MellowsgramRootControllerEntry: ItemListNodeEntry {
    case header
    case categoriesHeader
    case category(MellowsgramSettingsCategory)
    case linksHeader
    case channel
    case github

    var section: ItemListSectionId {
        switch self {
        case .header, .categoriesHeader, .category:
            return MellowsgramRootSection.categories.rawValue
        case .linksHeader, .channel, .github:
            return MellowsgramRootSection.links.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .categoriesHeader:
            return 2
        case let .category(category):
            return 3 + category.rawValue
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
        let languageCode = presentationData.strings.primaryComponent.languageCode
        switch self {
        case .header:
            return MellowsgramHeaderItem(sectionId: self.section)
        case .categoriesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: mellowsgramText("Categories", "Категории", languageCode: languageCode), sectionId: self.section)
        case let .category(category):
            let icon: UIImage?
            switch category {
            case .spyAndGhost:
                icon = PresentationResourcesSettings.security
            case .appearance:
                icon = PresentationResourcesSettings.appearance
            case .profilesAndCalls:
                icon = PresentationResourcesSettings.devices
            case .mediaAndVoice:
                icon = PresentationResourcesSettings.dataAndStorage
            case .messagesAndContext:
                icon = PresentationResourcesSettings.chatHistory
            }
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: icon,
                title: category.title(languageCode: languageCode),
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openCategory(category, nil, nil)
                }
            )
        case .linksHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: mellowsgramText("Links", "Ссылки", languageCode: languageCode), sectionId: self.section)
        case .channel:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: mellowsgramText("Channel", "Канал", languageCode: languageCode),
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
                label: "github.com/Eld3rly/Mellowsgram-IOS",
                labelStyle: .coloredText(presentationData.theme.list.itemAccentColor),
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openExternalUrl("https://github.com/Eld3rly/Mellowsgram-IOS")
                }
            )
        }
    }
}

private func mellowsgramRootControllerEntries() -> [MellowsgramRootControllerEntry] {
    return [.header, .categoriesHeader]
        + MellowsgramSettingsCategory.allCases.map { .category($0) }
        + [.linksHeader, .channel, .github]
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
        let languageCode = presentationData.strings.primaryComponent.languageCode
        switch self {
        case .spyAndGhostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: mellowsgramText("Ghost essentials", "Основные настройки невидимости", languageCode: languageCode), sectionId: self.section)
        case let .ghostMode(value, enabledCount):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "\(mellowsgramText("Ghost Mode", "Режим невидимки", languageCode: languageCode)) \(enabledCount)/5", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateGhostMode)
        case let .ghostDontReadMessages(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Don't Read Messages", "Не отмечать сообщения прочитанными", languageCode: languageCode), style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontReadMessages(!value)
            })
        case let .ghostDontReadStories(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Don't Read Stories", "Не отмечать истории просмотренными", languageCode: languageCode), style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontReadStories(!value)
            })
        case let .ghostDontSendOnline(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Don't Send Online", "Не отправлять статус «в сети»", languageCode: languageCode), style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontSendOnline(!value)
            })
        case let .ghostDontSendTyping(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Don't Send Typing", "Не отправлять статус «печатает»", languageCode: languageCode), style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostDontSendTyping(!value)
            })
        case let .ghostGoOfflineAutomatically(value):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Go Offline Automatically", "Автоматически уходить в офлайн", languageCode: languageCode), style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateGhostGoOfflineAutomatically(!value)
            })
        case .ghostEssentialsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(mellowsgramText("Toggle each safeguard independently. Ghost Mode applies only to the selected options.", "Каждую защиту можно включать отдельно. Режим невидимки применяет только выбранные параметры.", languageCode: languageCode)), sectionId: self.section)
        case .spyEssentialsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: mellowsgramText("Spy essentials", "Архив сообщений", languageCode: languageCode), sectionId: self.section)
        case let .saveDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Save Deleted Messages", "Сохранять удалённые сообщения", languageCode: languageCode), value: value, sectionId: self.section, style: .blocks, updated: arguments.updateSaveDeletedMessages)
        case let .showDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Show Deleted Messages", "Показывать удалённые сообщения", languageCode: languageCode), value: value, sectionId: self.section, style: .blocks, updated: arguments.updateShowDeletedMessages)
        case let .saveEditedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Save Edits History", "Сохранять историю изменений", languageCode: languageCode), value: value, sectionId: self.section, style: .blocks, updated: arguments.updateSaveEditedMessages)
        case .spyAndGhostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(mellowsgramText("Ghost Mode suppresses network read and presence updates. The archive is stored only on this account.", "Режим невидимки подавляет сетевые отметки о прочтении и статусе. Архив хранится только в этом аккаунте.", languageCode: languageCode)), sectionId: self.section)
        case let .backgroundNotifications(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Background Notifications", "Уведомления в фоне", languageCode: languageCode), value: value, sectionId: self.section, style: .blocks, updated: arguments.updateBackgroundNotificationsEnabled)
        case let .backgroundNotificationsAllAccounts(value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("All Accounts in Background", "Все аккаунты в фоне", languageCode: languageCode), value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: arguments.updateBackgroundNotificationsAllAccounts)
        case .backgroundNotificationsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(mellowsgramText("Keeps selected Telegram sessions active in the background for local notifications. This uses battery; iOS stops the connection after you force-quit the app.", "Поддерживает выбранные сессии Telegram в фоне для локальных уведомлений. Это расходует заряд; после принудительного закрытия iOS остановит соединение.", languageCode: languageCode)), sectionId: self.section)
        case .appearanceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: mellowsgramText("Appearance", "Внешний вид", languageCode: languageCode), sectionId: self.section)
        case let .translucentDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: mellowsgramText("Translucent Deleted Messages", "Полупрозрачные удалённые сообщения", languageCode: languageCode), value: value, sectionId: self.section, style: .blocks, updated: arguments.updateTranslucentDeletedMessages)
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(mellowsgramText("Changes only the appearance of locally archived deleted-message rows.", "Меняет только отображение локальных строк удалённых сообщений.", languageCode: languageCode)), sectionId: self.section)
        case let .globalSettingsHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .globalSetting(key, value, enabled):
            if key.mellowsgramIsPercentageSlider {
                return MellowsgramPercentageSliderItem(
                    theme: presentationData.theme,
                    title: key.mellowsgramTitle(languageCode: languageCode),
                    limits: key.mellowsgramSliderLimits(languageCode: languageCode),
                    value: Int32(value) ?? Int32(key.defaultValue) ?? 0,
                    sectionId: self.section,
                    updated: { updatedValue in
                        arguments.updateGlobalSetting(key, "\(updatedValue)")
                    }
                )
            } else if key.mellowsgramIsChoice {
                let title: String
                if let selected = key.mellowsgramChoices(languageCode: languageCode).first(where: { $0.0 == value }) {
                    title = selected.1
                } else {
                    title = value
                }
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: key.mellowsgramTitle(languageCode: languageCode), enabled: enabled, label: title, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.selectGlobalSetting(key, value)
                })
            }
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: key.mellowsgramTitle(languageCode: languageCode), value: value == "true", enabled: enabled, sectionId: self.section, style: .blocks, updated: { updatedValue in
                arguments.updateGlobalSetting(key, updatedValue ? "true" : "false")
            })
        }
    }
}

private final class MellowsgramPercentageSliderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let title: String
    let limits: (minimum: String, maximum: String)
    let value: Int32
    let sectionId: ItemListSectionId
    let updated: (Int32) -> Void

    init(theme: PresentationTheme, title: String, limits: (minimum: String, maximum: String), value: Int32, sectionId: ItemListSectionId, updated: @escaping (Int32) -> Void) {
        self.theme = theme
        self.title = title
        self.limits = limits
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
    private let titleTextNode: ImmediateTextNode
    private let minimumTextNode: ImmediateTextNode
    private let valueTextNode: ImmediateTextNode
    private let maximumTextNode: ImmediateTextNode
    private var sliderView: TGPhotoEditorSliderView?
    private var item: MellowsgramPercentageSliderItem?
    private var valueTextRightInset: CGFloat = 16.0
    private var sliderFrame: CGRect = .zero
    private var sliderHitTestRightInset: CGFloat = -16.0

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        self.maskNode = ASImageNode()
        self.titleTextNode = ImmediateTextNode()
        self.minimumTextNode = ImmediateTextNode()
        self.valueTextNode = ImmediateTextNode()
        self.maximumTextNode = ImmediateTextNode()
        super.init(layerBacked: false)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topStripeNode)
        self.addSubnode(self.bottomStripeNode)
        self.addSubnode(self.maskNode)
        self.addSubnode(self.titleTextNode)
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
        sliderView.dotSize = 5.0
        sliderView.minimumValue = 0.0
        sliderView.maximumValue = 1.0
        sliderView.startValue = 0.0
        sliderView.disablesInteractiveTransitionGestureRecognizer = true
        sliderView.displayEdges = true
        sliderView.addTarget(self, action: #selector(self.sliderValueChanged), for: .valueChanged)
        sliderView.interactionEnded = { [weak self] in
            self?.sliderEditingEnded()
        }
        self.view.addSubview(sliderView)
        self.sliderView = sliderView
        if let item = self.item {
            self.updateSliderView(sliderView, item: item, themeUpdated: true)
        }
    }

    func asyncLayout() -> (_ item: MellowsgramPercentageSliderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let currentItem = self.item
        return { [weak self] item, params, neighbors in
            let themeUpdated = currentItem?.theme !== item.theme
            let contentSize = CGSize(width: params.width, height: 104.0)
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
                self.titleTextNode.attributedText = NSAttributedString(string: item.title, font: Font.regular(15.0), textColor: item.theme.list.itemPrimaryTextColor)
                self.minimumTextNode.attributedText = NSAttributedString(string: item.limits.minimum, font: Font.regular(12.0), textColor: secondaryColor)
                self.valueTextNode.attributedText = NSAttributedString(string: "\(item.value)%", font: Font.semibold(14.0), textColor: item.theme.list.itemPrimaryTextColor)
                self.maximumTextNode.attributedText = NSAttributedString(string: item.limits.maximum, font: Font.regular(12.0), textColor: secondaryColor)
                let titleSize = self.titleTextNode.updateLayout(CGSize(width: max(0.0, params.width - params.leftInset - params.rightInset - 112.0), height: 24.0))
                let minimumSize = self.minimumTextNode.updateLayout(CGSize(width: max(0.0, params.width * 0.5), height: 20.0))
                let valueSize = self.valueTextNode.updateLayout(CGSize(width: 84.0, height: 24.0))
                let maximumSize = self.maximumTextNode.updateLayout(CGSize(width: max(0.0, params.width * 0.5), height: 20.0))
                self.valueTextRightInset = params.rightInset + 16.0
                self.titleTextNode.frame = CGRect(x: params.leftInset + 16.0, y: 10.0, width: titleSize.width, height: titleSize.height)
                self.valueTextNode.frame = CGRect(x: params.width - params.rightInset - 16.0 - valueSize.width, y: 10.0, width: valueSize.width, height: valueSize.height)
                self.minimumTextNode.frame = CGRect(x: params.leftInset + 16.0, y: 78.0, width: minimumSize.width, height: minimumSize.height)
                self.maximumTextNode.frame = CGRect(x: params.width - params.rightInset - 16.0 - maximumSize.width, y: 78.0, width: maximumSize.width, height: maximumSize.height)

                self.sliderFrame = CGRect(x: params.leftInset + 16.0, y: 34.0, width: params.width - params.leftInset - params.rightInset - 32.0, height: 40.0)
                self.sliderHitTestRightInset = -(params.rightInset + 16.0)
                if let sliderView = self.sliderView {
                    self.updateSliderView(sliderView, item: item, themeUpdated: themeUpdated)
                }
            })
        }
    }

    private func updateSliderView(_ sliderView: TGPhotoEditorSliderView, item: MellowsgramPercentageSliderItem, themeUpdated: Bool) {
        if themeUpdated || sliderView.backgroundColor == nil {
            sliderView.backgroundColor = item.theme.list.itemBlocksBackgroundColor
            sliderView.backColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.startColor = item.theme.list.itemSwitchColors.frameColor
            sliderView.trackColor = item.theme.list.itemAccentColor
            sliderView.knobImage = PresentationResourcesItemList.knobImage(item.theme)
        }
        sliderView.value = CGFloat(item.value) / 100.0
        sliderView.accessibilityLabel = item.title
        sliderView.accessibilityValue = "\(item.value)%"
        sliderView.frame = self.sliderFrame
        sliderView.hitTestEdgeInsets = UIEdgeInsets(top: -sliderView.frame.minY, left: 0.0, bottom: 0.0, right: self.sliderHitTestRightInset)
    }

    @objc private func sliderValueChanged() {
        guard let sliderView = self.sliderView, let item = self.item else {
            return
        }
        let value = Int32((sliderView.value * 100.0).rounded())
        self.valueTextNode.attributedText = NSAttributedString(string: "\(value)%", font: Font.semibold(14.0), textColor: item.theme.list.itemPrimaryTextColor)
        let valueSize = self.valueTextNode.updateLayout(CGSize(width: 84.0, height: 24.0))
        self.valueTextNode.frame = CGRect(x: self.bounds.width - self.valueTextRightInset - valueSize.width, y: 10.0, width: valueSize.width, height: valueSize.height)
        sliderView.accessibilityLabel = self.item?.title ?? "Slider"
        sliderView.accessibilityValue = "\(value)%"
    }

    @objc private func sliderEditingEnded() {
        guard let sliderView = self.sliderView else {
            return
        }
        self.item?.updated(Int32((sliderView.value * 100.0).rounded()))
    }
}

private func mellowsgramCategoryControllerEntries(category: MellowsgramSettingsCategory, settings: MellowsgramSettings, snapshot: MellowsgramSettingsSnapshot, languageCode: String, onlySetting: MellowsgramGlobalSettingKey?, onlyAccountSetting: MellowsgramAccountSetting?) -> [MellowsgramCategoryControllerEntry] {
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
            entries.append(.globalSettingsHeader(category.title(languageCode: languageCode)))
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
            let languageCode = presentationData.strings.primaryComponent.languageCode
            let options = key.mellowsgramChoices(languageCode: languageCode).map { rawValue, title in
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
            title: .text(category.title(languageCode: presentationData.strings.primaryComponent.languageCode)),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: mellowsgramCategoryControllerEntries(category: category, settings: settings, snapshot: snapshot, languageCode: presentationData.strings.primaryComponent.languageCode, onlySetting: onlySetting, onlyAccountSetting: onlyAccountSetting),
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

    let arguments = MellowsgramRootControllerArguments(
        openCategory: { category, setting, accountSetting in
            openCategoryImpl?(category, setting, accountSetting)
        },
        openExternalUrl: { url in
            openExternalUrlImpl?(url)
        }
    )

    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Mellowsgram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: mellowsgramRootControllerEntries(),
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
