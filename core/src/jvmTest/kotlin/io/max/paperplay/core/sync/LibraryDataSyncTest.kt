package io.max.paperplay.core.sync

import io.max.paperplay.core.account.ChatPost
import io.max.paperplay.core.account.IndexStore
import io.max.paperplay.core.app.LibraryRepository
import io.max.paperplay.core.db.LibraryDatabase
import io.max.paperplay.core.db.libraryDriver
import io.max.paperplay.core.library.LibraryRepo
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlin.test.Test
import kotlin.test.assertEquals

class LibraryDataSyncTest {
    private class Device(val name: String) {
        var now = 1_000L
        val driver = libraryDriver()
        val library = LibraryRepository(LibraryRepo(LibraryDatabase(driver)) { ++now }) { ++now }
        val index = IndexStore(driver)
        var paused = false to 0L
        val sync = LibraryDataSync(driver, library, { index }, { paused }, { p, at -> paused = p to at }, mainChat = { -1_000_000_000_001L })

        fun song(uid: String, msg: Long) = driver.execute(
            null,
            "INSERT INTO songs (chat_id, message_id, unique_id, remote_id, title, artist, size, mime, file_name, date, cover_path, cached_bytes, plays) " +
                "VALUES (-1000000000001, $msg, '$uid', 'r$msg', 'Song $msg', 'Art', 10, 'audio/flac', 'f.flac', 5, '/local/cover.jpg', 99, 2)", 0,
        )

        fun count(sql: String) = driver.executeQuery(null, sql, { c -> c.next(); app.cash.sqldelight.db.QueryResult.Value(c.getLong(0)!!) }, 0).value
    }

    private fun post(chat: Long, msg: Long) = ChatPost(chat, msg, "u$chat:$msg", "T$msg", "A", 100, 1, "audio/flac", "f.flac", msg)

    private suspend fun pull(into: Device, from: Device) = into.sync.pull(from.name) { q -> from.sync.answer(into.name, q) }

    @Test
    fun bothDevicesEndWithTheSameSongsAndIndex() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        pc.song("a", 1); pc.song("b", 2); phone.song("c", 3)
        // The phone deleted "b" on purpose: it must not come back.
        phone.library.setPref(io.max.paperplay.core.filing.GONE_KEY, """{"b":${Long.MAX_VALUE / 2}}""")
        pc.index.saveChat(-1_000_000_000_005, "Big"); pc.index.setChatInfo(-1_000_000_000_005, "bigchan", "", true, true, 1)
        pc.index.upsertPosts((1L..4500L).map { post(-1_000_000_000_005, it) }, 7)
        phone.index.saveChat(-6, "Small"); phone.index.upsertPosts(listOf(post(-6, 1)), 8)

