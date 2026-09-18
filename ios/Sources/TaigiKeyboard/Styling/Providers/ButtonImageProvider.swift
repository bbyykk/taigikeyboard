import KeyboardKit
import SwiftUI

/// Button image provider — first in the render chain.
///
/// Returns the SF Symbol image for a key. Returns nil to defer to `ButtonTextProvider`.
/// Only handles keys with icon-based rendering: globe, return, settings, translate toggle.
///
/// Created by: `TaigiKeyboardView.RenderProviders`
/// Queried by: `TaigiButtonContent.body` (first priority check)
/// Depends on: `KeyboardContext` (composing state, translate toggle state)
final class ButtonImageProvider {
    private let keyboardContext: KeyboardContext

    init(keyboardContext: KeyboardContext) {
        self.keyboardContext = keyboardContext
    }

    /// Returns an SF Symbol image, or nil to defer to text rendering.
    func buttonImage(for action: KeyboardAction) -> Image? {
        switch action {
        case .nextKeyboard:
            return Image(latinSystemName: "globe")
        case .primary(.return):
            // Show newline icon when not composing; nil lets ButtonTextProvider show confirmation text
            return keyboardContext.isComposingText ? nil : Image(latinSystemName: "arrow.turn.down.left")
        case .settings:
            return Image(latinSystemName: "gearshape.fill")
        case let .custom(name):
            switch name {
            case "translate":
                // Lit when the key has been taken OFF the shipped state — the
                // layouts type half-width marks and a commit leads with the
                // romanization (USER 2026-09-18, after hanji-first became the
                // default: a key that lights up on a fresh install reads as a
                // mode the user never chose). Outlined = hanji + full-width,
                // what the key flips in every mode it is shown in.
                let iconName = keyboardContext.isFullWidthPunctuation
                    ? "character.square" // Default: outlined
                    : "character.square.fill" // Off the default: filled
                return Image(latinSystemName: iconName)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}
