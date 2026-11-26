package io.max.paperplay.ui.app

import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.animate
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.sign

/** Axis along which the mini-player dismisses when paused. */
enum class MiniPlayerHideAxis {
    /** Default mini-player: horizontal swipe left or right while paused. */
    HorizontalAny,
    /** Modern floating mini-player: vertical swipe down while paused. */
    VerticalDown,
}

/** Thresholds and animation targets for mini-player hide, parameterized by [axis]. */
data class MiniPlayerHideConfig(
    val axis: MiniPlayerHideAxis,
    val distanceThresholdPx: Float,
    val velocityThresholdPxPerSec: Float,
    val fadeSpanPx: Float,
    val dismissTargetPx: Float,
)

/** Default style hide config: byte-for-byte identical to the original Default constants. */
internal fun defaultMiniHideConfig(density: Density): MiniPlayerHideConfig = MiniPlayerHideConfig(
    axis = MiniPlayerHideAxis.HorizontalAny,
    distanceThresholdPx = with(density) { 80.dp.toPx() },
    velocityThresholdPxPerSec = 800f,
    fadeSpanPx = 700f,
    dismissTargetPx = 1000f,
)

/** Modern style hide config: downward swipe scaled to the 68 dp floating pill height. */
internal fun modernMiniHideConfig(density: Density): MiniPlayerHideConfig = MiniPlayerHideConfig(
    axis = MiniPlayerHideAxis.VerticalDown,
    distanceThresholdPx = with(density) { 36.dp.toPx() },
    velocityThresholdPxPerSec = 600f,
    fadeSpanPx = with(density) { 120.dp.toPx() },
    dismissTargetPx = with(density) { 140.dp.toPx() },
)

/** Mini-player can only be dismissed while paused. */
internal fun canDismissMiniPlayer(playing: Boolean): Boolean = !playing

/** Mini-player returns automatically whenever playback starts or resumes. */
internal fun shouldRestoreMiniPlayer(playing: Boolean): Boolean = playing

/** Pure hide release decision shared by Default (horizontal) and Modern (vertical down). */
internal fun shouldDismissMiniPlayer(
    offsetPx: Float,
    velocityPxPerSec: Float,
    config: MiniPlayerHideConfig,
    playing: Boolean,
): Boolean {
    if (!canDismissMiniPlayer(playing)) return false
    return when (config.axis) {
        MiniPlayerHideAxis.HorizontalAny ->
            abs(offsetPx) > config.distanceThresholdPx || abs(velocityPxPerSec) > config.velocityThresholdPxPerSec
        MiniPlayerHideAxis.VerticalDown ->
            offsetPx > config.distanceThresholdPx || (offsetPx > 0f && velocityPxPerSec > config.velocityThresholdPxPerSec)
    }
}

/** Off-screen dismiss target along [config.axis]. */
internal fun dismissTargetOffset(
    offsetPx: Float,
    velocityPxPerSec: Float,
    config: MiniPlayerHideConfig,
): Float = when (config.axis) {
    MiniPlayerHideAxis.HorizontalAny -> {
        val dir = if (offsetPx != 0f) sign(offsetPx) else sign(velocityPxPerSec)
        dir * config.dismissTargetPx
    }
    MiniPlayerHideAxis.VerticalDown -> config.dismissTargetPx
}

/** Alpha multiplier as the mini-player slides toward its dismiss target. */
internal fun hideAlphaFactor(offsetPx: Float, config: MiniPlayerHideConfig): Float =
    (1f - abs(offsetPx) / config.fadeSpanPx.coerceAtLeast(1f)).coerceIn(0f, 1f)

/** Single shared hide state for both Default and Modern mini-players. */
@Stable
class MiniPlayerHideState {
    var gone by mutableStateOf(false)
    var dragOffset by mutableFloatStateOf(0f)

    fun onPlayingChanged(playing: Boolean) {
        if (shouldRestoreMiniPlayer(playing)) {
            gone = false
            dragOffset = 0f
        }
    }

