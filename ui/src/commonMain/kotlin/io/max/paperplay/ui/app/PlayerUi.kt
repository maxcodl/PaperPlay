package io.max.paperplay.ui.app

import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.uniqueKeys
import io.max.paperplay.ui.components.toggleOnColor
import io.max.paperplay.ui.theme.motionItem
import kotlinx.coroutines.launch

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.outlined.Bedtime
import androidx.compose.material.icons.outlined.Lyrics
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Fullscreen
import androidx.compose.material.icons.rounded.FullscreenExit
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.NightsStay
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.RepeatOne
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import io.max.paperplay.ui.nowMoment
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.PlatformBackHandler
import io.max.paperplay.ui.components.AuroraSeek
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.components.SongMenu
import io.max.paperplay.ui.components.WavySeek
import io.max.paperplay.ui.logic.formatDuration
import androidx.compose.material.icons.rounded.Computer
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material.icons.rounded.Devices
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.FastRewind
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.automirrored.rounded.VolumeDown
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import io.max.paperplay.ui.state.PlaybackUiState
import io.max.paperplay.ui.state.RepeatUi
import io.max.paperplay.ui.state.SongUi
import io.max.paperplay.ui.theme.amoled
import io.max.paperplay.ui.theme.schemeFromSeed

/**
 * The full-screen player host: switches between [DefaultFullPlayer] and [ModernFullPlayer] from
 * [UiPrefs.playerStyle] while sharing state, queue, and dialogs.
 */
@Composable
fun FullPlayer(
    state: PlaybackUiState, error: String?, backend: PlayerControls, actions: ListActions, onClose: () -> Unit, modifier: Modifier = Modifier,
    onOpenSettings: ((String) -> Unit)? = null,
    onOpenEq: (() -> Unit)? = null,
    onOpenLyrics: (() -> Unit)? = null,
) {
    val song = state.current ?: return
    val base = MaterialTheme.colorScheme
    val scheme = coverScheme(song.coverUri) ?: remember(base.primary) { schemeFromSeed(base.primary.toArgb(), dark = true) }
    var showQueue by remember { mutableStateOf(false) }
    var showLyrics by remember { mutableStateOf(false) }
    var outputInfoOpen by remember { mutableStateOf(false) }
    var showSleep by remember { mutableStateOf(false) }
    var showSpeed by remember { mutableStateOf(false) }
    var showEq by remember { mutableStateOf(false) }
    var devicesOpen by remember { mutableStateOf(false) }
    val fullscreen by WindowFullscreen.on.collectAsState()
    val canFullscreen by WindowFullscreen.supported.collectAsState()
    val coverBounds = LocalCoverBounds.current
    androidx.compose.runtime.SideEffect { coverBounds?.queueOpen = showQueue }
    androidx.compose.runtime.DisposableEffect(Unit) { onDispose { WindowFullscreen.on.value = false; coverBounds?.clearFull() } }
    PlatformBackHandler(showQueue) { showQueue = false }

    val standbyPrefs = if (io.max.paperplay.ui.isPhone) LocalUiPrefs.current?.standby else null
    var standby by remember { mutableStateOf(false) }
    val openStandby: (() -> Unit)? = if (standbyPrefs != null) ({ standby = true }) else null
    if (standby && standbyPrefs != null) StandbyScreen(state, backend, standbyPrefs) { standby = false }

    val style = resolveEffectivePlayerStyle(LocalUiPrefs.current)
    if (style == PlayerStyle.Modern) {
        val appDark = base.background.luminance() < 0.5f
        val appAmoled = appDark && (io.max.paperplay.ui.theme.LocalModernTokens.current.amoled || LocalUiPrefs.current?.amoled == true)
        val modernBase = coverScheme(song.coverUri, dark = appDark)
            ?: remember(base.primary, appDark) { schemeFromSeed(base.primary.toArgb(), dark = appDark) }
        val modernScheme = remember(modernBase, appAmoled) { if (appAmoled) modernBase.amoled() else modernBase }
        ModernFullPlayer(
            state = state,
            error = error,
            backend = backend,
            actions = actions,
            scheme = modernScheme,
            showQueue = showQueue,
            showLyrics = showLyrics,
            fullscreen = fullscreen,
            canFullscreen = canFullscreen,
            onClose = onClose,
            onSetShowQueue = { showQueue = it },
            onSetShowLyrics = { showLyrics = it },
            onOpenEq = onOpenEq ?: { showEq = true },
            onOpenLyrics = onOpenLyrics,
            onOpenOutputInfo = { outputInfoOpen = true },
            onOpenSleep = { showSleep = true },
            onOpenSpeed = { showSpeed = true },
            onOpenDevices = onOpenSettings?.let { { devicesOpen = true } },
            onOpenStandby = openStandby,
            modifier = modifier,
            dark = appDark,
            amoled = appAmoled,
        )
    } else {
        DefaultFullPlayer(
            song = song,
            state = state,
            error = error,
            backend = backend,
            actions = actions,
            scheme = scheme,
            showQueue = showQueue,
            showLyrics = showLyrics,
            fullscreen = fullscreen,
            canFullscreen = canFullscreen,
            onClose = onClose,
            onSetShowQueue = { showQueue = it },
            onSetShowLyrics = { showLyrics = it },
            onOpenSettings = onOpenSettings,
            onOpenEq = onOpenEq,
            onOpenLyrics = onOpenLyrics,
            onOpenStandby = openStandby,
            modifier = modifier,
        )
    }

    if (outputInfoOpen) OutputInfoDialog(song, backend) { outputInfoOpen = false }
    if (showSleep) SleepTimerDialog(backend) { showSleep = false }
    if (showSpeed) SpeedDialog(backend) { showSpeed = false }
    if (showEq) EqualizerDialog(backend) { showEq = false }
    if (devicesOpen && onOpenSettings != null) {
        val switchOutput = io.max.paperplay.ui.rememberOutputSwitcher()
        val activeId = LocalOutputSwitch.current?.active?.collectAsState()?.value
        PhoneDevicesDialog({ id -> onClose(); onOpenSettings(id) }, switchOutput, if (activeId == null) song else null) { devicesOpen = false }
    }
}

