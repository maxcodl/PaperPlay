package io.max.paperplay.ui.app

import io.max.paperplay.ui.theme.motionItem
import io.max.paperplay.ui.components.AppIcon

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.widthIn
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Sort
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.automirrored.rounded.PlaylistAdd
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material3.AssistChip
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.SongRow
import io.max.paperplay.ui.logic.Selection
import io.max.paperplay.ui.logic.SongSort
import io.max.paperplay.ui.logic.filterSongs
import io.max.paperplay.ui.logic.sortSongs
import io.max.paperplay.ui.state.SongActions
import io.max.paperplay.ui.state.SongUi

/** The shell's list actions, for pages (such as Settings pages) that show songs. */
/** The colour at the top of the page behind the content, so pinned bars can match it instead of showing plain black. */
internal val LocalPageTop = androidx.compose.runtime.staticCompositionLocalOf<androidx.compose.runtime.State<androidx.compose.ui.graphics.Color>?> { null }

val LocalListActions = androidx.compose.runtime.staticCompositionLocalOf<ListActions?> { null }

/** Topics of the main chat and starred channels, as lists to show beside the playlists. Empty where there are none. */
/** The album and artist lists, built only while a screen collects them. */
internal val LocalAlbums = androidx.compose.runtime.staticCompositionLocalOf<kotlinx.coroutines.flow.StateFlow<List<io.max.paperplay.ui.state.GroupUi>>> { kotlinx.coroutines.flow.MutableStateFlow(emptyList()) }
internal val LocalArtists = androidx.compose.runtime.staticCompositionLocalOf<kotlinx.coroutines.flow.StateFlow<List<io.max.paperplay.ui.state.GroupUi>>> { kotlinx.coroutines.flow.MutableStateFlow(emptyList()) }

/** The chats of the account's chat index, for the library lists, and how to open one (its paged songs page). */
internal class IndexedChats(
    val chats: kotlinx.coroutines.flow.StateFlow<List<io.max.paperplay.core.account.IndexedChat>>,
    val open: (io.max.paperplay.core.account.IndexedChat) -> Unit,
    /** Posts of every indexed chat matching a search, best first. Reads the database: call off the main thread. */
    val search: (query: String, limit: Int) -> List<io.max.paperplay.core.account.ChatPost> = { _, _ -> emptyList() },
    /** Opens a chat's songs page with a search already typed. */
    val openSearch: (chatId: Long, query: String) -> Unit = { _, _ -> },
    /** The tiny cover Telegram keeps in a post. Reads the database: call off the main thread. */
    val thumb: (chatId: Long, messageId: Long) -> ByteArray? = { _, _ -> null },
    /** Plays a post without adding it to the library. */
    val play: (io.max.paperplay.core.account.ChatPost) -> Unit = {},
    /** Whether the song is playing from the index and not in the library, and a way to copy it to the main chat. */
    val isPreview: (String) -> Boolean = { false },
    val copyPreview: suspend (String) -> String = { "" },
)
internal val LocalIndexedChats = androidx.compose.runtime.staticCompositionLocalOf<IndexedChats?> { null }

internal val LocalTelegramLists = androidx.compose.runtime.staticCompositionLocalOf<() -> List<CoreBackend.TelegramList>> { { emptyList() } }

/** What a list of songs can do; the shell provides one. */
class ListActions(
    val play: (List<SongUi>, Int) -> Unit,
    val shuffle: (List<SongUi>) -> Unit,
    val setFavorite: (SongUi, Boolean) -> Unit,
    val addToPlaylist: (Set<String>) -> Unit,
    val notice: (String) -> Unit,
    val playNext: (SongUi) -> Unit = {},
    val telegramLink: (SongUi) -> String? = { null },
    val findMetadata: (SongUi) -> Unit = {},
    val editTags: (SongUi) -> Unit = {},
    val changeCover: (SongUi) -> Unit = {},
    val setPinned: (SongUi, Boolean) -> Unit = { _, _ -> },
    val deleteSong: (SongUi) -> Unit = {},
    val deleteSongs: (List<SongUi>) -> Unit = {},
    /** Copies songs into the main chat, so the bots can read them. */
    val copyToChat: (List<SongUi>) -> Unit = {},
)

