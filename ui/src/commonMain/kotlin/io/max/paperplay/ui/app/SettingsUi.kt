package io.max.paperplay.ui.app

import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.ModernSurfaceTier
import io.max.paperplay.ui.components.modernSurface

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.graphics.graphicsLayer

/** Page title with a back arrow. */
@Composable
fun BackTopBar(title: String, onBack: () -> Unit, modifier: Modifier = Modifier, actions: @Composable () -> Unit = {}) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val barMod = if (tokens.enabled) {
        modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp)
            .modernSurface(ModernSurfaceTier.Chrome, appShape(22.dp, CornerArea.Cards), LookGroup.Bars)
    } else {
        modifier.barSurface()
    }
    Row(barMod.padding(start = 4.dp, end = 8.dp, top = if (tokens.enabled) 8.dp else 12.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        androidx.compose.runtime.CompositionLocalProvider(io.max.paperplay.ui.components.LocalInsideModernSurface provides tokens.enabled) {
        // The arrow arrives pointing forward (the way the page was entered) and turns to point back, as the page settles.
        val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
        val turn = androidx.compose.runtime.remember { androidx.compose.animation.core.Animatable(if (reduceMotion) 180f else 0f) }
        val turnSpec = io.max.paperplay.ui.theme.motionEffectTween<Float>(
            durationMs = io.max.paperplay.ui.theme.Motion.Micro.IconTurnMs,
            delayMillis = io.max.paperplay.ui.theme.Motion.Micro.IconTurnDelayMs,
            easing = io.max.paperplay.ui.theme.Motion.Standard,
        )
        androidx.compose.runtime.LaunchedEffect(Unit) {
            if (!reduceMotion) turn.animateTo(180f, turnSpec)
        }
        IconButton(onBack) { AppIcon(Icons.Rounded.ChevronRight, "Back", Modifier.graphicsLayer { rotationZ = turn.value }) }
        Text(
            title,
            Modifier.weight(1f).padding(start = 4.dp),
            style = MaterialTheme.typography.headlineSmall,
            color = if (tokens.enabled) tokens.onGlass else androidx.compose.ui.graphics.Color.Unspecified,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
        )
        actions()
        }
    }
}

/** One rounded card per category on the Settings list. */
@Composable
fun SettingsCard(icon: ImageVector, title: String, subtitle: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val shape = appShape(if (tokens.enabled) 22.dp else 20.dp)
    val cardMod = if (tokens.enabled) {
        modifier.fillMaxWidth().modernSurface(ModernSurfaceTier.Card, shape, LookGroup.Cards)
    } else {
        modifier.fillMaxWidth().partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, shape)
    }
    Row(
        cardMod.clickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.runtime.CompositionLocalProvider(io.max.paperplay.ui.components.LocalInsideModernSurface provides tokens.enabled) {
        AppIcon(icon, null, tint = if (tokens.enabled) tokens.onGlass else MaterialTheme.colorScheme.onSurface)
        Column(Modifier.weight(1f).padding(horizontal = 16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = if (tokens.enabled) tokens.onGlass else androidx.compose.ui.graphics.Color.Unspecified)
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = if (tokens.enabled) tokens.onGlassMuted else MaterialTheme.colorScheme.onSurfaceVariant)
        }
        AppIcon(Icons.Rounded.ChevronRight, null, tint = if (tokens.enabled) tokens.onGlassMuted else MaterialTheme.colorScheme.onSurface)
        }
    }
}

