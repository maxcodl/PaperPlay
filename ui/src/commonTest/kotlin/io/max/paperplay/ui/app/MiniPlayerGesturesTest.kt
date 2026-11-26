package io.max.paperplay.ui.app

import androidx.compose.ui.unit.Density
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class MiniPlayerGesturesTest {
    private val density = Density(2.75f, 1f)
    private val defaultCfg = defaultMiniHideConfig(density)
    private val modernCfg = modernMiniHideConfig(density)

    @Test
    fun axisLockDisambiguatesBelowSlopHorizontalExpandAndHide() {
        val slop = 22f
        // Below touch slop stays None
        assertEquals(ModernMiniDragLock.None, resolveModernMiniDragLock(10f, 10f, slop))
        // Horizontal wins over smaller vertical
        assertEquals(ModernMiniDragLock.HorizontalSkip, resolveModernMiniDragLock(-30f, 12f, slop))
        assertEquals(ModernMiniDragLock.HorizontalSkip, resolveModernMiniDragLock(28f, -20f, slop))
        // Tie goes to HorizontalSkip
        assertEquals(ModernMiniDragLock.HorizontalSkip, resolveModernMiniDragLock(25f, 25f, slop))
        // Upward vertical -> expand
        assertEquals(ModernMiniDragLock.VerticalExpand, resolveModernMiniDragLock(8f, -30f, slop))
        // Downward vertical -> hide
        assertEquals(ModernMiniDragLock.VerticalHide, resolveModernMiniDragLock(-8f, 30f, slop))
    }

    @Test
    fun horizontalSkipResolvesLeftNextAndRightPreviousByDistanceOrVelocity() {
        val threshold = 143f
        assertEquals(ModernMiniSkipAction.Next, resolveModernMiniSkip(-150f, 0f, threshold))
        assertEquals(ModernMiniSkipAction.Previous, resolveModernMiniSkip(150f, 0f, threshold))
        assertEquals(ModernMiniSkipAction.Next, resolveModernMiniSkip(-20f, -950f, threshold))
        assertEquals(ModernMiniSkipAction.Previous, resolveModernMiniSkip(20f, 950f, threshold))
        assertEquals(ModernMiniSkipAction.None, resolveModernMiniSkip(-60f, -200f, threshold))
        assertEquals(ModernMiniSkipAction.None, resolveModernMiniSkip(60f, 200f, threshold))
    }

    @Test
    fun sharedHideDecisionsPreserveDefaultHorizontalAndModernVerticalDown() {
        // Playing blocks dismiss in both styles
        assertFalse(shouldDismissMiniPlayer(offsetPx = 500f, velocityPxPerSec = 2000f, config = defaultCfg, playing = true))
        assertFalse(shouldDismissMiniPlayer(offsetPx = 500f, velocityPxPerSec = 2000f, config = modernCfg, playing = true))

        // Default: left or right past 80 dp or 800 px/s dismisses
        assertTrue(shouldDismissMiniPlayer(offsetPx = -defaultCfg.distanceThresholdPx - 1f, velocityPxPerSec = 0f, config = defaultCfg, playing = false))
        assertTrue(shouldDismissMiniPlayer(offsetPx = defaultCfg.distanceThresholdPx + 1f, velocityPxPerSec = 0f, config = defaultCfg, playing = false))
        assertTrue(shouldDismissMiniPlayer(offsetPx = -10f, velocityPxPerSec = -850f, config = defaultCfg, playing = false))
        assertFalse(shouldDismissMiniPlayer(offsetPx = -40f, velocityPxPerSec = -200f, config = defaultCfg, playing = false))
        assertEquals(-1000f, dismissTargetOffset(-50f, 0f, defaultCfg))
        assertEquals(1000f, dismissTargetOffset(50f, 0f, defaultCfg))

        // Modern: only downward past 36 dp or 600 px/s dismisses; upward never dismisses
        assertTrue(shouldDismissMiniPlayer(offsetPx = modernCfg.distanceThresholdPx + 1f, velocityPxPerSec = 0f, config = modernCfg, playing = false))
        assertTrue(shouldDismissMiniPlayer(offsetPx = 12f, velocityPxPerSec = 650f, config = modernCfg, playing = false))
        assertFalse(shouldDismissMiniPlayer(offsetPx = -200f, velocityPxPerSec = -2000f, config = modernCfg, playing = false))
        assertEquals(modernCfg.dismissTargetPx, dismissTargetOffset(20f, 0f, modernCfg))
    }

    @Test
    fun sharedHideStateClampsDirectionAndRestoresOnPlayback() {
        val state = MiniPlayerHideState()
        assertFalse(state.gone)

        // Modern clamps upward drag to >= 0
        state.onDragDelta(-25f, modernCfg, playing = false)
        assertEquals(0f, state.dragOffset)
        state.onDragDelta(40f, modernCfg, playing = false)
        assertEquals(40f, state.dragOffset)

        // Ignored while playing
        state.dragOffset = 0f
        state.onDragDelta(40f, modernCfg, playing = true)
        assertEquals(0f, state.dragOffset)

        // Default allows negative (left) and positive (right)
        state.onDragDelta(-50f, defaultCfg, playing = false)
        assertEquals(-50f, state.dragOffset)

        // Restore rule: starting playback brings back hidden mini-player
        state.gone = true
        state.dragOffset = 100f
        state.onPlayingChanged(false)
        assertTrue(state.gone)
        state.onPlayingChanged(true)
        assertFalse(state.gone)
        assertEquals(0f, state.dragOffset)
    }

    @Test
    fun expandReleaseOpensOnFastUpFlickOrPastTwentyPercent() {
        assertTrue(shouldOpenOnExpandRelease(progress = 0.05f, velocityYPxPerSec = -1500f))
        assertFalse(shouldOpenOnExpandRelease(progress = 0.50f, velocityYPxPerSec = 1500f))
        assertTrue(shouldOpenOnExpandRelease(progress = 0.25f, velocityYPxPerSec = 0f))
        assertFalse(shouldOpenOnExpandRelease(progress = 0.15f, velocityYPxPerSec = 0f))
    }
}
