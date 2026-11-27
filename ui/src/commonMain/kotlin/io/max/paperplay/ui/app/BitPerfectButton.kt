package io.max.paperplay.ui.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.TrueAudioIcon
import io.max.paperplay.ui.components.toggleOnColor
import io.max.paperplay.ui.theme.LocalAmbientClock
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.Motion
import io.max.paperplay.ui.theme.rememberAmbientClock

/**
 * The bit-perfect switch for the player bar: a gem for true audio. While it is on, tiny notes and sparks drift up from it
 * (not with reduced motion, where the gem just takes the on colour).
 */
@Composable
fun BitPerfectButton(on: Boolean, off: Color, iconSize: Modifier, unavailable: String? = null, onToggle: () -> Unit) {
    if (unavailable != null) {
        // Greyed and struck through, with the reason on hover, so it is clear why it cannot be switched on.
        val grey = off.copy(alpha = 0.38f)
        DesktopTooltip(unavailable) {
            IconButton(onToggle, enabled = false) {
                AppIcon(
                    TrueAudioIcon, "Bit-perfect ($unavailable)",
                    iconSize.drawWithContent {
                        drawContent()
                        // Inset to the glyph itself (Material icons keep about a sixth of the box empty on each side).
                        val i = size.minDimension * 0.18f
                        drawLine(grey, Offset(i, size.height - i), Offset(size.width - i, i), strokeWidth = 2.dp.toPx(), cap = StrokeCap.Round)
                    },
                    tint = grey,
                )
            }
        }
        return
    }
    val accent = toggleOnColor()
    val foreground = io.max.paperplay.ui.rememberAppForeground()
    Box {
        if (on && foreground && !LocalReduceMotion.current) Floaters(accent)
        IconButton(onToggle) { AppIcon(TrueAudioIcon, if (on) "Bit-perfect (on)" else "Bit-perfect", iconSize, tint = if (on) accent else off) }
    }
}

/** Why bit-perfect cannot be switched on for the current output (PC on Bluetooth), or null when it can. */
@Composable
fun bitPerfectUnavailable(backend: PlayerControls): String? {
    val bluetooth = !io.max.paperplay.ui.isPhone && backend.outputInfo.collectAsState().value?.bluetooth == true
    return if (bluetooth) "Not supported on Bluetooth devices" else null
}

/** Four small marks that rise from the button and fade, each a quarter of the cycle behind the one before. */
@Composable
private fun Floaters(color: Color) {
    val clock = LocalAmbientClock.current ?: rememberAmbientClock(active = true)
    clock.subscribe(active = true)
    val marks = listOf(
        Triple(Icons.Rounded.MusicNote, (-10).dp, 0.00f),
        Triple(Icons.Rounded.Bolt, 8.dp, 0.25f),
        Triple(Icons.Rounded.MusicNote, 12.dp, 0.50f),
        Triple(Icons.Rounded.Bolt, (-6).dp, 0.75f),
    )
    for ((icon, dx, shift) in marks) {
        Icon(
            icon, null,
            Modifier.size(10.dp).graphicsLayer {
                val p = (clock.phase(Motion.Ambient.BitPerfectPeriodMs) + shift) % 1f
                translationX = (19.dp + dx).toPx()
                translationY = (30f - 34f * p).dp.toPx()
                alpha = if (p < 0.15f) p / 0.15f else 1f - (p - 0.15f) / 0.85f
            },
            tint = color,
        )
    }
}