/** A titled group of settings rows on one rounded card: groups are told apart by the card and its label, rows inside by thin dividers ([RowDivider]). */
@Composable
fun SettingsSection(title: String?, modifier: Modifier = Modifier, content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val shape = appShape(if (tokens.enabled) 22.dp else 20.dp)
    Column(modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
        if (title != null) Text(title, Modifier.padding(start = 8.dp, bottom = 6.dp), style = MaterialTheme.typography.titleSmall, color = if (tokens.enabled) tokens.accentOnGlass else MaterialTheme.colorScheme.primary)
        val boxMod = if (tokens.enabled) {
            Modifier.fillMaxWidth().modernSurface(ModernSurfaceTier.Card, shape, LookGroup.Cards)
        } else {
            Modifier.fillMaxWidth().partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, shape).clip(shape)
        }
        Column(boxMod) {
            androidx.compose.runtime.CompositionLocalProvider(io.max.paperplay.ui.components.LocalInsideModernSurface provides tokens.enabled) {
                content()
            }
        }
    }
}

/** A thin line between two rows of a [SettingsSection], starting after the icon (tonal spacing in Modern). */
@Composable
fun RowDivider() {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    if (tokens.enabled) {
        androidx.compose.foundation.layout.Spacer(Modifier.size(0.dp, 2.dp))
    } else {
        androidx.compose.material3.HorizontalDivider(
            Modifier.padding(start = 56.dp, end = 12.dp),
            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f),
        )
    }
}

/** True inside Settings: a row's explanation text sits behind an info button next to its title instead of under it. */
val LocalSettingsInfo = androidx.compose.runtime.staticCompositionLocalOf { false }

/** Longer subtitles explain the setting; short ones are values, such as "Logged in", and stay visible. */
private fun isExplanation(subtitle: String?) = subtitle != null && subtitle.length >= 30

