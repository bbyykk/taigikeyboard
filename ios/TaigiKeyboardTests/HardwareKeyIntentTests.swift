@testable import TaigiKeyboard
import UIKit
import XCTest

/// Pins the iPad external-keyboard key contract (`HardwareKeyIntent`) — the
/// iOS mirror of the desktop's `ComposingKeyIntentTests`.
final class HardwareKeyIntentTests: XCTestCase {
    private func key(
        _ characters: String,
        ignoringModifiers: String? = nil,
        code: UIKeyboardHIDUsage = .keyboardA,
        modifiers: UIKeyModifierFlags = [],
    ) -> HardwareKeySnapshot {
        HardwareKeySnapshot(
            characters: characters,
            charactersIgnoringModifiers: ignoringModifiers,
            keyCode: code,
            modifiers: modifiers,
        )
    }

    // MARK: - Text

    func testRomanizationCharacters_areInput_inBothStates() {
        for (characters, code) in [("t", UIKeyboardHIDUsage.keyboardT), ("-", .keyboardHyphen), ("5", .keyboard5)] {
            XCTAssertEqual(HardwareKeyIntent.intent(for: key(characters, code: code), isComposing: false), .input(characters))
            XCTAssertEqual(HardwareKeyIntent.intent(for: key(characters, code: code), isComposing: true), .input(characters))
        }
    }

