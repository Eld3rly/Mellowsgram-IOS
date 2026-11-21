import Foundation
import TelegramCore
import SwiftSignalKit

public struct CallListSettings: Codable, Equatable {
    public var _showTab: Bool?
    public var _showContactsTab: Bool?
    
    public static var defaultSettings: CallListSettings {
        return CallListSettings(showTab: nil, showContactsTab: nil)
    }
    
    public var showTab: Bool {
        get {
            if let value = self._showTab {
                return value
            } else {
                return true
            }
        } set {
            self._showTab = newValue
        }
    }

    public var showContactsTab: Bool {
        get {
            return self._showContactsTab ?? true
        } set {
            self._showContactsTab = newValue
        }
    }
    
    public init(showTab: Bool?, showContactsTab: Bool? = nil) {
        self._showTab = showTab
        self._showContactsTab = showContactsTab
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let value = try container.decodeIfPresent(Int32.self, forKey: "showTab") {
            self._showTab = value != 0
        }
        if let value = try container.decodeIfPresent(Int32.self, forKey: "showContactsTab") {
            self._showContactsTab = value != 0
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        if let showTab = self._showTab {
            try container.encode((showTab ? 1 : 0) as Int32, forKey: "showTab")
        } else {
            try container.encodeNil(forKey: "showTab")
        }
        if let showContactsTab = self._showContactsTab {
            try container.encode((showContactsTab ? 1 : 0) as Int32, forKey: "showContactsTab")
        } else {
            try container.encodeNil(forKey: "showContactsTab")
        }
    }
    
    public static func ==(lhs: CallListSettings, rhs: CallListSettings) -> Bool {
        return lhs._showTab == rhs._showTab && lhs._showContactsTab == rhs._showContactsTab
    }
    
    public func withUpdatedShowTab(_ showTab: Bool) -> CallListSettings {
        return CallListSettings(showTab: showTab, showContactsTab: self._showContactsTab)
    }

    public func withUpdatedShowContactsTab(_ showContactsTab: Bool) -> CallListSettings {
        return CallListSettings(showTab: self._showTab, showContactsTab: showContactsTab)
    }
}

public func updateCallListSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (CallListSettings) -> CallListSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.callListSettings, { entry in
            let currentSettings: CallListSettings
            if let entry = entry?.get(CallListSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = CallListSettings.defaultSettings
            }
            return SharedPreferencesEntry(f(currentSettings))
        })
    }
}
