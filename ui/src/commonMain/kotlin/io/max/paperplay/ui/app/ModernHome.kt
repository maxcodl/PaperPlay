package io.max.paperplay.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Celebration
import androidx.compose.material.icons.rounded.CenterFocusStrong
import androidx.compose.material.icons.rounded.DirectionsCar
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Umbrella
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.components.ModernScallopedBadge
import io.max.paperplay.ui.components.modernDockBrush
import io.max.paperplay.ui.components.modernSurfaceStatic
import io.max.paperplay.ui.components.uniqueKeys
import io.max.paperplay.ui.state.CollectionUi
import io.max.paperplay.ui.state.GroupUi
import io.max.paperplay.ui.state.HomeUi
import io.max.paperplay.ui.state.LibraryUi
import io.max.paperplay.ui.state.Load
import io.max.paperplay.ui.state.ShelfKindUi
import io.max.paperplay.ui.state.ShelfUi
import io.max.paperplay.ui.state.SongUi
import io.max.paperplay.ui.theme.LocalModernTokens
import io.max.paperplay.ui.theme.LocalReduceMotion
import io.max.paperplay.ui.theme.Motion
import io.max.paperplay.ui.theme.motionEffectTween
import io.max.paperplay.ui.theme.pressScale
import kotlinx.coroutines.delay

private val modernHomeMessages = listOf(
    "Ready when you are.", "What are we playing today?", "Your music, your way.", "Good tunes are waiting.",
    "Press play on something great.", "Let the music pick the mood.", "Find your next favorite song.", "Turn it up.",
)

private val modernMoodColors = mapOf(
    "happy" to Color(0xFFB8860B), "sad" to Color(0xFF34568B), "drive" to Color(0xFFB5482A), "rain" to Color(0xFF3F6B7D),
    "chill" to Color(0xFF2F7D6B), "focus" to Color(0xFF4F5B93), "party" to Color(0xFFA8326E), "night" to Color(0xFF3B2F6B),
    "love" to Color(0xFFB03A5B), "workout" to Color(0xFFA33A2A),
)

private val modernMoodIcons = mapOf(
    "happy" to Icons.Rounded.WbSunny, "sad" to Icons.Rounded.WaterDrop, "drive" to Icons.Rounded.DirectionsCar, "rain" to Icons.Rounded.Umbrella,
    "chill" to Icons.Rounded.Spa, "focus" to Icons.Rounded.CenterFocusStrong, "party" to Icons.Rounded.Celebration, "night" to Icons.Rounded.NightsStay,
    "love" to Icons.Rounded.Favorite, "workout" to Icons.Rounded.FitnessCenter,
)

/**
 * Dedicated expressive borderless Home layout for `UiStyle.Modern` on phones.
 * Order: Header -> Mix tiles (Favorites hero pill + 2-col pill grid) -> Recently played ->
 * Your daily mixes -> Remaining shelves (Your playlists, From Telegram, Recently added, Albums, Artists).
 * Zero outlines, zero HWUI interior shadow holes, zero per-item live blur.
 */
