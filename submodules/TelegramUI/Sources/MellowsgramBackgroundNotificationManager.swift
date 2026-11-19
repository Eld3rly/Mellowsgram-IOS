import Foundation
import UIKit
import UserNotifications
import Intents
import AVFAudio
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData

/// Keeps opted-in Telegram accounts connected while the app is backgrounded
/// and turns incoming AccountStateManager events into local notifications.
///
/// This intentionally does not poll Telegram and does not download media. The
/// account state manager already receives the normal MTProto updates; the
/// manager only adds a local-notification projection for those updates.
public final class MellowsgramBackgroundNotificationManager {
    private let presentationData: () -> PresentationData?
    private let activeAccountsDisposable = MetaDisposable()
    private let inForegroundDisposable = MetaDisposable()
    private let hasActiveAudioSessionDisposable = MetaDisposable()

    private var accountNotificationDisposables: [AccountRecordId: Disposable] = [:]
    private var accountSettingsDisposables: [AccountRecordId: Disposable] = [:]
    private var accounts: [AccountRecordId: Account] = [:]
    private var engines: [AccountRecordId: TelegramEngine] = [:]
    private var settings: [AccountRecordId: MellowsgramSettings] = [:]
    private var primaryAccountId: AccountRecordId?
    private var enabledAccountIdsValue: Set<AccountRecordId> = []
    private var inForeground = true
    private var hasActiveAudioSession = false
    private var notificationsAuthorized = true

    private let enabledAccountIdsPromise = ValuePromise<Set<AccountRecordId>>([], ignoreRepeated: true)
    public var enabledAccountIds: Signal<Set<AccountRecordId>, NoError> {
        return self.enabledAccountIdsPromise.get()
    }

    private var silentAudioPlayer: AVAudioPlayer?
    private var didActivateAudioSession = false

    public init(
        activeAccounts: Signal<(primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?), NoError>,
        inForeground: Signal<Bool, NoError>,
        hasActiveAudioSession: Signal<Bool, NoError>,
        presentationData: @escaping () -> PresentationData?
    ) {
        self.presentationData = presentationData
        self.activeAccountsDisposable.set((activeAccounts
        |> deliverOnMainQueue).startStrict(next: { [weak self] activeAccounts in
            self?.updateAccounts(activeAccounts)
        }))

        self.inForegroundDisposable.set((inForeground
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let self else {
                return
            }
            self.inForeground = value
            self.updateAudioKeepAlive()
        }))