    fun onDragDelta(delta: Float, config: MiniPlayerHideConfig, playing: Boolean) {
        if (!canDismissMiniPlayer(playing)) return
        dragOffset = when (config.axis) {
            MiniPlayerHideAxis.HorizontalAny -> dragOffset + delta
            MiniPlayerHideAxis.VerticalDown -> (dragOffset + delta).coerceAtLeast(0f)
        }
    }

    suspend fun onDragEnd(
        velocityPxPerSec: Float,
        config: MiniPlayerHideConfig,
        playing: Boolean,
        dismissSpec: AnimationSpec<Float>,
        returnSpec: AnimationSpec<Float>,
    ) {
        val from = dragOffset
        if (shouldDismissMiniPlayer(from, velocityPxPerSec, config, playing)) {
            animate(from, dismissTargetOffset(from, velocityPxPerSec, config), animationSpec = dismissSpec) { v, _ ->
                dragOffset = v
            }
            gone = true
            dragOffset = 0f
        } else {
            animate(from, 0f, animationSpec = returnSpec) { v, _ ->
                dragOffset = v
            }
            dragOffset = 0f
        }
    }

    suspend fun onDragCancel(returnSpec: AnimationSpec<Float>) {
        animate(dragOffset, 0f, animationSpec = returnSpec) { v, _ ->
            dragOffset = v
        }
        dragOffset = 0f
    }

    suspend fun dismissProgrammatically(
        config: MiniPlayerHideConfig,
        playing: Boolean,
        dismissSpec: AnimationSpec<Float>,
    ) {
        if (!canDismissMiniPlayer(playing)) return
        val target = if (config.axis == MiniPlayerHideAxis.HorizontalAny) {
            -config.dismissTargetPx
        } else {
            config.dismissTargetPx
        }
        animate(dragOffset, target, animationSpec = dismissSpec) { v, _ ->
            dragOffset = v
        }
        gone = true
        dragOffset = 0f
    }
}

/** Locked drag axis for the Modern floating mini-player once pointer movement passes touch slop. */
internal enum class ModernMiniDragLock {
    None,
    HorizontalSkip,
    VerticalExpand,
    VerticalHide,
}

/** Track skip outcome on horizontal swipe release in Modern. */
internal enum class ModernMiniSkipAction {
    None,
    Next,
    Previous,
}

/** Locks the Modern mini-player drag axis once total pointer travel reaches [touchSlopPx]. */
internal fun resolveModernMiniDragLock(
    totalDx: Float,
    totalDy: Float,
    touchSlopPx: Float,
): ModernMiniDragLock {
    if (hypot(totalDx, totalDy) < touchSlopPx) return ModernMiniDragLock.None
    if (abs(totalDx) >= abs(totalDy)) return ModernMiniDragLock.HorizontalSkip
    return if (totalDy < 0f) ModernMiniDragLock.VerticalExpand else ModernMiniDragLock.VerticalHide
}

/** Resolves horizontal skip direction in Modern (left = Next, right = Previous). */
internal fun resolveModernMiniSkip(
    totalDx: Float,
    velocityXPxPerSec: Float,
    thresholdPx: Float,
    velocityThresholdPxPerSec: Float = 800f,
): ModernMiniSkipAction = when {
    totalDx <= -thresholdPx || (totalDx < 0f && velocityXPxPerSec <= -velocityThresholdPxPerSec) ->
        ModernMiniSkipAction.Next
    totalDx >= thresholdPx || (totalDx > 0f && velocityXPxPerSec >= velocityThresholdPxPerSec) ->
        ModernMiniSkipAction.Previous
    else -> ModernMiniSkipAction.None
}

/** Pure release decision for upward expand drag from the mini-player. */
internal fun shouldOpenOnExpandRelease(progress: Float, velocityYPxPerSec: Float): Boolean = when {
    velocityYPxPerSec <= io.max.paperplay.ui.theme.PlayerMotionTokens.OPEN_VELOCITY_PX_PER_SEC -> true
    velocityYPxPerSec >= io.max.paperplay.ui.theme.PlayerMotionTokens.DISMISS_VELOCITY_PX_PER_SEC -> false
    else -> progress >= 0.20f
}
