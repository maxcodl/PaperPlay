package io.max.paperplay.ui.app

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccountCircle
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.CleaningServices
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Devices
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Forum
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.PlaylistPlay
import androidx.compose.material.icons.rounded.Rule
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.SettingsEthernet
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material.icons.rounded.Upload
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialShapes
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
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
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
import androidx.graphics.shapes.Cubic
import androidx.graphics.shapes.Morph
import io.max.paperplay.core.update.UpdateService
import io.max.paperplay.core.update.UpdateState
import io.max.paperplay.ui.StaticLogo
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.LocalInsideModernSurface
import io.max.paperplay.ui.components.modernSurfaceStatic
import io.max.paperplay.ui.currentHour
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

internal enum class UiPreviewOverride(val label: String) {
    Live("Live data"),
    Loading("Loading skeleton"),
    Empty("Empty history"),
    Error("Error state"),
    NoAvatar("No avatar"),
}

/** Pure in-memory developer preview override for Profile & Stats states (never persisted). */
internal val uiPreviewOverride = kotlinx.coroutines.flow.MutableStateFlow(UiPreviewOverride.Live)

internal sealed interface ProfileStatsState {
    data object Loading : ProfileStatsState
    data class Ready(val stats: ProfileStats) : ProfileStatsState
    data class Error(val message: String) : ProfileStatsState
}

/**
 * Unified Android Profile screen shared by [UiStyle.Default] and [UiStyle.Modern].
 * Both styles share state, stats loading, and navigation targets while rendering native surfaces and typography.
 */
