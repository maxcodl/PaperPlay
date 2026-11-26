package io.max.paperplay.ui.app

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.BarChart
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Insights
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Headphones
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.max.paperplay.core.library.ListenTotal
import io.max.paperplay.core.metadata.splitArtists
import io.max.paperplay.ui.components.AppIcon
import io.max.paperplay.ui.components.CoverImage
import io.max.paperplay.ui.state.SongUi
import org.jetbrains.compose.ui.tooling.preview.Preview

private const val HEAT_WEEKS = 17

internal data class Personality(val name: String, val line: String)
internal data class Badge(val label: String, val earned: Boolean)

internal data class ProfileStats(
    val today: Long,
    val currentStreak: Int,
    val longestStreak: Int,
    val listenedToday: Boolean,
    val todayMs: Long,
    val weekMs: Long,
    val monthMs: Long,
    val totalMs: Long,
    /** Last 7 days, oldest first, today last. */
    val week: List<Long>,
    /** [HEAT_WEEKS] columns of 7 rows (Monday first), index = column * 7 + row; -1 for days that have not come yet. */
    val heat: List<Long>,
    val topArtist: Pair<String, Long>?,
    val topSong: ListenTotal?,
    val personality: Personality,
    val badges: List<Badge>,
    val totalPlays: Long = 0L,
    val distinctSongs: Int = 0,
    val weekTopArtist: Pair<String, Long>? = null,
)

internal data class BusiestDay(val epochDay: Long, val dateLabel: String, val ms: Long, val plays: Long)
internal data class PeakTime(val weekday: String, val bucket: String?)
internal data class TopGenre(val name: String, val percent: Int, val ms: Long)
internal data class LibraryExplored(val exploredSongs: Int, val totalSongs: Int) {
    val fraction: Float get() = if (totalSongs <= 0) 0f else (exploredSongs.toFloat() / totalSongs).coerceIn(0f, 1f)
    val percent: Int get() = if (totalSongs <= 0) 0 else ((exploredSongs * 100.0) / totalSongs).toInt().coerceIn(0, 100)
}
internal data class SongMetaSnapshot(val uniqueId: String, val album: String, val genre: String?, val playedBefore: Boolean)
internal data class ListeningInsights(
    val currentStreak: Int,
    val longestStreak: Int,
    val listenedToday: Boolean,
    val busiestDay: BusiestDay?,
    val peakTime: PeakTime?,
    val topGenre: TopGenre?,
    val libraryExplored: LibraryExplored?,
    val topArtists: List<Pair<String, Long>>,
    val topAlbums: List<Triple<String, String, Long>>,
)

internal data class StatsSongEntry(
    val total: ListenTotal,
    val song: SongUi?,
)

internal data class StatsArtistEntry(
    val artist: String,
    val ms: Long,
    val coverUri: String?,
)

internal data class StatsAlbumEntry(
    val album: String,
    val artist: String,
    val ms: Long,
    val coverUri: String?,
)

internal data class StatsPageData(
    val days: Int,
    val totalMs: Long,
    val totalPlays: Long,
    val distinctSongs: Int,
    val heroSong: StatsSongEntry?,
    val topSongs: List<StatsSongEntry>,
    val topArtists: List<StatsArtistEntry>,
    val topAlbums: List<StatsAlbumEntry>,
    val insights: ListeningInsights,
)

internal fun filterEventsForSpan(
    events: List<io.max.paperplay.core.recs.PlayEvent>,
    days: Int,
    nowMs: Long,
    tzOffsetMs: Long = 0L,
): List<io.max.paperplay.core.recs.PlayEvent> {
    if (days <= 0) return events
    val minDay = epochDayForMillis(nowMs, tzOffsetMs) - (days - 1)
    return events.filter { epochDayForMillis(it.at, tzOffsetMs) >= minDay }
}

