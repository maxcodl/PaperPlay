@file:OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)

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
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.PhotoSizeSelectSmall
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material.icons.rounded.Cloud
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Notes
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import kotlinx.coroutines.launch
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import org.jetbrains.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.max.paperplay.ui.components.CoverImage
import com.kyant.backdrop.backdrops.layerBackdrop
import io.max.paperplay.ui.isPhone

/** The headings of the Settings list. Every [Category] names one, so none can be left out of the list. */
internal enum class CategoryGroup(val label: String) {
    Look("Look and feel"), Music("Music"), Telegram("Telegram and devices"), About("About"),
}

internal class Category(
    val id: String, val title: String, val subtitle: String, val keywords: String, val icon: ImageVector, val group: CategoryGroup,
    val phoneOnly: Boolean = false, private val desktopSubtitle: String? = null,
) {
    /** The line shown under the title; some pages have fewer options on the desktop. */
    val text: String get() = if (isPhone) subtitle else desktopSubtitle ?: subtitle
}

internal val categories = listOf(
    Category("style", "Appearance", "Theme, colors, icons, glass look, sidebar and bar", "style look glass material expressive blur theme dark amoled accent color icons nav bar sidebar floating radius selection", Icons.Rounded.AutoAwesome, CategoryGroup.Look),
    Category("glass", "Glass", "Blur and tint for every glass part", "glass blur refraction tint", Icons.Rounded.BlurOn, CategoryGroup.Look),
    Category("listening", "Listening", "ListenBrainz, volume levelling, equalizer", "listenbrainz scrobble listens loudness replaygain equalizer eq", Icons.Rounded.GraphicEq, CategoryGroup.Music),
    Category("mixes", "Mixes", "Mixes learned from your listening", "mix taste learning weather city", Icons.Rounded.AutoAwesome, CategoryGroup.Music),
    Category("library", "Library", "Repair, sorting, duplicates, rescan, song info", "speed rate rescan duplicates sort general covers info repair fix missing songs metadata organize tidy", Icons.Rounded.LibraryMusic, CategoryGroup.Music),
    Category("uploads", "Uploads", "Upload pace and skipping known songs", "upload slow skip speed parallel", Icons.Rounded.Upload, CategoryGroup.Music),
    Category("spotify", "Spotify import", "Import playlists from Spotify", "spotify playlist import", Icons.Rounded.PlaylistAdd, CategoryGroup.Music),
    Category("telegram", "Telegram", "Channels, your account, bot activity, log out", "bot channels account log tdlib logout speed reading copy", Icons.Rounded.Send, CategoryGroup.Telegram),
    Category("devices", "Devices and background", "Connect devices, keep running", "device connection sync background battery", Icons.Rounded.Devices, CategoryGroup.Telegram, desktopSubtitle = "Connect other devices"),
    Category("storage", "Storage and backup", "Cache size, backup and restore", "cache storage backup restore clear", Icons.Rounded.Storage, CategoryGroup.Telegram),
    Category("about", "About", "Version, updates and source code", "about update updates version beta release github shizuku changelog installer", Icons.Rounded.Info, CategoryGroup.About),
)

private val cacheLimits = listOf(1L shl 29, 1L shl 30, 2L shl 30, 5L shl 30, 10L shl 30, 20L shl 30, 50L shl 30)
/** True while Clear cache or Shrink covers runs; the Storage page then measures every second. */
private val storageBusy = androidx.compose.runtime.mutableStateOf(false)

/** Disk use in decimal units, the way Android's App info shows it, so the two numbers match. */
private fun diskText(b: Long) = if (b >= 1_000_000_000L) "${(b / 10_000_000L) / 100.0} GB" else "${b / 1_000_000L} MB"
private fun bytesText(b: Long) = if (b >= 1L shl 30) "${b / (1L shl 30)} GB" else "${b / (1L shl 20)} MB"

private class RateWork(val key: String, val label: String, val default: Int)

private val rateWorks = mapOf(
    "reading" to RateWork("rate_reading", "Reading channels", 20),
    "accountCopy" to RateWork("rate_accountCopy", "Copying from your chats", 20),
    "filing" to RateWork("rate_filing", "Copying, moving and deleting songs", 12),
    "lookups" to RateWork("rate_lookups", "Song info, lyrics and genre", 50),
    "covers" to RateWork("rate_covers", "Covers", 40),
    "uploads" to RateWork("rate_uploads", "Uploads", 6),
)

/**
 * The Settings pages. [stack] holds the open page ids (empty shows the list), so the shell's back handler can pop it.
 */
@Composable
fun SettingsHost(
    stack: MutableList<String>, prefs: UiPrefs, conn: ConnectionUi, songCount: Int, backend: CoreBackend,
    onRestore: () -> Unit, onExit: () -> Unit, bottomPadding: Dp, modifier: Modifier = Modifier, deep: Boolean = false,
) {
    val reduceMotion = io.max.paperplay.ui.theme.LocalReduceMotion.current
    // A page opened from the list slides in; going back slides out. The page leaving keeps drawing itself.
    androidx.compose.animation.AnimatedContent(
        targetState = stack.lastOrNull() to stack.size,
        modifier = modifier,
        transitionSpec = { pageTransition(navMove(initialState.second, targetState.second), reduceMotion) },
        label = "settings",
    ) { (page, _) ->
        SettingsScreen(page, stack, prefs, conn, songCount, backend, onRestore, onExit, bottomPadding, deep)
    }
}

@Composable
private fun SettingsScreen(
    page: String?, stack: MutableList<String>, prefs: UiPrefs, conn: ConnectionUi, songCount: Int, backend: CoreBackend,
    onRestore: () -> Unit, onExit: () -> Unit, bottomPadding: Dp, deep: Boolean,
) {
    val goBack: () -> Unit = { if (stack.isEmpty() || (deep && stack.size <= 1)) onExit() else stack.removeAt(stack.lastIndex) }
    if (page == "stats" && isPhone) {
        AndroidStatsScreen(
            backend = backend,
            onBack = goBack,
            onStartListening = onExit,
            bottomPadding = bottomPadding,
        )
        return
    }
    val title = categories.firstOrNull { it.id == page }?.title ?: settingsPageTitle(page) ?: "Settings"
    Column(Modifier.fillMaxSize()) {
        BackTopBar(title, onBack = goBack) {
            val loggedIn by backend.account.loggedIn.collectAsState()
            if (page == "channels" && loggedIn) IconButton({ stack.add("index") }) { AppIcon(Icons.Rounded.Forum, "Your chats and channels") }
            if (page == "eq") EqualizerTopBarActions(backend)
        }
        // The chat pages hold long lists, so they scroll lazily instead of inside the shared scroll column.
        val isLazy = page == "index" || page == "missing" || page == "log" || page == "changelog" || page == "eq" || page?.startsWith("index:") == true
        if (page == "index") IndexPage(backend, stack, bottomPadding)
        else if (page == "dupes") DuplicatesPage(backend, bottomPadding)
        else if (page != null && page.startsWith("index:")) ChatSongsPage(backend, page.removePrefix("index:").toLongOrNull() ?: 0L, stack, bottomPadding)
        else Column(
            Modifier.fillMaxSize()
                // A scrolling page keeps the room for the bottom bar as padding at its end. A lazy list pads its own content instead
                // (LocalPageBottomPadding), so it scrolls under the bar and is not cut off at a hard edge above it.
                .then(if (isLazy) Modifier else Modifier.verticalScroll(rememberScrollState()).padding(bottom = bottomPadding))
        ) {
            androidx.compose.runtime.CompositionLocalProvider(LocalPageBottomPadding provides bottomPadding) {
                if (page == null) SettingsList(prefs, stack) else SettingsPage(page, stack, prefs, conn, songCount, backend, onRestore)
            }
        }
    }
}

