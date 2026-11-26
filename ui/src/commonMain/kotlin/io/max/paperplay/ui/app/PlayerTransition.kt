package io.max.paperplay.ui.app

import androidx.compose.animation.core.AnimationState
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.animateTo
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.paneTitle
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.PreviewFrame
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.state.SongUi
import io.max.paperplay.ui.theme.PlayerMotionTokens
import io.max.paperplay.ui.theme.playerCloseSpringSpec
import io.max.paperplay.ui.theme.playerOpenSpringSpec
import io.max.paperplay.ui.theme.playerReducedFadeSpec
import io.max.paperplay.ui.theme.playerSettleSpringSpec
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.abs

/**
 * Explicit lifecycle states of the full-player sheet transition.
 *
 * - [Closed]: Fully hidden (`progress == 0f`) and unmounted from composition.
 * - [Opening]: Animating toward `1f` (`isSettled == false`).
 * - [Open]: Fully open and settled (`progress == 1f`, `isSettled == true`).
 * - [Closing]: Animating toward `0f` (`isSettled == false`).
 * - [Dragging]: Tracking a finger 1:1 downward or rubber-banding upward.
 * - [BackGesture]: Scrubbed by Android predictive back (`1f - BACK_GESTURE_MAX_PULL * p`).
 * - [Settling]: Returning to `1f` after a cancelled back gesture or a sub-threshold drag.
 */
enum class PlayerSheetPhase {
    Closed,
    Opening,
    Open,
    Closing,
    Dragging,
    BackGesture,
    Settling,
}

/**
 * Content staging tiers so frame 1 of opening stays cheap:
 * - [Chrome]: Cover, tinted surface, title/artist, primary transport, static progress line.
 * - [Interactive]: Secondary controls and interactive seek bar (wave animation paused).
 * - [SettledEffects]: Heavy glass blur/lens, drifting blooms, and seek wave animations.
 */
enum class PlayerContentStage {
    Chrome,
    Interactive,
    SettledEffects,
}

/**
 * Single source of truth for the full-player sheet open/close transition.
 *
 * [progress] (`0f..1f`) and [visualProgress] (`0f..1f + RUBBER_BAND_MAX`) are backed by snapshot
 * float state and MUST only be read inside `graphicsLayer`, `drawWithContent`, layout, or
 * `derivedStateOf` hysteresis properties — never directly inside composable bodies.
 */
