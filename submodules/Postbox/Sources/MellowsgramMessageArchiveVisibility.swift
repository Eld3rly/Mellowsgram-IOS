import Foundation

/// The part of a history view that is relevant when deciding which locally
/// archived deleted messages can be rendered.
public struct MellowsgramArchiveHistoryState {
    public let loadedMessageIndices: [MessageIndex]
    public let liveMessageIds: Set<MessageId>
    public let earlierId: MessageIndex?
    public let laterId: MessageIndex?
    public let holeEarlier: Bool
    public let holeLater: Bool
    public let isLoading: Bool
    public let historyAppearsCleared: Bool

    public init(
        loadedMessageIndices: [MessageIndex],
        liveMessageIds: Set<MessageId>,
        earlierId: MessageIndex?,
        laterId: MessageIndex?,
        holeEarlier: Bool,
        holeLater: Bool,
        isLoading: Bool,
        historyAppearsCleared: Bool
    ) {
        self.loadedMessageIndices = loadedMessageIndices
        self.liveMessageIds = liveMessageIds
        self.earlierId = earlierId
        self.laterId = laterId
        self.holeEarlier = holeEarlier
        self.holeLater = holeLater
        self.isLoading = isLoading
        self.historyAppearsCleared = historyAppearsCleared
    }
}

/// Selects the local Mellowsgram archive rows that belong to a visible chat
/// history page. Archived rows are never sent back to Telegram and are only
/// eligible for rendering when the corresponding side of the live history is
/// fully loaded.
public func mellowsgramArchiveRecordsForHistory(
    records: [MellowsgramMessageArchiveRecord],
    peerId: PeerId,
    threadId: Int64?,
    state: MellowsgramArchiveHistoryState,
    excludedPeerNamespaces: Set<PeerId.Namespace> = [],
    excludedMessageNamespaces: Set<MessageId.Namespace> = []
) -> [MellowsgramMessageArchiveRecord] {
    guard !state.isLoading else {
        return []
    }

    let candidates = records.filter { record in
        guard record.messageId.peerId == peerId,
              record.threadId == threadId,
              record.deletedAt != nil,
              !excludedPeerNamespaces.contains(record.messageId.peerId.namespace),
              !excludedMessageNamespaces.contains(record.messageId.namespace),
              !state.liveMessageIds.contains(record.messageId) else {
            return false
        }
        return true
    }

    guard !candidates.isEmpty else {
        return []
    }

    let sortedCandidates = candidates.sorted { lhs, rhs in
        let lhsIndex = MessageIndex(id: lhs.messageId, timestamp: lhs.timestamp)
        let rhsIndex = MessageIndex(id: rhs.messageId, timestamp: rhs.timestamp)
        return lhsIndex < rhsIndex
    }

    guard let lowerBound = state.loadedMessageIndices.min(), let upperBound = state.loadedMessageIndices.max() else {
        // An empty, fully loaded history is the expected state after deleting
        // the last live message. This also covers the short interval while
        // historyAppearsCleared is true and the live view has caught up. If
        // either side is still a hole, avoid showing rows outside an unknown
        // range.
        guard state.earlierId == nil,
              state.laterId == nil,
              !state.holeEarlier,
              !state.holeLater else {
            return []
        }
        return sortedCandidates
    }

    return sortedCandidates.filter { record in
        let index = MessageIndex(id: record.messageId, timestamp: record.timestamp)
        if index < lowerBound {
            return state.earlierId == nil && !state.holeEarlier
        } else if index > upperBound {
            return state.laterId == nil && !state.holeLater
        } else {
            return true
        }
    }
}
