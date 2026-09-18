// One recordable key combination, and the keys a binding may never claim.

import UIKit

/// A key plus its modifiers, as a composing action or a shortcut can be
/// bound to it. The iOS twin of the desktop's `ComposingKeyChord`, stored in
/// the same `"<modifiers>|<scalars>"` form so a chord reads the same in either
/// app's defaults.
///
/// Constructing one is where the typing keys are defended: `make` refuses any
/// chord that would take away a key the user composes with, so a corrupt
/// defaults value cannot produce a binding that swallows the letters of a
/// syllable — the classifier never has to re-check.
// CROSS-PLATFORM INVARIANT — mirrors
// `macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyChord.swift`
// (`make`, `normalized`, `isTypingKey`, `RawRepresentable`).
struct HardwareKeyChord: Hashable {
    /// What the key types with no modifiers held, lowercased for ASCII so
    /// `⇧[` and `[` cannot be recorded as two different chords on the same key.
    let key: String
    /// Only the four chording modifiers (`HardwareKeyIntent.chordingModifiers`).
    let modifiers: UIKeyModifierFlags

    private init(key: String, modifiers: UIKeyModifierFlags) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Why a key could not be recorded, so the recorder can say so.
    enum Rejection: Error, Equatable {
        /// A letter, a digit, the hyphen or `;` with no ⌘/⌃/⌥ held — the keys
        /// a composition is typed or picked with.
        case typesRomanization
        /// Backspace, Escape, the arrows or the paging keys, which the input
        /// method reserves whatever modifiers are held.
        case reservedKey
        /// A press carrying no character to bind.
        case noKey
    }

    /// The fixed navigation contract (`HardwareKeyIntent`): a binding must not
    /// shadow these even WITH a modifier.
    private static let neverBindable: Set<String> = [
        UIKeyCommand.inputLeftArrow, UIKeyCommand.inputRightArrow,
        UIKeyCommand.inputUpArrow, UIKeyCommand.inputDownArrow,
        UIKeyCommand.inputPageUp, UIKeyCommand.inputPageDown,
        "\u{8}", // Backspace
        "\u{7F}", // Delete
        "\u{1B}", // Escape
    ]

    /// The chord `key` and `modifiers` name, or why it cannot be one.
    static func make(key rawKey: String?, modifiers rawModifiers: UIKeyModifierFlags)
        -> Result<HardwareKeyChord, Rejection>
    {
        guard let rawKey, !rawKey.isEmpty else { return .failure(.noKey) }
        // Checked before the case fold: UIKit's names for the arrows
        // (`UIKeyCommand.inputLeftArrow`) are strings a fold would alter.
        guard !neverBindable.contains(rawKey) else { return .failure(.reservedKey) }
        let key = normalized(rawKey)

        let modifiers = rawModifiers.intersection(HardwareKeyIntent.chordingModifiers)
        // Shift alone does not make a chord out of a typing key: ⇧A is still
        // the letter A, and binding it would cost the user their capitals.
        let hasChordingModifier = !modifiers.isDisjoint(with: HardwareKeyIntent.hostChords)
        if !hasChordingModifier, let first = key.first, isTypingKey(first) {
            return .failure(.typesRomanization)
        }
        return .success(HardwareKeyChord(key: key, modifiers: modifiers))
    }

    /// The chord this press would record, or why it cannot be recorded.
    ///
    /// A shifted number-row key or `;` is refused as the key it is: `⇧3`
    /// types `#` on a US layout, and only the key code still says which key
    /// was pressed — the same reading `HardwareKeyIntent` picks the shifted
    /// slot by.
    static func make(_ key: HardwareKeySnapshot) -> Result<HardwareKeyChord, Rejection> {
        // The key's position is what says it is a named key, whatever string
        // UIKit reports for it.
        guard !HardwareKeyIntent.isNamedKey(key.keyCode) else { return .failure(.reservedKey) }
        if key.chordingModifiers == .shift, Self.isShiftedTypingKeyCode(key.keyCode) {
            return .failure(.typesRomanization)
        }
        return make(key: key.charactersIgnoringModifiers, modifiers: key.modifiers)
    }

