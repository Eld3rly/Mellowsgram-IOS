import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext

private enum MellowsgramEditHistorySection: Int32 {
    case versions
}

private enum MellowsgramEditHistoryEntry: ItemListNodeEntry {
    case header
    case current(String)
    case revision(index: Int32, text: String, timestamp: Int32)
    case footer

    var section: ItemListSectionId {
        return MellowsgramEditHistorySection.versions.rawValue
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .current:
            return 1
        case let .revision(index, _, _):
            return 2 + index
        case .footer:
            return Int32.max
        }
    }

    static func < (lhs: MellowsgramEditHistoryEntry, rhs: MellowsgramEditHistoryEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let languageCode = presentationData.strings.primaryComponent.languageCode
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: mellowsgramLocalizedString(english: "Message Versions", russian: "Версии сообщения", languageCode: languageCode), sectionId: self.section)
        case let .current(text):
            return ItemListMultilineTextItem(
                presentationData: presentationData,
                text: "\(mellowsgramLocalizedString(english: "Current", russian: "Текущая", languageCode: languageCode))\n\(text)",
                enabledEntityTypes: [],
                sectionId: self.section,
                style: .blocks,
                action: {
                    UIPasteboard.general.string = text
                }
            )
        case let .revision(_, text, timestamp):
            return ItemListMultilineTextItem(
                presentationData: presentationData,
                text: "\(MellowsgramEditHistoryEntry.dateString(timestamp, languageCode: languageCode))\n\(text)",
                enabledEntityTypes: [],
                sectionId: self.section,
                style: .blocks,
                action: {
                    UIPasteboard.general.string = text
                }
            )
        case .footer:
            return ItemListTextItem(
                presentationData: presentationData,
                text: .plain(mellowsgramLocalizedString(english: "Tap a version to copy its text.", russian: "Нажмите на версию, чтобы скопировать её текст.", languageCode: languageCode)),
                sectionId: self.section
            )
        }
    }

    private static func dateString(_ timestamp: Int32, languageCode: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageCode)
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

private func mellowsgramEditHistoryEntries(record: EngineMellowsgramMessageArchiveRecord) -> [MellowsgramEditHistoryEntry] {
    var entries: [MellowsgramEditHistoryEntry] = [
        .header,
        .current(record.text)
    ]

    for (index, revision) in record.revisions.reversed().enumerated() {
        entries.append(.revision(index: Int32(index), text: revision.text, timestamp: revision.timestamp))
    }

    entries.append(.footer)
    return entries
}

public func mellowsgramEditHistoryController(context: AccountContext, record: EngineMellowsgramMessageArchiveRecord) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let itemListPresentationData = ItemListPresentationData(presentationData)
        let controllerState = ItemListControllerState(
            presentationData: itemListPresentationData,
            title: .text(mellowsgramLocalizedString(english: "Edit History", russian: "История редактирования", languageCode: presentationData.strings.primaryComponent.languageCode)),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back)
        )
        let listState = ItemListNodeState(
            presentationData: itemListPresentationData,
            entries: mellowsgramEditHistoryEntries(record: record),
            style: .blocks,
            animateChanges: false
        )
        return (controllerState, (listState, ()))
    }

    return ItemListController(context: context, state: signal)
}
