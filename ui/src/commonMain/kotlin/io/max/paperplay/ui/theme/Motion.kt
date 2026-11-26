package io.max.paperplay.ui.theme

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.FiniteAnimationSpec
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.grid.LazyGridItemScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.animation.expandHorizontally
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkHorizontally
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf

/** Timings and curves shared by every transition, so the app moves with one rhythm. */
object Motion {
    const val FAST = 150
    const val STANDARD = 300
    const val EMPHASIZED = 450

    val Standard: Easing = FastOutSlowInEasing

    /** A quick start and a long, soft landing, for things that arrive on screen. */
    val Emphasized: Easing = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)

    /** Spatial movement tokens: critically damped springs (no overshoot) and navigation timings. */
    object Spatial {
        const val EnterStiffness = 500f
        const val ExitStiffness = 720f
        const val SettleStiffness = 620f
        const val MoveStiffness = 520f
        const val DampingNoBounce = Spring.DampingRatioNoBouncy
        const val PageEnterMs = 300
        const val PageExitMs = 260
        const val TabSwitchMs = 220
        const val TabDelayMs = 80
        const val DialogMs = 200
        const val ExpandMs = 260
        const val StaggerStepMs = 55L
        const val StaggerEnterMs = 360
    }

    /** Non-spatial effect tokens: alpha fades, color shifts, and cover washes. */
    object Effects {
        const val FadeFastMs = 120
        const val FadeStandardMs = 180
        const val ColorMs = 220
        const val WashMs = 600
        const val CoverCrossfadeMs = 300
        const val ReducedFadeMs = 120
        const val LyricsFocusMs = 260
    }

    /** Micro-interaction tokens: press feedback (intentional gentle bounce), toggles, and nav pill. */
    object Micro {
        const val PressScale = 0.94f
        const val CardPressScale = 0.98f
        /** Intentional subtle bounce on press-release feedback for tactile buttons. */
        const val PressDamping = 0.65f
        const val PressStiffness = 650f
        const val ToggleMs = 160
        const val PillDamping = 0.85f
        const val PillStiffness = 480f
        const val PlayMorphMs = 240
        /** Intentional playful pop on onboarding hero badges. */
        const val PopDamping = 0.55f
        const val PopStiffness = 380f
        const val IconTurnMs = 320
        const val IconTurnDelayMs = 100
    }

    /** Ambient loop periods and redraw cap. */
    object Ambient {
        const val FrameIntervalNanos = 33_000_000L
        const val ShimmerPeriodMs = 1300
        const val BitPerfectPeriodMs = 2400
        const val CallPulsePeriodMs = 700
        const val LogoLoopMs = 7000
        const val HeroCornerPeriodMs = 2600
        const val HeroWigglePeriodMs = 1900
        const val OnboardingDriftMs = 9000
        const val OnboardingRiseMs = 60_000
        const val PlainLyricsDriftMs = 900
        const val StandbyHintMs = 1200
    }

    /** Modern expressive shape-morph and press-feedback tokens (low bounce; navigation/player stay untouched). */
    object Modern {
        const val MorphDamping = 0.86f
        const val MorphStiffness = 560f
        const val PressScale = 0.95f
        const val PressDamping = 0.85f
        const val PressStiffness = 620f
        const val ColorMs = 180
    }

    /** Desktop-specific interaction, wheel, scrollbar, and subtle card-navigation tokens. */
    object Desktop {
        const val HoverMs = 110
        const val PressMs = 70
        const val PressScale = 0.985f
        const val FocusMs = 120
        const val TooltipShowDelayMs = 450L
        const val TooltipHideDelayMs = 80L
        const val TooltipFadeMs = 120
        const val TooltipShiftDp = 4f
        const val PageEnterMs = 180
        const val PageExitMs = 130
        const val PageShiftDp = 16f
        const val PageSideShiftDp = 8f
        const val SidebarStiffness = 560f
        const val PanelStiffness = 560f
        const val PanelFadeMs = 150
        const val WheelStepDp = 84f
        const val WheelDecayTauSec = 0.085f
        const val WheelMaxAccumulatedDp = 1200f
        const val WheelSettleThresholdPx = 0.5f
        const val ScrollbarIdleDelayMs = 950L
        const val ScrollbarFadeInMs = 110
        const val ScrollbarFadeOutMs = 280
        const val ScrollbarRestWidthDp = 5f
        const val ScrollbarHoverWidthDp = 8f
        const val PaneSwitchMs = 180
        const val PaneShiftDp = 14f
        const val MiniEnterMs = 180
        const val MiniExitMs = 130
        const val MiniResizeStiffness = 520f
        const val DropOverlayFadeMs = 140
    }
}

