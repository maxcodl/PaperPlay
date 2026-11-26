package io.max.paperplay.ui.app

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.collectIsDraggedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.FastRewind
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.RepeatOne
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.max.paperplay.core.metadata.PairedLrcLine
import io.max.paperplay.core.metadata.pairLrcLines
import io.max.paperplay.core.metadata.parseLrc
import io.max.paperplay.ui.FakePlayerControls
import io.max.paperplay.ui.PreviewFrame
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.components.SongMenu
import io.max.paperplay.ui.components.toggleOnColor
import io.max.paperplay.ui.previewActions
import io.max.paperplay.ui.previewPlayback
import io.max.paperplay.ui.previewSongs
import io.max.paperplay.ui.state.PlaybackUiState
import io.max.paperplay.ui.state.RepeatUi
import io.max.paperplay.ui.state.SongUi
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.Motion
import io.max.paperplay.ui.theme.amoled
import io.max.paperplay.ui.theme.motionTween
import io.max.paperplay.ui.theme.schemeFromSeed
import kotlinx.coroutines.delay
import org.jetbrains.compose.ui.tooling.preview.Preview

internal data class SecondaryToggleState(
    val available: Boolean,
    val activeText: String?,
    val chipLabel: String,
    val active: Boolean,
)

internal fun resolveSecondaryState(
    romanized: String?,
    translation: String?,
    enabled: Boolean,
    preferredKind: String,
    primaryText: String?,
): SecondaryToggleState {
    val cleanRoma = romanized?.takeIf { it.isNotBlank() && it != primaryText }
    val cleanTrans = translation?.takeIf { it.isNotBlank() && it != primaryText }
    if (cleanRoma == null && cleanTrans == null) {
        return SecondaryToggleState(available = false, activeText = null, chipLabel = "Romanized", active = false)
    }
    val chosenKind = when {
        preferredKind == "translation" && cleanTrans != null -> "translation"
        preferredKind == "romanized" && cleanRoma != null -> "romanized"
        cleanRoma != null -> "romanized"
        else -> "translation"
    }
    val label = if (chosenKind == "translation") "Translation" else "Romanized"
    val activeText = if (!enabled) null else if (chosenKind == "translation") cleanTrans else cleanRoma
    return SecondaryToggleState(available = true, activeText = activeText, chipLabel = label, active = enabled)
}

internal fun nextSecondaryPref(
    romanized: String?,
    translation: String?,
    enabled: Boolean,
    preferredKind: String,
): Pair<Boolean, String> {
    val hasRoma = !romanized.isNullOrBlank()
    val hasTrans = !translation.isNullOrBlank()
    return when {
        hasRoma && hasTrans -> when {
            !enabled -> true to "romanized"
            preferredKind == "romanized" -> true to "translation"
            else -> false to "romanized"
        }
        hasRoma -> (!enabled) to "romanized"
        hasTrans -> (!enabled) to "translation"
        else -> false to preferredKind
    }
}

internal fun lyricsLineAlpha(index: Int, current: Int, dark: Boolean): Float = when {
    index == current -> 1f
    index < current -> if (dark) 0.38f else 0.42f
    else -> if (dark) 0.68f else 0.64f
}

/**
 * Synced lyrics for the current song: the current line is prominent and kept in view, sung lines dim,
 * upcoming lines stay legible, and tapping any line seeks. Optional romanization/translation appears
 * beneath each line when available. Shared between phone [FullLyricsPage] and desktop [NowPlayingView] / [FullPlayer].
 */