@Composable
internal fun ModernHomeScreen(
    lib: LibraryUi,
    home: HomeUi,
    favorites: List<SongUi>,
    currentId: String?,
    actions: ListActions,
    onOpen: (Detail) -> Unit,
    onProfile: (() -> Unit)?,
    onLibraryTab: ((Int) -> Unit)?,
    bottomPadding: Dp,
    modifier: Modifier = Modifier,
    name: String = "",
    warm: Boolean = true,
) {
    val tokens = LocalModernTokens.current
    val prefs = LocalUiPrefs.current
    val songs = (lib.songs as? Load.Ready)?.value.orEmpty()
    val telegram = LocalTelegramLists.current()

    var waited by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { delay(4_000); waited = true }
    val hasPlan = home.tiles.isNotEmpty() || home.shelves.isNotEmpty()
    val ready = (hasPlan && warm) || waited

    val recentPlayed = remember(home.shelves) { home.shelves.firstOrNull { it.title == "Recently played" } }
    val recentAdded = remember(home.shelves) { home.shelves.firstOrNull { it.title == "Recently added" } }
    val otherShelves = remember(home.shelves) {
        home.shelves.filter { it.title != "Recently played" && it.title != "Recently added" }
    }

    val secondaryTiles = remember(lib.playlists, home.tiles, actions) {
        buildList<Pair<GroupUi, () -> Unit>> {
            lib.playlists.forEach { g -> add(g to { onOpen(Detail.Playlist(g.id, g.name)) }) }
            val needed = (6 - size).coerceAtLeast(0)
            home.tiles.take(needed).forEach { c ->
                add(GroupUi(c.id, c.name, coverUris = listOf(c.coverUri)) to { onOpen(Detail.Songs(c.name, c.songs)) })
            }
        }
    }

    val message = remember { modernHomeMessages.random() }
    val listState = rememberLazyListState()

    LazyColumn(
        state = listState,
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(top = 12.dp, bottom = bottomPadding + 28.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        item(key = "modern_header", contentType = "header") {
            ModernHomeHeader(
                name = name,
                message = message,
                photo = prefs?.profilePhoto,
                onProfile = onProfile,
            )
        }

        if (lib.songs is Load.Error) {
            item(key = "modern_error", contentType = "state_card") {
                ModernHomeStateCard(
                    title = "Could not load library",
                    subtitle = lib.songs.message,
                    icon = Icons.Rounded.ErrorOutline,
                )
            }
            return@LazyColumn
        }

        if (!ready) {
            item(key = "modern_skeleton", contentType = "skeleton") {
                ModernHomeSkeleton()
            }
            return@LazyColumn
        }

        if (songs.isEmpty() && home.shelves.isEmpty() && favorites.isEmpty() && lib.playlists.isEmpty()) {
            item(key = "modern_empty", contentType = "state_card") {
                ModernHomeStateCard(
                    title = "No songs yet",
                    subtitle = "Add your Telegram music chat or local folders in Settings to fill Home.",
                    icon = Icons.Rounded.MusicNote,
                )
            }
            return@LazyColumn
        }

        // 1. Mix tiles (Favorites wide full-pill tile + 2-col pill grid)
        if (favorites.isNotEmpty() || secondaryTiles.isNotEmpty()) {
            item(key = "modern_tiles", contentType = "tiles") {
                ModernQuickTilesSection(
                    favorites = favorites,
                    secondaryTiles = secondaryTiles,
                    onPlayFavorites = { actions.play(favorites, 0) },
                    modifier = Modifier.modernStaggerIn(0),
                )
            }
        }

        // 2. Recently played (with "See all" pill)
        if (recentPlayed != null && recentPlayed.songs.isNotEmpty()) {
            item(key = "modern_recent_played", contentType = "shelf_songs") {
                ModernSongShelf(
                    title = recentPlayed.title,
                    songs = recentPlayed.songs,
                    currentId = currentId,
                    actions = actions,
                    onSeeAll = { onOpen(Detail.Songs(recentPlayed.title, recentPlayed.songs)) },
                    modifier = Modifier.modernStaggerIn(1),
                )
            }
        }

        // 3. Your daily mixes directly after Recently played
        if (home.mixes.isNotEmpty()) {
            item(key = "modern_daily_mixes", contentType = "shelf_mixes") {
                Column(Modifier.modernStaggerIn(2), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ModernSectionHeader(title = "Your daily mixes")
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        items(home.mixes, key = { it.id }, contentType = { "mix_card" }) { mix ->
                            ModernDailyMixCard(mix = mix) { onOpen(Detail.Mix(mix.name, mix.id, mix.songs)) }
                        }
                    }
                }
            }
        } else if (songs.isNotEmpty()) {
            item(key = "modern_mix_hint", contentType = "hint") {
                Box(
                    Modifier
                        .padding(horizontal = 16.dp)
                        .fillMaxWidth()
                        .then(modernSurfaceStatic(tokens.cardBg, appShape(20.dp, CornerArea.Cards)))
                        .padding(16.dp),
                ) {
                    Text(
                        "Daily mixes appear as Paper Play learns your music.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = tokens.onGlassMuted,
                    )
                }
            }
        }

        // 4. Remaining shelves in their existing order
        if (lib.playlists.isNotEmpty()) {
            item(key = "modern_playlists", contentType = "shelf_playlists") {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ModernSectionHeader(
                        title = "Your playlists",
                        onSeeAll = onLibraryTab?.let { openTab -> { openTab(3) } },
                    )
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        items(lib.playlists, key = { it.id }, contentType = { "playlist_wide" }) { g ->
                            ModernWidePlaylistCard(g) { onOpen(Detail.Playlist(g.id, g.name)) }
                        }
                    }
                }
            }
        }

        if (telegram.isNotEmpty()) {
            item(key = "modern_telegram", contentType = "shelf_telegram") {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    ModernSectionHeader(title = "From Telegram")
                    LazyRow(
                        contentPadding = PaddingValues(horizontal = 16.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        items(telegram, key = { it.key }, contentType = { "telegram_card" }) { t ->
                            ModernSquareCollectionCard(
                                coverUris = t.songs.mapNotNull { it.coverUri }.distinct().take(4),
                                key = t.key,
                                title = t.name,
                                subtitle = "${t.songs.size} songs",
                                onClick = { onOpen(Detail.Songs(t.name, t.songs)) },
                            )
                        }
                    }
                }
            }
        }

        if (recentAdded != null && recentAdded.songs.isNotEmpty()) {
            item(key = "modern_recent_added", contentType = "shelf_songs") {
                ModernSongShelf(
                    title = recentAdded.title,
                    songs = recentAdded.songs,
                    currentId = currentId,
                    actions = actions,
                    onSeeAll = { onOpen(Detail.Songs(recentAdded.title, recentAdded.songs)) },
                )
            }
        }

        otherShelves.forEach { shelf ->
            item(key = "modern_shelf_${shelf.title}", contentType = "shelf_${shelf.kind.name}") {
                ModernDynamicShelf(shelf = shelf, currentId = currentId, actions = actions, onOpen = onOpen)
            }
        }
    }
}