internal fun buildStatsSummaryLine(totalPlays: Long, distinctSongs: Int, totalMs: Long): String {
    val songLabel = if (distinctSongs == 1) "1 song" else "$distinctSongs songs"
    return if (totalPlays > 0L) {
        val playLabel = if (totalPlays == 1L) "1 play" else "$totalPlays plays"
        "$playLabel · $songLabel"
    } else {
        "${fmtCompactTime(totalMs)} · $songLabel"
    }
}

/** Days since 1970-01-01 of a yyyy-MM-dd string; null when it is not one. */
internal fun epochDay(day: String): Long? {
    val p = day.split('-')
    if (p.size != 3) return null
    val y0 = p[0].toLongOrNull() ?: return null
    val m = p[1].toLongOrNull() ?: return null
    val d = p[2].toLongOrNull() ?: return null
    val y = if (m <= 2) y0 - 1 else y0
    val era = y.floorDiv(400)
    val yoe = y - era * 400
    val doy = (153 * (if (m > 2) m - 3 else m + 9) + 2) / 5 + d - 1
    val doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
}

/** 0 for a day with nothing, then 1 to 4 as the listening grows. */
internal fun heatLevel(ms: Long): Int = when {
    ms <= 0 -> 0
    ms < 15 * 60_000L -> 1
    ms < 60 * 60_000L -> 2
    ms < 120 * 60_000L -> 3
    else -> 4
}

internal fun fmtTime(ms: Long): String {
    val m = ms / 60_000
    return if (m >= 60) "${m / 60} h ${m % 60} min" else "$m min"
}

internal fun fmtCompactTime(ms: Long): String {
    val m = (ms / 60_000).coerceAtLeast(0L)
    return if (m >= 60) "${m / 60}h ${m % 60}m" else "${m}m"
}

internal fun fmtSpokenTime(ms: Long): String {
    val m = (ms / 60_000).coerceAtLeast(0L)
    val h = m / 60
    val rem = m % 60
    return buildString {
        if (h > 0) append(if (h == 1L) "1 hour" else "$h hours")
        if (h > 0 && rem > 0) append(' ')
        if (rem > 0 || h == 0L) append(if (rem == 1L) "1 minute" else "$rem minutes")
    }
}

internal fun epochDayForMillis(epochMs: Long, tzOffsetMs: Long = 0L): Long =
    (epochMs + tzOffsetMs).floorDiv(86_400_000L)

private val WEEKDAY_NAMES = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
private val MONTH_NAMES = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

internal fun weekdayName(epochDay: Long): String =
    WEEKDAY_NAMES[((epochDay + 3).mod(7L)).toInt()]

internal fun timeOfDayBucket(hour: Int): String = when (hour.mod(24)) {
    in 5..11 -> "Morning"
    in 12..16 -> "Afternoon"
    in 17..20 -> "Evening"
    else -> "Night"
}

internal fun formatShortDate(epochDay: Long): String {
    val parts = io.max.paperplay.core.app.dayOf(epochDay * 86_400_000L).split('-')
    val monthIdx = (parts.getOrNull(1)?.toIntOrNull() ?: 1) - 1
    val dayNum = parts.getOrNull(2)?.toIntOrNull() ?: 1
    val mon = MONTH_NAMES.getOrElse(monthIdx) { "Jan" }
    return "$mon $dayNum"
}

