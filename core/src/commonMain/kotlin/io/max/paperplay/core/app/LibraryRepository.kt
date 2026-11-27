package io.max.paperplay.core.app

import io.max.paperplay.core.library.LibraryChat
import io.max.paperplay.core.library.LibraryRepo
import io.max.paperplay.core.library.Playlist
import io.max.paperplay.core.library.Song
import io.max.paperplay.core.library.allSongsNow
import io.max.paperplay.core.library.laterStamp
import io.max.paperplay.core.library.newUuid
import io.max.paperplay.core.library.stableRead
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.job
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.shareIn
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update

/**
 * Flow-based view of the library. Every write made through this class bumps a change counter,
 * which re-runs the queries behind the `watch` flows. Write only through here, never through [repo].
 */
class LibraryRepository(val repo: LibraryRepo, private val clock: () -> Long) {
    constructor(repo: LibraryRepo, clock: () -> Long, parentScope: CoroutineScope?) : this(repo, clock) {
        parentScope?.coroutineContext?.job?.invokeOnCompletion { close() }
    }

    private val songs get() = repo.db.songsQueries
    private val lists get() = repo.db.playlistsQueries
    private val misc get() = repo.db.miscQueries
    /** Counts every write; collect it to re-run a query that [watch] does not cover. */
    val changes = MutableStateFlow(0L)

    /** Call after changing the database behind this class's back (e.g. a restored backup). Re-runs the queries at once. */
    fun invalidate() = changes.update { it + 1 }

    private val bgScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val soft = Channel<Unit>(Channel.CONFLATED)

    fun close() {
        runCatching { repo.flushPrefs() }
        bgScope.cancel()
        soft.close()
    }

    /** True while the song-info run is going; the cover workers stand down for it. */
    val enrichRunning = MutableStateFlow(false)

    init {
        // Background writers: the first bump goes out at once, later ones merge into one per [SOFT_GAP_MS].
        bgScope.launch {
            for (u in soft) {
                invalidate()
                // A song-info run writes for minutes or hours, and every bump makes each open list read the whole library again.
                delay(if (enrichRunning.value) BUSY_GAP_MS else SOFT_GAP_MS)
            }
        }
    }

    /** Like [invalidate] for background writers: at most one bump per couple of seconds, however many writes. */
    fun invalidateSoon() { soft.trySend(Unit) }

    private fun <T> watch(query: () -> T): Flow<T> =
        changes.map { repo.db.stableRead(query) }.distinctUntilChanged().flowOn(Dispatchers.IO)

    private fun <T> write(soft: Boolean = false, notify: Boolean = true, block: () -> T): T =
        block().also { if (notify) { if (soft) invalidateSoon() else invalidate() } }

    /** Runs [block] as one database transaction and signals one change (coalesced when [soft]). */
    fun <T> batch(soft: Boolean = true, block: () -> T): T =
        write(soft) { repo.db.transactionWithResult { repo.lockForWrite(); block() } }

    private val allShared: Flow<List<Song>> by lazy {
        watch { songs.allSongs().executeAsList() }
            .shareIn(bgScope, SharingStarted.WhileSubscribed(10_000, 0), replay = 1)
    }

    // Reads
    /** One query shared by every collector. */
    fun allSongs(): Flow<List<Song>> = allShared
    fun favorites(): Flow<List<Song>> = watch { songs.favorites().executeAsList() }
    fun recents(limit: Long = 50): Flow<List<Song>> = watch {
        songs.recent(limit) { chat_id, message_id, unique_id, remote_id, title, artist, album,
            duration_sec, size, mime, file_name, date, cover_path, release_id, cover_url, genre, year,
            metadata_source, favorite, cover_hi_res, user_edited, enrich_state, lyrics, cached_bytes,
            last_played_at, pinned, tags_at, favorite_at, cover_at, instrumental, mood_scanned_at,
            plays, skips, topic_id, sample_rate, bit_depth, codec ->
            Song(chat_id, message_id, unique_id, remote_id, title, artist, album, duration_sec, size,
                mime, file_name, date, cover_path, release_id, cover_url, genre, year, metadata_source,
                favorite, cover_hi_res, user_edited, enrich_state, lyrics, cached_bytes, last_played_at,
                pinned, tags_at, favorite_at, cover_at, instrumental, mood_scanned_at, plays, skips,
                topic_id, sample_rate, bit_depth, codec)
        }.executeAsList()
    }
    fun album(name: String): Flow<List<Song>> = watch { songs.albumRows(name).executeAsList().sortedBy { it.title } }
    /**
     * Every song [name] is credited on, alone or with others ("A, B" counts for A and for B), by cleaned names. A shared credit
     * such as "A & B" (the Artists page's shared entries) gives the songs credited to exactly those artists together.
     */
    fun artist(name: String): Flow<List<Song>> = watch {
        val want = io.max.paperplay.core.metadata.splitArtistsClean(name).map { it.lowercase() }
        songs.allSongs().executeAsList()
            .filter { s ->
                val names = io.max.paperplay.core.metadata.splitArtistsClean(s.artist).map { it.lowercase() }
                if (want.size > 1) names.toSet() == want.toSet()
                else s.artist == name || names.any { it == name.lowercase() } || io.max.paperplay.core.metadata.cleanArtistName(s.artist).equals(name, ignoreCase = true)
            }
            .sortedWith(compareBy({ it.album }, { it.title }))
    }
    fun playlistSongs(id: Long): Flow<List<Song>> = watch { lists.playlistSongs(id).executeAsList() }
    fun playlists(): Flow<List<Playlist>> = watch { lists.livePlaylists().executeAsList() }
    fun chats(): Flow<List<LibraryChat>> = watch { misc.chats().executeAsList() }