/** The room a Settings page leaves for the bottom bar, for pages that are one lazy list. */
internal val LocalPageBottomPadding = androidx.compose.runtime.compositionLocalOf { 0.dp }

internal val subTitles = mapOf(
    "channels" to "Channels and chats", "bots" to "Bots", "account" to "Your account", "log" to "Activity log",
    "repair" to "Scan library", "recover" to "Recover songs", "folders" to "Music folders", "exports" to "Saved export lists", "cache" to "Cache manager", "sort" to "Sort General", "dupes" to "Find duplicates", "missing" to "Song info left", "uploadhub" to "Upload songs", "mixlearn" to "Mixes and learning", "weather" to "Weather",
    "permissions" to "Permissions", "conn" to "Connection", "netplay" to "Network play", "index" to "Chats and channels", "eq" to "Equalizer", "listenbrainz" to "ListenBrainz", "stats" to "Listening statistics", "credentials" to "Bots", "profile" to "Profile", "usb_audio" to "USB DAC", "usb_probe" to "USB probe", "motion_lab" to "Motion Lab", "changelog" to "Change log",
)

@Composable
private fun SettingsList(prefs: UiPrefs, stack: MutableList<String>) {
    var query by remember { mutableStateOf("") }
    val q = query.trim().lowercase()
    val shown = categories.filter { (!it.phoneOnly || isPhone) && (q.isEmpty() || q in "${it.title} ${it.subtitle} ${it.keywords}".lowercase()) }
    Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        PillField(query, { query = it }, "Search settings")
        Spacer(Modifier.height(12.dp))
        if (q.isEmpty()) {
            val tokens = io.max.paperplay.ui.theme.LocalModernTokens.current
            val profileCardMod = if (tokens.enabled) {
                Modifier.fillMaxWidth().padding(bottom = 12.dp)
                    .modernSurface(ModernSurfaceTier.Card, appShape(28.dp), LookGroup.Cards)
            } else {
                Modifier.fillMaxWidth().padding(bottom = 12.dp).partSurface(LookGroup.Cards, MaterialTheme.colorScheme.surfaceContainerLow, appShape(28.dp))
            }
            Row(
                profileCardMod.clickableRow { stack.add("profile") }.padding(horizontal = 20.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Avatar(prefs.profilePhoto, prefs.profileName, 60.dp)
                Text(prefs.profileName, Modifier.weight(1f).padding(start = 16.dp), style = MaterialTheme.typography.titleLarge, color = if (tokens.enabled) tokens.onGlass else androidx.compose.ui.graphics.Color.Unspecified)
                AppIcon(Icons.Rounded.ChevronRight, null, tint = if (tokens.enabled) tokens.onGlassMuted else MaterialTheme.colorScheme.onSurface)
            }
        }
        val tour = io.max.paperplay.ui.LocalAppEnv.current?.showTour
        val tourShown = tour != null && (q.isEmpty() || "welcome tour intro".contains(q))
        for (group in CategoryGroup.entries) {
            val inGroup = shown.filter { it.group == group }
            val withTour = tourShown && group == CategoryGroup.About
            if (inGroup.isEmpty() && !withTour) continue
            SectionLabel(group.label)
            if (withTour) SettingsCard(Icons.Rounded.MusicNote, "Welcome tour", "Show the introduction again", { tour!!.value = true })
            inGroup.forEach { c -> SettingsCard(c.icon, c.title, c.text, { stack.add(c.id) }) }
        }
        val hits = if (q.isEmpty()) emptyList() else settingHits.filter { q in "${it.title} ${it.extra}".lowercase() }
        if (hits.isNotEmpty()) {
            SectionLabel("Options")
            hits.forEach { x ->
                val where = categories.firstOrNull { it.id == x.page }?.title ?: subTitles[x.page]
                SettingsCard(Icons.Rounded.Tune, x.title, where.orEmpty(), { focusedSetting = x.title; stack.add(x.page) })
            }
        }
        if (shown.isEmpty() && !tourShown && hits.isEmpty()) Text("No settings match", Modifier.padding(24.dp))
        if (q.isEmpty()) MadeBy()
    }
}

private fun Modifier.clickableRow(onClick: () -> Unit): Modifier = this.then(Modifier.clickable(onClick = onClick))

@Composable
fun Avatar(photo: String?, name: String, size: Dp) {
    // Onboarding shows the photo before the main screen (which provides the image loader) exists, so it brings its own.
    if (photo != null) {
        if (io.max.paperplay.ui.components.LocalCoverLoader.current == null) {
            androidx.compose.runtime.CompositionLocalProvider(io.max.paperplay.ui.components.LocalCoverLoader provides SharedCovers.loader) {
                CoverImage(photo, "avatar", size = size, radius = size / 2)
            }
        } else CoverImage(photo, "avatar", size = size, radius = size / 2)
    }
    else Box(Modifier.size(size).clip(CircleShape).background(MaterialTheme.colorScheme.primaryContainer), contentAlignment = Alignment.Center) {
        Text(name.firstOrNull()?.uppercase() ?: "?", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onPrimaryContainer)
    }
}