internal fun computeProfileStats(
    perDay: Map<String, Long>,
    month: List<ListenTotal>,
    all: List<ListenTotal>,
    today: Long,
    weekTotals: List<ListenTotal> = emptyList(),
): ProfileStats {
    val days = HashMap<Long, Long>()
    for ((k, v) in perDay) epochDay(k)?.let { if (v > 0) days[it] = (days[it] ?: 0) + v }
    fun ms(d: Long) = days[d] ?: 0L

    var current = 0
    var d = if (ms(today) > 0) today else today - 1
    while (ms(d) > 0) { current++; d-- }
    var longest = 0
    var run = 0
    var prev = Long.MIN_VALUE
    for (k in days.keys.sorted()) {
        run = if (k == prev + 1) run + 1 else 1
        if (run > longest) longest = run
        prev = k
    }

    val row = ((today + 3).mod(7L)).toInt() // 1970-01-01 was a Thursday; Monday is row 0
    val first = today - row - (HEAT_WEEKS - 1) * 7L
    val heat = List(HEAT_WEEKS * 7) { i -> val day = first + i; if (day > today) -1L else ms(day) }
    val week = (today - 6..today).map(::ms)
    val total = all.sumOf { it.ms }

    val perArtist = HashMap<String, Long>()
    for (t in month) t.artist?.let { a -> splitArtists(a).forEach { perArtist[it] = (perArtist[it] ?: 0) + t.ms } }

    val weekPerArtist = HashMap<String, Long>()
    for (t in weekTotals) t.artist?.let { a -> splitArtists(a).forEach { weekPerArtist[it] = (weekPerArtist[it] ?: 0) + t.ms } }

    val plays = all.sumOf { it.plays }
    val distinctSongs = all.count { it.ms > 0 || it.plays > 0 }
    val hours = total / 3_600_000L
    return ProfileStats(
        today, current, longest, ms(today) > 0, ms(today), week.sum(), (today - 29..today).sumOf(::ms), total,
        week, heat, perArtist.maxByOrNull { it.value }?.toPair(), month.maxByOrNull { it.ms },
        personality(all.size, plays, total),
        listOf(
            Badge("7 day streak", longest >= 7), Badge("30 day streak", longest >= 30), Badge("100 day streak", longest >= 100),
            Badge("10 hours", hours >= 10), Badge("100 hours", hours >= 100), Badge("1000 hours", hours >= 1000),
        ),
        totalPlays = plays,
        distinctSongs = distinctSongs,
        weekTopArtist = weekPerArtist.maxByOrNull { it.value }?.toPair(),
    )
}

