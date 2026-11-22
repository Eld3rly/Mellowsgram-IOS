import Foundation
import Postbox
import SwiftSignalKit

/// UI-only marker used when an archived Mellowsgram message is rendered through
/// Telegram's regular message bubble pipeline. It is never written to Postbox:
/// the display message is an in-memory EngineRawMessage created by TelegramUI.
public final class MellowsgramDeletedMessageAttribute: MessageAttribute {
    /// The archive record is carried only by the in-memory UI projection. It
    /// lets the regular message item open edit history without adding a second
    /// Postbox message or a ChatInfo row.
    public let record: MellowsgramMessageArchiveRecord?
    public let translucent: Bool

    public init(record: MellowsgramMessageArchiveRecord? = nil, translucent: Bool = false) {
        self.record = record
        self.translucent = translucent
    }

    required public init(decoder: PostboxDecoder) {
        self.record = nil
        self.translucent = false
    }

    public func encode(_ encoder: PostboxEncoder) {
    }
}

/// UI-only marker put on a display copy after Mellowsgram removes the
/// autoremove/view-once attributes. It lets media playback and consume paths
/// distinguish that copy from an ordinary Telegram message without changing
/// the persisted Postbox message.
///
/// The original timer state is intentionally retained as display metadata.
/// Keeping the real Telegram attributes here would re-enable the regular
/// view-once/auto-remove renderer, so the media stays replayable while the
/// standard Telegram badge can still tell the user what the original message
/// contained.
public final class MellowsgramAutoremoveBypassAttribute: MessageAttribute {
    public let timeout: Int32?
    public let isViewOnce: Bool

    public init(timeout: Int32? = nil, isViewOnce: Bool = false) {
        self.timeout = timeout
        self.isViewOnce = isViewOnce || timeout == viewOnceTimeout
    }

    required public init(decoder: PostboxDecoder) {
        self.timeout = nil
        self.isViewOnce = false
    }

    public func encode(_ encoder: PostboxEncoder) {
    }
}

/// Public engine-facing name for the local Postbox archive record.
public typealias EngineMellowsgramMessageArchiveRecord = MellowsgramMessageArchiveRecord

/// Engine-facing access to the local Mellowsgram archive for consumer modules.
public func mellowsgramArchiveRecords(engine: TelegramEngine, peerId: PeerId, threadId: Int64?) -> Signal<[EngineMellowsgramMessageArchiveRecord], NoError> {
    return engine.account.postbox.mellowsgramArchiveRecords(peerId: peerId, threadId: threadId)
}

/// Decodes all message attributes stored in a Mellowsgram archive record.
///
/// Postbox stores message attributes as a length-prefixed sequence of encoded
/// objects. The helper lives in TelegramCore because the archive table
/// intentionally stays in Postbox while the display projection is assembled by
/// TelegramUI.
public func engineMellowsgramMessageAttributes(_ attributesData: Data) -> [MessageAttribute] {
    let buffer = ReadBuffer(data: attributesData)
    guard buffer.length >= 4 else {
        return []
    }

    var attributeCount: Int32 = 0
    buffer.read(&attributeCount, offset: 0, length: 4)
    guard attributeCount >= 0 else {
        return []
    }

    var result: [MessageAttribute] = []
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
            result.append(attribute)
        }
        buffer.skip(Int(attributeLength))
    }
    return result
}

/// Decodes the text entities stored in a Mellowsgram archive record.
public func engineMellowsgramMessageTextEntities(_ attributesData: Data) -> [MessageTextEntity] {
    return engineMellowsgramMessageAttributes(attributesData).compactMap { attribute in
        (attribute as? TextEntitiesMessageAttribute)?.entities
    }.flatMap { $0 }
}

