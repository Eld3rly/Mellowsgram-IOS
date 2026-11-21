import Foundation
import CryptoKit
import Security
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences

private func mellowsgramThenAfterCompletion<T>(_ signal: Signal<Never, NoError>, _ nextSignal: Signal<T, NoError>) -> Signal<T, NoError> {
    return Signal { subscriber in
        let disposableSet = DisposableSet()
        disposableSet.add(signal.start(completed: {
            disposableSet.add(nextSignal.start(next: { value in
                subscriber.putNext(value)
            }, completed: {
                subscriber.putCompletion()
            }))
        }))
        return disposableSet
    }
}

/// Registers Telegram Web Push tokens for the Bark relay. While foregrounded,
/// it uploads small avatar thumbnails already present in MediaBox; it never
/// fetches avatars just for this feature or keeps an account connection alive.
/// It does not create local message notifications.
public final class MellowsgramBarkNotificationManager {
    private static let relayBaseURL = "https://push.mellowsgram.cc"
    private static let registrationDebounce: Double = 0.8
    private static let registrationRetryDelay: Double = 30.0
    private static let registrationRefreshInterval: Double = 23.0 * 60.0 * 60.0
    private static let foregroundPresenceInterval: Double = 30.0
    private static let avatarRefreshInterval: Double = 10.0 * 60.0
    private static let avatarUploadRefreshInterval: TimeInterval = 25.0 * 24.0 * 60.0 * 60.0
    private static let maxAvatarPeersPerSync = 300
    private static let avatarThumbnailSide: CGFloat = 96.0
    private static let foregroundPresenceHeader = "mellowsgram-ios-foreground-v1"
    private static let registrationClientHeader = "mellowsgram-ios-registration-v1"
    private static let registrationSubscriptionHeader = "X-Mellowsgram-Subscription"
    private static let registrationTimestampHeader = "X-Mellowsgram-Timestamp"
    private static let registrationSignatureHeader = "X-Mellowsgram-Signature"
    private static let avatarSubscriptionHeader = "X-Mellowsgram-Subscription"
    private static let avatarPeerIdHeader = "X-Mellowsgram-Peer"

    private struct WebPushToken: Codable {
        struct Keys: Codable {
            let p256dh: String
            let auth: String
        }

        let endpoint: String
        let keys: Keys
    }

    private struct UploadedAvatarState: Codable {
        let digest: String
        let timestamp: TimeInterval
    }

