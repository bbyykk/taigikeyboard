@testable import TaigiKeyboard
import UIKit
import XCTest

/// Pins the recordable-chord gate and its storage form — the iOS mirror of
/// the desktop's `ComposingKeyBindingsTests` chord half.
final class HardwareKeyChordTests: XCTestCase {
    private func chord(_ key: String, _ modifiers: UIKeyModifierFlags = []) throws -> HardwareKeyChord {
        try HardwareKeyChord.make(key: key, modifiers: modifiers).get()
    }

    func testTypingKeys_cannotBeRecordedBare_orWithShiftAlone() {
        for key in ["a", "Z", "5", "-", ";", "q"] {
            XCTAssertEqual(HardwareKeyChord.make(key: key, modifiers: []).failure, .typesRomanization, key)
            XCTAssertEqual(HardwareKeyChord.make(key: key, modifiers: .shift).failure, .typesRomanization, "⇧\(key)")
        }
    }

    func testTypingKeys_canBeRecordedWithAChordingModifier() throws {
        XCTAssertEqual(try chord("c", [.control, .command]).key, "c")
        XCTAssertEqual(try chord("C", .alternate).key, "c", "capitals fold to their letter")
    }

    func testBarePunctuationAndNamedKeys_canBeRecordedBare() throws {
        for key in ["[", "]", " ", "\r", "\t", "`", ","] {
            XCTAssertEqual(try chord(key).key, key)
        }
    }

    func testReservedKeys_cannotBeRecordedAtAll() {
        for key in [UIKeyCommand.inputLeftArrow, UIKeyCommand.inputPageDown, "\u{8}", "\u{7F}", "\u{1B}"] {
            XCTAssertEqual(HardwareKeyChord.make(key: key, modifiers: [.control, .command]).failure, .reservedKey, key)
        }
        // By position too: whatever string UIKit reports for a named key.
        for code in [UIKeyboardHIDUsage.keyboardLeftArrow, .keyboardPageUp, .keyboardHome, .keyboardF5, .keyboardEscape, .keyboardDeleteOrBackspace] {
            let press = HardwareKeySnapshot(characters: "x", keyCode: code, modifiers: .alternate)
            XCTAssertEqual(HardwareKeyChord.make(press).failure, .reservedKey, "\(code)")
        }
        XCTAssertEqual(HardwareKeyChord.make(key: "", modifiers: []).failure, .noKey)
        XCTAssertEqual(HardwareKeyChord.make(key: nil, modifiers: []).failure, .noKey)
    }

    func testKeypadEnterAndBackTab_foldOntoReturnAndTab() throws {
        XCTAssertEqual(try chord("\u{3}"), try chord("\r"))
        XCTAssertEqual(try chord("\u{19}", .shift), try chord("\t", .shift))
    }

    func testRecording_dropsTheNonChordingModifiers() throws {
        XCTAssertEqual(try chord("\r", [.alphaShift, .numericPad, .shift]).modifiers, .shift)
    }

    func testAShiftedNumberRowKey_isRefusedAsTheDigitItIs() {
        let shiftThree = HardwareKeySnapshot(characters: "#", charactersIgnoringModifiers: "#", keyCode: .keyboard3, modifiers: .shift)
        XCTAssertEqual(HardwareKeyChord.make(shiftThree).failure, .typesRomanization)
        let shiftSemicolon = HardwareKeySnapshot(characters: ":", charactersIgnoringModifiers: ":", keyCode: .keyboardSemicolon, modifiers: .shift)
        XCTAssertEqual(HardwareKeyChord.make(shiftSemicolon).failure, .typesRomanization)
    }

    func testChords_roundTripThroughTheirRawValue_inTheDesktopsEncoding() throws {
        let cases: [(HardwareKeyChord, String)] = [
            (try chord("\t"), "|0009"),
            (try chord("\t", .shift), "s|0009"),
            (try chord("\r", .shift), "s|000D"),
            (try chord(" "), "|0020"),
            (try chord("c", [.control, .command]), "dc|0063"),
            (try chord("`"), "|0060"),
            (try chord("]", .alternate), "o|005D"),
        ]
        for (chord, raw) in cases {
            XCTAssertEqual(chord.rawValue, raw)
            XCTAssertEqual(HardwareKeyChord(rawValue: raw), chord)
        }
    }

    func testRawValues_thatWouldTakeATypingKey_doNotParse() {
        XCTAssertNil(HardwareKeyChord(rawValue: "|0061"), "bare a")
        XCTAssertNil(HardwareKeyChord(rawValue: "s|0035"), "⇧5")
        XCTAssertNil(HardwareKeyChord(rawValue: "x|0020"), "unknown modifier letter")
        XCTAssertNil(HardwareKeyChord(rawValue: ""), "a cleared row")
    }

    func testAChordMatches_onlyItsOwnKeyAndModifiers() throws {
        let tab = try chord("\t")
        XCTAssertTrue(tab.matches(HardwareKeySnapshot(characters: "\t", keyCode: .keyboardTab)))
        XCTAssertTrue(tab.matches(HardwareKeySnapshot(characters: "\t", keyCode: .keyboardTab, modifiers: .alphaShift)))
        XCTAssertFalse(tab.matches(HardwareKeySnapshot(characters: "\t", keyCode: .keyboardTab, modifiers: .shift)))
        let ctrlCmdC = try chord("c", [.control, .command])
        // Control rewrites the character; the unmodified one still matches.
        XCTAssertTrue(ctrlCmdC.matches(HardwareKeySnapshot(characters: "\u{3}", charactersIgnoringModifiers: "c", keyCode: .keyboardC, modifiers: [.control, .command])))
    }

    func testDisplay_printsTheMacsGlyphsAndKeycaps() throws {
        XCTAssertEqual(HardwareKeyChordDisplay.text(for: try chord("\t", .shift)), "⇧⇥")
        XCTAssertEqual(HardwareKeyChordDisplay.text(for: try chord("\r")), "↩")
        XCTAssertEqual(HardwareKeyChordDisplay.text(for: try chord(" ")), "Space")
        XCTAssertEqual(HardwareKeyChordDisplay.text(for: try chord("c", [.control, .command])), "⌃⌘C")
        XCTAssertEqual(HardwareKeyChordDisplay.text(for: try chord("`")), "`")
    }
}

private extension Result where Failure == HardwareKeyChord.Rejection {
    var failure: HardwareKeyChord.Rejection? {
        if case let .failure(reason) = self { return reason }
        return nil
    }
}
