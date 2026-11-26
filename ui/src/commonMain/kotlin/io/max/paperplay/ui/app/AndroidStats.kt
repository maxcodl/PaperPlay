package io.max.paperplay.ui.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Album
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Schedule
import androidx.compose.material.icons.rounded.Style
import androidx.compose.material3.Button
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.core.library.ListenTotal
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.components.LocalInsideModernSurface
import io.max.paperplay.ui.components.ModernScallopedBadge
import io.max.paperplay.ui.components.SongRow
import io.max.paperplay.ui.components.modernSurfaceStatic
import io.max.paperplay.ui.theme.LocalModernTokens
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.Motion
import io.max.paperplay.ui.theme.PaperPlayTheme
import io.max.paperplay.ui.theme.motionEffectTween
import io.max.paperplay.ui.theme.pressScale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.jetbrains.compose.ui.tooling.preview.Preview

internal sealed interface StatsUiState {
    data object Loading : StatsUiState
    data class Ready(val data: StatsPageData) : StatsUiState
    data class Error(val message: String) : StatsUiState
}

private data class HighlightCardData(
    val label: String,
    val value: String,
    val detail: String,
    val icon: ImageVector,
    val progress: Float? = null,
)

private val statsSpans = listOf("All time" to 0, "30 days" to 30, "7 days" to 7)

/**
 * Unified Android Listening Statistics screen shared by [UiStyle.Default] and [UiStyle.Modern].
 * Uses one lazy list, cached off-main-thread queries, real-only highlights, and `SongRow` reuse.
 */
