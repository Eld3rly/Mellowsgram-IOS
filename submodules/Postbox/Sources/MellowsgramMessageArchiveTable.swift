import Foundation

public protocol MellowsgramMessageArchiveExclusion {
    var mellowsgramShouldNotArchive: Bool { get }
}

/// Marks message attributes that change the user-visible text representation
/// and therefore belong in edit history. Transport, read-state, and playback
/// attributes must not create text revisions.
public protocol MellowsgramMessageArchiveRevisionAttribute {
}

public struct MellowsgramMessageRevision: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case text
        case attributesData
        case timestamp
        case stableVersion
    }

    public let text: String
    public let attributesData: Data
    public let timestamp: Int32
    public let stableVersion: UInt32

    public init(text: String, attributesData: Data, timestamp: Int32, stableVersion: UInt32) {
        self.text = text
        self.attributesData = attributesData
        self.timestamp = timestamp
        self.stableVersion = stableVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decode(String.self, forKey: .text)
        self.attributesData = try container.decode(Data.self, forKey: .attributesData)
        self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
        self.stableVersion = try mellowsgramDecodeStableVersion(container, forKey: .stableVersion)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.text, forKey: .text)
        try container.encode(self.attributesData, forKey: .attributesData)
        try container.encode(self.timestamp, forKey: .timestamp)
        // AdaptedPostboxEncoder intentionally has no UInt32 single-value
        // container. Store the bit-preserving value as its supported Int64 type.
        try container.encode(Int64(self.stableVersion), forKey: .stableVersion)
    }
}

public struct MellowsgramMessageArchiveRecord: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case messageId
        case threadId
        case timestamp
        case authorId
        case isIncoming
        case text
        case attributesData
        case deletedAt
        case stableId
        case stableVersion
        case mediaData
        case revisions
    }

    public let messageId: MessageId
    public let threadId: Int64?
    public let timestamp: Int32
    public let authorId: PeerId?
    public let isIncoming: Bool
    public var text: String
    public var attributesData: Data
    public var deletedAt: Int32?
    /// The original Telegram stable id. Keeping it in the local archive lets
    /// the UI replace the live row in place instead of inserting a second
    /// service-style item.
    public var stableId: UInt32
    public var stableVersion: UInt32
    /// Serialized media descriptors only. Resource bytes stay in MediaBox and
    /// are never copied into the archive table.
    public var mediaData: Data
    public var revisions: [MellowsgramMessageRevision]

    public init(
        messageId: MessageId,
        threadId: Int64?,
        timestamp: Int32,
        authorId: PeerId?,
        isIncoming: Bool,
        text: String,
        attributesData: Data,
        deletedAt: Int32?,
        stableVersion: UInt32,
        revisions: [MellowsgramMessageRevision],
        stableId: UInt32 = 0,
        mediaData: Data = Data()
    ) {
        self.messageId = messageId
        self.threadId = threadId
        self.timestamp = timestamp
        self.authorId = authorId
        self.isIncoming = isIncoming
        self.text = text
        self.attributesData = attributesData
        self.deletedAt = deletedAt
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.mediaData = mediaData
        self.revisions = revisions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.messageId = try container.decode(MessageId.self, forKey: .messageId)
        self.threadId = try container.decodeIfPresent(Int64.self, forKey: .threadId)
        self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
        self.authorId = try container.decodeIfPresent(PeerId.self, forKey: .authorId)
        self.isIncoming = try container.decode(Bool.self, forKey: .isIncoming)
        self.text = try container.decode(String.self, forKey: .text)
        self.attributesData = try container.decode(Data.self, forKey: .attributesData)
        self.deletedAt = try container.decodeIfPresent(Int32.self, forKey: .deletedAt)
        if let stableId = try container.decodeIfPresent(Int64.self, forKey: .stableId), stableId >= 0, stableId <= Int64(UInt32.max) {
            self.stableId = UInt32(stableId)
        } else {
            // Records written before the stable-id field used the message id
            // as the UI identity. Preserve that identity when upgrading them.
            self.stableId = UInt32(bitPattern: self.messageId.id)
        }
        self.stableVersion = try mellowsgramDecodeStableVersion(container, forKey: .stableVersion)
        self.mediaData = try container.decodeIfPresent(Data.self, forKey: .mediaData) ?? Data()
        self.revisions = try container.decode([MellowsgramMessageRevision].self, forKey: .revisions)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.messageId, forKey: .messageId)
        try container.encodeIfPresent(self.threadId, forKey: .threadId)
        try container.encode(self.timestamp, forKey: .timestamp)
        try container.encodeIfPresent(self.authorId, forKey: .authorId)
        try container.encode(self.isIncoming, forKey: .isIncoming)
        try container.encode(self.text, forKey: .text)
        try container.encode(self.attributesData, forKey: .attributesData)
        try container.encodeIfPresent(self.deletedAt, forKey: .deletedAt)
        try container.encode(Int64(self.stableId), forKey: .stableId)
        // See MellowsgramMessageRevision.encode(to:): UInt32 is not a supported
        // scalar in AdaptedPostboxEncoder.
        try container.encode(Int64(self.stableVersion), forKey: .stableVersion)
        try container.encode(self.mediaData, forKey: .mediaData)
        try container.encode(self.revisions, forKey: .revisions)
    }
}

