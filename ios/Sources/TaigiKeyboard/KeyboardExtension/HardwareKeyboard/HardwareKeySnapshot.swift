// The parts of one hardware key press a composing decision is made from.

import UIKit

/// A value built from `UIPress.key`, so the classification can be reasoned
/// about — and tested — without a `UIPress`, which only UIKit can construct.
///
/// Mirrors the desktop's `KeyEventSnapshot`
/// (`macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyIntent.swift`):
/// the characters the key types, what it would type with no modifiers held,
/// the key's position, and the modifiers. On iOS the position is the HID
/// usage (`UIKey.keyCode`) rather than a virtual key code, and the named
/// keys — arrows, Escape, Backspace, Return, Tab — are recognized by it
/// rather than by control characters, which is what Apple's own guide does
/// (developer.apple.com/documentation/uikit/handling-key-presses-made-on-a-physical-keyboard).
struct HardwareKeySnapshot: Equatable {
    let characters: String
    /// What the same key types with no modifiers held. Read for the slot keys
    /// and the paging brackets so a chord on the same key is still recognized
    /// as that key.
    let charactersIgnoringModifiers: String
    let keyCode: UIKeyboardHIDUsage
    let modifiers: UIKeyModifierFlags

    init(
        characters: String,
        charactersIgnoringModifiers: String? = nil,
        keyCode: UIKeyboardHIDUsage,
        modifiers: UIKeyModifierFlags = [],
    ) {
        self.characters = characters
        self.charactersIgnoringModifiers = charactersIgnoringModifiers ?? characters
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(_ key: UIKey) {
        self.init(
            characters: key.characters,
            charactersIgnoringModifiers: key.charactersIgnoringModifiers,
            keyCode: key.keyCode,
            modifiers: key.modifierFlags,
        )
    }

    /// Only the four chording modifiers. Caps Lock and the number pad say how
    /// a key was reached, not which key it is — the same reading the desktop
    /// classifier makes (`ComposingKeyIntent.chordingModifiers`).
    var chordingModifiers: UIKeyModifierFlags {
        modifiers.intersection(HardwareKeyIntent.chordingModifiers)
    }
}
