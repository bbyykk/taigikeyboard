// Persisted keyboard color settings (Codable + UserDefaults); a nil role falls back to KeyboardKit's dynamic color.

import Foundation
import SwiftUI
import UIKit

// MARK: - Codable Color

/// A color value that persists a single static RGBA to UserDefaults.
///
/// This deliberately stores one color for both light and dark modes.
/// When no custom color is set (`KeyboardColorSettings` field is `nil`),
/// the keyboard falls back to KeyboardKit's dynamic adaptive colors.
struct CodableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    /// Perceived luminance below mid-gray (Rec. 601 weighting). Used to derive a
    /// theme's palette appearance (dark keyText ⇒ light-palette theme) so the emoji
    /// key can pick the matching KeyboardKit asset variant.
    var isDark: Bool {
        (0.299 * red + 0.587 * green + 0.114 * blue) < 0.5
    }

    init(_ color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
    }

    /// Builds an opaque color from a `0xRRGGBB` literal (any high 8 bits are
    /// ignored — pass `0xRRGGBB`, not `0xAARRGGBB`). sRGB components, matching
    /// the `Color(red:green:blue:opacity:)` reconstruction in `color`. Used by
    /// the built-in theme table; no string parse, no failure path.
    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255.0
        green = Double((hex >> 8) & 0xFF) / 255.0
        blue = Double(hex & 0xFF) / 255.0
        alpha = 1.0
    }
}

// MARK: - Theme gradient

/// A linear keyboard-background gradient: ≥2 color `stops` from start to end plus
/// the direction `angle` in degrees, CSS / Figma convention (`0` = bottom→top,
/// `90` = left→right, `180` = top→bottom, clockwise). Built-in gradient themes use
/// the vertical `defaultAngle`.
///
/// "≥2 stops" is enforced at construction (`init` precondition, decode error), so
/// every `ThemeGradient` a render site sees is renderable. Decode is
/// forward-compatible: an `angle` absent from old JSON reads as `defaultAngle`.
// CROSS-PLATFORM INVARIANT — mirrors android .../ime/core/KeyboardColorSettings.kt ThemeGradient
// (stops + angle, same degree convention and unit-point math; Android mirror lands in PR B).
struct ThemeGradient: Codable, Equatable {
    /// Vertical top→bottom, the direction every built-in gradient theme uses.
    static let defaultAngle: Double = 180
    static let minimumStops = 2
    /// How far the end stop is lifted toward white in `seeded(from:)`.
    private static let seedLightenFactor: Double = 0.45

    var stops: [CodableColor]
    var angle: Double

    init(stops: [CodableColor], angle: Double = ThemeGradient.defaultAngle) {
        precondition(stops.count >= Self.minimumStops, "a gradient needs at least \(Self.minimumStops) stops")
        self.stops = stops
        self.angle = angle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stops = try container.decode([CodableColor].self, forKey: .stops)
        guard stops.count >= Self.minimumStops else {
            throw DecodingError.dataCorruptedError(forKey: .stops, in: container, debugDescription: "fewer than \(Self.minimumStops) stops")
        }
        self.stops = stops
        angle = try container.decodeIfPresent(Double.self, forKey: .angle) ?? Self.defaultAngle
    }

    /// The first vertical gradient a user sees when switching a solid background to
    /// 漸層: the solid color running into a lighter tint of itself.
    static func seeded(from solid: CodableColor) -> ThemeGradient {
        ThemeGradient(stops: [solid, solid.lightened(towardWhite: seedLightenFactor)])
    }

    var colors: [Color] {
        stops.map(\.color)
    }

    /// SwiftUI `LinearGradient` start / end points for `angle`, in the unit square of the
    /// painted surface. The CSS direction vector `(sin θ, -cos θ)` (y down) is normalised by
    /// its larger component so the diagonal presets run corner to corner (135° = top-left →
    /// bottom-right) and the axis presets run edge to edge (180° = top-centre → bottom-centre).
    var unitPoints: (start: UnitPoint, end: UnitPoint) {
        let radians = angle * .pi / 180
        let dx = sin(radians)
        let dy = -cos(radians)
        let magnitude = max(abs(dx), abs(dy))
        let halfX = dx / magnitude / 2
        let halfY = dy / magnitude / 2
        return (
            start: UnitPoint(x: 0.5 - halfX, y: 0.5 - halfY),
            end: UnitPoint(x: 0.5 + halfX, y: 0.5 + halfY),
        )
    }
}

extension LinearGradient {
    /// The theme gradient as a SwiftUI gradient; `points` overrides the gradient's own
    /// unit points (the overlay backdrops pass points remapped into panel space).
    init(_ gradient: ThemeGradient, points: (start: UnitPoint, end: UnitPoint)? = nil) {
        let points = points ?? gradient.unitPoints
        self.init(colors: gradient.colors, startPoint: points.start, endPoint: points.end)
    }
}

// MARK: - Theme background