@Composable
private fun DefaultFullPlayer(
    song: SongUi,
    state: PlaybackUiState,
    error: String?,
    backend: PlayerControls,
    actions: ListActions,
    scheme: ColorScheme,
    showQueue: Boolean,
    showLyrics: Boolean,
    fullscreen: Boolean,
    canFullscreen: Boolean,
    onClose: () -> Unit,
    onSetShowQueue: (Boolean) -> Unit,
    onSetShowLyrics: (Boolean) -> Unit,
    onOpenSettings: ((String) -> Unit)?,
    onOpenEq: (() -> Unit)?,
    onOpenLyrics: (() -> Unit)?,
    onOpenStandby: (() -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val top by animateColorAsState(lerp(scheme.primaryContainer, Color.Black, 0.25f), io.max.paperplay.ui.theme.motionWashSpec())
    val mid by animateColorAsState(lerp(scheme.surfaceContainerLow, Color.Black, 0.75f), io.max.paperplay.ui.theme.motionWashSpec())
    val insets = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    MaterialTheme(colorScheme = scheme) {
        BoxWithConstraints(
            modifier.fillMaxSize()
                .background(Brush.verticalGradient(0f to top, 0.6f to mid, 1f to Color.Black))
                .padding(top = insets, bottom = bottom),
        ) {
            val wide = maxWidth >= 900.dp && !(io.max.paperplay.ui.isPhone && maxWidth > maxHeight)
            when {
                wide -> Row(Modifier.fillMaxSize()) {
                    // The song gets the larger share and sits a little right of centre; the queue and lyrics take the rest.
                    Column(Modifier.weight(1.2f).fillMaxHeight().padding(start = 40.dp)) {
                        Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClose) { AppIcon(Icons.Rounded.KeyboardArrowDown, "Close player", Modifier.size(32.dp)) }
                            Spacer(Modifier.weight(1f))
                            if (canFullscreen) IconButton(WindowFullscreen::toggle) {
                                AppIcon(if (fullscreen) Icons.Rounded.FullscreenExit else Icons.Rounded.Fullscreen, if (fullscreen) "Exit full screen" else "Full screen", Modifier.size(28.dp))
                            }
                        }
                        PlayerBody(song, state, error, backend, actions, onClose, grabber = false, Modifier.weight(1f), contentMax = 720.dp, onOpenEq = onOpenEq, onOpenLyrics = { onSetShowLyrics(true) })
                    }
                    Column(Modifier.weight(1f).fillMaxHeight().padding(end = 16.dp)) {
                        Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                            listOf(false to "Queue", true to "Lyrics").forEach { (lyr, name) ->
                                val sel = showLyrics == lyr
                                Text(
                                    name,
                                    Modifier.clip(RoundedCornerShape(50)).clickable { onSetShowLyrics(lyr) }
                                        .background(if (sel) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f) else Color.Transparent)
                                        .padding(horizontal = 14.dp, vertical = 6.dp),
                                    style = MaterialTheme.typography.titleMedium,
                                    color = if (sel) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                        if (showLyrics) LyricsPane(song, backend, large = false, modifier = Modifier.weight(1f).fillMaxWidth())
                        else QueueList(state, backend, Modifier.weight(1f))
                    }
                }
                else -> androidx.compose.animation.Crossfade(showQueue, animationSpec = io.max.paperplay.ui.theme.motionTween(), label = "queue") { queueShown ->
                    if (queueShown) Column(Modifier.fillMaxSize()) {
                        Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                            IconButton({ onSetShowQueue(false) }) { AppIcon(Icons.Rounded.KeyboardArrowDown, "Back to the song", Modifier.size(32.dp)) }
                            Text("Queue", Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                            Text("${state.queue.size} songs", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(Modifier.width(12.dp))
                        }
                        QueueList(state, backend, Modifier.weight(1f))
                    } else PlayerBody(song, state, error, backend, actions, onClose, grabber = true, Modifier.fillMaxSize(), onQueue = { onSetShowQueue(true) }, onStandby = onOpenStandby, onDevices = onOpenSettings?.let { open -> { id: String -> onClose(); open(id) } }, onOpenEq = onOpenEq, onOpenLyrics = onOpenLyrics)
                }
            }
        }
    }
}

@Composable
private fun PlayerBody(
    song: SongUi, state: PlaybackUiState, error: String?, backend: PlayerControls, actions: ListActions, onClose: () -> Unit,
    grabber: Boolean, modifier: Modifier = Modifier, onQueue: (() -> Unit)? = null, onDevices: ((String) -> Unit)? = null,
    contentMax: androidx.compose.ui.unit.Dp = 560.dp, onStandby: (() -> Unit)? = null,
    onOpenEq: (() -> Unit)? = null,
    onOpenLyrics: (() -> Unit)? = null,
) {
    val scheme = MaterialTheme.colorScheme
    var outputInfoOpen by remember { mutableStateOf(false) }
    BoxWithConstraints(modifier, contentAlignment = Alignment.TopCenter) {
        // A phone on its side: cover left, controls scroll on the right.
        val short = io.max.paperplay.ui.isPhone && maxWidth > maxHeight
        // Room the controls need, so short screens shrink the cover, not them.
        val art = if (short) (maxHeight - 40.dp).coerceAtLeast(120.dp) else minOf(maxWidth - 48.dp, maxHeight - 25.dp - 410.dp).coerceAtLeast(120.dp)
        val controller = LocalPlayerTransition.current
        val stage = controller.contentStage
        val interactive = stage >= PlayerContentStage.Interactive
        val animateWave = stage >= PlayerContentStage.SettledEffects
        val stage1Alpha by animateFloatAsState(
            targetValue = if (interactive) 1f else 0f,
            animationSpec = if (controller.standalone || controller.reduceMotion) androidx.compose.animation.core.snap() else io.max.paperplay.ui.theme.playerEffectFadeSpec(),
            label = "playerStage1",
        )
        val cover: @Composable (Modifier) -> Unit = { cm ->
            // Drag down on the cover and the whole player follows your finger; sideways changes song, up opens the queue.
            Column(
                cm.playerSheetDrag(
                    controller = controller,
                    onQueue = onQueue,
                    onNext = backend::next,
                    onPrevious = backend::previous,
                ),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                if (grabber) {
                    Box(
                        Modifier
                            .size(width = 72.dp, height = 32.dp)
                            .semantics { contentDescription = "Close player" }
                            .clickable(onClickLabel = "Close player", role = Role.Button, onClick = onClose),
                        contentAlignment = Alignment.Center,
                    ) {
                        Box(Modifier.size(40.dp, 5.dp).clip(RoundedCornerShape(3.dp)).background(scheme.onSurface.copy(alpha = 0.35f)))
                    }
                } else {
                    Spacer(Modifier.height(8.dp))
                }
                Artwork(song, state.playing, art)
            }
        }
        // Everything below shares the leftover height evenly.
        val lower: @Composable (Modifier) -> Unit = { lm ->
            Column(lm.fillMaxWidth(), verticalArrangement = if (short) Arrangement.spacedBy(8.dp) else Arrangement.SpaceEvenly) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.animation.Crossfade(
                        Pair(song.title, song.artist), Modifier.weight(1f).padding(start = 12.dp, end = 4.dp).clipToBounds(),
                        animationSpec = io.max.paperplay.ui.theme.motionTween(io.max.paperplay.ui.theme.Motion.STANDARD), label = "song title",
                    ) { (title, artist) ->
                        Column {
                            Text(title, modifier = Modifier.basicMarquee(), maxLines = 1, style = MaterialTheme.typography.headlineSmall)
                            ArtistLinks(
                                artist, MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Medium), scheme.onSurface.copy(alpha = 0.7f),
                            )
                            if (song.album.isNotBlank()) AlbumLink(song.album, MaterialTheme.typography.bodyMedium, scheme.onSurface.copy(alpha = 0.5f))
                        }
                    }
                    PreviewCopyButton(song)
                    IconButton({ actions.setFavorite(song, !song.favorite) }) {
                        AppIcon(
                            if (song.favorite) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                            if (song.favorite) "Remove from favorites" else "Add to favorites",
                            Modifier.size(20.dp),
                            tint = if (song.favorite) scheme.primary else scheme.onSurface,
                        )
                    }
                    SongMenu(song, actions.rowActions(), Icons.Rounded.MoreHoriz, onOutputInfo = { outputInfoOpen = true })
                    Spacer(Modifier.width(4.dp))
                }
                Column(Modifier.padding(horizontal = 12.dp)) {
                    if (error != null) Text(error, color = scheme.error, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(bottom = 4.dp))
                    if (interactive) {
                        Box(Modifier.graphicsLayer { alpha = stage1Alpha }) {
                            Column {
                                PlayerProgress(song, state, backend, onBadge = { outputInfoOpen = true }, animateWave = animateWave)
                            }
                        }
                    } else {
                        // Stage 0 placeholder reserves exact height (52dp bar + 8dp spacer + 20dp time row) so Stage 1 never jumps layout.
                        Box(Modifier.fillMaxWidth().height(80.dp), contentAlignment = Alignment.CenterStart) {
                            Box(Modifier.fillMaxWidth().height(3.dp).clip(RoundedCornerShape(2.dp)).background(scheme.onSurface.copy(alpha = 0.2f)))
                        }
                    }
                }
                if (outputInfoOpen) OutputInfoDialog(song, backend) { outputInfoOpen = false }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly, verticalAlignment = Alignment.CenterVertically) {
                    IconButton(backend::previous, Modifier.size(72.dp)) { AppIcon(Icons.Rounded.FastRewind, "Previous", Modifier.size(48.dp)) }
                    PlayPauseButton(state.playing, backend::togglePlay)
                    IconButton(backend::next, Modifier.size(72.dp)) { AppIcon(Icons.Rounded.FastForward, "Next", Modifier.size(48.dp)) }
                }
                if (interactive) {
                    val volume by backend.volume.collectAsState()
                    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp).graphicsLayer { alpha = stage1Alpha }, verticalAlignment = Alignment.CenterVertically) {
                        AppIcon(Icons.AutoMirrored.Rounded.VolumeDown, "Quieter", Modifier.size(18.dp), tint = scheme.onSurface.copy(alpha = 0.65f))
                        VolumeBar(volume, backend::setVolume, scheme.onSurface, Modifier.weight(1f).padding(horizontal = 10.dp))
                        AppIcon(Icons.AutoMirrored.Rounded.VolumeUp, "Louder", Modifier.size(18.dp), tint = scheme.onSurface.copy(alpha = 0.65f))
                    }
                    // Output device pill, like the AirPods one in Apple Music.
                    val out = LocalOutputDevice.current ?: io.max.paperplay.ui.rememberOutputDevice()
                    var devicesOpen by remember { mutableStateOf(false) }
                    val switchOutput = io.max.paperplay.ui.rememberOutputSwitcher()
                    // When another linked device is the one playing, the pill says so instead of naming this phone's speaker or headphones.
                    val activeId = LocalOutputSwitch.current?.active?.collectAsState()?.value
                    val linked = LocalLanSync.current?.connected?.collectAsState()?.value.orEmpty()
                    val remoteDevice = activeId?.let { id -> linked.firstOrNull { it.id == id } }
                    Row(Modifier.fillMaxWidth().graphicsLayer { alpha = stage1Alpha }, horizontalArrangement = Arrangement.Center) {
                        Row(
                            Modifier.clip(RoundedCornerShape(50)).background(scheme.onSurface.copy(alpha = 0.14f))
                                .clickable(enabled = switchOutput != null || onDevices != null) { if (onDevices != null) devicesOpen = true else switchOutput?.invoke() }.padding(horizontal = 20.dp, vertical = 9.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            AppIcon(
                                when {
                                    remoteDevice != null -> if (remoteDevice.desktop) Icons.Rounded.Computer else Icons.Rounded.PhoneAndroid
                                    out.external -> Icons.Rounded.Headphones
                                    else -> Icons.Rounded.PhoneAndroid
                                }, null, Modifier.size(20.dp),
                            )
                            // A short name with a quiet line under it: "Headphones" over "Realtek Audio", or "Playing on Phone" over "via Buds".
                            val (title, caption) = if (remoteDevice != null) {
                                val via = LocalLanSync.current?.remoteNow?.collectAsState()?.value?.get(remoteDevice.id)?.outName?.let { splitDeviceName(it).first }
                                "Playing on ${remoteDevice.name}" to via?.let { "via $it" }
                            } else splitDeviceName(out.name)
                            Column(Modifier.widthIn(max = 220.dp)) {
                                Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall)
                                if (caption != null) Text(caption, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.labelSmall, color = scheme.onSurface.copy(alpha = 0.6f))
                            }
                        }
                    }
                    if (devicesOpen && onDevices != null) PhoneDevicesDialog(onDevices, switchOutput, if (remoteDevice == null) song else null) { devicesOpen = false }
                    Row(Modifier.fillMaxWidth().graphicsLayer { alpha = stage1Alpha }, horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        if (onOpenLyrics != null) {
                            IconButton(onOpenLyrics, enabled = state.current != null) { AppIcon(Icons.Outlined.Lyrics, "Lyrics") }
                        }
                        IconButton(backend::toggleShuffle) {
                            AppIcon(Icons.Rounded.Shuffle, "Shuffle", tint = if (state.shuffle) toggleOnColor() else scheme.onSurface)
                        }
                        IconButton(backend::cycleRepeat) {
                            AppIcon(
                                if (state.repeat == RepeatUi.One) Icons.Rounded.RepeatOne else Icons.Rounded.Repeat, "Repeat",
                                tint = if (state.repeat != RepeatUi.Off) toggleOnColor() else scheme.onSurface,
                            )
                        }
                        if (onQueue != null) IconButton(onQueue) { AppIcon(Icons.AutoMirrored.Rounded.QueueMusic, "Queue") }
                        if (backend.hasBass) {
                            val bitPerfect by backend.bitPerfect.collectAsState()
                            BitPerfectButton(bitPerfect, scheme.onSurface.copy(alpha = 0.7f), Modifier.size(22.dp), bitPerfectUnavailable(backend)) { backend.setBitPerfect(!bitPerfect) }
                        }
                        // Less used controls live behind one button.
                        var showSleep by remember { mutableStateOf(false) }
                        val sleepAt by backend.sleepAt.collectAsState()
                        var showSpeed by remember { mutableStateOf(false) }
                        val speed by backend.speed.collectAsState()
                        var more by remember { mutableStateOf(false) }
                        var showEq by remember { mutableStateOf(false) }
                        val eqOn by backend.eqOn.collectAsState()
                        Box {
                            IconButton({ more = true }) {
                                AppIcon(Icons.Rounded.Tune, "More controls", tint = if (sleepAt != null || speed != 1f || eqOn) toggleOnColor() else scheme.onSurface)
                            }
                            androidx.compose.material3.DropdownMenu(more, { more = false }) {
                                androidx.compose.material3.DropdownMenuItem({ Text(if (sleepAt != null) "Sleep timer (on)" else "Sleep timer") }, { more = false; showSleep = true })
                                androidx.compose.material3.DropdownMenuItem({ Text(if (eqOn) "Equalizer (on)" else "Equalizer") }, {
                                    more = false
                                    if (onOpenEq != null) onOpenEq() else showEq = true
                                })
                                androidx.compose.material3.DropdownMenuItem({ Text("Speed (${speedLabel(speed)})") }, { more = false; showSpeed = true })
                                if (onStandby != null) androidx.compose.material3.DropdownMenuItem({ Text("Standby mode") }, { more = false; onStandby() })
                                if (onDevices != null) androidx.compose.material3.DropdownMenuItem({ Text("Devices") }, { more = false; devicesOpen = true })
                            }
                        }
                        if (showSleep) SleepTimerDialog(backend) { showSleep = false }
                        if (showSpeed) SpeedDialog(backend) { showSpeed = false }
                        if (showEq) EqualizerDialog(backend) { showEq = false }
                    }
                } else {
                    // Stage 0 placeholders preserve exact spacing for SpaceEvenly without composing secondary rows.
                    Spacer(Modifier.height(36.dp))
                    Spacer(Modifier.height(42.dp))
                    Spacer(Modifier.height(48.dp))
                }
            }
        }
        if (short) Row(Modifier.fillMaxSize().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(20.dp), verticalAlignment = Alignment.CenterVertically) {
            cover(Modifier.width(art))
            lower(Modifier.weight(1f).fillMaxHeight().verticalScroll(androidx.compose.foundation.rememberScrollState()))
        } else Column(Modifier.widthIn(max = contentMax).fillMaxHeight().padding(horizontal = 12.dp)) {
            cover(Modifier.fillMaxWidth())
            lower(Modifier.weight(1f))
        }
    }
}

