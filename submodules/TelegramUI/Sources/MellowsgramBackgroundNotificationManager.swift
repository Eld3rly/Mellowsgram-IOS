import Foundation
import UIKit
import UserNotifications
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
        let removedIds = Set(self.accounts.keys).subtracting(updatedAccounts.keys)

        for accountId in removedIds {
            self.accountNotificationDisposables.removeValue(forKey: accountId)?.dispose()
            self.accountSettingsDisposables.removeValue(forKey: accountId)?.dispose()
            self.settings.removeValue(forKey: accountId)
        }

        self.accounts = updatedAccounts
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

            let peerTitle: String
            if let peer = message.peers[message.id.peerId], let presentationData = self.presentationData() {
                peerTitle = EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
            } else {
                peerTitle = "Mellowsgram"
            }

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

            let notificationContent = UNMutableNotificationContent()
            notificationContent.title = peerTitle
            notificationContent.body = messages.count > 1 ? "\(messages.count) новых сообщений" : body
            notificationContent.sound = .default
            notificationContent.threadIdentifier = "mellowsgram-\(accountId.int64)-\(message.id.peerId.toInt64())"
            notificationContent.userInfo = [
                "accountId": accountId.int64,
                "peerId": message.id.peerId.toInt64(),
                "messageId.namespace": message.id.namespace,
                "messageId.id": message.id.id
            ]

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
