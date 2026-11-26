package io.max.paperplay.ui.app

import io.max.paperplay.ui.components.AppIcon

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.material.icons.rounded.DriveFileMove
import androidx.compose.material.icons.rounded.Upload
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.CleaningServices
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Devices
import androidx.compose.material.icons.rounded.Rule
import androidx.compose.material.icons.rounded.SettingsEthernet
import androidx.compose.material.icons.rounded.Storage
import androidx.compose.material.icons.rounded.ExpandLess
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Forum
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlaylistPlay
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Full-width page header with no box behind it. */
/** The top bar of a page: plain on Material, a glass bar when the Top bars part is set to Glass on the Appearance page. */
@Composable
fun Modifier.barSurface(): Modifier =
    if (!glassLook(LookGroup.Bars)) fillMaxWidth()
    else fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp).partSurface(LookGroup.Bars, MaterialTheme.colorScheme.surfaceContainerLow, appShape(20.dp))

/** Large title with actions on the right, like the Flutter top bars. */
@Composable
fun TopBar(title: String, modifier: Modifier = Modifier, actions: @Composable () -> Unit = {}) {
    Row(modifier.barSurface().padding(start = 16.dp, end = 8.dp, top = 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f), style = MaterialTheme.typography.headlineMedium)
        actions()
    }
}

@Composable
fun ProfileScreen(
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
    /** How many background tasks are running (song info, covers, uploads and so on), for the Tasks row. */
    runningTasks: Int = 0,
    updates: io.max.paperplay.core.update.UpdateService? = null,
    backend: CoreBackend? = null,
    recents: List<io.max.paperplay.ui.state.SongUi> = emptyList(),
    onPlay: (List<io.max.paperplay.ui.state.SongUi>, Int) -> Unit = { _, _ -> },
) {
    if (io.max.paperplay.ui.isPhone) {
        AndroidProfileScreen(
            songs = songs,
            favorites = favorites,
            playlists = playlists,
            conn = conn,
            prefs = prefs,
            mainChatTitle = mainChatTitle,
            onSettings = onSettings,
            onTasks = onTasks,
            onLibraryTab = onLibraryTab,
            bottomPadding = bottomPadding,
            modifier = modifier,
            scan = scan,
            runningTasks = runningTasks,
            updates = updates,
            backend = backend,
        )
        return
    }
    var stats by androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateOf<ProfileStats?>(null) }
    androidx.compose.runtime.LaunchedEffect(backend) {
        // Also after a sync brought another device's listening; at most every 2 s while the library changes.
        backend?.services?.library?.changes?.collect {
            stats = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) { backend.profileStats() }
            kotlinx.coroutines.delay(2_000)
        }
    }
    LazyColumn(modifier, contentPadding = PaddingValues(bottom = bottomPadding + 32.dp)) {
        item {
            TopBar("Profile") { IconButton({ onSettings(null) }) { AppIcon(Icons.Rounded.Settings, "Settings") } }
        }
        item {
            Column(
                Modifier.padding(horizontal = 16.dp).fillMaxWidth()
                    .partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, appShape(36.dp)),
            ) {
                Column(
                    Modifier.fillMaxWidth().clickable { onSettings("profile") }.padding(top = 28.dp, bottom = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Avatar(prefs.profilePhoto, prefs.profileName, 112.dp)
                    Text(prefs.profileName, Modifier.padding(top = 12.dp), style = MaterialTheme.typography.headlineMedium)
                }
                Row(Modifier.fillMaxWidth().padding(start = 8.dp, end = 8.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Stat(Icons.Rounded.MusicNote, songs, "Songs", Modifier.weight(1f)) { onLibraryTab(0) }
                    StatDivider()
                    Stat(Icons.Rounded.Favorite, favorites, "Favorites", Modifier.weight(1f)) { onLibraryTab(4) }
                    StatDivider()
                    Stat(Icons.Rounded.PlaylistPlay, playlists, "Playlists", Modifier.weight(1f)) { onLibraryTab(3) }
                }
            }
        }
        if (backend != null) item { ListeningSection(stats, recents, prefs, onPlay) { onSettings("stats") } }
        item {
            ProfileSection("library", "Library", Icons.Rounded.LibraryMusic, prefs) {
                NavRow(if (conn.chats.size == 1) "1 channel" else "${conn.chats.size} channels", icon = Icons.Rounded.Forum, subtitle = mainChatTitle?.let { "Main chat: $it" } ?: "No chat added yet") {
                    onSettings("channels")
                }
                NavRow("Scan library", icon = Icons.Rounded.Sync, subtitle = "Read the chats with the bots and account you pick") { onSettings("repair") }
                NavRow("Tasks", icon = Icons.Rounded.TaskAlt, subtitle = scan?.value?.text ?: if (runningTasks > 0) "$runningTasks running" else "Nothing running", onClick = onTasks)
                NavRow("Upload songs", icon = Icons.Rounded.Upload, subtitle = "Send songs or a folder to a chat, with speed and queue") { onSettings("uploadhub") }
                NavRow("Duplicates", icon = Icons.Rounded.ContentCopy, subtitle = "Find repeated songs and remove the extras") { onSettings("dupes") }
                NavRow("Song info left", icon = Icons.Rounded.Rule, subtitle = "See which songs still lack info or a cover") { onSettings("missing") }
            }
        }
        item {
            ProfileSection("devices", "Devices and storage", Icons.Rounded.Devices, prefs) {
                NavRow("Connection", icon = Icons.Rounded.SettingsEthernet, subtitle = "Telegram status, devices on this network, pairing") {
                    onSettings("conn")
                }
                NavRow("Network play", icon = Icons.Rounded.Devices, subtitle = "Listen together with people on the same network") { onSettings("netplay") }
                NavRow("Cache and backup", icon = Icons.Rounded.CleaningServices, subtitle = "Manage cached songs and library backups") {
                    onSettings("storage")
                }
            }
        }
        if (updates != null) item { AboutCard(updates) { onSettings("about") } }
    }
}