/** The cover: full size while playing and slightly smaller when paused, in a slot that never moves. */
@Composable
private fun Artwork(song: SongUi, playing: Boolean, size: androidx.compose.ui.unit.Dp) {
    val controller = LocalPlayerTransition.current
    val coverBounds = LocalCoverBounds.current
    val scale by animateFloatAsState(if (playing) 1f else 0.92f, io.max.paperplay.ui.theme.motionPlayMorphSpec())
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        // One shadow around the cover; the covers of two songs fade into each other inside it.
        Box(
            Modifier
                .scale(scale)
                .registerFullCoverBounds(coverBounds)
                .graphicsLayer { alpha = if (controller.isCoverFlightActive(coverBounds)) 0f else 1f }
                .shadow(24.dp, RoundedCornerShape(28.dp), ambientColor = Color.Black, spotColor = Color.Black),
        ) {
            androidx.compose.animation.Crossfade(
                song.coverUri to song.id, animationSpec = io.max.paperplay.ui.theme.motionTween(io.max.paperplay.ui.theme.Motion.EMPHASIZED), label = "cover",
            ) { (uri, id) -> CoverImage(uri, id, size = size, radius = 28.dp) }
        }
    }
}

@Composable
private fun PlayPauseButton(playing: Boolean, onToggle: () -> Unit) {
    IconButton(onToggle, Modifier.size(88.dp)) {
        AppIcon(if (playing) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, if (playing) "Pause" else "Play", Modifier.size(64.dp))
    }
}

