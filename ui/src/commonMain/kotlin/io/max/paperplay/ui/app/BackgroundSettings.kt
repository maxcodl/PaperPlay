package io.max.paperplay.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.AuroraSeek
import io.max.paperplay.ui.components.WavySeek
import io.max.paperplay.ui.theme.schemeFromSeed
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.abs

/** The Background choice on Settings > Appearance > Display, with the controls of the chosen mode below it. */
@Composable
fun BackgroundSettings(prefs: UiPrefs) {
    SectionLabel("Background")
    ChoiceRow(BgMode.entries, prefs.background, { it.label }, prefs::putBackground)
    Text(
        when (prefs.background) {
            BgMode.Plain -> "A flat colour. Also the lowest-power choice."
            BgMode.Cover -> "The playing song's colours wash down from the top."
            BgMode.CoverBlur -> "The playing song's cover, blurred and dimmed."
            BgMode.Gradient -> "Your own colours."
            BgMode.Wallpaper -> "A picture of your own."
            BgMode.Animated -> "Moving shapes in your colours. Pauses when the app is in the background; choose Plain to turn motion off."
        },
        Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    when (prefs.background) {
        BgMode.Gradient -> GradientControls(prefs)
        BgMode.Wallpaper -> WallpaperControls(prefs)
        BgMode.Animated -> AnimatedControls(prefs)
        else -> {}
    }
}

/** App-wide UI style selector (Android only). */
@Composable
fun UiStyleSettings(prefs: UiPrefs) {
    SectionLabel("App style")
    ChoiceRow(UiStyle.entries, prefs.uiStyle, { it.label }, prefs::putUiStyle)
}

/** Full-screen player style selector under Settings > Appearance > Display (Android only). */
@Composable
fun PlayerStyleSettings(prefs: UiPrefs) {
    SectionLabel("Full-screen player")
    ChoiceRow(PlayerStyle.entries, prefs.playerStyle, { it.label }, prefs::putPlayerStyle)
    val effective = resolveEffectivePlayerStyle(prefs, isAndroid = true)
    Text(
        when (prefs.playerStyle) {
            PlayerStyle.FollowApp -> "Follows App style (currently ${effective.label})."
            PlayerStyle.Default -> "Cover-tinted theme with classic controls."
            PlayerStyle.Modern -> "Blurred cover backdrop with dark frosted glass controls and quality badges."
        },
        Modifier.padding(horizontal = 20.dp),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    if (effective == PlayerStyle.Modern || prefs.uiStyle == UiStyle.Modern) {
        SliderRow(
            title = "Backdrop blur: ${prefs.modernPlayerBlur.toInt()} dp",
            value = prefs.modernPlayerBlur,
            range = 0f..40f,
            onChange = { prefs.putModernPlayerBlur(it) },
        )
    }
}

/** Progress Bar Style selector with a compact interactive live preview on Settings > Appearance. */
@Composable
fun ProgressBarStyleSettings(prefs: UiPrefs, backend: CoreBackend? = null) {
    SectionLabel("Progress bar")
    ChoiceRow(ProgressBarStyle.entries, prefs.progressBarStyle, { it.label }, prefs::putProgressBarStyle)
    Text(
        when (prefs.progressBarStyle) {
            ProgressBarStyle.SQUIGGLY_WAVE -> "Material 3 wavy progress bar."
            ProgressBarStyle.AURORA_WAVE -> "Soft white aurora ribbons with a light tint from the playing cover."
        },
        Modifier.padding(horizontal = 20.dp),
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
    )
    val coverUri = backend?.playback?.collectAsState()?.value?.current?.coverUri
    val base = MaterialTheme.colorScheme
    val previewScheme = coverScheme(coverUri) ?: remember(base.primary) { schemeFromSeed(base.primary.toArgb(), dark = true) }
    val previewColors = auroraPalette(coverUri, previewScheme.primary)
    var previewProgress by remember { mutableFloatStateOf(0.64f) }
    MaterialTheme(colorScheme = previewScheme) {
        Box(
            Modifier
                .padding(horizontal = 20.dp, vertical = 10.dp)
                .fillMaxWidth()
                .clip(appShape(16.dp, CornerArea.Cards))
                .background(
                    Brush.verticalGradient(
                        0f to lerp(previewScheme.primaryContainer, Color.Black, 0.35f),
                        1f to lerp(previewScheme.surfaceContainerLow, Color.Black, 0.85f),
                    ),
                )
                .padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            when (prefs.progressBarStyle) {
                ProgressBarStyle.SQUIGGLY_WAVE -> WavySeek(
                    progress = { previewProgress },
                    buffered = { (previewProgress + 0.2f).coerceAtMost(1f) },
                    playing = true,
                    onSeek = { previewProgress = it },
                    modifier = Modifier.fillMaxWidth(),
                )
                ProgressBarStyle.AURORA_WAVE -> AuroraSeek(
                    progress = { previewProgress },
                    buffered = { (previewProgress + 0.2f).coerceAtMost(1f) },
                    playing = true,
                    onSeek = { previewProgress = it },
                    colors = previewColors,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun GradientControls(prefs: UiPrefs) {
    Box(
        Modifier.padding(horizontal = 20.dp, vertical = 8.dp).fillMaxWidth().height(72.dp).clip(RoundedCornerShape(16.dp))
            .drawBehind {
                val stops = listOf(Color(prefs.bgGradC1), Color(prefs.bgGradC2)) + listOfNotNull(prefs.bgGradC3.takeIf { it != 0 }?.let { Color(it) })
                drawRect(angledBrush(stops, prefs.bgGradAngle, size.width, size.height))
            },
    )
    SwitchRow("Start from the cover colour", prefs.bgGradCover, { prefs.putBgGrad(cover = it) }, subtitle = "The first colour follows the playing song")
    if (!prefs.bgGradCover) ColorRow("First colour", prefs.bgGradC1) { prefs.putBgGrad(c1 = it) }
    ColorRow("Second colour", prefs.bgGradC2) { prefs.putBgGrad(c2 = it) }
    SwitchRow("Third colour", prefs.bgGradC3 != 0, { on -> prefs.putBgGrad(c3 = if (on) 0xFFE8487F.toInt() else 0) })
    if (prefs.bgGradC3 != 0) ColorRow("Third colour", prefs.bgGradC3) { prefs.putBgGrad(c3 = it) }
    SliderRow("Angle: ${prefs.bgGradAngle.toInt()} degrees", prefs.bgGradAngle, 0f..360f, { prefs.putBgGrad(angle = it) })
}

@Composable
private fun WallpaperControls(prefs: UiPrefs) {
    val pick = io.max.paperplay.ui.LocalAppEnv.current?.pickPhoto
    if (pick != null) Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        OutlinedButton({ pick { path ->
            if (path != null) {
                // pickPhoto clears "photo-*" files; a renamed copy keeps the wallpaper and the profile photo apart.
                val f = java.io.File(path)
                val kept = runCatching { java.io.File(f.parentFile, "wallpaper-${f.name.removePrefix("photo-")}").also { f.renameTo(it) } }.getOrNull()
                prefs.bgImage?.let { old -> runCatching { java.io.File(old).takeIf { it.name.startsWith("wallpaper-") && it != kept }?.delete() } }
                prefs.putBgImage((kept?.takeIf { it.exists() } ?: f).path)
            }
        } }) { Text(if (prefs.bgImage == null) "Choose picture" else "Change picture") }
        if (prefs.bgImage != null) OutlinedButton({ prefs.putBgImage(null) }) { Text("Remove") }
    } else Text("Picking a picture is not available here.", Modifier.padding(horizontal = 20.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    SliderRow("Blur: ${prefs.bgBlur.toInt()}", prefs.bgBlur, 0f..40f, { prefs.putBgImage(prefs.bgImage, blur = it) })
    SliderRow("Dim: ${(prefs.bgDim * 100).toInt()}%", prefs.bgDim, 0f..0.9f, { prefs.putBgImage(prefs.bgImage, dim = it) })
}

@Composable
private fun AnimatedControls(prefs: UiPrefs) {
    ChoiceRow(BgAnim.entries, prefs.bgAnim, { it.label }, { prefs.putBgAnim(anim = it) })
    Box(Modifier.padding(horizontal = 20.dp, vertical = 8.dp).fillMaxWidth().height(110.dp).clip(RoundedCornerShape(16.dp))) {
        AnimatedBackdrop(prefs.bgAnim, Color(prefs.bgAnimC1), Color(prefs.bgAnimC2), prefs.bgAnimSpeed, prefs.bgAnimDensity)
    }
    ColorRow("Shape colour", prefs.bgAnimC1) { prefs.putBgAnim(c1 = it) }
    ColorRow("Background colour", prefs.bgAnimC2) { prefs.putBgAnim(c2 = it) }
    SliderRow("Speed: ${"%.1f".format(prefs.bgAnimSpeed)}x", prefs.bgAnimSpeed, 0.2f..3f, { prefs.putBgAnim(speed = it) })
    SliderRow("Amount: ${(prefs.bgAnimDensity * 100).toInt()}%", prefs.bgAnimDensity, 0f..1f, { prefs.putBgAnim(density = it) })
}

/** A settings row with a colour dot; tapping it opens the picker. [argb] is an ARGB Int. */
@Composable
fun ColorRow(title: String, argb: Int, onPick: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    SettingsRow(title, onClick = { open = true }) {
        Box(Modifier.size(32.dp).clip(CircleShape).background(Color(argb)).border(1.dp, MaterialTheme.colorScheme.outline, CircleShape))
    }
    if (open) ColorPickerDialog(title, Color(argb), { onPick(it.toArgbInt()) }, { open = false })
}

/** Hue, saturation and brightness sliders with a live swatch. */
@Composable
fun ColorPickerDialog(title: String, initial: Color, onPick: (Color) -> Unit, onDismiss: () -> Unit) {
    val start = remember(initial) { toHsv(initial) }
    var h by remember { mutableFloatStateOf(start[0]) }
    var s by remember { mutableFloatStateOf(start[1]) }
    var v by remember { mutableFloatStateOf(start[2]) }
    val current = hsvToColor(h, s, v)
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = overlayRim(appShape(28.dp, CornerArea.Dialogs)), shape = appShape(28.dp, CornerArea.Dialogs), containerColor = overlayColor(),
        title = { Text(title) },
        text = {
            Column {
                Box(Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(12.dp)).background(current))
                Text("Hue", Modifier.padding(top = 8.dp), style = MaterialTheme.typography.labelLarge)
                Slider(h, { h = it }, valueRange = 0f..360f)
                Text("Saturation", style = MaterialTheme.typography.labelLarge)
                Slider(s, { s = it }, valueRange = 0f..1f)
                Text("Brightness", style = MaterialTheme.typography.labelLarge)
                Slider(v, { v = it }, valueRange = 0f..1f)
            }
        },
        confirmButton = { TextButton({ onPick(current); onDismiss() }) { Text("Use") } },
        dismissButton = { TextButton(onDismiss) { Text("Cancel") } },
    )
}

private fun Color.toArgbInt(): Int {
    fun ch(f: Float) = (f * 255f + 0.5f).toInt().coerceIn(0, 255)
    return (0xFF shl 24) or (ch(red) shl 16) or (ch(green) shl 8) or ch(blue)
}

/** Hue 0..360, saturation 0..1, value 0..1. */
internal fun toHsv(c: Color): FloatArray {
    val max = maxOf(c.red, c.green, c.blue); val min = minOf(c.red, c.green, c.blue)
    val d = max - min
    val hue = when {
        d == 0f -> 0f
        max == c.red -> ((c.green - c.blue) / d).mod(6f)
        max == c.green -> (c.blue - c.red) / d + 2f
        else -> (c.red - c.green) / d + 4f
    } * 60f
    return floatArrayOf(hue, if (max == 0f) 0f else d / max, max)
}

internal fun hsvToColor(h: Float, s: Float, v: Float): Color {
    val k = h / 60f
    fun f(n: Float): Float {
        val x = (n + k).mod(6f)
        return v - v * s * maxOf(0f, minOf(minOf(x, 4f - x), 1f))
    }
    return Color(f(5f), f(3f), f(1f))
}

@Preview
@Composable
private fun BackgroundSettingsPreview() {
    io.max.paperplay.ui.PreviewFrame { Column { BackgroundSettings(io.max.paperplay.ui.previewPrefs()) } }
}