        self.hasActiveAudioSessionDisposable.set((hasActiveAudioSession
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let self else {
                return
            }
            self.hasActiveAudioSession = value
            self.updateAudioKeepAlive()
        }))
    }

    deinit {
        self.activeAccountsDisposable.dispose()
        self.inForegroundDisposable.dispose()
        self.hasActiveAudioSessionDisposable.dispose()
        for disposable in self.accountNotificationDisposables.values {
            disposable.dispose()
        }
        for disposable in self.accountSettingsDisposables.values {
            disposable.dispose()
        }
        self.stopAudioKeepAlive()
    }

    private func updateAccounts(_ activeAccounts: (primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?)) {
        let updatedAccounts = Dictionary(uniqueKeysWithValues: activeAccounts.accounts.map { ($0.0, $0.1.account) })
        let updatedEngines = Dictionary(uniqueKeysWithValues: activeAccounts.accounts.map { ($0.0, $0.1.engine) })
        let removedIds = Set(self.accounts.keys).subtracting(updatedAccounts.keys)

        for accountId in removedIds {
            self.accountNotificationDisposables.removeValue(forKey: accountId)?.dispose()
            self.accountSettingsDisposables.removeValue(forKey: accountId)?.dispose()
            self.settings.removeValue(forKey: accountId)
            self.engines.removeValue(forKey: accountId)
        }

        self.accounts = updatedAccounts
        self.engines = updatedEngines
        self.primaryAccountId = activeAccounts.primary?.account.id

        for (accountId, account) in updatedAccounts {
            if self.accountSettingsDisposables[accountId] == nil {
                self.accountSettingsDisposables[accountId] = (account.mellowsgramSettingsSignal
                |> deliverOnMainQueue).startStrict(next: { [weak self] settings in
                    guard let self else {
                        return
                    }
                    self.settings[accountId] = settings
                    if settings.backgroundNotificationsEnabled {
                        self.requestNotificationAuthorization()
                    }
                    self.updateEnabledAccountIds()
                })
            }

            if self.accountNotificationDisposables[accountId] == nil {
                self.accountNotificationDisposables[accountId] = (account.stateManager.notificationMessages
                |> deliverOnMainQueue).startStrict(next: { [weak self] messageList in
                    self?.handle(messageList, accountId: accountId)
                })
            }
        }

        self.updateEnabledAccountIds()
    }

    private func updateEnabledAccountIds() {
        var enabled = Set<AccountRecordId>()
        let accountsWithNotificationsEnabled = self.settings.filter { $0.value.backgroundNotificationsEnabled }
        if accountsWithNotificationsEnabled.values.contains(where: { $0.backgroundNotificationsAllAccounts }) {
            // The all-accounts option is an override: every signed-in account
            // receives updates even when its own per-account toggle is off.
            enabled = Set(self.accounts.keys)
        } else if let primaryAccountId = self.primaryAccountId,
                  self.settings[primaryAccountId]?.backgroundNotificationsEnabled == true {
            enabled.insert(primaryAccountId)
        }
        self.enabledAccountIdsValue = enabled
        self.enabledAccountIdsPromise.set(self.notificationsAuthorized ? enabled : [])
        self.updateAudioKeepAlive()
    }

    private func handle(_ messageList: [([EngineRawMessage], EnginePeerGroupId, Bool, EngineMessageHistoryThreadData?)], accountId: AccountRecordId) {
        guard !self.inForeground, self.notificationsAuthorized, self.enabledAccountIdsValue.contains(accountId) else {
            return
        }

        for (messages, _, notify, _) in messageList {
            guard notify, let message = messages.last ?? messages.first else {
                continue
            }

            // Secret chats and ephemeral content must keep their privacy
            // semantics; they are not projected into local notifications.
            if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                continue
            }
            if message.attributes.contains(where: { attribute in
                return attribute is EphemeralMessageAttribute || attribute is EphemeralOutgoingMessageAttribute
            }) {
                continue
            }

            let presentationData = self.presentationData()
            let chatPeer = message.peers[message.id.peerId]
            let senderPeer = message.effectiveAuthor ?? chatPeer
            let chatTitle = chatPeer.flatMap { peer in
                presentationData.map { EnginePeer(peer).displayTitle(strings: $0.strings, displayOrder: $0.nameDisplayOrder) }
            } ?? "Mellowsgram"
            let senderTitle = senderPeer.flatMap { peer in
                presentationData.map { EnginePeer(peer).displayTitle(strings: $0.strings, displayOrder: $0.nameDisplayOrder) }
            } ?? chatTitle

            let body: String
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                body = text
            } else if message.media.contains(where: { $0 is TelegramMediaImage }) {
                body = "Фото"
            } else if message.media.contains(where: { $0 is TelegramMediaFile }) {
                body = "Медиафайл"
            } else if message.media.contains(where: { $0 is TelegramMediaWebpage }) {
                body = "Ссылка"
            } else {
                body = "Новое сообщение"
            }

            var notificationContent = UNMutableNotificationContent()
            notificationContent.title = senderTitle
            notificationContent.body = messages.count > 1 ? "\(messages.count) новых сообщений" : body
            notificationContent.sound = .default
            notificationContent.threadIdentifier = "mellowsgram-\(accountId.int64)-\(message.id.peerId.toInt64())"
            notificationContent.userInfo = [
                "accountId": accountId.int64,
                "peerId": message.id.peerId.toInt64(),
                "messageId.namespace": message.id.namespace,
                "messageId.id": message.id.id
            ]

            if #available(iOS 15.0, *), let senderPeer, let engine = self.engines[accountId] {
                let representation = smallestImageRepresentation(senderPeer.profileImageRepresentations)
                let senderImage = mellowsgramNotificationAvatar(
                    resourcePath: representation.map { engine.resources.resourcePath(resource: EngineMediaResource($0.resource)) },
                    resourceId: representation?.resource.id.stringRepresentation,
                    peer: senderPeer
                )
                var personNameComponents = PersonNameComponents()
                personNameComponents.nickname = senderTitle
                let sender = INPerson(
                    personHandle: INPersonHandle(value: "\(senderPeer.id.toInt64())", type: .unknown),
                    nameComponents: personNameComponents,
                    displayName: senderTitle,
                    image: senderImage,
                    contactIdentifier: nil,
                    customIdentifier: "\(senderPeer.id.toInt64())",
                    isMe: false,
                    suggestionType: .none
                )
                let recipient = INPerson(
                    personHandle: INPersonHandle(value: "0", type: .unknown),
                    nameComponents: nil,
                    displayName: nil,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: nil,
                    isMe: true,
                    suggestionType: .none
                )
                let intent = INSendMessageIntent(
                    recipients: [recipient],
                    outgoingMessageType: .outgoingMessageText,
                    content: notificationContent.body,
                    speakableGroupName: INSpeakableString(spokenPhrase: chatTitle),
                    conversationIdentifier: "\(message.id.peerId.toInt64())",
                    serviceName: nil,
                    sender: sender,
                    attachments: nil
                )
                if let senderImage {
                    intent.setImage(senderImage, forParameterNamed: \.sender)
                }
                do {
                    if let updatedContent = try notificationContent.updating(from: intent) as? UNMutableNotificationContent {
                        notificationContent = updatedContent
                    }
                } catch {
                    // A plain local notification remains usable if iOS declines
                    // to apply the optional Siri messaging presentation.
                }
            }

            let identifier = "mellowsgram-\(accountId.int64)-\(message.id.peerId.toInt64())-\(message.id.id)"
            let request = UNNotificationRequest(identifier: identifier, content: notificationContent, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    private func updateAudioKeepAlive() {
        let shouldKeepAlive = !self.inForeground && !self.hasActiveAudioSession && self.notificationsAuthorized && !self.enabledAccountIdsValue.isEmpty
        if shouldKeepAlive {
            self.startAudioKeepAliveIfNeeded()
        } else {
            self.stopAudioKeepAlive()
        }
    }

    private func startAudioKeepAliveIfNeeded() {
        guard self.silentAudioPlayer == nil else {
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            guard let player = try? AVAudioPlayer(data: Self.silentAudioData()) else {
                try? session.setActive(false, options: [.notifyOthersOnDeactivation])
                return
            }
            player.numberOfLoops = -1
            player.volume = 0.0
            player.prepareToPlay()
            if player.play() {
                self.didActivateAudioSession = true
                self.silentAudioPlayer = player
            } else {
                try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            }
        } catch {
            self.didActivateAudioSession = false
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
            self?.refreshNotificationAuthorization()
        }
        self.refreshNotificationAuthorization()
    }

    private func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let isAuthorized = settings.authorizationStatus != .denied
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.notificationsAuthorized = isAuthorized
                self.updateEnabledAccountIds()
            }
        }
    }

    private func stopAudioKeepAlive() {
        self.silentAudioPlayer?.stop()
        self.silentAudioPlayer = nil
        if self.didActivateAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            self.didActivateAudioSession = false
        }
    }

    private static func silentAudioData() -> Data {
        let sampleRate: UInt32 = 8_000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)

        var bytes = Array("RIFF".utf8)
        func appendUInt32(_ value: UInt32) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes.append(contentsOf: $0) }
        }
        func appendUInt16(_ value: UInt16) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes.append(contentsOf: $0) }
        }

        appendUInt32(36 + dataSize)
        bytes.append(contentsOf: Array("WAVE".utf8))
        bytes.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(channels)
        appendUInt32(sampleRate)
        appendUInt32(byteRate)
        appendUInt16(blockAlign)
        appendUInt16(bitsPerSample)
        bytes.append(contentsOf: Array("data".utf8))
        appendUInt32(dataSize)
        bytes.append(contentsOf: repeatElement(UInt8(0), count: Int(dataSize)))
        return Data(bytes)
    }
}

