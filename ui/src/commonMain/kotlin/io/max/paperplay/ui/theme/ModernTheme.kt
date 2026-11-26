package io.max.paperplay.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.max.paperplay.ui.app.UiStyle
import kotlin.math.max
import kotlin.math.min

/**
 * Shared floating dock tokens for both [ModernMiniPlayer] and [NavBar] so they read as one
 * matched pair of floating glass pills (identical fill, tint, blur, corner radius, margins, and ink).
 */
@Immutable
data class ModernDockTokens(
    val fill: Color,
    val fillAlt: Color,
    val coverTintWeight: Float,
    val blurDp: Dp,
    val cornerRadius: Dp,
    val sideMargin: Dp,
    val dockGap: Dp,
    val contentColor: Color,
    val contentMutedColor: Color,
    val selectedPillBg: Color,
    val selectedContentColor: Color,
) {
    companion object {
        val Disabled = ModernDockTokens(
            fill = Color.Unspecified,
            fillAlt = Color.Unspecified,
            coverTintWeight = 0f,
            blurDp = 0.dp,
            cornerRadius = 0.dp,
            sideMargin = 0.dp,
            dockGap = 0.dp,
            contentColor = Color.Unspecified,
            contentMutedColor = Color.Unspecified,
            selectedPillBg = Color.Unspecified,
            selectedContentColor = Color.Unspecified,
        )
    }
}

/**
 * Design tokens for the optional Android-only Modern (Material 3 Expressive + borderless frosted glass) style.
 * Surfaces separate exclusively via stepped tonal fills and blur on chrome — zero outlines and zero shadows.
 * [enabled] is false for `UiStyle.Default` and all desktop sessions, leaving Default untouched.
 */
@Immutable
data class ModernTokens(
    val enabled: Boolean,
    val dark: Boolean,
    val amoled: Boolean,
    val reducedTransparency: Boolean,
    val chromeBg: Color,
    val chromeBgAlt: Color,
    val cardBg: Color,
    val cardBgElevated: Color,
    val rowBg: Color,
    val rowCurrentBg: Color,
    val rowSelectedBg: Color,
    val overlayBg: Color,
    val chipBg: Color,
    val chipSelectedBg: Color,
    val pillSelectedBg: Color,
    val fieldBg: Color,
    val scrimTop: Color,
    val scrimMid: Color,
    val scrimBottom: Color,
    val onGlass: Color,
    val onGlassMuted: Color,
    val accentOnGlass: Color,
    val dock: ModernDockTokens = ModernDockTokens.Disabled,
    val gutter: Dp = 16.dp,
    val sectionGap: Dp = 20.dp,
    val cardPadding: Dp = 16.dp,
    val groupGap: Dp = 3.dp,
) {
    companion object {
        val Disabled = ModernTokens(
            enabled = false,
            dark = true,
            amoled = false,
            reducedTransparency = false,
            chromeBg = Color.Unspecified,
            chromeBgAlt = Color.Unspecified,
            cardBg = Color.Unspecified,
            cardBgElevated = Color.Unspecified,
            rowBg = Color.Unspecified,
            rowCurrentBg = Color.Unspecified,
            rowSelectedBg = Color.Unspecified,
            overlayBg = Color.Unspecified,
            chipBg = Color.Unspecified,
            chipSelectedBg = Color.Unspecified,
            pillSelectedBg = Color.Unspecified,
            fieldBg = Color.Unspecified,
            scrimTop = Color.Unspecified,
            scrimMid = Color.Unspecified,
            scrimBottom = Color.Unspecified,
            onGlass = Color.Unspecified,
            onGlassMuted = Color.Unspecified,
            accentOnGlass = Color.Unspecified,
            dock = ModernDockTokens.Disabled,
        )
    }
}

val LocalModernTokens = staticCompositionLocalOf { ModernTokens.Disabled }
val LocalUiStyle = staticCompositionLocalOf { UiStyle.Default }

