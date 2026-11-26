package io.max.paperplay.ui.app

import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.LocalCoverLoader
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

enum class BgMode(val label: String) {
    Plain("Plain"), Cover("Cover"), CoverBlur("Blurred cover"), Gradient("Gradient"), Wallpaper("Wallpaper"), Animated("Animated"),
}

enum class BgAnim(val label: String) { Stars("Stars"), Snow("Snow"), Aurora("Aurora"), Bubbles("Bubbles"), Waves("Waves") }

/**
 * The page background layer. It is the only thing drawn behind the content, so the glass layer backdrop can record it.
 * Every mode ends on the theme's background colour or a scrim of it, so text keeps its contrast in light and dark.
 */
@Composable
fun AppBackground(prefs: UiPrefs, coverUri: String?, base: Color, modifier: Modifier = Modifier, playing: Boolean = true) {
    val modernTokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    if (modernTokens.enabled) {
        ModernBackdropHost(prefs = prefs, coverUri = coverUri, base = base, playing = playing, modifier = modifier)
        return
    }
    val dark = base.luminance() < 0.5f
    Box(modifier.fillMaxSize().background(base)) {
        when (prefs.background) {
            BgMode.Plain -> {}
            BgMode.Cover -> CoverWash(coverUri, base, dark)
            BgMode.CoverBlur -> CoverBlurLayer(coverUri, base)
            BgMode.Gradient -> GradientLayer(prefs, coverUri, base, dark)
            BgMode.Wallpaper -> WallpaperLayer(prefs, base)
            BgMode.Animated -> AnimatedBackdrop(prefs.bgAnim, Color(prefs.bgAnimC1), Color(prefs.bgAnimC2), prefs.bgAnimSpeed, prefs.bgAnimDensity, playing = playing)
        }
    }
}

/**
 * Shared app-level Modern backdrop: renders a low-cost cover thumbnail (or tonal gradient when
 * no cover / Plain mode) with cover-palette radial blooms and a luminance-clamped dark/light/AMOLED
 * scrim. Captured once by `Shell`'s `pageBackdrop` so glass chrome blurs it without per-row cost.
 */
