@testable import TaigiKeyboard
import XCTest

/// Pins the nine-cell page the hardware keys impose on the scrolling bar.
final class HardwareCandidatePageTests: XCTestCase {
    func testPageStart_isTheNineCellWindowTheHighlightIsIn() {
        for (selected, expected) in [(-1, 0), (0, 0), (8, 0), (9, 9), (17, 9), (18, 18)] {
            XCTAssertEqual(HardwareCandidatePage.pageStart(selected: selected), expected, "selected \(selected)")
        }
    }

    func testNextAndPrevious_stepOne_andClampAtTheEnds() {
        XCTAssertEqual(HardwareCandidatePage.target(for: .next, from: 0, count: 3), 1)
        XCTAssertEqual(HardwareCandidatePage.target(for: .previous, from: 2, count: 3), 1)
        XCTAssertNil(HardwareCandidatePage.target(for: .previous, from: 0, count: 3))
        XCTAssertNil(HardwareCandidatePage.target(for: .next, from: 2, count: 3))
        // An unset highlight walks from the first cell.
        XCTAssertEqual(HardwareCandidatePage.target(for: .next, from: -1, count: 3), 1)
    }

    func testPaging_movesNine_andClampsToTheLastCell() {
        XCTAssertEqual(HardwareCandidatePage.target(for: .pageForward, from: 2, count: 30), 11)
        XCTAssertEqual(HardwareCandidatePage.target(for: .pageBackward, from: 11, count: 30), 2)
        XCTAssertEqual(HardwareCandidatePage.target(for: .pageForward, from: 25, count: 30), 29)
        XCTAssertEqual(HardwareCandidatePage.target(for: .pageBackward, from: 4, count: 30), 0)
        XCTAssertNil(HardwareCandidatePage.target(for: .pageForward, from: 29, count: 30))
    }

    func testEmptyList_hasNowhereToGo() {
        XCTAssertNil(HardwareCandidatePage.target(for: .next, from: 0, count: 0))
    }

    func testSlots_addressTheCurrentPage_andStopAtTheListEnd() {
        XCTAssertEqual(HardwareCandidatePage.candidateIndex(forSlot: 0, selected: 0, count: 12), 0)
        XCTAssertEqual(HardwareCandidatePage.candidateIndex(forSlot: 8, selected: 3, count: 12), 8)
        XCTAssertEqual(HardwareCandidatePage.candidateIndex(forSlot: 0, selected: 9, count: 12), 9)
        XCTAssertEqual(HardwareCandidatePage.candidateIndex(forSlot: 2, selected: 9, count: 12), 11)
        XCTAssertNil(HardwareCandidatePage.candidateIndex(forSlot: 3, selected: 9, count: 12))
        XCTAssertNil(HardwareCandidatePage.candidateIndex(forSlot: 9, selected: 0, count: 12))
    }

    func testSlotLabels_followThePage() {
        XCTAssertEqual(HardwareCandidatePage.slotLabel(forIndex: 0, selected: 0), "q")
        XCTAssertEqual(HardwareCandidatePage.slotLabel(forIndex: 8, selected: 0), ";")
        XCTAssertNil(HardwareCandidatePage.slotLabel(forIndex: 9, selected: 0))
        XCTAssertEqual(HardwareCandidatePage.slotLabel(forIndex: 9, selected: 12), "q")
        XCTAssertNil(HardwareCandidatePage.slotLabel(forIndex: 3, selected: 12))
    }
}