internal fun computeListeningInsights(
    perDayStats: Map<String, Pair<Long, Long>>,
    totals: List<ListenTotal>,
    events: List<io.max.paperplay.core.recs.PlayEvent>,
    librarySongs: Collection<SongMetaSnapshot>,
    nowMs: Long,
    tzOffsetMs: Long = 0L,
): ListeningInsights {
    val today = epochDayForMillis(nowMs, tzOffsetMs)
    val dayStats = HashMap<Long, Pair<Long, Long>>()
    for ((k, v) in perDayStats) {
        if (v.first <= 0L && v.second <= 0L) continue
        val day = epochDay(k) ?: continue
        val cur = dayStats[day]
        dayStats[day] = ((cur?.first ?: 0L) + v.first) to ((cur?.second ?: 0L) + v.second)
    }

    val heardEvents = events.filter { it.heardMs > 0L }
    val eventDays = HashMap<Long, Pair<Long, Long>>()
    for (e in heardEvents) {
        val day = epochDayForMillis(e.at, tzOffsetMs)
        val cur = eventDays[day]
        eventDays[day] = ((cur?.first ?: 0L) + e.heardMs) to ((cur?.second ?: 0L) + 1L)
    }

    val activeDays = (dayStats.keys + eventDays.keys).toSortedSet()
    var currentStreak = 0
    var d = if (today in activeDays) today else today - 1
    while (d in activeDays) {
        currentStreak++
        d--
    }
    var longestStreak = 0
    var run = 0
    var prev = Long.MIN_VALUE
    for (day in activeDays) {
        run = if (day == prev + 1) run + 1 else 1
        if (run > longestStreak) longestStreak = run
        prev = day
    }

    val busiestSource = if (dayStats.isNotEmpty()) dayStats else eventDays
    val busiestEntry = busiestSource.maxWithOrNull(
        compareBy<Map.Entry<Long, Pair<Long, Long>>> { it.value.second }.thenBy { it.value.first }.thenBy { it.key },
    )
    val busiestDay = busiestEntry?.let { (day, pair) ->
        BusiestDay(day, formatShortDate(day), pair.first, pair.second)
    }

    val peakTime = if (heardEvents.isNotEmpty()) {
        val byWeekday = HashMap<Long, Long>()
        val byBucket = HashMap<String, Long>()
        for (e in heardEvents) {
            val day = epochDayForMillis(e.at, tzOffsetMs)
            val wd = (day + 3).mod(7L)
            byWeekday[wd] = (byWeekday[wd] ?: 0L) + e.heardMs
            val hour = if (e.at > 0L) ((e.at + tzOffsetMs).floorDiv(3_600_000L).mod(24L)).toInt() else e.hour
            val b = timeOfDayBucket(hour)
            byBucket[b] = (byBucket[b] ?: 0L) + e.heardMs
        }
        val topWd = byWeekday.maxByOrNull { it.value }?.key
        val topBucket = byBucket.maxByOrNull { it.value }?.key
        if (topWd != null) PeakTime(WEEKDAY_NAMES[topWd.toInt()], topBucket) else null
    } else if (dayStats.isNotEmpty()) {
        val byWeekday = HashMap<Long, Long>()
        for ((day, pair) in dayStats) {
            val wd = (day + 3).mod(7L)
            byWeekday[wd] = (byWeekday[wd] ?: 0L) + pair.first.coerceAtLeast(pair.second)
        }
        byWeekday.maxByOrNull { it.value }?.key?.let { PeakTime(WEEKDAY_NAMES[it.toInt()], null) }
    } else {
        null
    }

    val byId = librarySongs.associateBy { it.uniqueId }

    val genreMs = HashMap<String, Long>()
    var taggedMs = 0L
    for (t in totals) {
        if (t.ms <= 0L) continue
        val g = byId[t.key]?.genre?.trim()
        if (!g.isNullOrEmpty() && !g.equals("unknown", ignoreCase = true)) {
            genreMs[g] = (genreMs[g] ?: 0L) + t.ms
            taggedMs += t.ms
        }
    }
    val topGenre = if (taggedMs > 0L) {
        genreMs.maxByOrNull { it.value }?.let { (name, ms) ->
            TopGenre(name, ((ms * 100.0) / taggedMs).toInt().coerceIn(1, 100), ms)
        }
    } else {
        null
    }

    val heardIds = totals.asSequence().filter { it.ms > 0L || it.plays > 0L }.mapTo(HashSet()) { it.key }
    val libraryExplored = if (librarySongs.isNotEmpty()) {
        val explored = librarySongs.count { it.playedBefore || it.uniqueId in heardIds }
        LibraryExplored(explored, librarySongs.size)
    } else {
        null
    }

    val artistTotals = HashMap<String, Long>()
    for (t in totals) {
        if (t.ms <= 0L) continue
        t.artist?.let { a -> splitArtists(a).forEach { artistTotals[it] = (artistTotals[it] ?: 0L) + t.ms } }
    }
    val topArtists = artistTotals.entries.sortedByDescending { it.value }.map { it.key to it.value }

    val albumTotals = HashMap<String, Pair<String, Long>>()
    for (t in totals) {
        if (t.ms <= 0L) continue
        val album = byId[t.key]?.album?.trim().orEmpty()
        if (album.isEmpty() || io.max.paperplay.core.metadata.isCompilationAlbum(album)) continue
        val cur = albumTotals[album]
        val artist = cur?.first?.takeIf { it.isNotBlank() } ?: t.artist.orEmpty()
        albumTotals[album] = artist to ((cur?.second ?: 0L) + t.ms)
    }
    val topAlbums = albumTotals.entries
        .sortedByDescending { it.value.second }
        .map { Triple(it.key, it.value.first, it.value.second) }

    return ListeningInsights(
        currentStreak = currentStreak,
        longestStreak = longestStreak,
        listenedToday = today in activeDays,
        busiestDay = busiestDay,
        peakTime = peakTime,
        topGenre = topGenre,
        libraryExplored = libraryExplored,
        topArtists = topArtists,
        topAlbums = topAlbums,
    )
}