@Composable
internal fun PlayerProgress(
    song: SongUi,
    state: PlaybackUiState,
    backend: PlayerControls,
    onBadge: (() -> Unit)? = null,
    animateWave: Boolean = true,
) {
    val scheme = MaterialTheme.colorScheme
    val muted = MaterialTheme.typography.labelMedium.copy(color = scheme.onSurface.copy(alpha = 0.65f))
    val total = if (state.durationMs > 0) state.durationMs else song.durationSec * 1000L
    val pos by backend.position.collectAsState()
    val style = LocalUiPrefs.current?.progressBarStyle ?: ProgressBarStyle.SQUIGGLY_WAVE
    val label = formatDuration(pos.positionMs / 1000)
    val longPressLabel: (Float) -> String = { fraction -> formatDuration((total * fraction / 1000L).toLong()) }
    when (style) {
        ProgressBarStyle.SQUIGGLY_WAVE -> WavySeek(
            progress = { pos.progress(state.durationMs) }, buffered = { pos.bufferedProgress(state.durationMs) }, playing = state.playing,
            onSeek = backend::seekTo,
            modifier = Modifier.fillMaxWidth(),
            label = label,
            longPressLabel = longPressLabel,
            animateWave = animateWave,
        )
        ProgressBarStyle.AURORA_WAVE -> AuroraSeek(
            progress = { pos.progress(state.durationMs) }, buffered = { pos.bufferedProgress(state.durationMs) }, playing = state.playing,
            onSeek = backend::seekTo,
            colors = auroraPalette(song.coverUri, scheme.primary),
            modifier = Modifier.fillMaxWidth(),
            label = label,
            longPressLabel = longPressLabel,
            animateWave = animateWave,
        )
    }
    Spacer(Modifier.height(8.dp))
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(formatDuration(pos.positionMs / 1000), Modifier.weight(1f), style = muted)
        if (onBadge != null) {
            io.max.paperplay.ui.components.AudioBadge(song, Modifier.clip(RoundedCornerShape(8.dp)).background(scheme.onSurface.copy(alpha = 0.12f)).clickable(onClick = onBadge).padding(horizontal = 10.dp, vertical = 4.dp))
        }
        Text("-" + formatDuration(((total - pos.positionMs) / 1000).coerceAtLeast(0)), Modifier.weight(1f), style = muted, textAlign = TextAlign.End)
    }
}