@available(iOS 15.0, *)
private func mellowsgramNotificationAvatar(resourcePath: String?, resourceId: String?, peer: Peer) -> INImage? {
    if let resourcePath,
       let resourceId,
       FileManager.default.fileExists(atPath: resourcePath) {
        let sourceUrl = URL(fileURLWithPath: resourcePath)
        let ext = sourceUrl.pathExtension.isEmpty ? "jpg" : sourceUrl.pathExtension
        let cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MellowsgramNotificationAvatars", isDirectory: true)
        let resourceKey = resourceId.persistentHashValue
        let destination = cacheDirectory.appendingPathComponent("\(peer.id.toInt64())-\(resourceKey).\(ext)")
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: sourceUrl, to: destination)
            }
            return INImage(url: destination)
        } catch {
            // Fall through to a generated initials avatar.
        }
    }

    let letters = peer.displayLetters.joined().isEmpty ? "?" : peer.displayLetters.joined()
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64.0, height: 64.0))
    let image = renderer.image { context in
        UIColor(rgb: 0x4A90E2).setFill()
        context.cgContext.fillEllipse(in: CGRect(x: 0.0, y: 0.0, width: 64.0, height: 64.0))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Font.medium(24.0),
            .foregroundColor: UIColor.white
        ]
        let text = NSAttributedString(string: letters, attributes: attributes)
        let textSize = text.size()
        text.draw(at: CGPoint(x: floor((64.0 - textSize.width) / 2.0), y: floor((64.0 - textSize.height) / 2.0)))
    }
    guard let data = image.pngData() else {
        return nil
    }
    return INImage(imageData: data)
}
