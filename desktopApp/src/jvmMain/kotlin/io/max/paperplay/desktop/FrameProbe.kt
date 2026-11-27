package io.max.paperplay.desktop

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import io.max.paperplay.ui.theme.DesktopFrameMonitor
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.awt.Toolkit
import java.awt.event.MouseEvent
import java.awt.event.MouseWheelEvent
import javax.swing.SwingUtilities

/**
 * Off unless started with -Dpaperplay.frames=<warm-up seconds>. Waits for the real app to load (covers, blur, lists),
 * then measures frame gaps while still, while wheel scrolling down and back up over the window centre, and prints them.
 * The scroll is posted to the window's own event queue, so the real mouse is not moved.
 */
@Composable
fun FrameProbe(window: java.awt.Window) {
    val warmup = System.getProperty("paperplay.frames")?.toIntOrNull() ?: return
    val monitor = remember { DesktopFrameMonitor(capacity = 8192) }
    LaunchedEffect(Unit) {
        launch { while (isActive) withFrameNanos(monitor::recordFrameNanos) }
        delay(warmup * 1000L)
        suspend fun phase(name: String, ms: Long, tick: (() -> Unit)? = null) {
            monitor.reset()
            val end = System.currentTimeMillis() + ms
            while (System.currentTimeMillis() < end) { tick?.invoke(); delay(if (tick == null) 100 else 40) }
            val s = monitor.snapshot(forcedVsyncMs = 1000f / 60f)
            println("FRAMES $name: n=${s.sampleCount} p50=${"%.1f".format(s.p50Ms)} p95=${"%.1f".format(s.p95Ms)} " +
                "p99=${"%.1f".format(s.p99Ms)} max=${"%.1f".format(s.maxMs)} over2vsync=${"%.1f".format(s.over2VsyncPct)}%")
        }
        fun wheel(dir: Int) {
            val root = (window as? javax.swing.RootPaneContainer)?.contentPane ?: return
            val x = root.width / 2; val y = root.height / 2
            val target = SwingUtilities.getDeepestComponentAt(root, x, y) ?: return
            val p = SwingUtilities.convertPoint(root, x, y, target)
            val now = System.currentTimeMillis()
            Toolkit.getDefaultToolkit().systemEventQueue.postEvent(
                MouseWheelEvent(target, MouseEvent.MOUSE_WHEEL, now, 0, p.x, p.y, 0, false, MouseWheelEvent.WHEEL_UNIT_SCROLL, 3, dir)
            )
        }
        repeat(2) { round ->
            phase("r$round still", 4000)
            phase("r$round scroll_down", 5000) { wheel(1) }
            phase("r$round scroll_up", 5000) { wheel(-1) }
        }
        println("FRAMES done")
    }
}
