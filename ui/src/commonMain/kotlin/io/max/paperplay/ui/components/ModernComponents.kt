package io.max.paperplay.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.MaterialShapes
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.graphics.shapes.Cubic
import androidx.graphics.shapes.Morph
import androidx.graphics.shapes.RoundedPolygon
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.colorControls
import com.kyant.backdrop.effects.lens
import io.max.paperplay.ui.LocalGlassBackdrop
import io.max.paperplay.ui.app.GlassStyle
import io.max.paperplay.ui.app.LocalUiPrefs
import io.max.paperplay.ui.app.Look
import io.max.paperplay.ui.app.LookGroup
import io.max.paperplay.ui.app.UiStyle
import io.max.paperplay.ui.glassLensSupported
import io.max.paperplay.ui.isPhone
import io.max.paperplay.ui.theme.LocalModernTokens
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.LocalReducedTransparency
import io.max.paperplay.ui.theme.PaperPlayTheme
import io.max.paperplay.ui.theme.motionModernPressSpec
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** True while inside an outer Modern card/bar/overlay; prevents nested glass/surface layers. */
internal val LocalInsideModernSurface = compositionLocalOf { false }

/** Surface depth tiers for Modern UI. [Row] intentionally never uses live backdrop blur. */
enum class ModernSurfaceTier {
    Chrome,
    Card,
    Row,
    Overlay,
}

/**
 * Removes all shadows/elevation in Modern: layers separate strictly by tonal contrast and blur.
 */
internal fun modernSurfaceStatic(fill: Color, shape: Shape): Modifier =
    Modifier.clip(shape).background(fill)

/**
 * Shared horizontal gradient brush for both [ModernMiniPlayer] and [NavBar] so the floating
 * docks always share the exact same cover-tinted fill and alpha.
 */
internal fun modernDockBrush(
    tokens: io.max.paperplay.ui.theme.ModernTokens,
    cover: androidx.compose.material3.ColorScheme?,
): Brush {
    val d = tokens.dock
    val left = if (cover != null) {
        lerp(d.fill, cover.primaryContainer.copy(alpha = d.fill.alpha), d.coverTintWeight)
    } else {
        d.fill
    }
    val right = if (cover != null) {
        lerp(d.fillAlt, cover.tertiaryContainer.copy(alpha = d.fillAlt.alpha), d.coverTintWeight * 0.72f)
    } else {
        d.fillAlt
    }
    return Brush.horizontalGradient(listOf(left, right))
}

/**
 * Applies the borderless, shadowless Modern frosted-glass or stepped tonal surface for [tier] when
 * [LocalModernTokens] is enabled. Separates layers strictly via tonal fills and blur — zero outlines,
 * zero shadows, and zero nested surfaces.
 */
@Composable
fun Modifier.modernSurface(
    tier: ModernSurfaceTier,
    shape: Shape,
    lookGroup: LookGroup = LookGroup.Cards,
    active: Boolean = false,
    selected: Boolean = false,
    accentColor: Color = Color.Unspecified,
    gradientBrush: Brush? = null,
    blurOverride: Dp? = null,
): Modifier {
    val tokens = LocalModernTokens.current
    if (!tokens.enabled || LocalInsideModernSurface.current) return this

    val prefs = LocalUiPrefs.current
    val backdrop = LocalGlassBackdrop.current
    val reduced = LocalReducedTransparency.current

    val baseFill = when (tier) {
        ModernSurfaceTier.Chrome -> tokens.chromeBg
        ModernSurfaceTier.Card -> tokens.cardBg
        ModernSurfaceTier.Row -> when {
            selected -> tokens.rowSelectedBg
            active -> tokens.rowCurrentBg
            else -> tokens.rowBg
        }
        ModernSurfaceTier.Overlay -> tokens.overlayBg
    }
    val fill = if (active && accentColor != Color.Unspecified && tier != ModernSurfaceTier.Row) {
        lerp(baseFill, accentColor.copy(alpha = baseFill.alpha), 0.22f)
    } else {
        baseFill
    }

    // Hard rule: Row never calls drawBackdrop (no live blur in scrolling lists).
    val useLiveBlur = tier != ModernSurfaceTier.Row &&
        tier != ModernSurfaceTier.Overlay &&
        backdrop != null &&
        !reduced &&
        isPhone &&
        prefs?.look(lookGroup) != Look.Material

    if (!useLiveBlur) {
        return this
            .clip(shape)
            .then(if (gradientBrush != null) Modifier.background(gradientBrush) else Modifier.background(fill))
    }

    val g = prefs?.glass ?: GlassStyle()
    val blurDp = blurOverride ?: g.blur.coerceAtLeast(8f).dp
    return this
        .clip(shape)
        .drawBackdrop(
            backdrop = backdrop!!,
            shape = { shape },
            effects = {
                if (g.saturation != 1f) colorControls(saturation = g.saturation)
                blur(blurDp.toPx())
                if (glassLensSupported() && tier == ModernSurfaceTier.Chrome) {
                    lens(g.lensHeight.dp.toPx(), g.lensAmount.dp.toPx(), g.depth, g.chromatic)
                }
            },
            highlight = null,
            shadow = null,
            innerShadow = null,
            onDrawSurface = {
                if (gradientBrush != null) drawRect(gradientBrush) else drawRect(fill)
            },
        )
}