@Stable
class PlayerTransitionController(
    private val scope: CoroutineScope? = null,
    reduceMotion: Boolean = false,
    val standalone: Boolean = false,
    initiallyOpen: Boolean = standalone,
) {
    private var _rawProgress by mutableFloatStateOf(if (initiallyOpen) 1f else 0f)
    private var _phase by mutableStateOf(if (initiallyOpen) PlayerSheetPhase.Open else PlayerSheetPhase.Closed)
    private var _reduceMotion by mutableStateOf(reduceMotion)
    private var _settledEffectsReady by mutableStateOf(initiallyOpen && (standalone || reduceMotion))

    private var activeJob: Job? = null
    private var generation: Long = 0L
    private var currentVelocity: Float = 0f
    private var upwardOverscrollPx: Float = 0f
    private var disposed: Boolean = false

    private var lastCovered: Boolean = initiallyOpen
    private var lastSystemBars: Boolean = initiallyOpen

    /** Clamped `0f..1f` transition progress. Read only inside layer/draw/derivedStateOf blocks. */
    val progress: Float
        get() = _rawProgress.coerceIn(0f, 1f)

    /** Visual progress including upward rubber-band overscroll (`0f..1f + RUBBER_BAND_MAX`). */
    val visualProgress: Float
        get() = _rawProgress.coerceIn(0f, 1f + PlayerMotionTokens.RUBBER_BAND_MAX)

    /** Current explicit state-machine phase. */
    val phase: PlayerSheetPhase
        get() = _phase

    /** Whether Reduce Motion is currently active on this controller. */
    val reduceMotion: Boolean
        get() = _reduceMotion

    /** True when the sheet is at rest (`Closed` or `Open`). */
    val isSettled: Boolean
        get() = _phase == PlayerSheetPhase.Closed || _phase == PlayerSheetPhase.Open

    /** True while the full player should remain mounted in composition. */
    val isComposed: Boolean by derivedStateOf {
        standalone || _phase != PlayerSheetPhase.Closed || _rawProgress > 0f
    }

    /** True while the sheet is actively animating or being scrubbed. */
    val isTransitioning: Boolean by derivedStateOf {
        !standalone && _phase != PlayerSheetPhase.Closed && _phase != PlayerSheetPhase.Open
    }

    /** True when the user's intent is open (`Opening`, `Open`, `Settling`). */
    val isTargetOpen: Boolean by derivedStateOf {
        standalone || _phase == PlayerSheetPhase.Open || _phase == PlayerSheetPhase.Opening || _phase == PlayerSheetPhase.Settling
    }

    /** Hysteresis-guarded flag indicating the sheet completely occludes the underlying page. */
    val isCovered: Boolean by derivedStateOf {
        val next = nextCovered(lastCovered, _phase, progress)
        lastCovered = next
        next
    }

    /** Hysteresis-guarded flag indicating system bar icons should follow the dark player theme. */
    val isPlayerSystemBars: Boolean by derivedStateOf {
        val next = nextPlayerSystemBars(lastSystemBars, _phase, progress)
        lastSystemBars = next
        next
    }

    /** Current content staging tier. */
    val contentStage: PlayerContentStage by derivedStateOf {
        when {
            standalone -> PlayerContentStage.SettledEffects
            _phase == PlayerSheetPhase.Closed -> PlayerContentStage.Chrome
            _phase == PlayerSheetPhase.Open && (_settledEffectsReady || _reduceMotion) -> PlayerContentStage.SettledEffects
            _reduceMotion -> PlayerContentStage.Interactive
            _phase == PlayerSheetPhase.Open -> PlayerContentStage.Interactive
            _rawProgress >= PlayerMotionTokens.STAGE1_ENTER_PROGRESS || _phase != PlayerSheetPhase.Opening ->
                PlayerContentStage.Interactive
            else -> PlayerContentStage.Chrome
        }
    }

    /** True when the layer-based shared cover flight should replace resting mini/full covers. */
    fun isCoverFlightActive(bounds: CoverBoundsRegistry?): Boolean {
        if (standalone || _reduceMotion || bounds == null || !bounds.canFly) return false
        return _phase != PlayerSheetPhase.Closed &&
            _phase != PlayerSheetPhase.Open &&
            progress > 0.001f &&
            progress < 0.999f
    }

    fun setReduceMotion(enabled: Boolean) {
        if (_reduceMotion == enabled) return
        _reduceMotion = enabled
        if (enabled && _phase == PlayerSheetPhase.Open) {
            _settledEffectsReady = true
        }
    }

    internal fun setSettledEffectsReady(ready: Boolean) {
        _settledEffectsReady = ready
    }

    /** Opens the player from the current progress and velocity. Interruptible at any time. */
    fun open() {
        if (standalone || disposed) return
        if (_phase == PlayerSheetPhase.Open && _rawProgress >= 1f) return
        upwardOverscrollPx = 0f
        _settledEffectsReady = false
        val spec = if (_reduceMotion) playerReducedFadeSpec() else playerOpenSpringSpec()
        launchAnimation(
            target = 1f,
            targetPhase = PlayerSheetPhase.Opening,
            settledPhase = PlayerSheetPhase.Open,
            spec = spec,
            initialVelocity = if (_reduceMotion) 0f else currentVelocity,
        )
    }

    /** Closes the player from the current progress and velocity. Interruptible at any time. */
    fun close() {
        if (standalone || disposed) return
        if (_phase == PlayerSheetPhase.Closed && _rawProgress <= 0f) return
        upwardOverscrollPx = 0f
        _settledEffectsReady = false
        val spec = if (_reduceMotion) playerReducedFadeSpec() else playerCloseSpringSpec()
        launchAnimation(
            target = 0f,
            targetPhase = PlayerSheetPhase.Closing,
            settledPhase = PlayerSheetPhase.Closed,
            spec = spec,
            initialVelocity = if (_reduceMotion) 0f else currentVelocity,
        )
    }

    /**
     * Synchronous 1:1 vertical drag update ([dyPx] > 0 is downward).
     * Cancels any running animation immediately without coroutine dispatch delay.
     */
    fun dragBy(dyPx: Float, heightPx: Float) {
        if (standalone || disposed || heightPx <= 1f || !dyPx.isFinite()) return
        cancelActiveAnimation()
        _settledEffectsReady = false
        _phase = PlayerSheetPhase.Dragging
        currentVelocity = 0f

        if (upwardOverscrollPx > 0f) {
            // Unwind rubber-band overscroll before pulling below 1f.
            val remaining = upwardOverscrollPx - dyPx
            if (remaining >= 0f) {
                upwardOverscrollPx = remaining
                _rawProgress = 1f + rubberBandOverscroll(upwardOverscrollPx, heightPx)
                return
            } else {
                upwardOverscrollPx = 0f
                _rawProgress = (1f + remaining / heightPx).coerceIn(0f, 1f)
                return
            }
        }

        val next = _rawProgress - dyPx / heightPx
        if (next > 1f) {
            upwardOverscrollPx = (next - 1f) * heightPx
            _rawProgress = 1f + rubberBandOverscroll(upwardOverscrollPx, heightPx)
        } else {
            upwardOverscrollPx = 0f
            _rawProgress = next.coerceIn(0f, 1f)
        }
    }

    /**
     * Finishes a drag gesture using [velocityYPxPerSec] (positive is downward) and [heightPx].
     * Fast upward flicks stay open; fast downward flicks close; slow drags decide by distance.
     */
    fun release(velocityYPxPerSec: Float, heightPx: Float) {
        if (standalone || disposed) return
        val safeHeight = heightPx.coerceAtLeast(1f)
        val clampedVel = if (velocityYPxPerSec.isFinite()) velocityYPxPerSec else 0f
        val wasRubberBand = _rawProgress > 1f
        upwardOverscrollPx = 0f
        _settledEffectsReady = false

        val closing = when {
            clampedVel <= PlayerMotionTokens.OPEN_VELOCITY_PX_PER_SEC -> false
            clampedVel >= PlayerMotionTokens.DISMISS_VELOCITY_PX_PER_SEC -> true
            else -> (1f - progress) > PlayerMotionTokens.DISMISS_DISTANCE_FRACTION
        }
        val progressVelocity = if (wasRubberBand && !closing) {
            0f
        } else {
            (-clampedVel / safeHeight).coerceIn(-12f, 12f)
        }

        if (_reduceMotion) {
            val spec = playerReducedFadeSpec()
            if (closing) {
                launchAnimation(0f, PlayerSheetPhase.Closing, PlayerSheetPhase.Closed, spec, 0f)
            } else {
                launchAnimation(1f, PlayerSheetPhase.Settling, PlayerSheetPhase.Open, spec, 0f)
            }
            return
        }

        if (closing) {
            launchAnimation(
                target = 0f,
                targetPhase = PlayerSheetPhase.Closing,
                settledPhase = PlayerSheetPhase.Closed,
                spec = playerCloseSpringSpec(),
                initialVelocity = progressVelocity,
            )
        } else {
            launchAnimation(
                target = 1f,
                targetPhase = PlayerSheetPhase.Settling,
                settledPhase = PlayerSheetPhase.Open,
                spec = playerSettleSpringSpec(),
                initialVelocity = progressVelocity,
            )
        }
    }

    /**
     * Finishes an upward expand drag from the mini-player using [velocityYPxPerSec] and [heightPx].
     * Fast upward flicks open; fast downward flicks close; slow drags open past 20% height.
     */
    fun releaseExpand(velocityYPxPerSec: Float, heightPx: Float) {
        if (standalone || disposed) return
        val safeHeight = heightPx.coerceAtLeast(1f)
        val clampedVel = if (velocityYPxPerSec.isFinite()) velocityYPxPerSec else 0f
        upwardOverscrollPx = 0f
        _settledEffectsReady = false

        val opening = shouldOpenOnExpandRelease(progress, clampedVel)
        val progressVelocity = (-clampedVel / safeHeight).coerceIn(-12f, 12f)

        if (_reduceMotion) {
            val spec = playerReducedFadeSpec()
            if (opening) {
                launchAnimation(1f, PlayerSheetPhase.Opening, PlayerSheetPhase.Open, spec, 0f)
            } else {
                launchAnimation(0f, PlayerSheetPhase.Closing, PlayerSheetPhase.Closed, spec, 0f)
            }
            return
        }

        if (opening) {
            launchAnimation(
                target = 1f,
                targetPhase = PlayerSheetPhase.Opening,
                settledPhase = PlayerSheetPhase.Open,
                spec = playerOpenSpringSpec(),
                initialVelocity = progressVelocity,
            )
        } else {
            launchAnimation(
                target = 0f,
                targetPhase = PlayerSheetPhase.Closing,
                settledPhase = PlayerSheetPhase.Closed,
                spec = playerCloseSpringSpec(),
                initialVelocity = progressVelocity,
            )
        }
    }

    /** Cancels an active drag (e.g. pointer cancel) and settles back open. */
    fun cancelDrag() {
        if (_phase == PlayerSheetPhase.Dragging) {
            release(velocityYPxPerSec = 0f, heightPx = 1000f)
        }
    }

    /** Maps predictive back progress (`0f..1f`) to the sheet's progress synchronously. */
    fun backProgress(p: Float) {
        if (standalone || disposed || !isComposed) return
        cancelActiveAnimation()
        upwardOverscrollPx = 0f
        _settledEffectsReady = false
        _phase = PlayerSheetPhase.BackGesture
        currentVelocity = 0f
        val clamped = if (p.isFinite()) p.coerceIn(0f, 1f) else 0f
        _rawProgress = 1f - PlayerMotionTokens.BACK_GESTURE_MAX_PULL * clamped
    }

    /** Commits a predictive back gesture, closing from the current progress. */
    fun commitBack() {
        if (standalone || disposed) return
        close()
    }

    /** Cancels a predictive back gesture, settling back open from the current progress. */
    fun cancelBack() {
        if (standalone || disposed) return
        if (_phase == PlayerSheetPhase.Closed) return
        upwardOverscrollPx = 0f
        _settledEffectsReady = false
        val spec = if (_reduceMotion) playerReducedFadeSpec() else playerSettleSpringSpec()
        launchAnimation(
            target = 1f,
            targetPhase = PlayerSheetPhase.Settling,
            settledPhase = PlayerSheetPhase.Open,
            spec = spec,
            initialVelocity = if (_reduceMotion) 0f else currentVelocity,
        )
    }

    /** Immediately snaps the sheet open with no animation. */
    fun snapOpen() {
        if (disposed) return
        cancelActiveAnimation()
        upwardOverscrollPx = 0f
        currentVelocity = 0f
        _rawProgress = 1f
        _phase = PlayerSheetPhase.Open
        _settledEffectsReady = standalone || _reduceMotion
    }

    /** Immediately snaps the sheet closed with no animation (e.g., when queue becomes empty). */
    fun snapClosed() {
        if (standalone || disposed) return
        cancelActiveAnimation()
        upwardOverscrollPx = 0f
        currentVelocity = 0f
        _rawProgress = 0f
        _phase = PlayerSheetPhase.Closed
        _settledEffectsReady = false
    }

    /** Suspends until any running transition finishes. Intended for unit tests and benchmarks. */
    suspend fun awaitIdle() {
        activeJob?.join()
    }

    /** Cancels any running animations and prevents future launches after host disposal. */
    fun dispose() {
        disposed = true
        cancelActiveAnimation()
        currentVelocity = 0f
        upwardOverscrollPx = 0f
    }

    private fun cancelActiveAnimation() {
        generation++
        activeJob?.cancel()
        activeJob = null
    }

    private fun launchAnimation(
        target: Float,
        targetPhase: PlayerSheetPhase,
        settledPhase: PlayerSheetPhase,
        spec: FiniteAnimationSpec<Float>,
        initialVelocity: Float,
    ) {
        cancelActiveAnimation()
        val myGen = generation
        _phase = targetPhase
        val runnerScope = scope
        if (runnerScope == null) {
            _rawProgress = target
            currentVelocity = 0f
            _phase = settledPhase
            _settledEffectsReady = settledPhase == PlayerSheetPhase.Open && (_reduceMotion || standalone)
            return
        }
        val startValue = _rawProgress
        val startVel = if (initialVelocity.isFinite()) initialVelocity else 0f
        activeJob = runnerScope.launch {
            val anim = AnimationState(initialValue = startValue, initialVelocity = startVel)
            try {
                anim.animateTo(targetValue = target, animationSpec = spec) {
                    if (generation != myGen || disposed) {
                        cancelAnimation()
                        return@animateTo
                    }
                    _rawProgress = value
                    currentVelocity = velocity
                }
                if (generation == myGen && !disposed) {
                    _rawProgress = target
                    currentVelocity = 0f
                    _phase = settledPhase
                    if (settledPhase == PlayerSheetPhase.Open && _reduceMotion) {
                        _settledEffectsReady = true
                    }
                }
            } catch (_: CancellationException) {
                // Interrupted by another command; state was already updated by the interrupter.
            }
        }
    }

    companion object {
        fun standalone(): PlayerTransitionController = PlayerTransitionController(
            scope = null,
            reduceMotion = false,
            standalone = true,
            initiallyOpen = true,
        )
    }
}