@Composable
fun LyricsPane(
    song: SongUi,
    backend: PlayerControls,
    large: Boolean,
    modifier: Modifier = Modifier,
    showControls: Boolean = true,
) {
    val id = song.id
    val prefs = LocalUiPrefs.current
    val dark = MaterialTheme.colorScheme.surface.luminance() < 0.5f

    var text by remember(id) { mutableStateOf<String?>(null) }
    var loaded by remember(id) { mutableStateOf(false) }
    var fetchedSecondary by remember(id) { mutableStateOf<LyricsSecondaryUi?>(null) }
    var manualChoice by remember(id) { mutableStateOf<LyricsChoiceUi?>(null) }
    var reloadNonce by remember(id) { mutableStateOf(0) }
    var choosing by remember(id) { mutableStateOf(false) }

    var fallbackTextSize by remember { mutableStateOf(LyricsTextSize.Medium) }
    var fallbackSecondary by remember { mutableStateOf(true) }
    var fallbackKind by remember { mutableStateOf("romanized") }

    val textSize = prefs?.lyricsTextSize ?: fallbackTextSize
    val secondaryOn = prefs?.lyricsSecondary ?: fallbackSecondary
    val secondaryKind = prefs?.lyricsSecondaryKind ?: fallbackKind

    LaunchedEffect(id, reloadNonce) {
        loaded = false
        text = backend.lyricsFor(id)
        loaded = true
    }

    val primaryLines = remember(text) { text?.let(::parseLrc).orEmpty() }

    LaunchedEffect(id, text, manualChoice) {
        fetchedSecondary = if (manualChoice == null && primaryLines.isNotEmpty()) {
            runCatching { backend.lyricsSecondary(id) }.getOrNull()
        } else {
            null
        }
    }

    val romaTrack = manualChoice?.romanized ?: fetchedSecondary?.romanized
    val transTrack = manualChoice?.translation ?: fetchedSecondary?.translation
    val secondaryState = remember(romaTrack, transTrack, secondaryOn, secondaryKind, text) {
        resolveSecondaryState(romaTrack, transTrack, secondaryOn, secondaryKind, text)
    }

    val pairedLines = remember(primaryLines, secondaryState.activeText) {
        val secLines = secondaryState.activeText?.let(::parseLrc).orEmpty()
        pairLrcLines(primaryLines, secLines)
    }
    val hasAnyPairedSecondary = remember(primaryLines, romaTrack, transTrack) {
        if (primaryLines.isEmpty()) false
        else {
            val rPaired = romaTrack?.takeIf { it != text }?.let { pairLrcLines(primaryLines, parseLrc(it)) }
                ?.any { it.secondary != null } == true
            val tPaired = transTrack?.takeIf { it != text }?.let { pairLrcLines(primaryLines, parseLrc(it)) }
                ?.any { it.secondary != null } == true
            rPaired || tPaired
        }
    }

    val ink = MaterialTheme.colorScheme.onSurface
    val baseStyle = if (large) {
        MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.ExtraBold, lineHeight = 44.sp)
    } else {
        MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.ExtraBold, lineHeight = 32.sp)
    }
    val primaryStyle = remember(baseStyle, textSize) {
        baseStyle.copy(
            fontSize = baseStyle.fontSize * textSize.scale,
            lineHeight = baseStyle.lineHeight * textSize.scale,
        )
    }
    val subBase = if (large) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyLarge
    val secondaryStyle = remember(subBase, textSize) {
        subBase.copy(
            fontSize = subBase.fontSize * textSize.scale,
            lineHeight = subBase.lineHeight * textSize.scale,
        )
    }

    Column(modifier) {
        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                !loaded -> Text(
                    "Looking for lyrics…",
                    Modifier.padding(24.dp),
                    style = primaryStyle,
                    color = ink.copy(alpha = 0.6f),
                )
                text == null -> Column(
                    Modifier.padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        "No lyrics found for this song.",
                        style = primaryStyle,
                        color = ink.copy(alpha = 0.65f),
                    )
                    OutlinedButton(onClick = { choosing = true }) {
                        AppIcon(Icons.Rounded.Translate, null, Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Choose version")
                    }
                }
                pairedLines.isEmpty() -> PlainLyrics(
                    text = text.orEmpty(),
                    style = primaryStyle,
                    ink = ink,
                    backend = backend,
                    totalMs = song.durationSec * 1000L,
                    modifier = Modifier.fillMaxSize(),
                )
                else -> SyncedLyricsList(
                    songId = id,
                    lines = pairedLines,
                    primaryStyle = primaryStyle,
                    secondaryStyle = secondaryStyle,
                    ink = ink,
                    dark = dark,
                    large = large,
                    backend = backend,
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }

        if (showControls && (loaded && text != null)) {
            val sourceLabel = manualChoice?.source?.takeIf { it.isNotBlank() }
                ?: if (pairedLines.isNotEmpty()) "Synced" else "Plain"
            LyricsControlsStrip(
                sourceLabel = sourceLabel,
                showSecondaryToggle = secondaryState.available && hasAnyPairedSecondary,
                secondaryLabel = secondaryState.chipLabel,
                secondaryActive = secondaryState.active,
                textSize = textSize,
                onOpenVersions = { choosing = true },
                onToggleSecondary = {
                    val (nextOn, nextKind) = nextSecondaryPref(romaTrack, transTrack, secondaryOn, secondaryKind)
                    if (prefs != null) {
                        prefs.putLyricsSecondary(nextOn)
                        prefs.putLyricsSecondaryKind(nextKind)
                    } else {
                        fallbackSecondary = nextOn
                        fallbackKind = nextKind
                    }
                },
                onSelectTextSize = { picked ->
                    if (prefs != null) prefs.putLyricsTextSize(picked) else fallbackTextSize = picked
                },
            )
        }
    }

    if (choosing) {
        LyricsChoiceDialog(
            backend = backend,
            song = song,
            onPicked = { choice ->
                manualChoice = choice
                if (choice == null) {
                    reloadNonce++
                } else {
                    text = choice.text
                    loaded = true
                }
                choosing = false
            },
            onDismiss = { choosing = false },
        )
    }
}

