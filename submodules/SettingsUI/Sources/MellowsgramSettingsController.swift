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

private enum MellowsgramSettingsCategory {
    case spyAndGhost
    case appearance

    var title: String {
        switch self {
        case .spyAndGhost:
            return "Spy&Ghost"
        case .appearance:
            return "Appearance"
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
    let openCategory: (MellowsgramSettingsCategory) -> Void
    let openExternalUrl: (String) -> Void

    init(
        openCategory: @escaping (MellowsgramSettingsCategory) -> Void,
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
    case spyAndGhost
    case appearance
    case linksHeader
    case channel
    case github

    var section: ItemListSectionId {
        switch self {
        case .header, .categoriesHeader, .spyAndGhost, .appearance:
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
            return 1
        case .spyAndGhost:
            return 2
        case .appearance:
            return 3
        case .linksHeader:
            return 4
        case .channel:
            return 5
        case .github:
            return 6
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
        case .categoriesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Categories", sectionId: self.section)
        case .spyAndGhost:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: PresentationResourcesSettings.security,
                title: "Spy&Ghost",
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openCategory(.spyAndGhost)
                }
            )
        case .appearance:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: PresentationResourcesSettings.appearance,
                title: "Appearance",
                label: "",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .arrow,
                action: {
                    arguments.openCategory(.appearance)
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

private func mellowsgramRootControllerEntries() -> [MellowsgramRootControllerEntry] {
    return [
        .header,
        .categoriesHeader,
        .spyAndGhost,
        .appearance,
        .linksHeader,
        .channel,
        .github
    ]
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
        updateTranslucentDeletedMessages: @escaping (Bool) -> Void
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
    case appearanceHeader
    case translucentDeletedMessages(Bool)
    case appearanceFooter

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
        case .appearanceHeader:
            return 13
        case .translucentDeletedMessages:
            return 14
        case .appearanceFooter:
            return 15
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
        case .appearanceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Appearance", sectionId: self.section)
        case let .translucentDeletedMessages(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Translucent Deleted Messages", value: value, sectionId: self.section, style: .blocks, updated: arguments.updateTranslucentDeletedMessages)
        case .appearanceFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Изменяет только отображение локальных строк удалённых сообщений."), sectionId: self.section)
        }
    }
}

private func mellowsgramCategoryControllerEntries(category: MellowsgramSettingsCategory, settings: MellowsgramSettings) -> [MellowsgramCategoryControllerEntry] {
    switch category {
    case .spyAndGhost:
        let enabledCount = [
            settings.ghostDontReadMessages,
            settings.ghostDontReadStories,
            settings.ghostDontSendOnline,
            settings.ghostDontSendTyping,
            settings.ghostGoOfflineAutomatically
        ].filter { $0 }.count
        return [
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
            .spyAndGhostFooter
        ]
    case .appearance:
        return [
            .appearanceHeader,
            .translucentDeletedMessages(settings.translucentDeletedMessages),
            .appearanceFooter
        ]
    }
}

private func mellowsgramCategoryController(context: AccountContext, category: MellowsgramSettingsCategory) -> ViewController {
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
        }
    )

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, mellowsgramSettings(engine: context.engine))
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(category.title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: mellowsgramCategoryControllerEntries(category: category, settings: settings),
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
    var openCategoryImpl: ((MellowsgramSettingsCategory) -> Void)?
    var openExternalUrlImpl: ((String) -> Void)?

    let arguments = MellowsgramRootControllerArguments(
        openCategory: { category in
            openCategoryImpl?(category)
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
    openCategoryImpl = { [weak controller] category in
        guard let navigationController = controller?.navigationController as? NavigationController else {
            return
        }
        navigationController.pushViewController(mellowsgramCategoryController(context: context, category: category))
    }
    openExternalUrlImpl = { [weak controller] url in
        openMellowsgramExternalUrl(context: context, url: url, navigationController: controller?.navigationController as? NavigationController)
    }
    return controller
}
