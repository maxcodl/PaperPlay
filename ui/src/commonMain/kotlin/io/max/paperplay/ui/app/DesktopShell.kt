package io.max.paperplay.ui.app

import androidx.compose.material.icons.rounded.Campaign
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.toggleOnColor

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Forum
import androidx.compose.material.icons.rounded.Album
import androidx.compose.material.icons.outlined.Bedtime
import androidx.compose.material.icons.outlined.Lyrics
import androidx.compose.material.icons.rounded.Devices
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Menu
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Fullscreen
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.RepeatOne
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.FastRewind
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material.icons.rounded.Upload
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.Storage
import androidx.compose.material.icons.rounded.MonitorHeart
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.Rule
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.DriveFileMove
import androidx.compose.material.icons.rounded.ViewSidebar
import androidx.compose.material.icons.rounded.VolumeOff
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.logic.formatDuration
import io.max.paperplay.ui.state.GroupUi
import io.max.paperplay.ui.state.PlaybackUiState
import io.max.paperplay.ui.state.RepeatUi
import io.max.paperplay.ui.state.SongUi
import org.jetbrains.compose.ui.tooling.preview.Preview

/** Desktop pages reachable from the sidebar. */
internal class SidePage(val id: String, val label: String, val icon: ImageVector)

internal val mainPages = listOf(
    SidePage("home", "Home", Icons.Rounded.Home), SidePage("search", "Search", Icons.Rounded.Search),
    SidePage("profile", "Profile", Icons.Rounded.AccountCircle), SidePage("tasks", "Tasks", Icons.Rounded.TaskAlt),
    SidePage("upload", "Upload", Icons.Rounded.Upload),
)
internal val libraryPages = listOf(
    SidePage("songs", "Songs", Icons.Rounded.MusicNote), SidePage("albums", "Albums", Icons.Rounded.Album),
    SidePage("artists", "Artists", Icons.Rounded.Person), SidePage("favorites", "Favorites", Icons.Rounded.Favorite),
    SidePage("recent", "Recently played", Icons.Rounded.History),
)

/** Library tools that open as a settings page. */
internal val toolPages = listOf(
    SidePage("sort", "Sort General", Icons.Rounded.DriveFileMove), SidePage("dupes", "Duplicates", Icons.Rounded.ContentCopy),
    SidePage("missing", "Song info left", Icons.Rounded.Rule),
    SidePage("repair", "Scan library", Icons.Rounded.Sync), SidePage("channels", "Channels and chats", Icons.Rounded.Forum),
    SidePage("stats", "Listening statistics", Icons.Rounded.BarChart), SidePage("cache", "Cache manager", Icons.Rounded.Storage),
    SidePage("log", "Activity log", Icons.Rounded.MonitorHeart), SidePage("spotify", "Spotify import", Icons.Rounded.QueueMusic),
)

/** Tints the native title bar with the colour the page gradient starts from, so the two meet without a seam. */
@Composable
fun WindowTint(color: Color) {
    val windowTheme = io.max.paperplay.ui.LocalAppEnv.current?.windowTheme
    androidx.compose.runtime.LaunchedEffect(color, windowTheme) {
        val dark = color.luminance() < 0.5f
        windowTheme?.invoke(dark, color.toArgb(), (if (dark) Color.White else Color.Black).toArgb())
    }
}

/** The desktop card: rounded, a shade above the page background. */
@Composable
fun Modifier.deskCard(): Modifier = partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, appShape(16.dp, CornerArea.Panels))

