package io.max.paperplay.ui.app

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Verified
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.core.eq.AutoEqEntry
import io.max.paperplay.player.BitPerfectStatus
import io.max.paperplay.player.ParametricBand
import io.max.paperplay.player.ParametricEqProfile
import io.max.paperplay.player.PeqChannel
import io.max.paperplay.player.PeqFilterType
import io.max.paperplay.ui.FakePlayerControls
import io.max.paperplay.ui.PreviewFrame
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.isPhone
import io.max.paperplay.ui.theme.LocalReduceMotion
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.jetbrains.compose.ui.tooling.preview.Preview
import kotlin.math.round

private enum class EqTab(val label: String) {
    Curve("Curve"),
    Bands("Bands"),
    AutoEQ("AutoEQ"),
    Presets("Presets"),
}

internal enum class EqSignalTone { Primary, Secondary, Muted }

internal data class EqSignalBadge(
    val title: String,
    val detail: String,
    val tone: EqSignalTone,
    val iconKind: String,
)

internal fun isBitPerfectBypassingEq(
    bitPerfect: Boolean,
    outputBitPerfect: Boolean,
    isPhone: Boolean,
    allowEqInUsb: Boolean,
): Boolean {
    val allowDirectUsbEq = isPhone && allowEqInUsb
    return (bitPerfect || outputBitPerfect) && !allowDirectUsbEq
}

internal fun resolveEqSignalBadge(
    bitPerfectStatus: BitPerfectStatus,
    eqOn: Boolean,
    bitPerfectBypass: Boolean,
    sampleRate: Int,
    bitDepth: Int,
): EqSignalBadge = when (bitPerfectStatus) {
    is BitPerfectStatus.DirectWithEq -> EqSignalBadge(
        title = "USB Direct + EQ · ${formatSignalPathSpec(bitPerfectStatus.sampleRateHz, bitPerfectStatus.bitDepth)}",
        detail = "Native sample rate and bit depth preserved while bypassing Android's mixer (64-bit EQ with TPDF dither).",
        tone = EqSignalTone.Primary,
        iconKind = "usb",
    )
    is BitPerfectStatus.Active -> EqSignalBadge(
        title = "USB Bit-Perfect · ${formatSignalPathSpec(bitPerfectStatus.sampleRateHz, bitPerfectStatus.bitDepth)}",
        detail = if (bitPerfectBypass) {
            "Strict Bit-perfect is bypassing EQ so audio reaches your DAC untouched."
        } else {
            "DSP bypassed while EQ is off or flat — untouched bit-perfect output."
        },
        tone = EqSignalTone.Secondary,
        iconKind = "verified",
    )
    else -> {
        val active = eqOn && !bitPerfectBypass
        val suffix = if (active) "EQ Active" else "Bypassed"
        EqSignalBadge(
            title = "${formatSignalPathSpec(sampleRate, bitDepth)} · $suffix",
            detail = if (active) {
                "64-bit parametric EQ active on the current output."
            } else if (bitPerfectBypass) {
                "Strict Bit-perfect is bypassing EQ so audio reaches your DAC untouched."
            } else {
                "Equalizer is switched off; audio passes through untouched."
            },
            tone = if (active) EqSignalTone.Primary else EqSignalTone.Muted,
            iconKind = if (active) "active" else "info",
        )
    }
}

internal fun formatSignalPathSpec(sampleRateHz: Int, bitDepth: Int): String {
    val ratePart = when {
        sampleRateHz <= 0 -> "Native rate"
        sampleRateHz % 1000 == 0 -> "${sampleRateHz / 1000} kHz"
        else -> "${round(sampleRateHz / 100f) / 10f} kHz"
    }
    val depthPart = if (bitDepth > 0) "$bitDepth-bit" else "PCM"
    return "$ratePart / $depthPart"
}

