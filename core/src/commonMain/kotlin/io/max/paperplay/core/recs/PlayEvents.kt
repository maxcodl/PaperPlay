package io.max.paperplay.core.recs

import app.cash.sqldelight.db.QueryResult
import app.cash.sqldelight.db.SqlDriver

/** Local hour (0-23) of [epochMs] in the device's time zone. */
expect fun localHourOf(epochMs: Long): Int

/** Local timezone offset in milliseconds from UTC at [epochMs]. */
expect fun localTimezoneOffsetMs(epochMs: Long): Long

/** One time a song stopped playing: how much of it was heard, at what hour, and what played just before it. */
class PlayEvent(val uid: String, val at: Long, val hour: Int, val heardMs: Long, val durMs: Long, val prev: String?)

/**
 * Every listen, kept in its own table (runtime-created, so the schema shared with the Flutter app stays as it is).
 * The counters on songs only say played or skipped; recommendations also need how early a skip came and which song led to which.
 */
class PlayEventLog(private val driver: SqlDriver) {
    private var last: Pair<String, Long>? = null

    init {
        driver.execute(
            null,
            "CREATE TABLE IF NOT EXISTS play_events (id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, at INTEGER NOT NULL, " +
                "hour INTEGER NOT NULL, heard_ms INTEGER NOT NULL, dur_ms INTEGER NOT NULL, prev_uid TEXT)",
            0,
        )
    }

    /** Logs that [uid] stopped at [at] after [heardMs] of [durMs]. The song before counts as its lead-in when it ended within 15 minutes. */
    @Synchronized
    fun record(uid: String, at: Long, heardMs: Long, durMs: Long) {
        val prev = last?.takeIf { at - it.second in 0..15 * 60_000L && it.first != uid }?.first
        last = uid to at
        driver.execute(null, "INSERT INTO play_events (uid, at, hour, heard_ms, dur_ms, prev_uid) VALUES (?, ?, ?, ?, ?, ?)", 6) {
            bindString(0, uid); bindLong(1, at); bindLong(2, localHourOf(at).toLong()); bindLong(3, heardMs); bindLong(4, durMs); bindString(5, prev)
        }
    }

    /** "Does not fit" from a mix page: logged as a listen of nothing, which the recommender treats as an instant skip and mixes leave out. */
    fun reject(uid: String, at: Long, durMs: Long) {
        driver.execute(null, "INSERT INTO play_events (uid, at, hour, heard_ms, dur_ms, prev_uid) VALUES (?, ?, ?, 0, ?, NULL)", 4) {
            bindString(0, uid); bindLong(1, at); bindLong(2, localHourOf(at).toLong()); bindLong(3, durMs)
        }
    }

    fun unreject(uid: String) {
        driver.execute(null, "DELETE FROM play_events WHERE uid = ? AND heard_ms = 0", 1) { bindString(0, uid) }
    }

    /** Forgets every listen (Settings, forget what was learned). */
    fun clear() {
        driver.execute(null, "DELETE FROM play_events", 0)
        last = null
    }

    fun count(): Long = driver.executeQuery(null, "SELECT COUNT(*) FROM play_events", { c ->
        QueryResult.Value(if (c.next().value) c.getLong(0) ?: 0L else 0L)
    }, 0).value

    /** All events, oldest first. */
    fun all(): List<PlayEvent> = driver.executeQuery(null, "SELECT uid, at, hour, heard_ms, dur_ms, prev_uid FROM play_events ORDER BY at, id", { c ->
        val out = ArrayList<PlayEvent>()
        while (c.next().value) {
            out += PlayEvent(c.getString(0)!!, c.getLong(1)!!, c.getLong(2)!!.toInt(), c.getLong(3)!!, c.getLong(4)!!, c.getString(5))
        }
        QueryResult.Value(out)
    }, 0).value
}
