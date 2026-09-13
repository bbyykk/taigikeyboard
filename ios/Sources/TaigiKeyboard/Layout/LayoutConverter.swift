import KeyboardKit
import UIKit

/// Converts KeyDef layout to KeyboardKit's KeyboardLayout
struct LayoutConverter {
    let context: KeyboardContext
    let config: KeyboardLayoutConfiguration

    /// Entry point: converts [[KeyDef]] to KeyboardLayout. The 文/A key is
    /// dropped under 羅馬字 (always half-width, nothing to flip); `.space` is
    /// `.available`, so it takes the freed width.
    func convert(_ keyDefs: [[KeyDef]]) -> KeyboardLayout {
        let showsTranslateKey = context.candidateDisplayMode.allowsSwapToggle
        // Read once per layout, not per key: TPS is always full-width, the
        // other layouts follow the derived punctuation width.
        let typesFullWidth = SharedSettings.shared.keyboardLayoutType == .tps || context.isFullWidthPunctuation
        let itemRows = keyDefs.map { row in
            row.compactMap { keyDef -> KeyboardLayoutItem? in
                if case .translate = keyDef, !showsTranslateKey {
                    return nil
                }
                return createItem(from: keyDef, typesFullWidth: typesFullWidth)
            }
        }
        return KeyboardLayout(itemRows: itemRows, configuration: config)
    }

    // MARK: - Private

    private func createItem(from keyDef: KeyDef, typesFullWidth: Bool) -> KeyboardLayoutItem {
        let action = keyDefToAction(keyDef, typesFullWidth: typesFullWidth)
        let width = widthFor(keyDef)
        return action.standardLayoutItem(for: config, width: width)
    }

    /// Converts KeyDef to KeyboardAction; `.char` takes its `fullWidth` form
    /// when `typesFullWidth`.
    private func keyDefToAction(_ keyDef: KeyDef, typesFullWidth: Bool) -> KeyboardAction {
        switch keyDef {
        case let .char(char, fullWidth):
            return .character(typesFullWidth ? (fullWidth ?? char) : char)

        case .shift:
            return .shift(context.keyboardCase)

        case .backspace:
            return .backspace

        case .space:
            return .space

        case .return:
            return .primary(.return)

        case .translate:
            return .custom(named: "translate")

        case .numeric:
            return .keyboardType(.numeric)

        case .symbolic:
            return .keyboardType(.symbolic)

        case .alphabetic:
            return .keyboardType(.alphabetic)

        case .globe:
            return .nextKeyboard

        case .emoji:
            return .keyboardType(.emojis)
        }
    }

    /// Determines key width by KeyDef kind + screen orientation; `.char`
    /// returns nil to fall back to the default input-key width.
    private func widthFor(_ keyDef: KeyDef) -> KeyboardLayoutItem.Width? {
        // Use UIKit native API for orientation (KeyboardKit 10 no longer provides interfaceOrientation)
        let screenBounds = UIScreen.main.bounds
        let isPortrait = screenBounds.height > screenBounds.width

        switch keyDef {
        case .shift, .backspace:
            return .percentage(LayoutConstants.shiftBackspace)

        case .space:
            return .available

        case .return:
            return .percentage(
                isPortrait ? LayoutConstants.ReturnButton.portrait
                    : LayoutConstants.ReturnButton.landscape,
            )

        case .numeric, .symbolic, .alphabetic, .globe, .emoji:
            return .percentage(
                isPortrait ? LayoutConstants.BottomSystemButton.portrait
                    : LayoutConstants.BottomSystemButton.landscape,
            )

        case .translate:
            let layoutType = SharedSettings.shared.keyboardLayoutType
            let scale: CGFloat = (layoutType == .phahTaigi || layoutType == .moe1) ? 2.0 : 1.5
            return .inputPercentage(scale)

        case .char:
            return nil // Use default input width
        }
    }
}