@Composable
internal fun AndroidStatsScreen(
    backend: CoreBackend,
    onBack: () -> Unit,
    onStartListening: () -> Unit,
    bottomPadding: Dp,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val previewOverride by uiPreviewOverride.collectAsState()
    var selectedDays by rememberSaveable { mutableIntStateOf(0) }
    var retryTick by remember { mutableIntStateOf(0) }
    var uiState by remember(backend, selectedDays) {
        mutableStateOf<StatsUiState>(
            backend.cachedStatsPages.value[selectedDays]?.let { StatsUiState.Ready(it) } ?: StatsUiState.Loading,
        )
    }

    LaunchedEffect(backend, selectedDays, retryTick) {
        val cached = backend.cachedStatsPages.value[selectedDays]
        if (cached != null) {
            uiState = StatsUiState.Ready(cached)
        } else {
            uiState = StatsUiState.Loading
        }
        val loaded = withContext(Dispatchers.Default) {
            runCatching { backend.statsPageData(selectedDays) }
        }
        uiState = loaded.fold(
            onSuccess = { StatsUiState.Ready(it) },
            onFailure = { e -> StatsUiState.Error(e.message ?: "Could not load statistics") },
        )
    }

    val effectiveState = when (previewOverride) {
        UiPreviewOverride.Loading -> StatsUiState.Loading
        UiPreviewOverride.Empty -> StatsUiState.Ready(emptyStatsPageData(selectedDays))
        UiPreviewOverride.Error -> StatsUiState.Error("Simulated statistics error")
        UiPreviewOverride.Live, UiPreviewOverride.NoAvatar -> uiState
    }

    val pb by backend.playback.collectAsState()
    val currentId = pb.current?.id
    val actions = LocalListActions.current

    val readyData = (effectiveState as? StatsUiState.Ready)?.data
    val summaryLine = when (effectiveState) {
        StatsUiState.Loading -> null
        is StatsUiState.Error -> "Could not load summary"
        is StatsUiState.Ready -> {
            val d = effectiveState.data
            if (d.totalMs <= 0L && d.topSongs.isEmpty()) "No listening history yet"
            else buildStatsSummaryLine(d.totalPlays, d.distinctSongs, d.totalMs)
        }
    }

    val playableSongs = remember(readyData?.topSongs) {
        readyData?.topSongs?.mapNotNull { it.song }.orEmpty()
    }
    val playableIndexById = remember(playableSongs) {
        playableSongs.mapIndexed { idx, s -> s.id to idx }.toMap()
    }

    val highlights = remember(readyData?.insights) {
        readyData?.insights?.let(::buildHighlights).orEmpty()
    }
    val largeFont = LocalDensity.current.fontScale >= 1.5f

    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 8.dp, bottom = bottomPadding + 32.dp),
        verticalArrangement = Arrangement.spacedBy(if (modern) 20.dp else 16.dp),
    ) {
        item(key = "stats_header", contentType = "header") {
            StatsHeader(
                modern = modern,
                summaryLine = summaryLine,
                onBack = onBack,
            )
        }

        item(key = "stats_spans", contentType = "spans") {
            StatsSpanRow(
                selectedDays = selectedDays,
                modern = modern,
                onSelect = { selectedDays = it },
            )
        }

        when (effectiveState) {
            StatsUiState.Loading -> {
                item(key = "stats_skeleton", contentType = "skeleton") {
                    StatsLoadingSkeleton(modern = modern)
                }
            }
            is StatsUiState.Error -> {
                item(key = "stats_error", contentType = "state_card") {
                    StatsErrorCard(
                        message = effectiveState.message,
                        onRetry = {
                            uiPreviewOverride.value = UiPreviewOverride.Live
                            retryTick++
                        },
                    )
                }
            }
            is StatsUiState.Ready -> {
                val data = effectiveState.data
                if (data.totalMs <= 0L && data.topSongs.isEmpty()) {
                    item(key = "stats_empty", contentType = "state_card") {
                        StatsEmptyCard(
                            days = selectedDays,
                            onStartListening = onStartListening,
                        )
                    }
                } else {
                    data.heroSong?.let { hero ->
                        item(key = "stats_hero", contentType = "hero") {
                            StatsHeroSongCard(
                                hero = hero,
                                modern = modern,
                                canPlay = hero.song != null && actions != null,
                                onPlay = {
                                    val song = hero.song ?: return@StatsHeroSongCard
                                    val idx = playableIndexById[song.id] ?: 0
                                    if (playableSongs.isNotEmpty()) actions?.play(playableSongs, idx)
                                    else actions?.play(listOf(song), 0)
                                },
                                modifier = Modifier.statsStaggerIn(0),
                            )
                        }
                    }

                    item(key = "stats_time_streaks", contentType = "time_streaks") {
                        StatsTimeAndStreaksSection(
                            data = data,
                            modern = modern,
                            largeFont = largeFont,
                            modifier = Modifier.statsStaggerIn(1),
                        )
                    }

                    if (highlights.isNotEmpty()) {
                        item(key = "stats_highlights", contentType = "highlights") {
                            StatsHighlightsSection(
                                items = highlights,
                                modern = modern,
                                largeFont = largeFont,
                                modifier = Modifier.statsStaggerIn(2),
                            )
                        }
                    }

                    if (data.topSongs.isNotEmpty()) {
                        item(key = "stats_top_songs_header", contentType = "section_header") {
                            StatsSectionHeader("Top songs")
                        }
                        itemsIndexed(
                            items = data.topSongs,
                            key = { idx, item -> "top_song_${item.total.key}_$idx" },
                            contentType = { _, _ -> "top_song_row" },
                        ) { _, entry ->
                            val song = entry.song
                            if (song != null) {
                                val playIdx = playableIndexById[song.id] ?: 0
                                SongRow(
                                    song = song,
                                    onClick = {
                                        if (playableSongs.isNotEmpty()) actions?.play(playableSongs, playIdx)
                                    },
                                    onLongClick = {},
                                    current = song.id == currentId,
                                    modifier = Modifier.padding(horizontal = 16.dp),
                                )
                            } else {
                                StatsFallbackSongRow(
                                    total = entry.total,
                                    modern = modern,
                                )
                            }
                        }
                    }

                    if (data.topArtists.isNotEmpty()) {
                        item(key = "stats_top_artists", contentType = "top_artists") {
                            StatsTopArtistsSection(
                                artists = data.topArtists.take(5),
                                modern = modern,
                            )
                        }
                    }

                    if (data.topAlbums.isNotEmpty()) {
                        item(key = "stats_top_albums", contentType = "top_albums") {
                            StatsTopAlbumsSection(
                                albums = data.topAlbums.take(5),
                                modern = modern,
                            )
                        }
                    }
                }
            }
        }
    }
}