@Composable
private fun SongInfoDialog(song: SongUi, onDismiss: () -> Unit) {
    val rows = listOfNotNull(
        "Artist" to song.artist, "Album" to song.album.ifBlank { null }, "Genre" to song.genre,
        "Year" to song.year?.toString(), "Length" to formatDuration(song.durationSec.toLong()),
        "Size" to "${song.sizeBytes / 100_000 / 10.0} MB", "Quality" to song.qualityLabel, "Plays" to song.plays.toString(),
    ).filter { it.second != null }
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = overlayRim(appShape(28.dp, CornerArea.Dialogs)), shape = appShape(28.dp, CornerArea.Dialogs), containerColor = overlayColor(),
        confirmButton = { TextButton(onDismiss) { Text("Close") } },
        title = { Text(song.title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                for ((k, v) in rows) Row {
                    Text(k, Modifier.width(72.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(v!!, style = MaterialTheme.typography.bodyMedium)
                }
            }
        },
    )
}

/** The queue; tap to play, the row menu moves or removes a song. */
@Composable
internal fun QueueList(state: PlaybackUiState, backend: PlayerControls, modifier: Modifier = Modifier) {
    val keys = remember(state.queue) {
        val seen = HashMap<String, Int>()
        state.queue.map { s -> val n = seen.merge(s.id, 1, Int::plus)!!; "${s.id}#$n" }
    }
    LazyColumn(modifier) {
        itemsIndexed(state.queue, key = { i, _ -> keys[i] }) { i, s ->
            val on = i == state.queueIndex
            Row(
                motionItem().fillMaxWidth().background(if (on) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f) else Color.Transparent)
                    .clickable { backend.playQueueIndex(i) }.padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CoverImage(s.coverUri, s.id, size = 48.dp, radius = 8.dp)
                Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
                    Text(
                        s.title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyLarge,
                        color = if (on) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
                    )
                    Text(s.artist, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(formatDuration(s.durationSec.toLong()), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                var menu by remember { mutableStateOf(false) }
                val modernTokens = io.max.paperplay.ui.theme.LocalModernTokens.current
                Box {
                    IconButton({ menu = true }) { AppIcon(Icons.Rounded.MoreVert, "Queue options") }
                    androidx.compose.material3.DropdownMenu(
                        expanded = menu,
                        onDismissRequest = { menu = false },
                        containerColor = if (modernTokens.enabled) modernTokens.overlayBg else androidx.compose.material3.MenuDefaults.containerColor,
                        tonalElevation = if (modernTokens.enabled) 0.dp else androidx.compose.material3.MenuDefaults.TonalElevation,
                        shadowElevation = if (modernTokens.enabled) 0.dp else androidx.compose.material3.MenuDefaults.ShadowElevation,
                    ) {
                        if (i > 0) androidx.compose.material3.DropdownMenuItem({ Text("Move up") }, { menu = false; backend.moveInQueue(i, i - 1) })
                        if (i < state.queue.lastIndex) androidx.compose.material3.DropdownMenuItem({ Text("Move down") }, { menu = false; backend.moveInQueue(i, i + 1) })
                        if (i > state.queueIndex + 1) androidx.compose.material3.DropdownMenuItem({ Text("Play next") }, { menu = false; backend.moveInQueue(i, state.queueIndex + 1) })
                        if (state.queue.size > 1) androidx.compose.material3.DropdownMenuItem({ Text("Remove from queue") }, { menu = false; backend.removeFromQueue(i) })
                    }
                }
            }
        }
    }
}

/** The cover's dark scheme applied over the normal theme, for surfaces tinted by the current song. */
@Composable
fun CoverTinted(uri: String?, content: @Composable (ColorScheme?) -> Unit) {
    val cover = coverScheme(uri)
    if (cover == null) content(null) else MaterialTheme(colorScheme = cover) { content(cover) }
}

/** The desktop side panel: the current song large, with what comes next. Shown on wide windows while the pref is on. */
@Composable
fun NowPlayingPanel(state: PlaybackUiState, backend: PlayerControls, actions: ListActions, onOpen: () -> Unit, onHide: () -> Unit, modifier: Modifier = Modifier) {
    val song = state.current ?: return
    val muted = MaterialTheme.colorScheme.onSurfaceVariant

    val next = remember(state.queue, state.queueIndex) { if (state.queueIndex < 0) emptyList() else state.queue.drop(state.queueIndex + 1).take(10) }
    val nextKeys = remember(next) { next.map { it.id }.uniqueKeys() }
    LazyColumn(modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
        item {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    if (song.album.isEmpty() || song.album.startsWith(song.title)) "Now playing" else song.album,
                    Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall,
                )
                IconButton(onHide) { AppIcon(Icons.Rounded.Close, "Hide this panel", Modifier.size(20.dp)) }
            }
            BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                CoverImage(song.coverUri, song.id, Modifier.clickable(onClick = onOpen), size = maxWidth, radius = 12.dp)
            }
            Row(Modifier.padding(top = 14.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(song.title, style = MaterialTheme.typography.titleLarge)
                    ArtistLinks(song.artist, MaterialTheme.typography.bodyMedium, muted, Modifier.padding(top = 2.dp))
                    if (song.album.isNotBlank()) AlbumLink(song.album, MaterialTheme.typography.bodySmall, muted.copy(alpha = 0.8f))
                }
                PreviewCopyButton(song)
                IconButton({ actions.setFavorite(song, !song.favorite) }) {
                    AppIcon(if (song.favorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder, if (song.favorite) "Remove from favorites" else "Add to favorites")
                }
                SongMenu(song, actions.rowActions(), Icons.Rounded.MoreHoriz)
            }
            io.max.paperplay.ui.components.AudioBadge(song, Modifier.padding(top = 8.dp))
            val facts = listOfNotNull(song.qualityLabel?.takeIf { it.contains(' ') }?.substringAfter(' '), song.year?.toString(), song.genre).filter { it.isNotBlank() }
            if (facts.isNotEmpty()) androidx.compose.foundation.layout.FlowRow(
                Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp),
            ) { facts.forEach { io.max.paperplay.ui.components.FormatChip(it) } }
            if (next.isNotEmpty()) Text("Next up", Modifier.padding(top = 20.dp, bottom = 6.dp), style = MaterialTheme.typography.titleSmall)
        }
        itemsIndexed(next, key = { i, _ -> nextKeys[i] }) { i, s ->
            Row(
                Modifier.animateItem().fillMaxWidth().clip(RoundedCornerShape(8.dp)).clickable { backend.playQueueIndex(state.queueIndex + 1 + i) }.padding(vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                CoverImage(s.coverUri, s.id, size = 40.dp, radius = 6.dp)
                Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                    Text(s.title, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodyMedium)
                    Text(s.artist, maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall, color = muted)
                }
                Text(formatDuration(s.durationSec.toLong()), style = MaterialTheme.typography.labelSmall, color = muted)
            }
        }
    }
}