val LocalPlayerTransition = staticCompositionLocalOf { PlayerTransitionController.standalone() }

/** Non-snapshot bounds registry for the layer-based shared cover flight. */
@Stable
class CoverBoundsRegistry {
    var miniRect: Rect? = null
    var fullRect: Rect? = null
    var playerRootCoords: LayoutCoordinates? = null
    var queueOpen: Boolean = false
    internal var fullSizeState by mutableStateOf(IntSize.Zero)

    val canFly: Boolean
        get() {
            if (queueOpen) return false
            val mini = miniRect ?: return false
            val full = fullRect ?: return false
            return !mini.isEmpty && !full.isEmpty && fullSizeState.width > 0 && fullSizeState.height > 0
        }

    fun clearMini() {
        miniRect = null
    }

    fun clearFull() {
        fullRect = null
        fullSizeState = IntSize.Zero
    }
}

val LocalCoverBounds = staticCompositionLocalOf<CoverBoundsRegistry?> { null }

/** Asymptotic rubber-band progress offset (`0f..RUBBER_BAND_MAX`) when pulling up past `Open`. */
internal fun rubberBandOverscroll(overscrollPx: Float, heightPx: Float): Float {
    if (overscrollPx <= 0f || heightPx <= 1f) return 0f
    val normalized = overscrollPx / heightPx
    return PlayerMotionTokens.RUBBER_BAND_MAX * (normalized / (normalized + PlayerMotionTokens.RUBBER_BAND_DAMPING))
}

