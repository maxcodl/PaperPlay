package io.max.paperplay.ui.app

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp

/** Opens an artist, album or other page; set by the shell (it also closes the player). Null where nothing can be opened. */
val LocalOpenDetail = compositionLocalOf<((Detail) -> Unit)?> { null }

/** The credit of a song with each artist as its own tap target: "A, B & C" opens A, B or C. */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun ArtistLinks(artist: String, style: TextStyle, color: Color, modifier: Modifier = Modifier) {
    val open = LocalOpenDetail.current
    val names = remember(artist) { creditArtists(artist) }
    if (open == null || names.isEmpty()) {
        Text(artist, modifier, maxLines = 1, style = style, color = color)
        return
    }
    FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        names.forEachIndexed { i, n ->
            Text(
                if (i < names.lastIndex) "$n," else n, Modifier.clickable { open(Detail.Artist(n)) },
                maxLines = 1, style = style, color = color,
            )
        }
    }
}

/** The album name as a tap target that opens the album. */
@Composable
fun AlbumLink(album: String, style: TextStyle, color: Color, modifier: Modifier = Modifier) {
    val open = LocalOpenDetail.current
    Text(album, if (open == null) modifier else modifier.clickable { open(Detail.Album(io.max.paperplay.core.metadata.cleanAlbumName(album))) }, maxLines = 1, style = style, color = color)
}