    /**
     * Songs where every word of [query] matches the title, artist, album (the film, for film songs), genre or year, best first
     * (see [io.max.paperplay.core.metadata.songSearchScore]): exact words, word starts, parts of words and small typos count,
     * accents are ignored, and a title equal to the whole query comes first. Letters and combining marks of any script count.
     */
    fun search(query: String): Flow<List<Song>> {
        val q = io.max.paperplay.core.metadata.SearchQuery(query)
        if (q.isEmpty) return kotlinx.coroutines.flow.flowOf(emptyList())
        return allShared.map { l ->
            // A song's language: from the writing of its title, artist and album, else from the language the topic it is filed in is named for.
            val topicLanguages = misc.topics().executeAsList().mapNotNull { t ->
                io.max.paperplay.core.metadata.topicLanguage(t.name)?.let { (t.chat_id to t.topic_id) to it }
            }.toMap()
            l.mapNotNull { s ->
                val languages = io.max.paperplay.core.metadata.languagesOfText(s.title, s.artist, s.album) +
                    listOfNotNull(s.topic_id?.let { topicLanguages[s.chat_id to it] })
                s.searchScore(q, languages).takeIf { it > 0 }?.let { s to it }
            }.sortedByDescending { it.second }.map { it.first }
        }.distinctUntilChanged().flowOn(Dispatchers.Default)
    }

    /** Playlists with song count and up to four cover links each, from one query (no per-playlist song lists). */
    fun playlistSummaries(): Flow<List<PlaylistSummary>> = watch {
        val rows = lists.playlistCoverRows().executeAsList().groupBy { it.playlist_id }
        lists.livePlaylists().executeAsList().map { p ->
            val r = rows[p.id].orEmpty()
            PlaylistSummary(p.id, p.uuid, p.name, r.size, r.mapNotNull { it.cover_path }.distinct().take(12))
        }
    }

    fun song(chatId: Long, messageId: Long): Song? = songs.song(chatId, messageId).executeAsOneOrNull()
    /** Saves what the start of a song's file said about its sound. A shown list refreshes. */
    fun setAudioDetails(uniqueId: String, h: AudioHeader, notify: Boolean = true) = write(soft = true, notify = notify) {
        songs.setAudioDetails(h.sampleRate?.toLong(), h.bitDepth?.toLong(), h.codec ?: songs.songByUniqueId(uniqueId).executeAsOneOrNull()?.codec, uniqueId)
    }