/** Sheet vertical translation in pixels (`0f` when open or when [reduceMotion] is true). */
internal fun sheetTranslationY(visualProgress: Float, heightPx: Float, reduceMotion: Boolean): Float {
    if (reduceMotion || heightPx <= 0f) return 0f
    return (1f - visualProgress.coerceIn(0f, 1f + PlayerMotionTokens.RUBBER_BAND_MAX)) * heightPx
}

/** Sheet alpha (`1f` normally; short fade when [reduceMotion] is true). */
internal fun sheetAlpha(progress: Float, reduceMotion: Boolean): Float =
    if (reduceMotion) progress.coerceIn(0f, 1f) else 1f

/** True when top corners of the sheet should be rounded (during slide/drag/back, flat when full-screen). */
internal fun sheetClipsTopCorners(progress: Float, reduceMotion: Boolean): Boolean =
    !reduceMotion && progress.coerceIn(0f, 1f) < PlayerMotionTokens.SHEET_CORNER_CLIP_END

/** Underlying page dim scrim alpha (`0f..BACKDROP_MAX_DIM_ALPHA`). */
internal fun backdropDimAlpha(progress: Float): Float =
    progress.coerceIn(0f, 1f) * PlayerMotionTokens.BACKDROP_MAX_DIM_ALPHA

