import Foundation
import CryptoKit
import UIKit
import AppBundle
import Display
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
    /// A stable icon identifier, for example `verified` or `bot`. Older
    /// manifests omit this field and fall back to the legacy emoji value.
    public let iconId: String?

    public init(id: String, peerType: String, peerId: String, label: String, emoji: String, foreground: String, background: String, iconId: String? = nil) {
        self.id = id
        self.peerType = peerType
        self.peerId = peerId
        self.label = label
        self.emoji = emoji
        self.foreground = foreground
        self.background = background
        self.iconId = iconId
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

private let mellowsgramBadgeImageCache = NSCache<NSString, UIImage>()
private let mellowsgramVerifiedBadgeMasks: (background: UIImage, foreground: UIImage)? = {
    guard let background = UIImage(bundleImageName: "Chat List/PeerVerifiedIconBackground"),
          let foreground = UIImage(bundleImageName: "Chat List/PeerVerifiedIconForeground") else {
        return nil
    }
    return (background, foreground)
}()

private func mellowsgramBadgeColor(_ value: String, fallback: UIColor) -> UIColor {
    var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if hex.hasPrefix("#") {
        hex.removeFirst()
    }
    guard let rawValue = UInt32(hex, radix: 16) else {
        return fallback
    }

    if hex.count == 8 {
        return UIColor(
            red: CGFloat((rawValue >> 24) & 0xff) / 255.0,
            green: CGFloat((rawValue >> 16) & 0xff) / 255.0,
            blue: CGFloat((rawValue >> 8) & 0xff) / 255.0,
            alpha: CGFloat(rawValue & 0xff) / 255.0
        )
    } else if hex.count == 6 {
        return UIColor(
            red: CGFloat((rawValue >> 16) & 0xff) / 255.0,
            green: CGFloat((rawValue >> 8) & 0xff) / 255.0,
            blue: CGFloat(rawValue & 0xff) / 255.0,
            alpha: 1.0
        )
    } else {
        return fallback
    }
}

private func mellowsgramBadgeIconId(_ badge: MellowsgramBadge) -> String {
    if let iconId = badge.iconId?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !iconId.isEmpty {
        return iconId
    }
    let normalizedLabel = badge.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if ["✓", "✔", "✅"].contains(badge.emoji) || ["official", "verified", "официальный"].contains(normalizedLabel) {
        return "verified"
    }
    if ["bot", "бот", "rosette", "розетка"].contains(normalizedLabel) {
        return "bot"
    }
    return "symbol"
}

private func mellowsgramBadgeIsIconOnly(_ badge: MellowsgramBadge) -> Bool {
    switch mellowsgramBadgeIconId(badge) {
    case "verified", "official", "check", "bot", "star":
        return true
    default:
        return false
    }
}

private func mellowsgramStarburstPath(center: CGPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int) -> UIBezierPath {
    let path = UIBezierPath()
    let totalPoints = points * 2
    for index in 0 ..< totalPoints {
        let angle = -CGFloat.pi / 2.0 + CGFloat(index) * CGFloat.pi / CGFloat(points)
        let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        if index == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }
    path.close()
    return path
}

private func mellowsgramDrawBadgeGlyph(_ badge: MellowsgramBadge, in rect: CGRect) {
    let iconId = mellowsgramBadgeIconId(badge)
    let foreground = mellowsgramBadgeColor(badge.foreground, fallback: .white)
    let background = mellowsgramBadgeColor(badge.background, fallback: .systemBlue)
    // Avoid CGRect.center here: on newer SDKs it is a package-scoped SwiftUI
    // property and is not available to this module's public compilation.
    let center = CGPoint(x: rect.midX, y: rect.midY)

    switch iconId {
    case "verified", "official", "check":
        // Use Telegram's own verified badge masks, colored by the signed
        // manifest, so the shape matches a native verified peer exactly.
        if let masks = mellowsgramVerifiedBadgeMasks,
           let backgroundMask = masks.background.cgImage,
           let foregroundMask = masks.foreground.cgImage,
           let nativeImage = generateImage(rect.size, contextGenerator: { size, context in
               let imageRect = CGRect(origin: .zero, size: size)
               context.clear(imageRect)
               context.saveGState()
               context.clip(to: imageRect, mask: backgroundMask)
               context.setFillColor(background.cgColor)
               context.fill(imageRect)
               context.restoreGState()

               context.saveGState()
               context.setBlendMode(.copy)
               context.clip(to: imageRect, mask: foregroundMask)
               context.setFillColor(foreground.cgColor)
               context.fill(imageRect)
               context.restoreGState()
           }, opaque: false) {
            nativeImage.draw(in: rect)
        } else {
            let backgroundPath = mellowsgramStarburstPath(center: center, outerRadius: rect.width * 0.48, innerRadius: rect.width * 0.39, points: 8)
            background.setFill()
            backgroundPath.fill()
            let check = UIBezierPath()
            check.move(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.midY))
            check.addLine(to: CGPoint(x: rect.minX + rect.width * 0.45, y: rect.minY + rect.height * 0.66))
            check.addLine(to: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY + rect.height * 0.34))
            check.lineWidth = max(1.4, rect.width * 0.11)
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            foreground.setStroke()
            check.stroke()
        }
    case "bot", "star":
        let backgroundPath = mellowsgramStarburstPath(center: center, outerRadius: rect.width * 0.48, innerRadius: rect.width * 0.39, points: 8)
        background.setFill()
        backgroundPath.fill()
        let glyph = UIBezierPath()
        let outerRadius = rect.width * 0.24
        let innerRadius = rect.width * 0.10
        for index in 0 ..< 10 {
            let angle = -CGFloat.pi / 2.0 + CGFloat(index) * CGFloat.pi / 5.0
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                glyph.move(to: point)
            } else {
                glyph.addLine(to: point)
            }
        }
        glyph.close()
        foreground.setFill()
        glyph.fill()
    default:
        let path = UIBezierPath(roundedRect: rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04), cornerRadius: rect.width * 0.28)
        background.setFill()
        path.fill()
        let glyph = badge.emoji.isEmpty ? String(badge.label.prefix(1)) : String(badge.emoji.prefix(2))
        guard !glyph.isEmpty else {
            return
        }
        let font = UIFont.systemFont(ofSize: rect.width * 0.52, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: foreground
        ]
        let glyphSize = (glyph as NSString).size(withAttributes: attributes)
        let glyphRect = CGRect(
            x: rect.midX - glyphSize.width * 0.5,
            y: rect.midY - glyphSize.height * 0.5,
            width: glyphSize.width,
            height: glyphSize.height
        )
        (glyph as NSString).draw(in: glyphRect, withAttributes: attributes)
    }
}