private fun emptyStatsPageData(days: Int) = StatsPageData(
    days = days,
    totalMs = 0L,
    totalPlays = 0L,
    distinctSongs = 0,
    heroSong = null,
    topSongs = emptyList(),
    topArtists = emptyList(),
    topAlbums = emptyList(),
    insights = ListeningInsights(
        currentStreak = 0,
        longestStreak = 0,
        listenedToday = false,
        busiestDay = null,
        peakTime = null,
        topGenre = null,
        libraryExplored = null,
        topArtists = emptyList(),
        topAlbums = emptyList(),
    ),
)

private fun buildHighlights(ins: ListeningInsights): List<HighlightCardData> = buildList {
    ins.peakTime?.let { pt ->
        add(
            HighlightCardData(
                label = "Peak time",
                value = pt.weekday,
                detail = pt.bucket ?: "Most active day",
                icon = Icons.Rounded.Schedule,
            ),
        )
    }
    ins.busiestDay?.let { bd ->
        val detail = if (bd.plays > 0L) {
            if (bd.plays == 1L) "1 play" else "${bd.plays} plays"
        } else {
            fmtCompactTime(bd.ms)
        }
        add(
            HighlightCardData(
                label = "Busiest day",
                value = bd.dateLabel,
                detail = detail,
                icon = Icons.Rounded.CalendarMonth,
            ),
        )
    }
    ins.topGenre?.let { tg ->
        add(
            HighlightCardData(
                label = "Top genre",
                value = tg.name,
                detail = "${tg.percent}% of tagged listens",
                icon = Icons.Rounded.Style,
            ),
        )
    }
    ins.libraryExplored?.let { le ->
        add(
            HighlightCardData(
                label = "Library explored",
                value = "${le.percent}%",
                detail = "${le.exploredSongs} of ${le.totalSongs} songs",
                icon = Icons.Rounded.LibraryMusic,
                progress = le.fraction,
            ),
        )
    }
}

@Composable
private fun StatsHeader(
    modern: Boolean,
    summaryLine: String?,
    onBack: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (modern) {
            Box(
                Modifier
                    .size(48.dp)
                    .then(modernSurfaceStatic(tokens.cardBgElevated, CircleShape))
                    .clickable(role = Role.Button, onClick = onBack)
                    .semantics { contentDescription = "Back" },
                contentAlignment = Alignment.Center,
            ) {
                AppIcon(Icons.Rounded.ChevronRight, null, Modifier.graphicsLayer { rotationZ = 180f }, tint = tokens.onGlass)
            }
        } else {
            IconButton(onClick = onBack, modifier = Modifier.size(48.dp)) {
                AppIcon(Icons.Rounded.ChevronRight, "Back", Modifier.graphicsLayer { rotationZ = 180f })
            }
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = "Listening statistics",
                style = if (modern) {
                    MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.ExtraBold)
                } else {
                    MaterialTheme.typography.headlineSmall
                },
                color = if (modern) tokens.onGlass else scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (summaryLine != null) {
                Text(
                    text = summaryLine,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            } else {
                Box(Modifier.width(128.dp).height(14.dp).skeleton(CircleShape))
            }
        }
    }
}