@Composable
fun Sidebar(
    page: String, playlistId: String?, playlists: List<GroupUi>,
    expanded: Boolean, onToggle: () -> Unit,
    onPage: (String) -> Unit, onPlaylist: (GroupUi) -> Unit, onNewPlaylist: () -> Unit, modifier: Modifier = Modifier,
    onTelegram: (CoreBackend.TelegramList) -> Unit = {},
) {
    val readTelegram = LocalTelegramLists.current
    val telegram = readTelegram()
    val indexedSource = LocalIndexedChats.current
    val indexed = indexedSource?.chats?.collectAsState()?.value.orEmpty()
    var toolsOpen by remember { mutableStateOf(false) }
    var playlistsOpen by remember { mutableStateOf(true) }
    var telegramOpen by remember { mutableStateOf(true) }
    val scheme = MaterialTheme.colorScheme
    val prefs = LocalUiPrefs.current
    val look = prefs?.selectionLook ?: SelectionLook.Fill
    val itemShape = RoundedCornerShape(((prefs?.selectionRadius ?: 40f) / 100f * 22f).dp)
    val barShape = RoundedCornerShape(((prefs?.barRadius ?: 60f) / 100f * 28f).dp)
    val sidebarScroll = androidx.compose.foundation.lazy.rememberLazyListState()
    val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
    @Composable
    fun item(id: String, label: String, icon: @Composable () -> Unit, selected: Boolean, trailing: (@Composable () -> Unit)? = null, onClick: () -> Unit) {
        val selectedFill = when {
            !selected -> Color.Transparent
            look == SelectionLook.Fill -> scheme.primaryContainer.copy(alpha = 0.9f)
            look == SelectionLook.Soft -> scheme.onSurface.copy(alpha = 0.12f)
            look == SelectionLook.Ring || look == SelectionLook.Dot || look == SelectionLook.Text -> Color.Transparent
            else -> scheme.surfaceContainerHighest
        }
        val fill by animateColorAsState(selectedFill, io.max.paperplay.ui.theme.motionColorSpec(), label = "sidebar item")
        DesktopTooltip(label, enabled = !expanded) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 2.dp).clip(itemShape)
                    .background(fill)
                    .then(if (selected && look == SelectionLook.Ring) Modifier.border(1.5.dp, scheme.primary, itemShape) else Modifier)
                    .desktopInteractive(itemShape)
                    .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = if (expanded) Arrangement.Start else Arrangement.Center,
            ) {
                icon()
                if (expanded) {
                    Text(
                        label, Modifier.padding(start = 12.dp).weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyLarge,
                        fontWeight = if (selected) FontWeight.Bold else null,
                        // The Text look marks the open page by colouring its name.
                        color = if (selected && look == SelectionLook.Text) scheme.primary else Color.Unspecified,
                    )
                    // The Dot look marks it with a small dot.
                    if (selected && look == SelectionLook.Dot) Box(Modifier.padding(end = 4.dp).size(7.dp).clip(CircleShape).background(scheme.primary))
                    trailing?.invoke()
                }
            }
        }
    }
    @Composable
    fun label(text: String, trailing: (@Composable () -> Unit)? = null) {
        if (expanded) {
            Row(Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 14.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(text, Modifier.weight(1f), style = MaterialTheme.typography.labelMedium, color = scheme.onSurfaceVariant)
                trailing?.invoke()
            }
        } else {
            Spacer(Modifier.height(16.dp))
        }
    }
    @Composable
    fun foldChevron(open: Boolean, contentDescription: String) {
        val rotation by animateFloatAsState(
            targetValue = if (open) 180f else 0f,
            animationSpec = io.max.paperplay.ui.theme.motionEffectTween(io.max.paperplay.ui.theme.Motion.Micro.IconTurnMs),
            label = "foldChevron",
        )
        AppIcon(
            Icons.Rounded.ExpandMore,
            contentDescription,
            Modifier.size(20.dp).graphicsLayer { rotationZ = rotation },
            tint = scheme.onSurfaceVariant,
        )
    }
    DesktopScrollHost(
        sidebarScroll,
        modifier.partSurface(LookGroup.Nav, scheme.surfaceContainerLow, barShape),
        showScrollbar = false,
    ) { scrollMod ->
        LazyColumn(scrollMod.padding(vertical = 8.dp), state = sidebarScroll) {
            item {
                Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp), horizontalArrangement = if (expanded) Arrangement.End else Arrangement.Center) {
                    DesktopTooltip(if (expanded) "Collapse sidebar" else "Expand sidebar") {
                        IconButton(onToggle, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.Menu, "Toggle Sidebar") }
                    }
                }
            }
            items(mainPages, key = { it.id }) { p -> item(p.id, p.label, { AppIcon(p.icon, null, Modifier.size(22.dp)) }, page == p.id && playlistId == null) { onPage(p.id) } }
            item { label("Your library") }
            items(libraryPages, key = { it.id }) { p -> item(p.id, p.label, { AppIcon(p.icon, null, Modifier.size(22.dp)) }, page == p.id && playlistId == null) { onPage(p.id) } }
            // Tools is a row like the others: a toolbox icon, and an arrow that folds the list away.
            item {
                item("tools", "Tools", { AppIcon(Icons.Rounded.Build, null, Modifier.size(22.dp)) }, false, {
                    foldChevron(toolsOpen, if (toolsOpen) "Hide tools" else "Show tools")
                }) { toolsOpen = !toolsOpen }
            }
            item(key = "tools_body") {
                AnimatedVisibility(toolsOpen, enter = expandSectionEnter(reduceMotion), exit = expandSectionExit(reduceMotion)) {
                    Column {
                        toolPages.forEach { p -> item(p.id, p.label, { AppIcon(p.icon, null, Modifier.size(22.dp)) }, page == p.id && playlistId == null) { onPage(p.id) } }
                    }
                }
            }
            item { androidx.compose.material3.HorizontalDivider(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), color = scheme.onSurface.copy(alpha = 0.08f)) }
            item { item("settings", "Settings", { AppIcon(Icons.Rounded.Settings, null, Modifier.size(22.dp)) }, page == "settings" && playlistId == null) { onPage("settings") } }
            // Playlists and Telegram fold like Tools: an icon row with a fold arrow, which still works when the sidebar is narrow.
            item {
                item("playlists_group", "Playlists", { AppIcon(Icons.Rounded.QueueMusic, null, Modifier.size(22.dp)) }, false, {
                    DesktopTooltip("New playlist") {
                        IconButton(onNewPlaylist, Modifier.size(32.dp).desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.Add, "New playlist", Modifier.size(20.dp)) }
                    }
                    foldChevron(playlistsOpen, if (playlistsOpen) "Hide playlists" else "Show playlists")
                }) { playlistsOpen = !playlistsOpen }
            }
            item(key = "playlists_body") {
                AnimatedVisibility(playlistsOpen, enter = expandSectionEnter(reduceMotion), exit = expandSectionExit(reduceMotion)) {
                    Column {
                        playlists.forEach { g -> item(g.id, g.name, { CoverGrid(g.coverUris, g.id, 28.dp, 6.dp) }, playlistId == g.id) { onPlaylist(g) } }
                    }
                }
            }
            // The main chat's topics (and starred channels) sit apart from the playlists you made.
            if (telegram.isNotEmpty() || indexed.isNotEmpty()) {
                item {
                    item("telegram_group", "From Telegram", { AppIcon(Icons.Rounded.Forum, null, Modifier.size(22.dp)) }, false, {
                        foldChevron(telegramOpen, if (telegramOpen) "Hide Telegram" else "Show Telegram")
                    }) { telegramOpen = !telegramOpen }
                }
                item(key = "telegram_body") {
                    AnimatedVisibility(telegramOpen, enter = expandSectionEnter(reduceMotion), exit = expandSectionExit(reduceMotion)) {
                        Column {
                            telegram.forEach { t ->
                                item(t.key, t.name, { CoverGrid(t.songs.mapNotNull { it.coverUri }.distinct().take(4), t.key, 28.dp, 6.dp) }, false) { onTelegram(t) }
                            }
                            // Indexed chats: browsed a page at a time, their songs join the library only when added.
                            indexed.forEach { c ->
                                item("idx${c.id}", c.title, { AppIcon(if (c.isChannel) Icons.Rounded.Campaign else Icons.Rounded.Forum, null, Modifier.size(22.dp)) }, false) { indexedSource?.open?.invoke(c) }
                            }
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(8.dp)) }
        }
    }
}

