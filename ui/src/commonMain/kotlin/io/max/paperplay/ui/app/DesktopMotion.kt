package io.max.paperplay.ui.app

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.UploadFile
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.isPhone
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.Motion
import io.max.paperplay.ui.theme.desktopFocusSpec
import io.max.paperplay.ui.theme.desktopHoverSpec
import io.max.paperplay.ui.theme.desktopPressSpec
import io.max.paperplay.ui.theme.desktopScrollbarFadeInSpec
import io.max.paperplay.ui.theme.desktopScrollbarFadeOutSpec
import io.max.paperplay.ui.theme.motionEffectTween
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.exp

/**
 * Unified desktop interaction polish: fast non-bouncy hover wash, subtle press compression,
 * crisp keyboard focus ring, and pointer cursor shape. Zero-op on phone.
 */
fun Modifier.desktopInteractive(
    shape: Shape = RoundedCornerShape(10.dp),
    enabled: Boolean = true,
    cursor: PointerIcon = PointerIcon.Hand,
    hoverAlpha: Float = 0.07f,
    pressScale: Float = Motion.Desktop.PressScale,
    focusRing: Boolean = true,
    interactionSource: MutableInteractionSource? = null,
    attachFocus: Boolean = true,
): Modifier = if (isPhone) this else composed {
    val source = interactionSource ?: remember { MutableInteractionSource() }
    val hovered by source.collectIsHoveredAsState()
    val pressed by source.collectIsPressedAsState()
    val focused by source.collectIsFocusedAsState()
    val reduced = LocalReduceMotion.current

    val hoverProgress by animateFloatAsState(
        targetValue = if (enabled && hovered) 1f else 0f,
        animationSpec = desktopHoverSpec(),
        label = "deskHover",
    )
    val focusProgress by animateFloatAsState(
        targetValue = if (enabled && focusRing && focused) 1f else 0f,
        animationSpec = desktopFocusSpec(),
        label = "deskFocus",
    )
    val scale by animateFloatAsState(
        targetValue = if (enabled && pressed && !reduced) pressScale else 1f,
        animationSpec = desktopPressSpec(),
        label = "deskPress",
    )

    val hoverColor = MaterialTheme.colorScheme.onSurface
    val focusColor = MaterialTheme.colorScheme.primary
    val strokePx = with(LocalDensity.current) { 1.75.dp.toPx() }

    this
        .then(if (enabled) Modifier.pointerHoverIcon(cursor) else Modifier)
        .hoverable(source, enabled = enabled)
        .then(if (attachFocus) Modifier.focusable(enabled = enabled, interactionSource = source) else Modifier)
        .graphicsLayer {
            scaleX = scale
            scaleY = scale
        }
        .drawWithContent {
            drawContent()
            if (hoverProgress > 0.005f || focusProgress > 0.005f) {
                val outline = shape.createOutline(size, layoutDirection, this)
                if (hoverProgress > 0.005f) {
                    drawOutline(outline, hoverColor.copy(alpha = hoverAlpha * hoverProgress))
                }
                if (focusProgress > 0.005f) {
                    drawOutline(
                        outline = outline,
                        color = focusColor.copy(alpha = 0.85f * focusProgress),
                        style = Stroke(width = strokePx),
                    )
                }
            }
        }
}

/**
 * Delayed desktop tooltip triggered by pointer hover or keyboard focus, dismissed immediately on click.
 * Transparent passthrough on phone or when [enabled] is false.
 */