/** Live-tunable motion multipliers used by the debug Motion Lab screen. */
@Immutable
data class MotionTuning(
    val durationScale: Float = 1f,
    val spatialStiffnessScale: Float = 1f,
    val pressScale: Float = Motion.Micro.PressScale,
    val ambientFps: Int = 30,
) {
    fun scaledMs(baseMs: Int): Int =
        (baseMs * durationScale.coerceIn(0.25f, 2.5f)).toInt().coerceAtLeast(1)

    fun scaledStiffness(baseStiffness: Float): Float =
        (baseStiffness * spatialStiffnessScale.coerceIn(0.4f, 2.5f)).coerceAtLeast(50f)
}

internal object MotionTuningState {
    var current by mutableStateOf(MotionTuning())
    fun reset() {
        current = MotionTuning()
    }
}

val LocalMotionTuning = staticCompositionLocalOf { MotionTuning() }

/**
 * Named motion, gesture, staging, and visual-curve tokens for the full-player sheet transition.
 * Kept in one place so every layer, spring, and threshold shares one source of truth.
 */
object PlayerMotionTokens {
    // Spatial springs: critically damped (dampingRatio = 1f) so the sheet never overshoots.
    const val SHEET_OPEN_DAMPING = Spring.DampingRatioNoBouncy
    const val SHEET_OPEN_STIFFNESS = 500f
    const val SHEET_CLOSE_DAMPING = Spring.DampingRatioNoBouncy
    const val SHEET_CLOSE_STIFFNESS = 720f
    const val SHEET_SETTLE_DAMPING = Spring.DampingRatioNoBouncy
    const val SHEET_SETTLE_STIFFNESS = 620f
    const val SHEET_VISIBILITY_THRESHOLD = 0.001f

    // Effect and reduced-motion timings (faster than spatial movement).
    const val EFFECT_FADE_MS = 150
    const val REDUCED_MOTION_FADE_MS = 120

    // Gesture & rubber-band thresholds.
    const val DISMISS_DISTANCE_FRACTION = 0.35f
    const val DISMISS_VELOCITY_PX_PER_SEC = 1_200f
    const val OPEN_VELOCITY_PX_PER_SEC = -1_200f
    const val RUBBER_BAND_MAX = 0.055f
    const val RUBBER_BAND_DAMPING = 0.18f
    const val BACK_GESTURE_MAX_PULL = 0.30f

    // Derived layer curves & hysteresis.
    const val BACKDROP_MAX_DIM_ALPHA = 0.38f
    const val BACKDROP_MIN_SCALE = 0.96f
    const val MINI_PLAYER_FADE_END = 0.35f
    const val MINI_PLAYER_MAX_SHIFT_DP = 24f
    const val NAV_BAR_FADE_END = 0.40f
    const val NAV_BAR_SLIDE_END = 0.55f
    const val SHEET_CORNER_RADIUS_DP = 28f
    const val SHEET_CORNER_CLIP_END = 0.995f
    const val COVERED_ENTER = 0.999f
    const val COVERED_EXIT = 0.98f
    const val SYSTEM_BARS_ENTER = 0.55f
    const val SYSTEM_BARS_EXIT = 0.45f
    const val STAGE1_ENTER_PROGRESS = 0.40f
    const val OVERLAY_UNDER_SCALE = 0.96f
    const val OVERLAY_UNDER_DIM = 0.25f
}

