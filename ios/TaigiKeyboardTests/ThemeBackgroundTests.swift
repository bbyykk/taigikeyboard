import SwiftUI
@testable import TaigiKeyboard
import XCTest

/// Tests for `ThemeBackground` / `ThemeGradient` — the single background field a
/// theme carries (USER 2026-09-19: one surface for keyboard + candidate bar), its
/// legacy-key decoding, the angle → unit-point math shared with the overlay
/// backdrops, and the user-theme seed.
final class ThemeBackgroundTests: XCTestCase {
    private func decode(_ json: String) throws -> KeyboardColorSettings {
        try JSONDecoder().decode(KeyboardColorSettings.self, from: Data(json.utf8))
    }

    /// Two arbitrary stops — `ThemeGradient` requires ≥2; these tests only care about the angle.
    private func gradient(angle: Double) -> ThemeGradient {
        ThemeGradient(stops: [CodableColor(hex: 0x000000), CodableColor(hex: 0xFFFFFF)], angle: angle)
    }

    private func panelPoints(angle: Double, fullKeyboardHeight: CGFloat, topInset: CGFloat) throws -> (start: UnitPoint, end: UnitPoint) {
        let backdrop = KeyboardOverlayBackdrop(gradient: gradient(angle: angle), fullKeyboardHeight: fullKeyboardHeight, topInset: topInset)
        return try XCTUnwrap(backdrop.panelUnitPoints)
    }

    // MARK: - Legacy decode