@Composable
fun DesktopTooltip(
    text: String,
    modifier: Modifier = Modifier,
    enabled: Boolean = !isPhone,
    content: @Composable () -> Unit,
) {
    if (isPhone || !enabled || text.isBlank()) {
        Box(modifier) { content() }
        return
    }
    var hovered by remember { mutableStateOf(false) }
    var visible by remember { mutableStateOf(false) }
    val reduced = LocalReduceMotion.current
    val alphaAnim = remember { Animatable(0f) }
    val fadeSpec = motionEffectTween<Float>(Motion.Desktop.TooltipFadeMs)
    val shiftPx = with(LocalDensity.current) { Motion.Desktop.TooltipShiftDp.dp.roundToPx() }

    LaunchedEffect(hovered) {
        if (hovered) {
            delay(Motion.Desktop.TooltipShowDelayMs)
            visible = true
            alphaAnim.animateTo(1f, fadeSpec)
        } else {
            delay(Motion.Desktop.TooltipHideDelayMs)
            alphaAnim.animateTo(0f, fadeSpec)
            visible = false
        }
    }

    Box(
        modifier = modifier.pointerInput(Unit) {
            awaitPointerEventScope {
                while (true) {
                    val event = awaitPointerEvent(PointerEventPass.Initial)
                    when (event.type) {
                        PointerEventType.Enter -> hovered = true
                        PointerEventType.Exit, PointerEventType.Press -> hovered = false
                    }
                }
            }
        },
    ) {
        content()
        if (visible) {
            val yOffset = with(LocalDensity.current) { (-36).dp.roundToPx() }
            Popup(
                alignment = Alignment.TopCenter,
                offset = IntOffset(0, yOffset),
                properties = PopupProperties(focusable = false),
            ) {
                Surface(
                    shape = appShape(8.dp, CornerArea.Chips),
                    color = MaterialTheme.colorScheme.surfaceContainerHighest,
                    contentColor = MaterialTheme.colorScheme.onSurface,
                    border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f)),
                    shadowElevation = 4.dp,
                    modifier = Modifier.graphicsLayer {
                        val p = alphaAnim.value
                        alpha = p
                        if (!reduced) translationY = (1f - p) * shiftPx
                    },
                ) {
                    Text(
                        text = text,
                        style = MaterialTheme.typography.labelSmall,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
                    )
                }
            }
        }
    }
}

/**
 * Frame-rate-independent exponential-decay wheel scroll physics (supports 60, 120, 144, 240 Hz).
 * Zero per-frame allocations.
 */
class SmoothWheelScrollPhysics(
    private val tauSec: Float = Motion.Desktop.WheelDecayTauSec,
    private val settleThresholdPx: Float = Motion.Desktop.WheelSettleThresholdPx,
) {
    var remainingPx: Float = 0f
        private set

    val hasPending: Boolean
        get() = abs(remainingPx) >= settleThresholdPx

    /** Adds a wheel scroll impulse, reversing cleanly if direction flips. */
    fun addImpulse(deltaPx: Float, maxAccumulatedPx: Float) {
        if (!deltaPx.isFinite() || deltaPx == 0f) return
        if (remainingPx != 0f && (remainingPx > 0f) != (deltaPx > 0f)) {
            remainingPx = 0f
        }
        remainingPx = (remainingPx + deltaPx).coerceIn(-maxAccumulatedPx, maxAccumulatedPx)
    }

    /** Advances by [dtSeconds] and returns pixels to scroll this frame. */
    fun step(dtSeconds: Float, reduceMotion: Boolean = false): Float {
        if (!hasPending) {
            remainingPx = 0f
            return 0f
        }
        if (reduceMotion) {
            val all = remainingPx
            remainingPx = 0f
            return all
        }
        val dt = dtSeconds.coerceIn(0f, 0.1f)
        if (dt <= 0f) return 0f
        val fraction = 1f - exp(-dt / tauSec)
        val delta = remainingPx * fraction
        val nextRemaining = remainingPx - delta
        return if (abs(nextRemaining) < settleThresholdPx) {
            val all = remainingPx
            remainingPx = 0f
            all
        } else {
            remainingPx = nextRemaining
            delta
        }
    }

    fun stop() {
        remainingPx = 0f
    }
}

/**
 * Pure state machine for the fading desktop scrollbar.
 */
class FadingScrollbarController {
    var isScrolling: Boolean = false
        private set
    var isHovered: Boolean = false
        private set
    var isDragging: Boolean = false
        private set
    var isVisible: Boolean = false
        private set

