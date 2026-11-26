package io.max.paperplay.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.theme.LocalAmbientClock
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.Motion
import io.max.paperplay.ui.theme.rememberAmbientClock

/** A grey placeholder shape with a soft light sweeping across it using the shared [AmbientClock] (still under reduced motion). */
@Composable
fun Modifier.skeleton(shape: androidx.compose.ui.graphics.Shape = RoundedCornerShape(10.dp)): Modifier {
    val reduce = LocalReduceMotion.current
    val base = MaterialTheme.colorScheme.surfaceContainerHigh
    if (reduce) return this.clip(shape).background(base)
    val clock = LocalAmbientClock.current ?: rememberAmbientClock(active = true)
    clock.subscribe(active = true)
    val light = androidx.compose.ui.graphics.lerp(base, MaterialTheme.colorScheme.onSurface, 0.10f)
    return this.clip(shape).background(base).drawWithCache {
        val w = size.width.coerceAtLeast(1f)
        val brush = androidx.compose.ui.graphics.Brush.linearGradient(
            listOf(androidx.compose.ui.graphics.Color.Transparent, light, androidx.compose.ui.graphics.Color.Transparent),
            start = androidx.compose.ui.geometry.Offset(0f, 0f),
            end = androidx.compose.ui.geometry.Offset(w, size.height * 0.4f),
        )
        onDrawWithContent {
            drawContent()
            val tx = -w + clock.phase(Motion.Ambient.ShimmerPeriodMs) * 2f * w
            withTransform({ translate(left = tx) }) {
                drawRect(brush, topLeft = androidx.compose.ui.geometry.Offset(-tx, 0f), size = size)
            }
        }
    }
}

/** [skeleton] as a ready-made modifier for a cover-sized shape (the clip comes from the caller's box). */
@Composable
fun skeletonFill(): Modifier = Modifier.skeleton(androidx.compose.ui.graphics.RectangleShape)

/** The six quick tiles of Home as placeholders. */
@Composable
fun ModernHomeSkeleton(modifier: Modifier = Modifier, bottomPadding: Dp = 0.dp) {
    Column(
        modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = bottomPadding),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        // 1. Full-pill Favorites hero + 2-column full-pill mix tiles
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            androidx.compose.foundation.layout.Box(Modifier.fillMaxWidth().height(68.dp).skeleton(appShape(34.dp, CornerArea.Cards)))
            repeat(2) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    androidx.compose.foundation.layout.Box(Modifier.weight(1f).height(56.dp).skeleton(appShape(28.dp, CornerArea.Cards)))
                    androidx.compose.foundation.layout.Box(Modifier.weight(1f).height(56.dp).skeleton(appShape(28.dp, CornerArea.Cards)))
                }
            }
        }
        // 2. Recently played shelf (136dp covers)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            androidx.compose.foundation.layout.Box(Modifier.width(140.dp).height(20.dp).skeleton(RoundedCornerShape(8.dp)))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                repeat(3) {
                    Column(Modifier.width(136.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        androidx.compose.foundation.layout.Box(Modifier.size(136.dp).skeleton(appShape(20.dp, CornerArea.Covers)))
                        androidx.compose.foundation.layout.Box(Modifier.fillMaxWidth(0.8f).height(13.dp).skeleton(RoundedCornerShape(6.dp)))
                    }
                }
            }
        }
        // 3. Your daily mixes tall 28dp cards
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            androidx.compose.foundation.layout.Box(Modifier.width(156.dp).height(20.dp).skeleton(RoundedCornerShape(8.dp)))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                repeat(2) {
                    androidx.compose.foundation.layout.Box(Modifier.width(164.dp).height(204.dp).skeleton(appShape(28.dp, CornerArea.Cards)))
                }
            }
        }
    }
}
