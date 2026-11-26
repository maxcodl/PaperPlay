package io.max.paperplay.ui.theme

import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ContinuousCornerShapeTest {
    private val density = Density(1f)

    /** Whether the shape covers any of the small square at [x], [y]. */
    private fun androidx.compose.ui.graphics.Path.covers(x: Float, y: Float): Boolean {
        val box = androidx.compose.ui.graphics.Path().apply { addRect(androidx.compose.ui.geometry.Rect(x, y, x + 1f, y + 1f)) }
        return !androidx.compose.ui.graphics.Path.combine(androidx.compose.ui.graphics.PathOperation.Intersect, this, box).isEmpty
    }

    private fun outline(w: Float, h: Float, r: Float) = ContinuousCornerShape(r.dp).createOutline(Size(w, h), LayoutDirection.Ltr, density)

    @Test
    fun theCornerStaysInsideTheBoxAndKeepsItsEdges() {
        val b = (outline(200f, 100f, 30f) as Outline.Generic).path.getBounds()
        assertEquals(0f, b.left, 0.5f); assertEquals(0f, b.top, 0.5f); assertEquals(200f, b.right, 0.5f); assertEquals(100f, b.bottom, 0.5f)
        val path = (outline(200f, 100f, 30f) as Outline.Generic).path
        // The very corner is cut, the middle of each edge is not.
        assertFalse(path.covers(0f, 0f))
        assertTrue(path.covers(100f, 0f))
        assertTrue(path.covers(0f, 50f))
    }

    @Test
    fun aHugeRadiusOrNoneStillGivesAClosedShape() {
        assertTrue(outline(40f, 40f, 500f) is Outline.Generic)
        assertTrue(outline(40f, 40f, 0f) is Outline.Rectangle)
    }
}
