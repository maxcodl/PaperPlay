package io.max.paperplay.ui.app

import io.max.paperplay.ui.components.AppIcon

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.IconButton
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.layout.height
import androidx.compose.material.icons.rounded.Close
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.CoverImage

/** Slim filled search field with a round end and a clear button. */
@Composable
fun PillField(value: String, onChange: (String) -> Unit, hint: String, modifier: Modifier = Modifier) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val scheme = MaterialTheme.colorScheme
    val fieldBg = if (tokens.enabled) tokens.fieldBg else scheme.surfaceContainerHigh
    val fg = if (tokens.enabled) tokens.onGlass else scheme.onSurface
    val muted = if (tokens.enabled) tokens.onGlassMuted else scheme.onSurfaceVariant
    Row(
        modifier.fillMaxWidth().height(44.dp).clip(appShape(22.dp, CornerArea.Chips)).background(fieldBg).padding(start = 12.dp, end = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AppIcon(Icons.Rounded.Search, null, Modifier.size(20.dp), tint = muted)
        BasicTextField(
            value = value,
            onValueChange = onChange,
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = fg),
            cursorBrush = SolidColor(if (tokens.enabled) tokens.accentOnGlass else scheme.primary),
            modifier = Modifier.weight(1f).padding(horizontal = 10.dp),
            decorationBox = { inner ->
                Box(contentAlignment = Alignment.CenterStart) {
                    if (value.isEmpty()) Text(hint, style = MaterialTheme.typography.bodyLarge, color = muted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    inner()
                }
            },
        )
        if (value.isNotEmpty()) IconButton({ onChange("") }, Modifier.size(36.dp)) { AppIcon(Icons.Rounded.Close, "Clear", Modifier.size(18.dp), tint = muted) }
    }
}

/** Outlined chips in Default; borderless tonal pills in Modern. */
@Composable
fun ChipRow(labels: List<String>, selected: Int, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val shape = appShape(if (tokens.enabled) 50.dp else 12.dp, CornerArea.Chips)
    Row(
        modifier.horizontalScroll(rememberScrollState()).selectableGroup().padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        labels.forEachIndexed { i, t ->
            val on = i == selected
            val bg = when {
                tokens.enabled && on -> tokens.chipSelectedBg
                tokens.enabled -> tokens.chipBg
                on -> MaterialTheme.colorScheme.secondaryContainer
                else -> Color.Transparent
            }
            val fg = when {
                tokens.enabled && on -> MaterialTheme.colorScheme.onSecondaryContainer
                tokens.enabled -> tokens.onGlass
                on -> MaterialTheme.colorScheme.onSecondaryContainer
                else -> MaterialTheme.colorScheme.onSurface
            }
            Box(
                Modifier.heightIn(min = 48.dp)
                    .clip(shape)
                    .background(bg)
                    .then(if (on || tokens.enabled) Modifier else Modifier.border(BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant), shape))
                    .selectable(selected = on, role = Role.Tab, onClick = { onSelect(i) })
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(t, style = MaterialTheme.typography.labelLarge, color = fg)
            }
        }
    }
}

/** Four covers as a 2 by 2 grid when there are that many, else the first cover. */
@Composable
fun CoverGrid(uris: List<String?>, key: String, size: Dp, radius: Dp, modifier: Modifier = Modifier) {
    val real = uris.filterNotNull().distinct()
    if (real.size < 4) {
        CoverImage(real.firstOrNull(), key, modifier, size, radius)
    } else {
        Column(modifier.size(size).clip(appShape(radius, CornerArea.Covers))) {
            for (r in 0..1) Row { for (c in 0..1) CoverImage(real[r * 2 + c], "$key$r$c", size = size / 2, radius = 0.dp) }
        }
    }
}

@Preview
@Composable
private fun PillFieldPreview() {
    PillField(value = "Rock", onChange = {}, hint = "Search songs, artists...")
}

@Preview
@Composable
private fun ChipRowPreview() {
    ChipRow(labels = listOf("Songs", "Albums", "Artists", "Playlists"), selected = 0, onSelect = {})
}

@Preview
@Composable
private fun CoverGridPreview() {
    CoverGrid(uris = listOf(null, null, null, null), key = "preview_grid", size = 120.dp, radius = 12.dp)
}