@Composable
private fun SyncedLyricsList(
    songId: String,
    lines: List<PairedLrcLine>,
    primaryStyle: TextStyle,
    secondaryStyle: TextStyle,
    ink: Color,
    dark: Boolean,
    large: Boolean,
    backend: PlayerControls,
    modifier: Modifier = Modifier,
) {
    val reduceMotion = LocalReduceMotion.current
    val pos by backend.position.collectAsState()
    val current by remember(lines) { derivedStateOf { lines.indexOfLast { it.timeMs <= pos.positionMs } } }
    val list = rememberLazyListState()
    val dragged by list.interactionSource.collectIsDraggedAsState()
    var following by remember(songId) { mutableStateOf(true) }

    LaunchedEffect(dragged) { if (dragged) following = false }
    LaunchedEffect(current, following) {
        if (following && current >= 0) {
            val offset = -(list.layoutInfo.viewportSize.height * 0.30f).toInt()
            if (reduceMotion) list.scrollToItem(current, offset)
            else list.animateScrollToItem(current, offset)
        }
    }

    Box(modifier) {
        DesktopScrollHost(list, Modifier.fillMaxSize()) { scrollMod ->
            LazyColumn(
                modifier = scrollMod.lyricsEdgeFade(),
                state = list,
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 72.dp, bottom = 180.dp),
            ) {
            itemsIndexed(lines, key = { i, l -> "${l.timeMs}#$i" }) { i, line ->
                val targetAlpha = lyricsLineAlpha(i, current, dark)
                val alpha by animateFloatAsState(targetAlpha, motionTween(Motion.STANDARD), label = "lyricAlpha")
                val secAlpha = (alpha * 0.78f).coerceIn(0.28f, 0.85f)
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(appShape(14.dp, CornerArea.Cards))
                        .clickable {
                            following = true
                            backend.seekToMs(line.timeMs)
                        }
                        .padding(horizontal = 10.dp, vertical = if (large) 12.dp else 8.dp),
                    verticalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    Text(
                        text = line.text.ifBlank { " " },
                        style = primaryStyle,
                        color = ink.copy(alpha = alpha),
                    )
                    val sec = line.secondary
                    if (!sec.isNullOrBlank()) {
                        Text(
                            text = sec,
                            style = secondaryStyle,
                            color = ink.copy(alpha = secAlpha),
                        )
                    }
                }
            }
        }
        }

        if (lines.isNotEmpty() && !following) {
            Surface(
                onClick = { following = true },
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp),
                shape = RoundedCornerShape(50),
                color = MaterialTheme.colorScheme.secondaryContainer,
                contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
            ) {
                Row(
                    Modifier.heightIn(min = 44.dp).padding(horizontal = 18.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    AppIcon(Icons.Rounded.GraphicEq, null, Modifier.size(18.dp))
                    Text("Sync", style = MaterialTheme.typography.titleSmall)
                }
            }
        }
    }
}