/** Underlying page scale (`1f` down to `BACKDROP_MIN_SCALE`, disabled under [reduceMotion]). */
internal fun backdropScale(progress: Float, reduceMotion: Boolean): Float {
    if (reduceMotion) return 1f
    val p = progress.coerceIn(0f, 1f)
    return 1f - (1f - PlayerMotionTokens.BACKDROP_MIN_SCALE) * p
}

/** Mini player alpha synced to sheet progress (`1f` at 0 -> `0f` by `MINI_PLAYER_FADE_END`). */
internal fun miniPlayerAlpha(progress: Float, reduceMotion: Boolean): Float {
    val p = progress.coerceIn(0f, 1f)
    if (reduceMotion) return 1f - p
    return (1f - p / PlayerMotionTokens.MINI_PLAYER_FADE_END).coerceIn(0f, 1f)
}

/** Mini player subtle downward shift as sheet rises. */
internal fun miniPlayerTranslationY(progress: Float, maxShiftPx: Float, reduceMotion: Boolean): Float {
    if (reduceMotion) return 0f
    val t = (progress.coerceIn(0f, 1f) / PlayerMotionTokens.MINI_PLAYER_FADE_END).coerceIn(0f, 1f)
    return maxShiftPx * t
}

/** Bottom nav bar alpha synced to sheet progress. */
internal fun navBarAlpha(progress: Float, reduceMotion: Boolean): Float {
    val p = progress.coerceIn(0f, 1f)
    if (reduceMotion) return 1f - p
    return (1f - p / PlayerMotionTokens.NAV_BAR_FADE_END).coerceIn(0f, 1f)
}