@Composable
internal fun ModernBackdropHost(
    prefs: UiPrefs,
    coverUri: String?,
    base: Color,
    playing: Boolean,
    modifier: Modifier = Modifier,
) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val loader = LocalCoverLoader.current
    val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
    val reducedTransparency = io.max.paperplay.ui.theme.LocalReducedTransparency.current
    val animateBlooms = playing && !reduceMotion && prefs.background == BgMode.Animated
    val clock = io.max.paperplay.ui.theme.LocalAmbientClock.current
    clock?.subscribe(active = animateBlooms)

    val palette = androidx.compose.runtime.remember(coverUri, scheme.primary, scheme.tertiary) {
        val raw = CoverSeeds.palette(coverUri)
        if (raw.isNotEmpty()) raw.map(::Color) else listOf(scheme.primary, scheme.tertiary)
    }
    val desat = androidx.compose.runtime.remember(tokens.dark) {
        ColorFilter.colorMatrix(ColorMatrix().apply { setToSaturation(if (tokens.dark) 0.78f else 0.60f) })
    }
    val decodePx = modernBackdropDecodePx(prefs.modernPlayerBlur)
    val floorColor = when {
        tokens.dark && tokens.amoled -> Color.Black
        tokens.dark -> lerp(scheme.surfaceContainerLowest, Color.Black, 0.72f)
        else -> lerp(scheme.surface, Color.White, 0.45f)
    }

    Box(modifier.fillMaxSize().background(floorColor)) {
        when (prefs.background) {
            BgMode.Plain -> {
                if (!tokens.amoled || !tokens.dark) {
                    val top = lerp(scheme.primaryContainer, floorColor, if (tokens.dark) 0.52f else 0.65f)
                    Box(Modifier.fillMaxSize().drawBehind {
                        drawRect(Brush.verticalGradient(0f to top, 0.55f to floorColor, 1f to floorColor))
                    })
                }
            }
            BgMode.Gradient -> GradientLayer(prefs, coverUri, base, tokens.dark)
            BgMode.Wallpaper -> WallpaperLayer(prefs, base)
            BgMode.Cover, BgMode.CoverBlur, BgMode.Animated -> {
                if (!reducedTransparency && !(tokens.dark && tokens.amoled && coverUri == null)) {
                    Crossfade(
                        targetState = coverUri,
                        modifier = Modifier.fillMaxSize(),
                        animationSpec = io.max.paperplay.ui.theme.motionEffectTween(io.max.paperplay.ui.theme.Motion.Effects.WashMs),
                        label = "modernAppBackdrop",
                    ) { uri ->
                        val painter = if (uri != null) loader?.painter(uri, decodePx) else null
                        if (painter != null) {
                            Image(
                                painter = painter,
                                contentDescription = null,
                                modifier = Modifier.fillMaxSize()
                                    .graphicsLayer { scaleX = 1.25f; scaleY = 1.25f }
                                    .then(
                                        if (prefs.modernPlayerBlur > 0.5f && decodePx > 64 && io.max.paperplay.ui.glassEffectsSupported()) {
                                            Modifier.blur((prefs.modernPlayerBlur * 0.5f).dp)
                                        } else Modifier
                                    ),
                                contentScale = ContentScale.Crop,
                                colorFilter = desat,
                            )
                        } else {
                            val top = lerp(scheme.primaryContainer, floorColor, if (tokens.dark) 0.45f else 0.55f)
                            val mid = lerp(scheme.secondaryContainer, floorColor, if (tokens.dark) 0.65f else 0.72f)
                            Box(Modifier.fillMaxSize().drawBehind {
                                drawRect(Brush.verticalGradient(0f to top, 0.55f to mid, 1f to floorColor))
                            })
                        }
                    }
                }
            }
        }

        // Soft cover-palette radial blooms (static unless BgMode.Animated && playing && !reduceMotion).
        if (!reducedTransparency && !(tokens.dark && tokens.amoled && prefs.background == BgMode.Plain)) {
            val c1 = palette[0]
            val c2 = palette.getOrElse(1) { scheme.tertiary }
            val bloomStrength = when {
                tokens.dark && tokens.amoled -> 0.14f
                tokens.dark -> 0.22f
                else -> 0.16f
            }
            Box(Modifier.fillMaxSize().drawBehind {
                val t = if (animateBlooms && clock != null) clock.seconds else 0.5f
                val w = size.width
                val h = size.height
                val x1 = w * (0.26f + 0.12f * sin(t * 0.22f))
                val y1 = h * (0.22f + 0.08f * cos(t * 0.17f))
                val r1 = maxOf(w, h) * 0.55f
                drawCircle(
                    brush = Brush.radialGradient(listOf(c1.copy(alpha = bloomStrength), Color.Transparent), Offset(x1, y1), r1),
                    radius = r1,
                    center = Offset(x1, y1),
                )
                val x2 = w * (0.76f + 0.10f * cos(t * 0.19f))
                val y2 = h * (0.64f + 0.08f * sin(t * 0.15f))
                val r2 = maxOf(w, h) * 0.48f
                drawCircle(
                    brush = Brush.radialGradient(listOf(c2.copy(alpha = bloomStrength * 0.85f), Color.Transparent), Offset(x2, y2), r2),
                    radius = r2,
                    center = Offset(x2, y2),
                )
            })
        }

        // Luminance-clamped scrim so glass chrome and text maintain AA contrast in Dark, Light, and True Black.
        if (prefs.background != BgMode.Plain || !tokens.dark) {
            Box(Modifier.fillMaxSize().drawBehind {
                drawRect(
                    Brush.verticalGradient(
                        0.0f to tokens.scrimTop,
                        0.45f to tokens.scrimMid,
                        1.0f to tokens.scrimBottom,
                    ),
                )
            })
        }
    }
}

/** The colour at the top of the page for the chosen mode, used to tint the window and status areas. */
fun backgroundTopColor(prefs: UiPrefs, coverTint: Color, base: Color): Color = when (prefs.background) {
    BgMode.Gradient -> Color(prefs.bgGradC1)
    BgMode.Animated -> Color(prefs.bgAnimC2)
    else -> coverTint.copy(alpha = 0.85f).compositeOver(base)
}