private func mellowsgramAutoremoveBypassAttribute(attributes: [MessageAttribute]) -> MellowsgramAutoremoveBypassAttribute? {
    if let existing = attributes.first(where: { $0 is MellowsgramAutoremoveBypassAttribute }) as? MellowsgramAutoremoveBypassAttribute {
        return existing
    }

    var timeout: Int32?
    var isViewOnce = false
    for attribute in attributes {
        if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
            if attribute.timeout == viewOnceTimeout {
                isViewOnce = true
            } else if let currentTimeout = timeout {
                timeout = min(currentTimeout, attribute.timeout)
            } else {
                timeout = attribute.timeout
            }
        } else if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
            if attribute.timeout == viewOnceTimeout {
                isViewOnce = true
            } else if let currentTimeout = timeout {
                timeout = min(currentTimeout, attribute.timeout)
            } else {
                timeout = attribute.timeout
            }
        }
    }

    if isViewOnce {
        return MellowsgramAutoremoveBypassAttribute(timeout: viewOnceTimeout, isViewOnce: true)
    } else if let timeout {
        return MellowsgramAutoremoveBypassAttribute(timeout: timeout)
    } else {
        return nil
    }
}

/// Returns the display-only timer metadata attached to a Mellowsgram-projected
/// message. The metadata is not a real Telegram timer and must not be passed to
/// Postbox or the consume/autoremove machinery.
public func engineMellowsgramAutoremoveBypassAttribute(_ message: EngineRawMessage) -> MellowsgramAutoremoveBypassAttribute? {
    return message.attributes.compactMap { $0 as? MellowsgramAutoremoveBypassAttribute }.first
}

private func engineMellowsgramAutoremoveBypassAttribute(_ attributesData: Data) -> MellowsgramAutoremoveBypassAttribute? {
    return mellowsgramAutoremoveBypassAttribute(attributes: engineMellowsgramMessageAttributes(attributesData))
}

private func mellowsgramArchivedDisplayAttributes(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        // These attributes either re-enable one-shot/auto-remove behaviour or
        // point to server state that is deliberately absent from a tombstone.
        !(attribute is AutoremoveTimeoutMessageAttribute) &&
        !(attribute is AutoclearTimeoutMessageAttribute) &&
        !(attribute is ConsumableContentMessageAttribute) &&
        !(attribute is MellowsgramAutoremoveBypassAttribute) &&
        !(attribute is MellowsgramDeletedMessageAttribute) &&
        !(attribute is ReactionsMessageAttribute) &&
        !(attribute is PendingReactionsMessageAttribute) &&
        !(attribute is PendingStarsReactionsMessageAttribute) &&
        !(attribute is ReplyMessageAttribute) &&
        !(attribute is ReplyStoryAttribute) &&
        !(attribute is ReplyThreadMessageAttribute)
    }
}

/// Builds the non-persistent attributes used by the Telegram UI projection of
/// an archived message. Postbox types stay behind this TelegramCore wrapper so
/// TelegramUI does not import Postbox directly.
public func engineMellowsgramDeletedMessageAttributes(_ attributesData: Data) -> [MessageAttribute] {
    var result: [MessageAttribute] = [MellowsgramDeletedMessageAttribute()]
    if let autoremoveAttribute = engineMellowsgramAutoremoveBypassAttribute(attributesData) {
        result.append(autoremoveAttribute)
    }
    result.append(contentsOf: mellowsgramArchivedDisplayAttributes(engineMellowsgramMessageAttributes(attributesData)))
    return result
}

public func engineMellowsgramMessageIsDeleted(_ message: EngineRawMessage) -> Bool {
    return message.attributes.contains { $0 is MellowsgramDeletedMessageAttribute }
}

public func engineMellowsgramMessageIsEphemeral(_ message: EngineRawMessage) -> Bool {
    if Namespaces.Message.allEphemeral.contains(message.id.namespace) {
        return true
    }
    return message.attributes.contains { attribute in
        attribute is EphemeralMessageAttribute || attribute is EphemeralOutgoingMessageAttribute
    }
}

public func engineMellowsgramMessageIsAutoremoveBypassed(_ message: EngineRawMessage) -> Bool {
    return engineMellowsgramAutoremoveBypassAttribute(message) != nil
}

