import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
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
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "Версии сообщения", sectionId: self.section)
        case let .current(text):
            return ItemListMultilineTextItem(
                presentationData: presentationData,
                text: "Текущая\n\(text)",
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
                text: "\(MellowsgramEditHistoryEntry.dateString(timestamp))\n\(text)",
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
                text: .plain("Нажмите на версию, чтобы скопировать её текст."),
                sectionId: self.section
            )
        }
    }

    private static func dateString(_ timestamp: Int32) -> String {
        let formatter = DateFormatter()
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
            title: .text("История редактирования"),
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