/** The bar along the bottom of a desktop window: song, transport and seek, then panel, queue, volume and full screen. */
@Composable
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
fun PlayerBar(
    state: PlaybackUiState, volume: Float, backend: PlayerControls?, actions: ListActions,
    onOpen: () -> Unit, modifier: Modifier = Modifier,
    onNowPlaying: (() -> Unit)? = null, extras: @Composable () -> Unit = {},
    /** The Now playing page shows its own transport and seek bar, so the bar leaves them out while that page is open. */
    transportInPage: Boolean = false,
) {
    val song = state.current
    val scheme = MaterialTheme.colorScheme
    val muted = MaterialTheme.typography.labelSmall.copy(color = scheme.onSurfaceVariant)
    var showSleep by remember { mutableStateOf(false) }
    val prefs = LocalUiPrefs.current
    val carded = prefs != null && (prefs.look(LookGroup.Player) == Look.Glass || prefs.playerCard)
    val barShape = RoundedCornerShape(((prefs?.playerRadius ?: 40f) / 100f * 28f).dp)
    fun shown(id: String) = prefs?.playerButton(id) ?: true
    BoxWithConstraints(
        modifier.fillMaxWidth().height(84.dp).padding(horizontal = if (carded) 8.dp else 0.dp, vertical = if (carded) 4.dp else 0.dp)
            .then(if (carded) Modifier.partSurface(LookGroup.Player, scheme.surfaceContainerLow, barShape) else Modifier)
            .padding(horizontal = 16.dp),
    ) {
    // Wide windows put the song tools by the title; narrow ones keep them on the right so the title is never squeezed out.
    val wide = maxWidth >= 1100.dp
    val centre = (maxWidth * 0.34f).coerceIn(300.dp, 520.dp)
    val off = scheme.onSurfaceVariant
    val sz = Modifier.size(22.dp)
    val tools: @Composable () -> Unit = {
        if (shown("sleep")) IconButton({ showSleep = true }) { AppIcon(Icons.Outlined.Bedtime, "Sleep timer", sz, tint = off) }
        if (showSleep && backend != null) SleepTimerDialog(backend) { showSleep = false }
    }
    Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        Row(Modifier.weight(1f), verticalAlignment = Alignment.CenterVertically) {
            if (song != null) {
                CoverImage(song.coverUri, song.id, Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onNowPlaying ?: onOpen), size = 56.dp, radius = 8.dp)
                Column(Modifier.weight(1f, fill = false).padding(start = 12.dp)) {
                    Text(song.title, modifier = Modifier.basicMarquee(), maxLines = 1, style = MaterialTheme.typography.titleSmall)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        var outputInfoOpen by remember { mutableStateOf(false) }
                        io.max.paperplay.ui.components.formatChipOf(song)?.let { Box(Modifier.clickable { outputInfoOpen = true }) { io.max.paperplay.ui.components.FormatChip(it) } }
                        if (outputInfoOpen && backend != null) OutputInfoDialog(song, backend) { outputInfoOpen = false }
                        Text(song.artist, Modifier.weight(1f, fill = false), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = scheme.onSurfaceVariant)
                    }
                }
                if (shown("favorite")) IconButton({ actions.setFavorite(song, !song.favorite) }) {
                    AppIcon(if (song.favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder, if (song.favorite) "Remove from favorites" else "Add to favorites", tint = if (song.favorite) scheme.primary else scheme.onSurface)
                }
            }
            if (wide) tools()
        }
        if (transportInPage) {
            // The page has the controls; the bar's middle says how the sound is going out.
            val info = backend?.outputInfo?.collectAsState()?.value
            val line = listOfNotNull(
                song?.qualityLabel,
                info?.let { if (it.bitPerfect) "Bit-perfect" else null },
                info?.takeIf { it.bitPerfect }?.sampleRateHz?.let { (it / 1000.0).toString().removeSuffix(".0") + " kHz" },
            ).joinToString("  ·  ")
            Box(Modifier.width(centre), contentAlignment = Alignment.Center) {
                if (line.isNotEmpty()) Text(line, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.labelLarge, color = scheme.onSurfaceVariant)
            }
        } else Column(Modifier.width(centre), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                DesktopTooltip("Shuffle (S)") {
                    IconButton({ backend?.toggleShuffle() }, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.Shuffle, "Shuffle", tint = if (state.shuffle) toggleOnColor() else scheme.onSurface) }
                }
                // The same rewind, play and fast-forward glyphs as the phone player, with the play button drawn bare.
                DesktopTooltip("Previous (Ctrl+Left)") {
                    IconButton({ backend?.previous() }, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.FastRewind, "Previous", Modifier.size(28.dp)) }
                }
                DesktopTooltip(if (state.playing) "Pause (Space)" else "Play (Space)") {
                    IconButton({ backend?.togglePlay() }, Modifier.size(48.dp).desktopInteractive(CircleShape)) { AppIcon(if (state.playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, if (state.playing) "Pause" else "Play", Modifier.size(38.dp)) }
                }
                DesktopTooltip("Next (Ctrl+Right)") {
                    IconButton({ backend?.next() }, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.FastForward, "Next", Modifier.size(28.dp)) }
                }
                DesktopTooltip("Repeat (R)") {
                    IconButton({ backend?.cycleRepeat() }, Modifier.desktopInteractive(CircleShape)) {
                        AppIcon(if (state.repeat == RepeatUi.One) Icons.Rounded.RepeatOne else Icons.Rounded.Repeat, "Repeat", tint = if (state.repeat != RepeatUi.Off) toggleOnColor() else scheme.onSurface)
                    }
                }
            }
            Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                ElapsedSeek(backend, state.durationMs, muted, Modifier.weight(1f), enabled = song != null, coverUri = song?.coverUri)
                Text(formatDuration(state.durationMs / 1000), style = muted)
            }
        }
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
            if (shown("queue")) DesktopTooltip("Now playing & queue") {
                IconButton(onNowPlaying ?: onOpen, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.QueueMusic, "Queue", sz, tint = off) }
            }
            if (!wide) tools()
            if (shown("devices")) extras()
            var showEq by remember { mutableStateOf(false) }
            if (backend != null && backend.hasBass) {
                // Same kind of button as the equalizer: one tap switches untouched, exclusive output on or off.
                val bitPerfect by backend.bitPerfect.collectAsState()
                BitPerfectButton(bitPerfect, off, sz) { backend.setBitPerfect(!bitPerfect) }
            }
            if (backend != null) {
                val eqOn by backend.eqOn.collectAsState()
                DesktopTooltip("Equalizer") {
                    IconButton({ showEq = true }, Modifier.desktopInteractive(CircleShape)) { AppIcon(io.max.paperplay.ui.components.EqualizerBoardIcon, "Equalizer", sz, tint = if (eqOn) toggleOnColor() else off) }
                }
                if (showEq) EqualizerDialog(backend) { showEq = false }
            }
            Spacer(Modifier.width(8.dp))
            var lastVolume by remember { mutableStateOf(1f) }
            DesktopTooltip("Mute (M)") {
                IconButton({ if (volume > 0f) { lastVolume = volume; backend?.setVolume(0f) } else backend?.setVolume(lastVolume) }, Modifier.desktopInteractive(CircleShape)) { AppIcon(if (volume > 0f) Icons.Rounded.VolumeUp else Icons.Rounded.VolumeOff, "Mute", sz, tint = off) }
            }
            VolumeBar(volume, { backend?.setVolume(it) }, scheme.onSurface, Modifier.width(100.dp).pointerHoverIcon(PointerIcon.Hand))
            Spacer(Modifier.width(4.dp))
            if (shown("fullscreen")) DesktopTooltip("Full screen player") {
                IconButton(onOpen, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.Rounded.Fullscreen, "Full screen player", Modifier.size(26.dp), tint = off) }
            }
        }
    }
    }
}

