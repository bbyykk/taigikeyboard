// Hardware (external) keyboard path: `pressesBegan` → `HardwareKeyIntent` → the same
// ActionHandler / ComposingManager entry points the on-screen keys use.

import KeyboardKit
import UIKit

private let hardwareLogger = DebugLogger(category: "KeyboardViewController+HardwareKeyboard")

extension KeyboardViewController {
    // MARK: - UIResponder presses

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            guard let key = press.key, handleHardwareKey(HardwareKeySnapshot(key)) else {
                unhandled.insert(press)
                continue
            }
            handledHardwarePresses.insert(press)
        }
        // Only the presses this extension did not take go on up the chain,
        // so a key handled here is never also delivered as text.
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = releaseHandledPresses(presses)
        if !unhandled.isEmpty {
            super.pressesEnded(unhandled, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = releaseHandledPresses(presses)
        if !unhandled.isEmpty {
            super.pressesCancelled(unhandled, with: event)
        }
    }

    /// Drops `presses` from the handled set; returns the ones that were never ours.
    private func releaseHandledPresses(_ presses: Set<UIPress>) -> Set<UIPress> {
        let ours = presses.intersection(handledHardwarePresses)
        handledHardwarePresses.subtract(ours)
        return presses.subtracting(ours)
    }

    // MARK: - Dispatch

    /// Routes one hardware key. Returns false when the press is the host's.
    private func handleHardwareKey(_ key: HardwareKeySnapshot) -> Bool {
        hardwareKeyboard.noteHardwareKeyPress()
        guard let handler = actionHandler else { return false }

        let manager = handler.composingManager
        // The list as the bar draws it, so a picked cell commits what was shown.
        let suggestions = SuggestionCaseTransformer.transform(
            state.autocompleteContext.suggestions,
            composingText: manager.composingText,
            keyboardCase: state.keyboardContext.keyboardCase,
            inputMode: handler.settings.inputMode,
        )
        let visibleCount = min(suggestions.count, CandidateViewModels.UI.maxDisplayCount)
        // The bar counts only while a composition owns it: NextWord and
        // English suggestions sit in the same row but are not candidates the
        // slot keys or the arrows may take.
        let isShowingCandidates = manager.isComposing && !suggestions.isEmpty
        let intent = HardwareKeyIntent.intent(
            for: key,
            isComposing: manager.isComposing,
            isShowingCandidates: isShowingCandidates,
        )
        hardwareLogger.debug("[HARDWARE] code=\(key.keyCode.rawValue) intent=\(String(describing: intent))")

        switch intent {
        case let .input(characters):
            // The case is the key's own, never the on-screen Shift state:
            // a hardware `A` is a capital, a hardware `a` is not.
            let letterCase: RustEngineBridge.CaseTransformLetterCase =
                characters.first?.isUppercase == true ? .uppercased : .lowercased
            return handler.handleHardwareKey(.character(characters), letterCase: letterCase)
        case .space:
            return handler.handleHardwareKey(.space)
        case .deleteBackward:
            return handler.handleHardwareKey(.backspace)
        case .cancel:
            handler.beginInputEvent()
            cleanupInputState()
            return true
        case .confirmHighlighted:
            return confirmHighlightedCandidate(handler: handler, suggestions: suggestions)
        case .commitLiteral:
            handler.beginInputEvent()
            manager.commitRawInput()
            return true
        case let .navigate(navigation):
            if let target = HardwareCandidatePage.target(
                for: navigation, from: manager.selectedCandidateIndex, count: visibleCount,
            ) {
                manager.setSelectedCandidateIndex(target)
            }
            return true
        case let .selectCandidateSlot(slot):
            guard let index = HardwareCandidatePage.candidateIndex(
                forSlot: slot, selected: manager.selectedCandidateIndex, count: visibleCount,
            ) else { return true }
            commit(suggestions[index], handler: handler)
            return true
        case .commitThenPassThrough:
            handler.beginInputEvent()
            manager.commitComposition()
            return false
        case .passThrough:
            return false
        }
    }

    /// Return with the bar up = the same commit as tapping the highlighted
    /// cell (the literal when that is slot 0); with no highlight to take, the
    /// on-screen Return path (commit, or a newline when idle).
    private func confirmHighlightedCandidate(handler: ActionHandler, suggestions: [AutocompleteSuggestion]) -> Bool {
        let manager = handler.composingManager
        let index = manager.selectedCandidateIndex
        guard manager.isComposing, suggestions.indices.contains(index) else {
            return handler.handleHardwareKey(.primary(.return))
        }
        commit(suggestions[index], handler: handler)
        return true
    }

    /// One commit path for a picked cell, hardware or touch: the cell's
    /// display-mode rewrite (`suggestionToHandle`) then `handle(_ suggestion:)`.
    private func commit(_ suggestion: AutocompleteSuggestion, handler: ActionHandler) {
        handler.handle(CandidateCellHelper.suggestionToHandle(
            for: suggestion,
            isTranslateSwapped: state.keyboardContext.isTranslateSwapped,
            isTPSLayout: handler.isTPSLayout,
            orMapsToER: handler.settings.isTpsOrMappedToER,
        ))
    }

    // MARK: - Collapse

    /// The one writer of `KeyboardContext.isKeyboardCollapsed`, which swaps
    /// the key rows for the `collapsedView` builder (`TaigiKeyboardView`).
    /// Runs on attach / detach, on the open-keyboard control, and when the
    /// 外接齒盤 toggle changes in the host app.
    func applyHardwareKeyboardCollapse() {
        let context = state.keyboardContext
        let collapsed = hardwareKeyboard.isAttached
            && keyboardSettings.isHardwareKeyboardCompact
            && !hardwareKeyboard.wantsOnScreenKeys
        if context.isKeyboardCollapsed != collapsed {
            context.isKeyboardCollapsed = collapsed
        }
    }
}
