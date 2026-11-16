import Foundation
import SwiftSignalKit

/// The individual network safeguards exposed by the Ghost Mode settings.
/// Stored as a small bit mask so Postbox can make the decision synchronously
/// from read/presence transactions without depending on TelegramCore settings.
public struct MellowsgramGhostModeOptions: OptionSet, Equatable {
    public let rawValue: Int32

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let dontReadMessages = MellowsgramGhostModeOptions(rawValue: 1 << 0)
    public static let dontReadStories = MellowsgramGhostModeOptions(rawValue: 1 << 1)
    public static let dontSendOnline = MellowsgramGhostModeOptions(rawValue: 1 << 2)
    public static let dontSendTyping = MellowsgramGhostModeOptions(rawValue: 1 << 3)
    public static let goOfflineAutomatically = MellowsgramGhostModeOptions(rawValue: 1 << 4)

    public static let all: MellowsgramGhostModeOptions = [
        .dontReadMessages,
        .dontReadStories,
        .dontSendOnline,
        .dontSendTyping,
        .goOfflineAutomatically
    ]
}

/// Account-local, process-wide gate for client-side network side effects.
///
/// It deliberately does not block message sends or media uploads. Callers use
/// the coordinator at the point where read/presence/story/upload-progress work
/// would otherwise be queued, so disabling the mode only affects new actions.
public final class MellowsgramGhostModeCoordinator {
    private let enabledValue = Atomic<Bool>(value: false)
    private let enabledPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private let optionsValue = Atomic<Int32>(value: MellowsgramGhostModeOptions.all.rawValue)
    private let optionsPromise = ValuePromise<Int32>(MellowsgramGhostModeOptions.all.rawValue, ignoreRepeated: true)

    public init() {
    }

    public var isEnabled: Bool {
        return self.enabledValue.with { $0 }
    }

    public var signal: Signal<Bool, NoError> {
        return self.enabledPromise.get()
    }

    public var options: MellowsgramGhostModeOptions {
        return MellowsgramGhostModeOptions(rawValue: self.optionsValue.with { $0 })
    }

    public var optionsSignal: Signal<MellowsgramGhostModeOptions, NoError> {
        return self.optionsPromise.get()
        |> map { MellowsgramGhostModeOptions(rawValue: $0) }
    }

    public func setEnabled(_ value: Bool) {
        let previous = self.enabledValue.swap(value)
        if previous != value {
            self.enabledPromise.set(value)
        }
    }

    public func setOptions(_ value: MellowsgramGhostModeOptions) {
        let previous = self.optionsValue.swap(value.rawValue)
        if previous != value.rawValue {
            self.optionsPromise.set(value.rawValue)
        }
    }

    public func shouldSendReadReceipts() -> Bool {
        return !self.isEnabled || !self.options.contains(.dontReadMessages)
    }

    public func shouldSendStoryReads() -> Bool {
        return !self.isEnabled || !self.options.contains(.dontReadStories)
    }

    public func shouldSendOnlinePresence() -> Bool {
        return !self.isEnabled || (!self.options.contains(.dontSendOnline) && !self.options.contains(.goOfflineAutomatically))
    }

    public func shouldSendUploadProgress() -> Bool {
        return !self.isEnabled
    }

    public func shouldSendTypingActivity() -> Bool {
        return !self.isEnabled || !self.options.contains(.dontSendTyping)
    }

    public var readReceiptsSuppressedSignal: Signal<Bool, NoError> {
        return self.policySignal(for: .dontReadMessages)
    }

    public var storyReadsSuppressedSignal: Signal<Bool, NoError> {
        return self.policySignal(for: .dontReadStories)
    }

    public var onlinePresenceSuppressedSignal: Signal<Bool, NoError> {
        return combineLatest(self.enabledPromise.get(), self.optionsPromise.get())
        |> map { enabled, rawOptions in
            let options = MellowsgramGhostModeOptions(rawValue: rawOptions)
            return enabled && (options.contains(.dontSendOnline) || options.contains(.goOfflineAutomatically))
        }
        |> distinctUntilChanged
    }

    public var isReadReceiptsSuppressed: Bool {
        return self.isEnabled && self.options.contains(.dontReadMessages)
    }

    public var areStoryReadsSuppressed: Bool {
        return self.isEnabled && self.options.contains(.dontReadStories)
    }

    public var isOnlinePresenceSuppressed: Bool {
        return self.isEnabled && (self.options.contains(.dontSendOnline) || self.options.contains(.goOfflineAutomatically))
    }

    private func policySignal(for option: MellowsgramGhostModeOptions) -> Signal<Bool, NoError> {
        return combineLatest(self.enabledPromise.get(), self.optionsPromise.get())
        |> map { enabled, rawOptions in
            return enabled && MellowsgramGhostModeOptions(rawValue: rawOptions).contains(option)
        }
        |> distinctUntilChanged
    }
}