private func mellowsgramDecodeStableVersion<Key: CodingKey>(_ container: KeyedDecodingContainer<Key>, forKey key: Key) throws -> UInt32 {
    let value = try container.decode(Int64.self, forKey: key)
    guard value >= 0 && value <= Int64(UInt32.max) else {
        throw DecodingError.dataCorrupted(.init(
            codingPath: container.codingPath + [key],
            debugDescription: "Mellowsgram stableVersion is outside UInt32 range"
        ))
    }
    return UInt32(value)
}

final class MellowsgramMessageArchiveTable: Table {
    private var cachedEntries: [MessageId: MellowsgramMessageArchiveRecord] = [:]
    private var updatedMessageIds = Set<MessageId>()

    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .binary, compactValuesOnCreation: true)
    }

    override func clearMemoryCache() {
        assert(self.updatedMessageIds.isEmpty)
        self.cachedEntries.removeAll()
    }

    func get(_ messageId: MessageId) -> MellowsgramMessageArchiveRecord? {
        if let entry = self.cachedEntries[messageId] {
            return entry
        }
        if let value = self.valueBox.get(self.table, key: self.key(messageId)), let entry = CodableEntry(data: value.makeData()).get(MellowsgramMessageArchiveRecord.self) {
            self.cachedEntries[messageId] = entry
            return entry
        }
        return nil
    }

    func set(_ entry: MellowsgramMessageArchiveRecord) {
        self.cachedEntries[entry.messageId] = entry
        self.updatedMessageIds.insert(entry.messageId)
    }

    func remove(_ messageId: MessageId) {
        self.cachedEntries.removeValue(forKey: messageId)
        self.updatedMessageIds.insert(messageId)
    }

    func records(peerId: PeerId, threadId: Int64?) -> [MellowsgramMessageArchiveRecord] {
        var resultById: [MessageId: MellowsgramMessageArchiveRecord] = [:]
        self.valueBox.scan(self.table, values: { _, value in
            if let entry = CodableEntry(data: value.makeData()).get(MellowsgramMessageArchiveRecord.self), entry.messageId.peerId == peerId, entry.threadId == threadId {
                resultById[entry.messageId] = entry
            }
            return true
        })

        // The table is read while the current transaction is open. Include values
        // from the in-memory write cache, which are not committed yet. Cached
        // values intentionally overwrite the persisted value: an edit and a
        // deletion can be read before the ValueBox commit.
        for entry in self.cachedEntries.values where entry.messageId.peerId == peerId && entry.threadId == threadId {
            resultById[entry.messageId] = entry
        }
        return resultById.values.sorted { lhs, rhs in
            if lhs.timestamp == rhs.timestamp {
                return lhs.messageId < rhs.messageId
            } else {
                return lhs.timestamp < rhs.timestamp
            }
        }
    }

    func archiveDeletedMessage(_ message: IntermediateMessage, timestamp: Int32, media: [Media]) {
        guard Self.isEligible(message) else {
            return
        }
        if var entry = self.get(message.id) {
            entry.stableId = message.stableId
            entry.mediaData = Self.encodeMedia(media)
            if entry.deletedAt == nil {
                entry.deletedAt = timestamp
            }
            self.set(entry)
        } else {
            self.set(MellowsgramMessageArchiveRecord(
                messageId: message.id,
                threadId: message.threadId,
                timestamp: message.timestamp,
                authorId: message.authorId,
                isIncoming: !message.flags.intersection(.IsIncomingMask).isEmpty,
                text: message.text,
                attributesData: message.attributesData.makeData(),
                deletedAt: timestamp,
                stableVersion: message.stableVersion,
                revisions: [],
                stableId: message.stableId,
                mediaData: Self.encodeMedia(media)
            ))
        }
    }

    func archiveRevision(previousMessage: IntermediateMessage, updatedMessage: StoreMessage, timestamp: Int32) {
        guard Self.isEligible(previousMessage), case let .Id(updatedId) = updatedMessage.id, updatedId == previousMessage.id else {
            return
        }
        let updatedAttributesData = Self.encodeAttributes(updatedMessage.attributes)
        let previousRevisionAttributesData = Self.encodeRevisionAttributes(Self.decodeAttributes(previousMessage.attributesData))
        let updatedRevisionAttributesData = Self.encodeRevisionAttributes(updatedMessage.attributes)
        guard previousMessage.text != updatedMessage.text || previousRevisionAttributesData != updatedRevisionAttributesData else {
            return
        }

        var entry = self.get(previousMessage.id) ?? MellowsgramMessageArchiveRecord(
            messageId: previousMessage.id,
            threadId: previousMessage.threadId,
            timestamp: previousMessage.timestamp,
            authorId: previousMessage.authorId,
            isIncoming: !previousMessage.flags.intersection(.IsIncomingMask).isEmpty,
            text: previousMessage.text,
            attributesData: previousMessage.attributesData.makeData(),
            deletedAt: nil,
            stableVersion: previousMessage.stableVersion,
            revisions: [],
            stableId: previousMessage.stableId,
            mediaData: Self.encodeMedia(updatedMessage.media)
        )

        let previousRevision = MellowsgramMessageRevision(
            text: previousMessage.text,
            attributesData: previousMessage.attributesData.makeData(),
            timestamp: timestamp,
            stableVersion: previousMessage.stableVersion
        )
        if entry.revisions.last != previousRevision {
            entry.revisions.append(previousRevision)
        }
        entry.text = updatedMessage.text
        entry.attributesData = updatedAttributesData
        entry.stableVersion = previousMessage.stableVersion == UInt32.max ? UInt32.max : previousMessage.stableVersion + 1
        entry.stableId = previousMessage.stableId
        entry.mediaData = Self.encodeMedia(updatedMessage.media)
        self.set(entry)
    }

    private static func isEligible(_ message: IntermediateMessage) -> Bool {
        // Cloud and local messages only. Secret, scheduled, ephemeral and other
        // namespaces intentionally keep Telegram's original privacy semantics.
        // Peer namespace 3 is the Postbox-level Secret Chat namespace. Keep the
        // check here (rather than in TelegramCore) so the archive cannot be
        // enabled for secret chats by an accidental caller.
        guard (message.id.namespace == 0 || message.id.namespace == 1) && message.id.peerId.namespace._internalGetInt32Value() != 3 else {
            return false
        }

        let attributesData = message.attributesData.sharedBufferNoCopy()
        guard attributesData.length >= 4 else {
            return true
        }

        var attributeCount: Int32 = 0
        attributesData.read(&attributeCount, offset: 0, length: 4)
        guard attributeCount >= 0 else {
            return true
        }

        for _ in 0 ..< attributeCount {
            guard attributesData.offset + 4 <= attributesData.length else {
                break
            }
            var attributeLength: Int32 = 0
            attributesData.read(&attributeLength, offset: 0, length: 4)
            guard attributeLength >= 0, attributesData.offset + Int(attributeLength) <= attributesData.length else {
                break
            }
            let attribute = PostboxDecoder(buffer: MemoryBuffer(
                memory: attributesData.memory.advanced(by: attributesData.offset),
                capacity: Int(attributeLength),
                length: Int(attributeLength),
                freeWhenDone: false
            )).decodeRootObject()
            if let attribute = attribute as? MellowsgramMessageArchiveExclusion, attribute.mellowsgramShouldNotArchive {
                return false
            }
            attributesData.skip(Int(attributeLength))
        }
        return true
    }

    private static func encodeAttributes(_ attributes: [MessageAttribute]) -> Data {
        let buffer = WriteBuffer()
        var count = Int32(attributes.count)
        buffer.write(&count, offset: 0, length: 4)
        let encoder = PostboxEncoder()
        for attribute in attributes {
            encoder.reset()
            encoder.encodeRootObject(attribute)
            let data = encoder.makeData()
            var length = Int32(data.count)
            buffer.write(&length, offset: 0, length: 4)
            buffer.write(data)
        }
        return buffer.makeData()
    }

    private static func encodeRevisionAttributes(_ attributes: [MessageAttribute]) -> Data {
        return Self.encodeAttributes(attributes.filter { $0 is MellowsgramMessageArchiveRevisionAttribute })
    }

    private static func decodeAttributes(_ data: ReadBuffer) -> [MessageAttribute] {
        let buffer = data.sharedBufferNoCopy()
        guard buffer.length >= 4 else {
            return []
        }

        var attributeCount: Int32 = 0
        buffer.read(&attributeCount, offset: 0, length: 4)
        guard attributeCount >= 0 else {
            return []
        }

        var attributes: [MessageAttribute] = []
        for _ in 0 ..< attributeCount {
            guard buffer.offset + 4 <= buffer.length else {
                break
            }
            var attributeLength: Int32 = 0
            buffer.read(&attributeLength, offset: 0, length: 4)
            guard attributeLength >= 0, buffer.offset + Int(attributeLength) <= buffer.length else {
                break
            }
            if let attribute = PostboxDecoder(buffer: MemoryBuffer(
                memory: buffer.memory.advanced(by: buffer.offset),
                capacity: Int(attributeLength),
                length: Int(attributeLength),
                freeWhenDone: false
            )).decodeRootObject() as? MessageAttribute {
                attributes.append(attribute)
            }
            buffer.skip(Int(attributeLength))
        }
        return attributes
    }

    private static func encodeMedia(_ media: [Media]) -> Data {
        let buffer = WriteBuffer()
        var count = Int32(media.count)
        buffer.write(&count, offset: 0, length: 4)
        let encoder = PostboxEncoder()
        for object in media {
            encoder.reset()
            encoder.encodeRootObject(object)
            let data = encoder.makeData()
            var length = Int32(data.count)
            buffer.write(&length, offset: 0, length: 4)
            buffer.write(data)
        }
        return buffer.makeData()
    }

    private func key(_ messageId: MessageId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 16)
        key.setInt64(0, value: messageId.peerId.toInt64())
        key.setInt32(8, value: messageId.namespace)
        key.setInt32(12, value: messageId.id)
        return key
    }

    override func beforeCommit() {
        for messageId in self.updatedMessageIds {
            let key = self.key(messageId)
            if let entry = self.cachedEntries[messageId], let value = CodableEntry(entry) {
                self.valueBox.set(self.table, key: key, value: ReadBuffer(data: value.data))
            } else {
                self.valueBox.remove(self.table, key: key, secure: false)
            }
        }
        self.updatedMessageIds.removeAll()
    }
}