/** The end of Profile: the app, its version and channel, a note when an update is waiting, and the maker's line. Tapping opens Settings > About. */
@Composable
private fun AboutCard(updates: io.max.paperplay.core.update.UpdateService, onOpen: () -> Unit) {
    val state by updates.state.collectAsState()
    val available = (state as? io.max.paperplay.core.update.UpdateState.Available)?.release?.version
    Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth()) {
        Row(
            Modifier.fillMaxWidth().partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, appShape(28.dp))
                .clickable(onClickLabel = "Open About", onClick = onOpen).padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            io.max.paperplay.ui.StaticLogo(size = 28.dp)
            Column(Modifier.weight(1f).padding(horizontal = 16.dp)) {
                Text("Paper Play", style = MaterialTheme.typography.titleLarge)
                Text(
                    "Version ${updates.installed} · ${if (updates.prefs.beta) "Beta" else "Stable"} updates",
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (available != null) Text("Update $available available", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.primary)
            }
            AppIcon(Icons.Rounded.ChevronRight, null)
        }
        MadeBy()
    }
}

@Composable
private fun StatDivider() {
    Box(Modifier.width(1.dp).height(40.dp).background(MaterialTheme.colorScheme.outlineVariant))
}

/** A count with a small icon above it and its label below; sits in the identity card, not in a box of its own. */
@Composable
private fun Stat(icon: ImageVector, n: Int, label: String, modifier: Modifier, onClick: () -> Unit) {
    Column(
        modifier.clip(appShape(20.dp)).clickable(onClick = onClick).padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        AppIcon(icon, null, Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
        Text("$n", Modifier.padding(top = 4.dp), style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** A card whose body folds away. It always starts collapsed; the state is not saved. */
@Composable
internal fun ProfileSection(
    key: String, title: String, icon: ImageVector, prefs: UiPrefs, defaultOpen: Boolean = false,
    content: @Composable () -> Unit,
) {
    var open by androidx.compose.runtime.remember(key) { androidx.compose.runtime.mutableStateOf(defaultOpen) }
    Column(
        Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth()
            .partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, appShape(28.dp))
            .animateContentSize(io.max.paperplay.ui.theme.motionSpatialSpring()),
    ) {
        val state = if (open) "Expanded" else "Collapsed"
        Row(
            Modifier.fillMaxWidth()
                .clickable(onClickLabel = if (open) "Collapse $title" else "Expand $title") { open = !open }
                .semantics(mergeDescendants = true) { stateDescription = state }
                .padding(20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AppIcon(icon, null, Modifier.padding(end = 16.dp))
            Text(title, Modifier.weight(1f), style = MaterialTheme.typography.titleLarge)
            AppIcon(if (open) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, if (open) "Collapse $title" else "Expand $title")
        }
        if (open) content()
    }
}

@Preview
@Composable
private fun TopBarPreview() {
    TopBar(title = "Profile")
}

@Preview
@Composable
private fun ProfileScreenPreview() {
    val dummyConn = ConnectionUi(ready = true, state = "Connected")
    val dummyPrefs = UiPrefs({ null }, { _, _ -> })
    ProfileScreen(
        songs = 120,
        favorites = 15,
        playlists = 3,
        conn = dummyConn,
        prefs = dummyPrefs,
        mainChatTitle = null,
        onSettings = {},
        onTasks = {},
        onLibraryTab = {},
        bottomPadding = 0.dp,
    )
}


@Preview(name = "Stat", showBackground = true)
@Composable
private fun StatPreview() = io.max.paperplay.ui.PreviewFrame {
    Stat(androidx.compose.material.icons.Icons.Rounded.MusicNote, 120, "Songs", Modifier, onClick = {})
}

@Preview(name = "Section", showBackground = true)
@Composable
private fun ProfileSectionPreview() = io.max.paperplay.ui.PreviewFrame {
    ProfileSection("preview", "Account", androidx.compose.material.icons.Icons.Rounded.Person, io.max.paperplay.ui.previewPrefs(), defaultOpen = true) {
        Text("Section content", Modifier.padding(20.dp))
    }
}
