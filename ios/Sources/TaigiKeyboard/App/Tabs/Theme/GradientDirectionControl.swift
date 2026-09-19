// The theme editor's gradient direction control: the drag surface over the live
// preview, the finger → angle math behind it, and the 方向 row that reads it out.

import SwiftUI

/// Maps a finger on the live keyboard preview to a `ThemeGradient.angle`: the
/// direction from the preview's centre to the finger, in the CSS / Figma
/// convention the model uses (`0` = bottom→top, clockwise). Angles within
/// `snapTolerance` of a 45° preset snap to it (the eight presets the editor used
/// to offer as buttons stay one flick away); everything else is a whole degree.
enum GradientDirectionDrag {
    private static let presetStep = ThemeGradient.presetStep
    /// Half-width of the snap window around each preset, in degrees.
    static let snapTolerance: Double = 6
    /// Radius around the centre where the direction is too jittery to trust, in points.
    static let deadZone: CGFloat = 8

    /// The angle of `point` seen from `center`, snapped / rounded into `0 ..< 360`;
    /// nil while the finger is inside the dead zone.
    static func angle(from center: CGPoint, to point: CGPoint) -> Double? {
        let vector = CGVector(dx: point.x - center.x, dy: point.y - center.y)
        guard hypot(vector.dx, vector.dy) >= deadZone else { return nil }
        return snapped(ThemeGradient.degrees(of: vector))
    }

    /// `degrees` snapped to the nearest preset when within `snapTolerance`, else
    /// rounded to a whole degree; always in `0 ..< 360`.
    static func snapped(_ degrees: Double) -> Double {
        let nearestPreset = (degrees / presetStep).rounded() * presetStep
        return wrapped(abs(degrees - nearestPreset) <= snapTolerance ? nearestPreset : degrees.rounded())
    }

    static func isPreset(_ angle: Double) -> Bool {
        angle.truncatingRemainder(dividingBy: presetStep) == 0
    }

    /// The next preset clockwise or counter-clockwise from `angle` — the VoiceOver
    /// adjustable action's step, so the direction stays settable without the drag.
    static func steppedPreset(from angle: Double, clockwise: Bool) -> Double {
        let steps = angle / presetStep
        return wrapped((clockwise ? steps.rounded(.down) + 1 : steps.rounded(.up) - 1) * presetStep)
    }

    /// `degrees` reduced into `0 ..< 360` for any sign.
    private static func wrapped(_ degrees: Double) -> Double {
        (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}

/// The drag surface laid over the live preview while the background is a gradient:
/// swallows the preview keys' touches, draws the current direction as an axis
/// through the centre with an arrowhead at the gradient's end, and writes every
/// drag position through `GradientDirectionDrag` into `angle`. Snapping into a
/// preset clicks.
struct GradientDirectionOverlay: View {
    @Binding var angle: Double

    var body: some View {
        GeometryReader { geometry in
            GradientDirectionAxis(angle: angle)
                .equatable()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let next = GradientDirectionDrag.angle(from: geometry.size.center, to: value.location) {
                                angle = next
                            }
                        },
                )
        }
        .accessibilityHidden(true)
        .sensoryFeedback(.selection, trigger: angle) { _, new in GradientDirectionDrag.isPreset(new) }
    }
}

/// The axis through the centre with an arrowhead at the gradient's end. `Equatable`
/// on the angle alone so edits to other controls (which re-render the whole editor
/// body) skip the redraw.
private struct GradientDirectionAxis: View, Equatable {
    let angle: Double

    private static let strokeWidth: CGFloat = 3
    private static let headLength: CGFloat = 12
    private static let centreDotRadius: CGFloat = 4
    /// Half the axis length as a fraction of the preview's shorter side.
    private static let axisHalfLength: CGFloat = 0.3

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let center = size.center
        let direction = ThemeGradient.direction(degrees: angle)
        let halfLength = min(size.width, size.height) * Self.axisHalfLength
        let tip = CGPoint(x: center.x + direction.dx * halfLength, y: center.y + direction.dy * halfLength)
        let tail = CGPoint(x: center.x - direction.dx * halfLength, y: center.y - direction.dy * halfLength)

        var path = Path()
        path.move(to: tail)
        path.addLine(to: tip)
        // Arrowhead: two strokes swept back from the tip at ±150°.
        for sweep in [150.0, -150.0] {
            let head = ThemeGradient.direction(degrees: angle + sweep)
            path.move(to: tip)
            path.addLine(to: CGPoint(x: tip.x + head.dx * Self.headLength, y: tip.y + head.dy * Self.headLength))
        }
        let dot = Path(ellipseIn: CGRect(
            x: center.x - Self.centreDotRadius, y: center.y - Self.centreDotRadius,
            width: Self.centreDotRadius * 2, height: Self.centreDotRadius * 2,
        ))

        // White on a dark halo reads on any gradient.
        context.addFilter(.shadow(color: .black.opacity(0.6), radius: 2))
        context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round))
        context.fill(dot, with: .color(.white))
    }
}

private extension CGSize {
    var center: CGPoint {
        CGPoint(x: width / 2, y: height / 2)
    }
}

// MARK: - 方向 row

/// The 方向 row of the user-theme editor's 背景 › 漸層 group: the current angle in
/// whole degrees (CSS convention, see `ThemeGradient.angle`) and a caption telling
/// the user to drag the live preview, which is where the direction is actually set
/// (`GradientDirectionOverlay`). For VoiceOver the row is one adjustable element
/// stepping through the eight 45° presets.
struct ThemeGradientDirectionRow: View {
    let label: String
    let hint: String
    @Binding var angle: Double

    var body: some View {
        let degrees = "\(Int(angle))°"
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(degrees)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Text(hint)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(degrees)
        .accessibilityAdjustableAction { direction in
            angle = GradientDirectionDrag.steppedPreset(from: angle, clockwise: direction == .increment)
        }
    }
}
