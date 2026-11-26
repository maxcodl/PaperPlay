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
    // Phone and PC share one profile page; a wide window lays it out in two columns.
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


@Preview(name = "Section", showBackground = true)
@Composable
private fun ProfileSectionPreview() = io.max.paperplay.ui.PreviewFrame {
    ProfileSection("preview", "Account", androidx.compose.material.icons.Icons.Rounded.Person, io.max.paperplay.ui.previewPrefs(), defaultOpen = true) {
        Text("Section content", Modifier.padding(20.dp))
    }
}
