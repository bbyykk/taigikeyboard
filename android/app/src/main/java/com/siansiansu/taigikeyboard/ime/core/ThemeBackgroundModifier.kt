// Compose painting of a ThemeBackground (the keyboard surface) as a modifier + brush.

package com.siansiansu.taigikeyboard.ime.core

import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * The gradient as a Compose brush over a surface of [size] that sits [topInsetPx] below the
 * keyboard top: the unit points are taken over the full keyboard (`size.height + topInsetPx`)
 * and shifted up by the inset, so a panel mounted below the smartbar shows exactly its slice
 * and stays continuous with the keyboard above it. A surface spanning the whole keyboard
 * passes the default inset 0.
 */
fun ThemeGradient.brush(
    size: Size,
    topInsetPx: Float = 0f,
): Brush {
    val (start, end) = unitPoints()
    val fullHeight = size.height + topInsetPx
    return Brush.linearGradient(
        colors = stops.map { Color(it) },
        start = Offset(start.x * size.width, start.y * fullHeight - topInsetPx),
        end = Offset(end.x * size.width, end.y * fullHeight - topInsetPx),
    )
}

/**
 * Paints [background] as the surface: a solid color, or the gradient (see [ThemeGradient.brush]
 * for [topInsetPx]); null (adaptive) paints [fallback]. The modifier is remembered on its inputs
 * so the gradient's draw cache survives the host's recompositions and the brush is rebuilt only
 * when the draw size changes.
 */
@Composable
fun Modifier.themeBackground(
    background: ThemeBackground?,
    fallback: Color,
    topInsetPx: Float = 0f,
): Modifier =
    then(
        remember(background, fallback, topInsetPx) {
            when (background) {
                is ThemeBackground.Solid -> Modifier.background(Color(background.color))
                is ThemeBackground.Gradient ->
                    Modifier.drawWithCache {
                        val brush = background.gradient.brush(size, topInsetPx)
                        onDrawBehind { drawRect(brush) }
                    }
                null -> Modifier.background(fallback)
            }
        },
    )
