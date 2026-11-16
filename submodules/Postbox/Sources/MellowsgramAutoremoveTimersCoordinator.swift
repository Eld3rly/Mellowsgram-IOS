import Foundation
import SwiftSignalKit

/// Account-local switch used by Mellowsgram to keep ordinary cloud-chat media
/// available after Telegram's client-side autoremove/autoclear deadline.
///
/// The coordinator is deliberately separate from the archive and ghost-mode
/// switches: timer handling must be checked by both the timestamp manager and
/// the UI/media consumers.
public final class MellowsgramAutoremoveTimersCoordinator {
    private let enabledValue = Atomic<Bool>(value: true)
    private let enabledPromise = ValuePromise<Bool>(true, ignoreRepeated: true)

    public init() {
    }

    public var isEnabled: Bool {
        return self.enabledValue.with { $0 }
    }

    public var signal: Signal<Bool, NoError> {
        return self.enabledPromise.get()
    }

    public func setEnabled(_ value: Bool) {
        let previous = self.enabledValue.swap(value)
        if previous != value {
            self.enabledPromise.set(value)
        }
    }
}
