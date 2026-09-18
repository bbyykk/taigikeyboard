// 快速齒 — the hardware key contract, one recordable row per action (iPad).

import SwiftUI
import UIKit

/// The iOS twin of the desktop's `ShortcutSettingsView`: the keys that move
/// through the candidates, the keys that end the composition, and the
/// switches — each row a recorder. No row writes its own chord: a recording
/// clears every other row holding that chord first, on either roster, then
/// the pane re-reads what that left.
struct HardwareShortcutSettingsView: View {
    @Environment(DisplayLanguageStore.self) private var lang
    private let settings = SharedSettings.shared

    /// Re-read after every write so the rows repaint together.
    @State private var bindings = SharedSettings.shared.hardwareKeyBindings
    /// The row waiting for a key, if any.
    @State private var recording: ShortcutRow?
    /// Why the last press was turned down, shown on the row that refused it.
    @State private var rejection: (row: ShortcutRow, reason: HardwareKeyChord.Rejection)?

    var body: some View {
        Form {
            // Block one: through the candidates.
            Section {
                ForEach(HardwareComposingAction.groups[0], id: \.self) { action in
                    recorderRow(.composing(action))
                }
            } header: {
                Text(lang.string(.desktopShortcutSectionCandidateSelection))
            }

            // Block two: out of the composition and into the document.
            Section {
                ForEach(HardwareComposingAction.groups[1], id: \.self) { action in
                    recorderRow(.composing(action))
                }
                // Shown, not recordable: ⇧ on a slot key is the 漢羅 commit
                // aimed at that slot (`HardwareKeyIntent`).
                LabeledContent(lang.string(.desktopShortcutCommitAlternateScriptInSlot)) {
                    Text(Self.shiftedSlotKeysLabel)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(lang.string(.desktopShortcutSectionOutput))
            }

            // Block three: the switches.
            Section {
                ForEach(HardwareShortcutAction.allCases, id: \.self) { action in
                    recorderRow(.shortcut(action))
                }
            } header: {
                Text(lang.string(.desktopShortcutSectionOther))
            }

            Section {
                Button(role: .destructive) {
                    settings.resetHardwareShortcuts()
                    reload()
                } label: {
                    Text(lang.string(.themeEditorResetAll))
                }
            }
        }
        .navigationTitle(lang.string(.desktopShortcutsTab))
        .navigationBarTitleDisplayMode(.inline)
        .background {
            // Off-screen key capture, live only while a row is recording.
            HardwareKeyCaptureView(isActive: recording != nil, onKey: record)
                .frame(width: 0, height: 0)
        }
    }

    /// `⇧q ⇧w … ⇧;` — the row the slot keys make under Shift.
    static let shiftedSlotKeysLabel = HardwareKeyIntent.slotKeyRow.map { "⇧" + $0 }.joined(separator: " ")

    private func recorderRow(_ row: ShortcutRow) -> some View {
        Button {
            rejection = nil
            recording = recording == row ? nil : row
        } label: {
            LabeledContent(lang.string(row.labelKey)) {
                Text(fieldText(for: row))
                    .foregroundStyle(recording == row ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func fieldText(for row: ShortcutRow) -> String {
        // A refusal outranks the prompt: the row stays recording, and says
        // why the last press was turned down.
        if let rejection, rejection.row == row {
            // Every refusal but "no key" means the chord already belongs to
            // something — typing, or the input method itself.
            return lang.string(rejection.reason == .noKey ? .desktopShortcutRejectedNoKey : .desktopShortcutRejectedTaken)
        }
        if recording == row {
            return lang.string(.desktopShortcutRecording)
        }
        guard let chord = row.chord(in: bindings) else {
            return lang.string(.desktopShortcutUnbound)
        }
        return HardwareKeyChordDisplay.text(for: chord)
    }

    /// One hardware press while a row is recording.
    private func record(_ key: HardwareKeySnapshot) {
        guard let row = recording else { return }
        if key.chordingModifiers.isEmpty {
            switch key.keyCode {
            case .keyboardEscape:
                // The way out of a field opened by accident.
                recording = nil
                return
            case .keyboardDeleteOrBackspace, .keyboardDeleteForward:
                settings.setHardwareChord(nil, forKey: row.settingsKeyName)
                finishRecording()
                return
            default:
                break
            }
        }
        switch HardwareKeyChord.make(key) {
        case let .success(chord):
            // Return and ⇧Return are the always-bound pool's alone: refused
            // here, before any write, rather than written and then emptied
            // by the resolver.
            if !row.mayHoldPoolChord, HardwareComposingAction.alwaysBound.contains(where: { $0.defaultChord == chord }) {
                rejection = (row, .reservedKey)
                return
            }
            // Last writer wins: the rows that held this chord empty in front
            // of the user rather than being discovered later.
            let holders = bindings.rowsHolding(chord)
            for action in holders.composing where row != .composing(action) {
                settings.setHardwareChord(nil, forKey: action.settingsKeyName)
            }
            for action in holders.shortcuts where row != .shortcut(action) {
                settings.setHardwareChord(nil, forKey: action.settingsKeyName)
            }
            settings.setHardwareChord(chord, forKey: row.settingsKeyName)
            finishRecording()
        case let .failure(reason):
            rejection = (row, reason)
        }
    }

    private func finishRecording() {
        rejection = nil
        recording = nil
        reload()
    }

    private func reload() {
        bindings = settings.hardwareKeyBindings
    }
}

/// One row of the pane, on either roster.
enum ShortcutRow: Hashable {
    case composing(HardwareComposingAction)
    case shortcut(HardwareShortcutAction)

    private var action: any HardwareBindableAction {
        switch self {
        case let .composing(action): action
        case let .shortcut(action): action
        }
    }

    var labelKey: StringKey { action.labelKey }
    var settingsKeyName: String { action.settingsKeyName }

    func chord(in bindings: HardwareKeyBindings) -> HardwareKeyChord? {
        switch self {
        case let .composing(action): bindings.chord(for: action)
        case let .shortcut(action): bindings.chord(for: action)
        }
    }

    /// Only the always-bound composing rows may take Return / ⇧Return.
    var mayHoldPoolChord: Bool {
        if case let .composing(action) = self {
            return HardwareComposingAction.alwaysBound.contains(action)
        }
        return false
    }
}

/// An invisible first responder that turns hardware presses into
/// `HardwareKeySnapshot`s while `isActive`. The host app has no text field
/// to receive them, and a text field would type the key.
struct HardwareKeyCaptureView: UIViewRepresentable {
    let isActive: Bool
    let onKey: (HardwareKeySnapshot) -> Void

    func makeUIView(context _: Context) -> CaptureView {
        CaptureView()
    }

    func updateUIView(_ view: CaptureView, context _: Context) {
        view.onKey = onKey
        view.wantsFocus = isActive
    }

    final class CaptureView: UIView {
        var onKey: ((HardwareKeySnapshot) -> Void)?

        /// Focus is asked for whenever the flag flips and again once the
        /// view is in a window — `becomeFirstResponder` fails outside one.
        var wantsFocus = false {
            didSet { syncFocus() }
        }

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            syncFocus()
        }

        private func syncFocus() {
            guard window != nil else { return }
            if wantsFocus, !isFirstResponder {
                becomeFirstResponder()
            } else if !wantsFocus, isFirstResponder {
                resignFirstResponder()
            }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            let keys = presses.compactMap(\.key)
            guard let key = keys.first else {
                super.pressesBegan(presses, with: event)
                return
            }
            onKey?(HardwareKeySnapshot(key))
        }

        override func pressesEnded(_: Set<UIPress>, with _: UIPressesEvent?) {}
        override func pressesCancelled(_: Set<UIPress>, with _: UIPressesEvent?) {}
    }
}
