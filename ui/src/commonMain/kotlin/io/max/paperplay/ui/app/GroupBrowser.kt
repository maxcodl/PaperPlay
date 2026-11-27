package io.max.paperplay.ui.app

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Sort
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.max.paperplay.core.metadata.nameIndexLetter
import io.max.paperplay.core.metadata.nameSortKey
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.state.GroupUi
import io.max.paperplay.ui.theme.motionItem
import kotlinx.coroutines.launch
import org.jetbrains.compose.ui.tooling.preview.Preview

/** How the Albums and Artists pages order their entries. */
enum class GroupSort(val label: String) { Name("Name"), Songs("Most songs"), Added("Recently added"), Played("Most played") }

/**
 * The Albums or Artists page: a search box, sort, filters and an A-Z jump over a grid of covers (round for artists).
 * The choices are kept per page. [artists] also offers shared credits ("A & B") as entries of their own.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GroupBrowser(groups: List<GroupUi>, artists: Boolean, bottomPadding: Dp, onClick: (GroupUi) -> Unit) {
    val prefs = LocalUiPrefs.current
    val page = if (artists) "artists" else "albums"
    var query by remember { mutableStateOf("") }
    var sort by remember { mutableStateOf(GroupSort.entries.firstOrNull { it.name == prefs?.getString("browse_${page}_sort") } ?: GroupSort.Name) }
    var several by remember { mutableStateOf(prefs?.getString("browse_${page}_several") == "true") }
    var loved by remember { mutableStateOf(prefs?.getString("browse_${page}_loved") == "true") }
    var shared by remember { mutableStateOf(prefs?.getString("browse_${page}_shared") == "true") }
    var sortMenu by remember { mutableStateOf(false) }

    val shown = remember(groups, query, sort, several, loved, shared) {
        val q = query.trim().lowercase()
        groups.asSequence()
            // Split: each artist on their own. Shared credits: the credits as written, so an artist seen only in shared credits is left out.
            .filter { if (!artists) true else if (shared) it.combined || it.solo else !it.combined }
            .filter { !several || it.count > 1 }
            .filter { !loved || it.favorites > 0 }
            .filter { q.isEmpty() || it.name.lowercase().contains(q) || it.subtitle.lowercase().contains(q) }
            .toList()
            .let { list ->
                when (sort) {
                    GroupSort.Name -> list.sortedBy { nameSortKey(it.name) }
                    GroupSort.Songs -> list.sortedWith(compareByDescending<GroupUi> { it.count }.thenBy { nameSortKey(it.name) })
                    GroupSort.Added -> list.sortedByDescending { it.addedAt }
                    GroupSort.Played -> list.sortedWith(compareByDescending<GroupUi> { it.plays }.thenBy { nameSortKey(it.name) })
                }
            }
    }
    val grid = rememberLazyGridState()
    val scope = rememberCoroutineScope()

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            PillField(query, { query = it }, if (artists) "Search artists" else "Search albums or artists", Modifier.weight(1f))
            Box {
                DesktopTooltip("Sort: ${sort.label}") {
                    IconButton({ sortMenu = true }) { AppIcon(Icons.AutoMirrored.Rounded.Sort, "Sort") }
                }
                DropdownMenu(sortMenu, { sortMenu = false }) {
                    GroupSort.entries.forEach { o ->
                        DropdownMenuItem(
                            text = { Text(if (o == sort) "${o.label} (selected)" else o.label) },
                            onClick = { sort = o; prefs?.putString("browse_${page}_sort", o.name); sortMenu = false },
                        )
                    }
                }
            }
        }
        FlowRow(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(several, { several = !several; prefs?.putString("browse_${page}_several", "$several") }, { Text("More than 1 song") })
            FilterChip(loved, { loved = !loved; prefs?.putString("browse_${page}_loved", "$loved") }, { Text("Has favourites") })
            if (artists) FilterChip(shared, { shared = !shared; prefs?.putString("browse_${page}_shared", "$shared") }, { Text("Original credits") })
        }
        if (shown.isEmpty()) {
            Text(
                if (groups.isEmpty()) (if (artists) "No artists yet." else "No albums yet.") else "Nothing matches.",
                Modifier.padding(24.dp), color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            return@Column
        }
        Row(Modifier.fillMaxSize()) {
            LazyVerticalGrid(
                GridCells.Adaptive(if (io.max.paperplay.ui.isPhone) 140.dp else 160.dp), Modifier.weight(1f).fillMaxHeight(), state = grid,
                contentPadding = PaddingValues(16.dp, 8.dp, 8.dp, bottomPadding + 16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                items(shown.size, key = { shown[it].id }) { i ->
                    val g = shown[i]
                    val radius = if (artists) 999.dp else 12.dp
                    Column(
                        motionItem().clip(RoundedCornerShape(12.dp)).clickable { onClick(g) },
                        horizontalAlignment = if (artists) Alignment.CenterHorizontally else Alignment.Start,
                    ) {
                        BoxWithConstraints { CoverImage(g.coverUris.firstOrNull(), g.id, size = maxWidth, radius = if (artists) maxWidth / 2 else radius) }
                        val align = if (artists) TextAlign.Center else TextAlign.Start
                        Text(g.name, Modifier.padding(top = 8.dp), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleSmall, textAlign = align)
                        Text(
                            if (g.combined) "Together · ${g.subtitle}" else g.subtitle,
                            maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = align,
                        )
                    }
                }
            }
            // A-Z jump: only while sorted by name, the letters the list has, each scrolling to its first entry.
            if (sort == GroupSort.Name && shown.size > 30) {
                val letters = remember(shown) { shown.map { nameIndexLetter(it.name) }.distinct() }
                Column(
                    Modifier.width(24.dp).fillMaxHeight().padding(bottom = bottomPadding, top = 8.dp),
                    verticalArrangement = Arrangement.SpaceEvenly, horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    letters.forEach { l ->
                        Text(
                            "$l",
                            Modifier.clickable {
                                val at = shown.indexOfFirst { nameIndexLetter(it.name) == l }
                                if (at >= 0) scope.launch { grid.scrollToItem(at) }
                            }.padding(horizontal = 4.dp),
                            fontSize = 11.sp, color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }
            }
        }
    }
}

@Preview
@Composable
private fun GroupBrowserPreview() = io.max.paperplay.ui.PreviewFrame {
    GroupBrowser(
        listOf(
            GroupUi("1", "Billie Eilish", "12 songs", count = 12), GroupUi("2", "FINNEAS", "3 songs", count = 3),
            GroupUi("combo:Billie Eilish & FINNEAS", "Billie Eilish & FINNEAS", "2 songs", count = 2, combined = true),
        ),
        artists = true, bottomPadding = 0.dp,
    ) {}
}
