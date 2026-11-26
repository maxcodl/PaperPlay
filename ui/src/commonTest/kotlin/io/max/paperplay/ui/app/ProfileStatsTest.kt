package io.max.paperplay.ui.app

import io.max.paperplay.core.library.ListenTotal
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ProfileStatsTest {
    private val today = epochDay("2026-11-24")!!
    private fun day(back: Int) = io.max.paperplay.core.app.dayOf((today - back) * 86_400_000L)
    private fun stats(vararg back: Int, all: List<ListenTotal> = emptyList()) =
        computeProfileStats(back.associate { day(it) to 600_000L }, emptyList(), all, today)

    @Test
    fun epochDayParses() {
        assertEquals(0L, epochDay("1970-01-01"))
        assertEquals(1L, epochDay("1970-01-02"))
        assertNull(epochDay("nope"))
    }

    @Test
    fun streakCountsBackFromToday() {
        val s = stats(0, 1, 2, 5)
        assertEquals(3, s.currentStreak)
        assertEquals(3, s.longestStreak)
        assertTrue(s.listenedToday)
    }

    @Test
    fun streakSurvivesAnEmptyToday() {
        val s = stats(1, 2)
        assertEquals(2, s.currentStreak)
        assertFalse(s.listenedToday)
    }

    @Test
    fun streakBreaksOnAGap() {
        val s = stats(2, 3, 4, 5, 6)
        assertEquals(0, s.currentStreak)
        assertEquals(5, s.longestStreak)
    }

    @Test
    fun heatGridEndsOnTodayAndHidesTheFuture() {
        val s = stats(0)
        assertEquals(17 * 7, s.heat.size)
        val row = ((today + 3).mod(7L)).toInt()
        assertEquals(600_000L, s.heat[16 * 7 + row])
        if (row < 6) assertEquals(-1L, s.heat[16 * 7 + row + 1])
        assertEquals(600_000L, s.week.last())
    }

    @Test
    fun heatLevels() {
        assertEquals(0, heatLevel(0))
        assertEquals(1, heatLevel(60_000))
        assertEquals(2, heatLevel(30 * 60_000L))
        assertEquals(3, heatLevel(90 * 60_000L))
        assertEquals(4, heatLevel(3 * 3_600_000L))
    }

    @Test
    fun personalityByHabit() {
        assertEquals("Newcomer", personality(3, 5, 100_000).name)
        assertEquals("Loyalist", personality(20, 100, 10 * 3_600_000L).name)
        assertEquals("Explorer", personality(200, 250, 10 * 3_600_000L).name)
        assertEquals("Balanced", personality(50, 100, 10 * 3_600_000L).name)
    }

    @Test
    fun badgesFollowHoursAndStreak() {
        val hours = listOf(ListenTotal("a", 12 * 3_600_000L, 1, "t", "x"))
        val s = stats(0, 1, 2, 3, 4, 5, 6, all = hours)
        assertEquals(listOf(true, false, false, true, false, false), s.badges.map { it.earned })
    }

    @Test
    fun topArtistSplitsCredits() {
        val month = listOf(ListenTotal("a", 100, 1, "t", "A, B"), ListenTotal("b", 50, 1, "u", "B"))
        val s = computeProfileStats(emptyMap(), month, month, today)
        assertEquals("B" to 150L, s.topArtist)
    }

    @Test
    fun weekTopArtistSplitsCredits() {
        val week = listOf(ListenTotal("a", 120_000, 2, "t", "X, Y"), ListenTotal("b", 80_000, 1, "u", "Y"))
        val s = computeProfileStats(emptyMap(), emptyList(), week, today, weekTotals = week)
        assertEquals("Y" to 200_000L, s.weekTopArtist)
        assertEquals(3L, s.totalPlays)
        assertEquals(2, s.distinctSongs)
    }

    @Test
    fun insightsEmptyDataReturnsZeroAndNulls() {
        val nowMs = today * 86_400_000L + 12 * 3_600_000L
        val ins = computeListeningInsights(emptyMap(), emptyList(), emptyList(), emptyList(), nowMs)
        assertEquals(0, ins.currentStreak)
        assertEquals(0, ins.longestStreak)
        assertFalse(ins.listenedToday)
        assertNull(ins.busiestDay)
        assertNull(ins.peakTime)
        assertNull(ins.topGenre)
        assertNull(ins.libraryExplored)
        assertTrue(ins.topArtists.isEmpty())
        assertTrue(ins.topAlbums.isEmpty())
    }

    @Test
    fun insightsSinglePlay() {
        val d0 = today
        val dayStr = io.max.paperplay.core.app.dayOf(d0 * 86_400_000L)
        val at = d0 * 86_400_000L + 14 * 3_600_000L // 14:00 -> Afternoon
        val events = listOf(io.max.paperplay.core.recs.PlayEvent("u1", at, 14, 180_000L, 200_000L, null))
        val totals = listOf(ListenTotal("u1", 180_000L, 1L, "Track 1", "Artist 1"))
        val lib = listOf(
            SongMetaSnapshot("u1", "Album 1", "Rock", playedBefore = false),
            SongMetaSnapshot("u2", "Album 2", "Pop", playedBefore = false),
        )
        val ins = computeListeningInsights(
            perDayStats = mapOf(dayStr to (180_000L to 1L)),
            totals = totals,
            events = events,
            librarySongs = lib,
            nowMs = at + 60_000L,
        )
        assertEquals(1, ins.currentStreak)
        assertEquals(1, ins.longestStreak)
        assertTrue(ins.listenedToday)
        assertEquals(d0, ins.busiestDay?.epochDay)
        assertEquals(1L, ins.busiestDay?.plays)
        assertEquals(weekdayName(d0), ins.peakTime?.weekday)
        assertEquals("Afternoon", ins.peakTime?.bucket)
        assertEquals(TopGenre("Rock", 100, 180_000L), ins.topGenre)
        assertEquals(LibraryExplored(1, 2), ins.libraryExplored)
        assertEquals(50, ins.libraryExplored?.percent)
    }

    @Test
    fun streakCountsAcrossLocalMidnight() {
        val day1Start = today * 86_400_000L
        val at1 = day1Start + 23 * 3_600_000L + 55 * 60_000L // 23:55 day1
        val at2 = day1Start + 24 * 3_600_000L + 5 * 60_000L  // 00:05 day2
        val events = listOf(
            io.max.paperplay.core.recs.PlayEvent("u1", at1, 23, 120_000L, 180_000L, null),
            io.max.paperplay.core.recs.PlayEvent("u2", at2, 0, 120_000L, 180_000L, "u1"),
        )
        val ins = computeListeningInsights(emptyMap(), emptyList(), events, emptyList(), nowMs = at2 + 60_000L)
        assertEquals(2, ins.currentStreak)
        assertEquals(2, ins.longestStreak)
        assertTrue(ins.listenedToday)
    }

    @Test
    fun streakAndPeakTimeRespectTimezoneOffset() {
        // Two plays at 20:00 UTC (Nov 24) and 01:00 UTC (Nov 25)
        val utcDay = epochDay("2026-11-24")!! * 86_400_000L
        val play1 = utcDay + 20 * 3_600_000L
        val play2 = utcDay + 25 * 3_600_000L
        val events = listOf(
            io.max.paperplay.core.recs.PlayEvent("u1", play1, 20, 120_000L, 180_000L, null),
            io.max.paperplay.core.recs.PlayEvent("u2", play2, 1, 120_000L, 180_000L, "u1"),
        )
        // In UTC+0: Nov 24 20:00 (Evening) & Nov 25 01:00 (Night) -> 2-day streak
        val utcIns = computeListeningInsights(emptyMap(), emptyList(), events, emptyList(), nowMs = play2, tzOffsetMs = 0L)
        assertEquals(2, utcIns.currentStreak)

        // In UTC+5:30 (+19_800_000 ms): Nov 25 01:30 & Nov 25 06:30 -> both on Nov 25 -> 1-day streak
        val istOffset = (5 * 60 + 30) * 60_000L
        val istIns = computeListeningInsights(emptyMap(), emptyList(), events, emptyList(), nowMs = play2, tzOffsetMs = istOffset)
        assertEquals(1, istIns.currentStreak)
    }

    @Test
    fun busiestDayAndUnknownGenreAreHonest() {
        val d1 = io.max.paperplay.core.app.dayOf((today - 2) * 86_400_000L)
        val d2 = io.max.paperplay.core.app.dayOf((today - 1) * 86_400_000L)
        val perDay = mapOf(
            d1 to (300_000L to 2L),
            d2 to (200_000L to 5L),
        )
        val totals = listOf(
            ListenTotal("u1", 300_000L, 2L, "Song 1", "Artist 1"),
            ListenTotal("u2", 200_000L, 5L, "Song 2", "Artist 2"),
        )
        val lib = listOf(
            SongMetaSnapshot("u1", "Best Hits", "Unknown", playedBefore = true),
            SongMetaSnapshot("u2", "Bravo Hits 99", "", playedBefore = false),
        )
        val ins = computeListeningInsights(perDay, totals, emptyList(), lib, nowMs = today * 86_400_000L)
        assertEquals(today - 1, ins.busiestDay?.epochDay)
        assertEquals(5L, ins.busiestDay?.plays)
        assertNull(ins.topGenre) // Never fake "Unknown 100%"
        assertTrue(ins.topAlbums.none { it.first.contains("Bravo Hits") })
        assertEquals(LibraryExplored(2, 2), ins.libraryExplored)
    }

    @Test
    fun filterEventsForSpanRespectsDaysAndTimezone() {
        val istOffset = (5 * 60 + 30) * 60_000L
        val now = today * 86_400_000L + 12 * 3_600_000L
        val recent = io.max.paperplay.core.recs.PlayEvent("u1", now - 2 * 86_400_000L, 12, 60_000L, 180_000L, null)
        val old = io.max.paperplay.core.recs.PlayEvent("u2", now - 10 * 86_400_000L, 12, 60_000L, 180_000L, null)
        assertEquals(2, filterEventsForSpan(listOf(recent, old), 0, now, istOffset).size)
        assertEquals(listOf(recent), filterEventsForSpan(listOf(recent, old), 7, now, istOffset))
        assertEquals(2, filterEventsForSpan(listOf(recent, old), 30, now, istOffset).size)
    }

    @Test
    fun summaryLineFormatsSingularPluralAndZeroPlays() {
        assertEquals("1 play · 1 song", buildStatsSummaryLine(1L, 1, 180_000L))
        assertEquals("20 plays · 9 songs", buildStatsSummaryLine(20L, 9, 5_100_000L))
        assertEquals("45m · 3 songs", buildStatsSummaryLine(0L, 3, 45 * 60_000L))
    }
}
