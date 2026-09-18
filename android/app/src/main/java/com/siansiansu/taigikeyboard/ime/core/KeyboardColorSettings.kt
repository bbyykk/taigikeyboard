// Persisted keyboard color settings (JSON in DataStore); a null role falls back to the platform theme attr.

package com.siansiansu.taigikeyboard.ime.core

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/** A point in the unit square of a painted surface (0..1 on both axes; y down). */
data class UnitPoint(val x: Float, val y: Float)

/**
 * A linear keyboard-background gradient: >=2 ARGB [stops] from start to end plus
 * the direction [angle] in degrees, CSS / Figma convention (0 = bottom->top,
 * 90 = left->right, 180 = top->bottom, clockwise). Built-in gradient themes use
 * the vertical [DEFAULT_ANGLE].
 *
 * ">=2 stops" is enforced at construction ([init] require, [fromJson] null), so
 * every gradient a render site sees is renderable. Decode is forward-compatible:
 * an `angle` absent from old JSON reads as [DEFAULT_ANGLE].
 */
// CROSS-PLATFORM INVARIANT — mirrors ios/Sources/TaigiKeyboard/Settings/KeyboardColorSettings.swift ThemeGradient
// (stops + angle, same degree convention and unit-point math). Drift causes silent divergence.
data class ThemeGradient(
    val stops: List<Int>,
    val angle: Float = DEFAULT_ANGLE,
) {
    init {
        require(stops.size >= MINIMUM_STOPS) { "a gradient needs at least $MINIMUM_STOPS stops, got ${stops.size}" }
    }

    /**
     * Start / end points for [angle] in the unit square of the painted surface. The CSS
     * direction vector `(sin θ, -cos θ)` (y down) is normalised by its larger component so
     * the diagonal presets run corner to corner (135° = top-left -> bottom-right) and the
     * axis presets run edge to edge (180° = top-centre -> bottom-centre).
     */
    fun unitPoints(): Pair<UnitPoint, UnitPoint> {
        val radians = Math.toRadians(angle.toDouble())
        val dx = sin(radians)
        val dy = -cos(radians)
        val magnitude = max(abs(dx), abs(dy))
        val halfX = (dx / magnitude / 2).toFloat()
        val halfY = (dy / magnitude / 2).toFloat()
        return UnitPoint(0.5f - halfX, 0.5f - halfY) to UnitPoint(0.5f + halfX, 0.5f + halfY)
    }

    companion object {
        /** Vertical top->bottom, the direction every built-in gradient theme uses. */
        const val DEFAULT_ANGLE = 180f
        const val MINIMUM_STOPS = 2

        /** How far the end stop is lifted toward white in [seeded]. */
        private const val SEED_LIGHTEN_FACTOR = 0.45

        /**
         * The first vertical gradient a user sees when switching a solid background to
         * 漸層: the solid color running into a lighter tint of itself.
         */
        fun seeded(solid: Int): ThemeGradient = ThemeGradient(listOf(solid, lightenedArgb(solid, SEED_LIGHTEN_FACTOR)))

        /** Decodes `{ "stops": [...], "angle"?: n }`; null when fewer than [MINIMUM_STOPS] stops. */
        fun fromJson(obj: JSONObject): ThemeGradient? {
            val array = obj.optJSONArray("stops") ?: return null
            if (array.length() < MINIMUM_STOPS) return null
            val angle = obj.optDouble("angle", DEFAULT_ANGLE.toDouble()).toFloat()
            return ThemeGradient(List(array.length()) { array.getInt(it) }, angle)
        }
    }
}

/**
 * What paints the keyboard surface — one field, mutually exclusive cases. The
 * candidate bar is the same surface: a solid background colours both, a gradient
 * paints once behind both (the bar goes transparent). A null
 * [KeyboardColorSettings.background] means "adaptive" (`?keyboard_bgColor`) and
 * is reserved for the 經典 預設 head.
 *
 * JSON: `{"type":"solid","color":argb}` / `{"type":"gradient","stops":[…],"angle":180}`.
 */
// CROSS-PLATFORM INVARIANT — mirrors ios/Sources/TaigiKeyboard/Settings/KeyboardColorSettings.swift ThemeBackground
// (same `type` discriminator and field names; iOS stores the colour as an RGBA object). Drift causes silent divergence.
sealed class ThemeBackground {
    data class Solid(val color: Int) : ThemeBackground()