/** Elapsed time and the thin seek bar; the only part of the player bar that follows the position. */
@Composable
private fun ElapsedSeek(backend: PlayerControls?, durationMs: Long, style: androidx.compose.ui.text.TextStyle, modifier: Modifier, enabled: Boolean, coverUri: String? = null) {
    val pos = backend?.position?.collectAsState()?.value ?: io.max.paperplay.ui.state.PositionUi(0, 0)
    Text(formatDuration(pos.positionMs / 1000), style = style)
    val palette = auroraPalette(coverUri, MaterialTheme.colorScheme.primary)
    val themed = LocalUiPrefs.current?.themedSeek == true && coverUri != null
    ThinSeek({ pos.progress(durationMs) }, { backend?.seekTo(it) }, modifier.padding(horizontal = 10.dp), enabled = enabled, colors = if (themed) palette else null)
}

/** A thin seek bar: tap or drag; the seek is sent when the drag ends. With [colors] the played part is a gradient of the cover's colours. */
@Composable
fun ThinSeek(progress: () -> Float, onSeek: (Float) -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, colors: List<Color>? = null) {
    var dragging by remember { mutableStateOf<Float?>(null) }
    val hoverSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }
    val hovered by hoverSource.collectIsHoveredAsState()
    val trackHeight by animateDpAsState(
        targetValue = if ((hovered || dragging != null) && enabled) 6.dp else 4.dp,
        animationSpec = io.max.paperplay.ui.theme.desktopHoverSpec(),
        label = "seekHeight",
    )
    val scheme = MaterialTheme.colorScheme
    BoxWithConstraints(modifier.height(20.dp)) {
        val w = constraints.maxWidth.toFloat().coerceAtLeast(1f)
        Box(
            Modifier.fillMaxSize()
                .then(if (enabled) Modifier.pointerHoverIcon(PointerIcon.Hand) else Modifier)
                .hoverable(hoverSource, enabled = enabled)
                .pointerInput(w, enabled) { if (enabled) detectTapGestures { onSeek((it.x / w).coerceIn(0f, 1f)) } }
                .pointerInput(w, enabled) {
                    if (enabled) detectHorizontalDragGestures(
                        onDragEnd = { dragging?.let(onSeek); dragging = null }, onDragCancel = { dragging = null },
                    ) { change, _ -> change.consume(); dragging = (change.position.x / w).coerceIn(0f, 1f) }
                },
            contentAlignment = Alignment.CenterStart,
        ) {
            Box(Modifier.fillMaxWidth().height(trackHeight).clip(CircleShape).background(scheme.onSurface.copy(alpha = 0.2f)))
            val fill = scheme.onSurface
            Box(Modifier.fillMaxWidth().height(trackHeight).clip(CircleShape).drawBehind {
                val played = Size(size.width * (dragging ?: progress()).coerceIn(0f, 1f), size.height)
                if (colors != null && colors.size >= 2) drawRect(androidx.compose.ui.graphics.Brush.horizontalGradient(colors, 0f, size.width), size = played)
                else drawRect(fill, size = played)
            })
        }
    }
}