    /// The chord `press` would be looked up as — built on the unmodified
    /// characters for the same reason they are stored: Control rewrites the
    /// digits it is held with, and Option rewrites most of the keyboard.
    /// Ungated, since it is a key rather than a binding.
    init(pressed press: HardwareKeySnapshot) {
        key = Self.normalized(press.charactersIgnoringModifiers)
        modifiers = press.chordingModifiers
    }

    /// Whether `press` is this chord.
    func matches(_ press: HardwareKeySnapshot) -> Bool {
        HardwareKeyChord(pressed: press) == self
    }

    /// The number row `1`…`9` and `;` — the keys whose shifted form still
    /// means the key itself (`HardwareKeyIntent.shiftedSlotKeyCodes`).
    static func isShiftedTypingKeyCode(_ code: UIKeyboardHIDUsage) -> Bool {
        HardwareKeyIntent.numberRowKeyCodes.contains(code) || code == .keyboardSemicolon
    }

    /// The form a key is stored and compared in: ASCII lowercased, the
    /// keypad's Enter folded onto Return and a back tab onto Tab.
    static func normalized(_ key: String) -> String {
        switch key {
        case "\u{3}": "\r" // Keypad Enter
        case "\u{19}": "\t" // Back tab
        default: key.lowercased()
        }
    }

    /// The keys a composition is typed or picked with: all 26 ASCII letters,
    /// the digits, the hyphen and `;` (the slot keys are letters and `;`).
    private static func isTypingKey(_ character: Character) -> Bool {
        guard character.isASCII else { return false }
        return character.isLetter || character.isNumber || character == "-" || character == ";"
    }
}

extension HardwareKeyChord: RawRepresentable {
    /// `"<modifiers>|<scalars>"` — modifier letters in a fixed order (`d`
    /// command, `c` control, `o` option, `s` shift), then the key's Unicode
    /// scalars in hex. The desktop's encoding, byte for byte.
    var rawValue: String {
        var letters = ""
        if modifiers.contains(.command) { letters += "d" }
        if modifiers.contains(.control) { letters += "c" }
        if modifiers.contains(.alternate) { letters += "o" }
        if modifiers.contains(.shift) { letters += "s" }
        let scalars = key.unicodeScalars
            .map { String(format: "%04X", $0.value) }
            .joined(separator: ",")
        return "\(letters)|\(scalars)"
    }

    init?(rawValue: String) {
        let halves = rawValue.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard halves.count == 2 else { return nil }

        var modifiers: UIKeyModifierFlags = []
        for letter in halves[0] {
            switch letter {
            case "d": modifiers.insert(.command)
            case "c": modifiers.insert(.control)
            case "o": modifiers.insert(.alternate)
            case "s": modifiers.insert(.shift)
            default: return nil
            }
        }

        var key = ""
        for field in halves[1].split(separator: ",") {
            guard let value = UInt32(field, radix: 16),
                  let scalar = UnicodeScalar(value) else { return nil }
            key.unicodeScalars.append(scalar)
        }

        // Back through the same gate the recorder goes through, so a
        // hand-edited defaults value cannot install a binding the recorder
        // would have refused.
        guard case let .success(chord) = Self.make(key: key, modifiers: modifiers) else {
            return nil
        }
        self = chord
    }
}

/// How a recorded chord reads on screen: `⌃⌥⇧⌘` in the Mac's order, then
/// the keycap legend — the same vocabulary the desktop pane prints.
enum HardwareKeyChordDisplay {
    private static let keyNames: [String: String] = [
        " ": "Space",
        "\r": "↩",
        "\t": "⇥",
    ]

    static func text(for chord: HardwareKeyChord) -> String {
        var glyphs = ""
        if chord.modifiers.contains(.control) { glyphs += "⌃" }
        if chord.modifiers.contains(.alternate) { glyphs += "⌥" }
        if chord.modifiers.contains(.shift) { glyphs += "⇧" }
        if chord.modifiers.contains(.command) { glyphs += "⌘" }
        // A chord with modifiers keeps the uppercase keycap legend; a bare
        // key shows the character it types.
        let keycap = keyNames[chord.key]
            ?? (chord.modifiers.isEmpty ? chord.key : chord.key.uppercased())
        return glyphs + keycap
    }
}