/** Bottom nav bar downward hide translation synced to sheet progress. */
internal fun navBarTranslationY(progress: Float, barHeightPx: Float, reduceMotion: Boolean): Float {
    if (reduceMotion || barHeightPx <= 0f) return 0f
    val t = (progress.coerceIn(0f, 1f) / PlayerMotionTokens.NAV_BAR_SLIDE_END).coerceIn(0f, 1f)
    return barHeightPx * t
}

/** Hysteresis rule for whether the full player completely covers the underlying page. */
internal fun nextCovered(wasCovered: Boolean, phase: PlayerSheetPhase, progress: Float): Boolean {
    if (phase == PlayerSheetPhase.Closed || phase == PlayerSheetPhase.Dragging || phase == PlayerSheetPhase.BackGesture) {
        return false
    }
    if (phase != PlayerSheetPhase.Open && phase != PlayerSheetPhase.Opening && phase != PlayerSheetPhase.Settling) {
        return false
    }
    return if (wasCovered) {
        progress >= PlayerMotionTokens.COVERED_EXIT
    } else {
        progress >= PlayerMotionTokens.COVERED_ENTER
    }
}

/** Hysteresis rule for whether system bar icons should switch to light-on-dark for the player. */
internal fun nextPlayerSystemBars(wasPlayerBars: Boolean, phase: PlayerSheetPhase, progress: Float): Boolean {
    if (phase == PlayerSheetPhase.Closed) return false
    return if (wasPlayerBars) {
        progress >= PlayerMotionTokens.SYSTEM_BARS_EXIT
    } else {
        progress >= PlayerMotionTokens.SYSTEM_BARS_ENTER
    }
}

internal fun lerpFloat(start: Float, stop: Float, fraction: Float): Float =
    start + (stop - start) * fraction

private val SheetTopRoundedShape = RoundedCornerShape(
    topStart = PlayerMotionTokens.SHEET_CORNER_RADIUS_DP.dp,
    topEnd = PlayerMotionTokens.SHEET_CORNER_RADIUS_DP.dp,
)

/**
 * Creates and owns a [PlayerTransitionController] tied to the composition lifecycle.
 * Schedules [PlayerContentStage.SettledEffects] one frame after landing on [PlayerSheetPhase.Open]
 * and disposes any running animations when removed from composition.
 */
@Composable
fun rememberPlayerTransitionController(
    initiallyOpen: Boolean = false,
    reduceMotion: Boolean = false,
): PlayerTransitionController {
    val scope = rememberCoroutineScope()
    val controller = remember {
        PlayerTransitionController(
            scope = scope,
            reduceMotion = reduceMotion,
            standalone = false,
            initiallyOpen = initiallyOpen,
        )
    }
    LaunchedEffect(reduceMotion) {
        controller.setReduceMotion(reduceMotion)
    }
    LaunchedEffect(controller.phase) {
        if (controller.phase == PlayerSheetPhase.Open) {
            if (!controller.reduceMotion) {
                withFrameNanos { }
            }
            controller.setSettledEffectsReady(true)
        } else {
            controller.setSettledEffectsReady(false)
        }
    }
    DisposableEffect(controller) {
        onDispose { controller.dispose() }
    }
    return controller
}

/**
 * Hosts the full player sheet driven by [controller]:
 * - Unmounts [content] completely when [PlayerTransitionController.isComposed] is false.
 * - Renders the dim scrim behind the sheet and blocks touches to underlying pages while active.
 * - Reads [PlayerTransitionController.progress] and [PlayerTransitionController.visualProgress]
 *   only inside `graphicsLayer` lambdas, never during composition.
 * - Manages TalkBack pane semantics and focus handoff on open/close.
 */
