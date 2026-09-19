import CoreGraphics
@testable import TaigiKeyboard
import XCTest

/// Tests for `GradientDirectionDrag` — the finger-on-preview → `ThemeGradient.angle`
/// math behind the theme editor's drag-to-set direction (CSS convention: 0° = ↑,
/// clockwise), its 45° preset snapping, and the VoiceOver preset stepping.
final class GradientDirectionDragTests: XCTestCase {
    private let center = CGPoint(x: 100, y: 100)

    private func angle(dx: CGFloat, dy: CGFloat) -> Double? {
        GradientDirectionDrag.angle(from: center, to: CGPoint(x: center.x + dx, y: center.y + dy))
    }

    // MARK: - Direction

    // trace: finger straight above the centre (dy < 0) → atan2(0, +) = 0 → ↑ = 0°
    func testAngle_cardinalPoints_followCSSConvention() {
        XCTAssertEqual(angle(dx: 0, dy: -50), 0)
        XCTAssertEqual(angle(dx: 50, dy: 0), 90)
        XCTAssertEqual(angle(dx: 0, dy: 50), 180)
        XCTAssertEqual(angle(dx: -50, dy: 0), 270)
    }

    // trace: (dx, dy) = (50, -50) → atan2(50, 50) = 45°; (-50, -50) → atan2(-50, 50) = -45 → 315°
    func testAngle_diagonals_hitThePresets() {
        XCTAssertEqual(angle(dx: 50, dy: -50), 45)
        XCTAssertEqual(angle(dx: 50, dy: 50), 135)
        XCTAssertEqual(angle(dx: -50, dy: 50), 225)
        XCTAssertEqual(angle(dx: -50, dy: -50), 315)
    }

    // trace: hypot(5, 5) ≈ 7.07 < deadZone 8 → nil; hypot(6, 6) ≈ 8.49 → 45°
    func testAngle_insideDeadZone_isNil() {
        XCTAssertNil(angle(dx: 5, dy: 5))
        XCTAssertEqual(angle(dx: 6, dy: 6), 135)
    }

    // MARK: - Snapping

    // trace: 48 → nearest preset 45, |48 − 45| = 3 ≤ 6 → 45; 52 → |52 − 45| = 7 > 6 → 52
    func testSnapped_withinTolerance_snapsToPreset() {
        XCTAssertEqual(GradientDirectionDrag.snapped(48), 45)
        XCTAssertEqual(GradientDirectionDrag.snapped(42), 45)
        XCTAssertEqual(GradientDirectionDrag.snapped(52), 52)
    }

    // trace: 100.4 → not near 90 or 135 → rounded 100; 359.7 → nearest preset 360 → wrapped 0;
    // −20 (raw atan2 output) → nearest preset 0, |−20| > 6 → −20 → wrapped 340
    func testSnapped_offPreset_roundsToWholeDegreeInRange() {
        XCTAssertEqual(GradientDirectionDrag.snapped(100.4), 100)
        XCTAssertEqual(GradientDirectionDrag.snapped(359.7), 0)
        XCTAssertEqual(GradientDirectionDrag.snapped(356), 0)
        XCTAssertEqual(GradientDirectionDrag.snapped(-20), 340)
    }

    // MARK: - VoiceOver stepping

    // trace: 100 / 45 = 2.22 → clockwise: floor 2 + 1 = 3 → 135; counter: ceil 3 − 1 = 2 → 90
    func testSteppedPreset_fromOffPreset_goesToNeighbouringPresets() {
        XCTAssertEqual(GradientDirectionDrag.steppedPreset(from: 100, clockwise: true), 135)
        XCTAssertEqual(GradientDirectionDrag.steppedPreset(from: 100, clockwise: false), 90)
    }

    // trace: 315 + 45 = 360 → wraps to 0; 0 − 45 = −45 → wrapped 315
    func testSteppedPreset_fromPreset_stepsOneAndWraps() {
        XCTAssertEqual(GradientDirectionDrag.steppedPreset(from: 45, clockwise: true), 90)
        XCTAssertEqual(GradientDirectionDrag.steppedPreset(from: 315, clockwise: true), 0)
        XCTAssertEqual(GradientDirectionDrag.steppedPreset(from: 0, clockwise: false), 315)
    }
}
