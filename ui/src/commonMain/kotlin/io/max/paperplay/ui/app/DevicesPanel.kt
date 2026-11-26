package io.max.paperplay.ui.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.rounded.Bluetooth
import androidx.compose.material.icons.rounded.Computer
import androidx.compose.material.icons.rounded.Devices
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material.icons.rounded.PhoneAndroid
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Wifi
import androidx.compose.ui.draw.clip
import io.max.paperplay.ui.state.SongUi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.max.paperplay.core.sync.LanSync
import io.max.paperplay.ui.components.AppIcon
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The local network sync of this app, or null while it has never been turned on. Provided by the shell. */
val LocalLanSync = compositionLocalOf<LanSync?> { null }

/** The backend's sync once it exists; sync is created the first time it is turned on, so this waits for it. */
@Composable
fun rememberLanSync(backend: CoreBackend): LanSync? {
    var lan by remember { mutableStateOf(backend.lanSync) }
    LaunchedEffect(lan) { while (lan == null) { delay(2000); lan = backend.lanSync } }
    return lan
}

/** Where the player's controls go, and the way to change it. [active] is null for this device, else a linked device's id. */
class OutputSwitch(val active: kotlinx.coroutines.flow.StateFlow<String?>, val switchTo: (String?) -> Unit, val moveTo: (String?) -> Unit)

val LocalOutputSwitch = compositionLocalOf<OutputSwitch?> { null }

/** "Headphones (Realtek(R) Audio)" becomes "Headphones" and "Realtek Audio"; a name without a trailing bracket is kept whole. */
internal fun splitDeviceName(raw: String): Pair<String, String?> {
    val name = raw.trim()
    val cut = name.indexOf(" (")
    if (cut <= 0 || !name.endsWith(")")) return name to null
    val detail = name.substring(cut + 2).removeSuffix(")").replace("(R)", "").replace("(TM)", "").replace(Regex("\\s+"), " ").trim()
    return name.substring(0, cut).trim() to detail.ifBlank { null }
}

/**
 * Other PaperPlay devices for the player's device pickers (desktop popup, phone sheet): each linked device with what it plays
 * and its controls, and paired devices that are away with a Connect button. No addresses here; they live on the Connection page.
 */
@Composable
fun LanDevicesSection(modifier: Modifier = Modifier) {
    val lan = LocalLanSync.current
    val scheme = MaterialTheme.colorScheme
    val muted = MaterialTheme.typography.bodySmall
    if (lan == null) {
        Text(
            "Turn on Sync with devices on this network under Connection to see your other devices here.",
            modifier, style = muted, color = scheme.onSurfaceVariant,
        )
        return
    }
    val connected by lan.connected.collectAsState()
    val paired by lan.paired.collectAsState()
    val now by lan.remoteNow.collectAsState()
    val scope = rememberCoroutineScope()
    var note by remember { mutableStateOf<String?>(null) }
    val output = LocalOutputSwitch.current
    val activeId = output?.active?.collectAsState()?.value
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        // Playing on another device: one tap brings playback back here.
        if (output != null && activeId != null) Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).clickable { output.switchTo(null) }.padding(vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AppIcon(Icons.Rounded.Devices, null, Modifier.size(28.dp), tint = scheme.primary)
            Text("Control this device", Modifier.weight(1f).padding(horizontal = 14.dp), style = MaterialTheme.typography.titleMedium, color = scheme.primary)
        }
        for (d in connected) {
            val n = now[d.id]
            val isActive = activeId == d.id
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                    .then(if (d.paired && output != null) Modifier.clickable { output.switchTo(if (isActive) null else d.id) } else Modifier),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                AppIcon(if (d.desktop) Icons.Rounded.Computer else Icons.Rounded.PhoneAndroid, null, Modifier.size(28.dp), tint = scheme.onSurfaceVariant)
                Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
                    Text(d.name, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val nowMs = System.currentTimeMillis()
                    val live = n != null && n.fresh(nowMs) && n.uniqueId != null
                    val song = n?.title?.let { t -> if (n.artist.isNullOrBlank()) t else "$t - ${n.artist}" }
                    Text(
                        when {
                            live && song != null -> (if (n!!.playing) "Playing: " else "Paused: ") + song
                            d.paired && output != null -> "Nothing playing. Tap to play on ${d.name}"
                            else -> "Connected"
                        },
                        style = muted, color = if (live && n!!.playing) scheme.primary else scheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                    val via = n?.outName?.takeIf { live }
                    if (via != null || isActive) Text(
                        listOfNotNull(if (isActive) "Controlled from here" else null, via?.let { "via $it" }).joinToString(" · "),
                        style = muted, color = scheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                }
                if (d.paired) {
                    IconButton({ scope.launch { lan.sendControl(d.id, "previous") } }, Modifier.size(36.dp)) { AppIcon(Icons.Rounded.SkipPrevious, "Previous on ${d.name}", Modifier.size(22.dp)) }
                    IconButton({ scope.launch { lan.sendControl(d.id, if (n?.playing == true) "pause" else "play") } }, Modifier.size(36.dp)) {
                        AppIcon(if (n?.playing == true) Icons.Rounded.Pause else Icons.Rounded.PlayArrow, if (n?.playing == true) "Pause on ${d.name}" else "Play on ${d.name}", Modifier.size(24.dp))
                    }
                    IconButton({ scope.launch { lan.sendControl(d.id, "next") } }, Modifier.size(36.dp)) { AppIcon(Icons.Rounded.SkipNext, "Next on ${d.name}", Modifier.size(22.dp)) }
                }
            }
            // Play on: both keep playing. Move: the song and queue go over and the other one stops.
            // A row of its own under the device, so the narrow text column beside the transport buttons never squeezes them.
            if (d.paired && output != null) Row(Modifier.padding(start = 42.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                androidx.compose.material3.FilterChip(false, { output.switchTo(if (isActive) null else d.id) }, { Text(if (isActive) "Control here" else "Play on", style = muted, maxLines = 1, softWrap = false) })
                androidx.compose.material3.FilterChip(false, { output.moveTo(if (isActive) null else d.id) }, { Text(if (isActive) "Move back" else "Move to", style = muted, maxLines = 1, softWrap = false) })
            }
        }
        for (p in paired.filter { p -> connected.none { it.id == p.id } }) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                AppIcon(Icons.Rounded.Devices, null, Modifier.size(28.dp), tint = scheme.onSurfaceVariant.copy(alpha = 0.6f))
                Column(Modifier.weight(1f).padding(horizontal = 14.dp)) {
                    Text(p.name, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis, color = scheme.onSurface.copy(alpha = 0.8f))
                    Text("Not connected", style = muted, color = scheme.onSurfaceVariant)
                }
                OutlinedButton({ scope.launch { note = if (lan.connect(p.id).ok) null else "Could not reach ${p.name}. Check its addresses under Connection." } }) { Text("Connect") }
            }
        }
        if (connected.isEmpty() && paired.isEmpty()) Text("No other devices found. Open Paper Play on another device on this Wi-Fi, with the same bot.", style = muted, color = scheme.onSurfaceVariant)
        note?.let { Text(it, style = muted, color = scheme.error) }
    }
}