internal fun personality(distinct: Int, plays: Long, totalMs: Long): Personality {
    val repeat = if (distinct == 0) 0.0 else plays.toDouble() / distinct
    return when {
        totalMs < 3_600_000L || distinct < 10 -> Personality("Newcomer", "Keep listening and this fills in.")
        repeat >= 4 -> Personality("Loyalist", "You play your favourites again and again.")
        distinct >= 100 && repeat < 2 -> Personality("Explorer", "$distinct different songs and always hunting for more.")
        else -> Personality("Balanced", "A good mix of old favourites and new finds.")
    }
}

@Composable
internal fun ListeningSection(stats: ProfileStats?, recents: List<SongUi>, prefs: UiPrefs, onPlay: (List<SongUi>, Int) -> Unit, onFull: () -> Unit) {
    ProfileSection("listening", "Your listening", Icons.Rounded.Insights, prefs, defaultOpen = true) {
        val s = stats
        if (s == null || s.totalMs == 0L) {
            Text(
                if (s == null) "Reading" else "Nothing yet. Play some songs and your listening shows up here.",
                Modifier.padding(horizontal = 20.dp, vertical = 8.dp), color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            // A wide window splits the stats into two columns instead of one narrow stack with empty space beside it.
            BoxWithConstraints(Modifier.fillMaxWidth()) {
                val gap = Arrangement.spacedBy(16.dp)
                if (maxWidth >= 720.dp) {
                    Row(Modifier.padding(horizontal = 20.dp).padding(bottom = 12.dp), horizontalArrangement = Arrangement.spacedBy(40.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = gap) { TimeHero(s); WeekBars(s); PersonalityRow(s) }
                        Column(Modifier.weight(1f), verticalArrangement = gap) { StreakRow(s); Heatmap(s); Badges(s) }
                    }
                } else {
                    Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 12.dp), verticalArrangement = gap) {
                        TimeHero(s); StreakRow(s); Heatmap(s); WeekBars(s); PersonalityRow(s); Badges(s)
                    }
                }
            }
            if (recents.isNotEmpty()) {
                SectionLabel("Recently played")
                RecentRow(recents, onPlay)
            }
            if (s.topArtist != null || s.topSong != null) {
                SectionLabel("Top of the last 30 days")
                s.topArtist?.let { SettingsRow(it.first, icon = Icons.Rounded.Headphones, subtitle = "Top artist", trailing = { Text(fmtTime(it.second)) }) }
                s.topSong?.let { SettingsRow(it.title ?: "Unknown song", icon = Icons.Rounded.EmojiEvents, subtitle = "Top song · ${it.artist.orEmpty()}", trailing = { Text(fmtTime(it.ms)) }) }
            }
        }
        NavRow("Full statistics", icon = Icons.Rounded.BarChart, subtitle = "Top songs and artists by period", onClick = onFull)
    }
}