    data class Gradient(val gradient: ThemeGradient) : ThemeBackground()

    /** The JSON discriminator, also the editor's 純色 / 漸層 segmented choice. */
    enum class Kind(val jsonValue: String) {
        SOLID("solid"),
        GRADIENT("gradient"),
    }

    val kind: Kind
        get() =
            when (this) {
                is Solid -> Kind.SOLID
                is Gradient -> Kind.GRADIENT
            }

    val asGradient: ThemeGradient?
        get() = (this as? Gradient)?.gradient

    fun toJson(): JSONObject =
        JSONObject().put("type", kind.jsonValue).apply {
            when (this@ThemeBackground) {
                is Solid -> put("color", color)
                is Gradient -> put("stops", JSONArray(gradient.stops)).put("angle", gradient.angle.toDouble())
            }
        }

    companion object {
        /** Decodes one background; null for an unknown `type` (a newer build) or a non-renderable gradient. */
        fun fromJson(obj: JSONObject): ThemeBackground? =
            when (obj.optString("type")) {
                Kind.SOLID.jsonValue -> obj.optIntOrNull("color")?.let(::Solid)
                Kind.GRADIENT.jsonValue -> ThemeGradient.fromJson(obj)?.let(::Gradient)
                else -> null
            }
    }
}

/**
 * Custom keyboard color settings.
 *
 * Each role is nullable -- null means "use the platform theme attr color".
 * Stored as JSON in DataStore via colorSettings preference.
 *
 * Matches iOS KeyboardColorSettings structure.
 */
data class KeyboardColorSettings(
    /** The keyboard + candidate-bar surface. null = adaptive (`?keyboard_bgColor`). */
    val background: ThemeBackground? = null,
    val keyTextColor: Int? = null,
    val normalKeyFillColor: Int? = null,
    val specialKeyFillColor: Int? = null,
    val candidateTextColor: Int? = null,
) {
    /**
     * The background gradient, or null for a solid / adaptive background. Single source
     * for the candidate-tint derivation and the built-in theme tests.
     */
    val backgroundGradient: ThemeGradient?
        get() = background?.asGradient

    /**
     * Fills every null role from [UserThemeSeed]. Applied when a user theme is decoded
     * ([UserTheme.fromJson]), so themes saved before the seed existed become
     * scheme-invariant without a migration write.
     */
    fun seededForUserTheme(): KeyboardColorSettings =
        KeyboardColorSettings(
            background = background ?: UserThemeSeed.BACKGROUND,
            keyTextColor = keyTextColor ?: UserThemeSeed.KEY_TEXT,
            normalKeyFillColor = normalKeyFillColor ?: UserThemeSeed.NORMAL_KEY_FILL,
            specialKeyFillColor = specialKeyFillColor ?: UserThemeSeed.SPECIAL_KEY_FILL,
            candidateTextColor = candidateTextColor ?: UserThemeSeed.CANDIDATE_TEXT,
        )

    /** The JSON object form. [toJson] is the string serialization; nested users (e.g. [ThemeAppearance]) embed this directly. */
    fun toJsonObject(): JSONObject {
        val json = JSONObject()
        background?.let { json.put("background", it.toJson()) }
        keyTextColor?.let { json.put("keyTextColor", it) }
        normalKeyFillColor?.let { json.put("normalKeyFillColor", it) }
        specialKeyFillColor?.let { json.put("specialKeyFillColor", it) }
        candidateTextColor?.let { json.put("candidateTextColor", it) }
        return json
    }

    fun toJson(): String = toJsonObject().toString()

    companion object {
        fun fromJson(json: String): KeyboardColorSettings {
            if (json.isBlank() || json == "{}") return KeyboardColorSettings()
            return try {
                fromJson(JSONObject(json))
            } catch (e: Exception) {
                KeyboardColorSettings()
            }
        }

        /**
         * `background` replaced three older keys. Decoding still reads them so a theme
         * written by an older build keeps its look: `backgroundGradient` (>=2 stops) ->
         * [ThemeBackground.Gradient] at the vertical default angle, else `backgroundColor`
         * -> [ThemeBackground.Solid]. `candidateBackgroundColor` is dropped — the candidate
         * bar is the keyboard surface now (USER 2026-09-19). Encoding writes only `background`.
         */
        fun fromJson(obj: JSONObject): KeyboardColorSettings =
            KeyboardColorSettings(
                background =
                    obj.optJSONObject("background")?.let { ThemeBackground.fromJson(it) }
                        ?: obj.optJSONObject("backgroundGradient")?.let { ThemeGradient.fromJson(it) }?.let { ThemeBackground.Gradient(it) }
                        ?: obj.optIntOrNull("backgroundColor")?.let { ThemeBackground.Solid(it) },
                keyTextColor = obj.optIntOrNull("keyTextColor"),
                normalKeyFillColor = obj.optIntOrNull("normalKeyFillColor"),
                specialKeyFillColor = obj.optIntOrNull("specialKeyFillColor"),
                candidateTextColor = obj.optIntOrNull("candidateTextColor"),
            )
    }
}

