// What one hardware key press means to the composition. Pure classification.

import UIKit

/// One step through the candidate bar, as a hardware key asks for it.
///
/// Named outcomes rather than raw directions: the iOS bar is one scrolling
/// row, so `↑` / `↓` have no second axis to move on and read as a page like
/// PgUp / PgDn do (`HardwareCandidatePage`).
enum HardwareCandidateNavigation: Equatable {
    case previous
    case next
    case pageBackward
    case pageForward
}

/// The composing meaning of a hardware key, decided before any engine call.
///
/// The key contract of the iPad external keyboard, kept in one table so it can
/// be read — and pinned by `HardwareKeyIntentTests` — on its own. Mirrors the
/// desktop's `ComposingKeyIntent` tier by tier; where iOS reads a key
/// differently the case says why.
//
// CROSS-PLATFORM INVARIANT — mirrors
// `macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyIntent.swift`
// (`intent(for:isComposing:isShowingCandidates:bindings:)`) with the shipped
// `ComposingAction` defaults baked in: ⇥ / ⇧⇥ walk, `[` / `]` page, Return
// confirms, ⇧Return commits the literal. The slot keys are
// `CandidateSlotKeySet.bareKeys` (`ComposingKeyBindings.swift`).
enum HardwareKeyIntent: Equatable {
    /// Characters to hand to the composition — or to the document, when no
    /// composition is running: the on-screen key path already decides which
    /// (`ActionHandler.handleCharacterInput`), and the hardware path reuses
    /// it so the two cannot drift. Carried as typed, capitals included; the
    /// dispatcher turns the case into the `letterCase` the engine's case
    /// transform takes.
    case input(String)
    case space
    /// Take one character back — from the composition while one runs, from
    /// the document otherwise. Always ours, unlike the desktop's idle
    /// pass-through: on iOS the extension is the document's only writer, and
    /// the on-screen key re-predicts NextWord after an idle delete
    /// (`ActionHandler.handleBackspaceAction`), which a hardware delete must
    /// do too.
    case deleteBackward
    /// Abandon the composition without writing to the document.
    case cancel
    /// Commit whichever cell the bar has highlighted — the literal when that
    /// is slot 0 — or, idle, whatever Return does on screen (a newline).
    case confirmHighlighted
    /// Commit the romanization exactly as typed, ignoring the highlight.
    case commitLiteral
    /// Move the highlight along the bar.
    case navigate(HardwareCandidateNavigation)
    /// Commit the candidate in this slot of the visible page, counting from
    /// zero — what the bare slot keys address.
    case selectCandidateSlot(Int)
    /// The host must receive this press, and the composition has to be
    /// finished into the document first — a ⌘ / ⌃ / ⌥ chord is about to act
    /// on the document.
    case commitThenPassThrough
    /// Not ours — the press goes on up the responder chain.
    case passThrough

    /// The chords the host owns.
    static let hostChords: UIKeyModifierFlags = [.command, .control, .alternate]

    /// The four chording modifiers — what a key combination is made of.
    static let chordingModifiers: UIKeyModifierFlags = hostChords.union(.shift)

    /// The nine bare keys that pick slots 0…8 while the bar is up — every
    /// letter no TL or POJ syllable spells, plus `;`. Lowercase, as they are
    /// matched and drawn.
    // CROSS-PLATFORM INVARIANT — `CandidateSlotKeySet.bareKeyRow`
    // (`macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyBindings.swift`).
    static let slotKeyRow = ["q", "w", "d", "f", "z", "x", "v", "y", ";"]

    /// Classifies `key` for a session whose composition is or is not active,
    /// and whose candidate bar is or is not on screen.
    ///
    /// `isComposing` changes the meaning of Escape and Return; `isShowingCandidates`
    /// is what gives the arrows, the paging keys and the slot keys to the bar.
    /// A composition can run with no bar up (the fetch is asynchronous), but
    /// not the other way round.
    static func intent(
        for key: HardwareKeySnapshot,
        isComposing: Bool,
        isShowingCandidates: Bool = false,
    ) -> HardwareKeyIntent {
        let modifiers = key.chordingModifiers
        let hasHostChord = !modifiers.isDisjoint(with: hostChords)

        // The fixed tier: the way through the candidates, the way out of the
        // composition, and the way to take a character back. Shift is
        // excluded from the arrows on purpose — ⇧← is the host's selection.
        if isShowingCandidates, !hasHostChord, !modifiers.contains(.shift),
           let navigation = navigation(forNavigationKey: key.keyCode)
        {
            return .navigate(navigation)
        }
        if !hasHostChord {
            switch key.keyCode {
            case .keyboardEscape:
                return isComposing ? .cancel : .passThrough
            case .keyboardDeleteOrBackspace:
                return .deleteBackward
            case .keyboardReturnOrEnter, .keypadEnter:
                return isComposing && modifiers == .shift ? .commitLiteral : .confirmHighlighted
            case .keyboardTab:
                guard isShowingCandidates else { return hostKey(isComposing: isComposing) }
                return .navigate(modifiers == .shift ? .previous : .next)
            default:
                break
            }
        }

        // The slot keys and the paging brackets (the system candidate
        // window's `[` / `]`), bare only: ⇧Q is the capital the composition
        // takes as text, and ⌃3 is the host's.
        if isShowingCandidates, modifiers.isEmpty {
            let bareKey = key.charactersIgnoringModifiers.lowercased()
            switch bareKey {
            case "[": return .navigate(.pageBackward)
            case "]": return .navigate(.pageForward)
            default:
                if let slot = slotKeyRow.firstIndex(of: bareKey) {
                    return .selectCandidateSlot(slot)
                }
            }
        }

        if hasHostChord {
            return hostKey(isComposing: isComposing)
        }

        if key.keyCode == .keyboardSpacebar || key.characters == " " {
            return .space
        }
        guard !key.characters.isEmpty,
              key.characters.unicodeScalars.allSatisfy(isTextScalar)
        else {
            // A named key this table does not bind — F-keys, Home, End, the
            // arrows with no bar up or under ⇧ — is the host's.
            return hostKey(isComposing: isComposing)
        }
        return .input(key.characters)
    }

    /// A key the host owns. It still ends any composition first, so the host
    /// never acts on a document with an unfinished one in it — the host is
    /// about to move the caret or the selection, and a composition left
    /// running would be re-rendered somewhere it does not belong.
    // CROSS-PLATFORM INVARIANT — `ComposingKeyIntent.hostKey(isComposing:)`.
    private static func hostKey(isComposing: Bool) -> HardwareKeyIntent {
        isComposing ? .commitThenPassThrough : .passThrough
    }

    private static func navigation(forNavigationKey keyCode: UIKeyboardHIDUsage) -> HardwareCandidateNavigation? {
        switch keyCode {
        case .keyboardLeftArrow: .previous
        case .keyboardRightArrow: .next
        case .keyboardUpArrow, .keyboardPageUp: .pageBackward
        case .keyboardDownArrow, .keyboardPageDown: .pageForward
        default: nil
        }
    }

    /// UIKit reports the arrows and the function keys as private-use scalars
    /// (`UIKeyCommand.inputUpArrow` is U+F700), so a scalar check alone would
    /// let F5 through as composition input.
    private static let functionKeyRange: ClosedRange<UInt32> = 0xF700 ... 0xF8FF

    private static let controlCharacters = CharacterSet.controlCharacters

    private static func isTextScalar(_ scalar: Unicode.Scalar) -> Bool {
        !controlCharacters.contains(scalar) && !functionKeyRange.contains(scalar.value)
    }
}
