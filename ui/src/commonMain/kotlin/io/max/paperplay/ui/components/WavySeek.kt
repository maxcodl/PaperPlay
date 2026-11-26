package io.max.paperplay.ui.components

import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LinearWavyProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.WavyProgressIndicatorDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.max.paperplay.ui.PreviewFrame
import io.max.paperplay.ui.rememberAppForeground
import io.max.paperplay.ui.theme.LocalReduceMotion
import kotlinx.coroutines.delay
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Seek bar powered by Material 3's [LinearWavyProgressIndicator]: the played part is a moving wave
 * while audio plays and flattens when paused, scrubbing, in the background, or when motion is reduced.
 * [progress] and [buffered] return 0 to 1 and are read while drawing; [onSeek] fires when the finger lifts.
 */
@Composable
fun WavySeek(
    progress: () -> Float,
    buffered: () -> Float,
    playing: Boolean,
    onSeek: (Float) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    longPressLabel: ((Float) -> String)? = null,
    animateWave: Boolean = true,
    activeColor: Color? = null,
    trackColor: Color? = null,
    bufferedColor: Color? = null,
) {
    var dragging by remember { mutableStateOf<Float?>(null) }
    var longPressText by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(longPressText) {
        if (longPressText != null) {
            delay(1500)
            longPressText = null
            dragging = null
        }
    }

    val currentProgress by rememberUpdatedState(progress)
    val currentBuffered by rememberUpdatedState(buffered)
    val currentOnSeek by rememberUpdatedState(onSeek)
    val currentLabel by rememberUpdatedState(label)
    val currentLongPressLabel by rememberUpdatedState(longPressLabel)

    val foreground = rememberAppForeground()
    val reduceMotion = LocalReduceMotion.current
    val waving = playing && animateWave && dragging == null && foreground && !reduceMotion

    // Keep wave offset moving briefly while Material 3's 500 ms flatten animation finishes so pause does not snap phase.
    var waveMoving by remember { mutableStateOf(waving) }
    LaunchedEffect(waving, foreground, reduceMotion) {
        if (waving) {
            waveMoving = true
        } else if (!foreground || reduceMotion) {
            waveMoving = false
        } else {
            delay(550)
            waveMoving = false
        }
    }

    val shownProgress: () -> Float = remember {
        {
            val raw = dragging ?: currentProgress()
            if (raw.isFinite()) raw.coerceIn(0f, 1f) else Float.NaN
        }
    }
    val amplitude: (Float) -> Float = remember(waving) {
        { p ->
            if (!waving) 0f
            else if (p.isNaN()) 1f
            else if (p <= 0f || p >= 1f) 0f
            else 1f
        }
    }

    val active = activeColor ?: WavyProgressIndicatorDefaults.indicatorColor
    val resolvedTrackColor = trackColor ?: WavyProgressIndicatorDefaults.trackColor
    val indicatorStroke = WavyProgressIndicatorDefaults.linearIndicatorStroke
    val trackStroke = WavyProgressIndicatorDefaults.linearTrackStroke
    val gapSize = WavyProgressIndicatorDefaults.LinearIndicatorTrackGapSize
    val stopSize = WavyProgressIndicatorDefaults.LinearTrackStopIndicatorSize
    val wavelength = WavyProgressIndicatorDefaults.LinearDeterminateWavelength
    val barHeight = WavyProgressIndicatorDefaults.LinearContainerHeight
    val resolvedBufferedColor = bufferedColor ?: MaterialTheme.colorScheme.onSurface.copy(alpha = 0.24f)

    BoxWithConstraints(modifier.fillMaxWidth().height(52.dp)) {
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    // Only touches on the line itself count, so brushing past the bar or the times never seeks.
                    val reach = 14.dp.toPx()
                    val lineY = 20.dp.toPx()
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
                            dragging = fraction
                            longPressText = currentLongPressLabel?.invoke(fraction) ?: currentLabel
                            currentOnSeek(fraction)
                        },
                    )
                }
                .pointerInput(Unit) {
                    val reach = 14.dp.toPx()
                    val lineY = 20.dp.toPx()
                    var live = false
                    detectHorizontalDragGestures(
                        onDragStart = {
                            live = abs(it.y - lineY) <= reach
                            if (live) {
                                longPressText = null
                                dragging = (it.x / size.width.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)
                            }
                        },
                        onDragEnd = {
                            if (live) dragging?.let(currentOnSeek)
                            dragging = null
                            live = false
                        },
                        onDragCancel = {
                            dragging = null
                            live = false
                        },
                    ) { change, _ ->
                        if (live) {
                            change.consume()
                            dragging = (change.position.x / size.width.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)
                        }
                    }
                },
        ) {
            LinearWavyProgressIndicator(
                progress = shownProgress,
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(top = 20.dp - barHeight / 2)
                    .fillMaxWidth()
                    .height(barHeight)
                    .semantics {
                        contentDescription = "Seek"
                        if (label != null) stateDescription = label
                    }
                    .drawWithContent {
                        drawContent()
                        val shown = shownProgress()
                        val buf = currentBuffered().coerceIn(0f, 1f)
                        if (!shown.isFinite() || !buf.isFinite() || buf <= shown || size.width <= 0f) {
                            return@drawWithContent
                        }
                        val capWidth = trackStroke.width / 2f
                        val barHead = shown * size.width
                        val adjustedBarHead = barHead.coerceIn(capWidth, (size.width - capWidth).coerceAtLeast(capWidth))
                        val activeVisible = barHead >= capWidth
                        val adjustedGap = if (barHead < capWidth) 0f else min(barHead - capWidth, gapSize.toPx())
                        val adaptiveSpacing = if (activeVisible) adjustedGap + capWidth * 2f else adjustedGap
                        val trackStart = max(capWidth, adjustedBarHead + adaptiveSpacing)
                        val stopPx = min(trackStroke.width, stopSize.toPx())
                        val trackEnd = if (stopPx > 0f) size.width - stopPx - capWidth else size.width - capWidth
                        val bufferedEnd = min(buf * size.width - capWidth, trackEnd)
                        if (bufferedEnd > trackStart) {
                            val midY = size.height / 2f
                            rotate(if (layoutDirection == LayoutDirection.Ltr) 0f else 180f) {
                                drawLine(
                                    color = resolvedBufferedColor,
                                    start = Offset(trackStart, midY),
                                    end = Offset(bufferedEnd, midY),
                                    strokeWidth = trackStroke.width,
                                    cap = trackStroke.cap,
                                )
                            }
                        }
                    },
                color = active,
                trackColor = resolvedTrackColor,
                stroke = indicatorStroke,
                trackStroke = trackStroke,
                gapSize = gapSize,
                stopSize = stopSize,
                amplitude = amplitude,
                wavelength = wavelength,
                waveSpeed = if (waveMoving) wavelength / 2 else 0.dp,
            )
        }
        longPressText?.let { text ->
            Text(
                text = text,
                color = active,
                style = TextStyle(fontSize = 12.sp),
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .offset(x = (maxWidth * (dragging ?: 0f) - 16.dp).coerceIn(0.dp, maxWidth - 32.dp), y = 32.dp),
            )
        }
    }
}

@Preview
@Composable
private fun WavySeekPlayingPreview() {
    PreviewFrame(dark = true) {
        WavySeek(progress = { 0.4f }, buffered = { 0.7f }, playing = true, onSeek = {}, label = "1:45")
    }
}

@Preview
@Composable
private fun WavySeekPausedPreview() {
    PreviewFrame(dark = true) {
        WavySeek(progress = { 0.6f }, buffered = { 0.85f }, playing = false, onSeek = {}, label = "2:30")
    }
}
