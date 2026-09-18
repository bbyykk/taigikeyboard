@testable import TaigiInputMethodCore
import XCTest

final class RecentSymbolsTests: XCTestCase {
    private let table = ["，", "。", "！", "「」", "★"]

    func testNothingRecent_leavesTheTableInFileOrder() {
        XCTAssertEqual(RecentSymbols([]).ordered(table), table)
    }

    func testAPick_movesToTheFront_andTheRestKeepsFileOrder() {
        // trace: noting("「」") → ["「」"]; ordered → ["「」"] + table minus it.
        let recents = RecentSymbols([]).noting("「」")
        XCTAssertEqual(recents.symbols, ["「」"])
        XCTAssertEqual(recents.ordered(table), ["「」", "，", "。", "！", "★"])
    }

    func testTheLatestPick_leads_andRepickingMovesItUp() {
        let recents = RecentSymbols([]).noting("。").noting("★").noting("。")
        XCTAssertEqual(recents.symbols, ["。", "★"])
        XCTAssertEqual(recents.ordered(table), ["。", "★", "，", "！", "「」"])
    }

    func testTheTenthPick_dropsTheOldest() {
        var recents = RecentSymbols([])
        for symbol in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"] {
            recents = recents.noting(symbol)
        }
        XCTAssertEqual(recents.symbols, ["10", "9", "8", "7", "6", "5", "4", "3", "2"], "one slot-key page")
    }

    func testAStoredListIsNormalized_repeatsAndOverflowAndBlanksDropped() {
        let stored = ["★", "", "★", "。", "1", "2", "3", "4", "5", "6", "7", "8"]
        XCTAssertEqual(
            RecentSymbols(stored).symbols,
            ["★", "。", "1", "2", "3", "4", "5", "6", "7"],
        )
    }

    func testARecentTheTableNoLongerHas_isNotShown_andNotForgotten() {
        let recents = RecentSymbols(["☃", "★"])
        XCTAssertEqual(recents.ordered(table), ["★", "，", "。", "！", "「」"])
        XCTAssertEqual(recents.symbols, ["☃", "★"], "ordering never writes back")
    }
}