@Composable
private fun ModernHomeHeader(
    name: String,
    message: String,
    photo: String?,
    onProfile: (() -> Unit)?,
) {
    val tokens = LocalModernTokens.current
    val h = io.max.paperplay.ui.currentHour()
    val greeting = if (h < 12) "Good morning" else if (h < 18) "Good afternoon" else "Good evening"
    val who = name.trim()
    val displayTitle = if (who.isEmpty()) greeting else "$greeting, $who"

    Row(
        Modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                text = displayTitle,
                style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.ExtraBold),
                color = tokens.onGlass,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = message,
                modifier = Modifier.padding(top = 3.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = tokens.onGlassMuted,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        val avatarBox = Modifier
            .size(44.dp)
            .then(modernSurfaceStatic(tokens.cardBgElevated, CircleShape))
            .then(
                if (onProfile != null) Modifier.clickable(role = Role.Button, onClick = onProfile)
                else Modifier
            )
            .semantics { contentDescription = "Open profile" }
        Box(avatarBox, contentAlignment = Alignment.Center) {
            Avatar(photo = photo, name = who.ifEmpty { "Listener" }, size = 44.dp)
        }
    }
}

@Composable
private fun ModernSectionHeader(
    title: String,
    onSeeAll: (() -> Unit)? = null,
) {
    val tokens = LocalModernTokens.current
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold),
            color = tokens.onGlass,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        if (onSeeAll != null) {
            val pillShape = appShape(50.dp, CornerArea.Chips)
            Box(
                Modifier
                    .clip(pillShape)
                    .background(tokens.chipBg)
                    .clickable(role = Role.Button, onClick = onSeeAll)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
            ) {
                Text(
                    "See all",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = tokens.onGlass,
                )
            }
        }
    }
}

@Composable
private fun ModernSongShelf(
    title: String,
    songs: List<SongUi>,
    currentId: String?,
    actions: ListActions,
    onSeeAll: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val keys = remember(songs) { songs.map { it.id }.uniqueKeys() }
    val coverSize = 136.dp
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        ModernSectionHeader(title = title, onSeeAll = onSeeAll)
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            itemsIndexed(songs, key = { i, _ -> keys[i] }, contentType = { _, _ -> "song_card" }) { i, s ->
                val isPlaying = s.id == currentId
                val press = remember { MutableInteractionSource() }
                Column(
                    Modifier
                        .width(coverSize)
                        .pressScale(press, Motion.Micro.CardPressScale)
                        .clip(RoundedCornerShape(8.dp))
                        .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current) {
                            actions.play(songs, i)
                        }
                        .padding(horizontal = 2.dp, vertical = 2.dp),
                ) {
                    Box(Modifier.size(coverSize)) {
                        CoverImage(s.coverUri, s.id, size = coverSize, radius = 20.dp)
                        if (isPlaying) {
                            Box(
                                Modifier
                                    .align(Alignment.BottomStart)
                                    .padding(8.dp)
                                    .clip(appShape(50.dp, CornerArea.Chips))
                                    .background(MaterialTheme.colorScheme.primary)
                                    .padding(horizontal = 8.dp, vertical = 3.dp),
                            ) {
                                Text(
                                    "Playing",
                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                    color = MaterialTheme.colorScheme.onPrimary,
                                )
                            }
                        }
                    }
                    Text(
                        text = s.title,
                        modifier = Modifier.padding(top = 8.dp),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        color = if (isPlaying) tokens.accentOnGlass else tokens.onGlass,
                    )
                    Text(
                        text = s.artist,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.onGlassMuted,
                    )
                }
            }
        }
    }
}

