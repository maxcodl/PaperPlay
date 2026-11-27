package io.max.paperplay.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import io.max.paperplay.ui.theme.schemeFromSeed
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.gestures.draggable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ViewSidebar
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.animation.AnimatedContent
import io.max.paperplay.ui.theme.animatedWidth
import io.max.paperplay.ui.theme.panelEnter
import io.max.paperplay.ui.theme.panelExit
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.hideFromAccessibility
import androidx.compose.ui.semantics.semantics
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.input.key.isAltPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.type
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.backdrops.rememberLayerBackdrop
import io.max.paperplay.ui.PlatformBackHandler
import io.max.paperplay.ui.components.LocalCoverLoader
import io.max.paperplay.ui.components.LocalOnMissingCover
import io.max.paperplay.ui.isPhone
import io.max.paperplay.ui.mouseBackButton
import io.max.paperplay.ui.state.Load
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch

internal val LocalOutputDevice = androidx.compose.runtime.staticCompositionLocalOf<io.max.paperplay.ui.OutputDevice?> { null }

private data class NavSnapshot(
    val tab: Int, val libraryTab: Int?, val profilePage: String?, val detail: Detail?,
    val settings: Boolean, val settingsStack: List<String>, val settingsDeep: Boolean, val page: String,
)

@Composable
fun MainShell(backend: CoreBackend, prefs: UiPrefs, onRestore: () -> Unit, open: MutableStateFlow<String?>? = null) {
    val lib by backend.library.collectAsState()
    val favorites by backend.favorites.collectAsState()
    val recents by backend.recents.collectAsState()
    val home by backend.home.collectAsState()
    val homeWarm by backend.homeWarm.collectAsState()
    val pb by backend.playbackMeta.collectAsState()
    // Position and scan text change every tick: keep them as State and read them only in draw lambdas and small leaf composables.
    val pos = backend.position.collectAsState()
    val scan = backend.scan.collectAsState()
    val runningTasks = backend.tasks.running.collectAsState().value.size
    val scanning by backend.scanning.collectAsState()
    val pbError by backend.playbackError.collectAsState()
    val conn by backend.connection.collectAsState()

    // Phone: four tabs. Desktop: a sidebar page id.
    var tab by remember { mutableIntStateOf(0) }
    var libraryTab by remember { mutableStateOf<Int?>(null) }
    var profilePage by remember { mutableStateOf<String?>(null) }
    var page by remember { mutableStateOf("home") }
    var detail by remember { mutableStateOf<Detail?>(null) }
    var settings by remember { mutableStateOf(false) }
    var showNow by remember { mutableStateOf(false) }
    val settingsStack = remember { mutableStateListOf<String>() }
    // True when a page was opened straight from Profile or a library link: Back then returns there, not to the Settings list.
    var settingsDeep by remember { mutableStateOf(false) }
    var desktopNavMove by remember { mutableStateOf(NavMove.Switch) }
    val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
    var savedPlayerOpen by rememberSaveable { mutableStateOf(false) }
    val playerController = rememberPlayerTransitionController(
        initiallyOpen = savedPlayerOpen && pb.current != null,
        reduceMotion = reduceMotion,
    )
    LaunchedEffect(playerController.isTargetOpen) {
        savedPlayerOpen = playerController.isTargetOpen
    }
    val coverBounds = remember { CoverBoundsRegistry() }
    val miniFocusRequester = remember { FocusRequester() }
    val pageBackProgress = remember { androidx.compose.animation.core.Animatable(0f) }
    val pageBackCancelSpec = io.max.paperplay.ui.theme.motionSpatialSpring<Float>(io.max.paperplay.ui.theme.Motion.Spatial.SettleStiffness)
    // Left for a while (phone in the background): free the decoded covers and compact the heap. Opening the app decodes what is on screen again.
    val inForeground = io.max.paperplay.ui.rememberAppForeground()
    androidx.compose.runtime.LaunchedEffect(inForeground) {
        if (!inForeground && (isPhone || !io.max.paperplay.ui.AppForegroundState.isVisible)) {
            kotlinx.coroutines.delay(10_000)
            SharedCovers.loader.clear()
            System.gc()
        }
    }
    // Where the phone came from, so Back returns there instead of jumping to Home or Settings.
    val history = remember { mutableStateListOf<NavSnapshot>() }
    fun snapshot() = NavSnapshot(tab, libraryTab, profilePage, detail, settings, settingsStack.toList(), settingsDeep, page)
    // Every screen change goes in the log, so a shared log shows what was open when something went wrong.
    val where = "tab=$tab page=$page library=$libraryTab profile=$profilePage detail=${detail?.let { it::class.simpleName }} settings=${if (settings) settingsStack.joinToString("/").ifEmpty { "list" } else "-"} player=${playerController.phase.name}"
    LaunchedEffect(where) { io.max.paperplay.player.PlayLog.log("nav", where) }
    fun navigate(change: () -> Unit) {
        val before = snapshot()
        val beforeLevel = DeskKey(showNow, before.settings, before.detail, before.page).level
        change()
        val after = snapshot()
        if (after != before) {
            val afterLevel = DeskKey(showNow, after.settings, after.detail, after.page).level
            desktopNavMove = navMove(beforeLevel, afterLevel)
            history.add(before)
            if (history.size > 40) history.removeAt(0)
        }
    }
    fun openLive(kind: io.max.paperplay.core.app.TaskKind) {
        MissingStart.filter = if (kind == io.max.paperplay.core.app.TaskKind.Covers) Missing.NoCover else Missing.Waiting
        navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("missing") }
    }

    fun goBack() {
        desktopNavMove = NavMove.Back
        val to = history.removeLastOrNull()
        if (to != null) {
            tab = to.tab; libraryTab = to.libraryTab; profilePage = to.profilePage; detail = to.detail
            settings = to.settings; settingsDeep = to.settingsDeep; page = to.page
            settingsStack.clear(); settingsStack.addAll(to.settingsStack)
        } else when {
            settings -> { settings = false; settingsStack.clear() }
            detail != null -> detail = null
            profilePage != null -> profilePage = null
            else -> { tab = 0; page = "home" }
        }
    }
    var showEqFullScreen by remember { mutableStateOf(false) }
    var showLyricsFullScreen by remember { mutableStateOf(false) }
    var runMotionHarness by remember { mutableStateOf(false) }
    LaunchedEffect(pb.current == null) {
        if (pb.current == null) {
            showLyricsFullScreen = false
            showEqFullScreen = false
            showNow = false
            playerController.snapClosed()
        }
    }
    fun handleBack() {
        desktopNavMove = NavMove.Back
        when {
            showEqFullScreen -> showEqFullScreen = false
            showLyricsFullScreen -> showLyricsFullScreen = false
            playerController.isComposed -> playerController.commitBack()
            !isPhone && showNow -> showNow = false
            settings && settingsStack.size > (if (settingsDeep || !isPhone) 1 else 0) -> settingsStack.removeAt(settingsStack.lastIndex)
            else -> goBack()
        }
    }
    var pickFor by remember { mutableStateOf<Set<String>?>(null) }
    var newPlaylist by remember { mutableStateOf(false) }
    // Songs waiting for a playlist that is about to be created.
    var pendingAdd by remember { mutableStateOf<Set<String>?>(null) }
    val snack = remember { SnackbarHostState() }
    // The mini player can be swiped away while nothing plays; starting playback shows it again.
    val miniHideState = remember { MiniPlayerHideState() }
    LaunchedEffect(pb.playing) { miniHideState.onPlayingChanged(pb.playing) }
    val scope = rememberCoroutineScope()
    val loader = SharedCovers.loader
    // Glass needs blur layers; with every part on Material (and Default style) they are skipped.
    // Modern chrome reads pageBackdrop via LocalGlassBackdrop, so it must not wrap the page in a second offscreen layerBackdrop or duplicate AppBackground.
    val modernUi = io.max.paperplay.ui.theme.LocalModernTokens.current.enabled
    val navGlass = !modernUi && prefs.look(LookGroup.Nav) == Look.Glass
    val anyGlass = modernUi || LookGroup.entries.any { prefs.look(it) == Look.Glass }
    val backdrop = rememberLayerBackdrop()
    val pageBackdrop = rememberLayerBackdrop()

    val tagDialogs = remember { TagDialogState() }
    // The sound output goes to linked devices with the playing state, so each one can say where the music is heard.
    val out = io.max.paperplay.ui.rememberOutputDevice()
    androidx.compose.runtime.SideEffect {
        backend.services.outputInfo = { out.name to (if (out.external) "headphones" else if (isPhone) "phone" else "speakers") }
    }
    // Prewarm the full-player cover bitmap, backdrop thumbnail, and palette on track change rather than on the first frame of opening the sheet.
    LaunchedEffect(pb.current?.coverUri, prefs.modernPlayerBlur) {
        pb.current?.coverUri?.let { uri ->
            loader.preload(listOf(uri), 1280)
            loader.preload(listOf(uri), modernBackdropDecodePx(prefs.modernPlayerBlur))
            CoverSeeds.palette(uri)
            CoverSeeds.prewarmScheme(uri, dark = true)
        }
    }
    val actions = remember(backend) {
        ListActions(
            play = backend::play,
            shuffle = backend::shuffleAll,
            setFavorite = { s, f -> backend.setFavorite(s.id, f) },
            addToPlaylist = { pickFor = it },
            notice = { scope.launch { snack.showSnackbar(it) } },
            playNext = { s -> backend.playNext(s); scope.launch { snack.showSnackbar("Plays next") } },
            setPinned = { s, p -> backend.setPinned(s.id, p) },
            deleteSong = { s ->
                // A repeat row stands for one extra post of a file; deleting it by the file's id would delete the main post.
                if (s.copyKey != null) scope.launch { snack.showSnackbar("Delete repeated posts from the Duplicates page") }
                else backend.deleteSong(s.id) { m -> scope.launch { snack.showSnackbar(m) } }
            },
            deleteSongs = { list ->
                val real = list.filter { it.copyKey == null }
                if (real.size < list.size) scope.launch { snack.showSnackbar("Repeated posts are skipped; delete them from the Duplicates page") }
                if (real.isNotEmpty()) backend.deleteSongs(real.map { it.id }) { m -> scope.launch { snack.showSnackbar(m) } }
            },
            copyToChat = { list -> backend.copySongsToChat(list.map { it.id }) { m -> scope.launch { snack.showSnackbar(m) } } },
            telegramLink = backend::telegramLink,
            findMetadata = { s -> tagDialogs.match = s },
            editTags = { s -> tagDialogs.tags = s },
            changeCover = { s -> tagDialogs.cover = s },
        )
    }

    // A notification tap: the player, or Profile (where tasks are listed) for the background notification.
    val openRequest = open?.collectAsState()?.value
    // A short notice while this device dials a paired device, and when one links. The sync object appears once the
    // Connection page or the saved "on" setting creates it, so wait for it.
    LaunchedEffect(Unit) {
        var lan = backend.lanSync
        while (lan == null) { kotlinx.coroutines.delay(2_000); lan = backend.lanSync }
        val sync = lan
        launch {
            // The sync loop dials an offline paired device every 20 seconds; each device is announced once per run.
            val announced = announcedConnecting // once per process, so a rebuilt screen does not repeat it
            sync.connecting.collect { now ->
                now.firstOrNull { announced.add(it) }?.let { name -> launch { waitForQuietStart(); snack.currentSnackbarData?.dismiss(); snack.showSnackbar("Connecting to $name", duration = androidx.compose.material3.SnackbarDuration.Short) } }
            }
        }
        var known = sync.connected.value.map { it.id }.toSet()
        sync.connected.collect { devices ->
            val now = devices.map { it.id }.toSet()
            devices.firstOrNull { it.id !in known }?.let { d -> launch { waitForQuietStart(); snack.currentSnackbarData?.dismiss(); snack.showSnackbar("Connected to ${d.name}", duration = androidx.compose.material3.SnackbarDuration.Short) } }
            known = now
        }
    }
    // On every launch, when allowed, look for a newer release; a dialog offers to open About if there is one.
    var updatePrompt by remember { mutableStateOf<io.max.paperplay.core.update.ReleaseInfo?>(null) }
    LaunchedEffect(Unit) {
        val updates = backend.services.updates
        if (!updates.prefs.auto) return@LaunchedEffect
        if (updates.autoCheckDue()) updates.check()
        updatePrompt = (updates.state.value as? io.max.paperplay.core.update.UpdateState.Available)?.release
    }
    updatePrompt?.let { r ->
        AlertDialog(
            onDismissRequest = { updatePrompt = null },
            title = { Text("Update available") },
            text = { Text("PaperPlay ${r.version} is ready to download.") },
            confirmButton = {
                androidx.compose.material3.TextButton({
                    updatePrompt = null
                    navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("about") }
                }) { Text("View") }
            },
            dismissButton = {
                Row {
                    androidx.compose.material3.TextButton({ backend.services.updates.skip(r); updatePrompt = null }) { Text("Skip this version") }
                    androidx.compose.material3.TextButton({ updatePrompt = null }) { Text("Later") }
                }
            },
        )
    }
    LaunchedEffect(openRequest) {
        when (openRequest) {
            "player" -> if (pb.current != null) playerController.open()
            "upload" -> { page = "upload"; detail = null; settings = false; playerController.close() }
            "tasks" -> { navigate { tab = 3; profilePage = "tasks"; detail = null; settings = false }; page = "tasks"; playerController.close() }
            "motion_test" -> if (backend.devOptionsUnlocked.value && pb.current != null) runMotionHarness = true
            "motion_lab" -> if (backend.devOptionsUnlocked.value) {
                playerController.close()
                navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("motion_lab") }
            }
            "preview_live" -> if (backend.devOptionsUnlocked.value) uiPreviewOverride.value = UiPreviewOverride.Live
            "preview_loading" -> if (backend.devOptionsUnlocked.value) uiPreviewOverride.value = UiPreviewOverride.Loading
            "preview_empty" -> if (backend.devOptionsUnlocked.value) uiPreviewOverride.value = UiPreviewOverride.Empty
            "preview_error" -> if (backend.devOptionsUnlocked.value) uiPreviewOverride.value = UiPreviewOverride.Error
            "preview_no_avatar" -> if (backend.devOptionsUnlocked.value) uiPreviewOverride.value = UiPreviewOverride.NoAvatar
        }
        if (openRequest != null) open?.value = null
    }
    // One handler: several enabled handlers would let the last one win.
    PlatformBackHandler(
        enabled = showEqFullScreen || showLyricsFullScreen || playerController.isComposed || settings || detail != null || profilePage != null || tab != 0 || history.isNotEmpty(),
        onProgress = { p ->
            when {
                playerController.isComposed && !showEqFullScreen && !showLyricsFullScreen ->
                    playerController.backProgress(p)
                !playerController.isComposed && !showEqFullScreen && !showLyricsFullScreen ->
                    scope.launch { pageBackProgress.snapTo(p.coerceIn(0f, 1f)) }
            }
        },
        onCancel = {
            if (playerController.phase == PlayerSheetPhase.BackGesture) {
                playerController.cancelBack()
            } else if (pageBackProgress.value > 0f) {
                scope.launch { pageBackProgress.animateTo(0f, pageBackCancelSpec) }
            }
        },
        onBack = {
            if (pageBackProgress.value > 0f) {
                scope.launch { pageBackProgress.snapTo(0f) }
            }
            handleBack()
        },
    )

    val songs = (lib.songs as? Load.Ready)?.value.orEmpty()
    val currentId = pb.current?.id
    val mainChatTitle = remember(conn.chats, settings) { conn.chats.firstOrNull { it.id == backend.mainChatId() }?.title }

    // Cover gradient: the current song's colours wash down from the top of every page.
    val base = MaterialTheme.colorScheme.background
    val dark = base.luminance() < 0.5f
    val tint = (if (prefs.coverGradient) coverScheme(pb.current?.coverUri, dark) else null)?.primaryContainer ?: MaterialTheme.colorScheme.primaryContainer
    val g0 = androidx.compose.animation.animateColorAsState(backgroundTopColor(prefs, tint, base), io.max.paperplay.ui.theme.motionWashSpec())
    // The page itself is drawn by AppBackground; g0 only tints the window and top areas.
    // Colour of the page where a pinned list bar sits, a fifth of the way down: the cover wash eases from g0 to g1 over the top 45%.
    val tintState = androidx.compose.runtime.rememberUpdatedState(tint)
    val baseState = androidx.compose.runtime.rememberUpdatedState(base)
    val bgState = androidx.compose.runtime.rememberUpdatedState(prefs.background)
    val pinnedBar = androidx.compose.runtime.remember(g0) {
        androidx.compose.runtime.derivedStateOf {
            val b = baseState.value
            if (bgState.value == BgMode.Cover) {
                val g1 = tintState.value.copy(alpha = 0.32f).compositeOver(b)
                androidx.compose.ui.graphics.lerp(g0.value, g1, 0.45f)
            } else b
        }
    }

    val lanSync = rememberLanSync(backend)
    // The topic and channel lists are built off the main thread; only the screens that show them read this state.
    val telegramState = backend.telegram.collectAsState()
    // Placeholder covers only while the app starts up. After that a cover fetched while scrolling must not turn the others into placeholders.
    // The queue size changes many times a second at startup, so it is read in an effect, not in composition (which redrew the whole shell each time).
    var coversStarting by remember { mutableStateOf(true) }
    LaunchedEffect(Unit) {
        var saw = false
        backend.services.covers.queued.collect { q -> if (q > 0) saw = true else if (saw) coversStarting = false }
    }
    LaunchedEffect(Unit) { kotlinx.coroutines.delay(10_000); coversStarting = false }
    val ambientClock = io.max.paperplay.ui.theme.rememberAmbientClock(active = !playerController.isCovered)
    CompositionLocalProvider(io.max.paperplay.ui.theme.LocalAmbientClock provides ambientClock, LocalLanSync provides lanSync, io.max.paperplay.ui.components.LocalCoversPending provides coversStarting, LocalCoverLoader provides loader, LocalOnMissingCover provides backend::ensureCover, LocalListActions provides actions, LocalAlbums provides backend.albums, LocalArtists provides backend.artists, LocalTelegramLists provides remember(telegramState) { { telegramState.value } }, LocalIndexedChats provides remember(backend) {
        fun openChat(id: Long, title: String, query: String) {
            indexPageTitles["index:$id"] = title
            indexPageQuery["index:$id"] = query
            navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("index:$id") }
        }
        IndexedChats(
            backend.chatIndex.chats, { c -> openChat(c.id, c.title, "") },
            search = { q, n -> backend.chatIndex.searchAll(q, n) },
            thumb = { c, m -> backend.postThumb(c, m) },
            play = { backend.previewPost(it) },
            isPreview = { backend.isPreview(it) },
            copyPreview = { backend.copyPreview(it) },
            openSearch = { id, q -> openChat(id, backend.chatIndex.chats.value.firstOrNull { it.id == id }?.title ?: "Indexed chat", q) },
        )
    }, LocalOpenDetail provides { d: Detail -> playerController.close(); navigate { detail = d; settings = false } }, LocalOutputDevice provides out, LocalOutputSwitch provides remember(backend) { OutputSwitch(backend.activeOutput, { id -> backend.switchOutput(id) { m -> scope.launch { snack.showSnackbar(m) } } }, { id -> backend.switchOutput(id, move = true) { m -> scope.launch { snack.showSnackbar(m) } } }) }, LocalPageTop provides pinnedBar, io.max.paperplay.ui.LocalGlassBackdrop provides (if (anyGlass) pageBackdrop else null)) {
        TagDialogHost(backend, tagDialogs) { m -> scope.launch { snack.showSnackbar(m) } }
        var phoneHeightPx by remember { androidx.compose.runtime.mutableFloatStateOf(0f) }
        Box(Modifier.fillMaxSize().onSizeChanged { phoneHeightPx = it.height.toFloat() }) {
            // The page background alone is the layer glass cards and bars blur (content on it would recurse).
            Box(Modifier.fillMaxSize().drawWithContent { if (!playerController.isCovered) drawContent() }.then(if (anyGlass) Modifier.layerBackdrop(pageBackdrop) else Modifier)) {
                AppBackground(prefs, pb.current?.coverUri, base, playing = pb.playing && !playerController.isCovered)
            }
            if (isPhone) {
                val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
                val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
                val navHeight = if (prefs.navLayout == NavLayout.Labels || prefs.navLayout == NavLayout.Dock) 76.dp else 64.dp
                val barsHeight = (if (pb.current != null) 70.dp + 8.dp else 0.dp) + navHeight + (if (prefs.floatingNav) 24.dp else 0.dp) + bottomInset + 40.dp // extra scroll room so the last item clears the bar
                val forceDarkBars = playerController.isPlayerSystemBars &&
                    !showEqFullScreen &&
                    !showLyricsFullScreen &&
                    (resolveEffectivePlayerStyle(prefs) != PlayerStyle.Modern || dark)
                io.max.paperplay.ui.SystemBarAppearanceEffect(darkIcons = !dark && !forceDarkBars)
                // The layer the nav bar blurs: the page colour (a still copy, so it costs no animation) with the page on top. Without the colour there
                // would be almost nothing under the bar to blur or refract.
                Box(
                    Modifier
                        .fillMaxSize()
                        .drawWithContent { if (!playerController.isCovered) drawContent() }
                        .then(if (navGlass) Modifier.layerBackdrop(backdrop) else Modifier)
                        .graphicsLayer {
                            val s = backdropScale(playerController.progress, playerController.reduceMotion)
                            scaleX = s
                            scaleY = s
                            compositingStrategy = if (playerController.isTransitioning) {
                                CompositingStrategy.Offscreen
                            } else {
                                CompositingStrategy.Auto
                            }
                        }
                        .semantics { if (playerController.isCovered) hideFromAccessibility() },
                ) {
                // The second copy of the background (for the glass bar to blur) joins after the page has animated in: drawing two blurred
                // backgrounds in the first frames was a large part of their cost.
                var navBackground by remember { mutableStateOf(false) }
                LaunchedEffect(homeWarm) { if (homeWarm) { kotlinx.coroutines.delay(2_500); navBackground = true } }
                if (navGlass && navBackground) AppBackground(prefs, pb.current?.coverUri, base, playing = false)
                Box(Modifier.fillMaxSize().padding(top = top)) {
                    // Each page is drawn from its own key, so the page that is leaving keeps showing what it showed.
                    val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
                    // A tab remembers where its list was scrolled to while you are on another page.
                    val tabStates = androidx.compose.runtime.saveable.rememberSaveableStateHolder()
                    AnimatedContent(
                        targetState = PageKey(settings, detail, tab, tab == 3 && profilePage == "tasks"),
                        modifier = Modifier.fillMaxSize().graphicsLayer {
                            val bp = pageBackProgress.value
                            if (bp > 0f) {
                                val tf = pageBackTransform(bp, size.width, reduceMotion)
                                translationX = tf.translationX
                                scaleX = tf.scale
                                scaleY = tf.scale
                                alpha = tf.alpha
                            }
                        },
                        transitionSpec = { pageTransition(navMove(initialState.level, targetState.level), reduceMotion) },
                        label = "page",
                    ) { k ->
                    val phonePage: @Composable () -> Unit = {
                    val d = k.detail
                    when {
                        k.settings -> CompositionLocalProvider(LocalSettingsInfo provides true) { SettingsHost(settingsStack, prefs, conn, songs.size, backend, onRestore, ::goBack, barsHeight, deep = settingsDeep) }
                        d != null -> DetailScreen(d, backend, currentId, actions, ::goBack, barsHeight)
                        k.tab == 0 -> HomeScreen(
                            lib, home, favorites, currentId, conn, scan, actions,
                            { d2 -> navigate { detail = d2 } }, barsHeight, name = prefs.profileName, warm = homeWarm,
                            onProfile = { navigate { tab = 3; profilePage = null; detail = null; settings = false } },
                            onLibraryTab = { sel -> navigate { tab = 2; libraryTab = sel; detail = null; settings = false } },
                        )
                        k.tab == 1 -> SearchScreen(backend::search, songs, currentId, actions, { d2 -> navigate { detail = d2 } }, barsHeight)
                        k.tab == 2 -> LibraryScreen(lib, favorites, currentId, actions, { d2 -> navigate { detail = d2 } }, { newPlaylist = true }, barsHeight, selectedTab = libraryTab,
                            recents = recents, onImportSpotify = { navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("spotify") } })
                        k.tasks -> TasksScreen(backend.tasks, Modifier.fillMaxSize().padding(bottom = barsHeight), onBack = ::goBack, onOpen = { kd -> openLive(kd) })
                        else -> ProfileScreen(
                            songs.size, favorites.size, lib.playlists.size, conn, prefs,
                            mainChatTitle,
                            onSettings = { id ->
                                navigate {
                                    settings = true
                                    settingsDeep = id != null
                                    settingsStack.clear()
                                    id?.let(settingsStack::add)
                                }
                            },
                            onTasks = { navigate { profilePage = "tasks" } },
                            onLibraryTab = { selected ->
                                navigate {
                                    profilePage = null
                                    libraryTab = selected
                                    tab = 2
                                }
                            },
                            barsHeight,
                            scan = scan,
                            runningTasks = runningTasks,
                            updates = backend.services.updates,
                            backend = backend, recents = recents, onPlay = actions.play,
                        )
                    }
                    }
                    if (k.settings || k.detail != null || k.tasks) phonePage() else tabStates.SaveableStateProvider("tab${k.tab}") { phonePage() }
                    }
                }
                }
                val dockSideMargin = if (modernUi) io.max.paperplay.ui.theme.LocalModernTokens.current.dock.sideMargin else 16.dp
                val dockGap = if (modernUi) io.max.paperplay.ui.theme.LocalModernTokens.current.dock.dockGap else 8.dp
                Column(
                    Modifier.align(Alignment.BottomCenter).fillMaxWidth().drawWithContent { if (!playerController.isCovered) drawContent() }.blockTouchesBehind().then(if (prefs.floatingNav) Modifier.padding(start = dockSideMargin, end = dockSideMargin, bottom = bottomInset.coerceAtLeast(12.dp)) else Modifier),
                ) {
                    // Toasts sit above the mini player and the bar, where they cover the least; swipe one sideways to dismiss it.
                    AppSnackbarHost(snack, Modifier.fillMaxWidth().padding(bottom = 8.dp), tint)
                    RemoteNowStrip(backend)
                    if (pb.current != null && !miniHideState.gone) {
                        val density = androidx.compose.ui.platform.LocalDensity.current
                        val hideConfig = remember(modernUi, density) {
                            if (modernUi) modernMiniHideConfig(density) else defaultMiniHideConfig(density)
                        }
                        val miniMaxShiftPx = with(density) { io.max.paperplay.ui.theme.PlayerMotionTokens.MINI_PLAYER_MAX_SHIFT_DP.dp.toPx() }
                        val miniSwipeDismissSpec = io.max.paperplay.ui.theme.motionEffectTween<Float>(io.max.paperplay.ui.theme.Motion.Effects.FadeFastMs)
                        val miniSwipeReturnSpec = io.max.paperplay.ui.theme.motionSpatialSpring<Float>()
                        MiniPlayer(pb, { playerController.open() }, backend::togglePlay, backend::next, backend::previous, { pos.value.progress(pb.durationMs) },
                            Modifier
                                .focusRequester(miniFocusRequester)
                                .focusable()
                                .graphicsLayer {
                                    val p = playerController.progress
                                    val hideOffset = miniHideState.dragOffset
                                    alpha = miniPlayerAlpha(p, playerController.reduceMotion) * hideAlphaFactor(hideOffset, hideConfig)
                                    translationX = if (hideConfig.axis == MiniPlayerHideAxis.HorizontalAny) hideOffset else 0f
                                    translationY = miniPlayerTranslationY(p, miniMaxShiftPx, playerController.reduceMotion) +
                                        if (hideConfig.axis == MiniPlayerHideAxis.VerticalDown) hideOffset else 0f
                                }.then(if (prefs.floatingNav) Modifier else if (modernUi) Modifier.padding(horizontal = dockSideMargin) else Modifier.padding(horizontal = 8.dp))
                                // Default uses horizontal drag-to-hide here; Modern uses unified axis-locked gestures inside ModernMiniPlayer.
                                .then(
                                    if (!modernUi) Modifier.draggable(
                                        androidx.compose.foundation.gestures.rememberDraggableState { d ->
                                            miniHideState.onDragDelta(d, hideConfig, pb.playing)
                                        },
                                        androidx.compose.foundation.gestures.Orientation.Horizontal,
                                        enabled = canDismissMiniPlayer(pb.playing),
                                        onDragStopped = { velocity ->
                                            miniHideState.onDragEnd(
                                                velocityPxPerSec = velocity,
                                                config = hideConfig,
                                                playing = pb.playing,
                                                dismissSpec = miniSwipeDismissSpec,
                                                returnSpec = miniSwipeReturnSpec,
                                            )
                                        },
                                    ) else Modifier
                                ),
                            onDevices = { id -> navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add(id) } },
                            coverBounds = coverBounds,
                            coverHidden = { playerController.isCoverFlightActive(coverBounds) },
                            covered = playerController.isCovered,
                            outputInfoFlow = if (modernUi) backend.outputInfo else null,
                            hideState = miniHideState,
                            hideConfig = hideConfig,
                            playerController = playerController,
                            sheetHeightPx = { phoneHeightPx.takeIf { it > 1f } ?: with(density) { 640.dp.toPx() } },
                            onDismissAccessibility = {
                                scope.launch { miniHideState.dismissProgrammatically(hideConfig, pb.playing, miniSwipeDismissSpec) }
                            })
                        Box(Modifier.height(dockGap))
                    }
                    val navTotalPx = with(androidx.compose.ui.platform.LocalDensity.current) {
                        (navHeight + bottomInset + (if (prefs.floatingNav) 24.dp else 0.dp)).toPx()
                    }
                    NavBar(
                        selected = if (settings) 3 else tab,
                        backdrop = backdrop,
                        prefs = prefs,
                        inset = bottomInset,
                        onSelect = { sel -> navigate { tab = sel; detail = null; settings = false; settingsStack.clear(); profilePage = null } },
                        modifier = Modifier.graphicsLayer {
                            val p = playerController.progress
                            alpha = navBarAlpha(p, playerController.reduceMotion)
                            translationY = navBarTranslationY(p, navTotalPx, playerController.reduceMotion)
                        },
                        taskRunning = scanning,
                        coverUri = pb.current?.coverUri,
                    )
                }
                PlayerSheetHost(
                    controller = playerController,
                    coverBounds = coverBounds,
                    onRequestFocusReturn = { runCatching { miniFocusRequester.requestFocus() } },
                    overlayActive = showEqFullScreen || showLyricsFullScreen,
                ) {
                    FullPlayer(
                        pb, pbError, backend, actions, { playerController.close() },
                        onOpenSettings = { id -> navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add(id) } },
                        onOpenEq = { showEqFullScreen = true },
                        onOpenLyrics = { showLyricsFullScreen = true },
                    )
                }
                SharedCoverLayer(
                    controller = playerController,
                    coverBounds = coverBounds,
                    song = pb.current,
                    targetCornerRadiusDp = if (resolveEffectivePlayerStyle(prefs) == PlayerStyle.Modern) 24.dp else 28.dp,
                    startCircular = modernUi,
                )
                val eqReduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
                androidx.compose.animation.AnimatedVisibility(
                    visible = showLyricsFullScreen && pb.current != null,
                    enter = overlayPageEnter(eqReduceMotion),
                    exit = overlayPageExit(eqReduceMotion),
                ) {
                    FullLyricsPage(
                        state = pb,
                        backend = backend,
                        actions = actions,
                        onClose = { showLyricsFullScreen = false },
                    )
                }
                androidx.compose.animation.AnimatedVisibility(
                    visible = showEqFullScreen,
                    enter = overlayPageEnter(eqReduceMotion),
                    exit = overlayPageExit(eqReduceMotion),
                ) {
                    FullScreenEqualizerPage(
                        backend = backend,
                        onBack = { showEqFullScreen = false },
                    )
                }
            } else {
                // Desktop: sidebar, content card, now playing panel, player bar.
                val volume by backend.volume.collectAsState()
                LaunchedEffect(settings) { if (settings && settingsStack.isEmpty()) settingsStack.add("style") }
                val playlistId = (detail as? Detail.Playlist)?.id
                LaunchedEffect(page, detail, settings) { showNow = false }
                val droppedFiles by IncomingDrops.files.collectAsState()
                val dropDragging by IncomingDrops.dragging.collectAsState()
                val dropCount by IncomingDrops.dragCount.collectAsState()
                LaunchedEffect(droppedFiles) {
                    if (droppedFiles.isNotEmpty() && page != "upload") {
                        navigate { page = "upload"; detail = null; settings = false; showNow = false }
                    }
                }
                val keys = rememberPlayerKeys(backend, volume)
                // Alt + Left arrow goes back, like the mouse's back button.
                val backKey = Modifier.onPreviewKeyEvent { e ->
                    if (e.type == androidx.compose.ui.input.key.KeyEventType.KeyDown && e.isAltPressed && e.key == androidx.compose.ui.input.key.Key.DirectionLeft) { handleBack(); true } else false
                }
                PublishMiniState(prefs.miniFormat)
                // The saved song comes back a few seconds after the window shows; the panel's room is kept from the first frame so the page does not re-lay out.
                var waitingForSong by remember { mutableStateOf(prefs.songExpected) }
                LaunchedEffect(Unit) { kotlinx.coroutines.delay(25_000); waitingForSong = false }
                var sidebarExpanded by remember { mutableStateOf(true) }
                WindowTintFromState(g0)
                // The mouse back button goes back like the phone gesture.
                // While the full now playing view is open the whole window takes the song's colours, so the sidebar and
                // player bar sit on the same wash as the card instead of on the plain page background.
                // Only on the Plain and Cover backgrounds: a blurred cover, gradient, wallpaper or animation the user chose stays.
                val nowSong = if (showNow && (prefs.background == BgMode.Plain || prefs.background == BgMode.Cover)) pb.current else null
                val shell: @Composable () -> Unit = {
                val goPage: (String) -> Unit = { target ->
                    navigate {
                        detail = null; settingsStack.clear(); showNow = false
                        if (target == "settings") { settings = true; settingsDeep = false } else if (target in toolPages.map { t -> t.id }) { settings = true; settingsStack.add(target) } else { page = target; settings = false }
                    }
                }
                Column(Modifier.fillMaxSize().mouseBackButton(::handleBack).playerKeys(keys).then(backKey)) {
                    DesktopTopBar(prefs, backend, canBack = showNow || history.isNotEmpty() || settings || detail != null, onBack = ::handleBack, onGo = goPage, Modifier.padding(start = 12.dp, top = 8.dp, end = 12.dp))
                    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().padding(start = 12.dp, top = 8.dp, end = 12.dp)) {
                        val panel = prefs.nowPlayingPanel && (pb.current != null || waitingForSong) && !showNow && maxWidth >= 960.dp
                        val sidebarTarget = (if (sidebarExpanded) prefs.sidebarWidth.dp else 72.dp).coerceAtMost(maxWidth * 0.35f)
                        Row(Modifier.fillMaxSize()) {
                        Sidebar(
                            page, playlistId, lib.playlists,
                            expanded = sidebarExpanded,
                            onToggle = { sidebarExpanded = !sidebarExpanded },
                            onPage = goPage,
                            onPlaylist = { g -> navigate { detail = Detail.Playlist(g.id, g.name); settings = false; showNow = false } },
                            onNewPlaylist = { newPlaylist = true },
                            onTelegram = { t -> navigate { detail = Detail.Songs(t.name, t.songs); settings = false; showNow = false } },
                            modifier = Modifier.animatedWidth(sidebarTarget).fillMaxHeight(),
                        )
                        Spacer(Modifier.width(12.dp))
                        Box(Modifier.weight(1f).fillMaxHeight().deskCard()) {
                            val pad = 16.dp
                            val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
                            val density = androidx.compose.ui.platform.LocalDensity.current
                            val shiftPx = with(density) { io.max.paperplay.ui.theme.Motion.Desktop.PageShiftDp.dp.roundToPx() }
                            val sideShiftPx = with(density) { io.max.paperplay.ui.theme.Motion.Desktop.PageSideShiftDp.dp.roundToPx() }
                            val pageStates = androidx.compose.runtime.saveable.rememberSaveableStateHolder()
                            AnimatedContent(
                                targetState = DeskKey(showNow && pb.current != null, settings, detail, page),
                                modifier = Modifier.fillMaxSize(),
                                transitionSpec = { desktopPageTransition(desktopNavMove, reduceMotion, shiftPx, sideShiftPx) },
                                label = "page",
                            ) { k ->
                            val deskPage: @Composable () -> Unit = {
                            val d = k.detail
                            when {
                                k.now -> DesktopNowPlayingView(pb, backend, actions, { desktopNavMove = NavMove.Back; showNow = false }, Modifier.fillMaxSize())
                                k.settings -> CompositionLocalProvider(LocalSettingsInfo provides true) { DesktopSettings(settingsStack, prefs, conn, songs.size, backend, onRestore, ::goBack, Modifier.fillMaxSize()) }
                                d != null -> DetailScreen(d, backend, currentId, actions, ::goBack, pad)
                                k.page == "home" -> HomeScreen(lib, home, favorites, currentId, conn, scan, actions, { d2 -> navigate { detail = d2 } }, pad, name = prefs.profileName, warm = homeWarm)
                                k.page == "search" -> SearchScreen(backend::search, songs, currentId, actions, { d2 -> navigate { detail = d2 } }, pad)
                                k.page == "profile" -> ProfileScreen(
                                    songs.size, favorites.size, lib.playlists.size, conn, prefs,
                                    mainChatTitle,
                                    onSettings = { id ->
                                        navigate {
                                            settings = true
                                            settingsDeep = id != null
                                            settingsStack.clear()
                                            id?.let(settingsStack::add)
                                        }
                                    },
                                    onTasks = { navigate { page = "tasks" } },
                                    onLibraryTab = { selected ->
                                        navigate {
                                            page = when (selected) {
                                                3 -> "playlists"
                                                4 -> "favorites"
                                                else -> "songs"
                                            }
                                        }
                                    },
                                    pad,
                                    scan = scan,
                                    runningTasks = runningTasks,
                                    updates = backend.services.updates,
                                    backend = backend, recents = recents, onPlay = actions.play,
                                )
                                k.page == "tasks" -> TasksScreen(backend.tasks, onBack = ::goBack, onOpen = { kd -> openLive(kd) })
                                k.page == "upload" -> Column(Modifier.verticalScroll(androidx.compose.foundation.rememberScrollState())) { TopBar("Upload"); UploadsPage(backend); androidx.compose.foundation.layout.Spacer(Modifier.height(120.dp)) }
                                k.page == "songs" -> Column { TopBar("Songs"); SongList(songs, currentId, actions, Modifier.fillMaxSize(), pad, empty = "No songs yet. Add a chat in Settings.", listKey = "library:songs") }
                                k.page == "playlists" -> Column {
                                    TopBar("Playlists")
                                    PlaylistsTab(lib.playlists, favorites, recents, pad, { d2 -> navigate { detail = d2 } }, { newPlaylist = true },
                                        { navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("spotify") } })
                                }
                                k.page == "albums" -> Column { TopBar("Albums"); GroupBrowser(LocalAlbums.current.collectAsState().value, artists = false, pad) { g -> navigate { detail = Detail.Album(g.name, g.owner) } } }
                                k.page == "artists" -> Column { TopBar("Artists"); GroupBrowser(LocalArtists.current.collectAsState().value, artists = true, pad) { g -> navigate { detail = Detail.Artist(g.name) } } }
                                k.page == "favorites" -> Column { TopBar("Favorites"); SongList(favorites, currentId, actions, Modifier.fillMaxSize(), pad, empty = "No favorites yet.", listKey = "library:favorites") }
                                else -> Column { TopBar("Recently played"); SongList(recents, currentId, actions, Modifier.fillMaxSize(), pad, sortable = false, empty = "Nothing played yet.") }
                            }
                            }
                            if (k.now || k.settings || k.detail != null) deskPage() else pageStates.SaveableStateProvider(k.page) { deskPage() }
                            }
                        }
                        androidx.compose.animation.AnimatedVisibility(panel, enter = panelEnter(), exit = panelExit()) {
                            Row {
                                Spacer(Modifier.width(12.dp))
                                if (pb.current != null) NowPlayingPanel(pb, backend, actions, { playerController.open() }, { prefs.putNowPlayingPanel(false) }, Modifier.width(320.dp).fillMaxHeight().deskCard())
                                else Box(Modifier.width(320.dp).fillMaxHeight().deskCard())
                            }
                        }
                        }
                    }
                    RemoteNowStrip(backend)
                    PlayerBar(pb, volume, backend, actions, { playerController.open() },
                        onNowPlaying = {
                            desktopNavMove = if (showNow) NavMove.Back else NavMove.Forward
                            showNow = !showNow
                        },
                        transportInPage = showNow && pb.current != null,
                        extras = { DevicePickerButton(onOpen = { id -> navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add(id) } }); MiniPlayerToggle() })
                }
                }
                if (nowSong != null) CoverTinted(nowSong.coverUri) {
                    var phoneHeightPx by remember { androidx.compose.runtime.mutableFloatStateOf(0f) }
        Box(Modifier.fillMaxSize().onSizeChanged { phoneHeightPx = it.height.toFloat() }) {
                        // One tone per main colour of the cover, running diagonally; a cover with one colour fades to a darker shade of it.
                        val top = MaterialTheme.colorScheme.primaryContainer
                        val tones = CoverSeeds.palette(nowSong.coverUri).map { schemeFromSeed(it, true).primaryContainer }.ifEmpty { listOf(top) }
                        val stops = if (tones.size > 1) tones else listOf(top, androidx.compose.ui.graphics.Color.Black.copy(alpha = 0.35f).compositeOver(top))
                        Box(Modifier.fillMaxSize().drawBehind {
                            drawRect(androidx.compose.ui.graphics.Brush.linearGradient(stops, androidx.compose.ui.geometry.Offset.Zero, androidx.compose.ui.geometry.Offset(size.width, size.height)))
                        })
                        shell()
                    }
                } else Box(Modifier.fillMaxSize().drawWithContent { if (!playerController.isCovered) drawContent() }) { shell() }
                PlayerSheetHost(playerController) { FullPlayer(pb, pbError, backend, actions, { playerController.close() }) }
                AppSnackbarHost(snack, Modifier.align(Alignment.BottomCenter).padding(bottom = 96.dp), tint)
                ShortcutsOverlay(keys, Modifier.fillMaxSize())
                DesktopFileDropOverlay(visible = dropDragging, fileCount = dropCount)
            }
            Row(
                Modifier.align(Alignment.TopEnd).padding(top = if (isPhone) WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 8.dp else 16.dp, end = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                NetplayIndicator(
                    backend, Modifier,
                ) { navigate { settings = true; settingsDeep = true; settingsStack.clear(); settingsStack.add("netplay") } }
                // Only a way to open the panel: hidden while the panel, the now playing view or the full player is up, back once the panel is closed.
                if (!isPhone && pb.current != null && !prefs.nowPlayingPanel && !playerController.isComposed) {
                    val panelOn = prefs.nowPlayingPanel
                    val on = MaterialTheme.colorScheme.primary
                    val off = MaterialTheme.colorScheme.onSurfaceVariant
                    Spacer(Modifier.width(8.dp))
                    DesktopTooltip("Show now playing panel") {
                        androidx.compose.material3.Surface(
                            shape = androidx.compose.foundation.shape.CircleShape,
                            color = androidx.compose.ui.graphics.Color.Transparent,
                            modifier = Modifier
                                .desktopInteractive(androidx.compose.foundation.shape.CircleShape)
                                .clickable { prefs.putNowPlayingPanel(!prefs.nowPlayingPanel) },
                        ) {
                            io.max.paperplay.ui.components.AppIcon(
                                Icons.AutoMirrored.Rounded.ViewSidebar,
                                if (panelOn) "Hide the now playing panel" else "Show the now playing panel",
                                Modifier.padding(10.dp).size(20.dp),
                                tint = if (panelOn) on else off
                            )
                        }
                    }
                }
            }
            StatusToastFromState(
                conn, scan, if (lib.songs is Load.Ready) songs.size else 1, g0,
                if (isPhone) Modifier.align(Alignment.TopCenter).padding(top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 8.dp)
                // On a desktop it sits bottom right above the player bar, clear of page titles and the panel button.
                else Modifier.align(Alignment.BottomEnd).padding(bottom = 96.dp, end = 8.dp),
            )
            if (isPhone && runMotionHarness) {
                PlayerMotionHarness(
                    active = true,
                    controller = playerController,
                    onDone = { report ->
                        runMotionHarness = false
                        scope.launch {
                            snack.showSnackbar("Motion bench: p95=${report.p95FrameMs.toInt()}ms max=${report.maxFrameMs.toInt()}ms >20ms=${report.framesOver20ms}")
                        }
                    },
                    modifier = Modifier.align(Alignment.TopCenter).padding(top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 12.dp),
                )
            }
        }

        pickFor?.let { ids ->
            PlaylistPicker(
                lib.playlists, onPick = { backend.addToPlaylist(it, ids); pickFor = null },
                onNew = { pickFor = null; newPlaylist = true; pendingAdd = ids }, onDismiss = { pickFor = null },
            )
        }
        if (newPlaylist) {
            NameDialog("New playlist", onDone = { name ->
                backend.createPlaylist(name, pendingAdd.orEmpty())
                pendingAdd = null
                newPlaylist = false
            }, onDismiss = { newPlaylist = false; pendingAdd = null })
        }
    }
}