/// Returns a display-only copy with ordinary cloud-chat self-destruct and
/// consumable-content attributes removed. The persisted message and Telegram's
/// server-side state are never modified here.
public func engineMellowsgramMessageBypassingAutoremoveTimers(_ message: EngineRawMessage) -> EngineRawMessage {
    guard message.id.peerId.namespace != Namespaces.Peer.SecretChat,
          !engineMellowsgramMessageIsEphemeral(message) else {
        return message
    }

    guard let bypassAttribute = mellowsgramAutoremoveBypassAttribute(attributes: message.attributes) else {
        return message
    }

    var attributes = message.attributes.filter { attribute in
        !(attribute is AutoremoveTimeoutMessageAttribute) &&
        !(attribute is AutoclearTimeoutMessageAttribute) &&
        !(attribute is ConsumableContentMessageAttribute) &&
        !(attribute is MellowsgramAutoremoveBypassAttribute)
    }
    attributes.append(bypassAttribute)
    return message.withUpdatedAttributes(attributes)
}

/// Decodes the serialized media descriptors captured before the live message
/// is removed. The descriptors contain Telegram's normal media/resource ids;
/// media bytes are still owned by MediaBox and are not duplicated here.
public func engineMellowsgramMessageMedia(_ mediaData: Data) -> [EngineRawMedia] {
    let buffer = ReadBuffer(data: mediaData)
    guard buffer.length >= 4 else {
        return []
    }

    var mediaCount: Int32 = 0
    buffer.read(&mediaCount, offset: 0, length: 4)
    guard mediaCount >= 0 else {
        return []
    }

    var result: [EngineRawMedia] = []
    for _ in 0 ..< mediaCount {
        guard buffer.offset + 4 <= buffer.length else {
            break
        }

        var mediaLength: Int32 = 0
        buffer.read(&mediaLength, offset: 0, length: 4)
        guard mediaLength >= 0, buffer.offset + Int(mediaLength) <= buffer.length else {
            break
        }

        if let media = PostboxDecoder(buffer: MemoryBuffer(
            memory: buffer.memory.advanced(by: buffer.offset),
            capacity: Int(mediaLength),
            length: Int(mediaLength),
            freeWhenDone: false
        )).decodeRootObject() as? EngineRawMedia {
            result.append(media)
        }
        buffer.skip(Int(mediaLength))
    }
    return result
}

struct MellowsgramDeletedReplyFormatting {
    /// Text that represents the archived message inside the reply quote.
    ///
    /// The author line is deliberately not built here: whether it belongs in
    /// the quote depends on the destination peer (groups/channels use it,
    /// private chats do not), and the peer lookup is only available to the
    /// enqueue transaction.
    let preview: String
}

private func mellowsgramUsesRussian(languageCode: String) -> Bool {
    return languageCode.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first == "ru"
}

private func mellowsgramDeletedReplyMediaDescription(_ media: [EngineRawMedia], languageCode: String) -> String? {
    let isRussian = mellowsgramUsesRussian(languageCode: languageCode)
    for item in media {
        if item is TelegramMediaImage {
            return isRussian ? "Фото" : "Photo"
        } else if let file = item as? TelegramMediaFile {
            if file.isInstantVideo {
                return isRussian ? "Видеосообщение" : "Video message"
            } else if file.isVoice {
                return isRussian ? "Голосовое сообщение" : "Voice message"
            } else if file.isVideo {
                return isRussian ? "Видео" : "Video"
            } else if file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                return isRussian ? "Стикер" : "Sticker"
            } else if file.isMusic {
                return isRussian ? "Аудио" : "Audio"
            } else {
                return isRussian ? "Файл" : "File"
            }
        } else if item is TelegramMediaPoll {
            return isRussian ? "Опрос" : "Poll"
        } else if item is TelegramMediaContact {
            return isRussian ? "Контакт" : "Contact"
        } else if item is TelegramMediaMap {
            return isRussian ? "Геопозиция" : "Location"
        } else if item is TelegramMediaWebpage {
            return isRussian ? "Ссылка" : "Link"
        }
    }
    return nil
}