private fun Modifier.lyricsEdgeFade(): Modifier = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        drawRect(
            Brush.verticalGradient(
                0f to Color.Transparent,
                0.08f to Color.Black,
                0.88f to Color.Black,
                1f to Color.Transparent,
            ),
            blendMode = BlendMode.DstIn,
        )
    }

@Composable
private fun LyricsControlsStrip(
    sourceLabel: String,
    showSecondaryToggle: Boolean,
    secondaryLabel: String,
    secondaryActive: Boolean,
    textSize: LyricsTextSize,
    onOpenVersions: () -> Unit,
    onToggleSecondary: () -> Unit,
    onSelectTextSize: (LyricsTextSize) -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val chipShape = appShape(16.dp, CornerArea.Chips)
    var sizeMenuOpen by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Source / version picker chip
        Row(
            modifier = Modifier
                .heightIn(min = 40.dp)
                .clip(chipShape)
                .background(scheme.onSurface.copy(alpha = 0.10f))
                .clickable(role = Role.Button, onClick = onOpenVersions)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                sourceLabel,
                style = MaterialTheme.typography.labelLarge,
                color = scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            AppIcon(Icons.Rounded.ExpandMore, "Choose lyrics version", Modifier.size(18.dp), tint = scheme.onSurfaceVariant)
        }

        if (showSecondaryToggle) {
            Row(
                modifier = Modifier
                    .heightIn(min = 40.dp)
                    .clip(chipShape)
                    .background(if (secondaryActive) scheme.secondaryContainer else Color.Transparent)
                    .then(if (secondaryActive) Modifier else Modifier.border(1.dp, scheme.outlineVariant, chipShape))
                    .semantics { contentDescription = "Toggle $secondaryLabel lyrics" }
                    .toggleable(value = secondaryActive, role = Role.Switch, onValueChange = { onToggleSecondary() })
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AppIcon(
                    Icons.Rounded.Translate,
                    null,
                    Modifier.size(16.dp),
                    tint = if (secondaryActive) scheme.onSecondaryContainer else scheme.onSurface,
                )
                Text(
                    secondaryLabel,
                    style = MaterialTheme.typography.labelLarge,
                    color = if (secondaryActive) scheme.onSecondaryContainer else scheme.onSurface,
                    maxLines = 1,
                )
            }
        }

        Box {
            Box(
                modifier = Modifier
                    .heightIn(min = 40.dp)
                    .clip(chipShape)
                    .background(scheme.onSurface.copy(alpha = 0.10f))
                    .semantics { contentDescription = "Lyrics text size: ${textSize.label}" }
                    .clickable(role = Role.Button, onClick = { sizeMenuOpen = true })
                    .padding(horizontal = 14.dp, vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text("Aa", style = MaterialTheme.typography.labelLarge, color = scheme.onSurface)
            }
            val modernTokens = io.max.paperplay.ui.theme.LocalModernTokens.current
            DropdownMenu(
                expanded = sizeMenuOpen,
                onDismissRequest = { sizeMenuOpen = false },
                containerColor = if (modernTokens.enabled) modernTokens.overlayBg else androidx.compose.material3.MenuDefaults.containerColor,
                tonalElevation = if (modernTokens.enabled) 0.dp else androidx.compose.material3.MenuDefaults.TonalElevation,
                shadowElevation = if (modernTokens.enabled) 0.dp else androidx.compose.material3.MenuDefaults.ShadowElevation,
            ) {
                LyricsTextSize.entries.forEach { size ->
                    DropdownMenuItem(
                        text = { Text(size.label) },
                        trailingIcon = if (size == textSize) {
                            { AppIcon(Icons.Rounded.Check, "Selected", Modifier.size(18.dp), tint = scheme.primary) }
                        } else null,
                        onClick = {
                            onSelectTextSize(size)
                            sizeMenuOpen = false
                        },
                    )
                }
            }
        }
    }
}

