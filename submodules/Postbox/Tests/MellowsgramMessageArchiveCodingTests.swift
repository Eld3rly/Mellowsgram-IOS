import Foundation
import XCTest
@testable import Postbox

final class MellowsgramMessageArchiveCodingTests: XCTestCase {
    func testArchiveRecordRoundTripsThroughCodableEntry() {
        let peerId = MessageHistoryTableFixture.peerId(900)
        let record = MellowsgramMessageArchiveRecord(
            messageId: MessageId(peerId: peerId, namespace: 0, id: 5),
            threadId: 42,
            timestamp: 1000,
            authorId: peerId,
            isIncoming: true,
            text: "edited",
            attributesData: Data([0, 1, 2, 3]),
            deletedAt: 1005,
            stableVersion: UInt32.max,
            revisions: [
                MellowsgramMessageRevision(
                    text: "before edit",
                    attributesData: Data([4, 5, 6]),
                    timestamp: 1004,
                    stableVersion: UInt32.max - 1
                )
            ]
        )

        guard let entry = CodableEntry(record) else {
            return XCTFail("archive record could not be encoded")
        }
        XCTAssertEqual(entry.get(MellowsgramMessageArchiveRecord.self), record)
    }
}