internal const val WAVY_RING_LOBES = 10

/**
 * Single parametric contour shared by BOTH the scalloped play/pause button and the surrounding
 * wavy progress ring (`r(theta) = R + A * cos(N * (theta + pi/2))`), so every lobe peak aligns
 * radially at 12 o'clock and every angle with a visually even gap.
 */
internal fun scallopedPolarRadius(
    baseRadius: Float,
    amplitudePx: Float,
    angleRad: Float,
    lobes: Int = WAVY_RING_LOBES,
): Float = baseRadius + amplitudePx * cos(lobes * (angleRad + (PI / 2.0).toFloat()))

/** Generates `[x0, y0, x1, y1, ...]` vertices along a closed [scallopedPolarRadius] contour. */
internal fun buildScallopedPoints(
    cx: Float,
    cy: Float,
    baseRadius: Float,
    amplitudePx: Float,
    lobes: Int = WAVY_RING_LOBES,
    steps: Int = 180,
): FloatArray {
    val pts = FloatArray(steps * 2)
    val twoPi = (2.0 * PI).toFloat()
    for (i in 0 until steps) {
        val angle = twoPi * i / steps
        val r = scallopedPolarRadius(baseRadius, amplitudePx, angle, lobes)
        pts[i * 2] = cx + r * cos(angle)
        pts[i * 2 + 1] = cy + r * sin(angle)
    }
    return pts
}

private fun FloatArray.toClosedPath(): Path = Path().apply {
    moveTo(this@toClosedPath[0], this@toClosedPath[1])
    var i = 2
    while (i < this@toClosedPath.size) {
        lineTo(this@toClosedPath[i], this@toClosedPath[i + 1])
        i += 2
    }
    close()
}

/**
 * Floating mini-player control: a static scalloped play/pause button centered inside a matching
 * concentric dual-layer circular wavy progress ring (`N = 10` aligned lobes):
 * - Both button and ring share [scallopedPolarRadius] with the same lobe count and phase so the
 *   gap between button and ring is uniform at every angle.
 * - Track layer: static full 360° wavy path in [trackColor].
 * - Active layer: identical static wavy path in [ringColor] (dimmed slightly when paused),
 *   masked by an angular sweep from 12 o'clock to current progress, with rounded start and tip caps.
 * - Zero rotation or phase animation in any state: only the progress sweep advances.
 * - Paths are built once per size via `drawWithCache`; progress is read in draw phase with zero per-frame allocations.
 */