private fun JSONObject.optIntOrNull(key: String): Int? = if (has(key) && !isNull(key)) getInt(key) else null

/**
 * The concrete light palette every user theme starts from, so a user theme never
 * carries a null (scheme-following) role and renders identically in light and dark
 * mode (USER 2026-09-19). Background is the light keyboard grey; the special key
 * fill is the iOS light dark-button grey.
 */
// CROSS-PLATFORM INVARIANT — mirrors ios/Sources/TaigiKeyboard/Settings/KeyboardColorSettings.swift UserThemeSeed.
// Drift = a new custom theme starts from different colors per platform.
object UserThemeSeed {
    const val SOLID_COLOR = 0xFFD4D5DD.toInt()
    val BACKGROUND: ThemeBackground = ThemeBackground.Solid(SOLID_COLOR)
    const val KEY_TEXT = 0xFF000000.toInt()
    const val NORMAL_KEY_FILL = 0xFFFFFFFF.toInt()
    const val SPECIAL_KEY_FILL = 0xFFABB1BA.toInt()
    const val CANDIDATE_TEXT = 0xFF000000.toInt()

    val colors =
        KeyboardColorSettings(
            background = BACKGROUND,
            keyTextColor = KEY_TEXT,
            normalKeyFillColor = NORMAL_KEY_FILL,
            specialKeyFillColor = SPECIAL_KEY_FILL,
            candidateTextColor = CANDIDATE_TEXT,
        )
}

// CROSS-PLATFORM INVARIANT — mirrors ios/Sources/TaigiKeyboard/Settings/KeyboardColorSettings.swift
// candidateHighlightLightenFactor / candidatePressedDeepenFactor. Drift causes silent divergence.
// Factors used to derive the candidate strip's first-candidate highlight + pressed tints from a
// gradient theme's first stop, so those states match the theme hue instead of a neutral keycap color.
// The highlight is LIGHTENED toward white (a light tint, lighter than the gradient bar so it stays
// visible); the pressed state is DEEPENED toward black. A flat/scaffold theme (no gradient) keeps
// the neutral attr-based fallback.
const val CANDIDATE_HIGHLIGHT_LIGHTEN_FACTOR = 0.5
const val CANDIDATE_PRESSED_DEEPEN_FACTOR = 0.65

/**
 * Returns an opaque ARGB color lightened toward white by [factor]: each 0-255 RGB component is
 * lifted by `c + (255 - c) * factor`, truncated toward zero (alpha forced 0xFF). Used to derive the
 * candidate first-candidate highlight — a light tint of a gradient theme's first stop.
 */
fun lightenedArgb(argb: Int, factor: Double): Int {
    fun lift(c: Int): Int = c + ((255 - c) * factor).toInt()
    val r = lift(argb shr 16 and 0xFF)
    val g = lift(argb shr 8 and 0xFF)
    val b = lift(argb and 0xFF)
    return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
}

/**
 * Returns an opaque ARGB color deepened toward black by [factor]: each 0-255 RGB component is
 * multiplied and truncated toward zero (alpha forced 0xFF). Used to derive the candidate pressed
 * tint from a gradient theme's first stop.
 */
fun deepenedArgb(argb: Int, factor: Double): Int {
    val r = ((argb shr 16 and 0xFF) * factor).toInt()
    val g = ((argb shr 8 and 0xFF) * factor).toInt()
    val b = ((argb and 0xFF) * factor).toInt()
    return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
}
