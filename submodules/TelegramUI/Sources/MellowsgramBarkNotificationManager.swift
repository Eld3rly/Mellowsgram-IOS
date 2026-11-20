import Foundation
import CryptoKit
import Security
import UIKit
import UserNotifications
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences

/// Registers Telegram Web Push tokens for the Bark relay. It never keeps an
/// account connection alive and does not create local message notifications.
public final class MellowsgramBarkNotificationManager {
    private static let relayBaseURL = "https://push.mellowsgram.cc"
    private static let registrationDebounce: Double = 0.8
    private static let registrationRetryDelay: Double = 30.0
    private static let registrationRefreshInterval: Double = 23.0 * 60.0 * 60.0
    private static let foregroundPresenceInterval: Double = 30.0
    private static let foregroundPresenceHeader = "mellowsgram-ios-foreground-v1"

    private struct WebPushToken: Codable {
        struct Keys: Codable {
            let p256dh: String
            let auth: String
        }

        let endpoint: String
        let keys: Keys
    }

    private let activeAccountsDisposable = MetaDisposable()
    private let settingsDisposable = MetaDisposable()
    private let deviceKeyDisposable = MetaDisposable()
    private let reconcileDisposable = MetaDisposable()

    private var accounts: [AccountRecordId: AccountContext] = [:]
    private var removedAccounts: [AccountRecordId: AccountContext] = [:]
    private var primaryAccountId: AccountRecordId?
    private var globalSettings = MellowsgramGlobalSettings.defaultSettings
    private var hasLoadedSettings = false
    private var registeredTokens: [AccountRecordId: Data] = [:]
    private var reconcileTimer: SwiftSignalKit.Timer?
    private var registrationRefreshTimer: SwiftSignalKit.Timer?
    private var foregroundPresenceTimer: SwiftSignalKit.Timer?
    private var foregroundPresenceURL: URL?
    private var isAppForeground = UIApplication.shared.applicationState == .active
    private var lifecycleObservers: [NSObjectProtocol] = []

    public init(
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        activeAccounts: Signal<(primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?), NoError>
    ) {
        Self.removeLegacyLocalNotifications()

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
        self.reconcileTimer?.invalidate()
        self.registrationRefreshTimer?.invalidate()
        self.foregroundPresenceTimer?.invalidate()
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
                        |> map { (_: Never) -> (AccountRecordId, Data?) in
                            return (accountId, nil)
                        }
                        operations.append(unregisterOperation |> then(registerOperation))
                    } else {
                        operations.append(registerOperation)
                    }
                }
            } else if let oldToken {
                let unregisterOperation = context.engine.accountData.unregisterNotificationToken(token: oldToken, type: .webPush, otherAccountUserIds: [])
                |> map { (_: Never) -> (AccountRecordId, Data?) in
                    return (accountId, nil)
                }
                operations.append(unregisterOperation |> then(.single((accountId, nil))))
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
                if let storedRegistration {
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
        let updatedURL = token.flatMap { Self.makeForegroundPresenceURL(token: $0) }
        guard self.foregroundPresenceURL?.absoluteString != updatedURL?.absoluteString else {
            return
        }
        if let currentURL = self.foregroundPresenceURL {
            self.sendForegroundPresence(active: false, to: currentURL)
        }
        self.foregroundPresenceURL = updatedURL
        if self.isAppForeground {
            self.sendForegroundPresence(active: true)
            self.startForegroundPresenceTimer()
        } else {
            self.foregroundPresenceTimer?.invalidate()
            self.foregroundPresenceTimer = nil
        }
    }

    private func updateAppForeground(_ value: Bool) {
        self.isAppForeground = value
        self.foregroundPresenceTimer?.invalidate()
        self.foregroundPresenceTimer = nil
        self.sendForegroundPresence(active: value)
        if value {
            self.startForegroundPresenceTimer()
        }
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

    private func sendForegroundPresence(active: Bool, to url: URL? = nil) {
        guard let url = url ?? self.foregroundPresenceURL else {
            return
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.foregroundPresenceHeader, forHTTPHeaderField: "X-Mellowsgram-Client")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["active": active])
        URLSession.shared.dataTask(with: request).resume()
    }

    private static func makeForegroundPresenceURL(token: Data) -> URL? {
        guard let webPushToken = try? JSONDecoder().decode(WebPushToken.self, from: token),
              let endpointURL = URL(string: webPushToken.endpoint),
              endpointURL.host == "push.mellowsgram.cc"
        else {
            return nil
        }
        let pathComponents = endpointURL.path.split(separator: "/")
        guard pathComponents.count == 2, pathComponents[0] == "p" else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpointURL.host
        components.path = "/presence/\(pathComponents[1])"
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