@Composable
fun ModernCircularPlayProgress(
    playing: Boolean,
    progress: () -> Float,
    active: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    covered: Boolean = false,
    size: Dp = 50.dp,
    ringColor: Color = Color.White,
    trackColor: Color = Color.White.copy(alpha = 0.22f),
    buttonContainerColor: Color = Color.White.copy(alpha = 0.22f),
    buttonContentColor: Color = Color.White,
) {
    val reduceMotion = LocalReduceMotion.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (pressed && !reduceMotion) 0.94f else 1f,
        animationSpec = motionModernPressSpec(),
        label = "modernPlayPress",
    )

    val density = LocalDensity.current
    val strokePx = with(density) { 2.6.dp.toPx() }
    val amplitudePx = with(density) { 1.4.dp.toPx() }
    val gapPx = with(density) { 3.0.dp.toPx() }

    // Retain covered/active parameters for call-site compatibility; wave is strictly static in all states.
    @Suppress("UNUSED_EXPRESSION")
    active && !covered

    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        Box(
            Modifier
                .size(size)
                .drawWithCache {
                    val cx = this.size.width / 2f
                    val cy = this.size.height / 2f
                    val ringBaseRadius = (minOf(this.size.width, this.size.height) / 2f) - strokePx / 2f - amplitudePx
                    val buttonBaseRadius = (ringBaseRadius - strokePx / 2f - gapPx).coerceAtLeast(1f)
                    val wavyRingPath = buildScallopedPoints(cx, cy, ringBaseRadius, amplitudePx, WAVY_RING_LOBES, 180).toClosedPath()
                    val buttonPath = buildScallopedPoints(cx, cy, buttonBaseRadius, amplitudePx, WAVY_RING_LOBES, 180).toClosedPath()
                    val wedgePath = Path()
                    val stroke = Stroke(width = strokePx, cap = StrokeCap.Round, join = StrokeJoin.Round)
                    val pad = strokePx * 2f
                    val outerArcRect = Rect(-pad, -pad, this.size.width + pad, this.size.height + pad)
                    val capRadius = strokePx / 2f
                    val twoPi = (2.0 * PI).toFloat()

                    onDrawBehind {
                        // Concentric scalloped button fill (scaled around center on press)
                        if (pressScale != 1f) {
                            withTransform({
                                scale(scaleX = pressScale, scaleY = pressScale, pivot = Offset(cx, cy))
                            }) {
                                drawPath(path = buttonPath, color = buttonContainerColor)
                            }
                        } else {
                            drawPath(path = buttonPath, color = buttonContainerColor)
                        }

                        // 1. Static full 360° wavy track
                        drawPath(path = wavyRingPath, color = trackColor, style = stroke)

                        // 2. Identical static wavy path masked by angular sweep from 12 o'clock (-90°)
                        val p = progress().coerceIn(0f, 1f)
                        val activeCol = if (playing) ringColor else ringColor.copy(alpha = 0.62f)
                        if (p >= 0.999f) {
                            drawPath(path = wavyRingPath, color = activeCol, style = stroke)
                        } else if (p > 0.001f) {
                            val sweepDeg = 360f * p
                            wedgePath.reset()
                            wedgePath.moveTo(cx, cy)
                            wedgePath.arcTo(outerArcRect, startAngleDegrees = -90f, sweepAngleDegrees = sweepDeg, forceMoveTo = false)
                            wedgePath.close()

                            clipPath(wedgePath) {
                                drawPath(path = wavyRingPath, color = activeCol, style = stroke)
                            }

                            // Rounded caps at 12 o'clock start and progress tip on the exact scalloped contour
                            val startAngle = (-PI / 2.0).toFloat()
                            val endAngle = startAngle + twoPi * p
                            val rStart = scallopedPolarRadius(ringBaseRadius, amplitudePx, startAngle, WAVY_RING_LOBES)
                            val rEnd = scallopedPolarRadius(ringBaseRadius, amplitudePx, endAngle, WAVY_RING_LOBES)
                            drawCircle(
                                color = activeCol,
                                radius = capRadius,
                                center = Offset(cx + rStart * cos(startAngle), cy + rStart * sin(startAngle)),
                            )
                            drawCircle(
                                color = activeCol,
                                radius = capRadius,
                                center = Offset(cx + rEnd * cos(endAngle), cy + rEnd * sin(endAngle)),
                            )
                        }
                    }
                }
                .semantics { this.contentDescription = if (playing) "Pause" else "Play" }
                .clickable(
                    interactionSource = interaction,
                    indication = null,
                    role = Role.Button,
                    onClick = onClick,
                ),
            contentAlignment = Alignment.Center,
        ) {
            AppIcon(
                imageVector = if (playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                contentDescription = null,
                modifier = Modifier.size(size * 0.40f).graphicsLayer { scaleX = pressScale; scaleY = pressScale },
                tint = buttonContentColor,
            )
        }
    }
}

/** Small static scalloped play badge for Modern Daily Mix cards (allocates Path lazily in DrawScope). */
@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun ModernScallopedBadge(
    modifier: Modifier = Modifier,
    size: Dp = 32.dp,
    containerColor: Color = Color.White.copy(alpha = 0.90f),
    contentColor: Color = Color(0xFF141418),
    polygon: RoundedPolygon = MaterialShapes.Cookie9Sided,
) {
    val morph = remember(polygon) { Morph(polygon, polygon) }
    Box(modifier.size(size), contentAlignment = Alignment.Center) {
        Box(
            Modifier.matchParentSize().drawWithCache {
                val path = Path()
                val matrix = Matrix().apply { scale(this@drawWithCache.size.width, this@drawWithCache.size.height) }
                morph.forEachCubic(0f) { c: Cubic ->
                    if (path.isEmpty) path.moveTo(c.anchor0X, c.anchor0Y)
                    path.cubicTo(c.control0X, c.control0Y, c.control1X, c.control1Y, c.anchor1X, c.anchor1Y)
                }
                path.close()
                path.transform(matrix)
                onDrawBehind {
                    drawPath(path = path, color = containerColor)
                }
            },
        )
        AppIcon(Icons.Rounded.PlayArrow, null, Modifier.size(size * 0.56f), tint = contentColor)
    }
}

@Preview(name = "Wavy Ring Progress Sweep", showBackground = true)
@Composable
private fun ModernCircularPlayProgressSweepPreview() {
    PaperPlayTheme(dark = true, amoled = false, uiStyle = UiStyle.Modern) {
        Row(
            Modifier.background(Color(0xFF14141A)).padding(12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            listOf(0f, 0.05f, 0.25f, 0.50f, 0.90f).forEach { p ->
                ModernCircularPlayProgress(playing = true, progress = { p }, active = true, onClick = {})
            }
            ModernCircularPlayProgress(playing = false, progress = { 0.50f }, active = false, onClick = {})
        }
    }
}
