import KeyboardKit
@testable import TaigiKeyboard
import XCTest

/// Pins what the 漢羅 key writes — the other script, bare — per cell shape.
final class ActionHandlerAlternateCommitTests: XCTestCase {
    private func alternate(_ suggestion: AutocompleteSuggestion, swapped: Bool = false, showsHanji: Bool = true) -> ResolvedCommit? {
        ActionHandler.alternateCommit(for: suggestion, isTranslateSwapped: swapped, showsHanji: showsHanji)
    }

    func testSideBySide_writesTheScriptTheListDoesNotLeadWith() {
        let romanLed = AutocompleteSuggestion(text: "tâi-gí", title: "tâi-gí", subtitle: "台語")
        XCTAssertEqual(alternate(romanLed)?.text, "台語")
        XCTAssertEqual(alternate(romanLed)?.wroteRomanization, false)
        // After `suggestionToHandle`'s pre-swap the hanji leads the text.
        let hanjiLed = AutocompleteSuggestion(text: "台語", title: "台語", subtitle: "tâi-gí")
        XCTAssertEqual(alternate(hanjiLed, swapped: true)?.text, "tâi-gí")
        XCTAssertEqual(alternate(hanjiLed, swapped: true)?.wroteRomanization, true)
    }

    func testCombinedCells_writeTheirSibling() {
        let hanjiCell = AutocompleteSuggestion(text: "台語", title: "台語", subtitle: nil, additionalInfo: [
            CandidateCellScript.infoKey: CandidateCellScript.hanji,
            CandidateCellScript.bracketRomanKey: "tâi-gí",
        ])
        XCTAssertEqual(alternate(hanjiCell)?.text, "tâi-gí")
        let romanCell = AutocompleteSuggestion(text: "tâi-gí", title: "tâi-gí", subtitle: nil, additionalInfo: [
            CandidateCellScript.infoKey: CandidateCellScript.roman,
            CandidateCellScript.alternateHanjiKey: "台語",
            "displayText": "台語",
        ])
        XCTAssertEqual(alternate(romanCell)?.text, "台語")
    }

    func testCombinedLiteralWithAdoptedIdentity_keepsRomanization() {
        // A §34 literal that absorbed a dictionary row carries that row's
        // identity in `displayText`, but no 漢字 of its own to commit.
        let literal = AutocompleteSuggestion(text: "Sió-chiá", title: "Sió-chiá", subtitle: nil, additionalInfo: [
            CandidateCellScript.infoKey: CandidateCellScript.roman,
            "displayText": "小姐",
            "canonicalTl": "sió-tsiá",
        ])
        XCTAssertNil(alternate(literal))
    }

    func testCellsWithNoOtherScript_commitAsATapWould() {
        XCTAssertNil(alternate(AutocompleteSuggestion(text: "tai5", title: "tai5", subtitle: nil, additionalInfo: ["isRawInput": "true"])))
        XCTAssertNil(alternate(AutocompleteSuggestion(text: "Kimo", title: "Kimo", subtitle: nil)))
        XCTAssertNil(alternate(AutocompleteSuggestion(text: "tâi-gí", title: "tâi-gí", subtitle: "台語"), showsHanji: false), "羅馬字 mode")
    }
}