@Composable
internal fun SettingsPage(
    id: String, stack: MutableList<String>, prefs: UiPrefs, conn: ConnectionUi, songCount: Int, backend: CoreBackend, onRestore: () -> Unit,
) {
    var confirm by remember { mutableStateOf<String?>(null) }
    val notice = remember { mutableStateOf<String?>(null) }
    val env = io.max.paperplay.ui.LocalAppEnv.current
    fun pref(k: String) = backend.pref(k)
    when (id) {
        "style" -> {
            if (isPhone) UiStyleSettings(prefs)
            SectionLabel("Theme")
            ChoiceRow(ThemeMode.entries, prefs.themeMode, { it.label }, prefs::putThemeMode)
            SectionLabel("Icons")
            ChoiceRow(IconSet.entries, prefs.iconSet, { it.label }, prefs::putIconSet)
            Text("Applies to the app on Android and desktop. Only the icons used by PaperPlay are included.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SwitchRow("True black", prefs.amoled, prefs::putAmoled, Icons.Rounded.DarkMode, "Pure black surfaces on dark, easier on OLED screens")
            SwitchRow("Reduce motion", prefs.reduceMotion, prefs::putReduceMotion, null, "Screens and the player switch instantly instead of sliding and fading")
            SwitchRow("Home animation", prefs.homeAnimation, prefs::putHomeAnimation, null, "Tiles and cards fly in when Home first appears")
            SectionLabel("Accent")
            androidx.compose.foundation.layout.FlowRow(Modifier.padding(horizontal = 16.dp)) {
                if (isPhone) {
                    Swatch(MaterialTheme.colorScheme.primary, prefs.accent == "dynamic", "Dynamic") { prefs.putAccent("dynamic") }
                    Swatch(MaterialTheme.colorScheme.tertiary, prefs.accent == "cover", "Cover") { prefs.putAccent("cover") }
                } else {
                    // No wallpaper colour on the desktop: the accent follows the playing song's cover.
                    Swatch(MaterialTheme.colorScheme.tertiary, prefs.accent == "cover" || prefs.accent == "dynamic", "Album art") { prefs.putAccent("cover") }
                }
                accentOptions.forEach { a -> Swatch(Color(a.color), prefs.accent == a.id, a.label) { prefs.putAccent(a.id) } }
            }
            SectionLabel("Display")
            BackgroundSettings(prefs)
            ProgressBarStyleSettings(prefs, backend)
            if (isPhone) PlayerStyleSettings(prefs)
            SectionLabel("Corners")
            Text("Each part has its own corner size. The first slider sets them all, the sidebar and the player bar too; the sidebar and bar sliders are further down.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SliderRow("All corners: ${prefs.cornerRadius.toInt()}%", prefs.cornerRadius, 0f..100f, { prefs.putCornerRadius(it) })
            for (a in CornerArea.entries.filter { !isPhone || it != CornerArea.Panels }) {
                SliderRow("${a.label}: ${prefs.radius(a).toInt()}%", prefs.radius(a), 0f..100f, { prefs.putRadius(a, it) })
            }
            SectionLabel("Look")
            Text("Pick Material 3 or glass for each part, or all at once.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            SectionLabel("All parts")
            // On desktop the nav part is the sidebar, drawn with blur and tint like the cards.
            val groups = LookGroup.entries.filter { !isPhone || it != LookGroup.Player }
            ChoiceRow(Look.entries, if (groups.all { prefs.look(it) == Look.Glass }) Look.Glass else Look.Material, { it.name }, { l ->
                groups.forEach { prefs.setLook(it, l) }
            })
            if (!io.max.paperplay.ui.glassLensSupported()) {
                Text("On desktop, glass is blur, tint and gradient. The sidebar uses the Navigation setting; blur and tint are on the Glass page.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            @Composable
            fun part(g: LookGroup) {
                SectionLabel(g.label)
                Text(g.hint, Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                ChoiceRow(Look.entries, prefs.look(g), { it.name }, { prefs.setLook(g, it) })
            }
            // Wide screens lay the parts out two to a row instead of one long column.
            // The player bar's background has its own choice (transparent, card or glass) further down.
            val listed = groups.filter { it != LookGroup.Player }
            if (isPhone) listed.forEach { part(it) } else androidx.compose.foundation.layout.FlowRow(
                Modifier.fillMaxWidth(), maxItemsInEachRow = 2,
            ) { listed.forEach { g -> Column(Modifier.weight(1f)) { part(g) } } }
            SectionLabel(if (isPhone) "Navigation bar" else "Sidebar")
            NavSettings(prefs)
            if (!isPhone) PlayerBarSettings(prefs)
        }
        "nav" -> NavSettings(prefs)
        "glass" -> {
            GlassPreview(prefs)
            Text("Applies to every part set to Glass on the Appearance page.", Modifier.padding(horizontal = 20.dp, vertical = 12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
            val g = prefs.glass
            SectionLabel("Material")
            if (!isPhone) SwitchRow("Blur the background", prefs.desktopBlur, prefs::putDesktopBlur, null, "Off is much faster; glass is then a tint and an edge line")
            SliderRow("Blur: ${g.blur.toInt()} dp", g.blur, 0f..40f, { prefs.updateGlass(g.copy(blur = it)) })
            if (io.max.paperplay.ui.glassLensSupported()) {
                SliderRow("Refraction height: ${g.lensHeight.toInt()} dp", g.lensHeight, 0f..48f, { prefs.updateGlass(g.copy(lensHeight = it)) })
                SliderRow("Refraction amount: ${g.lensAmount.toInt()} dp", g.lensAmount, 0f..48f, { prefs.updateGlass(g.copy(lensAmount = it)) })
            }
            SliderRow("Colour saturation: ${"%.2f".format(g.saturation)}", g.saturation, 0f..2.5f, { prefs.updateGlass(g.copy(saturation = it)) })
            SliderRow("Tint: ${(g.tint * 100).toInt()}%", g.tint, 0f..1f, { prefs.updateGlass(g.copy(tint = it)) })
            if (io.max.paperplay.ui.glassLensSupported()) {
                SwitchRow("Depth effect", g.depth, { prefs.updateGlass(g.copy(depth = it)) })
                SwitchRow("Colour fringing", g.chromatic, { prefs.updateGlass(g.copy(chromatic = it)) })
            }
            SectionLabel("Edge")
            SliderRow("Edge line width: ${"%.1f".format(g.edgeWidth)} dp", g.edgeWidth, 0f..4f, { prefs.updateGlass(g.copy(edgeWidth = it)) })
            SliderRow("Edge brightness: ${"%.2f".format(g.edgeAlpha)}", g.edgeAlpha, 0f..1f, { prefs.updateGlass(g.copy(edgeAlpha = it)) })
            Text("Edge reflection", Modifier.padding(horizontal = 20.dp, vertical = 4.dp), style = MaterialTheme.typography.bodyLarge)
            ChoiceRow(listOf(0, 1, 2), g.edgeStyle, { listOf("Directional", "Ambient", "Plain")[it] }, { prefs.updateGlass(g.copy(edgeStyle = it)) })
            SectionLabel("Shadow")
            SliderRow("Outer shadow size: ${g.shadowRadius.toInt()} dp", g.shadowRadius, 0f..40f, { prefs.updateGlass(g.copy(shadowRadius = it)) })
            SliderRow("Outer shadow strength: ${"%.2f".format(g.shadowAlpha)}", g.shadowAlpha, 0f..0.5f, { prefs.updateGlass(g.copy(shadowAlpha = it)) })
            SliderRow("Inner glow size: ${g.innerRadius.toInt()} dp", g.innerRadius, 0f..40f, { prefs.updateGlass(g.copy(innerRadius = it)) })
            SliderRow("Inner glow strength: ${"%.2f".format(g.innerAlpha)}", g.innerAlpha, 0f..0.5f, { prefs.updateGlass(g.copy(innerAlpha = it)) })
            OutlinedButton({ prefs.updateGlass(GlassStyle()) }, Modifier.padding(horizontal = 20.dp, vertical = 12.dp)) { Text("Reset to defaults") }
            if (LookGroup.entries.none { prefs.look(it) == Look.Glass }) {
                Text("No part uses Glass yet. Choose it on the Appearance page.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
            }
            if (!io.max.paperplay.ui.glassLensSupported()) {
                Text("Glass here is blur, tint and gradient.", Modifier.padding(20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else if (!io.max.paperplay.ui.glassEffectsSupported()) {
                Text("Blur needs Android 12 or newer; this device gets a plain tint.", Modifier.padding(20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                Text("Dialogs, sheets and menus open in their own window, so they get the tint but not the blur.", Modifier.padding(20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        "telegram" -> {
            val accountStep by backend.account.step.collectAsState()
            SettingsSection("Connections") {
                NavRow("Channels and chats", "Added channels, the main chat, and your own chats and channels", Icons.Rounded.Forum) { stack.add("channels") }
                RowDivider()
                NavRow("Bots", "Main bot credentials and extra bots for uploading", Icons.Rounded.SmartToy) { stack.add("bots") }
                RowDivider()
                NavRow(
                    "Your account (optional)",
                    if (accountStep == io.max.paperplay.core.account.LoginStep.Ready) "Logged in. Your chats can be read and copied from" else "Logged out. Log in as yourself to read and copy from your chats",
                    Icons.Rounded.Person,
                ) { stack.add("account") }
            }
            SettingsSection("Diagnostics") {
                NavRow("Activity log", "Reads, downloads, uploads, rate limits and problems. Search, copy and save", Icons.Rounded.MonitorHeart) { stack.add("log") }
            }
            SettingsSection("Log out") {
                SettingsRow("Log out", icon = Icons.Rounded.Logout, subtitle = "Your account (if logged in) and the main bot. The library stays on this device", onClick = { confirm = "logout" })
                RowDivider()
                SettingsRow("Log out the bot only", icon = Icons.Rounded.SmartToy, subtitle = "Forgets the main bot's credentials. Your account stays logged in", onClick = { confirm = "logoutbot" })
                RowDivider()
                SettingsRow("Log out the account only", icon = Icons.Rounded.Person, subtitle = "Your own login. The bot stays connected", onClick = { confirm = "accountout" })
            }
            SettingsSection("Danger zone") {
                SettingsRow("Log out and delete all data", icon = Icons.Rounded.DeleteForever, subtitle = "Removes the library and everything else from this device, for a fresh start", onClick = { confirm = "erase" })
            }
        }
        "library" -> {
            // What it is doing now, then the actions that matter, then upkeep, then the settings that fold open.
            SettingsSection("Overview") { LibraryStatusRows(backend) { stack.add("missing") } }
            SettingsSection("Main tools") {
                NavRow("Scan library", "Read every chat with the bots and account you pick, fill in what is missing", Icons.Rounded.Sync) { stack.add("repair") }
                RowDivider()
                NavRow("Find duplicates", "Repeated songs in your main chat, and deleting them", Icons.Rounded.ContentCopy) { stack.add("dupes") }
                RowDivider()
                NavRow("Sort General", "Suggests topics for songs in General. Nothing moves till you confirm", Icons.Rounded.DriveFileMove) { stack.add("sort") }
            }
            SettingsSection("Upkeep") {
            SettingsRow(
                "Fix compilation covers", icon = Icons.Rounded.Album,
                subtitle = "Songs filed under a hits compilation (Bravo Hits, Top 100) get that album's generic cover. This clears their album and cover so the next scan finds the real ones. Songs you edited stay",
                onClick = { notice.value = "Reset ${backend.resetCompilationInfo()} songs. Run Scan library to look them up again" },
            )
                RowDivider()
            SettingsRow(
                "Clear deleted songs", icon = Icons.Rounded.CleaningServices,
                subtitle = "Checks the songs the bot can't reach with your account and removes the ones whose post was deleted from Telegram. Songs that still exist stay",
                onClick = { backend.clearDeletedLibraryOnly { notice.value = it } },
            )
                RowDivider()
            SettingsRow(
                "Clear the deletion record", icon = Icons.Rounded.DeleteSweep,
                subtitle = "Songs you deleted are remembered so other devices remove them too. Clear it if a song was removed by mistake; no song is deleted by clearing",
                onClick = { notice.value = "Cleared ${backend.clearDeletionRecord()} entries" },
            )
            }
            SettingsSection("Settings") {
            SettingsGroup("Speeds", "How fast the app asks Telegram for things", Icons.Rounded.Speed) {
                RateSlider("reading", backend, notice)
                var auto by remember { mutableStateOf(pref("reading_auto") == "true") }
                SwitchRow(
                    "Adjust the reading speed by itself", auto, { auto = it; backend.setPref("reading_auto", "$it") }, Icons.Rounded.Speed,
                    "Starts at the speed above, speeds up while Telegram keeps answering and slows down after a rate limit. It remembers what worked, up to what your account and Telegram allow.",
                )
                RateSlider("filing", backend, notice)
                RateSlider("lookups", backend, notice)
                RateSlider("covers", backend, notice)
            }
                RowDivider()
            SettingsGroup("Song info, covers and lyrics", "Looking things up in the background", Icons.Rounded.Lyrics) {
                var fastLookups by remember { mutableStateOf(pref("lookups_fast") != "false") }
                SwitchRow(
                    "Fast song info", fastLookups, { fastLookups = it; backend.setPref("lookups_fast", "$it") }, Icons.Rounded.Speed,
                    "When Deezer is sure of a song (same title, artist and length) its answer is used and the slower sources are skipped. Turn off to ask every source for every song: slower, with a little more detail.",
                )
            val lyricsRunning by backend.lyricsRunning.collectAsState()
            var lyricsAuto by remember { mutableStateOf(backend.lyricsAuto) }
            SwitchRow("Fill in missing info in the background", lyricsAuto, { lyricsAuto = it; backend.setLyricsAuto(it) }, Icons.Rounded.Lyrics, "Looks up song info, covers, genres and lyrics for songs that lack them, ahead of time. Needs song lookups on")
            val scripts = listOf("", "Devanagari script", "Tamil script", "Telugu script", "Kannada script", "Malayalam script", "Gurmukhi script", "Bengali script", "Arabic script", "Japanese", "Korean", "Chinese characters", "Cyrillic", "Latin letters")
            var script by remember { mutableStateOf(pref("lyrics_script").orEmpty()) }
            Text("Lyrics writing", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodyLarge)
            Text("Picks lyrics in this writing when a source has them, even if only a plain version exists. New lookups only; Auto takes the best timed one", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            ChoiceRow(scripts, script, { if (it.isEmpty()) "Auto" else it.removeSuffix(" script").removeSuffix(" letters") }, { script = it; backend.setPref("lyrics_script", it) })
            SettingsRow(
                if (lyricsRunning) "Stop fetching lyrics" else "Fetch missing lyrics",
                icon = Icons.Rounded.Lyrics,
                subtitle = "Looks up lyrics on LRCLIB for songs without them. Progress shows in Tasks",
                onClick = { if (lyricsRunning) backend.stopLyricsRun() else backend.startLyricsRun() },
            )
            }
            }
            SettingsSection("More tools") {
                NavRow("Music folders", "Songs on this device, optionally sent to Telegram", Icons.Rounded.Folder) { stack.add("folders") }
                RowDivider()
                NavRow("Recover songs the bot cannot read", "Songs another bot posted. Your account posts them again", Icons.Rounded.Restore) { stack.add("recover") }
                RowDivider()
                NavRow("Saved export lists", "Songs not in your library, with Spotify and Apple Music links", Icons.Rounded.IosShare) { stack.add("exports") }
            }
        }
        "mixes" -> {
            NavRow("Mixes and learning", "What your taste is learned from, and clearing it", Icons.Rounded.AutoAwesome) { stack.add("mixlearn") }
            NavRow("Weather", "Your city, for the weather on the standby screen", Icons.Rounded.Cloud) { stack.add("weather") }
        }
        "uploads" -> {
            NavRow("Upload songs", "Pick songs, see the queue, retry failures", Icons.Rounded.Upload) { stack.add("uploadhub") }
            RateSlider("uploads", backend, notice)
            var parallel by remember { mutableStateOf((pref("upload_parallel")?.toIntOrNull() ?: 6).coerceIn(1, 20)) }
            SliderRow("Uploads at once: $parallel", parallel.toFloat(), 1f..20f, { parallel = it.toInt() }, steps = 18,
                hint = "Telegram lets a bot post about 20 messages a minute in one group, so keep this modest.",
                onDone = { backend.setPref("upload_parallel", "$parallel") })
            var slower by remember { mutableStateOf(pref("upload_slower") == "true") }
            SwitchRow("Upload more slowly", slower, { slower = it; backend.setPref("upload_slower", "$it") }, Icons.Rounded.HourglassBottom, "Each upload waits three times longer between songs. For really big uploads.")
            var skip by remember { mutableStateOf(pref("upload_skip_known") != "false") }
            SwitchRow("Skip songs already in my library", skip, { skip = it; backend.setPref("upload_skip_known", "$it") }, Icons.Rounded.Rule, "Matches the file name and size")
        }
        "spotify" -> SpotifyPage(backend)
        "listening" -> {
            val devUnlocked by backend.devOptionsUnlocked.collectAsState()
            val bitPerfect by backend.bitPerfect.collectAsState()
            if (isPhone && !bitPerfect) {
                val pendingHint by backend.pendingUsbDiscoveryHint.collectAsState()
                pendingHint?.let { hint ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 6.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                            .padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = "USB DAC detected: ${hint.deviceName} (${hint.vidPid})",
                            style = MaterialTheme.typography.titleSmall,
                        )
                        Text(
                            text = "Enable Bit-perfect to stream directly to this USB DAC without Android mixing or DSP?",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Button(onClick = {
                                backend.setBitPerfect(true)
                                backend.dismissUsbDiscoveryHint(hint.vidPid)
                            }) {
                                Text("Enable Bit-perfect")
                            }
                            TextButton(onClick = { backend.dismissUsbDiscoveryHint(hint.vidPid) }) {
                                Text("Dismiss")
                            }
                        }
                    }
                }
            }
            if (!isPhone) {
                var engine by remember { mutableStateOf(backend.pcEngine()) }
                SwitchRow("Use the mpv audio engine", engine == "mpv", { engine = if (it) "mpv" else "vlc"; backend.setPcEngine(engine) }, Icons.Rounded.GraphicEq,
                    "Equalizer with bass, exclusive output and earphone profiles. Needs libmpv next to the app; without it the player stays on VLC. Restart to apply")
            }
            // Unified Bit-perfect switch across Android and desktop.
            SwitchRow(
                "Bit-perfect",
                bitPerfect,
                backend::setBitPerfect,
                io.max.paperplay.ui.components.TrueAudioIcon,
                if (isPhone) {
                    "Streams eligible audio untouched through verified USB DACs or bit-perfect mixers. Equalizer, bass, normalise and profile are bypassed. Off by default."
                } else {
                    "mpv engine only. Takes the sound device for itself so the samples reach it unchanged, with no equalizer, levelling or profile. Other apps are silent meanwhile"
                },
            )
            if (isPhone) {
                NavRow("USB DAC", "Direct USB Audio Class playback, hardware volume, and status", Icons.Rounded.Usb) { stack.add("usb_audio") }
            }
            NavRow("Listening statistics", "Time listened, top songs and artists", Icons.Rounded.BarChart) { stack.add("stats") }
            NavRow("ListenBrainz", "Send what you listen to", Icons.Rounded.Sync) { stack.add("listenbrainz") }
            NavRow("Equalizer", icon = io.max.paperplay.ui.components.EqualizerBoardIcon) { stack.add("eq") }
            val levelOn by backend.normalizeOn.collectAsState()
            SwitchRow("Even out loudness", levelOn, backend::setNormalize, Icons.Rounded.GraphicEq,
                if (isPhone) "Pulls loud peaks down and lifts quiet songs. Needs Android 9 or newer" else "Evens out loud and quiet songs. Applies from the next song")
            if (!isPhone) {
                var taskbar by remember { mutableStateOf(backend.taskbarButtons()) }
                SwitchRow("Taskbar player buttons", taskbar, { taskbar = it; backend.setTaskbarButtons(it) }, Icons.Rounded.GraphicEq,
                    "Previous, play or pause and next under the taskbar preview of the window. Restart to apply")
                var profileOpen by remember { mutableStateOf(false) }
                val profile by backend.correctionProfile.collectAsState()
                SettingsRow("Earphone correction profile", icon = io.max.paperplay.ui.components.EqualizerBoardIcon,
                    subtitle = if (profile.isBlank()) "None. mpv engine only" else "On, ${io.max.paperplay.player.CorrectionProfile.parse(profile)?.size ?: 0} points",
                    onClick = { profileOpen = true })
                if (profileOpen) CorrectionProfileDialog(profile, { backend.setCorrectionProfile(it); profileOpen = false }) { profileOpen = false }
            }
            var restore by remember { mutableStateOf(backend.sessionRestore) }
            SwitchRow("Restore last session", restore, { restore = it; backend.setSessionRestore(it) }, Icons.Rounded.Sync,
                "Opens with the last queue and position, paused")
            if (devUnlocked) {
                SectionLabel("Developer")
                NavRow("Motion Lab", "Live-tune motion tokens and inspect frame timings", Icons.Rounded.Animation) { stack.add("motion_lab") }
                val previewMode by uiPreviewOverride.collectAsState()
                DropdownRow(
                    title = "Profile & Stats preview",
                    selected = previewMode,
                    options = UiPreviewOverride.entries,
                    label = { it.label },
                    onSelect = { uiPreviewOverride.value = it },
                    icon = Icons.Rounded.Visibility,
                    subtitle = "In-memory UI state override for Profile & Stats without touching your data",
                )
            }
            if (isPhone && devUnlocked) {
                val chain by backend.sinkChain.collectAsState()
                val devApi34 by backend.devApi34Mixer.collectAsState()
                val devUnified by backend.devUseUnifiedBitPerfect.collectAsState()
                SwitchRow(
                    "Unified Bit-perfect engine",
                    devUnified,
                    backend::setDevUseUnifiedBitPerfect,
                    Icons.Rounded.Tune,
                    "Switch between the unified Bit-perfect path (default) and legacy USB sink at runtime without rebuilding.",
                )
                env?.crashDiagnostics?.let { isOn ->
                    var diag by remember { mutableStateOf(isOn()) }
                    SwitchRow(
                        "Crash diagnostics", diag, { diag = it; env.setCrashDiagnostics(it) }, Icons.Rounded.BugReport,
                        "Adds memory jumps to the log. After an out of memory crash the log lists what filled the memory; the snapshot behind it (up to about 500 MB) is deleted at the next start.",
                    )
                }
                NavRow("USB probe", "Hardware descriptor probe and bit-perfect mixer spike", Icons.Rounded.BugReport) { stack.add("usb_probe") }
                SwitchRow(
                    "API 34+ bit-perfect mixer",
                    devApi34,
                    backend::setDevApi34Mixer,
                    Icons.Rounded.Science,
                    "Experimental Android 14+ integer 24/32-bit USB mixer route (5-gate verified). Off by default.",
                )
                DropdownRow(
                    title = "Sink chain",
                    selected = io.max.paperplay.player.SinkChainMode.fromId(chain),
                    options = io.max.paperplay.player.SinkChainMode.entries,
                    label = { it.label },
                    onSelect = { backend.setSinkChain(it.id) },
                    icon = Icons.Rounded.Build,
                    subtitle = when (io.max.paperplay.player.SinkChainMode.fromId(chain)) {
                        io.max.paperplay.player.SinkChainMode.FULL -> "Full: UsbAudioSink + EngineAudioSink (float on) + DefaultAudioSink. Swipe close and reopen app to apply"
                        io.max.paperplay.player.SinkChainMode.NO_DSP_FLOAT_ON -> "No DSP (float on): EngineAudioSink forced inactive, sinkFloat=true. Swipe close and reopen app to apply"
                        io.max.paperplay.player.SinkChainMode.NO_DSP_FLOAT_OFF -> "No DSP (float off): EngineAudioSink forced inactive, sinkFloat=false. Swipe close and reopen app to apply"
                        io.max.paperplay.player.SinkChainMode.PLAIN_FLOAT_OFF -> "Plain (float off): DefaultAudioSink only, sinkFloat=false (UsbAudioSink & EngineAudioSink bypassed). Restart app to apply"
                        io.max.paperplay.player.SinkChainMode.PLAIN_FLOAT_ON -> "Plain (float on): DefaultAudioSink only, sinkFloat=true (UsbAudioSink & EngineAudioSink bypassed). Restart app to apply"
                    },
                )
            }
        }
        "stats" -> StatsPage(backend)
        "listenbrainz" -> ListenBrainzPage(backend)
        "eq" -> EqualizerPage(backend)
        "usb_audio" -> UsbAudioPage(backend, stack)
        "usb_probe" -> UsbProbePage(backend)
        "motion_lab" -> MotionLabPage()
        "devices" -> {
            if (isPhone) {
                var keep by remember { mutableStateOf(pref("keep_running") == "true") }
                SwitchRow("Keep running in the background", keep, { keep = it; backend.setPref("keep_running", "$it"); env?.setKeepRunning?.invoke(it) },
                    Icons.Rounded.Sync, "Syncing carries on after you leave. A notification shows what the app is doing")
            } else {
                var keep by remember { mutableStateOf(pref("keep_running") != "false") }
                SwitchRow("Keep running in the background", keep, { keep = it; backend.setPref("keep_running", "$it") },
                    Icons.Rounded.Sync, "The close button hides the window to the tray and music keeps playing. Off: closing quits the app")
            }
            if (env?.permissions != null) NavRow("Permissions", "Notifications, music files, Bluetooth and battery: what is allowed", Icons.Rounded.Security) { stack.add("permissions") }
            NavRow("Connection", "Devices on this network, pairing, addresses and encryption", Icons.Rounded.SettingsEthernet) { stack.add("conn") }
            NavRow("Network play", "Listen together with people on the same network", Icons.Rounded.Devices) { stack.add("netplay") }
        }
        "storage" -> {
            var limit by remember { mutableStateOf(pref("cache_limit")?.toLongOrNull() ?: (2L shl 30)) }
            val idx = cacheLimits.indexOfFirst { it >= limit }.coerceAtLeast(0)
            // Measured on disk off the main thread; measured again after a clear or shrink (they set the notice).
            // Measured again every second while a clear or shrink runs, so the sizes count down as files go.
            val parts by androidx.compose.runtime.produceState<List<Pair<String, Long>>?>(null, notice.value, storageBusy.value) {
                do {
                    value = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { runCatching { backend.storageBreakdown() }.getOrNull() }
                    if (storageBusy.value) kotlinx.coroutines.delay(1_000)
                } while (storageBusy.value)
            }
            SectionLabel("On this device")
            SettingsRow(parts?.let { "Total: ${diskText(it.sumOf { p -> p.second })}" } ?: "Measuring...", icon = Icons.Rounded.Storage)
            parts?.forEach { (name, bytes) ->
                val icon = when (name) {
                    "Songs" -> Icons.Rounded.MusicNote
                    "Covers" -> Icons.Rounded.Image
                    "Lyrics" -> Icons.Rounded.Notes
                    "Song info" -> Icons.Rounded.Info
                    "Telegram data" -> Icons.Rounded.Cloud
                    else -> Icons.Rounded.Folder
                }
                SettingsRow(name, icon = icon) { Text(diskText(bytes), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
            SectionLabel("Song cache")
            SliderRow("Cache limit: ${bytesText(cacheLimits[idx])}", idx.toFloat(), 0f..(cacheLimits.size - 1f), { limit = cacheLimits[it.toInt()] }, steps = cacheLimits.size - 2,
                hint = "Shared by the main bot, your account and each extra bot. Pinned songs are not counted",
                onDone = { backend.setPref("cache_limit", "$limit") })
            NavRow("Cache manager", "Songs stored on this device, unpin and clear", Icons.Rounded.Storage) { stack.add("cache") }
            SettingsRow("Clear cache", icon = Icons.Rounded.CleaningServices, subtitle = "Deletes streamed songs stored on this device. They download again when played", onClick = { confirm = "clearcache" })
            SectionLabel("Covers")
            SettingsRow("Shrink covers", icon = Icons.Rounded.PhotoSizeSelectSmall, subtitle = "Saves covers larger than 600 px at 600 px. No cover is lost", onClick = { confirm = "shrinkcovers" })
            SectionLabel("Backup")
            val backupBusy by backend.backupProgress.collectAsState()
            SettingsRow("Save backup", icon = Icons.Rounded.SaveAlt, subtitle = "Song info, covers, playlists, favorites and layout, as a .zip file",
                enabled = backupBusy == null && BackupFiles.pickDestination != null, onClick = { confirm = "savebackup" })
            SettingsRow("Restore from file", icon = Icons.Rounded.Restore, subtitle = "Replaces your current library", enabled = backupBusy == null, onClick = { confirm = "restore" })
            backupBusy?.let { (stage, fraction) ->
                Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                    Text(stage + (fraction?.let { " (${(it * 100).toInt()}%)" } ?: ""), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        "channels" -> ChannelsPage(conn, backend, stack)
        "profile" -> {
            var name by remember { mutableStateOf(prefs.profileName) }
            // Tell the person what happened: the shell's snackbar when there is one, else the note at the foot of the page.
            val toast = LocalListActions.current
            val say = { m: String -> toast?.notice(m) ?: run { notice.value = m } }
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Avatar(prefs.profilePhoto, prefs.profileName, 96.dp)
                val pick = env?.pickPhoto
                if (pick != null) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton({ pick { path -> if (path != null) { prefs.putProfilePhoto(path); say("Profile photo saved") } } }) { Text("Change photo") }
                    if (prefs.profilePhoto != null) OutlinedButton({ prefs.putProfilePhoto(null); say("Profile photo removed") }) { Text("Remove photo") }
                }
                OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Name") }, singleLine = true)
                Button({ prefs.putProfileName(name.trim().ifEmpty { "Listener" }); say("Name saved") }) { Text("Save name") }
            }
        }
        "mixlearn" -> MixLearnPage(backend) { confirm = "clearlearned" }
        "weather" -> WeatherPage(backend)
        "about" -> AboutPage(backend, onOpenChangelog = { stack.add("changelog") })
        "changelog" -> ChangelogPage(backend)
        "permissions" -> PermissionsPage()
        "conn" -> ConnectionPage(conn, backend)
        "netplay" -> NetplayPage(backend)
        "log" -> LogPage(backend)
        "bots", "credentials" -> BotsPage(backend)
        "repair" -> RepairPage(backend, stack)
        "recover" -> RecoverPage(backend)
        "folders" -> LocalFoldersPage(backend)
        "cache" -> CachePage(backend, notice)
        "dupes" -> DuplicatesPage(backend)
        "exports" -> ExportListsPage(backend)
        "sort" -> SortPage(backend)
        "missing" -> MissingInfoPage(backend)
        "uploadhub" -> UploadsPage(backend)
        "account" -> AccountPage(backend, onOpenIndex = { stack.add("index") }) { confirm = "accountout" }
        "index" -> IndexPage(backend, stack)
        else -> if (id.startsWith("index:")) ChatSongsPage(backend, id.removePrefix("index:").toLongOrNull() ?: 0L, stack) else NotBuilt(subTitles[id] ?: id)
    }
    notice.value?.let { Text(it, Modifier.padding(20.dp), color = MaterialTheme.colorScheme.onSurfaceVariant) }
    val listToast = LocalListActions.current
    val tell = { m: String -> listToast?.notice(m) ?: run { notice.value = m } }
    when (confirm) {
        "savebackup" -> BackupPasswordDialog({ pw ->
            backend.services.scope.launch { notice.value = backend.saveBackup(pw, "paperplay-backup-${io.max.paperplay.core.app.dayOf(io.max.paperplay.ui.nowMoment().epochMs)}.zip") }
        }) { confirm = null }
        "restore" -> ConfirmDialog("Restore a backup?", "This replaces your library, playlists and favorites with the backup.", "Restore", onRestore) { confirm = null }
        "shrinkcovers" -> ConfirmDialog("Shrink covers?", "Covers larger than 600 px are saved again at 600 px. They look a little softer on large screens. This runs in the background.", "Shrink", { notice.value = "Shrinking covers..."; storageBusy.value = true; backend.shrinkCovers { notice.value = it; storageBusy.value = false } }) { confirm = null }
        "clearcache" -> ConfirmDialog("Clear the cache?", "Streamed songs stored on this device are deleted. Stop playback first. They download again when played.", "Clear", { notice.value = "Clearing the cache..."; storageBusy.value = true; backend.clearCache { notice.value = it; storageBusy.value = false } }) { confirm = null }
        "accountout" -> ConfirmDialog("Log out of your account?", "Your index stays on this device. Chats and channels need a new login. The bot is not affected.", "Log out", { backend.logOutAccount(tell) }) { confirm = null }
        "clearlearned" -> ConfirmDialog("Clear what mixes have learned?", "Forgets play and skip counts and your \"doesn't fit this mix\" choices. Songs and playlists stay.", "Clear", backend::clearLearned) { confirm = null }
        "logout" -> ConfirmDialog("Log out?", "Your account is logged out (if there is one) and the main bot's API id, hash and token are forgotten, so the setup screen shows again. Songs, playlists, settings and extra bots stay.", "Log out", backend::logOutAll) { confirm = null }
        "logoutbot" -> ConfirmDialog("Log out the bot?", "The main bot's API id, hash and token are forgotten and the setup screen shows again. Your account, songs, playlists, settings and extra bots stay.", "Log out", backend::logOutBot) { confirm = null }
        "erase" -> ConfirmDialog(
            "Delete all data?",
            "This logs out your account and the bot, then deletes the library, playlists, favorites, settings, covers, cached songs, extra bots and every login from this device, and starts the app from the beginning. It cannot be undone. Your Telegram chats and the songs in them are not touched. To keep a copy first, save a backup under Storage and backup.",
            "Delete everything", { env?.eraseEverything?.value = true },
        ) { confirm = null }
    }
}

/** A row that opens and closes a group of settings under it, so the page shows the important things and keeps the rest one tap away. */
@Composable
private fun SettingsGroup(title: String, subtitle: String, icon: androidx.compose.ui.graphics.vector.ImageVector, content: @Composable () -> Unit) {
    var open by remember { mutableStateOf(false) }
    SettingsRow(title, icon = icon, subtitle = subtitle, onClick = { open = !open }) {
        AppIcon(if (open) Icons.Rounded.ExpandLess else Icons.Rounded.ExpandMore, if (open) "Close" else "Open")
    }
    val reduce = io.max.paperplay.ui.theme.LocalReduceMotion.current
    androidx.compose.animation.AnimatedVisibility(
        visible = open,
        enter = expandSectionEnter(reduce),
        exit = expandSectionExit(reduce),
    ) { Column { content() } }
}

@Composable
internal fun RateSlider(key: String, backend: CoreBackend, notice: androidx.compose.runtime.MutableState<String?>) {
    val w = rateWorks.getValue(key)
    // Reading can go far faster than the others: a bot is allowed many requests a second, and Auto speed finds the real limit.
    val top = if (key == "reading") 300 else 120
    var v by remember { mutableStateOf(backend.pref(w.key)?.toIntOrNull()?.coerceIn(1, top) ?: w.default) }
    SliderRow("${w.label}: $v a minute", v.toFloat(), 1f..top.toFloat(), { v = it.toInt() }, hint = "Requests to Telegram a minute. Slower avoids its rate limit, which pauses the work for a while; faster finishes sooner.",
        onDone = { backend.setPref(w.key, "$v") })
    if (key == "reading") {
        var n by remember { mutableStateOf(backend.pref("reading_batch")?.toIntOrNull()?.coerceIn(10, 500) ?: 100) }
        SliderRow("Messages per request: $n", n.toFloat(), 10f..500f, { n = it.toInt() },
            hint = "How many messages each request asks Telegram about. 100 is what Telegram is known to answer; above that it may refuse, and the setting then goes back to 100 by itself.",
            onDone = { backend.setPref("reading_batch", "$n") })
    }
}

@Composable
internal fun AddChannelDialog(backend: CoreBackend, connected: Boolean, onDismiss: () -> Unit) {
    var chatId by remember { mutableStateOf("") }
    var chatTitle by remember { mutableStateOf("") }
    var chatError by remember { mutableStateOf<String?>(null) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add channel") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(
                    chatId,
                    { chatId = it },
                    label = { Text("Chat id") },
                    placeholder = { Text("-1001234567890") },
                    singleLine = true,
                )
                OutlinedTextField(
                    chatTitle,
                    { chatTitle = it },
                    label = { Text("Name (optional)") },
                    singleLine = true,
                )
                if (chatError != null) Text(chatError!!, color = MaterialTheme.colorScheme.error)
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    chatError = backend.addChat(chatId, chatTitle)
                    if (chatError == null) onDismiss()
                },
                enabled = connected,
            ) { Text("Add") }
        },
        dismissButton = { TextButton(onDismiss) { Text("Cancel") } },
    )
}

@Preview
@Composable
private fun AvatarPreview() {
    Avatar(photo = null, name = "Alex", size = 80.dp)
}


/** Live sample of the glass material over a colourful backdrop, using the current blur and tint. */
@Composable
private fun GlassPreview(prefs: UiPrefs) {
    val backdrop = com.kyant.backdrop.backdrops.rememberLayerBackdrop()
    val scheme = MaterialTheme.colorScheme
    Box(Modifier.padding(horizontal = 16.dp, vertical = 8.dp).fillMaxWidth().height(150.dp).clip(RoundedCornerShape(28.dp))) {
        Box(
            Modifier.fillMaxSize().layerBackdrop(backdrop)
                .background(androidx.compose.ui.graphics.Brush.linearGradient(listOf(scheme.primary, scheme.tertiary, scheme.secondary))),
        ) {
            Box(Modifier.padding(start = 24.dp, top = 20.dp).size(56.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.85f)))
            Box(Modifier.align(Alignment.BottomEnd).padding(end = 40.dp, bottom = 16.dp).size(72.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.6f)))
        }
        io.max.paperplay.ui.GlassSurface(
            backdrop, Modifier.align(Alignment.Center).fillMaxWidth(0.72f).height(68.dp),
            cornerRadius = 24.dp, blur = prefs.glassBlur.dp, tintAlpha = prefs.glassTint,
        ) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Glass preview", style = MaterialTheme.typography.titleMedium) }
        }
    }
}

@Preview(name = "Settings list phone", widthDp = 390, heightDp = 844, showBackground = true)
@Composable
private fun SettingsListPhonePreview() = io.max.paperplay.ui.PreviewFrame {
    SettingsList(io.max.paperplay.ui.previewPrefs(), mutableListOf())
}

@Preview(name = "Settings list desktop", widthDp = 520, heightDp = 800, showBackground = true)
@Composable
private fun SettingsListDesktopPreview() = io.max.paperplay.ui.PreviewFrame(dark = true) {
    SettingsList(io.max.paperplay.ui.previewPrefs(), mutableListOf())
}

private enum class BarBackground(val label: String) { Transparent("Transparent"), Card("Card"), Glass("Glass") }

/** Desktop player bar: background, corners and which buttons show. The Material or Glass look is chosen with the other parts above. */
@Composable
private fun PlayerBarSettings(prefs: UiPrefs) {
    SectionLabel("Player bar")
    // Transparent lets the window's own background show through the bar; Card puts a solid panel behind it; Glass uses the Glass page settings.
    val background = when {
        prefs.look(LookGroup.Player) == Look.Glass -> BarBackground.Glass
        prefs.playerCard -> BarBackground.Card
        else -> BarBackground.Transparent
    }
    Text("Bar background", Modifier.padding(horizontal = 20.dp, vertical = 4.dp), style = MaterialTheme.typography.bodyLarge)
    ChoiceRow(BarBackground.entries, background, { it.label }, { b ->
        prefs.setLook(LookGroup.Player, if (b == BarBackground.Glass) Look.Glass else Look.Material)
        prefs.putPlayerCard(b == BarBackground.Card)
    })
    SwitchRow("Format in mini player", prefs.miniFormat, prefs::putMiniFormat, null, "Shows FLAC, Hi-Res or Dolby next to the controls")
    SwitchRow("Themed seek bar", prefs.themedSeek, prefs::putThemedSeek, null, "Colours the seek bar from the song's cover; off keeps it plain")
    SliderRow("Bar corners: ${prefs.playerRadius.toInt()}%", prefs.playerRadius, 0f..100f, { prefs.putPlayerRadius(it) })
    listOf(
        "favorite" to "Favorite", "sleep" to "Sleep timer", "panel" to "Now playing panel", "queue" to "Queue",
        "devices" to "Devices and mini player", "fullscreen" to "Full screen player",
    ).forEach { (id, label) -> SwitchRow(label, prefs.playerButton(id), { prefs.setPlayerButton(id, it) }) }
}

/** Sidebar settings on desktop, the bottom tab bar's on the phone. Shown at the end of Appearance. */
@Composable
private fun NavSettings(prefs: UiPrefs) {
    if (!isPhone) {
        ChoiceRow(Look.entries, prefs.look(LookGroup.Nav), { it.name }, { prefs.setLook(LookGroup.Nav, it) })
        Text("Glass blurs the page background behind the sidebar. Blur and tint are on the Glass page.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        SectionLabel("Selection")
        ChoiceRow(SelectionLook.entries, prefs.selectionLook, { it.label }, { prefs.setNav(look = it) })
        SliderRow("Sidebar corners: ${prefs.barRadius.toInt()}%", prefs.barRadius, 0f..100f, { prefs.setNav(bar = it) })
        SliderRow("Selection corners: ${prefs.selectionRadius.toInt()}%", prefs.selectionRadius, 0f..100f, { prefs.setNav(selection = it) })
        SliderRow("Sidebar width: ${prefs.sidebarWidth.toInt()} dp", prefs.sidebarWidth, 180f..320f, { prefs.putSidebarWidth(it) })
    } else {
        SwitchRow("Floating bar", prefs.floatingNav, prefs::putFloatingNav, Icons.Rounded.ViewAgenda, "Off docks the bar to the screen edges")
        SectionLabel("Layout")
        ChoiceRow(NavLayout.entries, prefs.navLayout, { it.label }, { prefs.setNav(layout = it) })
        Text(prefs.navLayout.hint, Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        SectionLabel("Selection")
        ChoiceRow(SelectionLook.entries, prefs.selectionLook, { it.label }, { prefs.setNav(look = it) })
        if (prefs.floatingNav) SliderRow("Corner radius: ${prefs.cornerRadius.toInt()}%", prefs.cornerRadius, 0f..100f, { prefs.putCornerRadius(it) })
        else Text("A docked bar spans the screen edge to edge, so it has no corner radius.", Modifier.padding(horizontal = 20.dp), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