@Composable
private fun CoverWash(coverUri: String?, base: Color, dark: Boolean) {
    val tint = coverScheme(coverUri, dark)?.primaryContainer ?: MaterialTheme.colorScheme.primaryContainer
    val g0 = animateColorAsState(tint.copy(alpha = 0.85f).compositeOver(base), io.max.paperplay.ui.theme.motionWashSpec())
    val g1 = animateColorAsState(tint.copy(alpha = 0.32f).compositeOver(base), io.max.paperplay.ui.theme.motionWashSpec())
    // The animated colours are read while drawing, so the 700 ms wash does not recompose.
    Box(Modifier.fillMaxSize().drawBehind { drawRect(Brush.verticalGradient(0f to g0.value, 0.45f to g1.value, 1f to base)) })
}

@Composable
private fun CoverBlurLayer(coverUri: String?, base: Color) {
    val loader = LocalCoverLoader.current
    // A tiny bitmap stretched to the screen is already soft; the GPU blur filter drew wrong colours on some desktop drivers, so there is none.
    Crossfade(coverUri, Modifier.fillMaxSize(), animationSpec = io.max.paperplay.ui.theme.motionEffectTween(io.max.paperplay.ui.theme.Motion.Effects.WashMs), label = "coverBlur") { uri ->
        val painter = if (uri != null) loader?.painter(uri, 24) else null
        if (painter != null) {
            Image(
                painter, null, Modifier.fillMaxSize().graphicsLayer { scaleX = 1.25f; scaleY = 1.25f },
                contentScale = ContentScale.Crop,
            )
        }
    }
    Box(Modifier.fillMaxSize().background(base.copy(alpha = 0.55f)))
}

@Composable
private fun GradientLayer(prefs: UiPrefs, coverUri: String?, base: Color, dark: Boolean) {
    val fromCover = if (prefs.bgGradCover) coverScheme(coverUri, dark)?.primaryContainer else null
    val c1 = animateColorAsState(fromCover ?: Color(prefs.bgGradC1), io.max.paperplay.ui.theme.motionWashSpec())
    val c2 = Color(prefs.bgGradC2)
    val c3 = prefs.bgGradC3.takeIf { it != 0 }?.let { Color(it) }
    val angle = prefs.bgGradAngle
    Box(Modifier.fillMaxSize().drawBehind { drawRect(angledBrush(listOf(c1.value, c2) + listOfNotNull(c3), angle, size.width, size.height)) })
}

/** A linear gradient along [angle] degrees (0 left to right, 90 top to bottom) that spans the whole box. */
internal fun angledBrush(colors: List<Color>, angle: Float, w: Float, h: Float): Brush {
    val a = angle * (PI / 180.0).toFloat()
    val dx = cos(a); val dy = sin(a)
    val r = (abs(w * dx) + abs(h * dy)) / 2f
    val cx = w / 2f; val cy = h / 2f
    return Brush.linearGradient(colors, Offset(cx - dx * r, cy - dy * r), Offset(cx + dx * r, cy + dy * r))
}

@Composable
private fun WallpaperLayer(prefs: UiPrefs, base: Color) {
    val path = prefs.bgImage
    val painter = if (path != null) LocalCoverLoader.current?.painter(path, 1920) else null
    if (painter != null) {
        val blur = prefs.bgBlur
        Image(
            painter, null,
            Modifier.fillMaxSize().then(if (blur > 0.5f) Modifier.graphicsLayer { scaleX = 1.1f; scaleY = 1.1f }.blur(blur.dp) else Modifier),
            contentScale = ContentScale.Crop,
        )
    }
    Box(Modifier.fillMaxSize().background(base.copy(alpha = prefs.bgDim.coerceIn(0f, 0.95f))))
}

@Preview
@Composable
private fun AppBackgroundPreview() {
    val prefs = io.max.paperplay.ui.previewPrefs()
    io.max.paperplay.ui.PreviewFrame { AppBackground(prefs, null, MaterialTheme.colorScheme.background) }
}