/** Lists the versions of this song's lyrics the sources have; picking one keeps it for this song on every linked device. */
@Composable
private fun LyricsChoiceDialog(
    backend: PlayerControls,
    song: SongUi,
    onPicked: (LyricsChoiceUi?) -> Unit,
    onDismiss: () -> Unit,
) {
    var choices by remember(song.id) { mutableStateOf<List<LyricsChoiceUi>?>(null) }
    LaunchedEffect(song.id) { choices = backend.lyricsChoices(song.id) }
    val shape = appShape(28.dp, CornerArea.Dialogs)
    val modernTokens = io.max.paperplay.ui.theme.LocalModernTokens.current

    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = overlayRim(shape),
        shape = shape,
        containerColor = if (modernTokens.enabled) modernTokens.overlayBg else overlayColor(),
        tonalElevation = if (modernTokens.enabled) 0.dp else androidx.compose.material3.AlertDialogDefaults.TonalElevation,
        title = { Text("Choose lyrics") },
        text = {
            val list = choices
            when {
                list == null -> Text("Looking for versions…", color = MaterialTheme.colorScheme.onSurfaceVariant)
                list.isEmpty() -> Text("No other versions found.", color = MaterialTheme.colorScheme.onSurfaceVariant)
                else -> LazyColumn(Modifier.fillMaxWidth().heightIn(max = 360.dp)) {
                    itemsIndexed(list) { idx, c ->
                        if (idx > 0) RowDivider()
                        val sub = buildString {
                            append(c.preview)
                            val extras = listOfNotNull(
                                if (c.romanized != null) "Romanized" else null,
                                if (c.translation != null) "Translation" else null,
                            )
                            if (extras.isNotEmpty()) append("\nIncludes ${extras.joinToString(" & ")}")
                        }
                        SettingsRow(
                            title = c.label,
                            subtitle = sub,
                            onClick = {
                                backend.chooseLyrics(song.id, c.text)
                                onPicked(c)
                            },
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onDismiss) { Text("Close") } },
        dismissButton = {
            TextButton({
                backend.chooseLyrics(song.id, null)
                onPicked(null)
            }) { Text("Automatic") }
        },
    )
}

/**
 * Lyrics with no timestamps (any language) cannot be followed line by line, so they drift down in step with the song: the scroll
 * position tracks the share of the song played. Dragging them takes over; after a few quiet seconds they follow the song again.
 */
@Composable
private fun PlainLyrics(
    text: String,
    style: TextStyle,
    ink: Color,
    backend: PlayerControls,
    totalMs: Long,
    modifier: Modifier,
) {
    val reduceMotion = LocalReduceMotion.current
    val scroll = rememberScrollState()
    val pos = backend.position.collectAsState()
    val dragged by scroll.interactionSource.collectIsDraggedAsState()
    var following by remember(text) { mutableStateOf(true) }

    LaunchedEffect(dragged) {
        if (dragged) following = false
        else if (!following) {
            delay(6000)
            following = true
        }
    }
    val driftSpec = io.max.paperplay.ui.theme.motionLinearTween<Float>(Motion.Ambient.PlainLyricsDriftMs)
    LaunchedEffect(text, following) {
        snapshotFlow {
            // The first and last stretch of a song are usually instrumental, so the text is spread over the middle.
            val played = if (totalMs > 0) pos.value.positionMs.toFloat() / totalMs else 0f
            (((played - 0.05f) / 0.88f).coerceIn(0f, 1f) * scroll.maxValue).toInt()
        }.collect { target ->
            if (following) {
                if (reduceMotion) scroll.scrollTo(target)
                else scroll.animateScrollTo(target, driftSpec)
            }
        }
    }
    Column(modifier.lyricsEdgeFade().verticalScroll(scroll).padding(horizontal = 24.dp, vertical = 48.dp)) {
        Text(text, style = style, color = ink)
    }
}

/**
 * Phone full-screen lyrics page launched from [FullPlayer], with a cover-tinted backdrop,
 * compact song header, shared [LyricsPane], and compact playback dock.
 */
@Composable
internal fun FullLyricsPage(
    state: PlaybackUiState,
    backend: PlayerControls,
    actions: ListActions,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val song = state.current ?: return
    val base = MaterialTheme.colorScheme
    val dark = base.surface.luminance() < 0.5f
    val modernTokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val baseScheme = coverScheme(song.coverUri, dark = dark)
        ?: remember(base.primary, dark) { schemeFromSeed(base.primary.toArgb(), dark = dark) }
    val scheme = remember(baseScheme, dark, modernTokens.amoled) {
        if (dark && modernTokens.amoled) baseScheme.amoled() else baseScheme
    }
    val reduceMotion = LocalReduceMotion.current
    val topColor by animateColorAsState(
        lerp(scheme.primaryContainer, scheme.surface, if (dark) 0.28f else 0.42f),
        motionTween(Motion.EMPHASIZED),
        label = "lyricsTop",
    )
    val midColor by animateColorAsState(
        lerp(scheme.surfaceContainerLow, scheme.surface, if (dark) 0.55f else 0.65f),
        motionTween(Motion.EMPHASIZED),
        label = "lyricsMid",
    )
    val topInset = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()

    MaterialTheme(colorScheme = scheme) {
        val ink = MaterialTheme.colorScheme.onSurface
        Column(
            modifier = modifier
                .fillMaxSize()
                .blockTouchesBehind()
                .background(Brush.verticalGradient(0f to topColor, 0.55f to midColor, 1f to scheme.surface))
                .padding(top = topInset, bottom = bottomInset),
        ) {
            // Compact header: collapse, cover, song identity, favorite, overflow menu
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 4.dp, end = 8.dp, top = 6.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                IconButton(onClose) {
                    AppIcon(Icons.Rounded.KeyboardArrowDown, "Close lyrics", tint = ink)
                }
                CoverImage(song.coverUri, song.id, size = 40.dp, radius = 8.dp)
                Column(Modifier.weight(1f).padding(start = 8.dp)) {
                    Text(
                        song.title,
                        modifier = Modifier.basicMarquee(),
                        maxLines = 1,
                        style = MaterialTheme.typography.titleMedium,
                        color = ink,
                    )
                    Text(
                        song.artist,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodySmall,
                        color = ink.copy(alpha = 0.72f),
                    )
                }
                IconButton({ actions.setFavorite(song, !song.favorite) }) {
                    AppIcon(
                        if (song.favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                        if (song.favorite) "Remove from favorites" else "Add to favorites",
                        tint = if (song.favorite) scheme.primary else ink,
                    )
                }
                SongMenu(song, actions.rowActions(), Icons.Rounded.MoreHoriz)
            }

            LyricsPane(
                song = song,
                backend = backend,
                large = false,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            )

            // Compact playback dock
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                PlayerProgress(song, state, backend, onBadge = null)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    IconButton(backend::toggleShuffle) {
                        AppIcon(
                            Icons.Rounded.Shuffle,
                            "Shuffle",
                            tint = if (state.shuffle) toggleOnColor() else ink.copy(alpha = 0.78f),
                        )
                    }
                    IconButton(backend::previous) {
                        AppIcon(Icons.Rounded.FastRewind, "Previous", Modifier.size(30.dp), tint = ink)
                    }
                    IconButton(backend::togglePlay, Modifier.size(60.dp)) {
                        AppIcon(
                            if (state.playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                            if (state.playing) "Pause" else "Play",
                            Modifier.size(42.dp),
                            tint = ink,
                        )
                    }
                    IconButton(backend::next) {
                        AppIcon(Icons.Rounded.FastForward, "Next", Modifier.size(30.dp), tint = ink)
                    }
                    IconButton(backend::cycleRepeat) {
                        AppIcon(
                            if (state.repeat == RepeatUi.One) Icons.Rounded.RepeatOne else Icons.Rounded.Repeat,
                            "Repeat",
                            tint = if (state.repeat != RepeatUi.Off) toggleOnColor() else ink.copy(alpha = 0.78f),
                        )
                    }
                }
            }
        }
    }
    if (reduceMotion) {
        // Keep parameter read explicit for compose stability
    }
}

/** Lyrics filling the whole content area on desktop, with the song named at the top and a way back. */
@Composable
fun FullLyricsView(song: SongUi, backend: PlayerControls, onClose: () -> Unit, modifier: Modifier = Modifier) {
    val ink = MaterialTheme.colorScheme.onSurface
    Column(modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            IconButton(onClose) { AppIcon(Icons.Rounded.KeyboardArrowDown, "Close lyrics", tint = ink) }
            CoverImage(song.coverUri, song.id, size = 36.dp, radius = 8.dp)
            Column(Modifier.weight(1f)) {
                Text(song.title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleMedium, color = ink)
                Text(song.artist, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = ink.copy(alpha = 0.7f))
            }
        }
        LyricsPane(song, backend, large = true, modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 48.dp))
    }
}

