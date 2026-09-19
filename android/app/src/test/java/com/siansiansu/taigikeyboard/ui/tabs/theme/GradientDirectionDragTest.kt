package com.siansiansu.taigikeyboard.ui.tabs.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Tests for [GradientDirectionDrag] — the finger-on-preview -> `ThemeGradient.angle` math
 * behind the theme editor's drag-to-set direction (CSS convention: 0° = ↑, clockwise), its
 * 45° preset snapping, and the TalkBack preset stepping. Mirrors iOS GradientDirectionDragTests.
 */
class GradientDirectionDragTest {
    private val centerX = 100f
    private val centerY = 100f
    private val deadZonePx = 8f

    private fun angle(
        dx: Float,
        dy: Float,
    ): Float? = GradientDirectionDrag.angle(centerX, centerY, centerX + dx, centerY + dy, deadZonePx)

    // region Direction

    // trace: finger straight above the centre (dy < 0) -> atan2(0, +) = 0 -> ↑ = 0°
    @Test
    fun angle_cardinalPoints_followCssConvention() {
        assertEquals(0f, angle(0f, -50f))
        assertEquals(90f, angle(50f, 0f))
        assertEquals(180f, angle(0f, 50f))
        assertEquals(270f, angle(-50f, 0f))
    }

    // trace: (dx, dy) = (50, -50) -> atan2(50, 50) = 45°; (-50, -50) -> -45 -> wrapped 315°
    @Test
    fun angle_diagonals_hitThePresets() {
        assertEquals(45f, angle(50f, -50f))
        assertEquals(135f, angle(50f, 50f))
        assertEquals(225f, angle(-50f, 50f))
        assertEquals(315f, angle(-50f, -50f))
    }

    // trace: hypot(5, 5) ≈ 7.07 < deadZone 8 -> null; hypot(6, 6) ≈ 8.49 -> 135°
    @Test
    fun angle_insideDeadZone_isNull() {
        assertNull(angle(5f, 5f))
        assertEquals(135f, angle(6f, 6f))
    }

    // endregion

    // region Snapping

    // trace: 48 -> nearest preset 45, |48 − 45| = 3 ≤ 6 -> 45; 52 -> |52 − 45| = 7 > 6 -> 52
    @Test
    fun snapped_withinTolerance_snapsToPreset() {
        assertEquals(45f, GradientDirectionDrag.snapped(48f))
        assertEquals(45f, GradientDirectionDrag.snapped(42f))
        assertEquals(52f, GradientDirectionDrag.snapped(52f))
    }

    // trace: 100.4 -> not near 90 or 135 -> rounded 100; 359.7 -> nearest preset 360 -> wrapped 0;
    // −20 (raw atan2 output) -> wrapped 340, nearest preset 315, |340 − 315| > 6 -> 340
    @Test
    fun snapped_offPreset_roundsToWholeDegreeInRange() {
        assertEquals(100f, GradientDirectionDrag.snapped(100.4f))
        assertEquals(0f, GradientDirectionDrag.snapped(359.7f))
        assertEquals(0f, GradientDirectionDrag.snapped(356f))
        assertEquals(340f, GradientDirectionDrag.snapped(-20f))
    }

    // endregion

    // region TalkBack stepping

    // trace: 100 / 45 = 2.22 -> clockwise: floor 2 + 1 = 3 -> 135; counter: ceil 3 − 1 = 2 -> 90
    @Test
    fun steppedPreset_fromOffPreset_goesToNeighbouringPresets() {
        assertEquals(135f, GradientDirectionDrag.steppedPreset(100f, clockwise = true))
        assertEquals(90f, GradientDirectionDrag.steppedPreset(100f, clockwise = false))
    }

    // trace: 315 + 45 = 360 -> wraps to 0; 0 − 45 = −45 -> wrapped 315
    @Test
    fun steppedPreset_fromPreset_stepsOneAndWraps() {
        assertEquals(90f, GradientDirectionDrag.steppedPreset(45f, clockwise = true))
        assertEquals(0f, GradientDirectionDrag.steppedPreset(315f, clockwise = true))
        assertEquals(315f, GradientDirectionDrag.steppedPreset(0f, clockwise = false))
    }

    // endregion
}