/// Returns the compact badge image used beside peer names. The image is
/// deliberately generated from the signed manifest instead of loading remote
/// assets, so a badge cannot inject arbitrary UI or network content.
public func mellowsgramBadgeImage(_ badges: [MellowsgramBadge], size: CGFloat = 22.0) -> UIImage? {
    guard !badges.isEmpty, size > 0.0 else {
        return nil
    }

    let visibleBadges = Array(badges.prefix(3))
    let key = visibleBadges.map { badge in
        "\(badge.id)|\(badge.iconId ?? "")|\(badge.emoji)|\(badge.label)|\(badge.foreground)|\(badge.background)"
    }.joined(separator: ";") + "|\(Int(size.rounded()))"
    if let cached = mellowsgramBadgeImageCache.object(forKey: key as NSString) {
        return cached
    }

    let spacing = max(1.0, floor(size * 0.12))
    let imageSize = CGSize(
        width: size * CGFloat(visibleBadges.count) + spacing * CGFloat(max(0, visibleBadges.count - 1)),
        height: size
    )
    let image = UIGraphicsImageRenderer(size: imageSize).image { _ in
        for (index, badge) in visibleBadges.enumerated() {
            let rect = CGRect(
                x: CGFloat(index) * (size + spacing),
                y: 0.0,
                width: size,
                height: size
            )
            mellowsgramDrawBadgeGlyph(badge, in: rect)
        }
    }.withRenderingMode(.alwaysOriginal)
    mellowsgramBadgeImageCache.setObject(image, forKey: key as NSString)
    return image
}

/// Makes a text attachment compatible with Telegram's TextNode renderer. It
/// keeps the badge inline with the peer name while preserving truncation and
/// right-to-left layout behavior.
public func mellowsgramBadgeAttachment(_ badges: [MellowsgramBadge], font: UIFont, labelColor: UIColor? = nil) -> NSAttributedString? {
    guard !badges.isEmpty else {
        return nil
    }

    let result = NSMutableAttributedString()
    for badge in badges.prefix(3) {
        guard let image = mellowsgramBadgeImage([badge], size: 20.0) else {
            continue
        }
        var iconAttributes: [NSAttributedString.Key: Any] = [.font: font]
        if let labelColor {
            iconAttributes[.foregroundColor] = labelColor
        }
        result.append(NSAttributedString(string: " ", attributes: iconAttributes))
        let attachment = NSMutableAttributedString(string: "\u{FFFC}", attributes: iconAttributes)
        let attachmentRange = NSRange(location: 0, length: 1)
        attachment.addAttribute(.attachment, value: image, range: attachmentRange)
        let placeholderWidth = ("\u{FFFC}" as NSString).size(withAttributes: [.font: font]).width
        attachment.addAttribute(.kern, value: max(0.0, image.size.width - placeholderWidth), range: attachmentRange)
        result.append(attachment)
        // Icon badges intentionally never append their administrative label
        // (for example, "Official" or "Bot"). Telegram shows the glyph only;
        // the label remains in the signed manifest for the admin UI and legacy
        // symbol badges.
        if !mellowsgramBadgeIsIconOnly(badge), !badge.label.isEmpty {
            var textAttributes: [NSAttributedString.Key: Any] = [.font: font]
            if let labelColor {
                textAttributes[.foregroundColor] = labelColor
            }
            result.append(NSAttributedString(string: " \(badge.label)", attributes: textAttributes))
        }
    }
    guard result.length > 0 else {
        return nil
    }
    return result
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
        // Badge rendering must not depend on the Bark/background-notification
        // manager being initialized. Refresh as soon as the UI first touches
        // the runtime and keep the last verified cache available offline.
        self.refresh()
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
            .filter { !mellowsgramBadgeIsIconOnly($0) }
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