    fun songByUniqueId(uniqueId: String): Song? = songs.songByUniqueId(uniqueId).executeAsOneOrNull()
    /** Many songs in one query (the ids that match; the others are simply missing). */
    fun songsByUniqueIds(ids: Collection<String>): List<Song> = if (ids.isEmpty()) emptyList() else songs.songsByUniqueIds(ids).executeAsList()
    fun replaceSong(s: Song) = write { repo.db.enrichQueries.replaceSong(s) }
    /** Saves many rows in one transaction with one (coalesced) change signal. */
    fun replaceSongs(list: List<Song>) { if (list.isNotEmpty()) batch { list.forEach { repo.db.enrichQueries.replaceSong(it) } } }
    fun nextToEnrich(): Song? = songs.nextToEnrich().executeAsOneOrNull()
    fun unmatchedSongs(): List<Song> = repo.db.allSongsNow().filter { it.enrich_state == 2L && !it.user_edited }
    fun setCachedBytes(uniqueId: String, bytes: Long, notify: Boolean = false) {
        if (notify) write(soft = true) { songs.setCachedBytes(bytes, uniqueId) } else songs.setCachedBytes(bytes, uniqueId)
    }
    fun cachedSongs(): List<Song> = repo.db.stableRead { songs.cachedSongs().executeAsList() }
    fun cacheLimit(): Long = repo.cacheLimit()
    fun songsInChat(chatId: Long): List<Song> = repo.db.stableRead { songs.songsInChat(chatId).executeAsList() }
    fun songsNeedingCovers(): List<Song> = repo.db.stableRead { songs.songsNeedingCovers().executeAsList() }
    /** Songs of one album name, for sharing a cover and album info between its tracks. */
    fun albumSongs(name: String): List<Song> = repo.db.stableRead { songs.albumRows(name).executeAsList() }
    /** Songs whose cover is only a thumbnail but have a full-size source. */
    fun songsNeedingUpgrade(): List<Song> = repo.db.stableRead { songs.songsNeedingUpgrade().executeAsList() }
    /** Ids of songs with no cover at all, newest first. */
    fun coverMissingIds(): List<String> = songs.idsNeedingCovers().executeAsList()
    /** Ids of songs whose cover is only a low-quality thumbnail that has a full-size source. */
    fun coverUpgradeIds(): List<String> = songs.idsNeedingUpgrade().executeAsList()
    /** Songs that have a cover path but whose file is gone (cleared storage, a lost backup): a full pass fetches those again. */
    fun coverFileMissingIds(exists: (String) -> Boolean): List<String> =
        // Two small columns, not whole rows: a big read refills its cursor window while a delete writes, and crashed on a null row.
        songs.coverPaths().executeAsList().filter { val c = it.cover_path; !c.isNullOrEmpty() && !exists(c) }.map { it.unique_id }
    /** Records which client owns a song's post, by changing its remote id. */
    fun claimRemote(s: Song, remote: String) = write(soft = true) { songs.refreshPost(remote, s.topic_id, s.chat_id, s.message_id) }
    fun updateCover(
        uniqueId: String,
        coverPath: String? = null,
        coverUrl: String? = null,
        coverHiRes: Boolean? = null,
        album: String? = null,
        year: Long? = null,
        genre: String? = null,
        metadataSource: String? = null,
        enrichState: Long? = null,
        notify: Boolean = true,
    ) {
        val block = {
            songs.updateSongCover(
                coverPath = coverPath,
                coverUrl = coverUrl,
                coverHiRes = coverHiRes,
                album = album,
                year = year,
                genre = genre,
                metadataSource = metadataSource,
                enrichState = enrichState,
                uniqueId = uniqueId,
            )
        }
        if (notify) write(soft = true) { block() } else block()
    }
    /** How many songs use the cover file at [path] (songs of one album share a file). */
    fun coverPathUses(path: String): Long = songs.coverPathUses(path).executeAsOne()
    fun distinctCoverPaths(): List<String> = songs.distinctCoverPaths().executeAsList().mapNotNull { it.cover_path }
    /** Points every song that uses the cover file [from] at [to]. */
    fun retargetCover(from: String, to: String) = write(soft = true) { songs.retargetCover(to, from) }
    fun fillEmbeddedTags(
        uniqueId: String, title: String?, artist: String?, album: String?, year: Long?, genre: String?, coverPath: String?,
    ) = write(soft = true) { songs.fillEmbeddedTags(title, artist, album, year, genre, coverPath, uniqueId) }
    fun chatList(): List<LibraryChat> = misc.chats().executeAsList()
    fun chat(id: Long): LibraryChat? = chatList().firstOrNull { it.id == id }

    // Favorites, listening
    fun toggleFavorite(s: Song) = write {
        val fresh = songs.song(s.chat_id, s.message_id).executeAsOneOrNull() ?: return@write
        songs.setFavorite(!fresh.favorite, clock(), s.chat_id, s.message_id)
    }

    /** Marks songs as kept on this device (or not). */
    fun setPinned(uniqueIds: Collection<String>, pinned: Boolean) = write {
        uniqueIds.forEach { songs.setPinnedById(pinned, it) }
    }

    fun incompletePins(): List<Song> = repo.db.stableRead { songs.incompletePins().executeAsList() }

    /** Stores [ms] listened to [s] today and, when [finished] is not null, counts a play (true) or skip (false). */
    fun recordListen(s: Song, ms: Long, finished: Boolean?, notify: Boolean = true) = write(soft = true, notify = notify) {
        val now = clock()
        if (ms >= RECENT_AFTER_MS) songs.markPlayed(now, s.chat_id, s.message_id)
        if (finished != null) repo.countPlay(s, finished)
        repo.addListen(repo.pref("device_id") ?: "self", dayOf(now), s.unique_id, ms, if (finished == true) 1 else 0)
        runCatching { onListen?.invoke(s, ms, now) }
    }