    private let activeAccountsDisposable = MetaDisposable()
    private let settingsDisposable = MetaDisposable()
    private let deviceKeyDisposable = MetaDisposable()
    private let reconcileDisposable = MetaDisposable()
    private let avatarScanDisposable = MetaDisposable()
    private let avatarImageProcessingQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "MellowsgramAvatarThumbnailProcessing"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 2
        return queue
    }()

    private var accounts: [AccountRecordId: AccountContext] = [:]
    private var removedAccounts: [AccountRecordId: AccountContext] = [:]
    private var primaryAccountId: AccountRecordId?
    private var globalSettings = MellowsgramGlobalSettings.defaultSettings
    private var hasLoadedSettings = false
    private var registeredTokens: [AccountRecordId: Data] = [:]
    private var reconcileTimer: SwiftSignalKit.Timer?
    private var registrationRefreshTimer: SwiftSignalKit.Timer?
    private var foregroundPresenceTimer: SwiftSignalKit.Timer?
    private var avatarRefreshTimer: SwiftSignalKit.Timer?
    private var foregroundPresenceURL: URL?
    private var foregroundPresenceAuthSecret: Data?
    private var avatarSubscriptionRoute: String?
    private var avatarAuthSecret: Data?
    private var avatarUploadTasks: [UUID: URLSessionUploadTask] = [:]
    private var avatarUploadStateStorageKey: String?
    private var avatarUploadStatePersistenceWorkItem: DispatchWorkItem?
    private var uploadedAvatarStates: [String: UploadedAvatarState] = [:]
    private var pendingAvatarPeerIds = Set<Int64>()
    private var lastAvatarScanTimestamp: TimeInterval = 0.0
    private var remainingAvatarPeerBudget = 0
    private var isAppForeground = UIApplication.shared.applicationState == .active
    private var lifecycleObservers: [NSObjectProtocol] = []

    public init(
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        activeAccounts: Signal<(primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?), NoError>
    ) {
        Self.removeLegacyLocalNotifications()
        MellowsgramBadgeRuntime.shared.refresh()

        self.activeAccountsDisposable.set((activeAccounts
        |> deliverOnMainQueue).startStrict(next: { [weak self] activeAccounts in
            self?.updateAccounts(activeAccounts)
        }))

        self.settingsDisposable.set((mellowsgramGlobalSettings(accountManager: accountManager)
        |> deliverOnMainQueue).startStrict(next: { [weak self] settings in
            guard let self else {
                return
            }
            self.globalSettings = settings
            self.hasLoadedSettings = true
            self.lastAvatarScanTimestamp = 0.0
            self.scheduleReconcile()
        }))

        self.deviceKeyDisposable.set((MellowsgramBarkCredentialStore.deviceKeySignal
        |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
            self?.scheduleReconcile()
        }))

        let notificationCenter = NotificationCenter.default
        self.lifecycleObservers = [
            notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main, using: { [weak self] _ in
                self?.updateAppForeground(true)
            }),
            notificationCenter.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main, using: { [weak self] _ in
                self?.updateAppForeground(false)
            })
        ]
    }

    deinit {
        self.activeAccountsDisposable.dispose()
        self.settingsDisposable.dispose()
        self.deviceKeyDisposable.dispose()
        self.reconcileDisposable.dispose()
        self.avatarScanDisposable.dispose()
        self.avatarImageProcessingQueue.cancelAllOperations()
        self.avatarUploadStatePersistenceWorkItem?.cancel()
        self.reconcileTimer?.invalidate()
        self.registrationRefreshTimer?.invalidate()
        self.foregroundPresenceTimer?.invalidate()
        self.avatarRefreshTimer?.invalidate()
        for task in self.avatarUploadTasks.values {
            task.cancel()
        }
        for observer in self.lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func updateAccounts(_ activeAccounts: (primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?)) {
        let updatedAccounts = Dictionary(uniqueKeysWithValues: activeAccounts.accounts.map { ($0.0, $0.1) })
        let removedIds = Set(self.accounts.keys).subtracting(updatedAccounts.keys)
        for accountId in removedIds {
            if let context = self.accounts[accountId] {
                self.removedAccounts[accountId] = context
            }
        }
        self.accounts = updatedAccounts
        self.primaryAccountId = activeAccounts.primary?.account.id
        self.lastAvatarScanTimestamp = 0.0
        self.scheduleReconcile()
    }

    private func scheduleReconcile() {
        self.scheduleReconcile(after: Self.registrationDebounce)
    }

    private func scheduleReconcile(after delay: Double) {
        guard self.hasLoadedSettings else {
            return
        }
        self.reconcileTimer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: { [weak self] in
            self?.reconcile()
        }, queue: .mainQueue())
        self.reconcileTimer = timer
        timer.start()
    }

    private func reconcile() {
        let storedRegistration = MellowsgramBarkCredentialStore.registration
        let barkKey = MellowsgramBarkCredentialStore.deviceKey
        let notificationsEnabled = self.globalSettings.bool(for: .barkNotificationsEnabled) && !barkKey.isEmpty
        if !notificationsEnabled {
            self.registrationRefreshTimer?.invalidate()
            self.registrationRefreshTimer = nil
        }
        var desiredAccountIds = Set<AccountRecordId>()
        if notificationsEnabled {
            if self.globalSettings.bool(for: .barkAllAccounts) {
                desiredAccountIds = Set(self.accounts.keys)
            } else if let primaryAccountId = self.primaryAccountId, self.accounts[primaryAccountId] != nil {
                desiredAccountIds.insert(primaryAccountId)
            }
        }

        let token: Data?
        if notificationsEnabled {
            if let storedRegistration, storedRegistration.barkDeviceKey == barkKey {
                token = storedRegistration.token
            } else {
                token = Self.makeWebPushToken(barkKey: barkKey)
            }
        } else {
            token = nil
        }

        if let storedRegistration, let token, storedRegistration.token != token {
            self.updateRelayClientRegistration(active: false, token: storedRegistration.token)
        }

        if notificationsEnabled && token == nil {
            self.scheduleReconcile(after: Self.registrationRetryDelay)
            return
        }
        self.updateForegroundPresenceToken(token)

        var contexts = self.accounts
        contexts.merge(self.removedAccounts) { current, _ in current }
        let storedIds = Set(storedRegistration?.registeredAccountIds ?? [])
        let allIds = Set(contexts.keys).union(self.registeredTokens.keys)
        var operations: [Signal<(AccountRecordId, Data?), NoError>] = []

        for accountId in allIds {
            guard let context = contexts[accountId] else {
                continue
            }
            let oldToken = self.registeredTokens[accountId] ?? (storedIds.contains(accountId.int64) ? storedRegistration?.token : nil)
            let shouldRegister = desiredAccountIds.contains(accountId)
            if shouldRegister, let token {
                if self.registeredTokens[accountId] == token {
                    operations.append(.single((accountId, token)))
                } else {
                    let registerOperation = context.engine.accountData.registerNotificationToken(token: token, type: .webPush, sandbox: false, otherAccountUserIds: [], excludeMutedChats: true)
                    |> map { registered -> (AccountRecordId, Data?) in
                        return (accountId, registered ? token : nil)
                    }
                    if let oldToken, oldToken != token {
                        let unregisterOperation = context.engine.accountData.unregisterNotificationToken(token: oldToken, type: .webPush, otherAccountUserIds: [])
                        operations.append(mellowsgramThenAfterCompletion(unregisterOperation, registerOperation))
                    } else {
                        operations.append(registerOperation)
                    }
                }
            } else if let oldToken {
                let unregisterOperation = context.engine.accountData.unregisterNotificationToken(token: oldToken, type: .webPush, otherAccountUserIds: [])
                operations.append(mellowsgramThenAfterCompletion(unregisterOperation, .single((accountId, nil))))
            } else {
                operations.append(.single((accountId, nil)))
            }
        }

        let operationSignal: Signal<[(AccountRecordId, Data?)], NoError>
        if operations.isEmpty {
            operationSignal = .single([])
        } else {
            operationSignal = combineLatest(operations)
        }

        self.reconcileDisposable.set((operationSignal
        |> deliverOnMainQueue).startStrict(next: { [weak self] results in
            guard let self else {
                return
            }
            let shouldRetry = notificationsEnabled && results.contains(where: { result in
                return desiredAccountIds.contains(result.0) && result.1 == nil
            })
            for (accountId, token) in results {
                if let token {
                    self.registeredTokens[accountId] = token
                } else {
                    self.registeredTokens.removeValue(forKey: accountId)
                }
                self.removedAccounts.removeValue(forKey: accountId)
            }

            guard let token else {
                self.stopAvatarSync()
                if let storedRegistration {
                    self.updateRelayClientRegistration(active: false, token: storedRegistration.token)
                    let remainingIds = self.registeredTokens
                        .compactMap { entry -> Int64? in
                            entry.value == storedRegistration.token ? entry.key.int64 : nil
                        }
                        .sorted()
                    _ = MellowsgramBarkCredentialStore.updateRegistration(MellowsgramBarkStoredRegistration(
                        barkDeviceKey: storedRegistration.barkDeviceKey,
                        token: storedRegistration.token,
                        registeredAccountIds: remainingIds
                    ))
                }
                return
            }

            let registeredIds = self.registeredTokens
                .compactMap { entry -> Int64? in
                    entry.value == token ? entry.key.int64 : nil
                }
                .sorted()
            self.updateRelayClientRegistration(active: !registeredIds.isEmpty, token: token)
            _ = MellowsgramBarkCredentialStore.updateRegistration(MellowsgramBarkStoredRegistration(
                barkDeviceKey: barkKey,
                token: token,
                registeredAccountIds: registeredIds
            ))
            if shouldRetry {
                self.scheduleReconcile(after: Self.registrationRetryDelay)
            } else if !registeredIds.isEmpty {
                self.scheduleRegistrationRefresh()
            }
            if self.isAppForeground {
                self.syncAvatarCache()
                self.startAvatarRefreshTimer()
            } else {
                self.stopAvatarSync()
            }
        }))
    }

    private func scheduleRegistrationRefresh() {
        guard self.registrationRefreshTimer == nil else {
            return
        }
        let timer = SwiftSignalKit.Timer(timeout: Self.registrationRefreshInterval, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.registrationRefreshTimer = nil
            self.registeredTokens.removeAll()
            self.scheduleReconcile()
        }, queue: .mainQueue())
        self.registrationRefreshTimer = timer
        timer.start()
    }

    private func updateForegroundPresenceToken(_ token: Data?) {
        let relayCredentials = token.flatMap { Self.makeRelayCredentials(token: $0) }
        let updatedURL = token.flatMap { Self.makeForegroundPresenceURL(token: $0) }
        let previousAuthSecret = self.foregroundPresenceAuthSecret
        if self.avatarSubscriptionRoute != relayCredentials?.route {
            self.stopAvatarSync()
            self.avatarUploadStatePersistenceWorkItem?.cancel()
            self.avatarUploadStatePersistenceWorkItem = nil
            self.uploadedAvatarStates.removeAll()
            self.avatarUploadStateStorageKey = relayCredentials.map { Self.avatarUploadStateStorageKey(for: $0.route) }
            if let storageKey = self.avatarUploadStateStorageKey,
               let data = UserDefaults.standard.data(forKey: storageKey),
               let states = try? JSONDecoder().decode([String: UploadedAvatarState].self, from: data) {
                self.uploadedAvatarStates = states
            }
        }
        self.avatarSubscriptionRoute = relayCredentials?.route
        self.avatarAuthSecret = relayCredentials?.authSecret
        guard self.foregroundPresenceURL?.absoluteString != updatedURL?.absoluteString else {
            self.foregroundPresenceAuthSecret = relayCredentials?.authSecret
            return
        }
        if let currentURL = self.foregroundPresenceURL {
            self.sendForegroundPresence(active: false, to: currentURL, authSecret: previousAuthSecret)
        }
        self.foregroundPresenceURL = updatedURL
        self.foregroundPresenceAuthSecret = relayCredentials?.authSecret
        if self.isAppForeground {
            self.sendForegroundPresence(active: true)
            self.startForegroundPresenceTimer()
            self.syncAvatarCache()
            self.startAvatarRefreshTimer()
        } else {
            self.foregroundPresenceTimer?.invalidate()
            self.foregroundPresenceTimer = nil
            self.stopAvatarSync()
        }
    }

    private func updateAppForeground(_ value: Bool) {
        self.isAppForeground = value
        self.foregroundPresenceTimer?.invalidate()
        self.foregroundPresenceTimer = nil
        self.sendForegroundPresence(active: value)
        if value {
            MellowsgramBadgeRuntime.shared.refresh()
            self.startForegroundPresenceTimer()
            self.syncAvatarCache()
            self.startAvatarRefreshTimer()
        } else {
            self.stopAvatarSync()
        }
    }

    private func startAvatarRefreshTimer() {
        guard self.isAppForeground, self.avatarSubscriptionRoute != nil, self.avatarRefreshTimer == nil else {
            return
        }
        let timer = SwiftSignalKit.Timer(timeout: Self.avatarRefreshInterval, repeat: true, completion: { [weak self] in
            self?.syncAvatarCache()
        }, queue: .mainQueue())
        self.avatarRefreshTimer = timer
        timer.start()
    }

    private func stopAvatarSync() {
        self.avatarRefreshTimer?.invalidate()
        self.avatarRefreshTimer = nil
        self.lastAvatarScanTimestamp = 0.0
        self.avatarScanDisposable.set(nil)
        self.avatarImageProcessingQueue.cancelAllOperations()
        for task in self.avatarUploadTasks.values {
            task.cancel()
        }
        self.avatarUploadTasks.removeAll()
        self.pendingAvatarPeerIds.removeAll()
    }

    private func syncAvatarCache() {
        guard self.isAppForeground,
              self.globalSettings.bool(for: .barkNotificationsEnabled),
              let route = self.avatarSubscriptionRoute,
              let authSecret = self.avatarAuthSecret,
              !MellowsgramBarkCredentialStore.deviceKey.isEmpty
        else {
            self.stopAvatarSync()
            return
        }

        let selectedContexts: [AccountContext]
        if self.globalSettings.bool(for: .barkAllAccounts) {
            selectedContexts = self.accounts.keys.sorted { $0.int64 < $1.int64 }.compactMap { self.accounts[$0] }
        } else if let primaryAccountId = self.primaryAccountId, let context = self.accounts[primaryAccountId] {
            selectedContexts = [context]
        } else {
            selectedContexts = []
        }
        guard !selectedContexts.isEmpty else {
            self.stopAvatarSync()
            return
        }
        let now = Date.timeIntervalSinceReferenceDate
        guard now - self.lastAvatarScanTimestamp >= 60.0 else {
            return
        }
        self.lastAvatarScanTimestamp = now

        let scanDisposables = DisposableSet()
        self.avatarScanDisposable.set(scanDisposables)
        self.remainingAvatarPeerBudget = Self.maxAvatarPeersPerSync

        for context in selectedContexts {
            for group in [EngineChatList.Group.root, .archive] {
                let listSignal = context.engine.messages.chatList(group: group, count: 100)
                scanDisposables.add((listSignal
                |> take(1)
                |> deliverOnMainQueue).startStrict(next: { [weak self] chatList in
                    guard let self,
                          self.isAppForeground,
                          self.avatarSubscriptionRoute == route
                    else {
                        return
                    }
                    let peers = Self.avatarCandidates(from: chatList)
                    let ownPeerId = context.account.peerId
                    for peer in peers {
                        guard self.remainingAvatarPeerBudget > 0 else {
                            break
                        }
                        guard case .user = peer,
                              let peerId = Self.userPeerIdValue(peer),
                              peer.id != ownPeerId,
                              !self.pendingAvatarPeerIds.contains(peerId),
                              let representation = peer.smallProfileImage
                        else {
                            continue
                        }
                        self.pendingAvatarPeerIds.insert(peerId)
                        self.remainingAvatarPeerBudget -= 1

                        let dataSignal = context.engine.resources.data(
                            resource: EngineMediaResource(representation.resource),
                            waitUntilFetchStatus: false,
                            attemptSynchronously: false
                        )
                        scanDisposables.add((dataSignal
                        |> take(1)
                        |> deliverOnMainQueue).startStrict(next: { [weak self] resourceData in
                            guard let self,
                                  self.isAppForeground,
                                  self.avatarSubscriptionRoute == route,
                                  resourceData.isComplete
                            else {
                                self?.clearPendingAvatar(peerId, route: route)
                                return
                            }
                            self.avatarImageProcessingQueue.addOperation { [weak self] in
                                guard let imageData = Self.makeAvatarThumbnail(path: resourceData.path) else {
                                    DispatchQueue.main.async {
                                        self?.clearPendingAvatar(peerId, route: route)
                                    }
                                    return
                                }
                                let digest = Self.sha256(imageData)
                                DispatchQueue.main.async {
                                    guard let self,
                                          self.isAppForeground,
                                          self.avatarSubscriptionRoute == route
                                    else {
                                        self?.clearPendingAvatar(peerId, route: route)
                                        return
                                    }
                                    let now = Date.timeIntervalSinceReferenceDate
                                    let peerStateKey = Self.avatarStatePeerKey(peerId)
                                    if let previous = self.uploadedAvatarStates[peerStateKey],
                                       previous.digest == digest,
                                       now - previous.timestamp < Self.avatarUploadRefreshInterval {
                                        self.pendingAvatarPeerIds.remove(peerId)
                                        return
                                    }
                                    self.uploadAvatar(imageData, digest: digest, peerId: peerId, route: route, authSecret: authSecret)
                                }
                            }
                        }))
                    }
                }))
            }
        }
    }

    private func uploadAvatar(_ imageData: Data, digest: String, peerId: Int64, route: String, authSecret: Data) {
        guard self.isAppForeground,
              self.avatarSubscriptionRoute == route,
              let url = Self.makeAvatarUploadURL()
        else {
            self.clearPendingAvatar(peerId, route: route)
            return
        }

        let signedValue = "mellowsgram-avatar-v1\n\(peerId)\n\(digest)"
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(signedValue.utf8),
            using: SymmetricKey(data: authSecret)
        )
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.foregroundPresenceHeader, forHTTPHeaderField: "X-Mellowsgram-Client")
        request.setValue(route, forHTTPHeaderField: Self.avatarSubscriptionHeader)
        request.setValue(String(peerId), forHTTPHeaderField: Self.avatarPeerIdHeader)
        request.setValue(Data(signature).map { String(format: "%02x", $0) }.joined(), forHTTPHeaderField: "X-Mellowsgram-Signature")

        let uploadId = UUID()
        let task = URLSession.shared.uploadTask(with: request, from: imageData) { [weak self] _, response, _ in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.avatarUploadTasks.removeValue(forKey: uploadId)
                guard self.avatarSubscriptionRoute == route else {
                    return
                }
                self.pendingAvatarPeerIds.remove(peerId)
                guard self.isAppForeground,
                      let response = response as? HTTPURLResponse,
                      response.statusCode == 204
                else {
                    return
                }
                self.uploadedAvatarStates[Self.avatarStatePeerKey(peerId)] = UploadedAvatarState(digest: digest, timestamp: Date.timeIntervalSinceReferenceDate)
                if self.uploadedAvatarStates.count > Self.maxAvatarPeersPerSync {
                    let excess = self.uploadedAvatarStates.count - Self.maxAvatarPeersPerSync
                    let oldestKeys = self.uploadedAvatarStates
                        .sorted { $0.value.timestamp < $1.value.timestamp }
                        .prefix(excess)
                        .map(\.key)
                    for key in oldestKeys {
                        self.uploadedAvatarStates.removeValue(forKey: key)
                    }
                }
                self.schedulePersistAvatarUploadStates()
            }
        }
        self.avatarUploadTasks[uploadId] = task
        task.resume()
    }

    private func clearPendingAvatar(_ peerId: Int64, route: String) {
        guard self.avatarSubscriptionRoute == route else {
            return
        }
        self.pendingAvatarPeerIds.remove(peerId)
    }

    private func schedulePersistAvatarUploadStates() {
        guard let storageKey = self.avatarUploadStateStorageKey else {
            return
        }
        self.avatarUploadStatePersistenceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.avatarUploadStateStorageKey == storageKey,
                  let data = try? JSONEncoder().encode(self.uploadedAvatarStates)
            else {
                return
            }
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        self.avatarUploadStatePersistenceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }

    private static func avatarCandidates(from chatList: EngineChatList) -> [EnginePeer] {
        var result: [EnginePeer] = []
        var seen = Set<Int64>()

        func append(_ peer: EnginePeer?) {
            guard let peer,
                  case .user = peer,
                  let peerId = Self.userPeerIdValue(peer),
                  seen.insert(peerId).inserted
            else {
                return
            }
            result.append(peer)
        }

        for item in chatList.items {
            for message in item.messages {
                append(message.author)
            }
            append(item.renderedPeer.peer)
            for peerId in item.renderedPeer.peers.keys.sorted() {
                append(item.renderedPeer.peers[peerId])
            }
        }
        for groupItem in chatList.groupItems {
            append(groupItem.topMessage?.author)
            for item in groupItem.items {
                append(item.peer.peer)
            }
        }
        return result
    }

    private static func userPeerIdValue(_ peer: EnginePeer) -> Int64? {
        guard case .user = peer else {
            return nil
        }
        let value = peer.id.id._internalGetInt64Value()
        return value > 0 ? value : nil
    }

    private static func makeAvatarThumbnail(path: String) -> Data? {
        guard let source = UIImage(contentsOfFile: path), source.size.width > 0.0, source.size.height > 0.0 else {
            return nil
        }
        let size = CGSize(width: Self.avatarThumbnailSide, height: Self.avatarThumbnailSide)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let thumbnail = renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            let scale = max(size.width / source.size.width, size.height / source.size.height)
            let drawSize = CGSize(width: source.size.width * scale, height: source.size.height * scale)
            let drawRect = CGRect(x: (size.width - drawSize.width) * 0.5, y: (size.height - drawSize.height) * 0.5, width: drawSize.width, height: drawSize.height)
            source.draw(in: drawRect)
        }
        for quality: CGFloat in [0.72, 0.58, 0.42] {
            if let data = thumbnail.jpegData(compressionQuality: quality), data.count <= 12 * 1024 {
                return data
            }
        }
        return nil
    }

    private static func sha256(_ data: Data) -> String {
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func avatarStatePeerKey(_ peerId: Int64) -> String {
        return Self.sha256(Data(String(peerId).utf8))
    }

    private static func avatarUploadStateStorageKey(for route: String) -> String {
        return "mellowsgram.avatar-upload-state.\(Self.sha256(Data(route.utf8)))"
    }

    private static func makeRelayCredentials(token: Data) -> (route: String, authSecret: Data)? {
        guard let webPushToken = try? JSONDecoder().decode(WebPushToken.self, from: token),
              let endpointURL = URL(string: webPushToken.endpoint),
              endpointURL.host == "push.mellowsgram.cc"
        else {
            return nil
        }
        let pathComponents = endpointURL.path.split(separator: "/")
        guard pathComponents.count == 2,
              pathComponents[0] == "p",
              let authSecret = Self.decodeBase64URL(webPushToken.keys.auth),
              authSecret.count == 16
        else {
            return nil
        }
        return (String(pathComponents[1]), authSecret)
    }

    private static func makeAvatarUploadURL() -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "push.mellowsgram.cc"
        components.path = "/avatar"
        return components.url
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: normalized)
    }

    private func startForegroundPresenceTimer() {
        guard self.isAppForeground, self.foregroundPresenceURL != nil, self.foregroundPresenceTimer == nil else {
            return
        }
        let timer = SwiftSignalKit.Timer(timeout: Self.foregroundPresenceInterval, repeat: true, completion: { [weak self] in
            self?.sendForegroundPresence(active: true)
        }, queue: .mainQueue())
        self.foregroundPresenceTimer = timer
        timer.start()
    }

    private func sendForegroundPresence(active: Bool, to url: URL? = nil, authSecret: Data? = nil) {
        guard let url = url ?? self.foregroundPresenceURL else {
            return
        }
        let pathComponents = url.path.split(separator: "/")
        guard pathComponents.count == 2, pathComponents[0] == "presence",
              let routeComponent = pathComponents.last,
              let authSecret = authSecret ?? self.foregroundPresenceAuthSecret else {
            return
        }
        let route = String(routeComponent)
        let body = (try? JSONSerialization.data(withJSONObject: ["active": active])) ?? Data()
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000.0))
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.registrationClientHeader, forHTTPHeaderField: "X-Mellowsgram-Client")
        request.setValue(timestamp, forHTTPHeaderField: Self.registrationTimestampHeader)
        request.setValue(Self.requestSignature(method: "POST", path: "/presence/\(Self.sha256(Data(route.utf8)))", route: route, timestamp: timestamp, body: body, authSecret: authSecret), forHTTPHeaderField: Self.registrationSignatureHeader)
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }

    private func updateRelayClientRegistration(active: Bool, token: Data) {
        guard let credentials = Self.makeRelayCredentials(token: token),
              var components = URLComponents(string: Self.relayBaseURL) else {
            return
        }
        components.path = "/client/notification-registration"
        guard let url = components.url else {
            return
        }
        let method = active ? "PUT" : "DELETE"
        let body = Data()
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000.0))
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.httpMethod = method
        request.setValue(Self.registrationClientHeader, forHTTPHeaderField: "X-Mellowsgram-Client")
        request.setValue(credentials.route, forHTTPHeaderField: Self.registrationSubscriptionHeader)
        request.setValue(timestamp, forHTTPHeaderField: Self.registrationTimestampHeader)
        request.setValue(Self.requestSignature(method: method, path: "/client/notification-registration", route: credentials.route, timestamp: timestamp, body: body, authSecret: credentials.authSecret), forHTTPHeaderField: Self.registrationSignatureHeader)
        URLSession.shared.dataTask(with: request).resume()
    }

    private static func requestSignature(method: String, path: String, route: String, timestamp: String, body: Data, authSecret: Data) -> String {
        let routeHash = Self.sha256(Data(route.utf8))
        let bodyHash = Self.sha256(body)
        let message = "mellowsgram-client-request-v1\n\(method)\n\(path)\n\(routeHash)\n\(timestamp)\n\(bodyHash)"
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: authSecret))
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }

    private static func makeForegroundPresenceURL(token: Data) -> URL? {
        guard let credentials = Self.makeRelayCredentials(token: token) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "push.mellowsgram.cc"
        components.path = "/presence/\(credentials.route)"
        return components.url
    }

    private static func makeWebPushToken(barkKey: String) -> Data? {
        guard !barkKey.isEmpty else {
            return nil
        }

        let privateKey = P256.KeyAgreement.PrivateKey()
        let privateKeyData = privateKey.rawRepresentation
        let publicKeyData = privateKey.publicKey.x963Representation
        var authData = Data(count: 16)
        let randomStatus = authData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            return nil
        }

        var routeData = Data()
        routeData.append(privateKeyData)
        routeData.append(publicKeyData)
        routeData.append(authData)
        routeData.append(contentsOf: barkKey.utf8)

        let endpoint = "\(Self.relayBaseURL)/p/\(Self.base64URL(routeData))"
        let token = WebPushToken(
            endpoint: endpoint,
            keys: WebPushToken.Keys(
                p256dh: Self.base64URL(publicKeyData),
                auth: Self.base64URL(authData)
            )
        )
        guard let json = try? JSONEncoder().encode(token) else {
            return nil
        }
        return json
    }

    private static func removeLegacyLocalNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("mellowsgram-") }
            if !identifiers.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
        center.getDeliveredNotifications { notifications in
            let identifiers = notifications
                .map { $0.request.identifier }
                .filter { $0.hasPrefix("mellowsgram-") }
            if !identifiers.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }

    private static func base64URL(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