@Composable
internal fun AndroidProfileScreen(
    songs: Int,
    favorites: Int,
    playlists: Int,
    conn: ConnectionUi,
    prefs: UiPrefs,
    mainChatTitle: String?,
    onSettings: (String?) -> Unit,
    onTasks: () -> Unit,
    onLibraryTab: (Int) -> Unit,
    bottomPadding: Dp,
    modifier: Modifier = Modifier,
    scan: androidx.compose.runtime.State<ScanUi?>? = null,
    runningTasks: Int = 0,
    updates: UpdateService? = null,
    backend: CoreBackend? = null,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val previewOverride by uiPreviewOverride.collectAsState()
    var retryTick by remember { mutableIntStateOf(0) }
    var statsState by remember(backend) {
        mutableStateOf<ProfileStatsState>(
            backend?.cachedProfileStats?.value?.let { ProfileStatsState.Ready(it) }
                ?: if (backend == null) ProfileStatsState.Ready(emptyProfileStats()) else ProfileStatsState.Loading,
        )
    }

    LaunchedEffect(backend, retryTick) {
        if (backend == null) {
            statsState = ProfileStatsState.Ready(emptyProfileStats())
            return@LaunchedEffect
        }
        val cached = backend.cachedProfileStats.value
        if (cached != null) {
            statsState = ProfileStatsState.Ready(cached)
        } else if (statsState !is ProfileStatsState.Loading) {
            statsState = ProfileStatsState.Loading
        }
        backend.services.library.changes.collect {
            val loaded = withContext(Dispatchers.Default) {
                runCatching { backend.profileStats() }
            }
            statsState = loaded.fold(
                onSuccess = { ProfileStatsState.Ready(it) },
                onFailure = { e -> ProfileStatsState.Error(e.message ?: "Could not load listening stats") },
            )
            delay(2_000)
        }
    }

    val effectiveStatsState = when (previewOverride) {
        UiPreviewOverride.Loading -> ProfileStatsState.Loading
        UiPreviewOverride.Empty -> ProfileStatsState.Ready(emptyProfileStats())
        UiPreviewOverride.Error -> ProfileStatsState.Error("Simulated stats error")
        UiPreviewOverride.Live, UiPreviewOverride.NoAvatar -> statsState
    }

    val scanText = scan?.value?.text
    val tasksSubtitle = scanText ?: if (runningTasks > 0) "$runningTasks running" else "Nothing running"

    val header: @Composable () -> Unit = {
        ProfileHeader(modern = modern, onSettings = { onSettings(null) })
    }
    val identity: @Composable () -> Unit = {
        val readyStats = (effectiveStatsState as? ProfileStatsState.Ready)?.stats
        ProfileIdentityCard(
            prefs = prefs,
            photoOverride = if (previewOverride == UiPreviewOverride.NoAvatar) null else prefs.profilePhoto,
            songs = songs,
            favorites = favorites,
            playlists = playlists,
            topArtist = readyStats?.weekTopArtist?.let { "This week · ${it.first}" }
                ?: readyStats?.topArtist?.let { "Last 30 days · ${it.first}" },
            onEditProfile = { onSettings("profile") },
            onLibraryTab = onLibraryTab,
            onOpenStats = { onSettings("stats") },
            modifier = Modifier.profileStaggerIn(0),
        )
    }
    val statsBlock: @Composable () -> Unit = {
            when (val s = effectiveStatsState) {
                ProfileStatsState.Loading -> ProfileStatsSkeleton(
                    modern = modern,
                    modifier = Modifier.profileStaggerIn(1),
                )
                is ProfileStatsState.Error -> ProfileStatsErrorCard(
                    message = s.message,
                    onRetry = {
                        uiPreviewOverride.value = UiPreviewOverride.Live
                        retryTick++
                    },
                    modifier = Modifier.profileStaggerIn(1),
                )
                is ProfileStatsState.Ready -> {
                    if (s.stats.totalMs <= 0L) {
                        ProfileStatsEmptyCard(
                            onStartListening = { onLibraryTab(0) },
                            onOpenStats = { onSettings("stats") },
                            modifier = Modifier.profileStaggerIn(1),
                        )
                    } else {
                        ProfileStatTilesRow(
                            stats = s.stats,
                            onOpenStats = { onSettings("stats") },
                            modifier = Modifier.profileStaggerIn(1),
                        )
                    }
                }
            }
    }
    val quick: @Composable () -> Unit = {
        ProfileQuickActionsSection(
            runningTasks = runningTasks,
            hasScan = scanText != null,
            onAccount = { onSettings("account") },
            onTasks = onTasks,
            onScan = { onSettings("repair") },
            onUpload = { onSettings("uploadhub") },
            modifier = Modifier.profileStaggerIn(2),
        )
    }
    val library: @Composable () -> Unit = {
        Column(Modifier.profileStaggerIn(3), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ProfileSectionHeader("Library & tools")
            ProfileSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
                ProfileIconRow(
                    title = if (conn.chats.size == 1) "1 channel" else "${conn.chats.size} channels",
                    subtitle = mainChatTitle?.let { "Main chat: $it" } ?: "No chat added yet",
                    icon = Icons.Rounded.Forum,
                    onClick = { onSettings("channels") },
                )
                ProfileRowDivider(modern)
                ProfileIconRow(
                    title = "Duplicates",
                    subtitle = "Find repeated songs and remove extras",
                    icon = Icons.Rounded.ContentCopy,
                    onClick = { onSettings("dupes") },
                )
                ProfileRowDivider(modern)
                ProfileIconRow(
                    title = "Song info left",
                    subtitle = "Songs still missing info or a cover",
                    icon = Icons.Rounded.Rule,
                    onClick = { onSettings("missing") },
                )
            }
        }
    }
    val devices: @Composable () -> Unit = {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            ProfileSectionHeader("Devices & storage")
            ProfileSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
                ProfileIconRow(
                    title = "Connection",
                    subtitle = "Telegram status, devices on this network, pairing",
                    icon = Icons.Rounded.SettingsEthernet,
                    onClick = { onSettings("conn") },
                )
                ProfileRowDivider(modern)
                ProfileIconRow(
                    title = "Network play",
                    subtitle = "Listen together on the same network",
                    icon = Icons.Rounded.Devices,
                    onClick = { onSettings("netplay") },
                )
                ProfileRowDivider(modern)
                ProfileIconRow(
                    title = "Cache and backup",
                    subtitle = "Manage cached songs and library backups",
                    icon = Icons.Rounded.CleaningServices,
                    onClick = { onSettings("storage") },
                )
            }
        }
    }
    val about: @Composable () -> Unit = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ProfileSectionHeader("App")
                updates?.let { ProfileAboutCard(updates = it, onOpen = { onSettings("about") }) }
                MadeBy()
            }
    }
    val madeBy: @Composable () -> Unit = {
            MadeBy()
    }
    val gap = if (modern) 20.dp else 16.dp
    BoxWithConstraints(modifier.fillMaxSize()) {
        if (!io.max.paperplay.ui.isPhone && maxWidth >= 840.dp) {
            // A wide window (the PC): the same parts in two columns, you and your listening on the left, the rest on the right.
            Row(
                Modifier.fillMaxSize().widthIn(max = 1280.dp).align(Alignment.TopCenter).padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Column(
                    Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()).padding(top = 8.dp, bottom = bottomPadding + 32.dp),
                    verticalArrangement = Arrangement.spacedBy(gap),
                ) {
                    header()
                    identity()
                    if (backend != null) statsBlock()
                    quick()
                }
                Column(
                    Modifier.weight(1f).fillMaxHeight().verticalScroll(rememberScrollState()).padding(top = 8.dp, bottom = bottomPadding + 32.dp),
                    verticalArrangement = Arrangement.spacedBy(gap),
                ) {
                    // Lines the first card up with the identity card beside it.
                    Spacer(Modifier.height(56.dp))
                    library()
                    devices()
                    if (updates != null) about() else madeBy()
                }
            }
        } else LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(top = 8.dp, bottom = bottomPadding + 32.dp),
            verticalArrangement = Arrangement.spacedBy(gap),
        ) {
            item(key = "profile_header", contentType = "header") { header() }
            item(key = "profile_identity", contentType = "identity") { identity() }
            if (backend != null) item(key = "profile_stats", contentType = "stats") { statsBlock() }
            item(key = "profile_quick_actions", contentType = "quick_actions") { quick() }
            item(key = "profile_library_tools", contentType = "section") { library() }
            item(key = "profile_devices_storage", contentType = "section") { devices() }
            if (updates != null) item(key = "profile_about", contentType = "about") { about() }
            else item(key = "profile_made_by", contentType = "footer") { madeBy() }
        }
    }
}