private val previewJpSong = SongUi(
    id = "jp1",
    title = "Sing Alive",
    artist = "Roselia",
    album = "Sing Alive",
    durationSec = 315,
)

private const val previewJpLrc = """[00:10.00]頂点へと続く未来まで
[00:16.00]信じるままに 一歩ずつ
[00:22.00]I sing, alive
[00:28.00]貴方の想い 私の想い 全てはひとつ 始めから"""

private const val previewJpRoma = """[00:10.00]chouten he to tsuzuku mirai made
[00:16.00]shinjiru mama ni ippo zutsu
[00:22.00]I sing, alive
[00:28.00]anata no omoi watashi no omoi subete wa hitotsu hajime kara"""

@Preview(name = "Full lyrics phone dark", widthDp = 390, heightDp = 844)
@Composable
private fun FullLyricsPhoneDarkPreview() = PreviewFrame(dark = true) {
    FullLyricsPage(previewPlayback(), FakePlayerControls(), previewActions(), onClose = {})
}

@Preview(name = "Full lyrics phone light", widthDp = 390, heightDp = 844)
@Composable
private fun FullLyricsPhoneLightPreview() = PreviewFrame(dark = false) {
    FullLyricsPage(previewPlayback(), FakePlayerControls(), previewActions(), onClose = {})
}

