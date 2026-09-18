import SwiftUI

extension View {
    /// Mount this content as a toolbar overlay panel (symbol / layout / settings): shown only
    /// when `isExpanded`, sized to fill the keyboard below the toolbar, with the theme backdrop.
    ///
    /// The panels are mounted as siblings ON TOP of the painted keyboard (`TaigiKeyboardView`
    /// `.background { ThemeBackgroundSurface }`) and offset DOWN by the toolbar height, so they
    /// cover the keys — transparent would show the keys, not the surface. They repaint exactly
    /// their own `[toolbarHeight, keyboardHeight]` slice (`KeyboardSurfaceSlice`, see
    /// `ThemeBackgroundSurface`) so a gradient or photo continues seamlessly from the
    /// transparent toolbar above. The adaptive default keeps `Color.keyboardBackground`.
    @ViewBuilder
    func keyboardOverlayPanel(isExpanded: Bool, theme: CandidateTheme) -> some View {
        if isExpanded {
            GeometryReader { geometry in
                let toolbarHeight = theme.height
                self
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height - toolbarHeight)
                    .background(alignment: .top) {
                        if let surface = theme.surface {
                            ThemeBackgroundSurface(
                                surface: surface,
                                slice: KeyboardSurfaceSlice(fullHeight: geometry.size.height, topInset: toolbarHeight),
                            )
                            .equatable()
                        } else {
                            Color.keyboardBackground
                        }
                    }
            }
        }
    }
}