@Composable
private fun PlaylistPicker(
    playlists: List<io.max.paperplay.ui.state.GroupUi>, onPick: (String) -> Unit, onNew: () -> Unit, onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = overlayRim(appShape(28.dp, CornerArea.Dialogs)), shape = appShape(28.dp, CornerArea.Dialogs), containerColor = overlayColor(),
        confirmButton = { TextButton(onNew) { Text("New playlist") } },
        dismissButton = { TextButton(onDismiss) { Text("Cancel") } },
        title = { Text("Add to playlist") },
        text = {
            if (playlists.isEmpty()) Text("No playlists yet.")
            else LazyColumn {
                items(playlists, key = { it.id }) { p ->
                    Text(p.name, Modifier.fillMaxWidth().clickable { onPick(p.id) }.padding(vertical = 12.dp), style = MaterialTheme.typography.bodyLarge)
                }
            }
        },
    )
}

@Composable
private fun NameDialog(title: String, onDone: (String) -> Unit, onDismiss: () -> Unit) {
    var name by remember { mutableStateOf("") }
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = overlayRim(appShape(28.dp, CornerArea.Dialogs)), shape = appShape(28.dp, CornerArea.Dialogs), containerColor = overlayColor(),
        confirmButton = { TextButton({ onDone(name) }) { Text("Create") } },
        dismissButton = { TextButton(onDismiss) { Text("Cancel") } },
        title = { Text(title) },
        text = { OutlinedTextField(name, { name = it }, singleLine = true, label = { Text("Name") }) },
    )
}