@Composable
private fun StatsSpanRow(
    selectedDays: Int,
    modern: Boolean,
    onSelect: (Int) -> Unit,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val pillShape = appShape(50.dp, CornerArea.Chips)
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        statsSpans.forEach { (label, days) ->
            val selected = days == selectedDays
            val bg = when {
                modern && selected -> tokens.pillSelectedBg
                modern -> tokens.chipBg
                selected -> scheme.primaryContainer
                else -> scheme.surfaceContainerLow
            }
            val fg = when {
                modern && selected -> tokens.onGlass
                modern -> tokens.onGlassMuted
                selected -> scheme.onPrimaryContainer
                else -> scheme.onSurfaceVariant
            }
            Box(
                Modifier
                    .defaultMinSize(minHeight = 48.dp)
                    .clip(pillShape)
                    .background(bg, pillShape)
                    .clickable(role = Role.Tab) { onSelect(days) }
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelLarge.copy(
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                    ),
                    color = fg,
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun StatsSurfaceCard(
    modifier: Modifier = Modifier,
    shape: Shape = appShape(26.dp, CornerArea.Cards),
    fillOverride: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val tokens = LocalModernTokens.current
    val cardMod = if (tokens.enabled) {
        modifier.fillMaxWidth().then(modernSurfaceStatic(fillOverride ?: tokens.cardBg, shape))
    } else {
        modifier.fillMaxWidth().partSurface(LookGroup.Cards, fillOverride ?: MaterialTheme.colorScheme.surfaceContainerLow, shape)
    }
    Column(cardMod) {
        CompositionLocalProvider(LocalInsideModernSurface provides tokens.enabled) {
            content()
        }
    }
}

@Composable
private fun StatsHeroSongCard(
    hero: StatsSongEntry,
    modern: Boolean,
    canPlay: Boolean,
    onPlay: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val press = remember { MutableInteractionSource() }
    val heroFill = if (modern) {
        lerp(tokens.cardBgElevated, scheme.primaryContainer, if (tokens.dark) 0.30f else 0.38f)
    } else {
        scheme.surfaceContainerLow
    }
    val title = hero.song?.title?.takeIf { it.isNotBlank() } ?: hero.total.title?.takeIf { it.isNotBlank() } ?: "Unknown song"
    val artist = hero.song?.artist?.takeIf { it.isNotBlank() } ?: hero.total.artist.orEmpty()
    val album = hero.song?.album?.takeIf { it.isNotBlank() }
    val subtitle = if (album != null && artist.isNotBlank()) "$artist · $album" else artist.ifBlank { album.orEmpty() }
    val chipText = if (hero.total.plays > 0L) {
        if (hero.total.plays == 1L) "1 play" else "${hero.total.plays} plays"
    } else {
        fmtCompactTime(hero.total.ms)
    }
    val chipShape = appShape(50.dp, CornerArea.Chips)

    StatsSurfaceCard(
        modifier = modifier
            .padding(horizontal = 16.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .semantics(mergeDescendants = true) {
                contentDescription = "Your number one song, $title by $artist, $chipText"
            },
        shape = appShape(28.dp, CornerArea.Cards),
        fillOverride = heroFill,
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .then(
                    if (canPlay) Modifier.clickable(
                        interactionSource = press,
                        indication = androidx.compose.foundation.LocalIndication.current,
                        onClick = onPlay,
                    ) else Modifier,
                )
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            CoverImage(hero.song?.coverUri, hero.song?.album ?: hero.total.key, size = 84.dp, radius = 18.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = "YOUR #1 SONG",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = if (modern) tokens.accentOnGlass else scheme.primary,
                    maxLines = 1,
                )
                Text(
                    text = title,
                    style = if (modern) {
                        MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold)
                    } else {
                        MaterialTheme.typography.titleLarge
                    },
                    color = if (modern) tokens.onGlass else scheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (subtitle.isNotBlank()) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Box(
                    Modifier
                        .padding(top = 2.dp)
                        .clip(chipShape)
                        .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh, chipShape)
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text(
                        text = chipText,
                        style = MaterialTheme.typography.labelMedium,
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                        maxLines = 1,
                    )
                }
            }
            if (canPlay) {
                if (modern) {
                    ModernScallopedBadge(
                        size = 48.dp,
                        containerColor = scheme.primary,
                        contentColor = scheme.onPrimary,
                    )
                } else {
                    Box(
                        Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(scheme.primary, CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        AppIcon(Icons.Rounded.PlayArrow, "Play #1 song", Modifier.size(24.dp), tint = scheme.onPrimary)
                    }
                }
            }
        }
    }
}

@Composable
private fun StatsTimeAndStreaksSection(
    data: StatsPageData,
    modern: Boolean,
    largeFont: Boolean,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val reduceMotion = LocalReduceMotion.current
    val animatedMs by animateFloatAsState(
        targetValue = data.totalMs.toFloat(),
        animationSpec = if (reduceMotion) {
            motionEffectTween(1)
        } else {
            motionEffectTween(Motion.Effects.WashMs, easing = Motion.Emphasized)
        },
        label = "statsTimeCount",
    )
    val shownMs = if (reduceMotion) data.totalMs else animatedMs.toLong()
    val curStreak = data.insights.currentStreak
    val bestStreak = data.insights.longestStreak
    val curLabel = if (curStreak == 1) "1 day" else "$curStreak days"
    val bestLabel = if (bestStreak == 1) "1 day" else "$bestStreak days"

    val timeCard: @Composable (Modifier) -> Unit = { cardMod ->
        StatsSurfaceCard(
            modifier = cardMod.semantics(mergeDescendants = true) {
                contentDescription = "Listening time, ${fmtSpokenTime(data.totalMs)}, ${data.totalPlays} total plays"
            },
        ) {
            Column(
                Modifier.fillMaxSize().padding(16.dp),
                verticalArrangement = Arrangement.SpaceBetween,
            ) {
                Box(
                    Modifier
                        .size(36.dp)
                        .clip(appShape(12.dp, CornerArea.Chips))
                        .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh, appShape(12.dp, CornerArea.Chips)),
                    contentAlignment = Alignment.Center,
                ) {
                    AppIcon(Icons.Rounded.Schedule, null, Modifier.size(18.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
                }
                Column(Modifier.padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = fmtCompactTime(shownMs),
                        style = if (modern) {
                            MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.ExtraBold)
                        } else {
                            MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.SemiBold)
                        },
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = "Listening time",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                        maxLines = 1,
                    )
                }
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    AppIcon(Icons.Rounded.PlayArrow, null, Modifier.size(15.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
                    Text(
                        text = if (data.totalPlays == 1L) "1 total play" else "${data.totalPlays} total plays",
                        style = MaterialTheme.typography.labelMedium,
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }
    }

    val streakCards: @Composable (Modifier) -> Unit = { colMod ->
        Column(colMod, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            StatsMiniStreakCard(
                label = "Current streak",
                value = curLabel,
                icon = Icons.Rounded.LocalFireDepartment,
                modern = modern,
                modifier = Modifier.weight(1f),
            )
            StatsMiniStreakCard(
                label = "Longest streak",
                value = bestLabel,
                icon = Icons.Rounded.EmojiEvents,
                modern = modern,
                modifier = Modifier.weight(1f),
            )
        }
    }

    if (largeFont) {
        Column(modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            timeCard(Modifier.fillMaxWidth())
            StatsMiniStreakCard("Current streak", curLabel, Icons.Rounded.LocalFireDepartment, modern, Modifier.fillMaxWidth())
            StatsMiniStreakCard("Longest streak", bestLabel, Icons.Rounded.EmojiEvents, modern, Modifier.fillMaxWidth())
        }
    } else {
        Row(
            modifier.padding(horizontal = 16.dp).height(IntrinsicSize.Min),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            timeCard(Modifier.weight(1f).fillMaxHeight())
            streakCards(Modifier.weight(1f).fillMaxHeight())
        }
    }
}

@Composable
private fun StatsMiniStreakCard(
    label: String,
    value: String,
    icon: ImageVector,
    modern: Boolean,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    StatsSurfaceCard(
        modifier = modifier.semantics(mergeDescendants = true) {
            contentDescription = "$label, $value"
        },
        shape = appShape(22.dp, CornerArea.Cards),
    ) {
        Column(Modifier.fillMaxSize().padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AppIcon(icon, null, Modifier.size(16.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelMedium,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = value,
                style = if (modern) {
                    MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold)
                } else {
                    MaterialTheme.typography.titleLarge
                },
                color = if (modern) tokens.onGlass else scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

@Composable
private fun StatsHighlightsSection(
    items: List<HighlightCardData>,
    modern: Boolean,
    largeFont: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        StatsSectionHeader("Highlights")
        if (largeFont) {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items.forEach { item -> StatsHighlightCard(item, modern, Modifier.fillMaxWidth()) }
            }
        } else {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items.chunked(2).forEach { rowItems ->
                    Row(
                        Modifier.fillMaxWidth().height(IntrinsicSize.Min),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        rowItems.forEach { item ->
                            StatsHighlightCard(item, modern, Modifier.weight(1f).fillMaxHeight())
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun StatsHighlightCard(
    item: HighlightCardData,
    modern: Boolean,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    StatsSurfaceCard(
        modifier = modifier.semantics(mergeDescendants = true) {
            contentDescription = "${item.label}, ${item.value}, ${item.detail}"
        },
        shape = appShape(22.dp, CornerArea.Cards),
    ) {
        Column(
            Modifier.fillMaxSize().padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                AppIcon(item.icon, null, Modifier.size(16.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
                Text(
                    text = item.label,
                    style = MaterialTheme.typography.labelMedium,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = item.value,
                style = if (modern) {
                    MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold)
                } else {
                    MaterialTheme.typography.titleMedium
                },
                color = if (modern) tokens.onGlass else scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = item.detail,
                style = MaterialTheme.typography.bodySmall,
                color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (item.progress != null) {
                val trackColor = if (modern) tokens.chipBg else scheme.surfaceContainerHigh
                val fillColor = if (modern) tokens.accentOnGlass else scheme.primary
                Box(
                    Modifier
                        .padding(top = 2.dp)
                        .fillMaxWidth()
                        .height(6.dp)
                        .clip(CircleShape)
                        .background(trackColor, CircleShape),
                ) {
                    Box(
                        Modifier
                            .fillMaxWidth(item.progress.coerceIn(0f, 1f))
                            .fillMaxHeight()
                            .clip(CircleShape)
                            .background(fillColor, CircleShape),
                    )
                }
            }
        }
    }
}

@Composable
private fun StatsSectionHeader(title: String) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    Text(
        text = title,
        modifier = Modifier.padding(horizontal = 20.dp),
        style = if (modern) {
            MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold)
        } else {
            MaterialTheme.typography.titleSmall
        },
        color = if (modern) tokens.onGlass else MaterialTheme.colorScheme.primary,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

@Composable
private fun StatsFallbackSongRow(
    total: ListenTotal,
    modern: Boolean,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val shape = appShape(if (modern) 18.dp else 16.dp)
    val mod = if (modern) {
        Modifier.padding(horizontal = 16.dp).fillMaxWidth().then(modernSurfaceStatic(tokens.rowBg, shape))
    } else {
        Modifier.padding(horizontal = 16.dp).fillMaxWidth().partSurface(LookGroup.Cards, scheme.surfaceContainerLow, shape)
    }
    Row(
        mod.defaultMinSize(minHeight = 64.dp).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier
                .size(48.dp)
                .clip(appShape(10.dp, CornerArea.Covers))
                .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh, appShape(10.dp, CornerArea.Covers)),
            contentAlignment = Alignment.Center,
        ) {
            AppIcon(Icons.Rounded.MusicNote, null, tint = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant)
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = total.title ?: "Unknown song",
                style = MaterialTheme.typography.titleMedium,
                color = if (modern) tokens.onGlass else scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (!total.artist.isNullOrBlank()) {
                Text(
                    text = total.artist!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Text(
            text = fmtCompactTime(total.ms),
            style = MaterialTheme.typography.labelMedium,
            color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun StatsTopArtistsSection(
    artists: List<StatsArtistEntry>,
    modern: Boolean,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        StatsSectionHeader("Top artists")
        StatsSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
            artists.forEachIndexed { idx, artist ->
                if (idx > 0) {
                    if (modern) Spacer(Modifier.height(2.dp)) else RowDivider()
                }
                Row(
                    Modifier.fillMaxWidth().defaultMinSize(minHeight = 56.dp).padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    if (artist.coverUri != null) {
                        CoverImage(artist.coverUri, artist.artist, size = 40.dp, radius = 20.dp)
                    } else {
                        Box(
                            Modifier.size(40.dp).clip(CircleShape).background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            AppIcon(Icons.Rounded.Headphones, null, Modifier.size(18.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
                        }
                    }
                    Text(
                        text = artist.artist,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.titleMedium,
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = fmtCompactTime(artist.ms),
                        style = MaterialTheme.typography.labelLarge,
                        color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun StatsTopAlbumsSection(
    albums: List<StatsAlbumEntry>,
    modern: Boolean,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        StatsSectionHeader("Top albums")
        StatsSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
            albums.forEachIndexed { idx, album ->
                if (idx > 0) {
                    if (modern) Spacer(Modifier.height(2.dp)) else RowDivider()
                }
                Row(
                    Modifier.fillMaxWidth().defaultMinSize(minHeight = 60.dp).padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    if (album.coverUri != null) {
                        CoverImage(album.coverUri, album.album, size = 44.dp, radius = 10.dp)
                    } else {
                        val coverShape = appShape(10.dp, CornerArea.Covers)
                        Box(
                            Modifier.size(44.dp).clip(coverShape).background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh, coverShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            AppIcon(Icons.Rounded.Album, null, Modifier.size(20.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
                        }
                    }
                    Column(Modifier.weight(1f)) {
                        Text(
                            text = album.album,
                            style = MaterialTheme.typography.titleMedium,
                            color = if (modern) tokens.onGlass else scheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (album.artist.isNotBlank()) {
                            Text(
                                text = album.artist,
                                style = MaterialTheme.typography.bodySmall,
                                color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                    Text(
                        text = fmtCompactTime(album.ms),
                        style = MaterialTheme.typography.labelLarge,
                        color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun StatsLoadingSkeleton(modern: Boolean) {
    val cardShape = appShape(26.dp, CornerArea.Cards)
    val smallShape = appShape(22.dp, CornerArea.Cards)
    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(Modifier.fillMaxWidth().height(120.dp).skeleton(appShape(28.dp, CornerArea.Cards)))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.weight(1f).height(160.dp).skeleton(cardShape))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.fillMaxWidth().height(74.dp).skeleton(smallShape))
                Box(Modifier.fillMaxWidth().height(74.dp).skeleton(smallShape))
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f).height(88.dp).skeleton(smallShape))
            Box(Modifier.weight(1f).height(88.dp).skeleton(smallShape))
        }
        repeat(4) {
            Box(Modifier.fillMaxWidth().height(64.dp).skeleton(appShape(if (modern) 18.dp else 16.dp)))
        }
    }
}

@Composable
private fun StatsEmptyCard(
    days: Int,
    onStartListening: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    StatsSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
        Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(if (modern) tokens.chipBg else scheme.primaryContainer, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    AppIcon(
                        Icons.Rounded.Insights,
                        null,
                        Modifier.size(22.dp),
                        tint = if (modern) tokens.accentOnGlass else scheme.onPrimaryContainer,
                    )
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        text = if (days > 0) "No plays in the last $days days" else "No listening history yet",
                        style = if (modern) {
                            MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold)
                        } else {
                            MaterialTheme.typography.titleMedium
                        },
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                    )
                    Text(
                        text = "Play songs to unlock your top track, streaks, and listening highlights.",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    )
                }
            }
            Button(
                onClick = onStartListening,
                shape = appShape(50.dp, CornerArea.Chips),
                modifier = Modifier.defaultMinSize(minHeight = 48.dp),
            ) {
                AppIcon(Icons.Rounded.PlayArrow, null, Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("Start listening")
            }
        }
    }
}

@Composable
private fun StatsErrorCard(
    message: String,
    onRetry: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    StatsSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
        Row(
            Modifier.fillMaxWidth().padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            AppIcon(Icons.Rounded.ErrorOutline, null, Modifier.size(24.dp), tint = if (modern) tokens.accentOnGlass else scheme.error)
            Column(Modifier.weight(1f)) {
                Text(
                    "Could not load statistics",
                    style = MaterialTheme.typography.titleMedium,
                    color = if (modern) tokens.onGlass else scheme.onSurface,
                )
                Text(
                    message,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            TextButton(onClick = onRetry, modifier = Modifier.defaultMinSize(minHeight = 48.dp)) {
                Text("Try again")
            }
        }
    }
}

@Composable
private fun Modifier.statsStaggerIn(order: Int): Modifier {
    val reduce = LocalReduceMotion.current || LocalUiPrefs.current?.homeAnimation == false
    var shown by rememberSaveable { mutableStateOf(reduce) }
    val p = remember { Animatable(if (shown) 1f else 0f) }
    val spec = motionEffectTween<Float>(
        durationMs = Motion.Spatial.StaggerEnterMs,
        easing = Motion.Emphasized,
    )
    LaunchedEffect(Unit) {
        if (shown) return@LaunchedEffect
        delay(order * Motion.Spatial.StaggerStepMs)
        p.animateTo(1f, spec)
        shown = true
    }
    return graphicsLayer {
        alpha = p.value
        translationY = (1f - p.value) * 18.dp.toPx()
    }
}

@Preview(name = "Android Stats Empty & Skeleton - Modern Dark", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun AndroidStatsEmptyModernPreview() {
    PaperPlayTheme(dark = true, uiStyle = UiStyle.Modern) {
        Column(Modifier.background(Color(0xFF121318)).padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            StatsEmptyCard(days = 0, onStartListening = {})
            StatsLoadingSkeleton(modern = true)
        }
    }
}
