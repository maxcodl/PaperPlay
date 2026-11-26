package io.max.paperplay.ui.theme

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BluetoothAudio
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material.icons.rounded.Speaker
import androidx.compose.material.icons.rounded.Usb
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import io.max.paperplay.player.OutputInfo
import io.max.paperplay.ui.OutputDevice
import io.max.paperplay.ui.app.PlayerStyle
import io.max.paperplay.ui.app.UiPrefs
import io.max.paperplay.ui.app.UiStyle
import io.max.paperplay.ui.app.parsePlayerStyle
import io.max.paperplay.ui.app.parseUiStyle
import io.max.paperplay.ui.app.resolveEffectivePlayerStyle
import io.max.paperplay.ui.app.resolveEffectiveUiStyle
import io.max.paperplay.ui.app.resolveOutputIcon
import io.max.paperplay.ui.components.WAVY_RING_LOBES
import io.max.paperplay.ui.components.buildScallopedPoints
import io.max.paperplay.ui.components.scallopedPolarRadius
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ModernStyleTest {
    @Test
    fun uiStyleDefaultsToDefaultAndLocksDesktop() {
        val store = mutableMapOf<String, String>()
        val prefs = UiPrefs({ store[it] }, { k, v -> store[k] = v })
        assertEquals(UiStyle.Default, prefs.uiStyle)
        assertEquals(UiStyle.Default, resolveEffectiveUiStyle(prefs, isAndroid = true))
        assertEquals(UiStyle.Default, resolveEffectiveUiStyle(prefs, isAndroid = false))

        prefs.putUiStyle(UiStyle.Modern)
        assertEquals(UiStyle.Modern, prefs.uiStyle)
        assertEquals("modern", store["ui_style"])
        assertEquals(UiStyle.Modern, resolveEffectiveUiStyle(prefs, isAndroid = true))
        // Desktop must always stay Default
        assertEquals(UiStyle.Default, resolveEffectiveUiStyle(prefs, isAndroid = false))

        assertEquals(UiStyle.Default, parseUiStyle(null))
        assertEquals(UiStyle.Default, parseUiStyle("bogus"))
        assertEquals(UiStyle.Modern, parseUiStyle("MODERN"))
    }

    @Test
    fun playerStyleMigrationAndFollowAppMatrix() {
        // Unset becomes FollowApp; explicit default/modern keep their meaning.
        assertEquals(PlayerStyle.FollowApp, parsePlayerStyle(null))
        assertEquals(PlayerStyle.FollowApp, parsePlayerStyle(""))
        assertEquals(PlayerStyle.Default, parsePlayerStyle("default"))
        assertEquals(PlayerStyle.Modern, parsePlayerStyle("modern"))
        assertEquals(PlayerStyle.FollowApp, parsePlayerStyle("followapp"))
        assertEquals(PlayerStyle.FollowApp, parsePlayerStyle("follow_app"))
        assertEquals(PlayerStyle.Default, parsePlayerStyle("unknown"))

        val store = mutableMapOf<String, String>()
        val prefs = UiPrefs({ store[it] }, { k, v -> store[k] = v })
        // FollowApp mirrors UiStyle on Android
        assertEquals(PlayerStyle.Default, resolveEffectivePlayerStyle(prefs, isAndroid = true))
        prefs.putUiStyle(UiStyle.Modern)
        assertEquals(PlayerStyle.Modern, resolveEffectivePlayerStyle(prefs, isAndroid = true))
        // Desktop stays Default even when UiStyle is Modern
        assertEquals(PlayerStyle.Default, resolveEffectivePlayerStyle(prefs, isAndroid = false))

        // Explicit overrides win over UiStyle on Android
        prefs.putPlayerStyle(PlayerStyle.Default)
        assertEquals(PlayerStyle.Default, resolveEffectivePlayerStyle(prefs, isAndroid = true))

        prefs.putUiStyle(UiStyle.Default)
        prefs.putPlayerStyle(PlayerStyle.Modern)
        assertEquals(PlayerStyle.Modern, resolveEffectivePlayerStyle(prefs, isAndroid = true))
        assertEquals(PlayerStyle.Default, resolveEffectivePlayerStyle(prefs, isAndroid = false))
    }

    @Test
    fun defaultPathProducesDisabledTokensWithoutTouchingModern() {
        val scheme = schemeFromSeed(FallbackSeed, dark = true)
        val disabled = resolveModernTokens(
            enabled = false,
            scheme = scheme,
            dark = true,
            amoled = false,
            reducedTransparency = false,
        )
        assertFalse(disabled.enabled)
        assertEquals(ModernTokens.Disabled, disabled)
    }

    @Test
    fun modernTokensMeetContrastRequirementsAcrossAllModes() {
        val seeds = listOf(FallbackSeed, 0xFF2F80ED.toInt(), 0xFFE8A33D.toInt(), 0xFF888888.toInt())
        for (seed in seeds) {
            for (dark in listOf(true, false)) {
                for (amoled in if (dark) listOf(false, true) else listOf(false)) {
                    for (reduced in listOf(false, true)) {
                        val base = schemeFromSeed(seed, dark = dark)
                        val scheme = if (dark && amoled) base.amoled() else base
                        val tokens = resolveModernTokens(
                            enabled = true,
                            scheme = scheme,
                            dark = dark,
                            amoled = amoled,
                            reducedTransparency = reduced,
                        )
                        assertTrue(tokens.enabled)
                        val sampleBackdrop = if (dark) {
                            if (amoled) Color.Black else lerp(scheme.surfaceContainerLowest, Color.Black, 0.72f)
                        } else {
                            lerp(scheme.surface, scheme.primaryContainer, 0.18f)
                        }
                        val cardOver = tokens.cardBg.compositeOver(sampleBackdrop)
                        val chromeOver = tokens.chromeBg.compositeOver(sampleBackdrop)
                        val overlayOver = tokens.overlayBg.compositeOver(sampleBackdrop)

                        assertTrue(
                            contrastRatio(tokens.onGlass, cardOver) >= 4.5,
                            "onGlass contrast too low on card (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        assertTrue(
                            contrastRatio(tokens.onGlass, chromeOver) >= 4.5,
                            "onGlass contrast too low on chrome (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        assertTrue(
                            contrastRatio(tokens.onGlass, overlayOver) >= 4.5,
                            "onGlass contrast too low on overlay (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        assertTrue(
                            contrastRatio(tokens.onGlassMuted, cardOver) >= 4.5,
                            "onGlassMuted contrast too low (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        assertTrue(
                            contrastRatio(tokens.accentOnGlass, cardOver) >= 3.0,
                            "accentOnGlass UI contrast too low (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        // Borderless tonal separation: card & elevated card must stay distinguishable from backdrop
                        assertTrue(
                            kotlin.math.abs(cardOver.luminance() - sampleBackdrop.luminance()) > 0.004f,
                            "cardBg too close to backdrop (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        val elevatedOver = tokens.cardBgElevated.compositeOver(sampleBackdrop)
                        assertTrue(
                            abs(elevatedOver.luminance() - cardOver.luminance()) > 0.003f,
                            "cardBgElevated not stepped from cardBg (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                        // Shared dock tokens must match chrome contrast & maintain >= 4.5:1 selected pill text
                        assertEquals(tokens.chromeBg, tokens.dock.fill)
                        assertEquals(tokens.pillSelectedBg, tokens.dock.selectedPillBg)
                        val dockSelectedOver = tokens.dock.selectedPillBg.compositeOver(chromeOver)
                        assertTrue(
                            contrastRatio(tokens.dock.selectedContentColor, dockSelectedOver) >= 4.5,
                            "dock selectedContentColor contrast too low (dark=$dark, amoled=$amoled, reduced=$reduced)",
                        )
                    }
                }
            }
        }
    }

    @Test
    fun outputIconMapsSpeakerHeadphonesBluetoothAndUsb() {
        assertEquals(Icons.Rounded.Speaker, resolveOutputIcon(null, OutputDevice("Phone", false)))
        assertEquals(Icons.Rounded.Headphones, resolveOutputIcon(null, OutputDevice("Wired Headphones", true)))
        assertEquals(Icons.Rounded.BluetoothAudio, resolveOutputIcon(OutputInfo(device = "Bluetooth A2DP"), OutputDevice("Buds", true)))
        assertEquals(Icons.Rounded.Usb, resolveOutputIcon(OutputInfo(device = "CX31993 USB DAC"), OutputDevice("CX31993", true)))
    }

    @Test
    fun wavyProgressRingIsStaticConcentricAndMaintainsConstantAmplitudeAndGap() {
        assertEquals(10, WAVY_RING_LOBES)
        val ringBaseR = 44f
        val buttonBaseR = 36f
        val amp = 3.5f
        val pts = buildScallopedPoints(cx = 50f, cy = 50f, baseRadius = ringBaseR, amplitudePx = amp, lobes = WAVY_RING_LOBES, steps = 360)
        var minR = Float.MAX_VALUE
        var maxR = Float.MIN_VALUE
        for (i in pts.indices step 2) {
            val r = hypot(pts[i] - 50f, pts[i + 1] - 50f)
            if (r < minR) minR = r
            if (r > maxR) maxR = r
        }
        // Peak-to-trough must equal 2 * amplitude independent of progress
        assertEquals(ringBaseR + amp, maxR, 0.05f)
        assertEquals(ringBaseR - amp, minR, 0.05f)

        // Peak aligns at 12 o'clock (-PI/2) and radial gap between ring and button is identical at every angle
        val topAngle = (-PI / 2.0).toFloat()
        assertEquals(ringBaseR + amp, scallopedPolarRadius(ringBaseR, amp, topAngle), 0.001f)
        assertEquals(buttonBaseR + amp, scallopedPolarRadius(buttonBaseR, amp, topAngle), 0.001f)
        for (deg in 0 until 360) {
            val angle = (deg * PI / 180.0).toFloat()
            val gap = scallopedPolarRadius(ringBaseR, amp, angle) - scallopedPolarRadius(buttonBaseR, amp, angle)
            assertEquals(ringBaseR - buttonBaseR, gap, 0.001f)
        }
    }
}
