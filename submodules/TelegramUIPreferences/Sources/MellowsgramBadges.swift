import Foundation
import CryptoKit
import TelegramCore
import SwiftSignalKit

public struct MellowsgramBadge: Codable, Equatable, Hashable {
    public let id: String
    public let peerType: String
    public let peerId: String
    public let label: String
    public let emoji: String
    public let foreground: String
    public let background: String

    public init(id: String, peerType: String, peerId: String, label: String, emoji: String, foreground: String, background: String) {
        self.id = id
        self.peerType = peerType
        self.peerId = peerId
        self.label = label
        self.emoji = emoji
        self.foreground = foreground
        self.background = background
    }
}

private struct MellowsgramBadgeManifest: Decodable {
    let revision: Int
    let badges: [MellowsgramBadge]
}

private struct MellowsgramBadgeEnvelope: Decodable, Encodable {
    let payload: String
    let signature: String
}

/// Verifies and caches the relay's signed badge manifest. The cache is shared
/// by all Telegram accounts on this installation; badge assignments are app-wide.
public final class MellowsgramBadgeRuntime {
    public static let shared = MellowsgramBadgeRuntime()

    private static let relayURL = URL(string: "https://push.mellowsgram.cc/badges")!
    private static let clientHeader = "mellowsgram-ios-badges-v1"
    private static let publicKeyBase64 = "uEj3bxjwIk6d5XERCpqZPJ9qSoXff7n3zhIBrehqSY8="
    private static let cachedEnvelopeKey = "mellowsgram.badges.signed-envelope.v1"
    private static let minimumRefreshInterval: TimeInterval = 15.0 * 60.0

    private let badgesByPeer = Atomic<[String: [MellowsgramBadge]]>(value: [:])
    private let badgesPromise = ValuePromise<[MellowsgramBadge]>([], ignoreRepeated: false)
    private let refreshInProgress = Atomic<Bool>(value: false)
    private let lastRefreshTimestamp = Atomic<TimeInterval>(value: 0.0)

    public var signal: Signal<[MellowsgramBadge], NoError> {
        return self.badgesPromise.get()
    }

    private init() {
        if let cached = UserDefaults.standard.data(forKey: Self.cachedEnvelopeKey),
           let envelope = try? JSONDecoder().decode(MellowsgramBadgeEnvelope.self, from: cached),
           let manifest = Self.verifiedManifest(envelope) {
            self.install(manifest.badges)
        }
    }

    public func refresh() {
        let now = Date().timeIntervalSince1970
        let previousRefresh = self.lastRefreshTimestamp.with { $0 }
        guard now - previousRefresh >= Self.minimumRefreshInterval else {
            return
        }
        _ = self.lastRefreshTimestamp.swap(now)
        guard !self.refreshInProgress.swap(true) else {
            return
        }
        var request = URLRequest(url: Self.relayURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 12.0)
        request.httpMethod = "GET"
        request.setValue(Self.clientHeader, forHTTPHeaderField: "X-Mellowsgram-Client")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            guard let self else {
                return
            }
            defer {
                _ = self.refreshInProgress.swap(false)
            }
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200,
                  let data,
                  let envelope = try? JSONDecoder().decode(MellowsgramBadgeEnvelope.self, from: data),
                  let manifest = Self.verifiedManifest(envelope) else {
                return
            }
            if let encoded = try? JSONEncoder().encode(envelope) {
                UserDefaults.standard.set(encoded, forKey: Self.cachedEnvelopeKey)
            }
            self.install(manifest.badges)
        }.resume()
    }

    public func badges(peerNamespace: Int32, peerId: Int64) -> [MellowsgramBadge] {
        let type: String
        switch peerNamespace {
        case Namespaces.Peer.CloudUser._internalGetInt32Value():
            type = "user"
        case Namespaces.Peer.CloudGroup._internalGetInt32Value():
            type = "group"
        case Namespaces.Peer.CloudChannel._internalGetInt32Value():
            type = "channel"
        default:
            return []
        }
        return self.badgesByPeer.with { $0["\(type):\(peerId)"] ?? [] }
    }

    public func badges(peerId: String, peerType: String) -> [MellowsgramBadge] {
        guard ["user", "group", "channel"].contains(peerType) else {
            return []
        }
        return self.badgesByPeer.with { $0["\(peerType):\(peerId)"] ?? [] }
    }

    public func badgeText(peerNamespace: Int32, peerId: Int64) -> String {
        return self.badges(peerNamespace: peerNamespace, peerId: peerId)
            .map { badge in
                let prefix = badge.emoji.isEmpty ? "" : "\(badge.emoji) "
                return "\(prefix)\(badge.label)"
            }
            .joined(separator: "  ")
    }

    private func install(_ badges: [MellowsgramBadge]) {
        var grouped: [String: [MellowsgramBadge]] = [:]
        for badge in badges {
            guard let peerId = Int64(badge.peerId), peerId > 0,
                  ["user", "group", "channel"].contains(badge.peerType),
                  !badge.id.isEmpty, !badge.label.isEmpty, badge.label.count <= 48 else {
                continue
            }
            grouped["\(badge.peerType):\(badge.peerId)", default: []].append(badge)
        }
        for key in grouped.keys {
            grouped[key]?.sort { $0.id < $1.id }
        }
        _ = self.badgesByPeer.swap(grouped)
        self.badgesPromise.set(grouped.values.flatMap { $0 }.sorted { $0.id < $1.id })
    }

    private static func verifiedManifest(_ envelope: MellowsgramBadgeEnvelope) -> MellowsgramBadgeManifest? {
        guard !Self.publicKeyBase64.isEmpty,
              let publicKeyData = Data(base64Encoded: Self.publicKeyBase64),
              let payload = Self.decodeBase64URL(envelope.payload),
              let signature = Self.decodeBase64URL(envelope.signature),
              signature.count == 64,
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
              publicKey.isValidSignature(signature, for: payload),
              let manifest = try? JSONDecoder().decode(MellowsgramBadgeManifest.self, from: payload),
              manifest.revision >= 0 else {
            return nil
        }
        return manifest
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var normalized = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: normalized)
    }
}