@Preview
@Composable
private fun PlaylistPickerPreview() {
    val samplePlaylists = listOf(io.max.paperplay.ui.state.GroupUi(id = "1", name = "Chill Vibes", subtitle = "10 songs"))
    PlaylistPicker(playlists = samplePlaylists, onPick = {}, onNew = {}, onDismiss = {})
}

@Preview
@Composable
private fun NameDialogPreview() {
    NameDialog(title = "New playlist", onDone = {}, onDismiss = {})
}

private val launchMark = kotlin.time.TimeSource.Monotonic.markNow()

/** Connection toasts wait until the app has been open for 10 seconds, so starting it is not noisy. */
private suspend fun waitForQuietStart() {
    val left = 10_000L - launchMark.elapsedNow().inWholeMilliseconds
    if (left > 0) kotlinx.coroutines.delay(left)
}

private val announcedConnecting = mutableSetOf<String>()

@Composable
private fun WindowTintFromState(g0: androidx.compose.runtime.State<androidx.compose.ui.graphics.Color>) {
    WindowTint(g0.value)
}

@Composable
private fun StatusToastFromState(
    conn: ConnectionUi,
    scan: androidx.compose.runtime.State<ScanUi?>,
    songCount: Int,
    g0: androidx.compose.runtime.State<androidx.compose.ui.graphics.Color>,
    modifier: Modifier,
) {
    StatusToast(conn, scan, songCount, g0.value, modifier)
}
