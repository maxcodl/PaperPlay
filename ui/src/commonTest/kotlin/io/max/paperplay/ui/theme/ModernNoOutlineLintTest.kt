package io.max.paperplay.ui.theme

import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/**
 * Guardrail test: ensures Modern-only UI files never use borders, rims, hairlines, or Outlined*
 * Material components. Surfaces in Modern separate strictly by tonal fills, soft shadows, and blur.
 */
class ModernNoOutlineLintTest {
    private val forbidden = listOf(
        Regex("""\.border\s*\("""),
        Regex("""\bBorderStroke\b"""),
        Regex("""\brimColor\b"""),
        Regex("""\brimHighlight\b"""),
        Regex("""\bdrawRim\b"""),
        Regex("""\bOutlined(Button|TextField|Card|ToggleButton|IconButton)\b"""),
        Regex("""\bHorizontalDivider\b"""),
        Regex("""\.shadow\s*\("""),
        Regex("""\bmodernOuterShadow\b"""),
        Regex("""\bdrawShadow\b"""),
        Regex("""\bInnerShadow\s*\("""),
        Regex("""\bShadow\s*\("""),
        Regex("""shadowElevation\s*=\s*[1-9]"""),
        Regex("""tonalElevation\s*=\s*[1-9]"""),
    )

    @Test
    fun noBordersOrOutlinedComponentsInModernFiles() {
        val candidates = listOf(
            File("src/commonMain/kotlin"),
            File("ui/src/commonMain/kotlin"),
        )
        val root = candidates.firstOrNull { it.isDirectory }
            ?: error("Could not locate ui/src/commonMain/kotlin from ${File(".").absolutePath}")

        val modernFiles = listOf(
            "io/max/paperplay/ui/theme/ModernTheme.kt",
            "io/max/paperplay/ui/components/ModernComponents.kt",
            "io/max/paperplay/ui/app/ModernHome.kt",
            "io/max/paperplay/ui/app/ModernPlayerUi.kt",
            "io/max/paperplay/ui/app/ModernPlayerGlass.kt",
            "io/max/paperplay/ui/app/AndroidProfile.kt",
            "io/max/paperplay/ui/app/AndroidStats.kt",
        )
        val violations = mutableListOf<String>()

        for (rel in modernFiles) {
            val file = File(root, rel)
            if (!file.isFile) continue
            file.readLines().forEachIndexed { idx, line ->
                val t = line.trim()
                if (t.startsWith("//") || t.startsWith("*")) return@forEachIndexed
                for (pat in forbidden) {
                    if (pat.containsMatchIn(line)) {
                        violations += "$rel:${idx + 1}: $t"
                    }
                }
            }
        }

        assertTrue(
            violations.isEmpty(),
            "Found forbidden border/outline/divider in Modern files:\n${violations.joinToString("\n")}",
        )
    }

    @Test
    fun noUnclippedBackgroundOrUnguardedNestedSurfaceInModernFiles() {
        val candidates = listOf(
            File("src/commonMain/kotlin"),
            File("ui/src/commonMain/kotlin"),
        )
        val root = candidates.firstOrNull { it.isDirectory }
            ?: error("Could not locate ui/src/commonMain/kotlin from ${File(".").absolutePath}")

        val surfaceFiles = listOf(
            "io/max/paperplay/ui/components/ModernComponents.kt",
            "io/max/paperplay/ui/app/ModernHome.kt",
            "io/max/paperplay/ui/app/AndroidProfile.kt",
            "io/max/paperplay/ui/app/AndroidStats.kt",
        )
        val violations = mutableListOf<String>()

        for (rel in surfaceFiles) {
            val file = File(root, rel)
            if (!file.isFile) continue
            val lines = file.readLines()
            var inPreview = false
            lines.forEachIndexed { idx, line ->
                val t = line.trim()
                if (t.startsWith("@Preview")) {
                    inPreview = true
                    return@forEachIndexed
                }
                if (inPreview) return@forEachIndexed
                if (t.startsWith("//") || t.startsWith("*")) return@forEachIndexed
                if (t.contains(".background(") && !t.contains(".fillMaxSize().background(")) {
                    // Two-arg background(color/brush, shape) is self-clipped; otherwise require .clip( nearby.
                    val window = lines.subList(maxOf(0, idx - 3), minOf(lines.size, idx + 4)).joinToString(" ")
                    val callTail = t.substringAfter(".background(").substringBefore(")")
                    val hasShapeArg = callTail.contains(",") || t.contains("shape =")
                    val hasClipNearby = window.contains(".clip(")
                    if (!hasShapeArg && !hasClipNearby) {
                        violations += "$rel:${idx + 1}: unclipped .background(: $t"
                    }
                }
            }
        }

        val modernComponents = File(root, "io/max/paperplay/ui/components/ModernComponents.kt").readText()
        assertTrue(
            modernComponents.contains("LocalInsideModernSurface.current"),
            "ModernComponents.kt must guard against nested modernSurface calls via LocalInsideModernSurface.current",
        )

        val settingsUi = File(root, "io/max/paperplay/ui/app/SettingsUi.kt").readText()
        assertTrue(
            settingsUi.contains("LocalInsideModernSurface provides"),
            "SettingsUi.kt must provide LocalInsideModernSurface inside card/section containers",
        )

        assertTrue(
            violations.isEmpty(),
            "Found unclipped background in Modern files:\n${violations.joinToString("\n")}",
        )
    }
}
