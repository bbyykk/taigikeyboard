// Which hardware key does which action — the part of the key contract the user chooses.

import Foundation

/// The user's hardware key contract, resolved and ready to classify against.
///
/// A value passed into `HardwareKeyIntent.intent(for:…)` rather than read
/// from `UserDefaults` inside it, so the classification stays a pure
/// function of its inputs. "Resolved" means: every chord came through
/// `HardwareKeyChord.make`; no chord is on two rows (a later recording takes
/// it from the earlier one); the two always-bound composing actions are
/// restored from their shared default pool when emptied; and a shortcut can
/// never hold a chord of that pool.
// CROSS-PLATFORM INVARIANT — mirrors
// `macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyBindings.swift`
// (`removeDuplicates`, `restoreUnbound`, `actionsHolding`).
struct HardwareKeyBindings: Equatable {
    private(set) var composing: [HardwareComposingAction: HardwareKeyChord]
    private(set) var shortcuts: [HardwareShortcutAction: HardwareKeyChord]
    /// Chord → row, built once so a key press is one lookup. No chord is on
    /// two rows once resolved, so the maps are injective.
    private let composingByChord: [HardwareKeyChord: HardwareComposingAction]
    private let shortcutsByChord: [HardwareKeyChord: HardwareShortcutAction]

    static let `default` = HardwareKeyBindings()

    /// A stored nil is "the user cleared this row"; an absent key is "never
    /// touched", which is what the default is for.
    init(
        composing: [HardwareComposingAction: HardwareKeyChord?] = [:],
        shortcuts: [HardwareShortcutAction: HardwareKeyChord?] = [:],
    ) {
        var resolvedShortcuts: [HardwareShortcutAction: HardwareKeyChord] = [:]
        for action in HardwareShortcutAction.allCases {
            resolvedShortcuts[action] = shortcuts[action] ?? action.defaultChord
        }
        Self.removeDuplicates(in: &resolvedShortcuts)

        var resolvedComposing: [HardwareComposingAction: HardwareKeyChord] = [:]
        for action in HardwareComposingAction.allCases {
            resolvedComposing[action] = composing[action] ?? action.defaultChord
        }
        Self.removeDuplicates(in: &resolvedComposing)

        // The always-bound pool is the composing side's alone.
        let pool = Set(HardwareComposingAction.alwaysBound.map(\.defaultChord))
        for (action, chord) in resolvedShortcuts where pool.contains(chord) {
            resolvedShortcuts[action] = nil
        }
        // A chord on both rosters: a row the user chose outranks a row still
        // on its default (the desktop's `resolveAcrossRegistries`); between
        // two of the same standing the shortcut wins, because the classifier
        // reads the shortcuts first and the composing row would be empty in
        // fact.
        for (composingAction, chord) in resolvedComposing {
            guard let shortcutAction = resolvedShortcuts.first(where: { $0.value == chord })?.key else { continue }
            let composingIsCustom = chord != composingAction.defaultChord
            let shortcutIsCustom = chord != shortcutAction.defaultChord
            if composingIsCustom, !shortcutIsCustom {
                resolvedShortcuts[shortcutAction] = nil
            } else {
                resolvedComposing[composingAction] = nil
            }
        }
        Self.restoreUnbound(in: &resolvedComposing)

        self.composing = resolvedComposing
        self.shortcuts = resolvedShortcuts
        composingByChord = Dictionary(uniqueKeysWithValues: resolvedComposing.map { ($1, $0) })
        shortcutsByChord = Dictionary(uniqueKeysWithValues: resolvedShortcuts.map { ($1, $0) })
    }

    func chord(for action: HardwareComposingAction) -> HardwareKeyChord? {
        composing[action]
    }

    func chord(for action: HardwareShortcutAction) -> HardwareKeyChord? {
        shortcuts[action]
    }

    /// The composing action `press` is bound to, if any.
    func composingAction(for press: HardwareKeySnapshot) -> HardwareComposingAction? {
        composingByChord[HardwareKeyChord(pressed: press)]
    }

    /// The shortcut `press` is bound to, if any.
    func shortcutAction(for press: HardwareKeySnapshot) -> HardwareShortcutAction? {
        shortcutsByChord[HardwareKeyChord(pressed: press)]
    }

    /// Every row on either roster holding `chord` — what a recording empties.
    func rowsHolding(_ chord: HardwareKeyChord) -> (
        composing: [HardwareComposingAction], shortcuts: [HardwareShortcutAction],
    ) {
        (
            HardwareComposingAction.allCases.filter { composing[$0] == chord },
            HardwareShortcutAction.allCases.filter { shortcuts[$0] == chord },
        )
    }

    /// Drops a chord from every row but the last one holding it, with the
    /// rows still on their own default going first — a row holding a chord
    /// the user chose outranks a row holding only what it shipped with.
    private static func removeDuplicates<Action: HardwareBindableAction>(
        in resolved: inout [Action: HardwareKeyChord],
    ) {
        let onItsDefault = Set(resolved.filter { $0.value == $0.key.defaultChord }.keys)
        let order = Action.allCases.filter(onItsDefault.contains)
            + Action.allCases.filter { !onItsDefault.contains($0) }

        var seen: [HardwareKeyChord: Action] = [:]
        for action in order {
            guard let chord = resolved[action] else { continue }
            if let earlier = seen[chord] {
                resolved[earlier] = nil
            }
            seen[chord] = action
        }
    }

    /// Keeps every always-bound action reachable: an empty always-bound row
    /// takes whichever chord of the shared pool nobody else in the pool has,
    /// which is what lets Return and ⇧Return swap but never leave.
    private static func restoreUnbound(in resolved: inout [HardwareComposingAction: HardwareKeyChord]) {
        let alwaysBound = HardwareComposingAction.allCases.filter(HardwareComposingAction.alwaysBound.contains)
        let pool = alwaysBound.map(\.defaultChord)

        for (action, chord) in resolved
            where pool.contains(chord) && !HardwareComposingAction.alwaysBound.contains(action)
        {
            resolved[action] = nil
        }

        var taken = Set(alwaysBound.compactMap { resolved[$0] })
        for action in alwaysBound where resolved[action] == nil {
            guard let free = pool.first(where: { !taken.contains($0) }) else { continue }
            resolved[action] = free
            taken.insert(free)
        }
    }
}