internal fun playerOpenSpringSpec(): FiniteAnimationSpec<Float> = spring(
    dampingRatio = PlayerMotionTokens.SHEET_OPEN_DAMPING,
    stiffness = PlayerMotionTokens.SHEET_OPEN_STIFFNESS,
    visibilityThreshold = PlayerMotionTokens.SHEET_VISIBILITY_THRESHOLD,
)

internal fun playerCloseSpringSpec(): FiniteAnimationSpec<Float> = spring(
    dampingRatio = PlayerMotionTokens.SHEET_CLOSE_DAMPING,
    stiffness = PlayerMotionTokens.SHEET_CLOSE_STIFFNESS,
    visibilityThreshold = PlayerMotionTokens.SHEET_VISIBILITY_THRESHOLD,
)

internal fun playerSettleSpringSpec(): FiniteAnimationSpec<Float> = spring(
    dampingRatio = PlayerMotionTokens.SHEET_SETTLE_DAMPING,
    stiffness = PlayerMotionTokens.SHEET_SETTLE_STIFFNESS,
    visibilityThreshold = PlayerMotionTokens.SHEET_VISIBILITY_THRESHOLD,
)

internal fun playerReducedFadeSpec(): FiniteAnimationSpec<Float> = tween(
    durationMillis = PlayerMotionTokens.REDUCED_MOTION_FADE_MS,
    easing = Motion.Standard,
)

internal fun playerEffectFadeSpec(): FiniteAnimationSpec<Float> = tween(
    durationMillis = PlayerMotionTokens.EFFECT_FADE_MS,
    easing = Motion.Standard,
)

/** True when the user turned motion off in Settings: every transition built from these helpers becomes instant. */
val LocalReduceMotion = staticCompositionLocalOf { false }

@Composable
fun <T> motionTween(durationMs: Int = Motion.STANDARD, easing: Easing = Motion.Standard): FiniteAnimationSpec<T> {
    if (LocalReduceMotion.current) return snap()
    val tuning = LocalMotionTuning.current
    return tween(tuning.scaledMs(durationMs), easing = easing)
}

/** Critically damped spatial spring (no overshoot by default), honoring Reduce Motion and Motion Lab tuning. */
@Composable
fun <T> motionSpatialSpring(
    stiffness: Float = Motion.Spatial.MoveStiffness,
    dampingRatio: Float = Motion.Spatial.DampingNoBounce,
    visibilityThreshold: T? = null,
): FiniteAnimationSpec<T> {
    if (LocalReduceMotion.current) return snap()
    val tuning = LocalMotionTuning.current
    return spring(
        dampingRatio = dampingRatio,
        stiffness = tuning.scaledStiffness(stiffness),
        visibilityThreshold = visibilityThreshold,
    )
}

/** Non-overshooting effect tween (alpha, scale, color) honoring Reduce Motion and Motion Lab tuning. */
@Composable
fun <T> motionEffectTween(
    durationMs: Int = Motion.Effects.FadeStandardMs,
    delayMillis: Int = 0,
    easing: Easing = Motion.Standard,
): FiniteAnimationSpec<T> {
    if (LocalReduceMotion.current) return snap()
    val tuning = LocalMotionTuning.current
    return tween(tuning.scaledMs(durationMs), delayMillis = tuning.scaledMs(delayMillis).takeIf { delayMillis > 0 } ?: 0, easing = easing)
}

/** Linear-easing tween (e.g., plain lyrics drift or progress bar glide). */
@Composable
fun <T> motionLinearTween(durationMs: Int): FiniteAnimationSpec<T> {
    if (LocalReduceMotion.current) return snap()
    val tuning = LocalMotionTuning.current
    return tween(tuning.scaledMs(durationMs), easing = LinearEasing)
}

@Composable
fun motionColorSpec(): FiniteAnimationSpec<Color> = motionEffectTween(Motion.Effects.ColorMs)

@Composable
fun motionWashSpec(): FiniteAnimationSpec<Color> = motionEffectTween(Motion.Effects.WashMs)

