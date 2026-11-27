package io.max.paperplay.ui.app

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CloudSync
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.core.eq.AutoEqEntry
import io.max.paperplay.core.eq.AutoEqRemoteItem
import io.max.paperplay.ui.components.AppIcon

@Composable
internal fun EqAutoEqSection(
    profileId: String,
    autoEqCount: Int,
    query: String,
    selectedSource: String?,
    selectedForm: String?,
    sources: List<String>,
    forms: List<String>,
    results: List<AutoEqEntry>,
    onlineItems: List<AutoEqRemoteItem>,
    refreshing: Boolean,
    refreshMsg: String?,
    appliedId: Long?,
    listState: LazyListState,
    bottomPadding: Dp,
    onQueryChange: (String) -> Unit,
    onSourceChange: (String?) -> Unit,
    onFormChange: (String?) -> Unit,
    onRefreshOnline: () -> Unit,
    onPreviewEntry: (AutoEqEntry) -> Unit,
    onApplyEntry: (AutoEqEntry) -> Unit,
    onDownloadOnline: (AutoEqRemoteItem) -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val onlineMatches = remember(onlineItems, query) {
        if (onlineItems.isEmpty() || query.isBlank()) emptyList()
        else {
            val toks = query.trim().lowercase().split(Regex("\\s+")).filter { it.isNotEmpty() }
            onlineItems.filter { item ->
                val hay = "${item.model} ${item.source} ${item.form}".lowercase()
                toks.all { it in hay }
            }.take(20)
        }
    }

    Column(Modifier.fillMaxSize().imePadding()) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(top = 6.dp, bottom = 4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                PillField(
                    value = query,
                    onChange = onQueryChange,
                    hint = "Search headphones or IEMs",
                    modifier = Modifier.weight(1f),
                )
                IconButton(enabled = !refreshing, onClick = onRefreshOnline) {
                    AppIcon(Icons.Rounded.CloudSync, "Refresh online AutoEQ index")
                }
            }
            Text(
                refreshMsg ?: "$autoEqCount offline profiles (MIT, jaakkopasanen/AutoEq)",
                style = MaterialTheme.typography.bodySmall,
                color = scheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 2.dp),
            )
            if (forms.isNotEmpty()) {
                val formOptions = remember(forms) { listOf<String?>(null) + forms.take(6) }
                ChoiceRow(
                    options = formOptions,
                    selected = selectedForm,
                    label = { it ?: "All types" },
                    onSelect = { onFormChange(if (it != null && selectedForm == it) null else it) },
                )
            }
            if (sources.isNotEmpty()) {
                val topSources = remember(sources) {
                    val preferred = listOf("oratory1990", "crinacle", "Rtings", "Innerfidelity", "Headphone.com Legacy", "ToneDeafMonk")
                    listOf<String?>(null) + (preferred.filter { it in sources } + sources.filter { it !in preferred }).take(10)
                }
                ChoiceRow(
                    options = topSources,
                    selected = selectedSource,
                    label = { it ?: "All sources" },
                    onSelect = { onSourceChange(if (it != null && selectedSource == it) null else it) },
                )
            }
        }

        HorizontalDivider(color = scheme.outlineVariant.copy(alpha = 0.35f))

        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(top = 8.dp, bottom = bottomPadding + 16.dp),
        ) {
            if (results.isEmpty()) {
                item(key = "empty") {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 24.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        AppIcon(Icons.Rounded.Headphones, null, tint = scheme.onSurfaceVariant)
                        Text(
                            if (autoEqCount == 0) "Offline AutoEQ database not bundled yet."
                            else "No matching headphones found for \"$query\".",
                            style = MaterialTheme.typography.bodyMedium,
                            color = scheme.onSurfaceVariant,
                        )
                    }
                }
            } else {
                items(results, key = { it.id }) { entry ->
                    val isApplied = appliedId == entry.id || profileId == "autoeq-${entry.id}"
                    AutoEqEntryRow(
                        entry = entry,
                        isApplied = isApplied,
                        onPreview = { onPreviewEntry(entry) },
                        onApply = { onApplyEntry(entry) },
                    )
                }
            }

            if (onlineMatches.isNotEmpty()) {
                item(key = "online-header") { SectionLabel("Online AutoEQ index") }
                items(onlineMatches, key = { "${it.source}:${it.form}:${it.model}" }) { item ->
                    val shape = appShape(16.dp)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 3.dp)
                            .heightIn(min = 64.dp)
                            .partSurface(LookGroup.Cards, scheme.surfaceContainerLow, shape)
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(
                                item.model,
                                style = MaterialTheme.typography.titleMedium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            Text(
                                "${item.source} · ${item.form} (Online)",
                                style = MaterialTheme.typography.bodySmall,
                                color = scheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        OutlinedButton(onClick = { onDownloadOnline(item) }) {
                            Text("Download")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AutoEqEntryRow(
    entry: AutoEqEntry,
    isApplied: Boolean,
    onPreview: () -> Unit,
    onApply: () -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val shape = appShape(16.dp)
    val bg = if (isApplied) scheme.primaryContainer.copy(alpha = 0.5f) else scheme.surfaceContainerLow

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 3.dp)
            .heightIn(min = 64.dp)
            .partSurface(LookGroup.Cards, bg, shape)
            .clickable(onClick = onPreview)
            .padding(start = 16.dp, end = 10.dp, top = 10.dp, bottom = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                entry.model,
                style = MaterialTheme.typography.titleMedium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                "${entry.source} · ${entry.form} · Preamp ${fmtDb(entry.preampDb)} dB",
                style = MaterialTheme.typography.bodySmall,
                color = scheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        TextButton(onClick = onPreview) {
            Text(if (isApplied) "Turn off" else "Preview")
        }
        Button(onClick = onApply) {
            Text("Apply")
        }
    }
}