/** Top bar actions shared by FullScreenEqualizerPage, Settings > Listening > Equalizer, and EqualizerDialog. */
@Composable
internal fun EqualizerTopBarActions(backend: PlayerControls) {
    val eqOn by backend.eqOn.collectAsState()
    val eqDry by backend.eqDry.collectAsState()
    val scheme = MaterialTheme.colorScheme
    val shape = appShape(12.dp, CornerArea.Chips)

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .heightIn(min = 48.dp)
                .clip(shape)
                .background(if (eqDry) scheme.secondaryContainer else Color.Transparent)
                .then(if (eqDry) Modifier else Modifier.border(1.dp, scheme.outlineVariant, shape))
                .semantics { contentDescription = "Compare with original" }
                .toggleable(
                    value = eqDry,
                    role = Role.Switch,
                    onValueChange = { backend.setEqDry(it) },
                )
                .padding(horizontal = 14.dp, vertical = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                if (eqDry) "Orig" else "A/B",
                style = MaterialTheme.typography.labelLarge,
                color = if (eqDry) scheme.onSecondaryContainer else scheme.onSurface,
                maxLines = 1,
            )
        }
        Switch(
            checked = eqOn,
            onCheckedChange = { backend.setParametricEnabled(it) },
            modifier = Modifier.semantics { contentDescription = "Master equalizer" },
        )
    }
}

/**
 * Dedicated full-screen Equalizer destination launched from FullPlayer.
 * Uses PaperPlay's standard [BackTopBar] and shares [EqualizerScreenBody] with Settings and Desktop dialog.
 */
@Composable
internal fun FullScreenEqualizerPage(
    backend: PlayerControls,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    CompositionLocalProvider(LocalSettingsInfo provides true) {
        Surface(
            modifier = modifier.fillMaxSize().blockTouchesBehind(),
            color = MaterialTheme.colorScheme.background,
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .navigationBarsPadding(),
            ) {
                BackTopBar(
                    title = "Equalizer",
                    onBack = onBack,
                    actions = { EqualizerTopBarActions(backend) },
                )
                EqualizerScreenBody(
                    backend = backend,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    bottomPadding = 16.dp,
                )
            }
        }
    }
}

/**
 * Single shared Equalizer body used by FullScreenEqualizerPage, Settings > Listening > Equalizer,
 * and Desktop EqualizerDialog.
 */