private val previewPlayerSong = SongUi(
    id = "1", title = "Knights of Cydonia", artist = "Muse", album = "Black Holes and Revelations",
    durationSec = 366, sizeBytes = 14_000_000, qualityLabel = "FLAC 24/96", favorite = true,
)

@Preview
@Composable
private fun CoverTintedPreview() {
    CoverTinted(uri = null) {
        Text("Tinted Content", modifier = Modifier.padding(16.dp))
    }
}

@Preview
@Composable
private fun PlayPauseButtonPreview() {
    PlayPauseButton(playing = true, onToggle = {})
}

@Preview
@Composable
private fun SongInfoDialogPreview() {
    SongInfoDialog(song = previewPlayerSong, onDismiss = {})
}

private val speeds = listOf(0.5f, 0.75f, 1f, 1.25f, 1.5f, 1.75f, 2f)

internal fun speedLabel(s: Float) = (if (s % 1f == 0f) s.toInt().toString() else s.toString().trimEnd('0')) + "x"

/** Playback speed. */
@Composable
internal fun SpeedDialog(backend: PlayerControls, onClose: () -> Unit) {
    val speed by backend.speed.collectAsState()
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text("Playback speed") },
        text = {
            Column {
                speeds.forEach { s ->
                    TextButton({ backend.setSpeed(s); onClose() }) {
                        Text(speedLabel(s) + if (s == speed) " (selected)" else "")
                    }
                }
            }
        },
        confirmButton = { TextButton({ backend.setSpeed(1f); onClose() }) { Text("Normal") } },
        dismissButton = { TextButton(onClose) { Text("Close") } },
    )
}