/** What the app is doing right now; the full task list comes with the tasks work. */
@Composable
fun TasksPage(scan: ScanUi?, modifier: Modifier = Modifier, onBack: (() -> Unit)? = null) {
    Column(modifier) {
        if (onBack != null) {
            BackTopBar("Tasks", onBack)
        } else {
            TopBar("Tasks")
        }
        Row(Modifier.padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            AppIcon(Icons.Rounded.TaskAlt, null)
            Text(scan?.text ?: "Nothing running", Modifier.padding(start = 12.dp), style = MaterialTheme.typography.bodyLarge)
        }
    }
}

/** Settings on a desktop: categories on the left, the chosen page on the right. */
@Composable
fun DesktopSettings(
    stack: MutableList<String>, prefs: UiPrefs, conn: ConnectionUi, songCount: Int, backend: CoreBackend,
    onRestore: () -> Unit, onExit: () -> Unit, modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val page = stack.lastOrNull()
    val root = stack.firstOrNull()
    val catListState = androidx.compose.foundation.lazy.rememberLazyListState()
    val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
    val shiftPx = with(LocalDensity.current) { io.max.paperplay.ui.theme.Motion.Desktop.PageShiftDp.dp.roundToPx() }
    val sideShiftPx = with(LocalDensity.current) { io.max.paperplay.ui.theme.Motion.Desktop.PageSideShiftDp.dp.roundToPx() }
    Row(modifier) {
        Column(Modifier.width(300.dp).fillMaxHeight()) {
            Row(Modifier.padding(start = 4.dp, end = 8.dp, top = 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                DesktopTooltip("Back") {
                    IconButton({ if (stack.size > 1) stack.removeAt(stack.lastIndex) else onExit() }, Modifier.desktopInteractive(CircleShape)) { AppIcon(Icons.AutoMirrored.Rounded.ArrowBack, "Back") }
                }
                Text("Settings", Modifier.padding(start = 4.dp), style = MaterialTheme.typography.headlineMedium)
            }
            DesktopScrollHost(catListState, Modifier.fillMaxSize()) { scrollMod ->
                LazyColumn(scrollMod, state = catListState) {
                    item {
                        val profileOn = root == "profile"
                        val profileFill by animateColorAsState(if (profileOn) scheme.surfaceContainerHighest else Color.Transparent, io.max.paperplay.ui.theme.motionColorSpec(), label = "setProf")
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 2.dp).clip(RoundedCornerShape(10.dp))
                                .background(profileFill)
                                .desktopInteractive(RoundedCornerShape(10.dp))
                                .clickable { stack.clear(); stack.add("profile") }.padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Avatar(prefs.profilePhoto, prefs.profileName, 32.dp)
                            Text(prefs.profileName, Modifier.padding(start = 12.dp), style = MaterialTheme.typography.titleSmall)
                        }
                    }
                    categories.filter { !it.phoneOnly }.groupBy { it.group }.forEach { (group, list) ->
                    item(key = "group-${group.name}") {
                        Text(group.label, Modifier.padding(start = 20.dp, top = 12.dp, bottom = 2.dp), style = MaterialTheme.typography.labelMedium, color = scheme.onSurfaceVariant)
                    }
                    items(list, key = { it.id }) { c ->
                        val on = root == c.id
                        val rowFill by animateColorAsState(if (on) scheme.surfaceContainerHighest else Color.Transparent, io.max.paperplay.ui.theme.motionColorSpec(), label = "setCat")
                        Row(
                            Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 2.dp).clip(RoundedCornerShape(10.dp))
                                .background(rowFill)
                                .desktopInteractive(RoundedCornerShape(10.dp))
                                .clickable { stack.clear(); stack.add(c.id) }.padding(horizontal = 12.dp, vertical = 9.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            AppIcon(c.icon, null, Modifier.size(22.dp))
                            Column(Modifier.padding(start = 12.dp)) {
                                Text(c.title, style = MaterialTheme.typography.bodyLarge, fontWeight = if (on) FontWeight.Bold else null)
                                Text(c.text, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = scheme.onSurfaceVariant)
                            }
                        }
                    }
                    }
                }
            }
        }
        Box(Modifier.width(1.dp).fillMaxHeight().padding(vertical = 16.dp).background(scheme.outlineVariant.copy(alpha = 0.5f)))
        Column(Modifier.weight(1f).fillMaxHeight()) {
            val title = categories.firstOrNull { it.id == page }?.title ?: settingsPageTitle(page) ?: "Settings"
            if (stack.size > 1) BackTopBar(title, onBack = { stack.removeAt(stack.lastIndex) }) {
                val loggedIn by backend.account.loggedIn.collectAsState()
                if (page == "channels" && loggedIn) androidx.compose.material3.IconButton({ stack.add("index") }) { AppIcon(Icons.Rounded.Forum, "Your chats and channels") }
                if (page == "eq") EqualizerTopBarActions(backend)
            }
            else Row(
                Modifier.fillMaxWidth().padding(start = 20.dp, end = 16.dp, top = 24.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(title, Modifier.weight(1f), style = MaterialTheme.typography.headlineMedium)
                if (page == "eq") EqualizerTopBarActions(backend)
            }

            AnimatedContent(
                targetState = page,
                modifier = Modifier.weight(1f).fillMaxWidth(),
                transitionSpec = { desktopPageTransition(NavMove.Switch, reduceMotion, shiftPx, sideShiftPx) },
                label = "settingsPage",
            ) { targetPage ->
                val isLazy = targetPage == "missing" || targetPage == "dupes" || targetPage == "index" || targetPage == "log" || targetPage == "changelog" || targetPage == "eq" || targetPage?.startsWith("index:") == true
                if (isLazy) {
                    Column(Modifier.fillMaxSize().widthIn(max = 880.dp).padding(bottom = 24.dp)) {
                        if (targetPage != null) SettingsPage(targetPage, stack, prefs, conn, songCount, backend, onRestore)
                    }
                } else {
                    val contentScroll = rememberScrollState()
                    DesktopScrollHost(contentScroll, Modifier.fillMaxSize()) { scrollMod ->
                        Column(
                            // Sliders and rows stop at a readable width instead of stretching across a wide window.
                            scrollMod.widthIn(max = 880.dp).verticalScroll(contentScroll).padding(bottom = 24.dp)
                        ) {
                            if (targetPage != null) SettingsPage(targetPage, stack, prefs, conn, songCount, backend, onRestore)
                        }
                    }
                }
            }
        }
    }
}


