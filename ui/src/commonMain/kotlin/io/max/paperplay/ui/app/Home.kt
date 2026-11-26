package io.max.paperplay.ui.app

import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.uniqueKeys

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Celebration
import androidx.compose.material.icons.rounded.CenterFocusStrong
import androidx.compose.material.icons.rounded.DirectionsCar
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FitnessCenter
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.Spa
import androidx.compose.material.icons.rounded.Umbrella
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material.icons.rounded.WbSunny
import androidx.compose.material3.AssistChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.runtime.setValue
import androidx.compose.runtime.getValue
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.state.CollectionUi
import io.max.paperplay.ui.state.GroupUi
import io.max.paperplay.ui.state.HomeUi
import io.max.paperplay.ui.state.LibraryUi
import io.max.paperplay.ui.state.Load
import io.max.paperplay.ui.state.ShelfKindUi
import io.max.paperplay.ui.state.SongUi
import io.max.paperplay.ui.theme.hsl

private val cardSize = 150.dp
/** Playlist cards are smaller so more of them show at once; the row swipes sideways for the rest. */
private val playlistCardSize = 112.dp

@Composable
fun HomeScreen(
    lib: LibraryUi, home: HomeUi, favorites: List<SongUi>, currentId: String?,
    conn: ConnectionUi, scan: State<ScanUi?>, actions: ListActions, onOpen: (Detail) -> Unit, bottomPadding: Dp, modifier: Modifier = Modifier,
    name: String = "",
    /** False until the lists Home shows have all arrived; the page waits for it so it does not change while it animates in. */
    warm: Boolean = true,
    onProfile: (() -> Unit)? = null,
    onLibraryTab: ((Int) -> Unit)? = null,
) {
    if (io.max.paperplay.ui.theme.LocalModernTokens.current.enabled && io.max.paperplay.ui.isPhone) {
        ModernHomeScreen(
            lib = lib,
            home = home,
            favorites = favorites,
            currentId = currentId,
            actions = actions,
            onOpen = onOpen,
            onProfile = onProfile,
            onLibraryTab = onLibraryTab,
            bottomPadding = bottomPadding,
            modifier = modifier,
            name = name,
            warm = warm,
        )
        return
    }
    val songs = (lib.songs as? Load.Ready)?.value.orEmpty()
    val readTelegram = LocalTelegramLists.current
    val telegram = readTelegram()
    // Quick tiles: favorites, every playlist, then generated collections to make at least six. Three stack in a column; swipe sideways for more.
    val tileRows = remember(favorites, lib.playlists, home.tiles, actions) {
        buildList<Pair<GroupUi, () -> Unit>> {
            if (favorites.isNotEmpty()) add(GroupUi("fav", "Favorites", coverUris = favorites.map { it.coverUri }.shuffled()) to { actions.play(favorites, 0) })
            lib.playlists.forEach { g -> add(g.copy(coverUris = g.coverUris.shuffled()) to { onOpen(Detail.Playlist(g.id, g.name)) }) }
            home.tiles.take((6 - size).coerceAtLeast(0)).forEach { c -> add(GroupUi(c.id, c.name, coverUris = listOf(c.coverUri)) to { onOpen(Detail.Songs(c.name, c.songs)) }) }
        }.chunked(3)
    }
    // Recently played and Recently added stay as rows of songs. Every other shelf becomes one card on a single "More for you" row.
    val recentPlayed = remember(home.shelves) { home.shelves.firstOrNull { it.title == "Recently played" } }
    val recentAdded = remember(home.shelves) { home.shelves.firstOrNull { it.title == "Recently added" } }
    val moreCards = remember(home.shelves) {
        home.shelves.filter { it.title != "Recently played" && it.title != "Recently added" }.mapNotNull { sh ->
            val all = (if (sh.kind == ShelfKindUi.Songs) sh.songs else sh.groups.flatMap { it.songs }).distinctBy { it.id }
            if (all.isEmpty()) null else {
                val withArt = all.filter { it.coverUri != null }
                // A cover from inside the list, the same one all day.
                val art = withArt.getOrNull(if (withArt.isEmpty()) 0 else (sh.title.hashCode() and 0x7fffffff) % withArt.size)?.coverUri
                Triple(sh.title, art, all)
            }
        }
    }
    // No placeholders: the greeting is there at once and the tiles and cards fly in as soon as the page is on hand (last launch's, or the real
    // one), whether or not the library has finished loading. A plan that never comes (nothing to plan) is given up after four seconds.
    var waited by remember { mutableStateOf(false) }
    androidx.compose.runtime.LaunchedEffect(Unit) { kotlinx.coroutines.delay(4_000); waited = true }
    val hasPlan = home.tiles.isNotEmpty() || home.shelves.isNotEmpty()
    val ready = (hasPlan && warm) || waited
    // The fly-in plays for what is drawn in the first moments only; anything scrolled into view later just appears.
    androidx.compose.runtime.LaunchedEffect(ready) { if (ready) { kotlinx.coroutines.delay(2_200); introDone = true } }
    val message = remember { homeMessages.random() }
    BoxWithConstraints(modifier) {
    // A wide window (desktop) gets a denser top: tiles at a fixed width beside a compact recently played row.
    val wide = maxWidth >= 900.dp
    val homeListState = androidx.compose.foundation.lazy.rememberLazyListState()
    DesktopScrollHost(homeListState, Modifier.fillMaxSize()) { scrollMod ->
    LazyColumn(scrollMod, state = homeListState, contentPadding = PaddingValues(bottom = bottomPadding)) {
        item { HomeHeader(name, message) }
        if (ready && wide && (recentPlayed != null || tileRows.isNotEmpty())) item(key = "hero") {
            Row(Modifier.fillMaxWidth().padding(top = 0.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                // Two columns of three tiles, each a set width, so they stay compact however wide the window is.
                if (tileRows.isNotEmpty()) Row(Modifier.padding(start = 16.dp, top = 44.dp).staggerIn(1), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    tileRows.take(2).forEachIndexed { ci, column ->
                        Column(Modifier.width(244.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            column.forEachIndexed { ri, (g, click) -> QuickTile(g, click, ci * 3 + ri) }
                        }
                    }
                }
                if (recentPlayed != null) Column(Modifier.weight(1f).staggerIn(0)) {
                    SongShelf(recentPlayed.title, recentPlayed.songs, currentId, actions, order = 0, size = 120.dp)
                }
            }
        } else {
        if (ready && recentPlayed != null) item(key = "recent_played") { Box(Modifier.staggerIn(0)) { SongShelf(recentPlayed.title, recentPlayed.songs, currentId, actions, order = 0) } }
        if (ready && tileRows.isNotEmpty()) item {
            // Each column holds three tiles; two columns fill the screen and the rest wait a swipe away.
            LazyRow(Modifier.staggerIn(1), contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(tileRows) { column ->
                    val columnIndex = tileRows.indexOf(column)
                    Column(Modifier.fillParentMaxWidth(if (tileRows.size > 2) 0.46f else 0.485f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        column.forEachIndexed { rowIndex, (g, click) -> QuickTile(g, click, columnIndex * 3 + rowIndex) }
                    }
                }
            }
        }
        }
        if (ready && home.mixes.isNotEmpty()) item {
            Column(Modifier.staggerIn(2)) {
                Section("Your daily mixes")
                LazyRow(contentPadding = PaddingValues(horizontal = 8.dp)) {
                    items(home.mixes.size, key = { home.mixes[it].id }) { i -> val m = home.mixes[i]; MixCard(m, Modifier.snapIn(i, 200)) { onOpen(Detail.Mix(m.name, m.id, m.songs)) } }
                }
            }
        } else if (ready && songs.isNotEmpty()) item {
            Text("Daily mixes appear as Paper Play learns your music.", Modifier.padding(16.dp, 20.dp, 16.dp, 0.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (ready && lib.playlists.isNotEmpty()) item {
            Column(Modifier.staggerIn(3)) {
                Section("Your playlists")
                LazyRow(contentPadding = PaddingValues(horizontal = 8.dp)) {
                    items(lib.playlists, key = { it.id }) { g ->
                        Column(Modifier.width(playlistCardSize + 16.dp).clip(RoundedCornerShape(12.dp)).clickable { onOpen(Detail.Playlist(g.id, g.name)) }.padding(8.dp)) {
                            CoverGrid(g.coverUris, g.id, playlistCardSize, 10.dp)
                            Text(g.name, Modifier.padding(top = 8.dp), maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall)
                        }
                    }
                }
            }
        }
        // The main chat's topics and starred channels, apart from the playlists you made; swipe sideways for the rest.
        if (ready && telegram.isNotEmpty()) item {
            Column(Modifier.staggerIn(4)) {
                Section("From Telegram")
                LazyRow(contentPadding = PaddingValues(horizontal = 8.dp)) {
                    items(telegram, key = { it.key }) { t ->
                        Column(Modifier.width(cardSize + 16.dp).clip(RoundedCornerShape(12.dp)).clickable { onOpen(Detail.Songs(t.name, t.songs)) }.padding(8.dp)) {
                            CoverGrid(t.songs.mapNotNull { it.coverUri }.distinct().take(4), t.key, cardSize, 10.dp)
                            Text(t.name, Modifier.padding(top = 8.dp), maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall)
                            Text("${t.songs.size} songs", maxLines = 1, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        }
        if (ready && recentAdded != null) item(key = "recent_added") { Box(Modifier.staggerIn(5)) { SongShelf(recentAdded.title, recentAdded.songs, currentId, actions, order = 5) } }
        if (ready && moreCards.isNotEmpty()) item(key = "more_for_you") {
            Column(Modifier.staggerIn(6)) {
                Section("More for you")
                LazyRow(contentPadding = PaddingValues(horizontal = 8.dp)) {
                    items(moreCards.distinctBy { it.first }, key = { it.first }) { (title, art, list) ->
                        MediaCard(art, "more:$title", title, "${list.size} songs") { onOpen(Detail.Songs(title, list)) }
                    }
                }
            }
        }
    }
    }
    }
}

/** A quick tile: the cover mosaic and a name, flying in with the start-up animation. */
@Composable
private fun QuickTile(g: GroupUi, click: () -> Unit, order: Int) {
    Row(
        Modifier.fillMaxWidth().height(56.dp).snapIn(order, 0).partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerHigh, appShape(12.dp))
            .clickable(onClick = click),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        CoverGrid(g.coverUris, g.id, 56.dp, 0.dp)
        Text(g.name, Modifier.padding(horizontal = 12.dp), maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall)
    }
}

/** A section slides up a little and fades in, one after another by [order], the first time it is shown; scrolling back does not replay it. */
@Composable
private fun Modifier.staggerIn(order: Int): Modifier {
    val reduce = io.max.paperplay.ui.theme.LocalReduceMotion.current || LocalUiPrefs.current?.homeAnimation == false
    var shown by androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(reduce) }
    val p = remember { androidx.compose.animation.core.Animatable(if (shown) 1f else 0f) }
    val spec = io.max.paperplay.ui.theme.motionEffectTween<Float>(
        durationMs = io.max.paperplay.ui.theme.Motion.Spatial.StaggerEnterMs,
        easing = io.max.paperplay.ui.theme.Motion.Emphasized,
    )
    androidx.compose.runtime.LaunchedEffect(Unit) {
        if (shown) return@LaunchedEffect
        kotlinx.coroutines.delay(order * io.max.paperplay.ui.theme.Motion.Spatial.StaggerStepMs)
        p.animateTo(1f, spec)
        shown = true
    }
    return graphicsLayer { alpha = p.value; translationY = (1f - p.value) * 24.dp.toPx() }
}

/** Set when the first moments of the page are over; see [snapIn]. */
private var introDone = false

/**
 * The start-up animation: a tile or card flies in from the left, the right or the bottom (by its [index]) and snaps into
 * place cleanly (critically damped, zero overshoot), one after another from [startMs]. Plays only during the initial appear.
 */
@Composable
private fun Modifier.snapIn(index: Int, startMs: Int): Modifier {
    val reduce = io.max.paperplay.ui.theme.LocalReduceMotion.current || LocalUiPrefs.current?.homeAnimation == false
    val play = remember { !introDone && !reduce }
    if (!play) return this
    val p = remember { androidx.compose.animation.core.Animatable(0f) }
    val spec = io.max.paperplay.ui.theme.motionSpatialSpring<Float>(io.max.paperplay.ui.theme.Motion.Spatial.EnterStiffness)
    androidx.compose.runtime.LaunchedEffect(Unit) {
        // The first frames that draw this content are the slow ones (covers go to the graphics memory); the items wait, unseen, until
        // those have passed, so the movement does not start on a long frame and jump.
        repeat(3) { androidx.compose.runtime.withFrameNanos { } }
        kotlinx.coroutines.delay(startMs + index * io.max.paperplay.ui.theme.Motion.Spatial.StaggerStepMs)
        p.animateTo(1f, spec)
    }
    val from = index % 3
    return graphicsLayer {
        val away = 1f - p.value
        when (from) {
            0 -> translationX = -size.width * 1.3f * away
            1 -> translationX = size.width * 1.3f * away
            else -> translationY = size.height * 2.2f * away
        }
        // No tilt: a rotated layer made every cover in it be uploaded to the graphics memory again on every frame (measured: about a
        // thousand uploads in half a second, against about a hundred without it), which is what made the animation stutter.
        alpha = (p.value * 4f).coerceIn(0f, 1f)
        // Fade each piece as it is drawn instead of drawing the whole card into a separate buffer first: that buffer made every cover in it
        // be uploaded to the graphics memory again on every frame of the animation (about a thousand uploads in half a second).
        compositingStrategy = androidx.compose.ui.graphics.CompositingStrategy.ModulateAlpha
    }
}

private val homeMessages = listOf(
    "Ready when you are.", "What are we playing today?", "Your music, your way.", "Good tunes are waiting.",
    "Press play on something great.", "Let the music pick the mood.", "Find your next favorite song.", "Turn it up.",
)

/** Greeting with the user's name and one message that stays fixed while the screen is open. */
@Composable
private fun HomeHeader(name: String, message: String) {
    val h = io.max.paperplay.ui.currentHour()
    val greeting = if (h < 12) "Good morning" else if (h < 18) "Good afternoon" else "Good evening"
    val who = name.trim()
    Column(Modifier.barSurface().padding(start = 16.dp, end = 16.dp, top = 28.dp, bottom = 16.dp)) {
        Text(if (who.isEmpty()) greeting else "$greeting, $who", style = MaterialTheme.typography.displaySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(message, Modifier.padding(top = 4.dp), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Connection and scan status as a small toast over the page: swipe it sideways to dismiss; it takes the page colour. */
@Composable
fun StatusToast(conn: ConnectionUi, scanState: State<ScanUi?>, songCount: Int, tint: Color, modifier: Modifier = Modifier) {
    val scan = scanState.value
    val text = when {
        conn.error != null -> conn.error
        !conn.ready && conn.state.isNotEmpty() -> "Connecting to Telegram…"
        scan != null -> scan.text
        songCount == 0 && conn.ready -> "No songs yet. Add the chat that holds your music in Settings."
        else -> null
    }
    var dismissed by remember { mutableStateOf<String?>(null) }
    var offset by remember { mutableStateOf(0f) }
    var last by remember { mutableStateOf("") }
    if (text != null) last = text
    // Scan progress changes every second, so a swipe dismisses the whole run, not just the line that was showing.
    val key = if (text != null && text == scan?.text) "scan" else text
    if (text == null) { dismissed = null; offset = 0f }
    // A dismissal belongs to one scan run: when the scan ends, the next one shows again.
    if (scan == null && dismissed == "scan") dismissed = null
    androidx.compose.runtime.LaunchedEffect(key) { if (key != dismissed) offset = 0f }
    // A message that stays (not scan progress, which keeps changing) goes away after 20 seconds.
    androidx.compose.runtime.LaunchedEffect(if (scan != null && conn.error == null) null else text) {
        if (text != null && scan == null) { kotlinx.coroutines.delay(20_000); dismissed = text }
    }
    androidx.compose.animation.AnimatedVisibility(
        visible = text != null && key != dismissed,
        modifier = modifier,
        enter = androidx.compose.animation.slideInVertically { -it } + androidx.compose.animation.fadeIn(),
        exit = androidx.compose.animation.slideOutVertically { -it } + androidx.compose.animation.fadeOut(),
    ) {
        val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
        val scheme = MaterialTheme.colorScheme
        val bg = androidx.compose.ui.graphics.lerp(tint, scheme.onSurface, 0.16f)
        val fg = if (tokens.enabled) tokens.onGlass else if (bg.luminance() < 0.5f) Color.White else Color.Black
        val toastMod = if (tokens.enabled) {
            io.max.paperplay.ui.components.modernSurfaceStatic(tokens.overlayBg, RoundedCornerShape(16.dp))
        } else {
            Modifier.toastSurface(bg, fg)
        }
        Column(
            Modifier.padding(horizontal = 16.dp).widthIn(max = 440.dp)
                .offset { androidx.compose.ui.unit.IntOffset(offset.toInt(), 0) }
                .graphicsLayer { alpha = (1f - kotlin.math.abs(offset) / 600f).coerceIn(0f, 1f) }
                .then(toastMod)
                .pointerInput(key) {
                    detectHorizontalDragGestures(
                        // On dismiss the offset stays so the toast keeps sliding out; it resets when the toast comes back.
                        onDragEnd = { if (kotlin.math.abs(offset) > 80f) dismissed = key else offset = 0f },
                        onDragCancel = { offset = 0f },
                    ) { _, dx -> offset += dx }
                }
                .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                androidx.compose.material3.Icon(
                    if (conn.error != null) androidx.compose.material.icons.Icons.Rounded.ErrorOutline else androidx.compose.material.icons.Icons.Rounded.Sync,
                    null, Modifier.size(20.dp), tint = fg.copy(alpha = 0.8f),
                )
                Text(text ?: last, Modifier.padding(start = 12.dp), color = fg, maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyMedium)
            }
            if (scan != null && conn.error == null) {
                val f = scan.fraction
                val m = Modifier.fillMaxWidth().padding(top = 10.dp).height(4.dp).clip(RoundedCornerShape(2.dp))
                if (f != null) LinearProgressIndicator({ f.toFloat() }, m, color = fg, trackColor = fg.copy(alpha = 0.22f), gapSize = 0.dp, drawStopIndicator = {})
                else LinearProgressIndicator(m, color = fg, trackColor = fg.copy(alpha = 0.22f), gapSize = 0.dp)
            }
        }
    }
}

@Composable
fun SongShelf(title: String, songs: List<SongUi>, currentId: String?, actions: ListActions, order: Int = 99, size: Dp = cardSize) {
    val keys = remember(songs) { songs.map { it.id }.uniqueKeys() }
    Column {
        Section(title)
        LazyRow(contentPadding = PaddingValues(horizontal = 8.dp)) {
            items(songs.size, key = { keys[it] }) { i ->
                val s = songs[i]
                MediaCard(s.coverUri, s.id, s.title, s.artist, titleColor = if (s.id == currentId) MaterialTheme.colorScheme.primary else null, modifier = if (order < 99) Modifier.snapIn(i, 40 + order * 60) else Modifier, size = size) { actions.play(songs, i) }
            }
        }
    }
}

/** A cover with a title and subtitle under it; round for artists. */
@Composable
fun MediaCard(coverUri: String?, key: String, title: String, subtitle: String?, circle: Boolean = false, titleColor: Color? = null, modifier: Modifier = Modifier, size: Dp = cardSize, onClick: () -> Unit) {
    val align = if (circle) Alignment.CenterHorizontally else Alignment.Start
    Column(modifier.width(size + 16.dp).clip(RoundedCornerShape(18.dp)).clickable(onClick = onClick).padding(8.dp), horizontalAlignment = align) {
        CoverImage(coverUri, key, size = size, radius = if (circle) size / 2 else 10.dp)
        Text(
            title, Modifier.padding(top = 8.dp), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall,
            color = titleColor ?: MaterialTheme.colorScheme.onSurface, textAlign = if (circle) TextAlign.Center else TextAlign.Start,
        )
        if (!subtitle.isNullOrEmpty()) Text(
            subtitle, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = if (circle) TextAlign.Center else TextAlign.Start,
        )
    }
}

private val moodColors = mapOf(
    "happy" to Color(0xFFB8860B), "sad" to Color(0xFF34568B), "drive" to Color(0xFFB5482A), "rain" to Color(0xFF3F6B7D),
    "chill" to Color(0xFF2F7D6B), "focus" to Color(0xFF4F5B93), "party" to Color(0xFFA8326E), "night" to Color(0xFF3B2F6B),
    "love" to Color(0xFFB03A5B), "workout" to Color(0xFFA33A2A),
)

private val moodIcons = mapOf(
    "happy" to Icons.Rounded.WbSunny, "sad" to Icons.Rounded.WaterDrop, "drive" to Icons.Rounded.DirectionsCar, "rain" to Icons.Rounded.Umbrella,
    "chill" to Icons.Rounded.Spa, "focus" to Icons.Rounded.CenterFocusStrong, "party" to Icons.Rounded.Celebration, "night" to Icons.Rounded.NightsStay,
    "love" to Icons.Rounded.Favorite, "workout" to Icons.Rounded.FitnessCenter,
)

/** A daily mix: its covers washed in the mood's colour, with its name. */
@Composable
private fun MixCard(mix: CollectionUi, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val color = moodColors[mix.id] ?: MaterialTheme.colorScheme.primary
    Column(modifier.width(cardSize + 16.dp).clip(RoundedCornerShape(18.dp)).clickable(onClick = onClick).padding(8.dp)) {
        Box(Modifier.size(cardSize).clip(RoundedCornerShape(10.dp))) {
            CoverGrid(mix.coverUris, mix.id, cardSize, 0.dp)
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(color.copy(alpha = 0.35f), color.copy(alpha = 0.95f)))))
            Column(Modifier.fillMaxSize().padding(10.dp)) {
                moodIcons[mix.id]?.let { AppIcon(it, null, Modifier.size(22.dp), tint = Color.White) }
                Spacer(Modifier.weight(1f))
                Text(mix.name, maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleMedium, color = Color.White)
            }
        }
        Text(mix.subtitle, Modifier.padding(top = 8.dp), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Browse by genre: a tile per genre, largest first, with a cover tilted into the corner. */
@Composable
fun GenreGrid(songs: List<SongUi>, bottomPadding: Dp, onOpen: (Detail) -> Unit, modifier: Modifier = Modifier) {
    val genres = androidx.compose.runtime.remember(songs) { songs.filter { !it.genre.isNullOrBlank() }.groupBy { it.genre!!.trim() }.entries.sortedByDescending { it.value.size } }
    if (genres.isEmpty()) {
        Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Genres appear here as song info is found.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        return
    }
    BoxWithConstraints(modifier) {
        val cols = (maxWidth / 200.dp).toInt().coerceIn(2, 6)
        LazyVerticalGrid(
            GridCells.Fixed(cols), Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp, 0.dp, 16.dp, bottomPadding + 16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(genres, key = { it.key }) { (genre, list) ->
                // Stable per genre, dark enough for white text in either theme.
                val hue = (genre.hashCode() % 360).let { if (it < 0) -it else it }.toFloat()
                Box(
                    Modifier.aspectRatio(1.9f).clip(RoundedCornerShape(12.dp)).background(hsl(hue, 0.45f, 0.32f))
                        .clickable { onOpen(Detail.Songs(genre, list)) },
                ) {
                    val art = list.firstOrNull { it.coverUri != null }
                    if (art != null) CoverImage(
                        art.coverUri, art.id, Modifier.align(Alignment.BottomEnd).offset(12.dp, 8.dp).rotate(24f).shadow(8.dp, RoundedCornerShape(6.dp)),
                        size = 64.dp, radius = 6.dp,
                    )
                    Text(
                        genre, Modifier.padding(14.dp, 14.dp, 60.dp, 14.dp), maxLines = 2, overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.titleMedium, color = Color.White,
                    )
                }
            }
        }
    }
}

private val previewHomeSongs = listOf(
    SongUi("1", "Supermassive Black Hole", "Muse", "Black Holes and Revelations", genre = "Rock", durationSec = 209),
    SongUi("2", "Starlight", "Muse", "Black Holes and Revelations", genre = "Rock", durationSec = 240),
)

private val previewActions = ListActions(play = { _, _ -> }, shuffle = {}, setFavorite = { _, _ -> }, addToPlaylist = {}, notice = {})

@Preview
@Composable
private fun MediaCardPreview() {
    MediaCard(coverUri = null, key = "preview_art", title = "Muse", subtitle = "Artist", circle = true, onClick = {})
}

@Preview
@Composable
private fun SongShelfPreview() {
    SongShelf(title = "Recently Added", songs = previewHomeSongs, currentId = "1", actions = previewActions)
}

@Preview
@Composable
private fun GenreGridPreview() {
    GenreGrid(songs = previewHomeSongs, bottomPadding = 0.dp, onOpen = {})
}

@Preview
@Composable
private fun HomeScreenPreview() {
    HomeScreen(
        lib = LibraryUi(songs = Load.Ready(previewHomeSongs)),
        home = HomeUi(),
        favorites = previewHomeSongs,
        currentId = null, scan = remember { mutableStateOf(null) },
        conn = ConnectionUi(ready = true),
        actions = previewActions,
        onOpen = {},
        bottomPadding = 0.dp,
    )
}


@Preview(name = "Header", showBackground = true)
@Composable
private fun HomeHeaderPreview() = io.max.paperplay.ui.PreviewFrame { HomeHeader("Max", "Turn it up.") }

@Preview(name = "Status toast", showBackground = true)
@Composable
private fun StatusToastPreview() = io.max.paperplay.ui.PreviewFrame {
    StatusToast(
        conn = ConnectionUi(ready = true), scanState = remember { mutableStateOf<ScanUi?>(ScanUi("Reading channel 3 of 5", 0.4)) },
        songCount = 120, tint = MaterialTheme.colorScheme.primary,
    )
}

@Preview(name = "Mix card", showBackground = true)
@Composable
private fun MixCardPreview() = io.max.paperplay.ui.PreviewFrame {
    MixCard(CollectionUi(id = "mix1", name = "Daily Mix 1", subtitle = "Muse, Queen and more"), onClick = {})
}