/** WCAG 2.1 contrast ratio between [foreground] and [background] (1.0 .. 21.0). */
internal fun contrastRatio(foreground: Color, background: Color): Double {
    val fg = if (foreground.alpha < 1f) foreground.compositeOver(background) else foreground
    val l1 = fg.luminance().toDouble()
    val l2 = background.luminance().toDouble()
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
}

internal fun ensureContrast(candidate: Color, over: Color, minRatio: Double, darkTarget: Boolean): Color {
    if (contrastRatio(candidate, over) >= minRatio) return candidate
    val target = if (darkTarget) Color(0xFF0A0A0C) else Color(0xFFFDFDFE)
    var lo = 0f
    var hi = 1f
    var best = candidate
    repeat(12) {
        val mid = (lo + hi) / 2f
        val mixed = lerp(candidate, target, mid)
        if (contrastRatio(mixed, over) >= minRatio) {
            best = mixed
            hi = mid
        } else {
            lo = mid
        }
    }
    return best
}

/**
 * Pure token resolver for Dark, Frosted-Light, True Black (AMOLED), and Reduced Transparency modes.
 * Uses stepped tonal fills so layers remain distinct without any outlines or hairline borders,
 * while guaranteeing WCAG AA >= 4.5:1 text legibility and >= 3.0:1 accent contrast.
 */