        assertEquals(1, pull(phone, pc)) // "a" only
        pull(pc, phone)
        assertEquals(listOf("a", "c"), listOf("a", "b", "c").filter { phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = '$it'") == 1L })
        assertEquals(3L, pc.count("SELECT COUNT(*) FROM songs"))
        // A synced row keeps its data but not the other device's cover file or cache.
        assertEquals(0L, phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = 'a' AND (cover_path IS NOT NULL OR cached_bytes <> 0)"))
        assertEquals(2L, phone.count("SELECT plays FROM songs WHERE unique_id = 'a'"))

        assertEquals(4500, phone.index.chat(-1_000_000_000_005)!!.postCount)
        assertEquals("https://t.me/bigchan", phone.index.chat(-1_000_000_000_005)!!.publicLink)
        assertEquals(1, pc.index.chat(-6)!!.postCount)
        // Nothing is sent back to where it came from, and a second pull finds nothing new.
        assertEquals(listOf(-6L), phone.index.changedAfter(-1, 0, 0, "pc", 10).map { it.first.chatId })
        pull(phone, pc)
        assertEquals(4500, phone.index.chat(-1_000_000_000_005)!!.postCount)
    }

    @Test
    fun aDeletionWhosePostIsStillInTheMainChatIsStale() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        pc.song("alive", 1); pc.song("elsewhere", 2)
        phone.library.setPref(io.max.paperplay.core.filing.GONE_KEY, """{"alive":5,"elsewhere":5}""")
        // The phone's index still sees "alive" posted in the main chat (-1); "elsewhere" only in another chat, which is never deleted from.
        phone.index.saveChat(-1_000_000_000_001, "Main"); phone.index.upsertPosts(listOf(post(-1_000_000_000_001, 1).copy(uniqueId = "alive")), 1)
        phone.index.saveChat(-9, "Other"); phone.index.upsertPosts(listOf(post(-9, 4).copy(uniqueId = "elsewhere")), 1)
        assertEquals(1, pull(phone, pc))
        assertEquals(1L, phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = 'alive'"))
        assertEquals(0L, phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = 'elsewhere'"))
        assertEquals("""{"elsewhere":5}""", phone.library.pref(io.max.paperplay.core.filing.GONE_KEY))
    }

    @Test
    fun aSongWhosePostIsDeletedDoesNotComeBackFromTheOtherDevice() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        pc.song("kept", 1); pc.song("deleted", 2); pc.song("newer", 9)
        val chat = pc.count("SELECT chat_id FROM songs WHERE unique_id = 'deleted'")
        // The phone read the chat in full up to post 5 and found only post 1.
        phone.index.saveChat(chat, "Main"); phone.index.setChatInfo(chat, "", "", true, true, 1)
        phone.index.upsertPosts(listOf(post(chat, 1)), 1)
        phone.index.setState(chat, 5, 1, true)
        pull(phone, pc)
        assertEquals(listOf("kept", "newer"), listOf("kept", "deleted", "newer").filter { phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = '$it'") == 1L })
    }

    @Test
    fun listeningTimeOfAllDevicesAddsUpOnceOnEveryDevice() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        val tablet = Device("tablet")
        fun Device.hear(day: String, ms: Long) = library.repo.addListen(library.pref("device_id")!!, day, "k", ms, 1)
        fun Device.days() = library.repo.listenPerDay()
        pc.hear("2026-11-23", 500); pc.hear("2026-11-24", 100); phone.hear("2026-11-24", 30)
        pull(phone, pc); pull(pc, phone); pull(phone, pc)
        val both = mapOf("2026-11-23" to 500L, "2026-11-24" to 130L)
        assertEquals(both, phone.days())
        assertEquals(both, pc.days())
        // More heard later the same day arrives too, and a third device gets the PC's time through the phone.
        pc.hear("2026-11-24", 7)
        pull(phone, pc); pull(tablet, phone)
        assertEquals(137L, tablet.days()["2026-11-24"])
        // Nothing is left to send.
        assertEquals("[]", phone.sync.answer("pc", buildJsonObject {
            put("k", "listens"); put("self", pc.library.pref("device_id")!!)
            put("have", buildJsonObject { for (r in pc.library.repo.db.miscQueries.listenRows(null).executeAsList()) put("${r.origin}|${r.day}", r.ms + r.plays) })
        })["rows"].toString())
        // A device with an older build refuses the request; songs still sync.
        pc.song("a", 1)
        phone.sync.pull("pc") { q -> if (q["k"].toString() == "\"listens\"") throw java.io.IOException("the other device could not answer") else pc.sync.answer("phone", q) }
        assertEquals(1L, phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = 'a'"))
    }

    @Test
    fun aChatCountsAsReadOnlyAfterItsLastPostArrived() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        pc.index.saveChat(-1_000_000_000_005, "Big"); pc.index.setChatInfo(-1_000_000_000_005, "", "", true, true, 1)
        pc.index.upsertPosts((1L..4500L).map { post(-1_000_000_000_005, it) }, 7)
        pc.index.setState(-1_000_000_000_005, 4500, 1, true)
        // The link dies after the first page of 2,000 posts.
        var pages = 0
        runCatching { phone.sync.pull("pc") { q -> if (q["k"].toString() == "\"index\"" && ++pages > 1) throw java.io.IOException("link lost") else pc.sync.answer("phone", q) } }
        assertEquals(2000, phone.index.chat(-1_000_000_000_005)!!.postCount)
        assertEquals(false, phone.index.chat(-1_000_000_000_005)!!.complete)
        assertEquals(0L, phone.index.chat(-1_000_000_000_005)!!.newestMessageId)
        assertEquals(false, phone.index.isDeletedPost(-1_000_000_000_005, 4400))
        pull(phone, pc)
        assertEquals(4500, phone.index.chat(-1_000_000_000_005)!!.postCount)
        assertEquals(true, phone.index.chat(-1_000_000_000_005)!!.complete)
        assertEquals(4500L, phone.index.chat(-1_000_000_000_005)!!.newestMessageId)
    }

    @Test
    fun aChatRemovedAndAddedBackGetsItsPostsAgainOnce() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        pc.index.saveChat(-1_000_000_000_005, "Big"); pc.index.setChatInfo(-1_000_000_000_005, "", "", true, true, 1)
        pc.index.upsertPosts((1L..2500L).map { post(-1_000_000_000_005, it) }, 7)
        pc.index.setState(-1_000_000_000_005, 2500, 1, true)
        pull(phone, pc)
        assertEquals(2500, phone.index.count(-1_000_000_000_005))
        // Removed and added back before the PC heard of it: the cursor is already past all of its posts.
        phone.index.deleteChat(-1_000_000_000_005); phone.index.saveChat(-1_000_000_000_005, "Big")
        pull(phone, pc)
        assertEquals(2500, phone.index.count(-1_000_000_000_005))
        assertEquals(true, phone.index.chat(-1_000_000_000_005)!!.complete)
        // A difference that stays is not asked for again at every sync.
        pc.index.upsertPosts(listOf(post(-1_000_000_000_005, 2501)), 1)
        var pages = 0
        repeat(3) { phone.sync.pull("pc") { q -> if (q["k"].toString() == "\"index\"") pages++; pc.sync.answer("phone", q) } }
        assertEquals(true, pages <= 8, "$pages pages")
    }

    @Test
    fun aPostDeletedOnOneDeviceStaysDeletedOnBoth() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        for (d in listOf(pc, phone)) {
            d.song("a", 1); d.song("b", 2)
            d.index.saveChat(-1_000_000_000_001, "Main"); d.index.upsertPosts(listOf(post(-1_000_000_000_001, 1).copy(uniqueId = "a"), post(-1_000_000_000_001, 2).copy(uniqueId = "b")), 1)
        }
        // Deleted on the phone: the post is gone in Telegram, the deletion is recorded, and the PC knows nothing of it yet.
        phone.driver.execute(null, "DELETE FROM songs WHERE unique_id = 'b'", 0)
        phone.library.setPref(io.max.paperplay.core.filing.GONE_KEY, """{"b":5}""")
        phone.index.markGonePosts(listOf(-1_000_000_000_001L to 2L), 9)
        repeat(2) { pull(phone, pc) }
        assertEquals(0L, phone.count("SELECT COUNT(*) FROM songs WHERE unique_id = 'b'"))
        assertEquals("""{"b":5}""", phone.library.pref(io.max.paperplay.core.filing.GONE_KEY))
        // The PC hears of it and its index no longer says the post is there.
        pull(pc, phone)
        assertEquals(emptySet(), pc.sync.stillPosted(setOf("b")))
        assertEquals(setOf("a"), pc.sync.stillPosted(setOf("a", "b")))
        // Telegram showing the post again takes the mark back.
        pc.index.upsertPosts(listOf(post(-1_000_000_000_001, 2).copy(uniqueId = "b")), 20)
        assertEquals(setOf("b"), pc.sync.stillPosted(setOf("b")))
    }

    @Test
    fun theLaterPauseDecisionWins() = runBlocking {
        val pc = Device("pc")
        val phone = Device("phone")
        pc.paused = true to 50L
        phone.paused = false to 10L
        pull(phone, pc)
        assertEquals(true to 50L, phone.paused)
        phone.paused = false to 90L
        pull(pc, phone)
        assertEquals(false to 90L, pc.paused)
    }
}