/** The title with, when [explanation] is set, a small info button that shows or hides it. Same size and place in every row, so they line up. */
@Composable
private fun TitleWithInfo(title: String, explanation: String?, open: Boolean, onToggle: () -> Unit, color: androidx.compose.ui.graphics.Color, style: androidx.compose.ui.text.TextStyle) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f, fill = false), style = style, color = color)
        if (explanation != null) {
            IconButton(onToggle, Modifier.padding(start = 2.dp).size(32.dp)) {
                AppIcon(Icons.Rounded.Info, if (open) "Hide explanation" else "Explain", Modifier.size(18.dp), tint = if (open) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/** The option a Settings search result was tapped for; the row with that title scrolls into view and flashes once. */
internal var focusedSetting by mutableStateOf<String?>(null)

/** Makes a row findable from Settings search: scrolls it into view when it is the focused option and flashes its background. */
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
private fun Modifier.searchFocus(title: String): Modifier {
    val want = focusedSetting?.lowercase()
    val mine = want != null && title.lowercase().startsWith(want)
    val requester = remember { androidx.compose.foundation.relocation.BringIntoViewRequester() }
    val flash by androidx.compose.animation.animateColorAsState(
        if (mine) MaterialTheme.colorScheme.primary.copy(alpha = 0.18f) else androidx.compose.ui.graphics.Color.Transparent, label = "searchFocus",
    )
    LaunchedEffect(mine) {
        if (mine) {
            kotlinx.coroutines.delay(350)
            runCatching { requester.bringIntoView() }
            kotlinx.coroutines.delay(1800)
            if (focusedSetting?.lowercase() == want) focusedSetting = null
        }
    }
    return this.bringIntoViewRequester(requester).background(flash)
}

/** A row inside a sub-page: optional icon, title, optional subtitle, optional trailing content. */
@Composable
fun SettingsRow(
    title: String, modifier: Modifier = Modifier, icon: ImageVector? = null, subtitle: String? = null,
    onClick: (() -> Unit)? = null, enabled: Boolean = true,
    titleColor: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    iconTint: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Unspecified,
    /** Shown in place of [icon], such as a cover. */
    leading: (@Composable () -> Unit)? = null,
    // Last on purpose: a trailing lambda at a call site binds to the last parameter, and callers mean the content at the end of the row.
    trailing: @Composable () -> Unit = {},
) {
    val resolvedTitleColor = when {
        !enabled -> MaterialTheme.colorScheme.outline
        titleColor != androidx.compose.ui.graphics.Color.Unspecified -> titleColor
        else -> MaterialTheme.colorScheme.onSurface
    }
    val resolvedIconTint = when {
        !enabled -> MaterialTheme.colorScheme.outline
        iconTint != androidx.compose.ui.graphics.Color.Unspecified -> iconTint
        else -> MaterialTheme.colorScheme.onSurface
    }
    Row(
        modifier.fillMaxWidth().searchFocus(title).then(if (onClick != null && enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leading != null) Box(Modifier.padding(end = 16.dp)) { leading() }
        else if (icon != null) AppIcon(icon, null, Modifier.padding(end = 16.dp), tint = resolvedIconTint)
        Column(Modifier.weight(1f)) {
            val behindInfo = LocalSettingsInfo.current && isExplanation(subtitle)
            var open by remember { mutableStateOf(false) }
            TitleWithInfo(title, if (behindInfo) subtitle else null, open, { open = !open }, resolvedTitleColor, MaterialTheme.typography.titleMedium)
            if (subtitle != null && (!behindInfo || open)) Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        trailing()
    }
}

@Composable
fun NavRow(title: String, subtitle: String? = null, icon: ImageVector? = null, onClick: () -> Unit) =
    SettingsRow(title, icon = icon, subtitle = subtitle, onClick = onClick) { AppIcon(Icons.Rounded.ChevronRight, null) }

/** A row whose value is picked from a drop-down menu: the current choice and an arrow on the right, the options in a menu. [extra] sits before the value (a button, for example). */
@Composable
fun <T> DropdownRow(
    title: String, selected: T, options: List<T>, label: (T) -> String, onSelect: (T) -> Unit,
    icon: ImageVector? = null, subtitle: String? = null, extra: @Composable () -> Unit = {},
) {
    var open by remember { mutableStateOf(false) }
    SettingsRow(title, icon = icon, subtitle = subtitle, onClick = { open = true }) {
        extra()
        Box {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(label(selected), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.primary)
                AppIcon(Icons.Rounded.ExpandMore, null)
            }
            androidx.compose.material3.DropdownMenu(open, { open = false }) {
                options.forEach { o ->
                    androidx.compose.material3.DropdownMenuItem({ Text(label(o)) }, { open = false; onSelect(o) })
                }
            }
        }
    }
}

@Composable
fun SwitchRow(title: String, checked: Boolean, onChange: (Boolean) -> Unit, icon: ImageVector? = null, subtitle: String? = null, enabled: Boolean = true) =
    SettingsRow(title, icon = icon, subtitle = subtitle, onClick = { onChange(!checked) }, enabled = enabled) { Switch(checked, onChange, enabled = enabled) }

@Composable
fun SliderRow(title: String, value: Float, range: ClosedFloatingPointRange<Float>, onChange: (Float) -> Unit, steps: Int = 0, hint: String? = null, enabled: Boolean = true, onDone: () -> Unit = {}) {
    Column(Modifier.fillMaxWidth().searchFocus(title).padding(horizontal = 20.dp, vertical = 4.dp)) {
        val behindInfo = LocalSettingsInfo.current && hint != null
        var open by remember { mutableStateOf(false) }
        val titleColor = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.outline
        TitleWithInfo(title, if (behindInfo) hint else null, open, { open = !open }, titleColor, MaterialTheme.typography.bodyLarge)
        if (hint != null && (!behindInfo || open)) Text(hint, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Slider(value, onChange, valueRange = range, steps = steps, enabled = enabled, onValueChangeFinished = onDone)
    }
}

@Composable
fun SectionLabel(text: String) =
    Text(text, Modifier.padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 4.dp), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)

@Composable
fun <T> ChoiceRow(options: List<T>, selected: T, label: (T) -> String, onSelect: (T) -> Unit, modifier: Modifier = Modifier) =
    ChipRow(options.map(label), options.indexOf(selected).coerceAtLeast(0), { onSelect(options[it]) }, modifier)

@Composable
fun NotBuilt(what: String) {
    Column(Modifier.padding(20.dp)) {
        Text(what, style = MaterialTheme.typography.titleMedium)
        Text("Not built in this app yet.", Modifier.padding(top = 4.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun ConfirmDialog(title: String, body: String, action: String, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
    val shape = appShape(28.dp, CornerArea.Dialogs)
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = if (tokens.enabled) {
            Modifier.modernSurface(ModernSurfaceTier.Overlay, shape, LookGroup.Overlays)
        } else {
            overlayRim(shape)
        },
        shape = shape,
        containerColor = if (tokens.enabled) tokens.overlayBg else overlayColor(),
        tonalElevation = if (tokens.enabled) 0.dp else androidx.compose.material3.AlertDialogDefaults.TonalElevation,
        title = { Text(title, color = if (tokens.enabled) tokens.onGlass else androidx.compose.ui.graphics.Color.Unspecified) },
        text = { Text(body, color = if (tokens.enabled) tokens.onGlassMuted else androidx.compose.ui.graphics.Color.Unspecified) },
        confirmButton = { TextButton({ onDismiss(); onConfirm() }) { Text(action) } },
        dismissButton = { TextButton(onDismiss) { Text("Cancel") } },
    )
}

/** A round colour swatch for accent choices. */
@Composable
fun Swatch(color: androidx.compose.ui.graphics.Color, selected: Boolean, label: String, onClick: () -> Unit) {
    Column(Modifier.clickable(onClick = onClick).padding(4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier.size(44.dp).clip(CircleShape).background(color)
                .then(if (selected) Modifier.padding(0.dp) else Modifier),
            contentAlignment = Alignment.Center,
        ) { if (selected) AppIcon(Icons.Rounded.Check, null, tint = androidx.compose.ui.graphics.Color.White) }
        Text(label, style = MaterialTheme.typography.labelSmall, modifier = Modifier.padding(top = 2.dp))
    }
}

@Composable
fun SettingsColumn(content: @Composable () -> Unit) = Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(0.dp)) { content() }

@Preview
@Composable
private fun BackTopBarPreview() {
    BackTopBar(title = "Appearance", onBack = {})
}

@Preview
@Composable
private fun SettingsCardPreview() {
    SettingsCard(icon = Icons.Rounded.Check, title = "Appearance", subtitle = "Theme, colors, display", onClick = {})
}

@Preview
@Composable
private fun SettingsRowPreview() {
    SettingsRow(title = "General Settings", subtitle = "Manage general configuration", icon = Icons.Rounded.Check)
}

@Preview
@Composable
private fun NavRowPreview() {
    NavRow(title = "Channels", subtitle = "See and manage Telegram channels", onClick = {})
}

@Preview
@Composable
private fun SwitchRowPreview() {
    SwitchRow(title = "True Black", checked = true, onChange = {})
}

@Preview
@Composable
private fun SliderRowPreview() {
    SliderRow(title = "Blur: 16", value = 16f, range = 0f..40f, onChange = {})
}

@Preview
@Composable
private fun SectionLabelPreview() {
    SectionLabel(text = "Theme Customization")
}

@Preview
@Composable
private fun ChoiceRowPreview() {
    ChoiceRow(options = listOf("Dark", "Light", "System"), selected = "Dark", label = { it }, onSelect = {})
}

@Preview
@Composable
private fun NotBuiltPreview() {
    NotBuilt(what = "Spotify Import")
}

@Preview
@Composable
private fun ConfirmDialogPreview() {
    ConfirmDialog(title = "Log out?", body = "The bot credentials will be cleared.", action = "Log out", onConfirm = {}, onDismiss = {})
}

@Preview
@Composable
private fun SwatchPreview() {
    Swatch(color = androidx.compose.ui.graphics.Color.Blue, selected = true, label = "Blue", onClick = {})
}

@Preview
@Composable
private fun SettingsColumnPreview() {
    SettingsColumn {
        Text("Item 1")
        Text("Item 2")
    }
}