@Composable
private fun TimeHero(s: ProfileStats) {
    val shown by animateFloatAsState(s.totalMs.toFloat(), io.max.paperplay.ui.theme.motionEffectTween(io.max.paperplay.ui.theme.Motion.Effects.WashMs, easing = io.max.paperplay.ui.theme.Motion.Emphasized), label = "total")
    Column {
        Text(fmtTime(shown.toLong()), style = MaterialTheme.typography.displaySmall, color = MaterialTheme.colorScheme.primary)
        Text("listened in total", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(Modifier.padding(top = 12.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            for ((label, v) in listOf("Today" to s.todayMs, "7 days" to s.weekMs, "30 days" to s.monthMs)) {
                Column(Modifier.weight(1f)) {
                    Text(fmtTime(v), style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun StreakRow(s: ProfileStats) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        AppIcon(Icons.Rounded.LocalFireDepartment, null, Modifier.padding(end = 12.dp), tint = MaterialTheme.colorScheme.primary)
        Column(Modifier.weight(1f)) {
            Text(if (s.currentStreak == 1) "1 day streak" else "${s.currentStreak} day streak", style = MaterialTheme.typography.titleMedium)
            Text(
                if (s.currentStreak > 0 && !s.listenedToday) "Listen today to keep it going" else "Best streak ${s.longestStreak} days",
                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun Heatmap(s: ProfileStats) {
    val empty = MaterialTheme.colorScheme.surfaceContainerHighest
    val fill = MaterialTheme.colorScheme.primary
    val ring = MaterialTheme.colorScheme.onSurface
    Column {
        Canvas(Modifier.fillMaxWidth().widthIn(max = 480.dp).aspectRatio(HEAT_WEEKS / 7f)) {
            val cell = size.width / HEAT_WEEKS
            val gap = 2.dp.toPx()
            val side = cell - gap
            for (i in s.heat.indices) {
                val ms = s.heat[i]
                if (ms < 0) continue
                val at = Offset((i / 7) * cell, (i % 7) * cell)
                val level = heatLevel(ms)
                drawRoundRect(if (level == 0) empty else fill.copy(alpha = 0.25f + 0.25f * level), at, Size(side, side), CornerRadius(side / 5))
                if (i == s.heat.indexOfLast { it >= 0 }) drawRoundRect(ring, at, Size(side, side), CornerRadius(side / 4), Stroke(1.5.dp.toPx()))
            }
        }
        val active = s.heat.count { it > 0 }
        Text("$active listening days in the last $HEAT_WEEKS weeks", Modifier.padding(top = 8.dp), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun WeekBars(s: ProfileStats) {
    val bar = MaterialTheme.colorScheme.primary
    val dim = MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)
    val max = (s.week.maxOrNull() ?: 0L).coerceAtLeast(1L)
    Column {
        Canvas(Modifier.fillMaxWidth().height(56.dp)) {
            val slot = size.width / 7
            val w = minOf(slot * 0.5f, 14.dp.toPx())
            s.week.forEachIndexed { i, ms ->
                val h = (size.height * ms / max).coerceAtLeast(w)
                drawRoundRect(if (i == 6) bar else dim, Offset(i * slot + (slot - w) / 2, size.height - h), Size(w, h), CornerRadius(w / 2))
            }
        }
        Row(Modifier.fillMaxWidth()) {
            for (i in 0 until 7) {
                val letter = "MTWTFSS"[((s.today - 6 + i + 3).mod(7L)).toInt()]
                Text("$letter", Modifier.weight(1f), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
    }
}

@Composable
private fun PersonalityRow(s: ProfileStats) {
    Column {
        Text(s.personality.name, style = MaterialTheme.typography.titleMedium)
        Text(s.personality.line, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Badges(s: ProfileStats) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        for (b in s.badges) {
            Row(
                Modifier.alpha(if (b.earned) 1f else 0.4f)
                    .partSurface(LookGroup.Cards, MaterialTheme.colorScheme.primaryContainer, appShape(16.dp))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                AppIcon(Icons.Rounded.EmojiEvents, null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onPrimaryContainer)
                Spacer(Modifier.width(6.dp))
                Text(b.label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onPrimaryContainer)
            }
        }
    }
}

@Composable
private fun RecentRow(recents: List<SongUi>, onPlay: (List<SongUi>, Int) -> Unit) {
    val list = remember(recents) { recents.take(15) }
    LazyRow(Modifier.padding(bottom = 8.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        itemsIndexed(list, key = { _, s -> s.id }) { i, s ->
            Column(Modifier.width(96.dp).clickable(onClickLabel = "Play ${s.title}") { onPlay(list, i) }) {
                CoverImage(s.coverUri, s.id, size = 96.dp, radius = 12.dp)
                Text(s.title, Modifier.padding(top = 6.dp), style = MaterialTheme.typography.labelLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(s.artist, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

@Preview
@Composable
private fun ListeningSectionPreview() = io.max.paperplay.ui.PreviewFrame {
    val today = 20_400L
    val days = (0 until 60).filter { it % 5 != 0 }.associate { io.max.paperplay.core.app.dayOf((today - it) * 86_400_000L) to (20 + it % 7 * 25) * 60_000L }
    val all = List(40) { ListenTotal("k$it", 3_600_000, 3, "Song $it", "Artist ${it % 5}") }
    ListeningSection(computeProfileStats(days, all.take(5), all, today), emptyList(), io.max.paperplay.ui.previewPrefs(), { _, _ -> }, {})
}