private fun emptyProfileStats() = computeProfileStats(emptyMap(), emptyList(), emptyList(), 0L)

@Composable
private fun ProfileHeader(modern: Boolean, onSettings: () -> Unit) {
    val tokens = LocalModernTokens.current
    Row(
        Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Profile",
            modifier = Modifier.weight(1f),
            style = if (modern) {
                MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.ExtraBold)
            } else {
                MaterialTheme.typography.headlineMedium
            },
            color = if (modern) tokens.onGlass else MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (modern) {
            Box(
                Modifier
                    .size(48.dp)
                    .then(modernSurfaceStatic(tokens.cardBgElevated, CircleShape))
                    .clickable(role = Role.Button, onClick = onSettings)
                    .semantics { contentDescription = "Settings" },
                contentAlignment = Alignment.Center,
            ) {
                AppIcon(Icons.Rounded.Settings, null, tint = tokens.onGlass)
            }
        } else {
            IconButton(onClick = onSettings, modifier = Modifier.size(48.dp)) {
                AppIcon(Icons.Rounded.Settings, "Settings")
            }
        }
    }
}

@Composable
private fun ProfileSurfaceCard(
    modifier: Modifier = Modifier,
    shape: Shape = appShape(28.dp, CornerArea.Cards),
    elevated: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    val tokens = LocalModernTokens.current
    val cardMod = if (tokens.enabled) {
        val fill = if (elevated) tokens.cardBgElevated else tokens.cardBg
        modifier.fillMaxWidth().then(modernSurfaceStatic(fill, shape))
    } else {
        modifier.fillMaxWidth().partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, shape)
    }
    Column(cardMod) {
        CompositionLocalProvider(LocalInsideModernSurface provides tokens.enabled) {
            content()
        }
    }
}

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
private fun ProfileIdentityCard(
    prefs: UiPrefs,
    photoOverride: String? = prefs.profilePhoto,
    songs: Int,
    favorites: Int,
    playlists: Int,
    topArtist: String?,
    onEditProfile: () -> Unit,
    onLibraryTab: (Int) -> Unit,
    onOpenStats: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    val h = currentHour()
    val greeting = if (h < 12) "Good morning" else if (h < 18) "Good afternoon" else "Good evening"
    val displayName = prefs.profileName.trim().ifEmpty { "Listener" }
    val press = remember { MutableInteractionSource() }

    ProfileSurfaceCard(modifier.padding(horizontal = 16.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .pressScale(press, Motion.Micro.CardPressScale)
                .clickable(
                    interactionSource = press,
                    indication = androidx.compose.foundation.LocalIndication.current,
                    onClickLabel = "Edit profile",
                    onClick = onEditProfile,
                )
                .semantics(mergeDescendants = true) {
                    contentDescription = "$greeting, $displayName. Double tap to edit profile"
                }
                .padding(horizontal = 18.dp, vertical = 18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(Modifier.size(68.dp)) {
                Avatar(photoOverride, displayName, 68.dp)
                if (modern) {
                    ScallopedEditBadge(
                        Modifier.align(Alignment.BottomEnd),
                        containerColor = scheme.primary,
                        contentColor = scheme.onPrimary,
                    )
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = greeting,
                    style = MaterialTheme.typography.labelLarge,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = displayName,
                    style = if (modern) {
                        MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.ExtraBold)
                    } else {
                        MaterialTheme.typography.headlineSmall
                    },
                    color = if (modern) tokens.onGlass else scheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Box(
                Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh),
                contentAlignment = Alignment.Center,
            ) {
                AppIcon(
                    Icons.Rounded.Edit,
                    null,
                    Modifier.size(20.dp),
                    tint = if (modern) tokens.onGlass else scheme.onSurfaceVariant,
                )
            }
        }

        if (topArtist != null) {
            val stripShape = appShape(50.dp, CornerArea.Chips)
            Row(
                Modifier
                    .padding(start = 18.dp, end = 18.dp, bottom = 14.dp)
                    .fillMaxWidth()
                    .clip(stripShape)
                    .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh)
                    .clickable(onClickLabel = "Open listening statistics", onClick = onOpenStats)
                    .defaultMinSize(minHeight = 40.dp)
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                AppIcon(
                    Icons.Rounded.Headphones,
                    null,
                    Modifier.size(16.dp),
                    tint = if (modern) tokens.accentOnGlass else scheme.primary,
                )
                Text(
                    text = topArtist,
                    style = MaterialTheme.typography.labelLarge,
                    color = if (modern) tokens.onGlass else scheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        Row(
            Modifier
                .fillMaxWidth()
                .padding(start = 10.dp, end = 10.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            ProfileCountItem(
                icon = Icons.Rounded.MusicNote,
                count = songs,
                label = "Songs",
                modern = modern,
                modifier = Modifier.weight(1f),
                onClick = { onLibraryTab(0) },
            )
            val dividerColor = scheme.outlineVariant.copy(alpha = 0.5f)
            if (!modern) {
                Box(Modifier.width(1.dp).height(34.dp).clip(CircleShape).background(dividerColor, CircleShape))
            }
            ProfileCountItem(
                icon = Icons.Rounded.Favorite,
                count = favorites,
                label = "Favorites",
                modern = modern,
                modifier = Modifier.weight(1f),
                onClick = { onLibraryTab(4) },
            )
            if (!modern) {
                Box(Modifier.width(1.dp).height(34.dp).clip(CircleShape).background(dividerColor, CircleShape))
            }
            ProfileCountItem(
                icon = Icons.Rounded.PlaylistPlay,
                count = playlists,
                label = "Playlists",
                modern = modern,
                modifier = Modifier.weight(1f),
                onClick = { onLibraryTab(3) },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
private fun ScallopedEditBadge(
    modifier: Modifier = Modifier,
    containerColor: Color,
    contentColor: Color,
) {
    val morph = remember { Morph(MaterialShapes.Cookie9Sided, MaterialShapes.Cookie9Sided) }
    Box(modifier.size(26.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier.matchParentSize().drawWithCache {
                val path = Path()
                val matrix = Matrix().apply { scale(this@drawWithCache.size.width, this@drawWithCache.size.height) }
                morph.forEachCubic(0f) { c: Cubic ->
                    if (path.isEmpty) path.moveTo(c.anchor0X, c.anchor0Y)
                    path.cubicTo(c.control0X, c.control0Y, c.control1X, c.control1Y, c.anchor1X, c.anchor1Y)
                }
                path.close()
                path.transform(matrix)
                onDrawBehind {
                    drawPath(path = path, color = containerColor)
                }
            },
        )
        AppIcon(Icons.Rounded.Edit, null, Modifier.size(14.dp), tint = contentColor)
    }
}

@Composable
private fun ProfileCountItem(
    icon: ImageVector,
    count: Int,
    label: String,
    modern: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    Column(
        modifier
            .defaultMinSize(minHeight = 56.dp)
            .clip(appShape(18.dp, CornerArea.Chips))
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) {
                contentDescription = "$count $label, open library"
            }
            .padding(vertical = 8.dp, horizontal = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        AppIcon(icon, null, Modifier.size(18.dp), tint = if (modern) tokens.accentOnGlass else scheme.primary)
        Text(
            text = "$count",
            modifier = Modifier.padding(top = 4.dp),
            style = if (modern) {
                MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold)
            } else {
                MaterialTheme.typography.titleLarge
            },
            color = if (modern) tokens.onGlass else scheme.onSurface,
            maxLines = 1,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ProfileStatTilesRow(
    stats: ProfileStats,
    onOpenStats: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    val reduceMotion = LocalReduceMotion.current
    val largeFont = LocalDensity.current.fontScale >= 1.5f

    val primaryMs = if (stats.weekMs > 0L) stats.weekMs else stats.totalMs
    val animatedMs by animateFloatAsState(
        targetValue = primaryMs.toFloat(),
        animationSpec = if (reduceMotion) {
            io.max.paperplay.ui.theme.motionEffectTween(1)
        } else {
            motionEffectTween(Motion.Effects.WashMs, easing = Motion.Emphasized)
        },
        label = "profileListenCount",
    )
    val shownMs = if (reduceMotion) primaryMs else animatedMs.toLong()

    val timeLabel = if (stats.weekMs > 0L) "This week" else "Listening time"
    val timeSubtitle = if (stats.weekMs > 0L) "${fmtCompactTime(stats.totalMs)} total" else "${stats.totalPlays} plays"

    val streakBig = if (stats.currentStreak > 0) "${stats.currentStreak}d" else "${stats.totalPlays}"
    val streakLabel = if (stats.currentStreak > 0) "Current streak" else "Total plays"
    val streakSubtitle = when {
        stats.currentStreak > 0 && !stats.listenedToday -> "Listen today to keep going"
        stats.currentStreak > 0 -> "Best ${stats.longestStreak}d · ${stats.totalPlays} plays"
        stats.longestStreak > 0 -> "Best streak ${stats.longestStreak}d"
        else -> "${stats.distinctSongs} songs heard"
    }

    val tile1A11y = "$timeLabel, ${fmtSpokenTime(primaryMs)}, opens stats"
    val tile2A11y = if (stats.currentStreak > 0) {
        "Current streak, ${stats.currentStreak} days, $streakSubtitle, opens stats"
    } else {
        "Total plays, ${stats.totalPlays}, $streakSubtitle, opens stats"
    }

    val tileShape = appShape(26.dp, CornerArea.Cards)
    val accentBg = if (modern) {
        lerp(tokens.cardBgElevated, scheme.primaryContainer, if (tokens.dark) 0.28f else 0.36f)
    } else {
        scheme.surfaceContainerLow
    }

    if (largeFont) {
        Column(modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            ProfileBigStatTile(
                title = timeLabel,
                bigValue = fmtCompactTime(shownMs),
                subtitle = timeSubtitle,
                icon = Icons.Rounded.BarChart,
                a11yLabel = tile1A11y,
                modern = modern,
                fillOverride = if (modern) accentBg else null,
                shape = tileShape,
                onClick = onOpenStats,
                modifier = Modifier.fillMaxWidth(),
            )
            ProfileBigStatTile(
                title = streakLabel,
                bigValue = streakBig,
                subtitle = streakSubtitle,
                icon = Icons.Rounded.LocalFireDepartment,
                a11yLabel = tile2A11y,
                modern = modern,
                fillOverride = null,
                shape = tileShape,
                onClick = onOpenStats,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    } else {
        Row(modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ProfileBigStatTile(
                title = timeLabel,
                bigValue = fmtCompactTime(shownMs),
                subtitle = timeSubtitle,
                icon = Icons.Rounded.BarChart,
                a11yLabel = tile1A11y,
                modern = modern,
                fillOverride = if (modern) accentBg else null,
                shape = tileShape,
                onClick = onOpenStats,
                modifier = Modifier.weight(1f),
            )
            ProfileBigStatTile(
                title = streakLabel,
                bigValue = streakBig,
                subtitle = streakSubtitle,
                icon = Icons.Rounded.LocalFireDepartment,
                a11yLabel = tile2A11y,
                modern = modern,
                fillOverride = null,
                shape = tileShape,
                onClick = onOpenStats,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun ProfileBigStatTile(
    title: String,
    bigValue: String,
    subtitle: String,
    icon: ImageVector,
    a11yLabel: String,
    modern: Boolean,
    fillOverride: Color?,
    shape: Shape,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val press = remember { MutableInteractionSource() }
    val surfaceMod = if (modern) {
        modernSurfaceStatic(fillOverride ?: tokens.cardBg, shape)
    } else {
        Modifier.partSurface(LookGroup.Cards, scheme.surfaceContainerLow, shape)
    }
    Column(
        modifier
            .defaultMinSize(minHeight = 116.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .then(surfaceMod)
            .clickable(
                interactionSource = press,
                indication = androidx.compose.foundation.LocalIndication.current,
                onClick = onClick,
            )
            .semantics(mergeDescendants = true) { contentDescription = a11yLabel }
            .padding(16.dp),
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelLarge,
                color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            AppIcon(
                icon,
                null,
                Modifier.size(18.dp),
                tint = if (modern) tokens.accentOnGlass else scheme.primary,
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = bigValue,
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
            text = subtitle,
            style = MaterialTheme.typography.bodySmall,
            color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun ProfileStatsSkeleton(modern: Boolean, modifier: Modifier = Modifier) {
    val shape = appShape(26.dp, CornerArea.Cards)
    Row(
        modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.weight(1f).height(116.dp).skeleton(shape))
        Box(Modifier.weight(1f).height(116.dp).skeleton(shape))
    }
}

@Composable
private fun ProfileStatsEmptyCard(
    onStartListening: () -> Unit,
    onOpenStats: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    ProfileSurfaceCard(modifier.padding(horizontal = 16.dp)) {
        Column(
            Modifier.fillMaxWidth().padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Box(
                    Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(if (modern) tokens.chipBg else scheme.primaryContainer),
                    contentAlignment = Alignment.Center,
                ) {
                    AppIcon(
                        Icons.Rounded.Insights,
                        null,
                        Modifier.size(20.dp),
                        tint = if (modern) tokens.accentOnGlass else scheme.onPrimaryContainer,
                    )
                }
                Column(Modifier.weight(1f)) {
                    Text(
                        "No listening history yet",
                        style = if (modern) {
                            MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold)
                        } else {
                            MaterialTheme.typography.titleMedium
                        },
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                    )
                    Text(
                        "Play a few songs and your listening time, streaks, and stats will show up here.",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = onStartListening,
                    shape = appShape(50.dp, CornerArea.Chips),
                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                ) {
                    AppIcon(Icons.Rounded.PlayArrow, null, Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Start listening")
                }
                TextButton(
                    onClick = onOpenStats,
                    shape = appShape(50.dp, CornerArea.Chips),
                    modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                ) {
                    Text("View stats")
                }
            }
        }
    }
}

@Composable
private fun ProfileStatsErrorCard(
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    ProfileSurfaceCard(modifier.padding(horizontal = 16.dp)) {
        Row(
            Modifier.fillMaxWidth().padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            AppIcon(
                Icons.Rounded.ErrorOutline,
                null,
                Modifier.size(24.dp),
                tint = if (modern) tokens.accentOnGlass else scheme.error,
            )
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    "Could not load stats",
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
private fun ProfileQuickActionsSection(
    runningTasks: Int,
    hasScan: Boolean,
    onAccount: () -> Unit,
    onTasks: () -> Unit,
    onScan: () -> Unit,
    onUpload: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val outer = 24.dp
    val inner = 10.dp
    val topStartShape = if (modern) RoundedCornerShape(topStart = outer, topEnd = inner, bottomStart = inner, bottomEnd = inner) else appShape(20.dp)
    val topEndShape = if (modern) RoundedCornerShape(topStart = inner, topEnd = outer, bottomStart = inner, bottomEnd = inner) else appShape(20.dp)
    val bottomStartShape = if (modern) RoundedCornerShape(topStart = inner, topEnd = inner, bottomStart = outer, bottomEnd = inner) else appShape(20.dp)
    val bottomEndShape = if (modern) RoundedCornerShape(topStart = inner, topEnd = inner, bottomStart = inner, bottomEnd = outer) else appShape(20.dp)
    val gap = if (modern) 6.dp else 10.dp

    val taskBadge = when {
        runningTasks > 0 -> "$runningTasks active"
        hasScan -> "Active"
        else -> null
    }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        ProfileSectionHeader("Quick actions")
        Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(gap)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(gap)) {
                ProfileQuickActionTile(
                    label = "Account",
                    icon = Icons.Rounded.AccountCircle,
                    shape = topStartShape,
                    onClick = onAccount,
                    modifier = Modifier.weight(1f),
                )
                ProfileQuickActionTile(
                    label = "Tasks",
                    badge = taskBadge,
                    icon = Icons.Rounded.TaskAlt,
                    shape = topEndShape,
                    onClick = onTasks,
                    modifier = Modifier.weight(1f),
                )
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(gap)) {
                ProfileQuickActionTile(
                    label = "Scan library",
                    icon = Icons.Rounded.Sync,
                    shape = bottomStartShape,
                    onClick = onScan,
                    modifier = Modifier.weight(1f),
                )
                ProfileQuickActionTile(
                    label = "Upload songs",
                    icon = Icons.Rounded.Upload,
                    shape = bottomEndShape,
                    onClick = onUpload,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun ProfileQuickActionTile(
    label: String,
    icon: ImageVector,
    shape: Shape,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    badge: String? = null,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    val press = remember { MutableInteractionSource() }
    val surfaceMod = if (modern) {
        modernSurfaceStatic(tokens.cardBgElevated, shape)
    } else {
        Modifier.partSurface(LookGroup.Cards, scheme.surfaceContainerLow, shape)
    }
    Row(
        modifier
            .defaultMinSize(minHeight = 56.dp)
            .pressScale(press, Motion.Micro.CardPressScale)
            .then(surfaceMod)
            .clickable(
                interactionSource = press,
                indication = androidx.compose.foundation.LocalIndication.current,
                onClick = onClick,
            )
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(
            Modifier
                .size(34.dp)
                .clip(appShape(12.dp, CornerArea.Chips))
                .background(if (modern) tokens.chipBg else scheme.primaryContainer),
            contentAlignment = Alignment.Center,
        ) {
            AppIcon(
                icon,
                null,
                Modifier.size(18.dp),
                tint = if (modern) tokens.accentOnGlass else scheme.onPrimaryContainer,
            )
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = label,
                style = if (modern) {
                    MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold)
                } else {
                    MaterialTheme.typography.titleSmall
                },
                color = if (modern) tokens.onGlass else scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (badge != null) {
                Text(
                    text = badge,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (modern) tokens.accentOnGlass else scheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun ProfileSectionHeader(title: String) {
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
private fun ProfileIconRow(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 60.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            Modifier
                .size(38.dp)
                .clip(appShape(12.dp, CornerArea.Chips))
                .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh),
            contentAlignment = Alignment.Center,
        ) {
            AppIcon(
                icon,
                null,
                Modifier.size(20.dp),
                tint = if (modern) tokens.accentOnGlass else scheme.primary,
            )
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                color = if (modern) tokens.onGlass else scheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        AppIcon(
            Icons.Rounded.ChevronRight,
            null,
            tint = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun ProfileRowDivider(modern: Boolean) {
    if (modern) {
        Spacer(Modifier.height(2.dp))
    } else {
        RowDivider()
    }
}

@Composable
private fun ProfileAboutCard(updates: UpdateService, onOpen: () -> Unit) {
    val tokens = LocalModernTokens.current
    val modern = tokens.enabled
    val scheme = MaterialTheme.colorScheme
    val state by updates.state.collectAsState()
    val available = (state as? UpdateState.Available)?.release?.version

    ProfileSurfaceCard(Modifier.padding(horizontal = 16.dp)) {
        Row(
            Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = 68.dp)
                .clickable(onClickLabel = "Open About", onClick = onOpen)
                .semantics(mergeDescendants = true) {
                    contentDescription = "Paper Play version ${updates.installed}, opens about"
                }
                .padding(horizontal = 18.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            StaticLogo(size = 36.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        "Paper Play",
                        style = if (modern) {
                            MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold)
                        } else {
                            MaterialTheme.typography.titleMedium
                        },
                        color = if (modern) tokens.onGlass else scheme.onSurface,
                    )
                    Box(
                        Modifier
                            .clip(appShape(50.dp, CornerArea.Chips))
                            .background(if (modern) tokens.chipBg else scheme.surfaceContainerHigh)
                            .padding(horizontal = 8.dp, vertical = 2.dp),
                    ) {
                        Text(
                            if (updates.prefs.beta) "Beta" else "Stable",
                            style = MaterialTheme.typography.labelSmall,
                            color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                        )
                    }
                }
                Text(
                    "Version ${updates.installed}",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
                )
                if (available != null) {
                    Text(
                        "Update $available available",
                        style = MaterialTheme.typography.labelMedium,
                        color = if (modern) tokens.accentOnGlass else scheme.primary,
                    )
                }
            }
            AppIcon(
                Icons.Rounded.ChevronRight,
                null,
                tint = if (modern) tokens.onGlassMuted else scheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Modifier.profileStaggerIn(order: Int): Modifier {
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

@Preview(name = "Android Profile Empty - Modern Dark", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun AndroidProfileEmptyModernPreview() {
    PaperPlayTheme(dark = true, uiStyle = UiStyle.Modern) {
        Column(Modifier.background(Color(0xFF121318)).padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            ProfileStatsEmptyCard(onStartListening = {}, onOpenStats = {})
            ProfileStatsSkeleton(modern = true)
        }
    }
}

@Preview(name = "Android Profile Long Name - Modern Light", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun AndroidProfileLongNameLightPreview() {
    PaperPlayTheme(dark = false, uiStyle = UiStyle.Modern) {
        val prefs = UiPrefs({ k -> if (k == "profile_name") "Alexandria Montgomery-Fitzwilliam III" else null }, { _, _ -> })
        Box(Modifier.background(Color(0xFFEBEFF7)).padding(vertical = 16.dp)) {
            ProfileIdentityCard(
                prefs = prefs,
                songs = 348,
                favorites = 19,
                playlists = 4,
                topArtist = "This week · HWASA",
                onEditProfile = {},
                onLibraryTab = {},
                onOpenStats = {},
            )
        }
    }
}