@Composable
fun <T> motionCrossfadeSpec(): FiniteAnimationSpec<T> = motionEffectTween(Motion.Effects.CoverCrossfadeMs)

@Composable
fun <T> motionPlayMorphSpec(): FiniteAnimationSpec<T> = motionEffectTween(Motion.Micro.PlayMorphMs, easing = Motion.Emphasized)

@Composable
fun <T> motionPillSpring(): FiniteAnimationSpec<T> =
    if (LocalReduceMotion.current) snap()
    else spring(dampingRatio = Motion.Micro.PillDamping, stiffness = LocalMotionTuning.current.scaledStiffness(Motion.Micro.PillStiffness))

@Composable
fun <T> motionPressSpring(): FiniteAnimationSpec<T> =
    if (LocalReduceMotion.current) snap()
    else spring(dampingRatio = Motion.Micro.PressDamping, stiffness = LocalMotionTuning.current.scaledStiffness(Motion.Micro.PressStiffness))

@Composable
fun <T> motionPopSpring(): FiniteAnimationSpec<T> =
    if (LocalReduceMotion.current) snap()
    else spring(dampingRatio = Motion.Micro.PopDamping, stiffness = LocalMotionTuning.current.scaledStiffness(Motion.Micro.PopStiffness))

@Composable
fun <T> motionReducedFade(): FiniteAnimationSpec<T> = tween(Motion.Effects.ReducedFadeMs, easing = Motion.Standard)

@Composable
fun <T> desktopHoverSpec(): FiniteAnimationSpec<T> = motionEffectTween(Motion.Desktop.HoverMs, easing = Motion.Standard)

@Composable
fun <T> desktopPressSpec(): FiniteAnimationSpec<T> = motionEffectTween(Motion.Desktop.PressMs, easing = Motion.Standard)

@Composable
fun <T> desktopFocusSpec(): FiniteAnimationSpec<T> = motionEffectTween(Motion.Desktop.FocusMs, easing = Motion.Standard)

@Composable
fun desktopScrollbarFadeInSpec(): FiniteAnimationSpec<Float> = motionEffectTween(Motion.Desktop.ScrollbarFadeInMs, easing = Motion.Standard)

@Composable
fun desktopScrollbarFadeOutSpec(): FiniteAnimationSpec<Float> = motionEffectTween(Motion.Desktop.ScrollbarFadeOutMs, easing = Motion.Standard)

fun <T> desktopPageEnterSpec(reduced: Boolean): FiniteAnimationSpec<T> =
    if (reduced) snap() else tween(Motion.Desktop.PageEnterMs, easing = Motion.Emphasized)

fun <T> desktopPageExitSpec(reduced: Boolean): FiniteAnimationSpec<T> =
    if (reduced) snap() else tween(Motion.Desktop.PageExitMs, easing = Motion.Standard)

fun <T> desktopPaneEnterSpec(reduced: Boolean): FiniteAnimationSpec<T> =
    if (reduced) snap() else tween(Motion.Desktop.PaneSwitchMs, easing = Motion.Emphasized)

fun <T> desktopPaneExitSpec(reduced: Boolean): FiniteAnimationSpec<T> =
    if (reduced) snap() else tween(Motion.Desktop.PageExitMs, easing = Motion.Standard)

@Composable
fun <T> desktopMiniResizeSpring(reduced: Boolean = LocalReduceMotion.current): FiniteAnimationSpec<T> =
    if (reduced) snap()
    else spring(
        dampingRatio = Motion.Spatial.DampingNoBounce,
        stiffness = LocalMotionTuning.current.scaledStiffness(Motion.Desktop.MiniResizeStiffness),
    )

/** Layer-phase tactile press feedback (scales down on press and springs back on release). */
@Composable
fun Modifier.pressScale(
    source: MutableInteractionSource,
    pressedScale: Float = LocalMotionTuning.current.pressScale,
): Modifier {
    val pressed by source.collectIsPressedAsState()
    val reduced = LocalReduceMotion.current
    val scale by animateFloatAsState(
        targetValue = if (pressed && !reduced) pressedScale else 1f,
        animationSpec = motionPressSpring(),
        label = "pressScale",
    )
    return graphicsLayer {
        scaleX = scale
        scaleY = scale
    }
}