@Composable
fun PlayerSheetHost(
    controller: PlayerTransitionController,
    coverBounds: CoverBoundsRegistry? = null,
    onRequestFocusReturn: (() -> Unit)? = null,
    overlayActive: Boolean = false,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    val playerFocusRequester = remember { FocusRequester() }
    var wasOpenForFocus by remember { mutableStateOf(false) }

    LaunchedEffect(controller.phase) {
        when (controller.phase) {
            PlayerSheetPhase.Open -> {
                wasOpenForFocus = true
                runCatching { playerFocusRequester.requestFocus() }
            }
            PlayerSheetPhase.Closed -> {
                if (wasOpenForFocus) {
                    wasOpenForFocus = false
                    onRequestFocusReturn?.invoke()
                }
            }
            else -> Unit
        }
    }

    if (!controller.isComposed) return

    CompositionLocalProvider(
        LocalPlayerTransition provides controller,
        LocalCoverBounds provides coverBounds,
    ) {
        Box(modifier.fillMaxSize()) {
            // Backdrop dim scrim behind the rising sheet; blocks touches to underlying pages.
            Box(
                Modifier
                    .fillMaxSize()
                    .graphicsLayer { alpha = backdropDimAlpha(controller.progress) }
                    .background(Color.Black)
                    .blockTouchesBehind(),
            )
            // Sheet container: translationY / alpha / top-corner clip all in graphicsLayer.
            Box(
                Modifier
                    .fillMaxSize()
                    .onGloballyPositioned { coords ->
                        coverBounds?.playerRootCoords = coords
                    }
                    .graphicsLayer {
                        val rm = controller.reduceMotion
                        val p = controller.progress
                        val vp = controller.visualProgress
                        translationY = sheetTranslationY(vp, size.height, rm)
                        alpha = sheetAlpha(p, rm)
                        if (overlayActive && !rm) {
                            scaleX = PlayerMotionTokens.OVERLAY_UNDER_SCALE
                            scaleY = PlayerMotionTokens.OVERLAY_UNDER_SCALE
                        }
                        if (sheetClipsTopCorners(p, rm)) {
                            shape = SheetTopRoundedShape
                            clip = true
                        } else {
                            clip = false
                        }
                        compositingStrategy = if (controller.isTransitioning) {
                            CompositingStrategy.Offscreen
                        } else {
                            CompositingStrategy.Auto
                        }
                    }
                    .blockTouchesBehind()
                    .semantics {
                        paneTitle = "Now playing"
                        isTraversalGroup = true
                    }
                    .focusRequester(playerFocusRequester)
                    .focusable(),
            ) {
                content()
            }
        }
    }
}

/**
 * Unified drag gesture for the full-player cover/header area:
 * - Downward drags track 1:1 with the finger and dismiss past distance or velocity thresholds.
 * - Upward drags while already pulling unwind smoothly; upward pulls from rest rubber-band.
 * - Pure upward flicks from rest trigger [onQueue]; horizontal flicks trigger [onNext]/[onPrevious].
 */
fun Modifier.playerSheetDrag(
    controller: PlayerTransitionController,
    onQueue: (() -> Unit)? = null,
    onNext: (() -> Unit)? = null,
    onPrevious: (() -> Unit)? = null,
): Modifier {
    if (controller.standalone) return this
    return this.then(
        Modifier.pointerInput(controller) {
            var dx = 0f
            var dy = 0f
            var pulling = false
            val tracker = VelocityTracker()
            val fallbackHeightPx = 640.dp.toPx()
            detectDragGestures(
                onDragStart = {
                    dx = 0f
                    dy = 0f
                    pulling = false
                    tracker.resetTracking()
                },
                onDragEnd = {
                    val heightPx = size.height.toFloat().takeIf { it > 1f } ?: fallbackHeightPx
                    when {
                        pulling -> controller.release(tracker.calculateVelocity().y, heightPx)
                        dy < -80f && dy < -abs(dx) -> onQueue?.invoke()
                        dx < -80f -> onNext?.invoke()
                        dx > 80f -> onPrevious?.invoke()
                    }
                },
                onDragCancel = {
                    if (pulling) controller.cancelDrag()
                },
            ) { change, drag ->
                change.consume()
                dx += drag.x
                dy += drag.y
                if (!pulling && dy > 0f && dy > abs(dx)) {
                    pulling = true
                }
                if (pulling) {
                    val heightPx = size.height.toFloat().takeIf { it > 1f } ?: fallbackHeightPx
                    tracker.addPosition(change.uptimeMillis, Offset(0f, dy))
                    controller.dragBy(drag.y, heightPx)
                }
            }
        },
    )
}

/**
 * Records the mini player's cover bounds in root coordinates for [SharedCoverLayer].
 */
fun Modifier.registerMiniCoverBounds(bounds: CoverBoundsRegistry?): Modifier {
    if (bounds == null) return this
    return this.then(
        Modifier.onGloballyPositioned { coords ->
            if (coords.isAttached) bounds.miniRect = coords.boundsInRoot()
        },
    )
}