internal fun ListActions.rowActions(onRemove: ((SongUi) -> Unit)? = null) = object : SongActions {
    override val removeLabel: String? get() = if (onRemove != null) "Remove from playlist" else null
    override fun remove(song: SongUi) { onRemove?.invoke(song) }
    override fun play(songs: List<SongUi>, index: Int) = this@rowActions.play(songs, index)
    override fun playNext(song: SongUi) = this@rowActions.playNext(song)
    override fun setFavorite(song: SongUi, favorite: Boolean) = this@rowActions.setFavorite(song, favorite)
    override fun setPinned(song: SongUi, pinned: Boolean) { this@rowActions.setPinned(song, pinned); notice(if (pinned) "Keeping on this device" else "No longer kept on this device") }
    override fun addToPlaylist(song: SongUi) = this@rowActions.addToPlaylist(setOf(song.id))
    override fun deleteFromTelegram(song: SongUi) = this@rowActions.deleteSong(song)
    override fun telegramLink(song: SongUi): String? = this@rowActions.telegramLink(song)
    override fun notice(text: String) = this@rowActions.notice(text)
    override fun findMetadata(song: SongUi) = this@rowActions.findMetadata(song)
    override fun editTags(song: SongUi) = this@rowActions.editTags(song)
    override fun changeCover(song: SongUi) = this@rowActions.changeCover(song)
}

/**
 * A song list with search, sort, play and shuffle, and multi-select.
 * [sortable] off keeps the given order (a playlist or album has its own).
 */