    val targetAlpha: Float
        get() = when {
            isDragging || isHovered -> 0.90f
            isVisible || isScrolling -> 0.55f
            else -> 0f
        }

    fun onScrollActivity() {
        isScrolling = true
        isVisible = true
    }

    fun onHoverChanged(hovered: Boolean) {
        isHovered = hovered
        if (hovered) isVisible = true
    }

    fun onDragChanged(dragging: Boolean) {
        isDragging = dragging
        if (dragging) isVisible = true
    }

    fun onIdleTimeout() {
        isScrolling = false
        if (!isHovered && !isDragging) {
            isVisible = false
        }
    }
}

/**
 * Intercepts mouse wheel steps on desktop and applies smooth, frame-time-based scrolling to [state].
 * Sleeps completely (0 frame callbacks) when settled. No-op on phone.
 */
fun Modifier.desktopSmoothWheelScroll(
    state: LazyListState,
    physics: SmoothWheelScrollPhysics? = null,
    onScrollActivity: (() -> Unit)? = null,
): Modifier = desktopSmoothWheelScrollImpl(
    physics = physics,
    onScrollActivity = onScrollActivity,
    canScroll = { delta -> if (delta > 0f) state.canScrollForward else state.canScrollBackward },
    scrollBy = { delta -> state.scrollBy(delta) },
)

/**
 * Intercepts mouse wheel steps on desktop and applies smooth, frame-time-based scrolling to [state].
 */
fun Modifier.desktopSmoothWheelScroll(
    state: ScrollState,
    physics: SmoothWheelScrollPhysics? = null,
    onScrollActivity: (() -> Unit)? = null,
): Modifier = desktopSmoothWheelScrollImpl(
    physics = physics,
    onScrollActivity = onScrollActivity,
    canScroll = { delta -> if (delta > 0f) state.canScrollForward else state.canScrollBackward },
    scrollBy = { delta -> state.scrollBy(delta) },
)

private fun Modifier.desktopSmoothWheelScrollImpl(
    physics: SmoothWheelScrollPhysics?,
    onScrollActivity: (() -> Unit)?,
    canScroll: (Float) -> Boolean,
    scrollBy: suspend (Float) -> Float,
): Modifier = if (isPhone) this else composed {
    val wheelPhysics = physics ?: remember { SmoothWheelScrollPhysics() }
    val reduceMotion = LocalReduceMotion.current
    val density = LocalDensity.current.density
    val scope = rememberCoroutineScope()
    val latestCanScroll by rememberUpdatedState(canScroll)
    val latestScrollBy by rememberUpdatedState(scrollBy)
    val latestActivity by rememberUpdatedState(onScrollActivity)
    var animating by remember { mutableStateOf(false) }

    fun kickLoop() {
        if (animating || !wheelPhysics.hasPending) return
        animating = true
        scope.launch {
            try {
                var lastNs = 0L
                while (isActive && wheelPhysics.hasPending) {
                    var moved = 0f
                    withFrameNanos { now ->
                        if (lastNs == 0L) {
                            lastNs = now
                        } else {
                            val dt = (now - lastNs) / 1_000_000_000f
                            lastNs = now
                            val step = wheelPhysics.step(dt, reduceMotion)
                            if (step != 0f) moved = step
                        }
                    }
                    if (moved != 0f) {
                        val consumed = latestScrollBy(moved)
                        if (abs(consumed) < 0.1f && !latestCanScroll(moved)) {
                            wheelPhysics.stop()
                        }
                    }
                }
            } finally {
                animating = false
            }
        }
    }

    pointerInput(density, reduceMotion) {
        awaitPointerEventScope {
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                if (event.type == PointerEventType.Scroll) {
                    val dy = event.changes.fold(0f) { acc, change -> acc + change.scrollDelta.y }
                    if (dy != 0f && latestCanScroll(dy)) {
                        event.changes.forEach { it.consume() }
                        val stepPx = dy * Motion.Desktop.WheelStepDp * density
                        val maxPx = Motion.Desktop.WheelMaxAccumulatedDp * density
                        wheelPhysics.addImpulse(stepPx, maxPx)
                        latestActivity?.invoke()
                        kickLoop()
                    }
                }
            }
        }
    }
}