/**
 * Records the full player's resting cover bounds relative to [CoverBoundsRegistry.playerRootCoords],
 * making the target rect invariant to the sheet's `graphicsLayer { translationY }`.
 */
fun Modifier.registerFullCoverBounds(bounds: CoverBoundsRegistry?): Modifier {
    if (bounds == null) return this
    return this.then(
        Modifier.onGloballyPositioned { coords ->
            val root = bounds.playerRootCoords
            if (coords.isAttached && root != null && root.isAttached) {
                bounds.fullRect = root.localBoundingBoxOf(coords, clipBounds = false)
                if (bounds.fullSizeState != coords.size) {
                    bounds.fullSizeState = coords.size
                }
            }
        },
    )
}

/**
 * Layer-based shared-element cover flight between [MiniPlayer] and [FullPlayer], driven
 * synchronously by [PlayerTransitionController.progress] inside `graphicsLayer` with zero
 * LookaheadScope double-measure overhead. Falls back automatically when bounds are unavailable,
 * when the queue is open, or when Reduce Motion is enabled.
 */
@Composable
fun SharedCoverLayer(
    controller: PlayerTransitionController,
    coverBounds: CoverBoundsRegistry?,
    song: SongUi?,
    targetCornerRadiusDp: Dp,
    modifier: Modifier = Modifier,
    startCircular: Boolean = false,
) {
    if (song == null || coverBounds == null || !controller.isCoverFlightActive(coverBounds)) return
    val fullSizePx = coverBounds.fullSizeState
    if (fullSizePx.width <= 0 || fullSizePx.height <= 0) return

    val density = LocalDensity.current
    val targetWidthDp = with(density) { fullSizePx.width.toDp() }
    val targetHeightDp = with(density) { fullSizePx.height.toDp() }
    val targetRadiusPx = with(density) { targetCornerRadiusDp.toPx() }

    Box(modifier.fillMaxSize()) {
        Box(
            Modifier
                .size(targetWidthDp, targetHeightDp)
                .graphicsLayer {
                    val mini = coverBounds.miniRect ?: return@graphicsLayer
                    val full = coverBounds.fullRect ?: return@graphicsLayer
                    if (mini.isEmpty || full.isEmpty || full.width <= 0f || full.height <= 0f) return@graphicsLayer
                    val t = controller.progress
                    val curLeft = lerpFloat(mini.left, full.left, t)
                    val curTop = lerpFloat(mini.top, full.top, t)
                    val curW = lerpFloat(mini.width, full.width, t)
                    val curH = lerpFloat(mini.height, full.height, t)
                    transformOrigin = TransformOrigin(0f, 0f)
                    translationX = curLeft
                    translationY = curTop
                    scaleX = (curW / full.width).coerceAtLeast(0.01f)
                    scaleY = (curH / full.height).coerceAtLeast(0.01f)
                    if (startCircular) {
                        val circleRadius = minOf(size.width, size.height) / 2f
                        shape = RoundedCornerShape(lerpFloat(circleRadius, targetRadiusPx, t))
                        clip = true
                    }
                    compositingStrategy = CompositingStrategy.Offscreen
                },
        ) {
            CoverImage(
                uri = song.coverUri,
                key = song.id,
                size = maxOf(targetWidthDp, targetHeightDp),
                radius = if (startCircular) 0.dp else targetCornerRadiusDp,
            )
        }
    }
}

@Preview(name = "PlayerSheetHost Open", widthDp = 390, heightDp = 844)
@Composable
private fun PlayerSheetHostOpenPreview() = PreviewFrame(dark = true) {
    val controller = remember { PlayerTransitionController.standalone() }
    PlayerSheetHost(controller = controller) {
        Box(Modifier.fillMaxSize().background(Color(0xFF1B1926)), contentAlignment = Alignment.Center) {
            Text("Full Player Open", color = Color.White)
        }
    }
}

@Preview(name = "PlayerSheetHost Half Drag", widthDp = 390, heightDp = 844)
@Composable
private fun PlayerSheetHostHalfPreview() = PreviewFrame(dark = true) {
    val controller = remember {
        PlayerTransitionController(scope = null, reduceMotion = false, standalone = false, initiallyOpen = true).apply {
            dragBy(420f, 844f)
        }
    }
    PlayerSheetHost(controller = controller) {
        Box(Modifier.fillMaxSize().background(Color(0xFF1B1926)), contentAlignment = Alignment.Center) {
            Text("Half Dragged", color = Color.White)
        }
    }
}