/** Tiles that open the device settings: Connection and Network play, and the system output chooser where there is one. */
@Composable
fun DevicesActions(onOpen: ((String) -> Unit)?, switchOutput: (() -> Unit)?, onDone: () -> Unit, modifier: Modifier = Modifier) {
    val scheme = MaterialTheme.colorScheme
    @Composable
    fun Tile(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, run: () -> Unit, mod: Modifier) {
        Column(
            mod.clip(RoundedCornerShape(18.dp)).background(scheme.onSurface.copy(alpha = 0.08f)).clickable { onDone(); run() }.padding(vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            AppIcon(icon, null, Modifier.size(26.dp), tint = scheme.primary)
            Text(label, style = MaterialTheme.typography.labelLarge, color = scheme.primary)
        }
    }
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        if (onOpen != null) Tile(Icons.Rounded.Sync, "Connection", { onOpen("devices") }, Modifier.weight(1f))
        if (onOpen != null) Tile(Icons.Rounded.Wifi, "Network play", { onOpen("netplay") }, Modifier.weight(1f))
        if (switchOutput != null) Tile(Icons.Rounded.Bluetooth, "Output", switchOutput, Modifier.weight(1f))
    }
}

/**
 * The phone's device sheet, in the style of Spotify's Connect: where the sound is going now (the headphones or the phone) with
 * what is playing, the other PaperPlay devices, and tiles into the device settings.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
internal fun PhoneDevicesDialog(onOpen: (String) -> Unit, switchOutput: (() -> Unit)?, current: SongUi?, onDismiss: () -> Unit) {
    val scheme = MaterialTheme.colorScheme
    val out = io.max.paperplay.ui.rememberOutputDevice()
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = androidx.compose.material3.rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = if (tokens.enabled) tokens.overlayBg else scheme.surfaceContainerHigh,
        tonalElevation = if (tokens.enabled) 0.dp else androidx.compose.material3.BottomSheetDefaults.Elevation,
    ) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Text("Play on", style = MaterialTheme.typography.headlineSmall)
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp)).background(scheme.primaryContainer.copy(alpha = 0.55f)).padding(18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    val (outTitle, outDetail) = splitDeviceName(out.name)
                    Text(outTitle, style = MaterialTheme.typography.titleLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(listOfNotNull("This phone", outDetail).joinToString(" · "), style = MaterialTheme.typography.bodyMedium, color = scheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (current != null) Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        AppIcon(Icons.Rounded.GraphicEq, null, Modifier.size(18.dp), tint = scheme.primary)
                        Text(
                            "${current.title} - ${current.artist}", Modifier.padding(start = 8.dp), style = MaterialTheme.typography.bodyMedium,
                            color = scheme.primary, maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
                AppIcon(if (out.external) Icons.Rounded.Headphones else Icons.Rounded.PhoneAndroid, null, Modifier.size(44.dp), tint = scheme.primary)
            }
            LanDevicesSection()
            DevicesActions(onOpen, switchOutput, onDismiss)
        }
    }
}
