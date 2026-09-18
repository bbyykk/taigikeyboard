import SwiftUI

/// Paints a keyboard overlay panel's theme backdrop so it stays continuous with the
/// gradient-painted keyboard root.
///
/// The symbol / layout / settings panels are mounted as siblings ON TOP of the
/// gradient-painted keyboard (`TaigiKeyboardView` `.background { LinearGradient }`) and
/// are offset DOWN by the toolbar height, so they cover the keyboard keys — making them
/// transparent would show the keys, not the gradient. They must repaint the gradient.
///
/// Because a panel occupies `[topInset, fullKeyboardHeight]` of the keyboard, painting the
/// gradient inside the panel's own bounds would restart it at the panel top and leave a
/// visible seam against the transparent toolbar above it (which shows the root gradient's
/// `[0, topInset]` slice). To stay continuous, express the gradient's start / end points in
/// full-keyboard unit space and map them into the panel's unit space (the start of a
/// vertical gradient lands ABOVE the panel as a negative-y `UnitPoint`), so the panel shows
/// exactly the `[topInset, fullKeyboardHeight]` slice in-bounds — NOT an oversized frame +
/// `.offset` + `.clipped()`, which froze the keyboard extension on gradient themes (#429).
///
/// Flat / default themes keep today's `Color.keyboardBackground` (no behavior change); only
/// gradient themes gain the repaint. Mirrors `ExpandedCandidateOverlay.backgroundView`'s
/// gradient branch (that overlay spans the full keyboard, so it needs no slice mapping).
struct KeyboardOverlayBackdrop: ViewModifier {
    /// The active theme's background gradient, or nil for a flat / default theme.
    let gradient: ThemeGradient?
    /// Full keyboard height (candidate bar + keyboard) the root gradient spans.
    let fullKeyboardHeight: CGFloat
    /// Height of the toolbar above the panel — the panel's vertical offset into the gradient.
    let topInset: CGFloat

    func body(content: Content) -> some View {
        content.background(alignment: .top) { backdrop }
    }

    @ViewBuilder
    private var backdrop: some View {
        if let gradient {
            LinearGradient(gradient, points: panelUnitPoints)
        } else {
            Color.keyboardBackground
        }
    }

    /// The gradient's full-keyboard unit points mapped into the panel's unit space: the panel
    /// shares the keyboard's width (x unchanged) and covers `[topInset, fullKeyboardHeight]`
    /// of its height, so `y' = (y · fullHeight − topInset) / panelHeight`. `panelHeight > 0`
    /// guards transient / degenerate geometry (fall back to the unshifted points). nil when
    /// there is no gradient.
    var panelUnitPoints: (start: UnitPoint, end: UnitPoint)? {
        guard let gradient else { return nil }
        let points = gradient.unitPoints
        let panelHeight = fullKeyboardHeight - topInset
        guard panelHeight > 0 else { return points }
        func mapped(_ point: UnitPoint) -> UnitPoint {
            UnitPoint(x: point.x, y: (point.y * fullKeyboardHeight - topInset) / panelHeight)
        }
        return (start: mapped(points.start), end: mapped(points.end))
    }
}

extension View {
    /// Apply the gradient-continuous keyboard overlay backdrop. See `KeyboardOverlayBackdrop`.
    func keyboardOverlayBackdrop(
        gradient: ThemeGradient?,
        fullKeyboardHeight: CGFloat,
        topInset: CGFloat,
    ) -> some View {
        modifier(
            KeyboardOverlayBackdrop(
                gradient: gradient,
                fullKeyboardHeight: fullKeyboardHeight,
                topInset: topInset,
            ),
        )
    }

    /// Mount this content as a toolbar overlay panel (symbol / layout / settings): shown only
    /// when `isExpanded`, sized to fill the keyboard below the toolbar, with the theme backdrop
    /// applied. Centralizes the geometry + inset wiring the three panels share — the panel sits
    /// `theme.height` (toolbar height) below the keyboard top, so that is both its size offset and
    /// the gradient's top inset.
    @ViewBuilder
    func keyboardOverlayPanel(isExpanded: Bool, theme: CandidateTheme) -> some View {
        if isExpanded {
            GeometryReader { geometry in
                let toolbarHeight = theme.height
                self
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height - toolbarHeight)
                    .keyboardOverlayBackdrop(
                        gradient: theme.backgroundGradient,
                        fullKeyboardHeight: geometry.size.height,
                        topInset: toolbarHeight,
                    )
            }
        }
    }
}
