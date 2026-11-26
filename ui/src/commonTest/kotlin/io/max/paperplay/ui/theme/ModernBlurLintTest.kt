package io.max.paperplay.ui.theme

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Guardrail test: prevents live backdrop blur (`drawBackdrop`, `modernGlassSurface`, `GlassSurface`,
 * or `ModernSurfaceTier.Chrome`) from being placed inside lazy list/grid item scopes or `SongRow.kt`.
 */
class ModernBlurLintTest {
    private val forbiddenInRows = listOf(
        Regex("""\bdrawBackdrop\s*\("""),
        Regex("""\bmodernGlassSurface\s*\("""),
        Regex("""\bGlassSurface\s*\("""),
        Regex("""ModernSurfaceTier\.Chrome"""),
    )

    @Test
    fun noLiveBlurInSongRowOrLazyItems() {
        val candidates = listOf(
            File("src/commonMain/kotlin"),
            File("ui/src/commonMain/kotlin"),
        )
        val root = candidates.firstOrNull { it.isDirectory }
            ?: error("Could not locate ui/src/commonMain/kotlin from ${File(".").absolutePath}")

        val violations = mutableListOf<String>()
        val songRow = File(root, "io/max/paperplay/ui/components/SongRow.kt")
        if (songRow.isFile) {
            songRow.readLines().forEachIndexed { idx, line ->
                val t = line.trim()
                if (t.startsWith("//") || t.startsWith("*")) return@forEachIndexed
                for (pat in forbiddenInRows) {
                    if (pat.containsMatchIn(line)) {
                        violations += "SongRow.kt:${idx + 1}: $t"
                    }
                }
            }
        }

        // Also ensure no file calls drawBackdrop inside an item/items block of a Lazy list/grid.
        val lazyStart = Regex("""\bLazy(Column|Row|VerticalGrid|HorizontalGrid)\s*[({]""")
        val itemStart = Regex("""\bitem(s|sIndexed)?\s*[({]""")
        root.walkTopDown()
            .filter { it.isFile && it.extension == "kt" }
            .forEach { file ->
                val lines = file.readLines()
                var inLazy = false
                var lazyDepth = 0
                var inItem = false
                var itemDepth = 0
                lines.forEachIndexed { idx, line ->
                    val t = line.trim()
                    if (t.startsWith("//") || t.startsWith("*")) return@forEachIndexed
                    val opens = line.count { it == '{' }
                    val closes = line.count { it == '}' }
                    if (!inLazy && lazyStart.containsMatchIn(line)) {
                        inLazy = true
                        lazyDepth = opens - closes
                        return@forEachIndexed
                    }
                    if (inLazy) {
                        if (!inItem && itemStart.containsMatchIn(line)) {
                            inItem = true
                            itemDepth = opens - closes
                        } else if (inItem) {
                            for (pat in forbiddenInRows) {
                                if (pat.containsMatchIn(line)) {
                                    violations += "${file.relativeTo(root).path}:${idx + 1}: $t"
                                }
                            }
                            itemDepth += opens - closes
                            if (itemDepth <= 0) inItem = false
                        }
                        lazyDepth += opens - closes
                        if (lazyDepth <= 0) {
                            inLazy = false
                            inItem = false
                        }
                    }
                }
            }

        assertTrue(
            violations.isEmpty(),
            "Found forbidden live blur inside lazy items or SongRow:\n${violations.joinToString("\n")}",
        )
    }
}