@OptIn(ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun SongList(
    songs: List<SongUi>,
    currentId: String?,
    actions: ListActions,
    modifier: Modifier = Modifier,
    bottomPadding: Dp = 0.dp,
    sortable: Boolean = true,
    searchable: Boolean = true,
    header: (@Composable () -> Unit)? = null,
    onRemove: ((SongUi) -> Unit)? = null,
    empty: String = "No songs here yet.",
    /** Names this list so its sort order is remembered for it alone; null uses the shared order. */
    listKey: String? = null,
    /** Songs the list wants but the library does not have: shown greyed out after the songs, tapping one opens it in Spotify. */
    ghosts: List<GhostSong> = emptyList(),
    /** True when [songs] are in the order the ghosts were placed for (a playlist's own order), so each ghost goes where its song belongs. */
    ghostsInline: Boolean = false,
) {
    var query by remember { mutableStateOf("") }
    // The sort is remembered between lists and launches.
    val uiPrefs = LocalUiPrefs.current
    val savedSort = listKey?.let { uiPrefs?.getString("list_sort:$it") }
    var sort by remember(listKey) { mutableStateOf(SongSort.entries.firstOrNull { it.name == savedSort?.substringBefore(':') } ?: uiPrefs?.songSort ?: SongSort.Added) }
    var reverse by remember(listKey) { mutableStateOf(if (savedSort != null) savedSort.substringAfter(':') == "true" else uiPrefs?.songSortReverse ?: false) }
    var selection by remember { mutableStateOf(Selection()) }
    var sortSheet by remember { mutableStateOf(false) }
    var onlyUnreachable by remember(listKey) { mutableStateOf(false) }
    var confirmBulkDelete by remember { mutableStateOf(false) }

    val shown = remember(songs, query, sort, reverse, sortable, onlyUnreachable) {
        val found = filterSongs(if (onlyUnreachable) songs.filter { it.botCantReach } else songs, query)
        if (sortable) sortSongs(found, sort, reverse) else found
    }
    val rowActions = remember(actions, onRemove) { actions.rowActions(onRemove) }
    val picked = remember(selection, songs) { if (selection.ids.isEmpty()) selection else selection.retain(songs.mapTo(HashSet()) { it.rowKey }) }

    val songCovers = remember(shown) {
        val map = mutableMapOf<String, String>()
        shown.forEach { song ->
            val uri = song.coverUri
            if (!uri.isNullOrBlank()) {
                if (song.album.isNotBlank()) map.putIfAbsent("album:${song.album}", uri)
                if (song.artist.isNotBlank()) map.putIfAbsent("artist:${song.artist}", uri)
            }
        }
        map
    }

    Column(modifier) {
        if (picked.active) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 6.dp),
                shape = appShape(16.dp),
                color = MaterialTheme.colorScheme.secondaryContainer,
                tonalElevation = if (io.max.paperplay.ui.theme.LocalModernTokens.current.enabled) 0.dp else 2.dp,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text(
                        text = "${picked.size} picked",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSecondaryContainer,
                        modifier = Modifier
                            .weight(1f)
                            .padding(start = 12.dp),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    IconButton(onClick = {
                        actions.play(shown.filter { it.rowKey in picked }, 0)
                        selection = Selection()
                    }) { AppIcon(Icons.Rounded.PlayArrow, "Play picked") }
                    IconButton(onClick = {
                        actions.addToPlaylist(shown.filter { it.rowKey in picked }.mapTo(LinkedHashSet()) { it.id })
                        selection = Selection()
                    }) { AppIcon(Icons.AutoMirrored.Rounded.PlaylistAdd, "Add to playlist") }
                    IconButton(onClick = {
                        val songsPicked = shown.filter { it.rowKey in picked }
                        val makeFavorite = songsPicked.any { !it.favorite }
                        songsPicked.forEach { actions.setFavorite(it, makeFavorite) }
                        selection = Selection()
                    }) { AppIcon(Icons.Rounded.FavoriteBorder, "Favorite picked") }
                    IconButton(onClick = {
                        actions.copyToChat(shown.filter { it.rowKey in picked })
                        selection = Selection()
                    }) { AppIcon(Icons.Rounded.ContentCopy, "Copy to chat") }
                    IconButton(onClick = {
                        // Only repeats picked: nothing to confirm, the action says where those are deleted.
                        if (deletableRows(shown, picked).isEmpty()) { actions.deleteSongs(shown.filter { it.rowKey in picked }); selection = Selection() }
                        else confirmBulkDelete = true
                    }) {
                        AppIcon(Icons.Rounded.Delete, "Delete from Telegram", tint = MaterialTheme.colorScheme.error)
                    }
                    IconButton(onClick = { selection = Selection() }) {
                        AppIcon(Icons.Rounded.Close, "Clear selection")
                    }
                }
            }
        } else if (searchable) {
            PillField(
                value = query,
                onChange = { query = it },
                hint = "Search songs, artists, albums, years",
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
            )
        }

        val listState = androidx.compose.foundation.lazy.rememberLazyListState()
        val barIndex = if (header != null) 1 else 0
        // Pinned means rows scroll under the bar. At its natural place it stays see-through, so the page colour shows.
        val pinned by androidx.compose.runtime.remember(barIndex) {
            androidx.compose.runtime.derivedStateOf { listState.firstVisibleItemIndex > barIndex || (listState.firstVisibleItemIndex == barIndex && listState.firstVisibleItemScrollOffset > 0) }
        }
        val pageTop = LocalPageTop.current
        val base = MaterialTheme.colorScheme.background
        // On desktop the list sits on a card, not the page gradient, so the pinned bar takes the card colour.
        val cardFill = MaterialTheme.colorScheme.surfaceContainerLow
        DesktopScrollHost(listState, Modifier.weight(1f)) { scrollMod ->
            LazyColumn(
                state = listState,
                modifier = scrollMod,
                // Horizontal insets live on the items, so the pinned bar can span the full width and hide rows fully.
                contentPadding = PaddingValues(bottom = bottomPadding + 16.dp),
            ) {
            // A Column, not a Box: the header can hold several parts (cover, then the missing-songs row) that stack down.
            if (header != null) item { Column(Modifier.padding(horizontal = 16.dp)) { header() } }
            if (shown.isNotEmpty()) stickyHeader(key = "song-list-bar") {
                val mins = shown.sumOf { it.durationSec } / 60
                val summary = "${shown.size} ${if (shown.size == 1) "song" else "songs"} · " +
                    if (mins >= 60) "${mins / 60} hr ${mins % 60} min" else "$mins min"
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .drawBehind { if (pinned) drawRect(if (io.max.paperplay.ui.isPhone) pageTop?.value ?: base else cardFill) }
                        .padding(start = 16.dp, end = 12.dp, top = 6.dp, bottom = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilledIconButton(
                        onClick = { actions.play(shown, 0) },
                        modifier = Modifier.size(44.dp),
                        shape = CircleShape,
                    ) { AppIcon(Icons.Rounded.PlayArrow, contentDescription = "Play all") }
                    FilledTonalIconButton(
                        onClick = { actions.shuffle(shown) },
                        modifier = Modifier.size(44.dp),
                        shape = CircleShape,
                    ) { AppIcon(Icons.Rounded.Shuffle, contentDescription = "Shuffle all", modifier = Modifier.size(20.dp)) }
                    Text(
                        text = summary,
                        modifier = Modifier.weight(1f).padding(start = 4.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (sortable) {
                        // Icon only; the order itself shows in the sheet that opens, and is remembered.
                        IconButton(onClick = { sortSheet = true }) {
                            AppIcon(Icons.AutoMirrored.Rounded.Sort, contentDescription = "Sort: ${sort.label}")
                        }
                    }
                }
            }
            if (shown.isEmpty()) item {
                Surface(
                    shape = appShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Text(
                        text = if (query.isNotBlank()) "No songs match \"${query.trim()}\"." else empty,
                        modifier = Modifier.padding(24.dp),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            val songRow: @Composable androidx.compose.foundation.lazy.LazyItemScope.(SongUi, Int) -> Unit = { song, i ->
                val songCoverUri = song.coverUri
                    ?: (if (song.album.isNotBlank()) songCovers["album:${song.album}"] else null)
                    ?: (if (song.artist.isNotBlank()) songCovers["artist:${song.artist}"] else null)
                SongRow(
                    song = song,
                    onClick = { if (picked.active) selection = picked.toggle(song.rowKey) else actions.play(shown, i) },
                    onLongClick = { selection = picked.toggle(song.rowKey) },
                    current = song.id == currentId,
                    selected = song.rowKey in picked,
                    coverUriOverride = songCoverUri,
                    actions = if (picked.active) null else rowActions,
                    modifier = motionItem().padding(start = 16.dp, end = 16.dp, bottom = 6.dp),
                )
            }
            // The songs the list wants but the library lacks sit where they belong in the order, greyed out. When the list is sorted or
            // searched, that place no longer means anything, so they are gathered after the songs instead.
            val inline = ghosts.isNotEmpty() && ghostsInline && query.isBlank()
            if (inline) {
                val before = ghosts.groupBy { it.after.coerceIn(0, shown.size) }
                for (i in 0..shown.size) {
                    before[i]?.forEach { g -> item(key = "ghost:${g.key}") { GhostRow(g, Modifier.padding(horizontal = 16.dp, vertical = 3.dp)) } }
                    if (i < shown.size) { val song = shown[i]; item(key = song.copyKey ?: song.id) { songRow(song, i) } }
                }
            } else {
                itemsIndexed(shown, key = { _, s -> s.copyKey ?: s.id }) { i, song -> songRow(song, i) }
            }
            // While searching, the ghosts that match are gathered after the songs (their place in the order means nothing for a result list).
            val tail = if (query.isBlank()) ghosts else ghosts.filter { it.title.contains(query.trim(), ignoreCase = true) || it.artist.contains(query.trim(), ignoreCase = true) }
            if (tail.isNotEmpty() && !inline) {
                item(key = "ghost-header") {
                    Text(
                        "Not in your library (${tail.size})", Modifier.padding(start = 20.dp, top = 16.dp, bottom = 6.dp),
                        style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                items(tail, key = { "ghost:${it.key}" }) { g -> GhostRow(g, Modifier.padding(horizontal = 16.dp, vertical = 3.dp)) }
            }
            }
        }
        if (confirmBulkDelete) androidx.compose.material3.AlertDialog(
            onDismissRequest = { confirmBulkDelete = false },
            title = { deletableRows(shown, picked).size.let { n -> Text("Delete $n ${if (n == 1) "song" else "songs"} from Telegram?") } },
            text = {
                val onlyLocal = deletableRows(shown, picked).all { it.botCantReach }
                Text(
                    if (onlyLocal) "They are only in this library, not in Telegram, so nothing is deleted there. This cannot be undone."
                    else "They are removed from your main chat and from this library. Repeats of the same files in that chat go too. Progress shows on the Tasks page. This cannot be undone.",
                )
            },
            confirmButton = {
                TextButton({
                    confirmBulkDelete = false
                    actions.deleteSongs(shown.filter { it.rowKey in picked })
                    selection = Selection()
                }) { Text("Delete") }
            },
            dismissButton = { TextButton({ confirmBulkDelete = false }) { Text("Cancel") } },
        )
        if (sortSheet) {
            ModalBottomSheet(onDismissRequest = { sortSheet = false }) {
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Text("Filter", style = MaterialTheme.typography.titleLarge)
                    androidx.compose.material3.FilterChip(
                        selected = onlyUnreachable,
                        onClick = { onlyUnreachable = !onlyUnreachable; sortSheet = false },
                        label = { Text("Only songs the bot can't reach (${songs.count { it.botCantReach }})") },
                    )
                    // Songs the bot cannot read are removed from the library unless they are the only copy: pick them here, then delete the
                    // duplicates (the same song is already in your chat) or copy the rest to the chat first.
                    val unreachable = songs.filter { it.botCantReach }
                    TextButton(
                        onClick = { selection = Selection(unreachable.mapTo(HashSet()) { it.rowKey }); sortSheet = false },
                        enabled = unreachable.isNotEmpty(), modifier = Modifier.fillMaxWidth(),
                    ) { Text("Select songs the bot can't read (${unreachable.size})", Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Start) }
                    val readable = songs.filter { !it.botCantReach }.groupBy { io.max.paperplay.core.integrations.looseTitleKey(it.title, it.artist) }
                    val duplicates = unreachable.filter { u ->
                        readable[io.max.paperplay.core.integrations.looseTitleKey(u.title, u.artist)].orEmpty().any { kotlin.math.abs(it.durationSec - u.durationSec) <= 3 }
                    }
                    TextButton(
                        onClick = { selection = Selection(duplicates.mapTo(HashSet()) { it.rowKey }); sortSheet = false },
                        enabled = duplicates.isNotEmpty(), modifier = Modifier.fillMaxWidth(),
                    ) { Text("Select only those already in your chat (${duplicates.size})", Modifier.fillMaxWidth(), textAlign = androidx.compose.ui.text.style.TextAlign.Start) }
                    Text("Sort songs", style = MaterialTheme.typography.titleLarge)
                    SongSort.entries.forEach { option ->
                        TextButton(
                            onClick = {
                                if (option == sort) reverse = !reverse else { sort = option; reverse = false }
                                if (listKey != null) uiPrefs?.putString("list_sort:$listKey", "${sort.name}:$reverse") else uiPrefs?.setSongSort(sort, reverse)
                                sortSheet = false
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(
                                text = "${option.label}${if (option == sort) if (reverse) " (descending)" else " (ascending)" else ""}",
                                modifier = Modifier.fillMaxWidth(),
                                textAlign = androidx.compose.ui.text.style.TextAlign.Start,
                            )
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }
            }
        }
    }
}

@Composable
fun ScreenTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text,
        style = MaterialTheme.typography.headlineMedium,
        modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 4.dp),
    )
}

@Composable
fun Section(title: String, modifier: Modifier = Modifier) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        modifier = modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 6.dp),
    )
}

@Composable
fun ClickableRow(onClick: () -> Unit, modifier: Modifier = Modifier, content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) {
    Row(modifier.fillMaxWidth().clickable(onClick = onClick), verticalAlignment = Alignment.CenterVertically, content = content)
}

@Composable
fun Gap(h: Int) = Spacer(Modifier.height(h.dp))

private val previewActions: ListActions
    get() = ListActions(
        play = { _, _ -> },
        shuffle = {},
        setFavorite = { _, _ -> },
        addToPlaylist = {},
        notice = {},
    )

private val previewSongList = listOf(
    SongUi(id = "1", title = "Song One", artist = "Artist A", album = "Album 1", durationSec = 200, sizeBytes = 5_000_000, qualityLabel = "320 kbps", favorite = true, pinned = false, offline = true),
    SongUi(id = "2", title = "Song Two", artist = "Artist B", album = "Album 2", durationSec = 180, sizeBytes = 4_500_000, qualityLabel = "FLAC", favorite = false, pinned = true, offline = true),
)

@Preview(name = "Song list", widthDp = 360, heightDp = 640, showBackground = true)
@Composable
private fun SongListPreview() = io.max.paperplay.ui.PreviewFrame {
    SongList(songs = previewSongList + io.max.paperplay.ui.previewSongs, currentId = "1", actions = previewActions)
}

@Preview
@Composable
private fun ScreenTitlePreview() {
    ScreenTitle(text = "Library Title")
}

@Preview
@Composable
private fun SectionPreview() {
    Section(title = "Featured Songs")
}

@Preview
@Composable
private fun ClickableRowPreview() {
    ClickableRow(onClick = {}) {
        Text("Clickable Row Content", modifier = Modifier.padding(16.dp))
    }
}


@Preview(name = "Gap", showBackground = true)
@Composable
private fun GapPreview() = io.max.paperplay.ui.PreviewFrame { Gap(24) }

/** One row of a list: a file posted twice has two rows with the same song id, and picking the extra one must not pick the song. */
internal val SongUi.rowKey: String get() = copyKey ?: id

/** The picked rows a delete may act on: the songs themselves, never the rows of their extra posts. */
internal fun deletableRows(rows: List<SongUi>, picked: Selection): List<SongUi> = rows.filter { it.copyKey == null && it.rowKey in picked }