/// What paints the keyboard surface — one field, mutually exclusive cases. The
/// candidate bar is the same surface: a solid background colours both, a
/// gradient paints once behind both (the bar goes transparent). `nil` on
/// `KeyboardColorSettings.background` means "adaptive" (KeyboardKit's dynamic
/// background + Liquid Glass) and is reserved for the 經典 預設 head.
///
/// JSON: `{"type":"solid","color":{…}}` / `{"type":"gradient","stops":[…],"angle":180}`.
// CROSS-PLATFORM INVARIANT — mirrors android .../ime/core/KeyboardColorSettings.kt ThemeBackground
// (same `type` discriminator and field names; Android mirror lands in PR B).
enum ThemeBackground: Codable, Equatable {
    case solid(CodableColor)
    case gradient(ThemeGradient)

    /// The JSON discriminator, also the editor's 純色 / 漸層 segmented choice.
    enum Kind: String, Codable, CaseIterable {
        case solid, gradient
    }

    var kind: Kind {
        switch self {
        case .solid: .solid
        case .gradient: .gradient
        }
    }

    var solidColor: CodableColor? {
        if case let .solid(color) = self {
            return color
        }
        return nil
    }

    var gradient: ThemeGradient? {
        if case let .gradient(gradient) = self {
            return gradient
        }
        return nil
    }