/** The owner wants no scroll bars anywhere: scrolling stays (wheel, drag, keys), only the bar is not drawn. True brings them back. */
private const val ShowScrollbars = false
/**
 * Wraps a scrollable [LazyListState] container on desktop with smooth wheel scrolling and a fading
 * vertical scrollbar. On phone, invokes [content] directly with [modifier].
 */
@Composable
fun DesktopScrollHost(
    state: LazyListState,
    modifier: Modifier = Modifier,
    /** False keeps the smooth wheel but draws no bar: for narrow strips such as the sidebar, where the bar sat over the icons. */
    showScrollbar: Boolean = true,
    content: @Composable (Modifier) -> Unit,
) {
    if (isPhone) {
        content(modifier)
        return
    }
    val physics = remember { SmoothWheelScrollPhysics() }
    val controller = remember { FadingScrollbarController() }
    var activityTick by remember { mutableLongStateOf(0L) }
    val scope = rememberCoroutineScope()

    val isScrollable by remember {
        derivedStateOf { state.canScrollForward || state.canScrollBackward }
    }
    LaunchedEffect(state.isScrollInProgress) {
        if (state.isScrollInProgress) {
            controller.onScrollActivity()
            activityTick++
        }
    }
    LaunchedEffect(activityTick) {
        if (activityTick > 0L) {
            delay(Motion.Desktop.ScrollbarIdleDelayMs)
            controller.onIdleTimeout()
            activityTick++ // triggers targetAlpha re-evaluation if needed via state below
        }
    }

    var targetAlpha by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(state.isScrollInProgress, activityTick) {
        targetAlpha = if (isScrollable) controller.targetAlpha else 0f
    }

    Box(modifier) {
        content(
            Modifier.fillMaxSize().desktopSmoothWheelScroll(
                state = state,
                physics = physics,
                onScrollActivity = {
                    controller.onScrollActivity()
                    activityTick++
                    targetAlpha = if (isScrollable) controller.targetAlpha else 0f
                },
            ),
        )
        if (ShowScrollbars && isScrollable && showScrollbar) {
            val metrics by remember {
                derivedStateOf {
                    val info = state.layoutInfo
                    val total = info.totalItemsCount
                    val visible = info.visibleItemsInfo
                    if (total <= 0 || visible.isEmpty()) {
                        0f to 1f
                    } else {
                        val avgSize = visible.sumOf { it.size }.toFloat() / visible.size
                        val totalEst = (avgSize * total).coerceAtLeast(1f)
                        val viewport = (info.viewportEndOffset - info.viewportStartOffset).toFloat().coerceAtLeast(1f)
                        val firstOffset = state.firstVisibleItemIndex * avgSize + state.firstVisibleItemScrollOffset
                        val fraction = (viewport / totalEst).coerceIn(0.08f, 1f)
                        val maxScroll = (totalEst - viewport).coerceAtLeast(1f)
                        val pos = (firstOffset / maxScroll).coerceIn(0f, 1f)
                        pos to fraction
                    }
                }
            }
            DesktopScrollbarTrack(
                positionFraction = metrics.first,
                thumbFraction = metrics.second,
                controller = controller,
                onActivity = {
                    activityTick++
                    targetAlpha = controller.targetAlpha
                },
                onScrollFraction = { frac ->
                    physics.stop()
                    val total = state.layoutInfo.totalItemsCount
                    if (total > 0) {
                        val idx = (frac.coerceIn(0f, 1f) * (total - 1)).toInt().coerceIn(0, total - 1)
                        scope.launch { state.scrollToItem(idx) }
                    }
                },
                onDragDeltaPx = { dyPx, trackHeightPx ->
                    physics.stop()
                    val info = state.layoutInfo
                    val visible = info.visibleItemsInfo
                    if (visible.isNotEmpty() && trackHeightPx > 1f) {
                        val avgSize = visible.sumOf { it.size }.toFloat() / visible.size
                        val totalEst = (avgSize * info.totalItemsCount).coerceAtLeast(1f)
                        val deltaScroll = (dyPx / trackHeightPx) * totalEst
                        scope.launch { state.scrollBy(deltaScroll) }
                    }
                },
                modifier = Modifier.align(Alignment.CenterEnd).fillMaxHeight(),
            )
        }
    }
}