@Preview
@Composable
fun SidebarPreview() {
    Sidebar(
        page = "home", playlistId = null,
        playlists = listOf(GroupUi("1", "Chill Vibes", "10 songs"), GroupUi("2", "Workout", "25 songs")),
        expanded = true, onToggle = {},
        onPage = {}, onPlaylist = {}, onNewPlaylist = {}, modifier = Modifier.width(240.dp).height(640.dp),
    )
}

@Preview
@Composable
fun ThinSeekPreview() {
    ThinSeek(progress = { 0.4f }, onSeek = {}, modifier = Modifier.width(320.dp))
}

@Preview
@Composable
fun TasksPagePreview() {
    TasksPage(ScanUi("Reading channel 3 of 5", null))
}

@Composable
private fun PlayerBarPreviewContent(state: PlaybackUiState, dark: Boolean) = io.max.paperplay.ui.PreviewFrame(dark) {
    PlayerBar(
        state = state, volume = 0.8f, backend = io.max.paperplay.ui.FakePlayerControls(),
        actions = io.max.paperplay.ui.previewActions(), onOpen = {},
        modifier = Modifier.background(MaterialTheme.colorScheme.surfaceContainer),
    )
}

@Preview(name = "Player bar 1280", widthDp = 1280, heightDp = 84, showBackground = true)
@Composable
fun PlayerBarPreview() = PlayerBarPreviewContent(io.max.paperplay.ui.previewPlayback(), dark = false)