func mellowsgramDeletedReplyFormatting(record: EngineMellowsgramMessageArchiveRecord, languageCode: String) -> MellowsgramDeletedReplyFormatting? {
    guard record.deletedAt != nil else {
        return nil
    }

    // Keep the original line breaks. AyuGram's deleted-message reply is a
    // real block quote, not a service-message label flattened into one line.
    let normalizedText = record.text.trimmingCharacters(in: .whitespacesAndNewlines)
    let preview: String
    if normalizedText.isEmpty {
        let isRussian = mellowsgramUsesRussian(languageCode: languageCode)
        preview = mellowsgramDeletedReplyMediaDescription(engineMellowsgramMessageMedia(record.mediaData), languageCode: languageCode) ?? (isRussian ? "Вложение" : "Attachment")
    } else {
        preview = String(normalizedText.prefix(256))
    }

    return MellowsgramDeletedReplyFormatting(preview: preview)
}

/// Creates a regular Telegram `Message` projection for a deleted archive row.
/// It is deliberately not written back to Postbox: the only identity visible
/// to the list is the original message stable id, so a deletion updates the
/// existing row instead of inserting a fake service message.
public func engineMellowsgramDeletedMessage(
    record: EngineMellowsgramMessageArchiveRecord,
    translucent: Bool,
    author: EngineRawPeer? = nil,
    peers: [PeerId: EngineRawPeer] = [:]
) -> EngineRawMessage {
    var textEntities: [MessageAttribute] = [MellowsgramDeletedMessageAttribute(record: record, translucent: translucent)]
    if let autoremoveAttribute = engineMellowsgramAutoremoveBypassAttribute(record.attributesData) {
        textEntities.append(autoremoveAttribute)
    }
    textEntities.append(contentsOf: mellowsgramArchivedDisplayAttributes(engineMellowsgramMessageAttributes(record.attributesData)))

    return EngineRawMessage(
        stableId: record.stableId == 0 ? UInt32(bitPattern: record.messageId.id) : record.stableId,
        stableVersion: record.stableVersion,
        id: EngineMessage.Id(peerId: record.messageId.peerId, namespace: record.messageId.namespace, id: record.messageId.id),
        globallyUniqueId: nil,
        groupingKey: record.groupingKey,
        groupInfo: record.groupInfoStableId.map { EngineMessage.GroupInfo(stableId: $0) },
        threadId: record.threadId,
        timestamp: record.timestamp,
        flags: record.isIncoming ? [.Incoming] : [],
        tags: [],
        globalTags: [],
        localTags: [],
        customTags: [],
        forwardInfo: nil,
        author: author,
        text: record.text,
        attributes: textEntities,
        media: engineMellowsgramMessageMedia(record.mediaData),
        peers: EngineSimpleDictionary(peers),
        associatedMessages: EngineSimpleDictionary(),
        associatedMessageIds: [],
        associatedMedia: [:],
        associatedThreadInfo: nil,
        associatedStories: [:]
    )
}

/// Keeps the already-rendered live message (including its media, peers and
/// captions) and only adds the in-memory deleted marker. This is used during
/// the deletion transition so the media renderer never falls back to a text
/// placeholder while Postbox removes the original row.
public func engineMellowsgramDeletedMessage(message: EngineRawMessage, record: EngineMellowsgramMessageArchiveRecord, translucent: Bool) -> EngineRawMessage {
    let bypassAttribute = mellowsgramAutoremoveBypassAttribute(attributes: message.attributes)
    var attributes = mellowsgramArchivedDisplayAttributes(message.attributes)
    if let bypassAttribute {
        attributes.append(bypassAttribute)
    }
    attributes.append(MellowsgramDeletedMessageAttribute(record: record, translucent: translucent))
    return message.withUpdatedAttributes(attributes)
}

/// In-memory tombstone used for the short interval between Postbox removing a
/// live row and the archive table publishing its committed record.
public func engineMellowsgramDeletedMessage(message: EngineRawMessage, translucent: Bool) -> EngineRawMessage {
    let bypassAttribute = mellowsgramAutoremoveBypassAttribute(attributes: message.attributes)
    var attributes = mellowsgramArchivedDisplayAttributes(message.attributes)
    if let bypassAttribute {
        attributes.append(bypassAttribute)
    }
    attributes.append(MellowsgramDeletedMessageAttribute(translucent: translucent))
    return message.withUpdatedAttributes(attributes)
}
