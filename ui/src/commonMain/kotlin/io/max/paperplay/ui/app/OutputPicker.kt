package io.max.paperplay.ui.app

import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import io.max.paperplay.ui.components.AppIcon

/**
 * PC: picks the sound output the app plays through, like the Windows output list but for this app only.
 * "Windows default" follows whatever Windows uses; a device picked here stays until it is changed back.
 */
@Composable
fun OutputPickerButton(backend: PlayerControls, tint: Color, iconSize: Modifier) {
    var open by remember { mutableStateOf(false) }
    var devices by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    val chosen by backend.outputChoice.collectAsState()
    // Read afresh each time the menu opens, so newly connected earbuds show up.
    LaunchedEffect(open) {
        if (open) devices = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) { io.max.paperplay.ui.listOutputDevices() }
    }
    Box {
        DesktopTooltip("Sound output") {
            IconButton({ open = true }) { AppIcon(Icons.Rounded.Headphones, "Sound output", iconSize, tint = tint) }
        }
        DropdownMenu(open, { open = false }) {
            val rows = listOf<Pair<String?, String>>(null to "Windows default") + devices
            for ((id, name) in rows) {
                DropdownMenuItem(
                    text = { Text(name) },
                    onClick = { open = false; backend.setOutputChoice(id) },
                    leadingIcon = { if (id == chosen) AppIcon(Icons.Rounded.Check, "Selected") else Box(iconSize) },
                )
            }
            // A device picked earlier that is not connected now: shown so it can be switched back to the default.
            if (chosen != null && devices.isNotEmpty() && devices.none { it.first == chosen }) {
                DropdownMenuItem(text = { Text("Picked device (not connected)") }, onClick = { open = false }, enabled = false)
            }
        }
    }
}