/** Desktop equalizer dialog; on Android phones FullPlayer navigates to [FullScreenEqualizerPage] instead. */
@Composable
internal fun EqualizerDialog(backend: PlayerControls, onClose: () -> Unit) {
    val dialogShape = appShape(28.dp, CornerArea.Dialogs)
    AlertDialog(
        onDismissRequest = onClose,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
        modifier = Modifier.widthIn(min = 420.dp, max = 680.dp).padding(horizontal = 24.dp, vertical = 16.dp).then(overlayRim(dialogShape)),
        shape = dialogShape,
        containerColor = overlayColor(),
        title = {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text("Equalizer", Modifier.weight(1f))
                EqualizerTopBarActions(backend)
            }
        },
        text = {
            androidx.compose.runtime.CompositionLocalProvider(LocalSettingsInfo provides true) {
                EqualizerScreenBody(
                    backend = backend,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 420.dp, max = 560.dp),
                )
            }
        },
        confirmButton = { TextButton(onClose) { Text("Close") } },
    )
}

/** Pauses playback after a chosen time. */
@Composable
internal fun SleepTimerDialog(backend: PlayerControls, onClose: () -> Unit) {
    val sleepAt by backend.sleepAt.collectAsState()
    AlertDialog(
        onDismissRequest = onClose,
        title = { Text("Sleep timer") },
        text = {
            Column {
                sleepAt?.let { end -> Text("Pauses in about ${maxOf(1L, (end - nowMoment().epochMs + 59_999) / 60_000)} min", Modifier.padding(bottom = 8.dp)) }
                listOf(15, 30, 45, 60, 90).forEach { m ->
                    TextButton({ backend.setSleepTimer(m); onClose() }) { Text("$m minutes") }
                }
            }
        },
        confirmButton = { TextButton({ backend.setSleepTimer(null); onClose() }) { Text("Turn off") } },
        dismissButton = { TextButton(onClose) { Text("Close") } },
    )
}

@Preview(name = "Artwork", showBackground = true)
@Composable
private fun ArtworkPreview() = io.max.paperplay.ui.PreviewFrame {
    Artwork(io.max.paperplay.ui.previewSongs[0], playing = true, size = 240.dp)
}

@Preview(name = "Full player phone", widthDp = 390, heightDp = 844)
@Composable
private fun FullPlayerPhonePreview() = io.max.paperplay.ui.PreviewFrame(dark = true) {
    FullPlayer(io.max.paperplay.ui.previewPlayback(), null, io.max.paperplay.ui.FakePlayerControls(), io.max.paperplay.ui.previewActions(), onClose = {})
}

@Preview(name = "Full player error", widthDp = 390, heightDp = 844)
@Composable
private fun FullPlayerErrorPreview() = io.max.paperplay.ui.PreviewFrame(dark = true) {
    FullPlayer(io.max.paperplay.ui.previewPlayback(false), "Could not load the song", io.max.paperplay.ui.FakePlayerControls(), io.max.paperplay.ui.previewActions(), onClose = {})
}

@Preview(name = "Full player desktop", widthDp = 1100, heightDp = 700)
@Composable
private fun FullPlayerDesktopPreview() = io.max.paperplay.ui.PreviewFrame(dark = true) {
    FullPlayer(io.max.paperplay.ui.previewPlayback(), null, io.max.paperplay.ui.FakePlayerControls(), io.max.paperplay.ui.previewActions(), onClose = {})
}

@Preview(name = "Progress", widthDp = 390, showBackground = true)
@Composable
private fun ProgressPreview() = io.max.paperplay.ui.PreviewFrame {
    Column(Modifier.padding(16.dp)) { PlayerProgress(io.max.paperplay.ui.previewSongs[0], io.max.paperplay.ui.previewPlayback(), io.max.paperplay.ui.FakePlayerControls(), onBadge = {}) }
}

@Preview(name = "Queue", widthDp = 390, heightDp = 500, showBackground = true)
@Composable
private fun QueueListPreview() = io.max.paperplay.ui.PreviewFrame {
    QueueList(io.max.paperplay.ui.previewPlayback(), io.max.paperplay.ui.FakePlayerControls())
}

@Preview(name = "Now playing panel", widthDp = 320, heightDp = 640, showBackground = true)
@Composable
private fun NowPlayingPanelPreview() = io.max.paperplay.ui.PreviewFrame {
    NowPlayingPanel(io.max.paperplay.ui.previewPlayback(), io.max.paperplay.ui.FakePlayerControls(), io.max.paperplay.ui.previewActions(), onOpen = {}, onHide = {})
}

@Preview(name = "Sleep timer dialog")
@Composable
private fun SleepTimerDialogPreview() = io.max.paperplay.ui.PreviewFrame {
    SleepTimerDialog(io.max.paperplay.ui.FakePlayerControls(sleepAt = 1L), onClose = {})
}