@Composable
internal fun EqualizerScreenBody(
    backend: PlayerControls,
    modifier: Modifier = Modifier,
    bottomPadding: Dp = 0.dp,
) {
    val scheme = MaterialTheme.colorScheme
    val scope = rememberCoroutineScope()
    val reduceMotion = LocalReduceMotion.current

    val eqOn by backend.eqOn.collectAsState()
    val profile by backend.peqProfile.collectAsState()
    val bitPerfect by backend.bitPerfect.collectAsState()
    val bitPerfectStatus by backend.bitPerfectStatus.collectAsState()
    val allowEqInUsb by backend.allowEqInUsbExclusive.collectAsState()
    val outputInfo by backend.outputInfo.collectAsState()
    val eqDeviceKey by backend.eqDeviceKey.collectAsState()
    val eqOutput by backend.eqOutput.collectAsState()
    val eqDeviceAssigned by backend.eqDeviceAssigned.collectAsState()
    val savedPresets by backend.peqPresets.collectAsState()
    val deviceAssignments by backend.eqDeviceAssignments.collectAsState()
    val onlineAutoEqItems by backend.onlineAutoEqItems.collectAsState()

    val bitPerfectBypass = isBitPerfectBypassingEq(
        bitPerfect = bitPerfect,
        outputBitPerfect = outputInfo?.bitPerfect == true,
        isPhone = isPhone,
        allowEqInUsb = allowEqInUsb,
    )
    val sampleRate = outputInfo?.sampleRateHz?.takeIf { it >= 8000 } ?: 48000

    var selectedTab by remember { mutableIntStateOf(EqTab.Curve.ordinal) }
    val curveScrollState = rememberScrollState()
    val bandsListState = rememberLazyListState()
    val autoEqListState = rememberLazyListState()
    val presetsListState = rememberLazyListState()

    var selectedBandId by remember(profile.id) { mutableIntStateOf(profile.bands.firstOrNull()?.id ?: -1) }
    var expandedBandId by remember(profile.id) { mutableIntStateOf(-1) }
    var showPresetsDialog by remember { mutableStateOf(false) }
    var showSaveDialog by remember { mutableStateOf(false) }
    var renamePresetTarget by remember { mutableStateOf<ParametricEqProfile?>(null) }
    var showImportDialog by remember { mutableStateOf(false) }
    var showExportDialog by remember { mutableStateOf(false) }
    var numericEditBand by remember { mutableStateOf<ParametricBand?>(null) }
    var statusNotice by remember { mutableStateOf<String?>(null) }

    // Hoisted AutoEQ browser state so switching tabs keeps query, filters, and scroll position intact.
    var autoQuery by remember { mutableStateOf("") }
    var autoSelectedSource by remember { mutableStateOf<String?>(null) }
    var autoSelectedForm by remember { mutableStateOf<String?>(null) }
    var autoResults by remember { mutableStateOf<List<AutoEqEntry>>(emptyList()) }
    var autoSources by remember { mutableStateOf<List<String>>(emptyList()) }
    var autoForms by remember { mutableStateOf<List<String>>(emptyList()) }
    var autoRefreshing by remember { mutableStateOf(false) }
    var autoRefreshMsg by remember { mutableStateOf<String?>(null) }
    var autoAppliedId by remember { mutableStateOf<Long?>(null) }

    LaunchedEffect(Unit) {
        autoSources = backend.autoEqSources()
        autoForms = backend.autoEqForms()
    }
    LaunchedEffect(autoQuery, autoSelectedSource, autoSelectedForm) {
        if (autoQuery.isNotBlank()) delay(60)
        autoResults = backend.searchAutoEq(autoQuery, autoSelectedSource, autoSelectedForm)
    }

    val selectedBand = profile.bands.firstOrNull { it.id == selectedBandId } ?: profile.bands.firstOrNull()

    fun updateProfile(next: ParametricEqProfile, enableIfActive: Boolean = eqOn) {
        backend.setParametricProfile(next, enabled = enableIfActive)
    }

    fun updateBand(updated: ParametricBand) {
        val c = updated.clamped()
        val list = profile.bands.map { if (it.id == c.id) c else it }
        updateProfile(profile.copy(bands = list), enableIfActive = true)
    }

    fun addNewBand(expandInList: Boolean) {
        if (profile.bands.size >= ParametricEqProfile.MAX_PEQ_BANDS) return
        val nextId = (profile.bands.maxOfOrNull { it.id } ?: 0) + 1
        val nb = ParametricBand(
            id = nextId,
            enabled = true,
            type = PeqFilterType.PK,
            channel = PeqChannel.STEREO,
            freqHz = 1000f,
            gainDb = 0f,
            q = 1.41f,
        )
        updateProfile(profile.copy(bands = profile.bands + nb), enableIfActive = true)
        selectedBandId = nextId
        if (expandInList) expandedBandId = nextId
    }

    fun deleteBand(id: Int) {
        if (profile.bands.size <= 1) return
        val remaining = profile.bands.filterNot { it.id == id }
        updateProfile(profile.copy(bands = remaining))
        if (selectedBandId == id) selectedBandId = remaining.firstOrNull()?.id ?: -1
        if (expandedBandId == id) expandedBandId = -1
    }

    Column(modifier = modifier) {
        if (bitPerfectBypass) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .partSurface(LookGroup.Cards, scheme.secondaryContainer, appShape(20.dp))
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                AppIcon(Icons.Rounded.Verified, "Bit-perfect bypass", tint = scheme.onSecondaryContainer)
                Text(
                    "EQ off in Bit-perfect mode",
                    style = MaterialTheme.typography.titleSmall,
                    color = scheme.onSecondaryContainer,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (isPhone) {
                    TextButton(
                        onClick = {
                            backend.setAllowEqInUsbExclusive(true)
                            statusNotice = "Enabled EQ in USB Exclusive Mode"
                        },
                    ) {
                        Text("Allow EQ", maxLines = 1)
                    }
                }
            }
        }

        statusNotice?.let { msg ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp)
                    .partSurface(LookGroup.Cards, scheme.surfaceContainerHigh, appShape(16.dp))
                    .padding(start = 16.dp, end = 4.dp, top = 4.dp, bottom = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    msg,
                    style = MaterialTheme.typography.bodySmall,
                    color = scheme.primary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = { statusNotice = null }) {
                    AppIcon(Icons.Rounded.Close, "Dismiss notice")
                }
            }
        }

        ChipRow(
            labels = EqTab.entries.map { it.label },
            selected = selectedTab,
            onSelect = { selectedTab = it },
        )

        AnimatedContent(
            targetState = selectedTab,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            transitionSpec = { pageTransition(NavMove.Switch, reduceMotion) },
            label = "eqTab",
        ) { tabIdx ->
            when (EqTab.entries[tabIdx]) {
                EqTab.Curve -> EqCurveSection(
                    backend = backend,
                    profile = profile,
                    eqOn = eqOn,
                    bitPerfectStatus = bitPerfectStatus,
                    bitPerfectBypass = bitPerfectBypass,
                    sampleRate = sampleRate,
                    outputInfo = outputInfo,
                    selectedBand = selectedBand,
                    scrollState = curveScrollState,
                    bottomPadding = bottomPadding,
                    onSelectBand = { id ->
                        selectedBandId = id
                        expandedBandId = id
                    },
                    onDragBand = { id, newFreq, newGain ->
                        selectedBandId = id
                        val list = profile.bands.map { b ->
                            if (b.id == id) {
                                b.copy(
                                    freqHz = newFreq.coerceIn(10f, 24000f),
                                    gainDb = if (b.type.usesGain) newGain.coerceIn(-24f, 24f) else b.gainDb,
                                )
                            } else b
                        }
                        updateProfile(profile.copy(bands = list), enableIfActive = true)
                    },
                    onChangeBand = ::updateBand,
                    onDeleteBand = ::deleteBand,
                    onOpenNumeric = { band -> numericEditBand = band },
                    onChangeProfile = { updateProfile(it) },
                    onOpenPresets = { showPresetsDialog = true },
                )

                EqTab.Bands -> EqBandsSection(
                    profile = profile,
                    selectedBandId = selectedBand?.id ?: -1,
                    expandedBandId = expandedBandId,
                    listState = bandsListState,
                    bottomPadding = bottomPadding,
                    onAddBand = { addNewBand(expandInList = true) },
                    onLoadIso31 = {
                        val iso = ParametricEqProfile.iso31Preset()
                        updateProfile(iso, enableIfActive = true)
                        selectedBandId = iso.bands.firstOrNull()?.id ?: -1
                        expandedBandId = -1
                        statusNotice = "Loaded 31-band ISO 1/3-octave layout"
                    },
                    onResetFlat = {
                        val flat = profile.copy(
                            preampDb = 0f,
                            bands = profile.bands.map { it.copy(gainDb = 0f) },
                        )
                        updateProfile(flat)
                        statusNotice = "Reset all bands to 0 dB"
                    },
                    onToggleExpand = { band ->
                        selectedBandId = band.id
                        expandedBandId = if (expandedBandId == band.id) -1 else band.id
                    },
                    onChangeBand = ::updateBand,
                    onDeleteBand = ::deleteBand,
                    onOpenNumeric = { band -> numericEditBand = band },
                )

                EqTab.AutoEQ -> EqAutoEqSection(
                    profileId = profile.id,
                    autoEqCount = backend.autoEqCount,
                    query = autoQuery,
                    selectedSource = autoSelectedSource,
                    selectedForm = autoSelectedForm,
                    sources = autoSources,
                    forms = autoForms,
                    results = autoResults,
                    onlineItems = onlineAutoEqItems,
                    refreshing = autoRefreshing,
                    refreshMsg = autoRefreshMsg,
                    appliedId = autoAppliedId,
                    listState = autoEqListState,
                    bottomPadding = bottomPadding,
                    onQueryChange = { autoQuery = it },
                    onSourceChange = { autoSelectedSource = it },
                    onFormChange = { autoSelectedForm = it },
                    onRefreshOnline = {
                        autoRefreshing = true
                        scope.launch {
                            autoRefreshMsg = backend.refreshAutoEqIndex()
                            autoRefreshing = false
                        }
                    },
                    onPreviewEntry = { entry ->
                        // Tapping the active one again takes it off: back to a flat curve.
                        if (autoAppliedId == entry.id) {
                            autoAppliedId = null
                            val flat = io.max.paperplay.player.ParametricEqProfile.flat10()
                            updateProfile(flat, enableIfActive = true)
                            selectedBandId = flat.bands.firstOrNull()?.id ?: -1
                            statusNotice = "Removed ${entry.model}"
                            return@EqAutoEqSection
                        }
                        autoAppliedId = entry.id
                        val prof = entry.toProfile()
                        updateProfile(prof, enableIfActive = true)
                        selectedBandId = prof.bands.firstOrNull()?.id ?: -1
                        statusNotice = "Previewing ${entry.model}"
                    },
                    onApplyEntry = { entry ->
                        autoAppliedId = entry.id
                        val prof = entry.toProfile()
                        updateProfile(prof, enableIfActive = true)
                        selectedBandId = prof.bands.firstOrNull()?.id ?: -1
                        statusNotice = "Applied ${entry.model}"
                        selectedTab = EqTab.Curve.ordinal
                    },
                    onDownloadOnline = { item ->
                        scope.launch {
                            val prof = backend.fetchOnlineAutoEqProfile(item)
                            if (prof != null) {
                                updateProfile(prof, enableIfActive = true)
                                selectedBandId = prof.bands.firstOrNull()?.id ?: -1
                                statusNotice = "Applied ${prof.name}"
                                selectedTab = EqTab.Curve.ordinal
                            } else {
                                autoRefreshMsg = "Could not download profile for ${item.model}"
                            }
                        }
                    },
                )

                EqTab.Presets -> EqPresetsSection(
                    backend = backend,
                    profile = profile,
                    savedPresets = savedPresets,
                    deviceAssignments = deviceAssignments,
                    eqDeviceKey = eqDeviceKey,
                    eqOutput = eqOutput,
                    outputInfo = outputInfo,
                    eqDeviceAssigned = eqDeviceAssigned,
                    allowEqInUsb = allowEqInUsb,
                    listState = presetsListState,
                    bottomPadding = bottomPadding,
                    onToggleAssignDevice = {
                        val devName = eqOutput ?: outputInfo?.device ?: "Current output"
                        if (eqDeviceAssigned) {
                            backend.unassignEqFromCurrentDevice()
                            statusNotice = "Unassigned EQ from $devName"
                        } else {
                            backend.assignEqToCurrentDevice()
                            statusNotice = "Assigned \"${profile.name}\" to $devName"
                        }
                    },
                    onSelectPreset = { picked ->
                        updateProfile(picked, enableIfActive = true)
                        selectedBandId = picked.bands.firstOrNull()?.id ?: -1
                        statusNotice = "Loaded ${picked.name}"
                    },
                    onOpenSave = { showSaveDialog = true },
                    onOpenRename = { target -> renamePresetTarget = target },
                    onDeletePreset = { id ->
                        backend.deleteParametricPreset(id)
                        statusNotice = "Deleted preset"
                    },
                    onOpenImport = { showImportDialog = true },
                    onOpenExport = { showExportDialog = true },
                )
            }
        }
    }

    if (showPresetsDialog) {
        PresetsPickerDialog(
            userPresets = savedPresets,
            currentId = profile.id,
            onSelect = { picked ->
                updateProfile(picked, enableIfActive = true)
                selectedBandId = picked.bands.firstOrNull()?.id ?: -1
                showPresetsDialog = false
                statusNotice = "Loaded preset: ${picked.name}"
            },
            onDeleteUser = { id -> backend.deleteParametricPreset(id) },
            onClose = { showPresetsDialog = false },
        )
    }

    if (showSaveDialog) {
        SavePresetDialog(
            initialName = profile.name,
            title = "Save EQ preset",
            confirmLabel = "Save",
            onSave = { newName ->
                val saved = profile.copy(
                    id = "user-${newName.lowercase().replace(Regex("[^a-z0-9]+"), "-")}-${profile.bands.size}",
                    name = newName,
                    source = "User",
                )
                backend.saveParametricPreset(saved)
                updateProfile(saved)
                showSaveDialog = false
                statusNotice = "Saved preset \"$newName\""
            },
            onClose = { showSaveDialog = false },
        )
    }

    renamePresetTarget?.let { target ->
        SavePresetDialog(
            initialName = target.name,
            title = "Rename EQ preset",
            confirmLabel = "Rename",
            onSave = { newName ->
                val updated = target.copy(name = newName)
                backend.saveParametricPreset(updated)
                if (profile.id == target.id) {
                    updateProfile(profile.copy(name = newName))
                }
                renamePresetTarget = null
                statusNotice = "Renamed preset to \"$newName\""
            },
            onClose = { renamePresetTarget = null },
        )
    }

    if (showImportDialog) {
        ImportEqDialog(
            onImport = { imported ->
                updateProfile(imported, enableIfActive = true)
                backend.saveParametricPreset(imported)
                selectedBandId = imported.bands.firstOrNull()?.id ?: -1
                showImportDialog = false
                statusNotice = "Imported \"${imported.name}\" (${imported.bands.size} bands)"
            },
            onClose = { showImportDialog = false },
        )
    }

    if (showExportDialog) {
        ExportEqDialog(
            profile = profile,
            onClose = { showExportDialog = false },
        )
    }

    numericEditBand?.let { band ->
        BandNumericInputDialog(
            band = band,
            onSave = { edited ->
                updateBand(edited)
                numericEditBand = null
            },
            onClose = { numericEditBand = null },
        )
    }
}