/** Layer-phase visibility fade using [Motion.Effects.FadeFastMs]. */
@Composable
fun Modifier.motionFade(visible: Boolean): Modifier {
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = motionEffectTween(Motion.Effects.FadeFastMs),
        label = "motionFade",
    )
    return graphicsLayer { this.alpha = alpha }
}

/** A lightly bouncy spring for things that settle, such as the nav bar pill. */
@Composable
fun <T> motionSpring(): FiniteAnimationSpec<T> =
    if (LocalReduceMotion.current) snap() else spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMedium)

/** For items of a lazy list with stable keys: they glide to a new place and fade in and out. Nothing when motion is reduced. */
@Composable
fun LazyItemScope.motionItem(): Modifier = if (LocalReduceMotion.current) Modifier else Modifier.animateItem()

/**
 * A fixed width that glides to [target] when it changes, such as a sidebar opening and closing. The glide is read in the
 * layout phase, so the composable that sets it does not recompose while it runs. Uses a critically damped spatial spring
 * so rapid toggles or continuous window resizes remain interruptible and never overshoot.
 */
@Composable
fun Modifier.animatedWidth(target: Dp): Modifier {
    val width = remember { Animatable(target.value) }
    val spec = motionSpatialSpring<Float>(Motion.Desktop.SidebarStiffness)
    LaunchedEffect(target) { width.animateTo(target.value, spec) }
    return layout { measurable, constraints ->
        val w = width.value.dp.roundToPx().coerceIn(constraints.minWidth, constraints.maxWidth)
        val placeable = measurable.measure(constraints.copy(minWidth = w, maxWidth = w))
        layout(placeable.width, placeable.height) { placeable.place(0, 0) }
    }
}

/** A side panel opening from the right edge. */
@Composable
fun panelEnter(): EnterTransition =
    if (LocalReduceMotion.current) fadeIn(motionReducedFade())
    else expandHorizontally(
        motionSpatialSpring(Motion.Desktop.PanelStiffness),
        expandFrom = Alignment.End,
    ) + fadeIn(motionEffectTween(Motion.Desktop.PanelFadeMs))

/** A side panel closing towards the right edge. */
@Composable
fun panelExit(): ExitTransition =
    if (LocalReduceMotion.current) fadeOut(motionReducedFade())
    else shrinkHorizontally(
        motionSpatialSpring(Motion.Desktop.PanelStiffness),
        shrinkTowards = Alignment.End,
    ) + fadeOut(motionEffectTween(Motion.Effects.FadeFastMs))

/** The same for the items of a lazy grid. */
@Composable
fun LazyGridItemScope.motionItem(): Modifier = if (LocalReduceMotion.current) Modifier else Modifier.animateItem()

/** Low-bounce expressive spring for Modern shape morphs (play/pause, selection badges, toggle corners). */
@Composable
fun <T> motionMorphSpec(): FiniteAnimationSpec<T> =
    if (LocalReduceMotion.current) snap()
    else spring(
        dampingRatio = Motion.Modern.MorphDamping,
        stiffness = LocalMotionTuning.current.scaledStiffness(Motion.Modern.MorphStiffness),
    )

/** Low-bounce expressive spring for Modern press-scale feedback. */
@Composable
fun motionModernPressSpec(): FiniteAnimationSpec<Float> =
    if (LocalReduceMotion.current) snap()
    else spring(
        dampingRatio = Motion.Modern.PressDamping,
        stiffness = LocalMotionTuning.current.scaledStiffness(Motion.Modern.PressStiffness),
    )

/** Smooth color/rim transition for Modern glass states. */
@Composable
fun <T> motionModernColorSpec(): FiniteAnimationSpec<T> =
    motionEffectTween(Motion.Modern.ColorMs)
