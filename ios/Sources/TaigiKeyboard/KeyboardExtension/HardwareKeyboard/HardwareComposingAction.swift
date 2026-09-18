// The composing actions and shortcuts a user can put on a hardware key of their choosing.

import UIKit

/// One row of the 快速齒 pane, on either roster: what it ships with, where
/// its chord is stored, and what the row is called.
protocol HardwareBindableAction: CaseIterable, Hashable {
    var defaultChord: HardwareKeyChord { get }
    var settingsKeyName: String { get }
    var labelKey: StringKey { get }
}

extension HardwareBindableAction {
    /// A default chord, built through the same gate a recorded one goes
    /// through. Trapping rather than nil: a default the gate refuses is a
    /// mistake in the roster, and shipping it as "unbound" would hide it.
    static func shipped(_ key: String, modifiers: UIKeyModifierFlags = []) -> HardwareKeyChord {
        guard case let .success(chord) = HardwareKeyChord.make(key: key, modifiers: modifiers) else {
            preconditionFailure("default chord for \(key) is not bindable")
        }
        return chord
    }
}

/// One thing the extension does while a composition is running, as the
/// 快速齒 pane names it. Only the actions whose key is the user's to choose
/// are here; the fixed navigation contract (arrows, paging keys, Escape,
/// Backspace) and the slot keys are `HardwareKeyIntent`'s own.
// CROSS-PLATFORM INVARIANT — mirrors
// `macos/Sources/TaigiInputMethodCore/Controller/ComposingAction.swift`:
// same cases, same raw values (the settings key), same defaults, same groups.
enum HardwareComposingAction: String, HardwareBindableAction {
    case nextCandidate
    case previousCandidate
    case pageForward
    case pageBackward
    case confirmHighlighted
    case commitLiteral
    case commitAlternateScript

    /// The chord a fresh install has on this action. ⇥ / ⇧⇥ walk, `]` / `[`
    /// page, Return confirms, ⇧Return keeps what was typed, Space writes the
    /// other script — the desktop's defaults.
    var defaultChord: HardwareKeyChord {
        switch self {
        case .nextCandidate: Self.shipped("\t")
        case .previousCandidate: Self.shipped("\t", modifiers: .shift)
        case .pageForward: Self.shipped("]")
        case .pageBackward: Self.shipped("[")
        case .confirmHighlighted: Self.shipped("\r")
        case .commitLiteral: Self.shipped("\r", modifiers: .shift)
        case .commitAlternateScript: Self.shipped(" ")
        }
    }

    /// Whether this action needs candidates on screen to mean anything. A
    /// chord whose action does not apply is not consumed: `]` still types a
    /// bracket with no page to turn, and Space still spaces.
    var requiresCandidates: Bool {
        self != .commitLiteral
    }

    var intent: HardwareKeyIntent {
        switch self {
        case .nextCandidate: .navigate(.next)
        case .previousCandidate: .navigate(.previous)
        case .pageForward: .navigate(.pageForward)
        case .pageBackward: .navigate(.pageBackward)
        case .confirmHighlighted: .confirmHighlighted
        case .commitLiteral: .commitLiteral
        case .commitAlternateScript: .commitAlternateScript
        }
    }

    /// The roster split into the blocks the pane draws: through the
    /// candidates, then out of the composition.
    static let groups: [[HardwareComposingAction]] = [
        [.nextCandidate, .previousCandidate, .pageForward, .pageBackward],
        [.confirmHighlighted, .commitLiteral, .commitAlternateScript],
    ]

    /// The two ways to end a composition into the document. A roster that let
    /// both go unbound would leave a composition that can only be cancelled.
    static let alwaysBound: Set<HardwareComposingAction> = [.confirmHighlighted, .commitLiteral]

    /// The App Group key this action's chord is stored under — the desktop's
    /// namespace, so a chord means the same thing in either defaults domain.
    var settingsKeyName: String {
        "composingShortcut.\(rawValue)"
    }

    var labelKey: StringKey {
        switch self {
        case .nextCandidate: .desktopActionNextCandidate
        case .previousCandidate: .desktopActionPreviousCandidate
        case .pageForward: .desktopActionPageForward
        case .pageBackward: .desktopActionPageBackward
        case .confirmHighlighted: .desktopActionConfirmHighlighted
        case .commitLiteral: .desktopActionCommitLiteral
        case .commitAlternateScript: .desktopActionCommitAlternateScript
        }
    }
}

/// The switches a hardware key can flip whether or not a composition is
/// running — the desktop's global roster, minus the two that have no iOS
/// counterpart (the settings window doorway, the Telex guide).
// CROSS-PLATFORM INVARIANT — mirrors `ShortcutAction` + the
// `KeyboardShortcuts.Name` defaults in
// `macos/Sources/TaigiInputMethodCore/Settings/ShortcutActions.swift`.
enum HardwareShortcutAction: String, HardwareBindableAction {
    case toggleRomanization
    case cycleCandidateDisplayMode
    case toggleTranslateSwapped
    case showSymbolPicker

    /// ⌃⌘ plus a letter is what a Taiwanese input method puts its switches
    /// on; the bare backtick is the classic 漢羅對調 key.
    var defaultChord: HardwareKeyChord {
        switch self {
        case .toggleRomanization: Self.shipped("c", modifiers: [.control, .command])
        case .cycleCandidateDisplayMode: Self.shipped("h", modifiers: [.control, .command])
        case .toggleTranslateSwapped: Self.shipped("`")
        case .showSymbolPicker: Self.shipped(",", modifiers: [.control, .command])
        }
    }

    var settingsKeyName: String {
        "hardwareShortcut.\(rawValue)"
    }

    var labelKey: StringKey {
        switch self {
        case .toggleRomanization: .desktopShortcutToggleRomanization
        case .cycleCandidateDisplayMode: .desktopShortcutCycleCandidateDisplayMode
        case .toggleTranslateSwapped: .desktopShortcutToggleTranslateSwapped
        case .showSymbolPicker: .desktopShortcutShowSymbolPicker
        }
    }
}