/**
 * Wraps a scrollable [ScrollState] container on desktop with smooth wheel scrolling and a fading
 * vertical scrollbar. On phone, invokes [content] directly with [modifier].
 */
@Composable
fun DesktopScrollHost(
    state: ScrollState,
    modifier: Modifier = Modifier,
    content: @Composable (Modifier) -> Unit,
) {
    if (isPhone) {
        content(modifier)
        return
    }
    val physics = remember { SmoothWheelScrollPhysics() }
    val controller = remember { FadingScrollbarController() }
    var activityTick by remember { mutableLongStateOf(0L) }
    val scope = rememberCoroutineScope()
    val isScrollable by remember { derivedStateOf { state.maxValue > 0 } }

    LaunchedEffect(state.isScrollInProgress) {
        if (state.isScrollInProgress) {
            controller.onScrollActivity()
            activityTick++
        }
    }
    LaunchedEffect(activityTick) {
        if (activityTick > 0L) {
            delay(Motion.Desktop.ScrollbarIdleDelayMs)
            controller.onIdleTimeout()
        }
    }

    Box(modifier) {
        content(
            Modifier.fillMaxSize().desktopSmoothWheelScroll(
                state = state,
                physics = physics,
                onScrollActivity = {
                    controller.onScrollActivity()
                    activityTick++
                },
            ),
        )
        if (ShowScrollbars && isScrollable) {
            val metrics by remember {
                derivedStateOf {
                    val max = state.maxValue.toFloat().coerceAtLeast(1f)
                    val vp = state.viewportSize.toFloat().coerceAtLeast(1f)
                    val total = max + vp
                    val thumb = (vp / total).coerceIn(0.08f, 1f)
                    val pos = (state.value / max).coerceIn(0f, 1f)
                    pos to thumb
                }
            }
            DesktopScrollbarTrack(
                positionFraction = metrics.first,
                thumbFraction = metrics.second,
                controller = controller,
                onActivity = { activityTick++ },
                onScrollFraction = { frac ->
                    physics.stop()
                    scope.launch { state.scrollTo((frac.coerceIn(0f, 1f) * state.maxValue).toInt()) }
                },
                onDragDeltaPx = { dyPx, trackHeightPx ->
                    physics.stop()
                    if (trackHeightPx > 1f) {
                        val total = state.maxValue + state.viewportSize.coerceAtLeast(1)
                        val deltaScroll = (dyPx / trackHeightPx) * total
                        scope.launch { state.scrollBy(deltaScroll) }
                    }
                },
                modifier = Modifier.align(Alignment.CenterEnd).fillMaxHeight(),
            )
        }
    }
}