@Preview(name = "Player bar 900 dark", widthDp = 900, heightDp = 84, showBackground = true)
@Composable
fun PlayerBarNarrowPreview() = PlayerBarPreviewContent(io.max.paperplay.ui.previewPlayback(false), dark = true)

@Preview(name = "Player bar idle", widthDp = 1280, heightDp = 84, showBackground = true)
@Composable
fun PlayerBarIdlePreview() = PlayerBarPreviewContent(PlaybackUiState(), dark = false)

/** Volume slider drawn in one canvas so the track and thumb always share a centre line. */
@Composable
internal fun VolumeBar(value: Float, onChange: (Float) -> Unit, color: Color, modifier: Modifier = Modifier) {
    var drag by remember { mutableStateOf<Float?>(null) }
    val shown = drag ?: value
    var widthPx by remember { mutableStateOf(1f) }
    fun at(x: Float) = (x / widthPx).coerceIn(0f, 1f)
    androidx.compose.foundation.Canvas(
        modifier.height(24.dp)
            .onSizeChanged { widthPx = it.width.toFloat().coerceAtLeast(1f) }
            .pointerInput(Unit) { detectTapGestures { onChange(at(it.x)) } }
            .pointerInput(Unit) {
                detectDragGestures(onDragStart = { drag = at(it.x); onChange(at(it.x)) }, onDragEnd = { drag = null }, onDragCancel = { drag = null }) { c, _ ->
                    val v = at(c.position.x); drag = v; onChange(v)
                }
            },
    ) {
        val r = 5.dp.toPx(); val h = 4.dp.toPx(); val y = size.height / 2
        val x = r + (size.width - 2 * r) * shown
        drawRoundRect(color.copy(alpha = 0.2f), Offset(0f, y - h / 2), Size(size.width, h), CornerRadius(h / 2))
        drawRoundRect(color, Offset(0f, y - h / 2), Size(x, h), CornerRadius(h / 2))
        drawCircle(color, r, Offset(x, y))
    }
}
