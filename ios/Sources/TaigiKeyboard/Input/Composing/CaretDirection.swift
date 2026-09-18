// One step of the caret inside the composition (`ComposingManager.moveCaret`).

import Foundation

/// The direction `MoveCaret` steps the composing caret — the engine owns the
/// caret (`engine/composing/src/api.rs` `Intent::MoveCaret`); this only names
/// the step.
// CROSS-PLATFORM INVARIANT — mirrors macos `CaretDirection`
// (`macos/Sources/TaigiInputMethodCore/Controller/ComposingKeyIntent.swift:32-44`).
public enum CaretDirection: Equatable {
    case left
    case right
}