@Preview(name = "Full lyrics desktop", widthDp = 900, heightDp = 600)
@Composable
private fun FullLyricsDesktopPreview() = PreviewFrame(dark = true) {
    FullLyricsView(previewSongs[0], FakePlayerControls(), onClose = {})
}

@Preview(name = "Lyrics Japanese + romanized", widthDp = 390, heightDp = 844)
@Composable
private fun LyricsJapaneseRomanizedPreview() = PreviewFrame(dark = true) {
    FullLyricsPage(
        state = PlaybackUiState(current = previewJpSong, playing = true, durationMs = 315_000, queue = listOf(previewJpSong), queueIndex = 0),
        backend = FakePlayerControls(
            position = io.max.paperplay.ui.state.PositionUi(23_000, 120_000),
            lyrics = previewJpLrc,
            lyricsSecondary = LyricsSecondaryUi(romanized = previewJpRoma),
        ),
        actions = previewActions(),
        onClose = {},
    )
}

@Preview(name = "Lyrics plain", widthDp = 390, heightDp = 700)
@Composable
private fun LyricsPlainPreview() = PreviewFrame(dark = true) {
    LyricsPane(
        song = previewSongs[0],
        backend = FakePlayerControls(lyrics = "Line one without timestamps\nLine two without timestamps\nLine three without timestamps"),
        large = false,
        modifier = Modifier.fillMaxSize(),
    )
}

@Preview(name = "Lyrics loading", widthDp = 390, heightDp = 500)
@Composable
private fun LyricsLoadingPreview() = PreviewFrame(dark = true) {
    LyricsPane(
        song = previewSongs[0],
        backend = FakePlayerControls(lyrics = null),
        large = false,
        modifier = Modifier.fillMaxSize(),
    )
}

@Preview(name = "Lyrics empty", widthDp = 390, heightDp = 500)
@Composable
private fun LyricsEmptyPreview() = PreviewFrame(dark = true) {
    LyricsPane(
        song = previewSongs[0],
        backend = FakePlayerControls(lyrics = null),
        large = false,
        modifier = Modifier.fillMaxSize(),
    )
}
