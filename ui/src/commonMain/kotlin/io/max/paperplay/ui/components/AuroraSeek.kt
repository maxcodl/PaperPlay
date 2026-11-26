package io.max.paperplay.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.max.paperplay.ui.PreviewFrame
import io.max.paperplay.ui.rememberAppForeground
import io.max.paperplay.ui.theme.LocalReduceMotion
import kotlinx.coroutines.delay
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin

private data class AuroraRibbonSpec(
    val speedScale: Float,
    val centerMin: Float,
    val centerMax: Float,
    val centerOffset: Float,
    val secSpeedScale: Float,
    val secOffset: Float,
    val breatheSpeed: Float,
    val breatheOffset: Float,
    val bellWidthFrac: Float,
    val minBellWidthDp: Float,
    val heightScale: Float,
    val topAlpha: Float,
    val baseAlpha: Float,
    val isFrontWhite: Boolean = false,
)

private val auroraRibbons = listOf(
    // 0: Tall broad wave sweeping smoothly across the left-to-right span.
    AuroraRibbonSpec(
        speedScale = 0.72f,
        centerMin = 0.16f,
        centerMax = 0.82f,
        centerOffset = 0.05f,
        secSpeedScale = -0.58f,
        secOffset = 0.62f,
        breatheSpeed = 0.41f,
        breatheOffset = 0.00f,
        bellWidthFrac = 0.22f,
        minBellWidthDp = 28f,
        heightScale = 1.00f,
        topAlpha = 0.28f,
        baseAlpha = 0.22f,
    ),
    // 1: Counter-drifting medium wave roaming independently across the bar.
    AuroraRibbonSpec(
        speedScale = -0.88f,
        centerMin = 0.14f,
        centerMax = 0.84f,
        centerOffset = 0.38f,
        secSpeedScale = 0.76f,
        secOffset = 0.15f,
        breatheSpeed = 0.53f,
        breatheOffset = 0.29f,
        bellWidthFrac = 0.18f,
        minBellWidthDp = 24f,
        heightScale = 0.82f,
        topAlpha = 0.34f,
        baseAlpha = 0.28f,
    ),
    // 2: Flexible narrower swell weaving freely from near 0:00 to near the thumb.
    AuroraRibbonSpec(
        speedScale = 1.12f,
        centerMin = 0.18f,
        centerMax = 0.86f,
        centerOffset = 0.71f,
        secSpeedScale = -0.94f,
        secOffset = 0.44f,
        breatheSpeed = 0.61f,
        breatheOffset = 0.58f,
        bellWidthFrac = 0.14f,
        minBellWidthDp = 22f,
        heightScale = 0.68f,
        topAlpha = 0.40f,
        baseAlpha = 0.36f,
    ),
    // 3: Front airy white silk ribbon with two gentle offset swells across the full bar.
    AuroraRibbonSpec(
        speedScale = -0.64f,
        centerMin = 0.15f,
        centerMax = 0.85f,
        centerOffset = 0.22f,
        secSpeedScale = 1.05f,
        secOffset = 0.81f,
        breatheSpeed = 0.47f,
        breatheOffset = 0.83f,
        bellWidthFrac = 0.16f,
        minBellWidthDp = 22f,
        heightScale = 0.50f,
        topAlpha = 0.46f,
        baseAlpha = 0.54f,
        isFrontWhite = true,
    ),
)

/**
 * Analytic C∞ window (`1 - cos^4(pi * u)`) with zero value and zero slope at both ends (`u = 0` and `u = 1`).
 * Unlike a piecewise smoothstep plateau, its curvature never jumps when a wave crest drifts near either edge,
 * while still giving waves full room across the bar.
 */
internal fun auroraWaveEnvelope(u: Float): Float {
    val clamped = u.coerceIn(0f, 1f)
    val s = sin(clamped * PI.toFloat())
    val s2 = s * s
    return s2 * (2f - s2)
}

internal class AuroraSeekInteractionState {
    var dragging by mutableStateOf<Float?>(null)
        private set
    var longPressText by mutableStateOf<String?>(null)
        private set
    var longPressToken by mutableIntStateOf(0)
        private set
    private var nextToken = 0

    fun onLongPress(fraction: Float, label: String?) {
        dragging = fraction
        longPressText = label
        longPressToken = ++nextToken
    }

    fun onDragStart(fraction: Float) {
        longPressToken = 0
        longPressText = null
        dragging = fraction
    }

    fun onDrag(fraction: Float) {
        dragging = fraction
    }

