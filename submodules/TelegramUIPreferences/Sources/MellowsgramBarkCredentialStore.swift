import Foundation
import Security
import SwiftSignalKit

public struct MellowsgramBarkStoredRegistration: Codable, Equatable {
    public let barkDeviceKey: String
    public let token: Data
    public let registeredAccountIds: [Int64]
    public let liveContainerNotificationLinks: Bool

    public init(barkDeviceKey: String, token: Data, registeredAccountIds: [Int64], liveContainerNotificationLinks: Bool = false) {
        self.barkDeviceKey = barkDeviceKey
        self.token = token
        self.registeredAccountIds = registeredAccountIds
        self.liveContainerNotificationLinks = liveContainerNotificationLinks
    }

    private enum CodingKeys: String, CodingKey {
        case barkDeviceKey
        case token
        case registeredAccountIds
        case liveContainerNotificationLinks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.barkDeviceKey = try container.decode(String.self, forKey: .barkDeviceKey)
        self.token = try container.decode(Data.self, forKey: .token)
        self.registeredAccountIds = try container.decode([Int64].self, forKey: .registeredAccountIds)
        self.liveContainerNotificationLinks = try container.decodeIfPresent(Bool.self, forKey: .liveContainerNotificationLinks) ?? false
    }
}

/// Keeps the Bark destination and the Telegram Web Push registration token in
/// the app Keychain. The token embeds the Web Push private key in its relay URL.
public enum MellowsgramBarkCredentialStore {
    private static let service = "com.mellowsgram.ios.bark-notifications"
    private static let deviceKeyAccount = "device-key"
    private static let registrationAccount = "webpush-registration"

    private static let initialDeviceKey = Self.readString(account: Self.deviceKeyAccount) ?? ""
    private static let initialRegistration = Self.readData(account: Self.registrationAccount).flatMap { try? JSONDecoder().decode(MellowsgramBarkStoredRegistration.self, from: $0) }
    private static let deviceKeyValue = Atomic(value: Self.initialDeviceKey)
    private static let registrationValue = Atomic(value: Self.initialRegistration)
    private static let deviceKeyPromise = ValuePromise(Self.initialDeviceKey, ignoreRepeated: true)

    public static var deviceKeySignal: Signal<String, NoError> {
        return self.deviceKeyPromise.get()
    }

    public static var deviceKey: String {
        return self.deviceKeyValue.with { $0 }
    }

    public static var registration: MellowsgramBarkStoredRegistration? {
        return self.registrationValue.with { $0 }
    }

    @discardableResult
    public static func updateDeviceKey(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.write(value.isEmpty ? nil : Data(value.utf8), account: Self.deviceKeyAccount) else {
            return false
        }
        _ = self.deviceKeyValue.swap(value)
        self.deviceKeyPromise.set(value)
        return true
    }

    @discardableResult
    public static func updateRegistration(_ value: MellowsgramBarkStoredRegistration?) -> Bool {
        let data = value.flatMap { try? JSONEncoder().encode($0) }
        guard value == nil || data != nil,
              Self.write(data, account: Self.registrationAccount) else {
            return false
        }
        _ = self.registrationValue.swap(value)
        return true
    }

    private static func baseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account
        ]
    }

    private static func readString(account: String) -> String? {
        guard let data = Self.readData(account: account) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private static func readData(account: String) -> Data? {
        var query = Self.baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    @discardableResult
    private static func write(_ data: Data?, account: String) -> Bool {
        let query = Self.baseQuery(account: account)
        guard let data else {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess
    }
}