    // trace: old JSON `backgroundColor` (no `background`) → .solid(that color)
    func testDecode_legacyBackgroundColor_becomesSolid() throws {
        let colors = try decode(#"{ "backgroundColor": { "red": 1, "green": 0, "blue": 0, "alpha": 1 } }"#)
        XCTAssertEqual(colors.background, .solid(CodableColor(hex: 0xFF0000)))
        XCTAssertEqual(colors.solidBackgroundColor, CodableColor(hex: 0xFF0000))
        XCTAssertNil(colors.backgroundGradient)
    }

    // trace: old JSON `backgroundGradient` (2 stops, no angle) → .gradient at the vertical default angle,
    // and it wins over a legacy `backgroundColor` written beside it (gradient overrode the flat fill before)
    func testDecode_legacyBackgroundGradient_becomesVerticalGradient() throws {
        let colors = try decode(#"""
        { "backgroundColor": { "red": 1, "green": 0, "blue": 0, "alpha": 1 },
          "backgroundGradient": { "stops": [ { "red": 0, "green": 0, "blue": 0, "alpha": 1 },
                                             { "red": 1, "green": 1, "blue": 1, "alpha": 1 } ] } }
        """#)
        let gradient = try XCTUnwrap(colors.backgroundGradient)
        XCTAssertEqual(gradient.angle, ThemeGradient.defaultAngle)
        XCTAssertEqual(gradient.stops, [CodableColor(hex: 0x000000), CodableColor(hex: 0xFFFFFF)])
        XCTAssertNil(colors.solidBackgroundColor)
    }

    // trace: a legacy 1-stop gradient is not renderable → falls through to the legacy solid color
    func testDecode_legacySingleStopGradient_fallsBackToSolid() throws {
        let colors = try decode(#"""
        { "backgroundColor": { "red": 0, "green": 1, "blue": 0, "alpha": 1 },
          "backgroundGradient": { "stops": [ { "red": 0, "green": 0, "blue": 0, "alpha": 1 } ] } }
        """#)
        XCTAssertEqual(colors.background, .solid(CodableColor(hex: 0x00FF00)))
    }

    // trace: `candidateBackgroundColor` is dropped on decode — the candidate bar is the keyboard surface
    func testDecode_legacyCandidateBackground_isIgnored() throws {
        let colors = try decode(#"{ "candidateBackgroundColor": { "red": 1, "green": 0, "blue": 0, "alpha": 1 } }"#)
        XCTAssertEqual(colors, .default)
    }

    // trace: an unknown background `type` (written by a newer build) degrades to adaptive, other roles kept
    func testDecode_unknownBackgroundType_degradesToAdaptive() throws {
        let colors = try decode(#"""
        { "background": { "type": "hologram" },
          "keyTextColor": { "red": 0, "green": 0, "blue": 1, "alpha": 1 } }
        """#)
        XCTAssertNil(colors.background)
        XCTAssertEqual(colors.keyTextColor, CodableColor(hex: 0x0000FF))
    }

    // MARK: - Round trip

    // trace: encode writes only the `background` key (type + fields), never the legacy keys; decode restores it
    func testRoundTrip_gradientWithAngle_andNoLegacyKeys() throws {
        var colors = KeyboardColorSettings()
        colors.background = .gradient(ThemeGradient(stops: [CodableColor(hex: 0x112233), CodableColor(hex: 0x445566)], angle: 45))
        let data = try JSONEncoder().encode(colors)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("backgroundColor"), "legacy key must not be written: \(json)")
        XCTAssertFalse(json.contains("backgroundGradient"), "legacy key must not be written: \(json)")
        XCTAssertTrue(json.contains(#""type":"gradient""#), json)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardColorSettings.self, from: data), colors)
    }

    func testRoundTrip_solid() throws {
        var colors = KeyboardColorSettings()
        colors.background = .solid(CodableColor(hex: 0xABCDEF))
        let data = try JSONEncoder().encode(colors)
        XCTAssertTrue(try XCTUnwrap(String(data: data, encoding: .utf8)).contains(#""type":"solid""#))
        XCTAssertEqual(try JSONDecoder().decode(KeyboardColorSettings.self, from: data), colors)
    }

    // MARK: - Angle → unit points

    // trace: CSS convention — 180 = top→bottom edge-to-edge; 90 = left→right; 0 = bottom→top;
    // 135 = top-left → bottom-right corner-to-corner (Chebyshev-normalised diagonal)
    func testUnitPoints_presets() {
        let cases: [(angle: Double, start: UnitPoint, end: UnitPoint)] = [
            (180, UnitPoint(x: 0.5, y: 0), UnitPoint(x: 0.5, y: 1)),
            (0, UnitPoint(x: 0.5, y: 1), UnitPoint(x: 0.5, y: 0)),
            (90, UnitPoint(x: 0, y: 0.5), UnitPoint(x: 1, y: 0.5)),
            (270, UnitPoint(x: 1, y: 0.5), UnitPoint(x: 0, y: 0.5)),
            (135, UnitPoint(x: 0, y: 0), UnitPoint(x: 1, y: 1)),
            (315, UnitPoint(x: 1, y: 1), UnitPoint(x: 0, y: 0)),
            (45, UnitPoint(x: 0, y: 1), UnitPoint(x: 1, y: 0)),
            (225, UnitPoint(x: 1, y: 0), UnitPoint(x: 0, y: 1)),
        ]
        for c in cases {
            let points = gradient(angle: c.angle).unitPoints
            XCTAssertEqual(points.start.x, c.start.x, accuracy: 1e-9, "angle \(c.angle) start.x")
            XCTAssertEqual(points.start.y, c.start.y, accuracy: 1e-9, "angle \(c.angle) start.y")
            XCTAssertEqual(points.end.x, c.end.x, accuracy: 1e-9, "angle \(c.angle) end.x")
            XCTAssertEqual(points.end.y, c.end.y, accuracy: 1e-9, "angle \(c.angle) end.y")
        }
    }

    // trace: a panel covering [topInset, fullHeight] maps the vertical gradient's start ABOVE itself:
    // y' = (0·H − topInset) / (H − topInset) = −topInset / panelHeight (the #429-safe slice shift), end stays 1
    func testPanelUnitPoints_verticalGradient_shiftsStartAbovePanel() throws {
        let points = try panelPoints(angle: ThemeGradient.defaultAngle, fullKeyboardHeight: 300, topInset: 50)
        XCTAssertEqual(points.start.y, -50.0 / 250.0, accuracy: 1e-9)
        XCTAssertEqual(points.end.y, 1, accuracy: 1e-9)
        XCTAssertEqual(points.start.x, 0.5, accuracy: 1e-9)
    }

    // trace: a horizontal gradient is unaffected by the vertical slice except for its y row
    func testPanelUnitPoints_horizontalGradient_keepsXAndRemapsY() throws {
        let points = try panelPoints(angle: 90, fullKeyboardHeight: 300, topInset: 50)
        XCTAssertEqual(points.start.x, 0, accuracy: 1e-9)
        XCTAssertEqual(points.end.x, 1, accuracy: 1e-9)
        XCTAssertEqual(points.start.y, (0.5 * 300 - 50) / 250, accuracy: 1e-9)
        XCTAssertEqual(points.end.y, points.start.y, accuracy: 1e-9)
    }

    // trace: degenerate geometry (panelHeight ≤ 0) → unshifted points, no division by zero
    func testPanelUnitPoints_degenerateGeometry_fallsBackToUnshifted() throws {
        let points = try panelPoints(angle: 180, fullKeyboardHeight: 50, topInset: 50)
        XCTAssertEqual(points.start.y, 0, accuracy: 1e-9)
        XCTAssertEqual(points.end.y, 1, accuracy: 1e-9)
    }

    // trace: a flat / default theme has no gradient → no panel points (the backdrop paints the flat color)
    func testPanelUnitPoints_noGradient_isNil() {
        XCTAssertNil(KeyboardOverlayBackdrop(gradient: nil, fullKeyboardHeight: 300, topInset: 50).panelUnitPoints)
    }

    // trace: a new-format gradient with one stop is not renderable → decode degrades to adaptive
    func testDecode_newFormatSingleStopGradient_degradesToAdaptive() throws {
        let colors = try decode(#"{ "background": { "type": "gradient", "stops": [ { "red": 0, "green": 0, "blue": 0, "alpha": 1 } ] } }"#)
        XCTAssertNil(colors.background)
    }

    // MARK: - Seed

    // trace: the seed sets every role (no nil) so a user theme never follows light / dark
    func testUserThemeSeed_hasNoNilRole() {
        let seed = UserThemeSeed.colors
        XCTAssertEqual(seed.background, .solid(CodableColor(hex: 0xD4D5DD)))
        XCTAssertNotNil(seed.keyTextColor)
        XCTAssertNotNil(seed.normalKeyFillColor)
        XCTAssertNotNil(seed.specialKeyFillColor)
        XCTAssertNotNil(seed.candidateTextColor)
    }

    // trace: seeding fills only nil roles; set roles (incl. a gradient background) are kept verbatim
    func testSeededForUserTheme_fillsOnlyNilRoles() {
        var colors = KeyboardColorSettings()
        colors.background = .gradient(ThemeGradient(stops: [CodableColor(hex: 0x000000), CodableColor(hex: 0xFFFFFF)], angle: 90))
        colors.keyTextColor = CodableColor(hex: 0x123456)
        let seeded = colors.seededForUserTheme()
        XCTAssertEqual(seeded.background, colors.background)
        XCTAssertEqual(seeded.keyTextColor, CodableColor(hex: 0x123456))
        XCTAssertEqual(seeded.normalKeyFillColor, UserThemeSeed.colors.normalKeyFillColor)
        XCTAssertEqual(seeded.specialKeyFillColor, UserThemeSeed.colors.specialKeyFillColor)
        XCTAssertEqual(seeded.candidateTextColor, UserThemeSeed.colors.candidateTextColor)
        XCTAssertEqual(UserThemeSeed.colors.seededForUserTheme(), UserThemeSeed.colors, "seeding the seed is a no-op")
    }
}