@Composable
private fun DesktopScrollbarTrack(
    positionFraction: Float,
    thumbFraction: Float,
    controller: FadingScrollbarController,
    onActivity: () -> Unit,
    onScrollFraction: (Float) -> Unit,
    onDragDeltaPx: (Float, Float) -> Unit,
    modifier: Modifier = Modifier,
) {
    var hovered by remember { mutableStateOf(false) }
    var dragging by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(
        targetValue = controller.targetAlpha,
        animationSpec = if (controller.targetAlpha > 0f) desktopScrollbarFadeInSpec() else desktopScrollbarFadeOutSpec(),
        label = "scrollbarAlpha",
    )
    val thumbWidth by animateDpAsState(
        targetValue = if (hovered || dragging) Motion.Desktop.ScrollbarHoverWidthDp.dp else Motion.Desktop.ScrollbarRestWidthDp.dp,
        animationSpec = desktopHoverSpec(),
        label = "scrollbarWidth",
    )
    val thumbColor = MaterialTheme.colorScheme.onSurfaceVariant
    var trackHeightPx by remember { mutableFloatStateOf(1f) }

    Box(
        modifier = modifier
            .width(14.dp)
            .padding(vertical = 6.dp, horizontal = 3.dp)
            .pointerHoverIcon(PointerIcon.Hand)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent(PointerEventPass.Initial)
                        when (event.type) {
                            PointerEventType.Enter -> {
                                hovered = true
                                controller.onHoverChanged(true)
                                onActivity()
                            }
                            PointerEventType.Exit -> {
                                hovered = false
                                controller.onHoverChanged(false)
                                onActivity()
                            }
                        }
                    }
                }
            }
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    val h = size.height.toFloat().coerceAtLeast(1f)
                    onScrollFraction(offset.y / h)
                    controller.onScrollActivity()
                    onActivity()
                }
            }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = {
                        dragging = true
                        controller.onDragChanged(true)
                        onActivity()
                    },
                    onDragEnd = {
                        dragging = false
                        controller.onDragChanged(false)
                        onActivity()
                    },
                    onDragCancel = {
                        dragging = false
                        controller.onDragChanged(false)
                        onActivity()
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()
                        onDragDeltaPx(dragAmount.y, trackHeightPx)
                    },
                )
            },
    ) {
        Canvas(Modifier.fillMaxSize().graphicsLayer { this.alpha = alpha }) {
            trackHeightPx = size.height
            val thumbH = (size.height * thumbFraction).coerceAtLeast(24.dp.toPx()).coerceAtMost(size.height)
            val travel = (size.height - thumbH).coerceAtLeast(0f)
            val top = travel * positionFraction.coerceIn(0f, 1f)
            val w = thumbWidth.toPx().coerceAtMost(size.width)
            val left = size.width - w
            drawRoundRect(
                color = thumbColor,
                topLeft = Offset(left, top),
                size = Size(w, thumbH),
                cornerRadius = CornerRadius(w / 2f, w / 2f),
            )
        }
    }
}

/**
 * Translucent file-drop target overlay shown when dragging audio files or folders onto the desktop window.
 */
@Composable
fun DesktopFileDropOverlay(
    visible: Boolean,
    fileCount: Int,
    modifier: Modifier = Modifier,
) {
    if (isPhone) return
    val reduced = LocalReduceMotion.current
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = motionEffectTween(Motion.Desktop.DropOverlayFadeMs),
        label = "dropOverlay",
    )
    if (alpha <= 0.01f && !visible) return

    val accent = MaterialTheme.colorScheme.primary
    val surface = MaterialTheme.colorScheme.surfaceContainerHigh
    val strokePx = with(LocalDensity.current) { 2.dp.toPx() }
    val dash = remember { PathEffect.dashPathEffect(floatArrayOf(14f, 10f), 0f) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .then(if (visible) Modifier.blockTouchesBehind() else Modifier)
            .graphicsLayer {
                this.alpha = alpha
                if (!reduced) {
                    val s = 0.985f + 0.015f * alpha
                    scaleX = s
                    scaleY = s
                }
            }
            .padding(24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Surface(
            shape = appShape(24.dp, CornerArea.Dialogs),
            color = surface.copy(alpha = 0.94f),
            tonalElevation = 8.dp,
            modifier = Modifier.drawWithContent {
                drawContent()
                drawRoundRect(
                    color = accent.copy(alpha = 0.75f),
                    style = Stroke(width = strokePx, pathEffect = dash),
                    cornerRadius = CornerRadius(24.dp.toPx(), 24.dp.toPx()),
                )
            },
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 44.dp, vertical = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                AppIcon(
                    Icons.Rounded.UploadFile,
                    contentDescription = "Drop files",
                    tint = accent,
                    modifier = Modifier.size(44.dp),
                )
                Text(
                    text = if (fileCount > 1) "Drop $fileCount items to upload" else "Drop audio files to upload",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    text = "Supported songs and folders are added to your upload queue",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