@Composable
private fun ModernQuickTilesSection(
    favorites: List<SongUi>,
    secondaryTiles: List<Pair<GroupUi, () -> Unit>>,
    onPlayFavorites: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    Column(modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (favorites.isNotEmpty()) {
            val heroShape = appShape(34.dp, CornerArea.Cards)
            val favUris = remember(favorites) { favorites.mapNotNull { it.coverUri }.distinct().take(4) }
            val heroBg = lerp(tokens.cardBgElevated, scheme.primaryContainer, if (tokens.dark) 0.32f else 0.40f)
            val press = remember { MutableInteractionSource() }
            Row(
                Modifier
                    .fillMaxWidth()
                    .height(68.dp)
                    .pressScale(press, Motion.Micro.CardPressScale)
                    .then(modernSurfaceStatic(heroBg, heroShape))
                    .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current, onClick = onPlayFavorites)
                    .padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                CoverGrid(favUris, "modern_fav", 52.dp, 26.dp)
                Column(Modifier.weight(1f)) {
                    Text(
                        "Favorites",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold),
                        color = tokens.onGlass,
                        maxLines = 1,
                    )
                    Text(
                        "${favorites.size} songs",
                        style = MaterialTheme.typography.bodySmall,
                        color = tokens.onGlassMuted,
                        maxLines = 1,
                    )
                }
                ModernScallopedBadge(
                    size = 36.dp,
                    containerColor = scheme.primary,
                    contentColor = scheme.onPrimary,
                )
            }
        }
        if (secondaryTiles.isNotEmpty()) {
            val pairs = remember(secondaryTiles) { secondaryTiles.chunked(2) }
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                pairs.forEach { rowItems ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        rowItems.forEach { (g, onClick) ->
                            ModernPillTile(g = g, onClick = onClick, modifier = Modifier.weight(1f))
                        }
                        if (rowItems.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun ModernPillTile(
    g: GroupUi,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val tileShape = appShape(28.dp, CornerArea.Cards)
    val press = remember { MutableInteractionSource() }
    Row(
        modifier
            .height(56.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .then(modernSurfaceStatic(tokens.cardBg, tileShape))
            .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current, onClick = onClick)
            .padding(start = 7.dp, end = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        CoverGrid(g.coverUris, g.id, 42.dp, 21.dp)
        Text(
            text = g.name,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
            color = tokens.onGlass,
        )
    }
}

@Composable
private fun ModernDailyMixCard(
    mix: CollectionUi,
    onClick: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val moodColor = modernMoodColors[mix.id] ?: MaterialTheme.colorScheme.primary
    val cardShape = appShape(28.dp, CornerArea.Cards)
    val press = remember { MutableInteractionSource() }
    Box(
        Modifier
            .width(164.dp)
            .height(204.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .clip(cardShape)
            .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current, onClick = onClick),
    ) {
        CoverGrid(mix.coverUris, mix.id, 204.dp, 0.dp, modifier = Modifier.fillMaxSize())
        Box(
            Modifier.fillMaxSize().background(
                Brush.verticalGradient(
                    0.0f to moodColor.copy(alpha = 0.25f),
                    0.45f to Color.Black.copy(alpha = 0.30f),
                    1.0f to Color.Black.copy(alpha = 0.88f),
                ),
            ),
        )
        modernMoodIcons[mix.id]?.let { icon ->
            AppIcon(icon, null, Modifier.padding(14.dp).size(22.dp), tint = Color.White.copy(alpha = 0.92f))
        }
        Row(
            Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Column(Modifier.weight(1f)) {
                Text(
                    mix.name,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold),
                    color = Color.White,
                )
                if (mix.subtitle.isNotBlank()) {
                    Text(
                        mix.subtitle,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White.copy(alpha = 0.80f),
                    )
                }
            }
            ModernScallopedBadge(size = 32.dp)
        }
    }
}

@Composable
private fun ModernWidePlaylistCard(g: GroupUi, onClick: () -> Unit) {
    val tokens = LocalModernTokens.current
    val cardShape = appShape(22.dp, CornerArea.Cards)
    val press = remember { MutableInteractionSource() }
    Row(
        Modifier
            .width(204.dp)
            .height(92.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .then(modernSurfaceStatic(tokens.cardBg, cardShape))
            .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current, onClick = onClick)
            .padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CoverGrid(g.coverUris, g.id, 72.dp, 14.dp)
        Column(Modifier.weight(1f)) {
            Text(
                g.name,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.ExtraBold),
                color = tokens.onGlass,
            )
            if (g.subtitle.isNotBlank()) {
                Text(
                    g.subtitle,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodySmall,
                    color = tokens.onGlassMuted,
                )
            }
        }
    }
}

@Composable
private fun ModernSquareCollectionCard(
    coverUris: List<String?>,
    key: String,
    title: String,
    subtitle: String?,
    onClick: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val press = remember { MutableInteractionSource() }
    Column(
        Modifier
            .width(140.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .clip(RoundedCornerShape(8.dp))
            .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current, onClick = onClick)
            .padding(horizontal = 2.dp, vertical = 2.dp),
    ) {
        CoverGrid(coverUris, key, 140.dp, 20.dp)
        Text(
            title,
            modifier = Modifier.padding(top = 8.dp),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
            color = tokens.onGlass,
        )
        if (!subtitle.isNullOrBlank()) {
            Text(
                subtitle,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodySmall,
                color = tokens.onGlassMuted,
            )
        }
    }
}

@Composable
private fun ModernDynamicShelf(
    shelf: ShelfUi,
    currentId: String?,
    actions: ListActions,
    onOpen: (Detail) -> Unit,
) {
    val tokens = LocalModernTokens.current
    when (shelf.kind) {
        ShelfKindUi.Songs -> if (shelf.songs.isNotEmpty()) {
            ModernSongShelf(
                title = shelf.title,
                songs = shelf.songs,
                currentId = currentId,
                actions = actions,
                onSeeAll = { onOpen(Detail.Songs(shelf.title, shelf.songs)) },
            )
        }
        ShelfKindUi.Artists -> if (shelf.groups.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ModernSectionHeader(title = shelf.title)
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    items(shelf.groups, key = { it.id }, contentType = { "artist_avatar" }) { g ->
                        val press = remember { MutableInteractionSource() }
                        Column(
                            Modifier
                                .width(116.dp)
                                .pressScale(press, Motion.Micro.CardPressScale)
                                .clip(RoundedCornerShape(8.dp))
                                .clickable(interactionSource = press, indication = androidx.compose.foundation.LocalIndication.current) {
                                    onOpen(Detail.Artist(g.name))
                                }
                                .padding(horizontal = 2.dp, vertical = 2.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            CoverImage(g.coverUri, g.id, size = 112.dp, radius = 56.dp)
                            Text(
                                g.name,
                                modifier = Modifier.padding(top = 8.dp),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                textAlign = TextAlign.Center,
                                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                color = tokens.onGlass,
                            )
                        }
                    }
                }
            }
        }
        ShelfKindUi.Albums -> if (shelf.groups.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                ModernSectionHeader(title = shelf.title)
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(shelf.groups, key = { it.id }, contentType = { "album_card" }) { g ->
                        ModernSquareCollectionCard(
                            coverUris = listOf(g.coverUri),
                            key = g.id,
                            title = g.name,
                            subtitle = g.subtitle.ifBlank { "${g.songs.size} songs" },
                            onClick = { onOpen(Detail.Album(g.name, g.subtitle.takeIf { it.isNotBlank() })) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ModernHomeStateCard(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
) {
    val tokens = LocalModernTokens.current
    Row(
        Modifier
            .padding(horizontal = 16.dp)
            .fillMaxWidth()
            .then(modernSurfaceStatic(tokens.cardBg, appShape(24.dp, CornerArea.Cards)))
            .padding(20.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        AppIcon(icon, null, Modifier.size(28.dp), tint = tokens.accentOnGlass)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold), color = tokens.onGlass)
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = tokens.onGlassMuted)
        }
    }
}

@Composable
private fun Modifier.modernStaggerIn(order: Int): Modifier {
    val reduce = LocalReduceMotion.current || LocalUiPrefs.current?.homeAnimation == false
    var shown by rememberSaveable { mutableStateOf(reduce) }
    val p = remember { androidx.compose.animation.core.Animatable(if (shown) 1f else 0f) }
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
        translationY = (1f - p.value) * 20.dp.toPx()
    }
}