/** Where the song plays and the ways to link other devices; the two links open those settings pages. */
/** What the song is, what the output does to it and whether it arrives untouched. Answers "is this playing at full quality?". */
@Composable
internal fun OutputInfoDialog(song: SongUi, backend: PlayerControls, onDismiss: () -> Unit) {
    val info by backend.outputInfo.collectAsState()
    val scheme = MaterialTheme.colorScheme
    // The file's own depth and rate come from its label ("ALAC 24/96") when the engine does not know them.
    val fromLabel = Regex("""(\d+)/([\d.]+)""").find(song.qualityLabel.orEmpty())
    fun khz(hz: Int) = (hz / 1000.0).toString().removeSuffix(".0") + " kHz"
    val rows = listOfNotNull(
        "File" to (song.qualityLabel ?: if (song.lossless) "Lossless" else "Lossy"),
        info?.codec?.let { "Decoded as" to it },
        (info?.bitDepth?.toString() ?: fromLabel?.groupValues?.get(1))?.let { "Bit depth" to "$it bit" },
        (info?.sampleRateHz?.let(::khz) ?: fromLabel?.groupValues?.get(2)?.toDoubleOrNull()?.let { khz((it * 1000).toInt()) })?.let { "Sample rate" to it },
        info?.channels?.let { "Channels" to if (it == 2) "Stereo" else if (it == 1) "Mono" else "$it" },
        info?.bitrateKbps?.let { "Bitrate" to "$it kbps" },
        info?.device?.let { "Output" to it },
        info?.outputRateHz?.let { "Mixer rate" to khz(it) },
        "Effects" to (info?.effects?.takeIf { it.isNotEmpty() }?.joinToString(", ") ?: "None"),
    ) + (info?.details ?: emptyList())
    val songRows = listOfNotNull(
        "Artist" to song.artist, song.album.ifBlank { null }?.let { "Album" to it }, song.genre?.let { "Genre" to it },
        song.year?.let { "Year" to it.toString() }, "Length" to formatDuration(song.durationSec.toLong()),
        "Size" to "${song.sizeBytes / 100_000 / 10.0} MB", "Plays" to song.plays.toString(),
    )
    val perfect = info?.bitPerfect == true
    val modernTokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        androidx.compose.material3.Surface(
            Modifier.widthIn(max = 460.dp).fillMaxWidth(),
            shape = RoundedCornerShape(28.dp),
            color = if (modernTokens.enabled) modernTokens.overlayBg else overlayColor(),
            tonalElevation = if (modernTokens.enabled) 0.dp else 6.dp,
            shadowElevation = 0.dp,
        ) {
            Column(Modifier.verticalScroll(androidx.compose.foundation.rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text(song.title, maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleLarge)
                DetailSection("Song", songRows)
                DetailSection("Sound", rows)
                info?.transport?.let { t ->
                    val tRows = buildList {
                        if (t.verified || t.kind != io.max.paperplay.player.TransportKind.NONE || t.protocolVersion != null) {
                            add("Route" to (t.kind.displayName + if (t.verified) " (verified)" else ""))
                        }
                        t.protocolVersion?.let { add("Protocol" to it) }
                        t.confirmedRateHz?.let { r ->
                            t.confirmedBitDepth?.let { d -> add("Confirmed" to "$d-bit / ${khz(r)}") }
                        }
                        t.confirmedAlt?.let { add("Alt setting" to "#$it") }
                        t.syncMode?.let { add("Sync mode" to it) }
                        t.hardwareVolume?.let { add("Hardware volume" to it) }
                        if (t.framesConsumed > 0L) add("Frames sent" to "${t.framesConsumed}")
                        if (t.underruns > 0L) add("Underruns" to "${t.underruns}")
                        if (t.errors > 0L) add("Transfer errors" to "${t.errors}")
                    }
                    DetailSection("Transport", tRows)
                }
                if (info == null) Text("Play the song to see how it is decoded and sent to the output.", color = scheme.onSurfaceVariant, style = MaterialTheme.typography.bodySmall)
                else Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(if (perfect) scheme.primaryContainer else scheme.surfaceContainerHighest).padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(if (perfect) "Bit-perfect" else "Not bit-perfect", style = MaterialTheme.typography.titleSmall, color = if (perfect) scheme.onPrimaryContainer else scheme.onSurface)
                    Text(
                        if (perfect) "The samples reach the output unchanged." else info?.note.orEmpty(),
                        style = MaterialTheme.typography.bodySmall, color = if (perfect) scheme.onPrimaryContainer else scheme.onSurfaceVariant,
                    )
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) { TextButton(onDismiss) { Text("Close") } }
            }
        }
    }
}

/** A titled block of label and value rows for the details popup. */
@Composable
private fun DetailSection(title: String, rows: List<Pair<String, String>>) {
    if (rows.isEmpty()) return
    val scheme = MaterialTheme.colorScheme
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.labelLarge, color = scheme.primary)
        for ((k, v) in rows) Row {
            Text(k, Modifier.width(112.dp), color = scheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium)
            Text(v, Modifier.weight(1f), style = MaterialTheme.typography.bodyMedium)
        }
    }
}

/** One switch for untouched verified output, drawn like the Equalizer switch under it. Equalizer, bass, levelling and profile keep their settings and come back when it is off. */
@Composable
internal fun BitPerfectRow(backend: PlayerControls) {
    if (!backend.hasBass) return
    val on by backend.bitPerfect.collectAsState()
    val bluetooth = !io.max.paperplay.ui.isPhone && backend.outputInfo.collectAsState().value?.bluetooth == true
    val subtitle = if (bluetooth) {
        "Not available on Bluetooth: the sound is always re-encoded on the way. Kept per output, so it comes back on other outputs."
    } else if (io.max.paperplay.ui.isPhone) {
        "Plays eligible audio untouched on verified USB DACs or bit-perfect mixers. Equalizer, bass, normalise and profile are bypassed."
    } else {
        "Plays the file untouched through exclusive output. The equalizer and bass are bypassed, and other apps go quiet."
    }
    SwitchRow("Bit-perfect", on && !bluetooth, { backend.setBitPerfect(it) }, io.max.paperplay.ui.components.TrueAudioIcon, subtitle, enabled = !bluetooth)
}
