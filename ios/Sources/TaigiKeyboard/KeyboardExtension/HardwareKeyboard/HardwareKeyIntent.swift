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
// (`intent(for:isComposing:isShowingCandidates:bindings:)`). The slot keys
// are `CandidateSlotKeySet.bareKeys` (`ComposingKeyBindings.swift`); the
// user-bindable tier is `HardwareKeyBindings`.
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
    /// Commit the highlighted candidate in the script the output settings do
    /// NOT lead with — the 漢羅 key, so a romanized word inside a 漢字
    /// sentence costs one key rather than a mode flip and back.
    case commitAlternateScript
    /// Move the highlight along the bar.
    case navigate(HardwareCandidateNavigation)
    /// Step the caret inside the romanization being typed, so the next
    /// character lands there — `ka2`, ⌥← ⌥←, `h` → `kha2`. The engine owns
    /// the caret (`ComposingManager.moveCaret`); the bar is left as it is.
    case moveCaret(CaretDirection)
    /// Commit the candidate in this slot of the visible page, counting from
    /// zero — what the bare slot keys address. With `flip`, in the other
    /// script: the 漢羅 key aimed at a slot, which is what ⇧ on the same key
    /// asks.
    case selectCandidateSlot(Int, flip: Bool)
    /// One of the switches a key can flip whether or not a composition runs.
    case shortcut(HardwareShortcutAction)
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

    /// The modifier under which ← / → step the composing caret — the host's
    /// own word-jump chord, and the one chord that is neither a candidate
    /// key (the bare arrows) nor one the system takes first. Fixed, not
    /// recordable; the 快速齒 pane draws its read-only row from this value.
    // CROSS-PLATFORM INVARIANT — `ComposingKeyIntent.caretChordModifiers`.
    static let caretChordModifiers: UIKeyModifierFlags = [.alternate]

    /// The nine bare keys that pick slots 0…8 while the bar is up — every
    /// letter no TL or POJ syllable spells, plus `;`. Lowercase, as they are
    /// matched and drawn.
    // CROSS-PLATFORM INVARIANT — `CandidateSlotKeySet.bareKeyRow`
    // (`macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyBindings.swift`).
    static let slotKeyRow = ["q", "w", "d", "f", "z", "x", "v", "y", ";"]

    /// The `1`…`9` keys of the number row, in digit order — positions, so a
    /// shifted press still names its digit (`HardwareKeyChord.make(_:)`).
    static let numberRowKeyCodes: [UIKeyboardHIDUsage] = [
        .keyboard1, .keyboard2, .keyboard3, .keyboard4, .keyboard5,
        .keyboard6, .keyboard7, .keyboard8, .keyboard9,
    ]

    /// Classifies `key` for a session whose composition is or is not active,
    /// and whose candidate bar is or is not on screen, against the user's
    /// `bindings`.
    ///
    /// `isComposing` changes the meaning of Escape and Return;
    /// `isShowingCandidates` is what gives the arrows, the paging keys and the
    /// slot keys to the bar. A composition can run with no bar up (the fetch
    /// is asynchronous), but not the other way round.
    static func intent(
        for key: HardwareKeySnapshot,
        isComposing: Bool,
        isShowingCandidates: Bool = false,
        bindings: HardwareKeyBindings = .default,
    ) -> HardwareKeyIntent {
        let modifiers = key.chordingModifiers
        let hasHostChord = !modifiers.isDisjoint(with: hostChords)

        // The caret inside the composition, on ⌥← / ⌥→. Exactly ⌥: ⌥⇧←
        // stays the host's selection, ⌥⌘← its shortcut. Idle, the chord is
        // the host's.
        if isComposing, modifiers == caretChordModifiers {
            switch key.keyCode {
            case .keyboardLeftArrow: return .moveCaret(.left)
            case .keyboardRightArrow: return .moveCaret(.right)
            default: break
            }
        }

        // The fixed tier, read before anything the user can rebind so that
        // no binding can shadow it: the way through the candidates, the way
        // out of the composition, and the way to take a character back.
        // Shift is excluded from the arrows on purpose — ⇧← is the host's
        // selection.
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
            default:
                break
            }
        }

        // The switches, wherever the composition stands — the desktop fires
        // these as global hotkeys, above the composing tier.
        if let shortcut = bindings.shortcutAction(for: key) {
            return .shortcut(shortcut)
        }

        // The slot keys, read before the user's bindings so that no binding
        // can shadow them. Bare only: ⇧Q is the capital the composition takes
        // as text, and ⌃3 is the host's — except exactly ⇧, which aims the
        // 漢羅 key at the slot.
        if isShowingCandidates {
            if modifiers.isEmpty, let slot = slot(for: key) {
                return .selectCandidateSlot(slot, flip: false)
            }
            if modifiers == .shift, let slot = shiftedSlot(for: key) {
                return .selectCandidateSlot(slot, flip: true)
            }
        }

        // What the user put on this key. Only an EXACT match does: an
        // unrecorded ⌥ chord still falls to the host below, because the
        // exception is the binding, not the modifier. A chord whose action
        // needs the bar is not consumed without one, so `]` still types a
        // bracket and Space still spaces.
        if isComposing, let action = bindings.composingAction(for: key),
           isShowingCandidates || !action.requiresCandidates
        {
            return action.intent
        }

        // A key the host owns still ends any composition first, so the host
        // never acts on a document with an unfinished one in it.
        if hasHostChord {
            return hostKey(isComposing: isComposing)
        }

        switch key.keyCode {
        case .keyboardReturnOrEnter, .keypadEnter:
            // Idle Return is the on-screen Return's newline (`.confirmHighlighted`
            // with no highlight); mid-composition it reached here only
            // unbound, and then ends the composition as typed, as ⇧Return
            // would — the composition must not swallow the key that sends.
            return isComposing ? .commitLiteral : .confirmHighlighted
        case .keyboardSpacebar:
            return .space
        default:
            break
        }
        guard !isNamedKey(key.keyCode),
              !key.characters.isEmpty,
              !key.characters.unicodeScalars.contains(where: controlCharacters.contains)
        else {
            // A named key this table does not bind — F-keys, Home, End, Tab
            // with no bar up, the arrows with no bar up or under ⇧ — is the
            // host's.
            return hostKey(isComposing: isComposing)
        }
        return .input(key.characters)
    }

    /// The keys that name an action rather than a character — Escape,
    /// Backspace, Caps Lock, F1…F24, Insert / Home / End / PgUp / PgDn /
    /// Delete-forward and the arrows — by HID position, because the string
    /// UIKit reports for them (`UIKeyCommand.inputLeftArrow`) is not a
    /// character either. Return, Tab and Space are typed keys and not here.
    static func isNamedKey(_ code: UIKeyboardHIDUsage) -> Bool {
        switch code.rawValue {
        case UIKeyboardHIDUsage.keyboardEscape.rawValue ... UIKeyboardHIDUsage.keyboardDeleteOrBackspace.rawValue,
             UIKeyboardHIDUsage.keyboardCapsLock.rawValue ... UIKeyboardHIDUsage.keyboardUpArrow.rawValue,
             UIKeyboardHIDUsage.keyboardF13.rawValue ... UIKeyboardHIDUsage.keyboardF24.rawValue:
            true
        default:
            false
        }
    }

    /// The slot `key` picks bare, or nil — read in the form a chord is
    /// (`HardwareKeyChord.normalized`), so the two readers cannot drift.
    private static func slot(for key: HardwareKeySnapshot) -> Int? {
        slotKeyRow.firstIndex(of: HardwareKeyChord.normalized(key.charactersIgnoringModifiers))
    }

    /// The slot `key` names with exactly ⇧ held. `;` is read off its key
    /// code, because `⇧;` types `:` and only the position still says which
    /// key was pressed; the letters read as their capital, which the case
    /// fold handles.
    private static func shiftedSlot(for key: HardwareKeySnapshot) -> Int? {
        if key.keyCode == .keyboardSemicolon {
            return slotKeyRow.count - 1
        }
        return slot(for: key)
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

    /// A key the host owns. It still ends any composition first, so the host
    /// never acts on a document with an unfinished one in it — the host is
    /// about to move the caret or the selection, and a composition left
    /// running would be re-rendered somewhere it does not belong.
    // CROSS-PLATFORM INVARIANT — `ComposingKeyIntent.hostKey(isComposing:)`.
    private static func hostKey(isComposing: Bool) -> HardwareKeyIntent {
        isComposing ? .commitThenPassThrough : .passThrough
    }

    /// Hoisted: `CharacterSet.controlCharacters` materializes a bridged set
    /// on each access.
    private static let controlCharacters = CharacterSet.controlCharacters
}
