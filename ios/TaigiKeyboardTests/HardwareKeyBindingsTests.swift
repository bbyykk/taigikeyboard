@testable import TaigiKeyboard
import UIKit
import XCTest

/// Pins how stored chords resolve into the contract the classifier reads.
final class HardwareKeyBindingsTests: XCTestCase {
    private func chord(_ key: String, _ modifiers: UIKeyModifierFlags = []) throws -> HardwareKeyChord {
        try HardwareKeyChord.make(key: key, modifiers: modifiers).get()
    }

    func testDefaults_followTheDesktop_andLeaveNoActionUnbound() throws {
        let bindings = HardwareKeyBindings.default
        XCTAssertEqual(bindings.chord(for: .nextCandidate), try chord("\t"))
        XCTAssertEqual(bindings.chord(for: .previousCandidate), try chord("\t", .shift))
        XCTAssertEqual(bindings.chord(for: .pageForward), try chord("]"))
        XCTAssertEqual(bindings.chord(for: .pageBackward), try chord("["))
        XCTAssertEqual(bindings.chord(for: .confirmHighlighted), try chord("\r"))
        XCTAssertEqual(bindings.chord(for: .commitLiteral), try chord("\r", .shift))
        XCTAssertEqual(bindings.chord(for: .commitAlternateScript), try chord(" "))
        XCTAssertEqual(bindings.chord(for: .toggleRomanization), try chord("c", [.control, .command]))
        XCTAssertEqual(bindings.chord(for: .cycleCandidateDisplayMode), try chord("h", [.control, .command]))
        XCTAssertEqual(bindings.chord(for: .toggleTranslateSwapped), try chord("`"))
        XCTAssertEqual(bindings.chord(for: .showSymbolPicker), try chord(",", [.control, .command]))
    }

    func testShippedDefaults_holdNoChordInCommon() {
        let all = HardwareComposingAction.allCases.map(\.defaultChord) + HardwareShortcutAction.allCases.map(\.defaultChord)
        XCTAssertEqual(Set(all).count, all.count)
    }

    func testAChordRecordedTwice_staysOnTheLastRowOnly_theStoredOneOutranksADefault() throws {
        // The user put Space on paging; the default Space on the 漢羅 row gives way.
        let bindings = HardwareKeyBindings(composing: [.pageForward: try chord(" ")])
        XCTAssertEqual(bindings.chord(for: .pageForward), try chord(" "))
        XCTAssertNil(bindings.chord(for: .commitAlternateScript))
    }

    func testAnAlwaysBoundAction_getsAPoolChordBackWhenCleared() throws {
        let bindings = HardwareKeyBindings(composing: [.confirmHighlighted: nil])
        XCTAssertEqual(bindings.chord(for: .confirmHighlighted), try chord("\r"))
        let swapped = HardwareKeyBindings(composing: [.confirmHighlighted: try chord("\r", .shift), .commitLiteral: try chord("\r")])
        XCTAssertEqual(swapped.chord(for: .confirmHighlighted), try chord("\r", .shift))
        XCTAssertEqual(swapped.chord(for: .commitLiteral), try chord("\r"))
    }

    func testAnOrdinaryRow_cannotHoldAPoolChord_onEitherRoster() throws {
        let bindings = HardwareKeyBindings(
            composing: [.nextCandidate: try chord("\r")],
            shortcuts: [.showSymbolPicker: try chord("\r", .shift)],
        )
        XCTAssertNil(bindings.chord(for: .nextCandidate))
        XCTAssertNil(bindings.chord(for: .showSymbolPicker))
        XCTAssertEqual(bindings.chord(for: .confirmHighlighted), try chord("\r"))
        XCTAssertEqual(bindings.chord(for: .commitLiteral), try chord("\r", .shift))
    }

    func testAChordOnBothRosters_theRowTheUserChoseWins() throws {
        // The user put `]` on a switch; the paging row still on its default gives way.
        let recordedShortcut = HardwareKeyBindings(shortcuts: [.toggleRomanization: try chord("]")])
        XCTAssertEqual(recordedShortcut.chord(for: .toggleRomanization), try chord("]"))
        XCTAssertNil(recordedShortcut.chord(for: .pageForward))
        let press = HardwareKeySnapshot(characters: "]", keyCode: .keyboardCloseBracket)
        XCTAssertEqual(recordedShortcut.shortcutAction(for: press), .toggleRomanization)
        XCTAssertNil(recordedShortcut.composingAction(for: press))
        // The user put ⌃⌘C on paging; the switch still on its default gives way.
        let recordedComposing = HardwareKeyBindings(composing: [.pageForward: try chord("c", [.control, .command])])
        XCTAssertEqual(recordedComposing.chord(for: .pageForward), try chord("c", [.control, .command]))
        XCTAssertNil(recordedComposing.chord(for: .toggleRomanization))
    }

    func testRowsHolding_namesEveryRowARecordingWouldEmpty() throws {
        let bindings = HardwareKeyBindings.default
        let holders = bindings.rowsHolding(try chord("\t"))
        XCTAssertEqual(holders.composing, [.nextCandidate])
        XCTAssertEqual(holders.shortcuts, [])
    }

    func testEveryAction_hasItsOwnSettingsKey_inTheDesktopsNamespace() {
        let keys = HardwareComposingAction.allCases.map(\.settingsKeyName) + HardwareShortcutAction.allCases.map(\.settingsKeyName)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(HardwareComposingAction.confirmHighlighted.settingsKeyName, "composingShortcut.confirmHighlighted")
        XCTAssertEqual(HardwareShortcutAction.toggleRomanization.settingsKeyName, "hardwareShortcut.toggleRomanization")
    }

    func testTheGroups_holdEveryComposingActionExactlyOnce() {
        let grouped = HardwareComposingAction.groups.flatMap { $0 }
        XCTAssertEqual(Set(grouped), Set(HardwareComposingAction.allCases))
        XCTAssertEqual(grouped.count, HardwareComposingAction.allCases.count)
    }
}
