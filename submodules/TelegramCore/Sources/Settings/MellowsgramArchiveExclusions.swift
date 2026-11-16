import Postbox

extension EphemeralMessageAttribute: MellowsgramMessageArchiveExclusion {
    public var mellowsgramShouldNotArchive: Bool {
        return true
    }
}

extension EphemeralOutgoingMessageAttribute: MellowsgramMessageArchiveExclusion {
    public var mellowsgramShouldNotArchive: Bool {
        return true
    }
}