    func testShiftedLetter_isInput_asTheCapital() {
        let shifted = key("A", ignoringModifiers: "a", code: .keyboardA, modifiers: .shift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: shifted, isComposing: true, isShowingCandidates: true), .input("A"))
    }

    func testPunctuation_isInput_soTheOnScreenPathCommitsThenInserts() {
        XCTAssertEqual(HardwareKeyIntent.intent(for: key(",", code: .keyboardComma), isComposing: true), .input(","))
        XCTAssertEqual(HardwareKeyIntent.intent(for: key("。", code: .keyboardPeriod), isComposing: false), .input("。"))
    }

    func testSpace_isSpace_withoutABar_andTheAlternateScriptWithOne() {
        let space = key(" ", code: .keyboardSpacebar)
        XCTAssertEqual(HardwareKeyIntent.intent(for: space, isComposing: true), .space)
        XCTAssertEqual(HardwareKeyIntent.intent(for: space, isComposing: false), .space)
        XCTAssertEqual(HardwareKeyIntent.intent(for: space, isComposing: true, isShowingCandidates: true), .commitAlternateScript)
    }

    // MARK: - Fixed tier

    func testEscape_cancelsWhileComposing_andPassesThroughIdle() {
        let escape = key("\u{1B}", code: .keyboardEscape)
        XCTAssertEqual(HardwareKeyIntent.intent(for: escape, isComposing: true), .cancel)
        XCTAssertEqual(HardwareKeyIntent.intent(for: escape, isComposing: false), .passThrough)
    }

    func testBackspace_isAlwaysOurs() {
        let backspace = key("\u{8}", code: .keyboardDeleteOrBackspace)
        XCTAssertEqual(HardwareKeyIntent.intent(for: backspace, isComposing: true), .deleteBackward)
        XCTAssertEqual(HardwareKeyIntent.intent(for: backspace, isComposing: false), .deleteBackward)
    }

    func testReturn_confirmsTheHighlight_andShiftReturnCommitsTheLiteral() {
        let enter = key("\r", code: .keyboardReturnOrEnter)
        let shiftEnter = key("\r", code: .keyboardReturnOrEnter, modifiers: .shift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: enter, isComposing: true, isShowingCandidates: true), .confirmHighlighted)
        XCTAssertEqual(HardwareKeyIntent.intent(for: shiftEnter, isComposing: true), .commitLiteral)
        // Idle, both are the newline the on-screen Return writes.
        XCTAssertEqual(HardwareKeyIntent.intent(for: enter, isComposing: false), .confirmHighlighted)
        XCTAssertEqual(HardwareKeyIntent.intent(for: shiftEnter, isComposing: false), .confirmHighlighted)
    }

    func testArrows_walkAndPage_onlyWhileTheBarIsUp() {
        let cases: [(UIKeyboardHIDUsage, HardwareCandidateNavigation)] = [
            (.keyboardLeftArrow, .previous), (.keyboardRightArrow, .next),
            (.keyboardUpArrow, .pageBackward), (.keyboardDownArrow, .pageForward),
            (.keyboardPageUp, .pageBackward), (.keyboardPageDown, .pageForward),
        ]
        for (code, expected) in cases {
            let arrow = key("", code: code)
            XCTAssertEqual(HardwareKeyIntent.intent(for: arrow, isComposing: true, isShowingCandidates: true), .navigate(expected))
            // With no bar the key is the host's — and a running composition
            // is finished first, before the host moves the caret.
            XCTAssertEqual(HardwareKeyIntent.intent(for: arrow, isComposing: true), .commitThenPassThrough, "\(code)")
            XCTAssertEqual(HardwareKeyIntent.intent(for: arrow, isComposing: false), .passThrough, "\(code)")
        }
    }

    func testShiftedArrow_isTheHostsSelection_afterTheCompositionEnds() {
        let shiftLeft = key("", code: .keyboardLeftArrow, modifiers: .shift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: shiftLeft, isComposing: true, isShowingCandidates: true), .commitThenPassThrough)
        XCTAssertEqual(HardwareKeyIntent.intent(for: shiftLeft, isComposing: false), .passThrough)
    }

    func testTab_walksWhileTheBarIsUp_andPassesThroughOtherwise() {
        let tab = key("\t", code: .keyboardTab)
        let shiftTab = key("\t", code: .keyboardTab, modifiers: .shift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: tab, isComposing: true, isShowingCandidates: true), .navigate(.next))
        XCTAssertEqual(HardwareKeyIntent.intent(for: shiftTab, isComposing: true, isShowingCandidates: true), .navigate(.previous))
        XCTAssertEqual(HardwareKeyIntent.intent(for: tab, isComposing: true), .commitThenPassThrough)
        XCTAssertEqual(HardwareKeyIntent.intent(for: tab, isComposing: false), .passThrough)
    }

    // MARK: - Slot keys and paging brackets

    func testTheNineBareKeys_pickSlotsZeroToEight_whileTheBarIsUp() {
        for (slot, character) in HardwareKeyIntent.slotKeyRow.enumerated() {
            let press = key(character)
            XCTAssertEqual(
                HardwareKeyIntent.intent(for: press, isComposing: true, isShowingCandidates: true),
                .selectCandidateSlot(slot, flip: false),
            )
            // With no bar the same key is what it types.
            XCTAssertEqual(HardwareKeyIntent.intent(for: press, isComposing: true), .input(character))
        }
    }

    func testShiftedSlotKey_flipsItsSlot_andIsTheCapitalWithNoBar() {
        let shifted = key("Q", ignoringModifiers: "q", code: .keyboardQ, modifiers: .shift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: shifted, isComposing: true, isShowingCandidates: true), .selectCandidateSlot(0, flip: true))
        XCTAssertEqual(HardwareKeyIntent.intent(for: shifted, isComposing: true), .input("Q"))
        // `⇧;` types `:`; the key code still says which key was pressed.
        let colon = key(":", ignoringModifiers: ":", code: .keyboardSemicolon, modifiers: .shift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: colon, isComposing: true, isShowingCandidates: true), .selectCandidateSlot(8, flip: true))
    }

    // MARK: - Caret

    func testOptionArrows_stepTheCaret_whileComposing_andAreTheHostsOtherwise() {
        let optionLeft = key("", code: .keyboardLeftArrow, modifiers: .alternate)
        let optionRight = key("", code: .keyboardRightArrow, modifiers: .alternate)
        XCTAssertEqual(HardwareKeyIntent.intent(for: optionLeft, isComposing: true, isShowingCandidates: true), .moveCaret(.left))
        XCTAssertEqual(HardwareKeyIntent.intent(for: optionRight, isComposing: true), .moveCaret(.right))
        XCTAssertEqual(HardwareKeyIntent.intent(for: optionLeft, isComposing: false), .passThrough)
        // Exactly ⌥: ⌥⇧← is the host's selection, and ends the composition first.
        let optionShiftLeft = key("", code: .keyboardLeftArrow, modifiers: [.alternate, .shift])
        XCTAssertEqual(HardwareKeyIntent.intent(for: optionShiftLeft, isComposing: true, isShowingCandidates: true), .commitThenPassThrough)
    }

    // MARK: - User bindings and shortcuts

    func testTheShortcuts_fireWhereverTheCompositionStands() {
        let backtick = key("`", code: .keyboardGraveAccentAndTilde)
        XCTAssertEqual(HardwareKeyIntent.intent(for: backtick, isComposing: false), .shortcut(.toggleTranslateSwapped))
        XCTAssertEqual(HardwareKeyIntent.intent(for: backtick, isComposing: true, isShowingCandidates: true), .shortcut(.toggleTranslateSwapped))
        let ctrlCmdC = key("\u{3}", ignoringModifiers: "c", code: .keyboardC, modifiers: [.control, .command])
        XCTAssertEqual(HardwareKeyIntent.intent(for: ctrlCmdC, isComposing: false), .shortcut(.toggleRomanization))
        XCTAssertEqual(HardwareKeyIntent.intent(for: ctrlCmdC, isComposing: true), .shortcut(.toggleRomanization))
    }

    func testARecordedChord_reachesItsAction_andAnUnrecordedModifierStillFallsToTheHost() throws {
        let optionReturn = try HardwareKeyChord.make(key: "\r", modifiers: .alternate).get()
        let bindings = HardwareKeyBindings(composing: [.pageForward: optionReturn])
        let press = key("\r", code: .keyboardReturnOrEnter, modifiers: .alternate)
        XCTAssertEqual(
            HardwareKeyIntent.intent(for: press, isComposing: true, isShowingCandidates: true, bindings: bindings),
            .navigate(.pageForward),
        )
        // The default table has nothing on ⌥Return, so it is the host's.
        XCTAssertEqual(HardwareKeyIntent.intent(for: press, isComposing: true, isShowingCandidates: true), .commitThenPassThrough)
        // A cleared row: `]` types a bracket even with the bar up.
        let cleared = HardwareKeyBindings(composing: [.pageForward: nil])
        XCTAssertEqual(
            HardwareKeyIntent.intent(for: key("]", code: .keyboardCloseBracket), isComposing: true, isShowingCandidates: true, bindings: cleared),
            .input("]"),
        )
    }

    func testAnUnboundReturn_stillEndsTheComposition() throws {
        // ⇧Return moved onto paging; Return stays on confirm; bare Return
        // with no bar up is not a confirm, and falls to the fixed rule.
        let enter = key("\r", code: .keyboardReturnOrEnter)
        XCTAssertEqual(HardwareKeyIntent.intent(for: enter, isComposing: true), .commitLiteral)
    }

    func testBrackets_pageWhileTheBarIsUp_andTypeOtherwise() {
        let open = key("[", code: .keyboardOpenBracket)
        let close = key("]", code: .keyboardCloseBracket)
        XCTAssertEqual(HardwareKeyIntent.intent(for: open, isComposing: true, isShowingCandidates: true), .navigate(.pageBackward))
        XCTAssertEqual(HardwareKeyIntent.intent(for: close, isComposing: true, isShowingCandidates: true), .navigate(.pageForward))
        XCTAssertEqual(HardwareKeyIntent.intent(for: close, isComposing: true), .input("]"))
    }

    // MARK: - Host chords

    func testHostChords_commitFirstWhileComposing_andPassThroughIdle() {
        for modifier in [UIKeyModifierFlags.command, .control, .alternate] {
            let chord = key("a", code: .keyboardA, modifiers: modifier)
            XCTAssertEqual(HardwareKeyIntent.intent(for: chord, isComposing: true, isShowingCandidates: true), .commitThenPassThrough)
            XCTAssertEqual(HardwareKeyIntent.intent(for: chord, isComposing: false), .passThrough)
        }
    }

    func testControlThree_isNotEscape_norASlotKey() {
        // Control rewrites the characters of chorded digits; the key code is
        // what says which key was pressed.
        let chord = key("\u{1B}", ignoringModifiers: "3", code: .keyboard3, modifiers: .control)
        XCTAssertEqual(HardwareKeyIntent.intent(for: chord, isComposing: true, isShowingCandidates: true), .commitThenPassThrough)
    }

    func testCapsLockAndKeypad_doNotMakeAChord() {
        let capsQ = key("Q", ignoringModifiers: "Q", code: .keyboardQ, modifiers: .alphaShift)
        XCTAssertEqual(HardwareKeyIntent.intent(for: capsQ, isComposing: true, isShowingCandidates: true), .selectCandidateSlot(0, flip: false))
        let keypadFive = key("5", code: .keypad5, modifiers: .numericPad)
        XCTAssertEqual(HardwareKeyIntent.intent(for: keypadFive, isComposing: true), .input("5"))
    }

    func testNamedKeys_areTheHosts_afterTheCompositionEnds() {
        // Whatever string UIKit reports for a named key, the position decides.
        let leftNamed = key(UIKeyCommand.inputLeftArrow, code: .keyboardLeftArrow)
        XCTAssertEqual(HardwareKeyIntent.intent(for: leftNamed, isComposing: true), .commitThenPassThrough)
        XCTAssertEqual(HardwareKeyIntent.intent(for: leftNamed, isComposing: true, isShowingCandidates: true), .navigate(.previous))
        let f5 = key("\u{F708}", code: .keyboardF5)
        XCTAssertEqual(HardwareKeyIntent.intent(for: f5, isComposing: true, isShowingCandidates: true), .commitThenPassThrough)
        XCTAssertEqual(HardwareKeyIntent.intent(for: f5, isComposing: false), .passThrough)
        let home = key("", code: .keyboardHome)
        XCTAssertEqual(HardwareKeyIntent.intent(for: home, isComposing: true), .commitThenPassThrough)
    }
}