private fun previewEqBackend(): FakePlayerControls = FakePlayerControls(
    eqOn = true,
    peqProfile = builtInParametricPresets[2],
    bitPerfectStatus = BitPerfectStatus.DirectWithEq("USB Direct", 96000, 32, "CX31993 USB DAC"),
    eqOutput = "CX31993 USB DAC",
)

@Preview(name = "Equalizer phone light", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun EqualizerPhoneLightPreview() = PreviewFrame(dark = false) {
    FullScreenEqualizerPage(backend = previewEqBackend(), onBack = {})
}

@Preview(name = "Equalizer phone dark", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun EqualizerPhoneDarkPreview() = PreviewFrame(dark = true) {
    FullScreenEqualizerPage(backend = previewEqBackend(), onBack = {})
}

@Preview(name = "Equalizer desktop light", widthDp = 900, heightDp = 700, showBackground = true)
@Composable
private fun EqualizerDesktopLightPreview() = PreviewFrame(dark = false) {
    CompositionLocalProvider(LocalSettingsInfo provides true) {
        EqualizerScreenBody(backend = previewEqBackend(), modifier = Modifier.fillMaxSize())
    }
}

@Preview(name = "Equalizer desktop dark", widthDp = 900, heightDp = 700, showBackground = true)
@Composable
private fun EqualizerDesktopDarkPreview() = PreviewFrame(dark = true) {
    CompositionLocalProvider(LocalSettingsInfo provides true) {
        EqualizerScreenBody(backend = previewEqBackend(), modifier = Modifier.fillMaxSize())
    }
}
