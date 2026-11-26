package io.max.paperplay.ui.theme

import androidx.compose.foundation.shape.CornerBasedShape
import androidx.compose.foundation.shape.CornerSize
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan

/**
 * Corners like an iPhone's: the curve starts before the circle would and eases into the straight edge, so there is no visible
 * point where straight turns into round. [smoothing] 0 is a plain circular corner; 0.6 is close to iOS.
 *
 * Each corner is a curve, an arc and a curve, following the "corner smoothing" construction Figma described.
 */
class ContinuousCornerShape(
    topStart: CornerSize,
    topEnd: CornerSize,
    bottomEnd: CornerSize,
    bottomStart: CornerSize,
    private val smoothing: Float = 0.6f,
) : CornerBasedShape(topStart, topEnd, bottomEnd, bottomStart) {
    constructor(radius: Dp, smoothing: Float = 0.6f) : this(CornerSize(radius), CornerSize(radius), CornerSize(radius), CornerSize(radius), smoothing)

    override fun copy(topStart: CornerSize, topEnd: CornerSize, bottomEnd: CornerSize, bottomStart: CornerSize) =
        ContinuousCornerShape(topStart, topEnd, bottomEnd, bottomStart, smoothing)

    override fun createOutline(size: Size, topStart: Float, topEnd: Float, bottomEnd: Float, bottomStart: Float, layoutDirection: LayoutDirection): Outline {
        if (topStart + topEnd + bottomEnd + bottomStart == 0f) return Outline.Rectangle(size.toRect())
        val ltr = layoutDirection == LayoutDirection.Ltr
        val tl = if (ltr) topStart else topEnd
        val tr = if (ltr) topEnd else topStart
        val br = if (ltr) bottomEnd else bottomStart
        val bl = if (ltr) bottomStart else bottomEnd
        val w = size.width
        val h = size.height
        val path = Path()
        // Clockwise from the top edge: each corner gets its point, the direction it is reached from and the direction it leaves in.
        val corners = listOf(
            Triple(Offset(w, 0f), Offset(1f, 0f), Offset(0f, 1f)) to tr,
            Triple(Offset(w, h), Offset(0f, 1f), Offset(-1f, 0f)) to br,
            Triple(Offset(0f, h), Offset(-1f, 0f), Offset(0f, -1f)) to bl,
            Triple(Offset(0f, 0f), Offset(0f, -1f), Offset(1f, 0f)) to tl,
        )
        val limit = min(w, h) / 2f
        for ((i, c) in corners.withIndex()) {
            val (k, u, v) = c.first
            corner(path, k, u, v, c.second, limit, first = i == 0)
        }
        path.close()
        return Outline.Generic(path)
    }

    private fun corner(path: Path, k: Offset, u: Offset, v: Offset, radius: Float, limit: Float, first: Boolean) {
        val r = min(radius, limit)
        if (r <= 0f) {
            if (first) path.moveTo(k.x, k.y) else path.lineTo(k.x, k.y)
            return
        }
        // Smoothing needs room along both edges; a small box gets less of it rather than a broken corner.
        val s = min(smoothing, (limit / r - 1f).coerceAtLeast(0f))
        val p = (1f + s) * r
        val arcDeg = 90f * (1f - s)
        val arcSide = sin(rad(arcDeg / 2f)) * r * sqrt(2f)
        val alpha = (90f - arcDeg) / 2f
        val p3p4 = r * tan(rad(alpha / 2f))
        val beta = 45f * s
        val c = p3p4 * cos(rad(beta))
        val d = c * tan(rad(beta))
        val b = (p - arcSide - c - d) / 3f
        val a = 2f * b
        fun at(along: Float, across: Float) = Offset(k.x - p * u.x + along * u.x + across * v.x, k.y - p * u.y + along * u.y + across * v.y)
        val start = at(0f, 0f)
        if (first) path.moveTo(start.x, start.y) else path.lineTo(start.x, start.y)
        val e1 = at(a + b + c, d)
        val c1 = at(a, 0f)
        val c2 = at(a + b, 0f)
        path.cubicTo(c1.x, c1.y, c2.x, c2.y, e1.x, e1.y)
        if (arcDeg > 0.01f) {
            val center = Offset(k.x - r * u.x + r * v.x, k.y - r * u.y + r * v.y)
            val startDeg = (atan2(e1.y - center.y, e1.x - center.x) * 180.0 / PI).toFloat()
            path.arcTo(Rect(center, r), startDeg, arcDeg, false)
        }
        val e2 = at(a + b + c + arcSide, d + arcSide)
        val c3 = Offset(e2.x + d * u.x + c * v.x, e2.y + d * u.y + c * v.y)
        val c4 = Offset(e2.x + d * u.x + (b + c) * v.x, e2.y + d * u.y + (b + c) * v.y)
        val end = Offset(e2.x + d * u.x + (a + b + c) * v.x, e2.y + d * u.y + (a + b + c) * v.y)
        path.cubicTo(c3.x, c3.y, c4.x, c4.y, end.x, end.y)
    }

    private fun rad(deg: Float) = deg * PI.toFloat() / 180f

    private fun Size.toRect() = Rect(Offset.Zero, this)

    override fun equals(other: Any?): Boolean = other is ContinuousCornerShape && other.smoothing == smoothing &&
        topStart == other.topStart && topEnd == other.topEnd && bottomEnd == other.bottomEnd && bottomStart == other.bottomStart

    override fun hashCode(): Int = ((topStart.hashCode() * 31 + topEnd.hashCode()) * 31 + bottomEnd.hashCode()) * 31 + bottomStart.hashCode() + smoothing.hashCode()
}