internal fun resolveModernTokens(
    enabled: Boolean,
    scheme: ColorScheme,
    dark: Boolean,
    amoled: Boolean,
    reducedTransparency: Boolean,
): ModernTokens {
    if (!enabled) return ModernTokens.Disabled

    if (dark) {
        val baseDark = if (amoled) Color.Black else lerp(scheme.surfaceContainerLowest, Color.Black, 0.58f)
        val chromeAlpha = if (reducedTransparency) 0.95f else if (amoled) 0.88f else 0.76f
        val cardAlpha = if (reducedTransparency) 0.94f else if (amoled) 0.86f else 0.68f
        val rowAlpha = if (reducedTransparency) 0.90f else if (amoled) 0.82f else 0.48f
        val overlayAlpha = if (reducedTransparency) 0.97f else if (amoled) 0.95f else 0.92f

        // Stepped tonal neutrals so Dark, True Black, and Reduced Transparency stay clearly separated without outlines or shadows.
        val rowTone = if (amoled) Color(0xFF15151C) else lerp(scheme.surfaceContainer, Color.White, 0.03f)
        val cardTone = if (amoled) Color(0xFF20202A) else lerp(scheme.surfaceContainerHigh, Color.White, 0.06f)
        val elevatedTone = if (amoled) Color(0xFF2A2A36) else lerp(scheme.surfaceContainerHighest, Color.White, 0.10f)
        val chromeTone = if (amoled) Color(0xFF242430) else lerp(scheme.surfaceContainerHigh, Color.White, 0.07f)
        val overlayTone = if (amoled) Color(0xFF2E2E3B) else lerp(scheme.surfaceContainerHighest, Color.White, 0.10f)

        val chromeBg = chromeTone.copy(alpha = chromeAlpha)
        val chromeBgAlt = lerp(chromeTone, scheme.primaryContainer, 0.24f).copy(alpha = chromeAlpha)
        val cardBg = cardTone.copy(alpha = cardAlpha)
        val cardBgElevated = elevatedTone.copy(alpha = if (reducedTransparency) 0.96f else if (amoled) 0.90f else 0.82f)
        val rowBg = rowTone.copy(alpha = rowAlpha)
        val rowCurrentBg = lerp(scheme.primaryContainer, cardTone, 0.36f).copy(alpha = if (reducedTransparency) 0.94f else 0.72f)
        val rowSelectedBg = lerp(scheme.primaryContainer, cardTone, 0.20f).copy(alpha = if (reducedTransparency) 0.96f else 0.84f)
        val overlayBg = overlayTone.copy(alpha = overlayAlpha)
        val chipBg = elevatedTone.copy(alpha = if (reducedTransparency) 0.94f else 0.72f)
        val chipSelectedBg = lerp(scheme.secondaryContainer, elevatedTone, 0.16f).copy(alpha = if (reducedTransparency) 0.96f else 0.90f)
        val pillSelectedBg = lerp(scheme.primaryContainer, elevatedTone, 0.22f).copy(alpha = if (reducedTransparency) 0.96f else 0.88f)
        val fieldBg = elevatedTone.copy(alpha = if (reducedTransparency) 0.95f else 0.76f)

        val compositedCard = cardBg.compositeOver(baseDark)
        val compositedChrome = chromeBg.compositeOver(baseDark)
        val onGlass = ensureContrast(Color.White.copy(alpha = 0.96f), compositedCard, 4.5, darkTarget = false)
        val onGlassMuted = ensureContrast(Color(0xFFD0D4DE), compositedCard, 4.5, darkTarget = false)
        val accentOnGlass = ensureContrast(scheme.primary, compositedCard, 3.0, darkTarget = false)
        val dockSelectedContent = ensureContrast(scheme.onPrimaryContainer, pillSelectedBg.compositeOver(compositedChrome), 4.5, darkTarget = false)

        return ModernTokens(
            enabled = true,
            dark = true,
            amoled = amoled,
            reducedTransparency = reducedTransparency,
            chromeBg = chromeBg,
            chromeBgAlt = chromeBgAlt,
            cardBg = cardBg,
            cardBgElevated = cardBgElevated,
            rowBg = rowBg,
            rowCurrentBg = rowCurrentBg,
            rowSelectedBg = rowSelectedBg,
            overlayBg = overlayBg,
            chipBg = chipBg,
            chipSelectedBg = chipSelectedBg,
            pillSelectedBg = pillSelectedBg,
            fieldBg = fieldBg,
            scrimTop = if (amoled) Color.Black.copy(alpha = 0.72f) else Color.Black.copy(alpha = 0.50f),
            scrimMid = if (amoled) Color.Black.copy(alpha = 0.88f) else Color.Black.copy(alpha = 0.42f),
            scrimBottom = if (amoled) Color.Black else Color.Black.copy(alpha = 0.82f),
            onGlass = onGlass,
            onGlassMuted = onGlassMuted,
            accentOnGlass = accentOnGlass,
            dock = ModernDockTokens(
                fill = chromeBg,
                fillAlt = chromeBgAlt,
                coverTintWeight = 0.34f,
                blurDp = 16.dp,
                cornerRadius = 34.dp,
                sideMargin = 14.dp,
                dockGap = 8.dp,
                contentColor = onGlass,
                contentMutedColor = onGlassMuted,
                selectedPillBg = pillSelectedBg,
                selectedContentColor = dockSelectedContent,
            ),
        )
    }

    // Frosted-Light Modern: soft translucent stepped white/surface fills (not inverted dark, zero borders, zero shadows).
    val frostBase = lerp(Color.White, scheme.surfaceContainer, 0.34f)
    val chromeAlpha = if (reducedTransparency) 0.96f else 0.84f
    val cardAlpha = if (reducedTransparency) 0.94f else 0.78f
    val rowAlpha = if (reducedTransparency) 0.92f else 0.70f
    val overlayAlpha = if (reducedTransparency) 0.98f else 0.94f

    val chromeBg = frostBase.copy(alpha = chromeAlpha)
    val chromeBgAlt = lerp(frostBase, scheme.primaryContainer, 0.22f).copy(alpha = chromeAlpha)
    val cardBg = frostBase.copy(alpha = cardAlpha)
    val cardBgElevated = Color.White.copy(alpha = if (reducedTransparency) 0.99f else 0.95f)
    val rowBg = lerp(frostBase, scheme.surfaceContainerLow, 0.25f).copy(alpha = rowAlpha)
    val rowCurrentBg = lerp(scheme.primaryContainer, Color.White, 0.20f).copy(alpha = if (reducedTransparency) 0.95f else 0.84f)
    val rowSelectedBg = lerp(scheme.primaryContainer, Color.White, 0.10f).copy(alpha = if (reducedTransparency) 0.97f else 0.92f)
    val overlayBg = Color.White.copy(alpha = overlayAlpha)
    val chipBg = lerp(scheme.surfaceContainerHigh, Color.White, 0.35f).copy(alpha = if (reducedTransparency) 0.95f else 0.82f)
    val chipSelectedBg = lerp(scheme.secondaryContainer, Color.White, 0.10f).copy(alpha = if (reducedTransparency) 0.97f else 0.92f)
    val pillSelectedBg = lerp(scheme.primaryContainer, Color.White, 0.12f).copy(alpha = if (reducedTransparency) 0.97f else 0.90f)
    val fieldBg = lerp(scheme.surfaceContainerHigh, Color.White, 0.30f).copy(alpha = if (reducedTransparency) 0.95f else 0.84f)

    val lightBackdropSample = lerp(scheme.surface, scheme.primaryContainer, 0.18f)
    val compositedCard = cardBg.compositeOver(lightBackdropSample)
    val compositedChrome = chromeBg.compositeOver(lightBackdropSample)
    val onGlass = ensureContrast(scheme.onSurface, compositedCard, 4.5, darkTarget = true)
    val onGlassMuted = ensureContrast(scheme.onSurfaceVariant, compositedCard, 4.5, darkTarget = true)
    val accentOnGlass = ensureContrast(scheme.primary, compositedCard, 3.0, darkTarget = true)
    val dockSelectedContent = ensureContrast(scheme.onPrimaryContainer, pillSelectedBg.compositeOver(compositedChrome), 4.5, darkTarget = true)

    return ModernTokens(
        enabled = true,
        dark = false,
        amoled = false,
        reducedTransparency = reducedTransparency,
        chromeBg = chromeBg,
        chromeBgAlt = chromeBgAlt,
        cardBg = cardBg,
        cardBgElevated = cardBgElevated,
        rowBg = rowBg,
        rowCurrentBg = rowCurrentBg,
        rowSelectedBg = rowSelectedBg,
        overlayBg = overlayBg,
        chipBg = chipBg,
        chipSelectedBg = chipSelectedBg,
        pillSelectedBg = pillSelectedBg,
        fieldBg = fieldBg,
        scrimTop = Color.White.copy(alpha = 0.48f),
        scrimMid = Color.White.copy(alpha = 0.42f),
        scrimBottom = Color.White.copy(alpha = 0.68f),
        onGlass = onGlass,
        onGlassMuted = onGlassMuted,
        accentOnGlass = accentOnGlass,
        dock = ModernDockTokens(
            fill = chromeBg,
            fillAlt = chromeBgAlt,
            coverTintWeight = 0.22f,
            blurDp = 16.dp,
            cornerRadius = 34.dp,
            sideMargin = 14.dp,
            dockGap = 8.dp,
            contentColor = onGlass,
            contentMutedColor = onGlassMuted,
            selectedPillBg = pillSelectedBg,
            selectedContentColor = dockSelectedContent,
        ),
    )
}

/**
 * Expressive typography emphasis for Modern mode. Keeps relative `sp` sizes intact so
 * 200% system font scale continues to scale cleanly without clipping.
 */
internal fun modernTypography(base: Typography): Typography = base.copy(
    displaySmall = base.displaySmall.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.5).sp),
    headlineMedium = base.headlineMedium.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.4).sp),
    headlineSmall = base.headlineSmall.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.3).sp),
    titleLarge = base.titleLarge.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.2).sp),
    titleSmall = base.titleSmall.copy(fontWeight = FontWeight.Bold, letterSpacing = 0.2.sp),
    labelLarge = base.labelLarge.copy(fontWeight = FontWeight.Bold),
)