    fun onDragEnd(): Float? {
        val target = dragging
        dragging = null
        return target
    }

    fun onDragCancel() {
        dragging = null
    }

    suspend fun runLongPressCleanup(timeoutMs: Long = 1500L) {
        val token = longPressToken
        if (token == 0) return
        delay(timeoutMs)
        if (longPressToken == token) {
            longPressText = null
            dragging = null
            longPressToken = 0
        }
    }
}

/**
 * One UI 9.0-inspired luminous multi-ribbon seek bar rendered purely with Compose [Canvas].
 * Uses 4 overlapping SiriWave9-style ribbons composited with [BlendMode.Screen] inside an
 * offscreen layer, a crisp bright core spine, a flat translucent unplayed track, and a glowing
 * circular thumb with a radial halo. Matches [WavySeek]'s base horizontal drift tempo (0.5 cycles/s
 * on a 40 dp wavelength) and touch/scrubbing precision.
 */
@Composable
fun AuroraSeek(
    progress: () -> Float,
    buffered: () -> Float,
    playing: Boolean,
    onSeek: (Float) -> Unit,
    colors: List<Color>,
    modifier: Modifier = Modifier,
    label: String? = null,
    longPressLabel: ((Float) -> String)? = null,
    compact: Boolean = false,
    animateWave: Boolean = true,
    trackColor: Color? = null,
    bufferedColor: Color? = null,
) {
    val interaction = remember { AuroraSeekInteractionState() }
    LaunchedEffect(interaction.longPressToken) {
        interaction.runLongPressCleanup()
    }
    val dragging = interaction.dragging
    val longPressText = interaction.longPressText

    val currentProgress by rememberUpdatedState(progress)
    val currentBuffered by rememberUpdatedState(buffered)
    val currentOnSeek by rememberUpdatedState(onSeek)
    val currentLabel by rememberUpdatedState(label)
    val currentLongPressLabel by rememberUpdatedState(longPressLabel)

    val foreground = rememberAppForeground()
    val reduceMotion = LocalReduceMotion.current
    val waving = playing && animateWave && dragging == null && foreground && !reduceMotion

    val waveAmp by animateFloatAsState(
        targetValue = if (waving) 1f else 0f,
        animationSpec = io.max.paperplay.ui.theme.motionEffectTween(io.max.paperplay.ui.theme.Motion.Spatial.StaggerEnterMs),
        label = "auroraAmp",
    )
    val thumbScale by animateFloatAsState(
        targetValue = if (dragging != null) 1.18f else 1f,
        animationSpec = io.max.paperplay.ui.theme.motionEffectTween(io.max.paperplay.ui.theme.Motion.Effects.FadeFastMs),
        label = "auroraThumbScale",
    )

    // Smoothly cross-fade the 4 extracted shades whenever the track changes.
    val scheme = MaterialTheme.colorScheme
    val target0 = colors.getOrElse(0) { scheme.primary }
    val target1 = colors.getOrElse(1) { scheme.tertiary }
    val target2 = colors.getOrElse(2) { scheme.secondary }
    val target3 = colors.getOrElse(3) { Color.White }
    val colorAnimSpec = io.max.paperplay.ui.theme.motionWashSpec()
    val c0 by animateColorAsState(target0, colorAnimSpec, label = "auroraC0")
    val c1 by animateColorAsState(target1, colorAnimSpec, label = "auroraC1")
    val c2 by animateColorAsState(target2, colorAnimSpec, label = "auroraC2")
    val c3 by animateColorAsState(target3, colorAnimSpec, label = "auroraC3")

    // Exact base phase velocity parity with WavySeek: 0.5 cycles/s on a 40 dp wavelength (20 dp/s).
    var phase by remember { mutableFloatStateOf(0f) }
    val running = foreground && !reduceMotion && (waving || waveAmp > 0.001f)
    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        var last = 0L
        while (true) {
            withFrameNanos { t ->
                // About 30 updates a second: the wave moves half a cycle a second, so this looks the same as 120 Hz, and each
                // skipped update is a frame the seek bar is not drawn again (it was 10% of the main thread with the player open).
                if (last != 0L && t - last < 33_000_000L) return@withFrameNanos
                if (last != 0L) {
                    val dtSec = ((t - last) / 1_000_000_000f).coerceIn(0f, 0.1f)
                    phase = (phase + dtSec * 0.5f) % 1000f
                }
                last = t
            }
        }
    }

    // Pre-allocate reusable Paths outside the draw block so 60/120 Hz frames allocate nothing.
    val ribbonPaths = remember { List(auroraRibbons.size) { Path() } }

    val totalHeight: Dp = if (compact) 40.dp else 52.dp
    val lineCenterY: Dp = if (compact) 24.dp else 30.dp
    val maxWaveHeightDp: Dp = if (compact) 14.dp else 20.dp
    val thumbDiameterDp: Dp = if (compact) 11.dp else 13.dp
    val isLight = scheme.surface.luminance() >= 0.5f
    val resolvedTrackColor = trackColor ?: if (isLight) scheme.onSurface.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.30f)
    val resolvedBufferedColor = bufferedColor ?: if (isLight) scheme.onSurface.copy(alpha = 0.36f) else Color.White.copy(alpha = 0.44f)

    BoxWithConstraints(modifier.fillMaxWidth().height(totalHeight)) {
        Box(
            Modifier
                .fillMaxSize()
                .semantics {
                    contentDescription = "Seek"
                    if (label != null) stateDescription = label
                    val p = (dragging ?: currentProgress()).takeIf { it.isFinite() }?.coerceIn(0f, 1f) ?: 0f
                    progressBarRangeInfo = ProgressBarRangeInfo(p, 0f..1f)
                }
                .pointerInput(lineCenterY) {
                    // Match WavySeek's exact vertical touch band so brushing near timestamps never seeks.
                    val reach = 14.dp.toPx()
                    val lineY = lineCenterY.toPx()
                    detectTapGestures(
                        onTap = {
                            if (abs(it.y - lineY) <= reach) {
                                val fraction = (it.x / size.width.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)
                                currentOnSeek(fraction)
                            }
                        },
                        onLongPress = {
                            if (abs(it.y - lineY) > reach) return@detectTapGestures
                            val fraction = (it.x / size.width.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)
                            interaction.onLongPress(fraction, currentLongPressLabel?.invoke(fraction) ?: currentLabel)
                            currentOnSeek(fraction)
                        },
                    )
                }
                .pointerInput(lineCenterY) {
                    val reach = 14.dp.toPx()
                    val lineY = lineCenterY.toPx()
                    var live = false
                    detectHorizontalDragGestures(
                        onDragStart = {
                            live = abs(it.y - lineY) <= reach
                            if (live) {
                                interaction.onDragStart((it.x / size.width.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f))
                            }
                        },
                        onDragEnd = {
                            val target = interaction.onDragEnd()
                            if (live) target?.let(currentOnSeek)
                            live = false
                        },
                        onDragCancel = {
                            interaction.onDragCancel()
                            live = false
                        },
                    ) { change, _ ->
                        if (live) {
                            change.consume()
                            interaction.onDrag((change.position.x / size.width.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f))
                        }
                    }
                },
        ) {
            // Draw without Offscreen clipping so the soft radial thumb bloom and wave aura bleed naturally into the player background.
            Canvas(Modifier.fillMaxSize()) {
                val w = size.width
                if (w <= 0f) return@Canvas
                val baseY = lineCenterY.toPx()
                val thumbRadius = (thumbDiameterDp.toPx() / 2f) * thumbScale
                val thumbStrokePx = (if (compact) 1.8.dp else 2.dp).toPx()
                // Keep progressed spine and unplayed track the exact same thickness.
                val barStrokePx = 3.dp.toPx()
                val maxWavePx = maxWaveHeightDp.toPx()
                val isScrubbing = dragging != null

                val rawShown = dragging ?: currentProgress()
                val shown = if (rawShown.isFinite()) rawShown.coerceIn(0f, 1f) else 0f
                val rawBuf = currentBuffered()
                val buf = if (rawBuf.isFinite()) rawBuf.coerceIn(0f, 1f) else 0f

                val pad = thumbRadius + thumbStrokePx * 0.5f
                val usableW = (w - pad * 2f).coerceAtLeast(1f)
                val thumbX = pad + shown * usableW

                // 0. Unclipped atmospheric thumb glow behind everything (whitish with a soft accent whisper).
                val outerHaloRadius = (if (compact) 30.dp else 44.dp).toPx() * thumbScale
                val haloBoost = if (isScrubbing) 1.15f else 1f
                val lightAccent = if (isLight) scheme.primary else androidx.compose.ui.graphics.lerp(Color.White, c0, 0.34f)
                val whisperAccent = if (isLight) androidx.compose.ui.graphics.lerp(scheme.primary, c0, 0.40f) else androidx.compose.ui.graphics.lerp(Color.White, c0, 0.20f)
                val haloCore = if (isLight) lightAccent.copy(alpha = (0.28f * haloBoost).coerceAtMost(0.42f)) else Color.White.copy(alpha = (0.48f * haloBoost).coerceAtMost(0.68f))
                drawCircle(
                    brush = Brush.radialGradient(
                        0.00f to haloCore,
                        0.28f to lightAccent.copy(alpha = (0.26f * haloBoost).coerceAtMost(0.42f)),
                        0.58f to lightAccent.copy(alpha = (0.09f * haloBoost).coerceAtMost(0.16f)),
                        1.00f to Color.Transparent,
                        center = Offset(thumbX, baseY),
                        radius = outerHaloRadius,
                    ),
                    radius = outerHaloRadius,
                    center = Offset(thumbX, baseY),
                )

                // 1. Unplayed track to the right of the thumb (same 3 dp thickness as played bar).
                val trackStart = thumbX + thumbRadius + thumbStrokePx * 0.5f + 2.dp.toPx()
                val trackEnd = w - barStrokePx / 2f
                if (trackStart < trackEnd) {
                    drawLine(
                        color = resolvedTrackColor,
                        start = Offset(trackStart, baseY),
                        end = Offset(trackEnd, baseY),
                        strokeWidth = barStrokePx,
                        cap = StrokeCap.Round,
                    )
                    val bufX = (pad + buf * usableW).coerceAtMost(trackEnd)
                    if (buf > shown && bufX > trackStart) {
                        drawLine(
                            color = resolvedBufferedColor,
                            start = Offset(trackStart, baseY),
                            end = Offset(bufX, baseY),
                            strokeWidth = barStrokePx,
                            cap = StrokeCap.Round,
                        )
                    }
                }

                // 2. Played One UI 6-inspired whitish silk waves with a faint cover-accent tint.
                val startX = barStrokePx / 2f
                val waveEndX = (thumbX - thumbRadius * 0.25f).coerceAtLeast(startX)
                val playedW = (waveEndX - startX).coerceAtLeast(0f)
                val ribbonTints = floatArrayOf(0.28f, 0.18f, 0.10f, 0.0f)
                val amp = waveAmp

                if (playedW > 2f && amp > 0.002f) {
                    val lengthScale = (playedW / 96.dp.toPx()).coerceIn(0f, 1f)
                    val stepPx = 2.dp.toPx().coerceAtLeast(1.5f)
                    val twoPi = (2.0 * PI).toFloat()

                    val auraCenterX = startX + playedW * 0.52f
                    val auraRadius = (playedW * 0.50f).coerceAtLeast(24.dp.toPx())
                    drawCircle(
                        brush = Brush.radialGradient(
                            0.0f to lightAccent.copy(alpha = 0.12f * amp * lengthScale),
                            0.6f to whisperAccent.copy(alpha = 0.04f * amp * lengthScale),
                            1.0f to Color.Transparent,
                            center = Offset(auraCenterX, baseY - maxWavePx * 0.35f),
                            radius = auraRadius,
                        ),
                        radius = auraRadius,
                        center = Offset(auraCenterX, baseY - maxWavePx * 0.35f),
                    )

                    for (i in auroraRibbons.indices) {
                        val spec = auroraRibbons[i]
                        val path = ribbonPaths[i]
                        path.reset()
                        path.moveTo(startX, baseY)

                        // Two independent travelling crests per ribbon so waves spread, separate, and vary across the whole bar.
                        val c1T = 0.5f + 0.5f * sin((phase * spec.speedScale * 0.28f + spec.centerOffset) * twoPi)
                        val c2T = 0.5f + 0.5f * sin((phase * spec.secSpeedScale * 0.24f + spec.secOffset) * twoPi)
                        val center1X = startX + playedW * (spec.centerMin + (spec.centerMax - spec.centerMin) * c1T)
                        val center2X = startX + playedW * (spec.centerMin + (spec.centerMax - spec.centerMin) * c2T)
                        // Keep sigma proportional to playedW on short bars so crests stay organic instead of being crushed at the ends.
                        val minSigma = minOf(spec.minBellWidthDp.dp.toPx(), playedW * 0.28f)
                        val sigma1 = maxOf(playedW * spec.bellWidthFrac, minSigma).coerceAtLeast(1f)
                        val sigma2 = (sigma1 * 0.78f).coerceAtLeast(1f)
                        val breathe1 = 0.62f + 0.38f * sin((phase * spec.breatheSpeed + spec.breatheOffset) * twoPi)
                        val breathe2 = 0.48f + 0.34f * sin((phase * spec.breatheSpeed * 0.83f + spec.secOffset) * twoPi)
                        val ribbonMaxH = maxWavePx * spec.heightScale * amp * lengthScale

                        val steps = (playedW / stepPx).toInt().coerceAtLeast(16)
                        for (s in 1 until steps) {
                            val u = s.toFloat() / steps
                            val x = startX + u * playedW
                            val edgeEnv = auroraWaveEnvelope(u)
                            val d1 = (x - center1X) / sigma1
                            val d2 = (x - center2X) / sigma2
                            val h1 = (breathe1 * exp(-d1 * d1 * 1.45f)).coerceIn(0f, 1f)
                            val h2 = (breathe2 * 0.72f * exp(-d2 * d2 * 1.65f)).coerceIn(0f, 1f)
                            // Smooth soft union (1 - (1 - h1)(1 - h2)) stays strictly in 0..1 with zero flat-top clipping when crests overlap.
                            val combined = 1f - (1f - h1) * (1f - h2)
                            val y = baseY - ribbonMaxH * edgeEnv * combined
                            path.lineTo(x, y)
                        }
                        path.lineTo(waveEndX, baseY)
                        path.close()

                        val tint = if (isLight) {
                            androidx.compose.ui.graphics.lerp(scheme.primary, c0, ribbonTints[i])
                        } else {
                            androidx.compose.ui.graphics.lerp(Color.White, c0, ribbonTints[i])
                        }
                        val fillTone = tint.copy(alpha = if (spec.isFrontWhite) spec.baseAlpha else spec.topAlpha)
                        drawPath(
                            path = path,
                            brush = Brush.horizontalGradient(
                                0.00f to Color.Transparent,
                                0.12f to fillTone,
                                0.88f to fillTone,
                                1.00f to Color.Transparent,
                                startX = startX,
                                endX = waveEndX,
                            ),
                        )
                    }
                }

                // 3. Clean whitish progressed bar with a light accent tint, exact same 3 dp thickness as the unplayed track.
                if (playedW > 0.5f) {
                    val spineEndX = (thumbX - thumbRadius * 0.1f).coerceAtLeast(startX)
                    drawLine(
                        brush = Brush.horizontalGradient(
                            0.00f to whisperAccent.copy(alpha = if (isLight) 0.55f else 0.25f),
                            0.14f to whisperAccent.copy(alpha = if (isLight) 0.96f else 0.90f),
                            1.00f to lightAccent,
                            startX = startX,
                            endX = spineEndX,
                        ),
                        start = Offset(startX, baseY),
                        end = Offset(spineEndX, baseY),
                        strokeWidth = barStrokePx,
                        cap = StrokeCap.Round,
                    )
                }

                // 4. Sleek circular thumb: light pastel accent fill + crisp white ring.
                drawCircle(
                    color = lightAccent,
                    radius = thumbRadius,
                    center = Offset(thumbX, baseY),
                )
                drawCircle(
                    color = Color.White,
                    radius = thumbRadius,
                    center = Offset(thumbX, baseY),
                    style = androidx.compose.ui.graphics.drawscope.Stroke(width = thumbStrokePx),
                )
            }
        }
        longPressText?.let { text ->
            Text(
                text = text,
                color = c0,
                style = TextStyle(fontSize = 12.sp),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset(
                        x = (maxWidth * (dragging ?: 0f) - 16.dp).coerceIn(0.dp, (maxWidth - 32.dp).coerceAtLeast(0.dp)),
                        y = (lineCenterY + 12.dp).coerceAtMost(totalHeight - 16.dp),
                    ),
            )
        }
    }
}

private val previewAuroraColors = listOf(
    Color(0xFFFF3B3B),
    Color(0xFFE040FB),
    Color(0xFF536DFE),
    Color(0xFFFFB2D9),
)

@Preview
@Composable
private fun AuroraWavePlayingPreview() {
    PreviewFrame(dark = true) {
        AuroraSeek(
            progress = { 0.68f },
            buffered = { 0.85f },
            playing = true,
            onSeek = {},
            colors = previewAuroraColors,
            label = "2:27",
        )
    }
}

@Preview
@Composable
private fun AuroraWavePausedPreview() {
    PreviewFrame(dark = true) {
        AuroraSeek(
            progress = { 0.45f },
            buffered = { 0.80f },
            playing = false,
            onSeek = {},
            colors = previewAuroraColors,
            label = "1:35",
        )
    }
}
