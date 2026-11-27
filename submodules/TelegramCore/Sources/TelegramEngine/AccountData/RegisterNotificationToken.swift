import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi


public enum NotificationTokenType {
    case aps(encrypt: Bool)
    case voip
    case webPush
}

func _internal_unregisterNotificationToken(account: Account, token: Data, type: NotificationTokenType, otherAccountUserIds: [PeerId.Id]) -> Signal<Never, NoError> {
    let mappedType: Int32
    let tokenString: String
    switch type {
        case .aps:
            mappedType = 1
            tokenString = hexString(token)
        case .voip:
            mappedType = 9
            tokenString = hexString(token)
        case .webPush:
            guard let webPushToken = String(data: token, encoding: .utf8), !webPushToken.isEmpty else {
                return .complete()
            }
            mappedType = 10
            tokenString = webPushToken
    }
    return account.network.request(Api.functions.account.unregisterDevice(tokenType: mappedType, token: tokenString, otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
    |> retryRequest
    |> ignoreValues
}

func _internal_registerNotificationToken(account: Account, token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [PeerId.Id], excludeMutedChats: Bool) -> Signal<Bool, NoError> {
    if case .webPush = type {
        guard let tokenString = String(data: token, encoding: .utf8), !tokenString.isEmpty else {
            return .single(false)
        }
        var flags: Int32 = 0
        if excludeMutedChats {
            flags |= 1 << 0
        }
        return account.network.request(Api.functions.account.registerDevice(flags: flags, tokenType: 10, token: tokenString, appSandbox: .boolFalse, secret: Buffer(data: Data()), otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
        |> map { result -> Bool in
            if case .boolTrue = result {
                return true
            }
            Logger.shared.log("MellowsgramBark", "Telegram web push registerDevice returned false")
            return false
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            let description = error.errorDescription ?? "UNKNOWN"
            let category = description.range(of: "^[A-Z0-9_]{1,64}$", options: .regularExpression) != nil ? description : "OTHER"
            Logger.shared.log("MellowsgramBark", "Telegram web push registerDevice failed with code \(error.errorCode): \(category)")
            return .single(false)
        }
    }

    return masterNotificationsKey(account: account, ignoreDisabled: false)
    |> mapToSignal { masterKey -> Signal<Bool, NoError> in
        let mappedType: Int32
        var keyData = Data()
        switch type {
            case let .aps(encrypt):
                mappedType = 1
                if encrypt {
                    keyData = masterKey.data
                }
            case .voip:
                mappedType = 9
                keyData = masterKey.data
            case .webPush:
                mappedType = 10
        }
        var flags: Int32 = 0
        if excludeMutedChats {
            flags |= 1 << 0
        }
        let tokenString = hexString(token)
        return account.network.request(Api.functions.account.registerDevice(flags: flags, tokenType: mappedType, token: tokenString, appSandbox: sandbox ? .boolTrue : .boolFalse, secret: Buffer(data: keyData), otherUids: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
        |> map { _ -> Bool in
            return true
        }
        |> `catch` { error -> Signal<Bool, NoError> in
            if error.errorDescription == "TOKEN_WAS_INVALIDATED" {
                return .single(false)
            } else {
                return .single(true)
            }
        }
    }
}