    /// The surface as a view — the keyboard root and the custom-theme card share it.
    @ViewBuilder
    var view: some View {
        switch self {
        case let .solid(color): color.color
        case let .gradient(gradient): LinearGradient(gradient)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .solid:
            self = try .solid(container.decode(CodableColor.self, forKey: .color))
        case .gradient:
            // The gradient's keys sit beside `type` in the same object.
            self = try .gradient(ThemeGradient(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .type)
        switch self {
        case let .solid(color):
            try container.encode(color, forKey: .color)
        case let .gradient(gradient):
            try gradient.encode(to: encoder)
        }
    }
}

// MARK: - Keyboard Color Settings

/// The customizable keyboard color roles; a nil field means "use the KeyboardKit default".
struct KeyboardColorSettings: Equatable {
    /// The keyboard + candidate-bar surface. `nil` = adaptive (KeyboardKit dynamic
    /// background, Liquid Glass eligible).
    var background: ThemeBackground?
    var keyTextColor: CodableColor?
    /// Letter-key fill.
    var normalKeyFillColor: CodableColor?
    /// Fill for Shift / Backspace / Enter and other special keys.
    var specialKeyFillColor: CodableColor?
    var candidateTextColor: CodableColor?

    static let `default` = KeyboardColorSettings()

    /// The solid surface color, or nil for a gradient / adaptive background.
    var solidBackgroundColor: CodableColor? {
        background?.solidColor
    }

    /// The background gradient, or nil for a solid / adaptive background. Single
    /// source for the render branch, the candidate-bar transparency and the overlay
    /// backdrops.
    var backgroundGradient: ThemeGradient? {
        background?.gradient
    }

    /// Factors used to derive the candidate strip's first-candidate highlight and
    /// pressed tints from a gradient theme's first stop, so those states match the theme
    /// hue instead of a neutral keycap color. The highlight is LIGHTENED toward white
    /// (a light tint of the hue, lighter than the gradient bar so it stays visible);
    /// the pressed state is DEEPENED toward black (a darker press feedback). A
    /// flat/scaffold theme (no gradient) keeps the neutral KeyboardKit fallback.
    // CROSS-PLATFORM INVARIANT — mirrors android/app/src/main/java/com/siansiansu/taigikeyboard/ime/core/KeyboardColorSettings.kt
    // CANDIDATE_HIGHLIGHT_LIGHTEN_FACTOR / CANDIDATE_PRESSED_DEEPEN_FACTOR. Drift causes silent divergence.
    static let candidateHighlightLightenFactor: Double = 0.5
    static let candidatePressedDeepenFactor: Double = 0.65
}

// Codable lives in an extension so the struct keeps its synthesized memberwise init.
extension KeyboardColorSettings: Codable {
    /// `background` replaced three older keys. Decoding still reads them so a theme
    /// written by an older build keeps its look: `backgroundGradient` → `.gradient` at
    /// the vertical `defaultAngle`, else `backgroundColor` → `.solid`.
    /// `candidateBackgroundColor` is dropped — the candidate bar is the keyboard
    /// surface now (USER 2026-09-19). Encoding writes only the current keys.
    private enum CodingKeys: String, CodingKey {
        case background, keyTextColor, normalKeyFillColor, specialKeyFillColor, candidateTextColor
        case legacyBackgroundColor = "backgroundColor"
        case legacyBackgroundGradient = "backgroundGradient"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyTextColor = try container.decodeIfPresent(CodableColor.self, forKey: .keyTextColor)
        normalKeyFillColor = try container.decodeIfPresent(CodableColor.self, forKey: .normalKeyFillColor)
        specialKeyFillColor = try container.decodeIfPresent(CodableColor.self, forKey: .specialKeyFillColor)
        candidateTextColor = try container.decodeIfPresent(CodableColor.self, forKey: .candidateTextColor)
        // `try?`: a background `type` this build does not know (written by a newer build),
        // or a legacy gradient with too few stops, degrades to the next fallback instead
        // of failing the whole theme list.
        if let background = try? container.decodeIfPresent(ThemeBackground.self, forKey: .background) {
            self.background = background
        } else if let gradient = try? container.decodeIfPresent(ThemeGradient.self, forKey: .legacyBackgroundGradient) {
            background = .gradient(gradient)
        } else if let color = try container.decodeIfPresent(CodableColor.self, forKey: .legacyBackgroundColor) {
            background = .solid(color)
        } else {
            background = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(background, forKey: .background)
        try container.encodeIfPresent(keyTextColor, forKey: .keyTextColor)
        try container.encodeIfPresent(normalKeyFillColor, forKey: .normalKeyFillColor)
        try container.encodeIfPresent(specialKeyFillColor, forKey: .specialKeyFillColor)
        try container.encodeIfPresent(candidateTextColor, forKey: .candidateTextColor)
    }
}

// MARK: - User-theme seed

/// The concrete light palette every user theme starts from, so a user theme never
/// carries a `nil` (scheme-following) role and renders identically in light and
/// dark mode (USER 2026-09-19). Background is the light keyboard grey; the special
/// key fill is KeyboardKit's light dark-button grey.
// CROSS-PLATFORM INVARIANT — mirrors android .../ime/core/KeyboardColorSettings.kt USER_THEME_SEED
// (Android mirror lands in PR B). Drift = a new custom theme starts from different colors per platform.
enum UserThemeSeed {
    static let solidColor = CodableColor(hex: 0xD4D5DD)
    static let background = ThemeBackground.solid(solidColor)
    static let keyText = CodableColor(hex: 0x000000)
    static let normalKeyFill = CodableColor(hex: 0xFFFFFF)
    static let specialKeyFill = CodableColor(hex: 0xABB1BA)
    static let candidateText = CodableColor(hex: 0x000000)

    static let colors = KeyboardColorSettings(
        background: background,
        keyTextColor: keyText,
        normalKeyFillColor: normalKeyFill,
        specialKeyFillColor: specialKeyFill,
        candidateTextColor: candidateText,
    )

    /// The seed value of one role (every role is set in `colors`).
    static func color(_ role: KeyPath<KeyboardColorSettings, CodableColor?>) -> CodableColor {
        colors[keyPath: role]!
    }
}

extension KeyboardColorSettings {
    /// Fills every `nil` role from `UserThemeSeed`. Applied when user themes are loaded,
    /// so themes saved before the seed existed become scheme-invariant without a
    /// migration write.
    func seededForUserTheme() -> KeyboardColorSettings {
        KeyboardColorSettings(
            background: background ?? UserThemeSeed.background,
            keyTextColor: keyTextColor ?? UserThemeSeed.keyText,
            normalKeyFillColor: normalKeyFillColor ?? UserThemeSeed.normalKeyFill,
            specialKeyFillColor: specialKeyFillColor ?? UserThemeSeed.specialKeyFill,
            candidateTextColor: candidateTextColor ?? UserThemeSeed.candidateText,
        )
    }
}

extension CodableColor {
    /// Returns an opaque variant lightened toward white by `factor`: each 0-255 RGB
    /// component is lifted by `component + (255 - component) * factor`, truncated
    /// toward zero. Used to derive the candidate first-candidate highlight — a light
    /// tint of the gradient theme's first stop.
    func lightened(towardWhite factor: Double) -> CodableColor {
        func scaled(_ component: Double) -> UInt32 {
            let byte = UInt32((component * 255).rounded())
            return byte + UInt32(Double(255 - byte) * factor)
        }
        let hex = (scaled(red) << 16) | (scaled(green) << 8) | scaled(blue)
        return CodableColor(hex: hex)
    }

    /// Returns an opaque variant deepened toward black by `factor`: each 0-255 RGB
    /// component is recovered, multiplied, and truncated toward zero. Used to derive
    /// the candidate pressed tint from a gradient theme's first stop.
    ///
    /// The 0-1 → 0-255 → 0-1 (`init(hex:)`) round-trip is deliberate, not redundant:
    /// it forces per-byte integer truncation so the result is byte-identical to
    /// Android's `deepenedArgb` (`.toInt()`), keeping the CROSS-PLATFORM INVARIANT
    /// exact. A direct `Color(red: red * factor, …)` would keep float precision and
    /// drift from Android by sub-byte amounts. Do not "simplify" away the round-trip.
    func deepened(by factor: Double) -> CodableColor {
        func scaled(_ component: Double) -> UInt32 {
            let byte = UInt32((component * 255).rounded())
            return UInt32(Double(byte) * factor)
        }
        let hex = (scaled(red) << 16) | (scaled(green) << 8) | scaled(blue)
        return CodableColor(hex: hex)
    }
}