    /** Told of every listen, for the recommender's play log. */
    @kotlin.concurrent.Volatile var onListen: ((Song, Long, Long) -> Unit)? = null

    /** Puts [s] on Recently played now, without counting a play. */
    fun markPlayedNow(s: Song) = write(soft = true) { songs.markPlayed(clock(), s.chat_id, s.message_id) }

    // Playlists
    fun createPlaylist(name: String): Long = write { repo.createPlaylist(name) }
    fun deletePlaylist(id: Long) = write { repo.deletePlaylist(id) }
    fun addToPlaylist(id: Long, s: Song) = write { repo.addToPlaylist(id, s) }
    fun removeFromPlaylist(id: Long, s: Song) = write { repo.removeFromPlaylist(id, s) }
    fun renamePlaylist(id: Long, name: String) = write {
        val prev = lists.playlist(id).executeAsOneOrNull()?.modified_at ?: 0
        lists.renamePlaylist(name, laterStamp(clock(), prev), id)
    }

    // Used by the scanner
    fun upsertBotSong(s: Song): Boolean = write(soft = true) { repo.upsertBotSong(s) }
    fun removePost(chatId: Long, messageId: Long) = write { repo.removePost(chatId, messageId) }
    fun removeChat(chatId: Long): Int = write { repo.removeChat(chatId) }
    fun saveTopic(chatId: Long, topicId: Long, name: String) = write { misc.saveTopic(chatId, topicId, name) }
    fun replaceTopics(chatId: Long, topics: List<Pair<Long, String>>) = write {
        misc.deleteTopicsOfChat(chatId)
        for ((topicId, name) in topics) misc.saveTopic(chatId, topicId, name)
    }
    /** Forum topics known per chat. */
    fun topicCountsByChat(): Map<Long, Int> = misc.topics().executeAsList().groupingBy { it.chat_id }.eachCount()
    /** Posts copied into the main chat, by the chat they came from. */
    fun copyCountsByChat(): Map<Long, Int> = repo.db.filingQueries.allPostCopies().executeAsList().groupingBy { it.chat_id }.eachCount()
    fun addChat(id: Long, title: String) = write {
        if (chat(id) == null) misc.insertChat(LibraryChat(id, title, null, true, false))
    }
    fun advanceScanned(chatId: Long, messageId: Long) = misc.advanceScanned(messageId, chatId)
    fun setScan(chatId: Long, messageId: Long, walkDone: Boolean) = misc.setScan(messageId, walkDone, chatId)
    fun renameChat(chatId: Long, title: String) = write { misc.renameChat(title, chatId) }

    fun pref(key: String): String? = repo.pref(key)
    fun setPref(key: String, value: String) = repo.setPref(key, value)

    /** Like [setPref] for the screen: the value counts at once and is written beside it, so a tap never waits for a scan or a sync that is writing. */
    fun savePref(key: String, value: String) {
        repo.holdPref(key, value)
        bgScope.launch(Dispatchers.IO) {
            repeat(5) {
                // Another writer held the file too long; what is held is still read, and tried again.
                if (runCatching { repo.flushPrefs() }.isSuccess) return@launch
                delay(1_000)
            }
        }
    }

    init {
        if (repo.pref("device_id") == null) repo.setPref("device_id", newUuid())
    }
}

/** A playlist row for the library page: count and a few cover links. */
data class PlaylistSummary(val id: Long, val uuid: String, val name: String, val count: Int, val covers: List<String>)

private const val SOFT_GAP_MS = 2_000L
private const val BUSY_GAP_MS = 12_000L

/** 0 when some word of the query matches nothing in the song; otherwise higher is a better match. */
internal fun Song.searchScore(q: io.max.paperplay.core.metadata.SearchQuery, languages: List<String> = emptyList()): Int =
    io.max.paperplay.core.metadata.songSearchScore(q, title, artist, album, genre, year?.toInt(), languages, plays.toInt(), favorite)

/** UTC calendar day of [millis] as yyyy-MM-dd. */
fun dayOf(millis: Long): String {
    val z = millis.floorDiv(86_400_000L) + 719_468
    val era = z.floorDiv(146_097L)
    val doe = z - era * 146_097
    val yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
    val doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    val mp = (5 * doy + 2) / 153
    val d = doy - (153 * mp + 2) / 5 + 1
    val m = if (mp < 10) mp + 3 else mp - 9
    val y = yoe + era * 400 + if (m <= 2) 1 else 0
    return "${y.toString().padStart(4, '0')}-${m.toString().padStart(2, '0')}-${d.toString().padStart(2, '0')}"
}
