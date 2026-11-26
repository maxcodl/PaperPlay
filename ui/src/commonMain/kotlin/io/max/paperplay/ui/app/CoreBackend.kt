package io.max.paperplay.ui.app

import io.max.paperplay.core.library.allSongsNow
import io.max.paperplay.core.app.AppServices
import io.max.paperplay.core.app.createBackup
import io.max.paperplay.core.app.NowPlaying
import io.max.paperplay.core.app.Repeat
import io.max.paperplay.core.library.LibraryChat
import io.max.paperplay.core.library.Song
import io.max.paperplay.core.recs.DailyMix
import io.max.paperplay.core.recs.HomeMix
import io.max.paperplay.core.recs.HomeShelves
import io.max.paperplay.core.recs.TasteList
import io.max.paperplay.core.recs.TasteSettings
import io.max.paperplay.core.recs.WeatherKind
import io.max.paperplay.core.recs.WeatherPlace
import io.max.paperplay.core.recs.WeatherService
import io.max.paperplay.core.integrations.HttpFetcher
import io.max.paperplay.core.integrations.ListenBrainz
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import io.max.paperplay.core.recs.ShelfKind
import io.max.paperplay.core.filing.MAIN_CHAT_KEY
import io.max.paperplay.core.filing.parseMainChat
import io.max.paperplay.ui.nowMoment
import io.max.paperplay.ui.state.CollectionUi
import io.max.paperplay.ui.state.HomeUi
import io.max.paperplay.ui.state.ShelfKindUi
import io.max.paperplay.ui.state.ShelfUi
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.emitAll
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.onStart
import kotlinx.coroutines.flow.transformLatest
import kotlinx.coroutines.flow.transform
import kotlinx.coroutines.flow.conflate
import io.max.paperplay.ui.state.GroupUi
import io.max.paperplay.ui.state.LibraryUi
import io.max.paperplay.ui.state.Load
import io.max.paperplay.ui.state.PlaybackUiState
import io.max.paperplay.ui.state.PositionUi
import io.max.paperplay.ui.state.RepeatUi
import io.max.paperplay.ui.state.SongUi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.job
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlin.concurrent.Volatile

data class LogLine(val at: Long, val source: String, val message: String, val error: Boolean = false)

/** What the connection screen shows. */
data class ConnectionUi(
    val hasCredentials: Boolean = false,
    /** TDLib's authorization state name, empty before connecting. */
    val state: String = "",
    val ready: Boolean = false,
    val error: String? = null,
    val chats: List<LibraryChat> = emptyList(),
)

/** What a running scan says; kept out of [ConnectionUi] so a scan tick does not recompose whole screens. */
data class ScanUi(val text: String, val fraction: Double?)

/**
 * Maps the app services onto the plain state the screens render and the actions they call.
 * No Telegram or database types leave this class except [LibraryChat].
 */
/** What the player screens need from the backend. Lets them be previewed with fake data. */
const val EQ_DYNAMIC_BASS = 1
const val EQ_DE_ESSER = 2
const val EQ_CROSSFEED = 4

interface PlayerControls {
    val position: StateFlow<PositionUi>
    val sleepAt: StateFlow<Long?>
    /** Source format and output path of the song playing, for the output info screen. */
    val outputInfo: StateFlow<io.max.paperplay.player.OutputInfo?>
    /** Output volume, 0 to 1. */
    val volume: StateFlow<Float>
    /** Playback speed, 1 is normal. */
    val speed: StateFlow<Float>
    fun setSpeed(speed: Float)
    /** Equalizer switch and its ten band gains in dB. */
    val eqOn: StateFlow<Boolean> get() = MutableStateFlow(false)
    val eqGains: StateFlow<List<Float>> get() = MutableStateFlow(List(10) { 0f })
    fun setEqualizer(on: Boolean = eqOn.value, gains: List<Float> = eqGains.value) {}
    /** 31-band parametric EQ profile, user presets, AutoEQ catalog, and per-device auto-assignment. */
    val peqProfile: StateFlow<io.max.paperplay.player.ParametricEqProfile>
        get() = MutableStateFlow(io.max.paperplay.player.ParametricEqProfile.flat10())
    fun setParametricProfile(profile: io.max.paperplay.player.ParametricEqProfile, enabled: Boolean = eqOn.value) {}
    fun setParametricEnabled(enabled: Boolean) { setEqualizer(on = enabled) }
    val peqPresets: StateFlow<List<io.max.paperplay.player.ParametricEqProfile>> get() = MutableStateFlow(emptyList())
    fun saveParametricPreset(profile: io.max.paperplay.player.ParametricEqProfile) {}
    fun deleteParametricPreset(id: String) {}
    val eqDeviceKey: StateFlow<String?> get() = MutableStateFlow(null)
    val eqDeviceAssigned: StateFlow<Boolean> get() = MutableStateFlow(false)
    val eqDeviceAssignments: StateFlow<List<io.max.paperplay.core.eq.DeviceEqAssignment>> get() = MutableStateFlow(emptyList())
    fun assignEqToCurrentDevice() {}
    fun unassignEqFromCurrentDevice() {}
    fun removeDeviceEqAssignment(deviceKey: String) {}
    val autoEqCount: Int get() = 0
    suspend fun searchAutoEq(query: String, source: String? = null, form: String? = null): List<io.max.paperplay.core.eq.AutoEqEntry> = emptyList()
    suspend fun autoEqSources(): List<String> = emptyList()
    suspend fun autoEqForms(): List<String> = emptyList()
    suspend fun refreshAutoEqIndex(): String = "AutoEQ online refresh unavailable."
    val onlineAutoEqItems: StateFlow<List<io.max.paperplay.core.eq.AutoEqRemoteItem>> get() = MutableStateFlow(emptyList())
    suspend fun fetchOnlineAutoEqProfile(item: io.max.paperplay.core.eq.AutoEqRemoteItem): io.max.paperplay.player.ParametricEqProfile? = null
    /** Extra bass in dB, 0 to 12, on top of the equalizer. */
    val eqBass: StateFlow<Float> get() = MutableStateFlow(0f)
    fun setEqBass(db: Float) {}
    /** Plays the file untouched through verified bit-perfect output; equalizer, bass, normalise and profile are bypassed (not erased). */
    val bitPerfect: StateFlow<Boolean> get() = MutableStateFlow(false)
    val bitPerfectStatus: StateFlow<io.max.paperplay.player.BitPerfectStatus>
        get() = MutableStateFlow(io.max.paperplay.player.BitPerfectStatus.Off)
    fun setBitPerfect(on: Boolean) {}
    /** When true, 31-band parametric EQ runs at native rate/bit-depth in USB Exclusive mode (reported as USB Direct + EQ). */
    val allowEqInUsbExclusive: StateFlow<Boolean> get() = MutableStateFlow(true)
    fun setAllowEqInUsbExclusive(allow: Boolean) {}
    /** Phone engine extras: exact level, A/B with the original, stereo width (see [CoreBackend]). */
    val eqExact: StateFlow<Boolean> get() = MutableStateFlow(false)
    fun setEqExact(on: Boolean) {}
    val eqDry: StateFlow<Boolean> get() = MutableStateFlow(false)
    fun setEqDry(on: Boolean) {}
    val eqWidth: StateFlow<Float> get() = MutableStateFlow(1f)
    fun setEqWidth(width: Float) {}
    /** Name of a built-in earphone correction ([io.max.paperplay.player.CorrectionProfile.EARPHONES]), empty for none. */
    val eqEarphone: StateFlow<String> get() = MutableStateFlow("")
    fun setEqEarphone(name: String) {}
    /** Engine option bits (see [EQ_DYNAMIC_BASS], [EQ_DE_ESSER], [EQ_CROSSFEED]). */
    val eqOptions: StateFlow<Int> get() = MutableStateFlow(0)
    fun setEqOption(bit: Int, on: Boolean) {}
    /** The output the equalizer settings belong to (they are kept per output), or null before anything played. */
    val eqOutput: StateFlow<String?> get() = MutableStateFlow(null)
    /** True where the engine in use has a Bass control: the phone, and the PC with the mpv engine. */
    val hasBass: Boolean get() = io.max.paperplay.ui.isPhone
    fun removeFromQueue(index: Int)
    fun moveInQueue(from: Int, to: Int)
    fun togglePlay()
    fun next()
    fun previous()
    fun seekTo(fraction: Float)
    fun seekToMs(ms: Long)
    fun setVolume(v: Float)
    fun toggleShuffle()
    fun cycleRepeat()
    fun playQueueIndex(index: Int)
    fun setSleepTimer(minutes: Int?)
    suspend fun lyricsFor(songId: String): String?

    /** The versions of this song's lyrics the sources have (original, romanized, translation, other records). */
    suspend fun lyricsChoices(songId: String): List<LyricsChoiceUi> = emptyList()

    /** Optional romanized and translated LRC tracks for [songId] when available from NetEase. */
    suspend fun lyricsSecondary(songId: String): LyricsSecondaryUi? = null

    /** Keeps [text] as this song's lyrics, chosen by hand (it then wins over what other devices found); null goes back to automatic. */
    fun chooseLyrics(songId: String, text: String?) {}
}

/** One lyrics version in the picker: its source and script, a two line preview, and the text. */
data class LyricsChoiceUi(
    val label: String,
    val preview: String,
    val text: String,
    val romanized: String? = null,
    val translation: String? = null,
    val source: String = label.substringBefore(',').trim(),
)

/** Optional romanized and translated LRC tracks associated with a song's lyrics. */
data class LyricsSecondaryUi(val romanized: String? = null, val translation: String? = null)

class CoreBackend(val services: AppServices) : PlayerControls {
    private val backendJob = SupervisorJob(services.scope.coroutineContext.job)
    private val scope = CoroutineScope(backendJob + Dispatchers.Default)
    private val repo = services.library

    /** False once the services it belongs to were shut down. */
    val alive: Boolean get() = backendJob.isActive

    private val listenQueueLock = kotlinx.coroutines.sync.Mutex()

    @Volatile private var byId: Map<String, Song> = emptyMap()
    @Volatile private var byGroupKey: Map<String, Song> = emptyMap()
    /** Bumped each time [byId] has been rebuilt, so the playing song and queue are mapped from the new rows, not the old ones. */
    private val songsVersion = kotlinx.coroutines.flow.MutableStateFlow(0L)

    fun ensureCover(key: String) {
        val song = byId[key] ?: byGroupKey[key] ?: return
        services.covers.prioritize(listOf(song))
    }

    val library: StateFlow<LibraryUi> = combine(
        repo.allSongs().map { songs ->
            byId = songs.associateBy { it.unique_id }
            songsVersion.value += 1
            val groupsByKey = HashMap<String, Song>(songs.size)
            for (s in songs) {
                for (k in listOf(s.album, s.artist, s.title)) {
                    if (k.isBlank()) continue
                    val prev = groupsByKey[k]
                    if (prev == null || (prev.cover_path != null && s.cover_path == null)) {
                        groupsByKey[k] = s
                    }
                }
            }
            byGroupKey = groupsByKey
            // The rows stay as they are and each song becomes a UI object only when a list asks for it (the ones on screen).
            LibraryUi(songs = Load.Ready(LazySongs(songs, repeatPosts(byId))))
        },
        repo.playlistSummaries().map { list ->
            list.map { p -> GroupUi(p.id.toString(), p.name, "${p.count} songs", p.covers) }
        },
    ) { lib, playlists -> lib.copy(playlists = playlists) }
        // Rebuilding every list for the whole library is heavy: after one result, newer ones wait (and merge) for a moment, which matters while a scan
        // changes the library every second or two.
        .conflate()
        .transform { value -> emit(value); delay(1_200) }
        .catch { emit(LibraryUi(songs = Load.Error(it.message ?: "The library could not be read."))) }
        .flowOn(Dispatchers.Default)
        .stateIn(scope, SharingStarted.WhileSubscribed(5_000), LibraryUi())

    /** Albums and artists are grouped only while their tab or page is open. */
    val albums: StateFlow<List<GroupUi>> = repo.allSongs().map { songs ->
        songs.filter { it.album.isNotBlank() }.groupBy { it.album }.entries.sortedBy { it.key.lowercase() }.flatMap { (name, list) ->
            io.max.paperplay.core.library.splitAlbum(list) { it.artist }.map { (owner, part) ->
                GroupUi(if (owner == null) name else "$name | $owner", name, albumSubtitle(part), covers(part), owner)
            }
        }
    }.flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val artists: StateFlow<List<GroupUi>> = repo.allSongs().map { artistGroups(it) }
        .flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /** Topic and starred-channel lists, rebuilt after the library is (it groups every song, so never on the main thread). */
    val telegram: StateFlow<List<TelegramList>> = library.map { telegramLists() }.conflate()
        .flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val favorites: StateFlow<List<SongUi>> = repo.favorites()
        .onEach { if (it.isNotEmpty()) services.covers.prioritize(it.take(20)) }
        .map { it.map(Song::toUi) }
        .flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val recents: StateFlow<List<SongUi>> = repo.recents(30)
        .onEach { if (it.isNotEmpty()) services.covers.prioritize(it.take(20)) }
        .map { it.map(Song::toUi) }
        .flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private class HomeInput(
        val songs: List<Song>, val recent: List<Song>, val favorites: List<Song>, val reserved: Int,
        val taste: TasteSettings, val weather: WeatherKind?, val busy: Boolean,
    )

    /** What mixes may learn from. Saved with the other preferences. */
    val taste = MutableStateFlow(TasteSettings.parse(repo.pref(TasteSettings.PREF_KEY)))

    fun updateTaste(change: (TasteSettings) -> TasteSettings) {
        val next = change(taste.value).copy(at = nowMoment().epochMs)
        taste.value = next
        repo.savePref(TasteSettings.PREF_KEY, next.encode())
    }

    /** Forgets plays, skips and "doesn't fit" votes, and ignores older counts synced from elsewhere. */
    fun clearLearned() {
        scope.launch(Dispatchers.Default) {
            repo.repo.clearLearnedRows()
            runCatching { services.playEvents.clear() }
            updateTaste { it.copy(resetAt = nowMoment().epochMs) }
            repo.invalidate()
        }
    }

    /** Playlists with their uuid, for choosing what mixes learn from. */
    fun playlistKeys(): List<Pair<String, String>> =
        repo.repo.db.playlistsQueries.livePlaylists().executeAsList().map { TasteSettings.playlistKey(it.uuid) to it.name }

    private fun tasteLists(favorites: List<Song>, t: TasteSettings): List<TasteList> = buildList {
        if (t.learnsFrom(TasteSettings.FAVORITES_KEY)) add(TasteList("Favorites", favorites.map { it.unique_id }.toSet()))
        for (p in repo.repo.db.playlistsQueries.livePlaylists().executeAsList()) {
            if (!t.learnsFrom(TasteSettings.playlistKey(p.uuid))) continue
            add(TasteList(p.name, repo.repo.db.playlistsQueries.playlistSongs(p.id).executeAsList().map { it.unique_id }.toSet()))
        }
    }

    /** While on, nothing played is added to Recently played, to the listening history or to what mixes learn. Off at every start. */
    val privateSession = MutableStateFlow(false)

    fun setPrivateSession(on: Boolean) {
        privateSession.value = on
        withPlayer { it.privateSession = on }
    }

    /** When a queue runs out (repeat off), play a related song picked from the whole library instead of stopping. */
    val keepPlaying = MutableStateFlow(repo.pref("keep_playing") != "false")

    fun setKeepPlaying(on: Boolean) {
        keepPlaying.value = on
        repo.savePref("keep_playing", "$on")
    }

    private suspend fun suggestAfter(queue: List<Song>): Song? {
        if (!keepPlaying.value) return null
        val songs = repo.allSongs().first()
        val t = taste.value
        // The newest are enough: old listens hardly count, and all of them are gone through again after every song once a queue has ended.
        val events = services.playEvents.all().takeLast(MAX_SUGGEST_EVENTS).let { ev -> if (t.useListens) ev else ev.filter { it.heardMs == 0L } }
        return io.max.paperplay.core.recs.RecMixes.next(
            songs, services.audioFeatures.all(), events, tasteLists(songs.filter { it.favorite }, t), nowMoment(), queue,
        )
    }

    val http: HttpFetcher = io.max.paperplay.core.integrations.defaultHttpFetcher()

    /** Cover art for tracks a playlist lists but the library does not have (saved in the covers folder, fetched once). */
    val missingArt: io.max.paperplay.core.integrations.MissingArt by lazy { io.max.paperplay.core.integrations.MissingArt(http, services.platform.dataDir) }
    private val weatherService = WeatherService(http)

    val weatherPlace = MutableStateFlow(
        repo.pref("weather_city")?.takeIf { it.isNotEmpty() }?.let { name ->
            val lat = repo.pref("weather_lat")?.toDoubleOrNull()
            val lon = repo.pref("weather_lon")?.toDoubleOrNull()
            if (lat != null && lon != null) WeatherPlace(name, lat, lon) else null
        },
    )
    val weather = MutableStateFlow<WeatherKind?>(null)

    suspend fun searchPlaces(query: String): List<WeatherPlace> =
        runCatching { weatherService.searchPlaces(query) }.getOrDefault(emptyList())

    /** Chooses the city to get the weather for, or turns weather off with null. */
    fun setPlace(p: WeatherPlace?) {
        weatherPlace.value = p
        weather.value = null
        repo.savePref("weather_city", p?.name.orEmpty())
        repo.savePref("weather_lat", p?.latitude?.toString().orEmpty())
        repo.savePref("weather_lon", p?.longitude?.toString().orEmpty())
        refreshWeather()
    }

    fun refreshWeather() {
        val p = weatherPlace.value ?: return
        scope.launch { weather.value = runCatching { weatherService.kindAt(p) }.getOrNull() }
    }

    init {
        refreshWeather()
        services.enricher.coverShrink = { b -> io.max.paperplay.ui.shrinkImageBytes(b, 1280) }
    }

    /** tg://privatepost link of the song's channel post, or null for chats that are not channels or supergroups. */
    /** Queues the song for another online lookup; says what happened. */
    fun findMetadata(song: SongUi): String {
        val s = byId[song.id] ?: return "Song not found"
        if (s.user_edited) return "Edited songs are left alone"
        return if (services.enricher.retrySongs(listOf(s)) > 0) "Looking up song info" else "Song not found"
    }

    fun songRow(id: String): Song? = byId[id]

    fun telegramLink(song: SongUi): String? {
        val s = byId[song.id] ?: return null
        return postLink(s.chat_id, s.message_id, s.topic_id)
    }

    /** Which bot the library holds a post under, for the duplicates page: the app's record, not Telegram's sender. */
    fun ownerLabel(song: Song?): String {
        if (song == null) return "Bot: not recorded (a repeat of the same file)"
        if (song.remote_id == io.max.paperplay.core.app.ACCOUNT_REMOTE) return "Bot: none can read it (account only)"
        val id = io.max.paperplay.core.app.botOwnerOf(song.remote_id)
        // The bot's name as Telegram shows it; its username only when it has no name. Never an "@".
        if (id == null) {
            val main = services.botPool.mainBot.value
            val mainName = main.name ?: main.username?.removePrefix("@")
            return "Bot: " + (if (mainName != null) "$mainName (main bot)" else "main bot")
        }
        val bot = services.botPool.bots.value.firstOrNull { it.id == id }
        return "Bot: " + (bot?.name ?: bot?.username?.removePrefix("@") ?: "bot $id")
    }

    /** The link to one post: [chatId] and [messageId] are TDLib's ids; a post in a forum topic names its topic. */
    fun postLink(chatId: Long, messageId: Long, topicId: Long?): String? {
        if (chatId > -1_000_000_000_000L) return null
        val channel = -chatId - 1_000_000_000_000L
        val post = messageId shr 20
        if (post <= 0) return null
        // The phone hands tg:// to the Telegram app. A PC browser cannot open it and shows an empty tab, so there it is the web link,
        // which opens the post in Telegram (or on the web); a post in a forum topic names its topic.
        if (!io.max.paperplay.ui.isPhone) {
            val topic = topicId?.takeIf { it != io.max.paperplay.core.filing.GENERAL_TOPIC_ID }?.shr(20)?.takeIf { it > 1 }
            return "https://t.me/c/$channel/$post" + (if (topic != null) "?thread=$topic" else "")
        }
        return "tg://privatepost?channel=$channel&post=$post"
    }

    fun playNext(song: SongUi) {
        byId[song.id]?.let { s -> withPlayer { it.playNext(s) } }
    }

    /** Looked-up lyrics, switched to the writing system chosen in Settings when the sources have one. */
    private suspend fun fetchWantedLyrics(song: Song): String? {
        val found = io.max.paperplay.core.integrations.fetchLyrics(http, song.title, song.artist, song.album, song.duration_sec.toInt())
        return runCatching {
            io.max.paperplay.core.integrations.lyricsInScript(http, song.title, song.artist, song.album, song.duration_sec.toInt(), found, pref("lyrics_script"))
        }.getOrDefault(found)
    }

    /** Lyrics for a song: the saved ones, else looked up on LRCLIB (unless lookups are off) and saved. Null when none. */
    override suspend fun lyricsFor(songId: String): String? {
        val song = byId[songId] ?: return null
        song.lyrics?.takeIf { it.isNotBlank() }?.let { return it }
        if (!taste.value.lookups) return null
        val found = runCatching {
            fetchWantedLyrics(song)
        }.getOrNull() ?: return null
        runCatching {
            services.driver.execute(null, "UPDATE songs SET lyrics = ? WHERE unique_id = ?", 2) { bindString(0, found); bindString(1, songId) }
        }
        return found
    }

    override suspend fun lyricsChoices(songId: String): List<LyricsChoiceUi> {
        val song = byId[songId] ?: return emptyList()
        val found = runCatching {
            io.max.paperplay.core.integrations.lyricsChoices(http, song.title, song.artist, song.album, song.duration_sec.toInt())
        }.getOrDefault(emptyList())
        return found.map { c ->
            val lines = io.max.paperplay.core.metadata.parseLrc(c.text).map { it.text }.ifEmpty { c.text.lines() }.map { it.trim() }.filter { it.isNotEmpty() }
            LyricsChoiceUi(c.label, lines.take(2).joinToString("\n"), c.text, c.romanized, c.translation, c.source)
        }
    }

    override suspend fun lyricsSecondary(songId: String): LyricsSecondaryUi? {
        val song = byId[songId] ?: return null
        if (!taste.value.lookups) return null
        val bundle = runCatching {
            io.max.paperplay.core.integrations.fetchNeteaseLyricBundle(
                http, song.title, song.artist, song.album, song.duration_sec.toInt(),
            )
        }.getOrNull() ?: return null
        if (bundle.romanized == null && bundle.translation == null) return null
        return LyricsSecondaryUi(bundle.romanized, bundle.translation)
    }

    override fun chooseLyrics(songId: String, text: String?) {
        val now = nowMoment().epochMs
        scope.launch {
            runCatching {
                services.driver.execute(null, "UPDATE songs SET lyrics = ? WHERE unique_id = ?", 2) { bindString(0, text); bindString(1, songId) }
                val meta = io.max.paperplay.core.sync.readLyricsMeta(repo).toMutableMap()
                if (text == null) meta.remove(songId) else meta[songId] = io.max.paperplay.core.sync.LyricsMeta(manual = true, at = now)
                io.max.paperplay.core.sync.writeLyricsMeta(repo, meta)
                repo.invalidate()
            }
        }
    }

    private var lyricsJob: kotlinx.coroutines.Job? = null
    private var lyricsTask = 0L
    val lyricsRunning = MutableStateFlow(false)

    /**
     * Background run: looks up lyrics for every song without them, two songs at a time, each against all lyrics
     * sources at once (rate-limited per source). Songs nobody had lyrics for are remembered for two weeks
     * (pref "lyrics_miss") and skipped; a network failure is retried a couple of times and is not remembered.
     * Progress shows in the task centre. Calling it while running does nothing.
     */
    fun startLyricsRun() {
        if (lyricsJob?.isActive == true) return
        val now0 = nowMoment().epochMs
        val ttl = 14 * 86_400_000L
        val misses = HashMap<String, Long>()
        repo.pref("lyrics_miss")?.lines()?.forEach { l ->
            val p = l.split('\t')
            val at = p.getOrNull(1)?.toLongOrNull() ?: return@forEach
            if (now0 - at < ttl) misses[p[0]] = at
        }
        val todo = byId.values.filter { it.lyrics.isNullOrBlank() && !it.instrumental && misses[it.unique_id] == null }.map { it.unique_id }
        if (todo.isEmpty()) return
        val id = tasks.start(io.max.paperplay.core.app.TaskKind.Info, "Lyrics", todo.size, "Starting", onStop = { stopLyricsRun() })
        lyricsTask = id
        lyricsRunning.value = true
        lyricsJob = scope.launch {
            var found = 0
            var missed = 0
            var done = 0
            val lock = kotlinx.coroutines.sync.Mutex()
            val queue = kotlinx.coroutines.channels.Channel<String>(kotlinx.coroutines.channels.Channel.UNLIMITED)
            todo.forEach { queue.trySend(it) }
            queue.close()
            val writes = ArrayList<Pair<String, String>>()
            var lastTask = 0L
            // Called under [lock]: all collected lyrics go in one transaction, then the lists refresh once.
            fun flushLyrics() {
                if (writes.isEmpty()) return
                val batch = writes.toList()
                writes.clear()
                runCatching {
                    repo.batch {
                        for ((u, text) in batch) {
                            services.driver.execute(null, "UPDATE songs SET lyrics = ? WHERE unique_id = ? AND (lyrics IS NULL OR lyrics = '')", 2) { bindString(0, text); bindString(1, u) }
                        }
                    }
                }
            }
            fun saveMisses() = repo.savePref("lyrics_miss", misses.entries.joinToString("\n") { "${it.key}\t${it.value}" })
            try {
                kotlinx.coroutines.coroutineScope {
                    repeat(2) {
                        launch {
                            for (uid in queue) {
                                val song = byId[uid] ?: continue
                                var result: String? = null
                                var failed = false
                                var attempt = 0
                                while (true) {
                                    try {
                                        result = fetchWantedLyrics(song)
                                        break
                                    } catch (e: kotlinx.coroutines.CancellationException) {
                                        throw e
                                    } catch (e: Exception) {
                                        if (++attempt > 2) { failed = true; break }
                                        kotlinx.coroutines.delay(2_000L shl attempt)
                                    }
                                }
                                lock.withLock {
                                    if (result != null) {
                                        writes += uid to result
                                        if (writes.size >= 20) flushLyrics()
                                    }
                                    if (result != null) { found++; misses.remove(uid) }
                                    else {
                                        missed++
                                        if (!failed) misses[uid] = nowMoment().epochMs
                                    }
                                    done++
                                    val t = nowMoment().epochMs
                                    if (t - lastTask >= 1_000L) { lastTask = t; tasks.update(id, done = done, detail = song.title) }
                                    if (done % 25 == 0) saveMisses()
                                }
                            }
                        }
                    }
                }
                lock.withLock { flushLyrics() }
                tasks.update(id, done = todo.size)
                tasks.finish(id, io.max.paperplay.core.app.TaskState.Done, "$found found, $missed without lyrics")
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } finally {
                runCatching { kotlinx.coroutines.withContext(kotlinx.coroutines.NonCancellable) { lock.withLock { flushLyrics() } } }
                runCatching { saveMisses() }
                lyricsRunning.value = false
            }
        }
    }

    fun stopLyricsRun() {
        lyricsJob?.cancel()
        lyricsRunning.value = false
        tasks.running.value.firstOrNull { it.id == lyricsTask }?.let { tasks.stop(it.id) }
    }

    override fun seekToMs(ms: Long) { if (!remote("seek:$ms") { it.copy(positionMs = ms) }) player.seek(ms) }

    /** Listening totals for the last [days] days (0 for all time): per song and per day. */
    fun listenStats(days: Int): Pair<List<io.max.paperplay.core.library.ListenTotal>, Map<String, Long>> {
        val from = if (days <= 0) "0000-00-00" else io.max.paperplay.core.app.dayOf(nowMoment().epochMs - (days - 1) * 86_400_000L)
        return repo.repo.listenTotals(from) to repo.repo.listenPerDay(from)
    }

    internal val cachedProfileStats = MutableStateFlow<ProfileStats?>(null)
    internal val cachedStatsPages = MutableStateFlow<Map<Int, StatsPageData>>(emptyMap())

    /** What the Profile page shows: streaks, heatmap, week, top of the last 30 days. Call off the main thread. */
    internal fun profileStats(): ProfileStats {
        val now = nowMoment().epochMs
        val from = io.max.paperplay.core.app.dayOf(now - 29 * 86_400_000L)
        val weekFrom = io.max.paperplay.core.app.dayOf(now - 6 * 86_400_000L)
        return computeProfileStats(
            perDay = repo.repo.listenPerDay(),
            month = repo.repo.listenTotals(from),
            all = repo.repo.listenTotals(),
            today = now.floorDiv(86_400_000L),
            weekTotals = repo.repo.listenTotals(weekFrom),
        ).also { cachedProfileStats.value = it }
    }

    /** Full Stats page data for [days] (0 = all time). Call off the main thread. */
    internal fun statsPageData(days: Int): StatsPageData {
        val nowMs = nowMoment().epochMs
        val tzOffsetMs = io.max.paperplay.core.recs.localTimezoneOffsetMs(nowMs)
        val from = if (days <= 0) "0000-00-00" else io.max.paperplay.core.app.dayOf(nowMs - (days - 1) * 86_400_000L)
        val perDayStats = repo.repo.listenPerDayStats(from)
        val totals = repo.repo.listenTotals(from)
        val allEvents = runCatching { services.playEvents.all() }.getOrDefault(emptyList())
        val spanEvents = filterEventsForSpan(allEvents, days, nowMs, tzOffsetMs)
        val songsSnapshot = byId.values.toList()
        val insights = computeListeningInsights(
            perDayStats = perDayStats,
            totals = totals,
            events = spanEvents,
            librarySongs = songsSnapshot.map { SongMetaSnapshot(it.unique_id, it.album, it.genre, it.last_played_at != null || it.plays > 0) },
            nowMs = nowMs,
            tzOffsetMs = tzOffsetMs,
        )
        val topSongs = totals.take(25).map { t -> StatsSongEntry(t, byId[t.key]?.toUi()) }
        val heroTotal = totals.maxWithOrNull(compareBy<io.max.paperplay.core.library.ListenTotal> { it.plays }.thenBy { it.ms })
        val heroSong = heroTotal?.let { t -> StatsSongEntry(t, byId[t.key]?.toUi()) }

        val artistCovers = HashMap<String, String>()
        val albumCovers = HashMap<String, String>()
        for (s in songsSnapshot) {
            val cover = s.cover_path ?: continue
            io.max.paperplay.core.metadata.splitArtists(s.artist).forEach { a ->
                if (a !in artistCovers) artistCovers[a] = cover
            }
            val alb = s.album.trim()
            if (alb.isNotEmpty() && alb !in albumCovers) albumCovers[alb] = cover
        }
        val topArtists = insights.topArtists.take(8).map { (name, ms) ->
            StatsArtistEntry(name, ms, artistCovers[name])
        }
        val topAlbums = insights.topAlbums.take(8).map { (album, artist, ms) ->
            StatsAlbumEntry(album, artist, ms, albumCovers[album])
        }
        val totalMs = perDayStats.values.sumOf { it.first }.takeIf { it > 0L } ?: totals.sumOf { it.ms }
        val totalPlays = totals.sumOf { it.plays }
        val distinctSongs = totals.count { it.ms > 0L || it.plays > 0L }
        return StatsPageData(
            days = days,
            totalMs = totalMs,
            totalPlays = totalPlays,
            distinctSongs = distinctSongs,
            heroSong = heroSong,
            topSongs = topSongs,
            topArtists = topArtists,
            topAlbums = topAlbums,
            insights = insights,
        ).also { result ->
            cachedStatsPages.value = cachedStatsPages.value + (days to result)
        }
    }

    val account get() = services.account
    val chatIndex get() = services.chatIndex

    /** Your own groups and channels. The last list is kept, so the page can show it at once and refresh behind it. */
    val myChats = MutableStateFlow<List<io.max.paperplay.core.account.ChatInfo>?>(
        repo.pref("my_chats")?.lines()?.mapNotNull { l ->
            val p = l.split('\t', limit = 3)
            val id = p.getOrNull(0)?.toLongOrNull() ?: return@mapNotNull null
            io.max.paperplay.core.account.ChatInfo(id, p.getOrNull(2).orEmpty(), p.getOrNull(1) == "1")
        }?.takeIf { it.isNotEmpty() },
    )

    suspend fun refreshChats() {
        val fresh = account.groupsAndChannels()
        if (fresh.isEmpty()) return
        myChats.value = fresh
        repo.savePref("my_chats", fresh.joinToString("\n") { "${it.id}\t${if (it.isChannel) 1 else 0}\t${it.title.replace('\t', ' ').replace('\n', ' ')}" })
    }

    /** Sleep timer: pauses at [sleepAt] (epoch ms). Null when none is set. */
    override val sleepAt = MutableStateFlow<Long?>(null)
    private var sleepJob: kotlinx.coroutines.Job? = null

    override fun setSleepTimer(minutes: Int?) {
        sleepJob?.cancel()
        if (minutes == null) { sleepAt.value = null; return }
        val end = nowMoment().epochMs + minutes * 60_000L
        sleepAt.value = end
        sleepJob = scope.launch {
            kotlinx.coroutines.delay(minutes * 60_000L)
            if (playerStarted.value) player.pause()
            sleepAt.value = null
        }
    }

    /** Bytes of songs stored on this device: (pinned, other). */
    /** Per-chat totals for the Channels page, from the songs already in memory plus the topic and copy tables. */
    fun channelStats(chatIds: Collection<Long>): Map<Long, ChannelStats> {
        val topics = repo.topicCountsByChat()
        val copies = repo.copyCountsByChat()
        val bySongs = byId.values.groupBy { it.chat_id }
        return chatIds.associateWith { id ->
            val list = bySongs[id].orEmpty()
            ChannelStats(
                songs = list.size, topics = topics[id] ?: 0, bytes = list.sumOf { it.size }, seconds = list.sumOf { it.duration_sec },
                lossless = list.count { (it.codec ?: it.file_name.substringAfterLast('.', "")).lowercase().trim() in LOSSLESS },
                offline = list.count { it.size > 0 && it.cached_bytes >= it.size }, pinned = list.count { it.pinned },
                favorites = list.count { it.favorite }, copies = copies[id] ?: 0,
            )
        }
    }

    /**
     * What the app keeps on this device, measured on disk, largest first: songs (every Telegram store's downloads), covers,
     * lyrics and song info (their share of the library database), Telegram data (its databases) and the rest. Run off the main thread.
     */
    suspend fun storageBreakdown(): List<Pair<String, Long>> {
        fun size(f: java.io.File): Long = if (f.isFile) f.length() else f.listFiles()?.sumOf { size(it) } ?: 0L
        val root = java.io.File(services.platform.dataDir)
        val top = root.listFiles().orEmpty()
        val songs = top.filter { it.isDirectory && (it.name.endsWith("_files") || it.name.startsWith("td_extra_files_")) }.sumOf { size(it) }
        val covers = size(java.io.File(root, "covers"))
        val telegram = top.filter { it.isDirectory && (it.name == "td" || it.name == "user_td" || it.name.startsWith("td_extra_") && !it.name.startsWith("td_extra_files_")) }.sumOf { size(it) }
        val db = top.filter { it.name.startsWith("library.sqlite") }.sumOf { size(it) }
        val lyrics = repo.allSongs().first().sumOf { it.lyrics?.length?.toLong() ?: 0L }.coerceAtMost(db)
        // Android: the whole app data folder (the parent of `files`), as App info counts it; `lib` only links to the installed app.
        // Desktop: the data folder itself, since its parent is all of %APPDATA%.
        val appDir = if (root.name == "files") root.parentFile else null
        val total = appDir?.listFiles().orEmpty().filter { it.name != "lib" }.sumOf { size(it) }.takeIf { appDir != null } ?: size(root)
        val other = (total - songs - covers - telegram - db).coerceAtLeast(0L)
        // For a shared log: where the song bytes are and what is meant to keep them.
        runCatching {
            val all = repo.allSongs().first()
            fun mb(b: Long) = "${b shr 20} MB"
            val dirs = top.filter { it.isDirectory && (it.name.endsWith("_files") || it.name.startsWith("td_extra_files_")) }
                .flatMap { d -> d.listFiles().orEmpty().filter { it.isDirectory }.map { "${d.name}/${it.name} ${mb(size(it))}" } }
            io.max.paperplay.player.PlayLog.log(
                "storage",
                "Songs ${mb(songs)}: ${dirs.joinToString(", ")}. Limit ${mb(repo.cacheLimit())}. Kept on device: ${all.count { it.pinned }} songs, " +
                    "${mb(all.filter { it.pinned }.sumOf { it.size })}. Cached per library: ${all.count { it.cached_bytes > 0 }} songs, ${mb(all.sumOf { it.cached_bytes })}",
            )
        }
        return listOf("Songs" to songs, "Covers" to covers, "Lyrics" to lyrics, "Song info" to db - lyrics, "Telegram data" to telegram, "Other" to other)
    }

    /** Re-saves covers larger than 600 px at 600 px; nothing is lost. Reports what happened as text. */
    fun shrinkCovers(done: (String) -> Unit) {
        scope.launch(kotlinx.coroutines.Dispatchers.IO) {
            val freed = runCatching { services.covers.shrinkCovers() }
            done(freed.fold({ "Covers shrunk, ${it / (1L shl 20)} MB freed." }, { it.message ?: "The covers could not be shrunk." }))
        }
    }

    /** Deletes streamed audio TDLib keeps on disk. Reports what happened as text. */
    fun clearCache(done: (String) -> Unit) {
        scope.launch {
            val msg = try {
                if (services.clearDownloads()) "Cache cleared." else "Connect first, then clear the cache."
            } catch (e: Exception) {
                e.message ?: "The cache could not be cleared."
            }
            done(msg)
        }
    }

    /** What a running backup is doing and how far along (null fraction when unknown); null when none runs. */
    val backupProgress = MutableStateFlow<Pair<String, Double?>?>(null)

    /**
     * Builds a full backup (Flutter's format), asks the platform where to put it, and copies it there. With a
     * [password] the keys and account session are included, sealed with it. Returns a message to show.
     */
    suspend fun saveBackup(password: String?, suggestedName: String): String {
        val pick = BackupFiles.pickDestination ?: return "Saving a backup is not supported here."
        if (backupProgress.value != null) return "A backup is already running."
        val tmp = services.platform.dataDir.trimEnd('/', '\\') + "/backup-tmp.zip"
        backupProgress.value = "Starting" to 0.0
        return try {
            val summary = services.createBackup(tmp, password) { stage, fraction -> backupProgress.value = stage to fraction }
            backupProgress.value = "Choose where to save it, then it is copied" to null
            val dest = kotlinx.coroutines.suspendCancellableCoroutine<BackupDestination?> { c ->
                pick(suggestedName) { if (c.isActive) c.resumeWith(Result.success(it)) }
            }
            if (dest == null) "Backup not saved."
            else if (withContext(Dispatchers.Default) { dest.save(tmp) }) {
                "Backup saved: ${summary.songs} songs" + if (password != null && !summary.credentials) ". No bot keys to add yet." else "."
            } else "Backup not saved."
        } catch (e: kotlin.coroutines.cancellation.CancellationException) {
            throw e
        } catch (e: Exception) {
            "Couldn't save the backup: ${e.message ?: e::class.simpleName}"
        } finally {
            backupProgress.value = null
            io.max.paperplay.core.backup.Fs.deleteRecursively(tmp)
        }
    }

    // Equalizer: 31-band parametric profile (plus legacy 10-band compatibility).
    override val eqOn = MutableStateFlow(repo.pref("eq_on") == "true")
    override val eqGains = MutableStateFlow(
        io.max.paperplay.player.migrateEqGains(repo.pref("eq_gains")?.trim('[', ']', ' ')?.split(',')?.mapNotNull { it.trim().toFloatOrNull() }),
    )
    override val peqProfile = MutableStateFlow(
        repo.pref("peq_active_json")?.let { io.max.paperplay.player.ParametricEqCodec.parsePowerampJson(it) }
            ?: if (eqGains.value.any { kotlin.math.abs(it) >= 0.05f }) {
                io.max.paperplay.player.ParametricEqProfile.fromLegacy10Gains(eqGains.value)
            } else {
                io.max.paperplay.player.ParametricEqProfile.flat10()
            },
    )
    override val peqPresets = MutableStateFlow<List<io.max.paperplay.player.ParametricEqProfile>>(emptyList())
    override val eqDeviceKey = MutableStateFlow<String?>(null)
    override val eqDeviceAssigned = MutableStateFlow(false)
    override val eqDeviceAssignments = MutableStateFlow<List<io.max.paperplay.core.eq.DeviceEqAssignment>>(emptyList())
    private val autoEqUpdater by lazy { io.max.paperplay.core.eq.AutoEqUpdater(http) }
    override val onlineAutoEqItems = MutableStateFlow<List<io.max.paperplay.core.eq.AutoEqRemoteItem>>(emptyList())
    override val autoEqCount: Int get() = services.autoEqCatalog.entryCount

    private fun reloadEqPersistence() {
        scope.launch(Dispatchers.Default) {
            runCatching {
                peqPresets.value = services.eqRepo.allPresets()
                eqDeviceAssignments.value = services.eqRepo.allDeviceAssignments()
                val key = eqDeviceKey.value
                eqDeviceAssigned.value = key != null && eqDeviceAssignments.value.any { it.deviceKey == key }
            }
        }
    }

    init {
        reloadEqPersistence()
    }

    override fun setParametricProfile(profile: io.max.paperplay.player.ParametricEqProfile, enabled: Boolean) {
        peqProfile.value = profile
        eqOn.value = enabled
        repo.savePref("eq_on", "$enabled")
        repo.savePref("peq_active_json", io.max.paperplay.player.ParametricEqCodec.exportPowerampJson(profile, includePaperPlayMeta = true))
        val key = eqDeviceKey.value
        if (key != null && eqDeviceAssigned.value) {
            val label = eqOutput.value ?: key
            scope.launch(Dispatchers.Default) {
                runCatching {
                    services.eqRepo.assignToDevice(key, label, profile, enabled)
                    eqDeviceAssignments.value = services.eqRepo.allDeviceAssignments()
                }
            }
        }
        pushParametricToPlayer()
        pushBass()
    }

    override fun setParametricEnabled(enabled: Boolean) {
        setParametricProfile(peqProfile.value, enabled)
    }

    private fun pushParametricToPlayer() {
        if (!playerStarted.value) return
        val allowDirectEq = io.max.paperplay.ui.isPhone && allowEqInUsbExclusive.value
        val on = eqOn.value && (!bitPerfect.value || allowDirectEq)
        val prof = peqProfile.value
        if (on && prof.hasActiveShaping()) {
            // Parametric EQ takes ownership; clear legacy 10-band so they never stack.
            player.setEqualizer(null)
            player.setParametricEq(prof, true)
        } else {
            player.setParametricEq(null, false)
            player.setEqualizer(if (eqOn.value && !bitPerfect.value && eqGains.value.any { kotlin.math.abs(it) >= 0.05f }) eqGains.value else null)
        }
    }

    override fun saveParametricPreset(profile: io.max.paperplay.player.ParametricEqProfile) {
        val withId = if (profile.id.isBlank() || profile.id == "custom" || profile.id == "flat-10") {
            profile.copy(id = "user-${nowMoment().epochMs}")
        } else profile
        scope.launch(Dispatchers.Default) {
            runCatching {
                services.eqRepo.savePreset(withId)
                peqPresets.value = services.eqRepo.allPresets()
            }
        }
    }

    override fun deleteParametricPreset(id: String) {
        scope.launch(Dispatchers.Default) {
            runCatching {
                services.eqRepo.deletePreset(id)
                peqPresets.value = services.eqRepo.allPresets()
            }
        }
    }

    override fun assignEqToCurrentDevice() {
        val key = eqDeviceKey.value ?: return
        val label = eqOutput.value ?: key
        val prof = peqProfile.value
        val on = eqOn.value
        eqDeviceAssigned.value = true
        scope.launch(Dispatchers.Default) {
            runCatching {
                services.eqRepo.assignToDevice(key, label, prof, on)
                eqDeviceAssignments.value = services.eqRepo.allDeviceAssignments()
            }
        }
    }

    override fun unassignEqFromCurrentDevice() {
        val key = eqDeviceKey.value ?: return
        eqDeviceAssigned.value = false
        scope.launch(Dispatchers.Default) {
            runCatching {
                services.eqRepo.unassignDevice(key)
                eqDeviceAssignments.value = services.eqRepo.allDeviceAssignments()
            }
        }
    }

    override fun removeDeviceEqAssignment(deviceKey: String) {
        if (eqDeviceKey.value == deviceKey) eqDeviceAssigned.value = false
        scope.launch(Dispatchers.Default) {
            runCatching {
                services.eqRepo.unassignDevice(deviceKey)
                eqDeviceAssignments.value = services.eqRepo.allDeviceAssignments()
            }
        }
    }

    override suspend fun searchAutoEq(query: String, source: String?, form: String?): List<io.max.paperplay.core.eq.AutoEqEntry> =
        withContext(Dispatchers.IO) { services.autoEqCatalog.search(query, source, form, limit = 80) }

    override suspend fun autoEqSources(): List<String> =
        withContext(Dispatchers.IO) { services.autoEqCatalog.sources() }

    override suspend fun autoEqForms(): List<String> =
        withContext(Dispatchers.IO) { services.autoEqCatalog.forms() }

    override suspend fun refreshAutoEqIndex(): String = withContext(Dispatchers.IO) {
        try {
            val prevEtag = repo.pref("autoeq_index_etag")
            val res = autoEqUpdater.fetchIndex(prevEtag)
            if (res.notModified) {
                "AutoEQ catalog is already up to date."
            } else {
                res.etag?.let { repo.savePref("autoeq_index_etag", it) }
                onlineAutoEqItems.value = res.items
                "Refreshed online AutoEQ index (${res.items.size} entries)."
            }
        } catch (e: Exception) {
            "AutoEQ refresh failed: ${e.message ?: e::class.simpleName}"
        }
    }

    override suspend fun fetchOnlineAutoEqProfile(item: io.max.paperplay.core.eq.AutoEqRemoteItem): io.max.paperplay.player.ParametricEqProfile? =
        withContext(Dispatchers.IO) { runCatching { autoEqUpdater.fetchParametricProfile(item) }.getOrNull() }

    private val _outputInfo = MutableStateFlow<io.max.paperplay.player.OutputInfo?>(null)
    override val outputInfo: StateFlow<io.max.paperplay.player.OutputInfo?> = _outputInfo

    /** PC only: which audio engine plays (vlc or mpv; read when the app starts, so a change applies after a restart). */
    fun pcEngine(): String = services.platform.settings.get("pc_engine") ?: "vlc"
    override val hasBass: Boolean get() = io.max.paperplay.ui.isPhone || pcEngine() == "mpv"
    override val bitPerfectStatus: StateFlow<io.max.paperplay.player.BitPerfectStatus>
        get() = services.playback.bitPerfectStatus
    override val bitPerfect = MutableStateFlow(
        io.max.paperplay.player.PlatformBitPerfectPrefs.load(sqliteGet = repo::pref, sqliteSet = repo::setPref) == io.max.paperplay.player.BitPerfectMode.ON
    )
    override val allowEqInUsbExclusive = MutableStateFlow(
        io.max.paperplay.player.PlatformBitPerfectPrefs.loadAllowEqInUsbExclusive(sqliteGet = repo::pref, sqliteSet = repo::setPref)
    )

    override fun setAllowEqInUsbExclusive(allow: Boolean) {
        allowEqInUsbExclusive.value = allow
        io.max.paperplay.player.PlatformBitPerfectPrefs.saveAllowEqInUsbExclusive(allow, sqliteSet = repo::setPref)
        if (playerStarted.value) {
            player.setAllowEqInUsbExclusive(allow)
            pushParametricToPlayer()
        }
    }

    override fun setBitPerfect(on: Boolean) {
        bitPerfect.value = on
        io.max.paperplay.player.PlatformBitPerfectPrefs.save(
            if (on) io.max.paperplay.player.BitPerfectMode.ON else io.max.paperplay.player.BitPerfectMode.OFF,
            sqliteSet = repo::setPref,
        )
        if (io.max.paperplay.ui.isPhone) {
            usbExclusiveMode.value = on
            repo.savePref("usb_exclusive_mode", "$on")
            if (playerStarted.value) player.dacController?.setUsbExclusive(on)
            else services.playback.dacController?.setUsbExclusive(on)
        }
        exclusiveOutput.value = false
        if (!playerStarted.value) return
        pushBass()
        pushParametricToPlayer()
        player.setNormalize(!on && normalizeOn.value)
        player.setCorrectionProfile(correctionProfile.value.takeIf { it.isNotBlank() && !on })
        if (!io.max.paperplay.ui.isPhone) player.setBitPerfect(on)
    }
    fun setPcEngine(engine: String) { services.platform.settings.put("pc_engine", engine) }

    /** PC only: previous, play or pause and next under the taskbar preview. On unless switched off. */
    fun taskbarButtons(): Boolean = services.platform.settings.get("taskbar_buttons") != "off"
    fun setTaskbarButtons(on: Boolean) { services.platform.settings.put("taskbar_buttons", if (on) "on" else "off") }

    /** PC only (mpv engine): exclusive output for bit-perfect playback. */
    val exclusiveOutput = MutableStateFlow(repo.pref("pc_exclusive") == "true")

    fun setExclusiveOutput(on: Boolean) {
        exclusiveOutput.value = on
        repo.savePref("pc_exclusive", "$on")
        if (playerStarted.value) player.setExclusiveOutput(on || bitPerfect.value)
    }

    private val noUsbStatus = MutableStateFlow<io.max.paperplay.player.usb.UsbExclusiveStatus?>(null)
    private val noUsbDiscoveryHint = MutableStateFlow<io.max.paperplay.player.usb.DiscoveredUsbDacHint?>(null)

    /** Mirrored USB DAC preference kept aligned with [bitPerfect] on Android. */
    val usbExclusiveMode = MutableStateFlow(bitPerfect.value)
    val usbExclusiveStatus: StateFlow<io.max.paperplay.player.usb.UsbExclusiveStatus?>
        get() = services.playback.dacController?.usbExclusiveStatus ?: noUsbStatus
    val pendingUsbDiscoveryHint: StateFlow<io.max.paperplay.player.usb.DiscoveredUsbDacHint?>
        get() = services.playback.dacController?.pendingDiscoveryHint ?: noUsbDiscoveryHint

    fun dismissUsbDiscoveryHint(vidPid: String) {
        services.playback.dacController?.dismissDiscoveryHint(vidPid)
    }

    fun setUsbExclusiveMode(on: Boolean) {
        setBitPerfect(on)
    }

    /** Hidden developer options (unlocked by 7 taps on version in About). */
    val devOptionsUnlocked = MutableStateFlow(repo.pref("dev_options") == "true")
    fun unlockDevOptions() {
        devOptionsUnlocked.value = true
        repo.savePref("dev_options", "true")
    }

    /** Developer option: switch between unified Bit-perfect path and legacy USB sink without rebuilding. */
    val devUseUnifiedBitPerfect = MutableStateFlow(
        repo.pref("dev_use_unified_bit_perfect")?.let { it == "true" }
            ?: io.max.paperplay.player.USE_UNIFIED_BIT_PERFECT_DEFAULT
    )
    fun setDevUseUnifiedBitPerfect(on: Boolean) {
        devUseUnifiedBitPerfect.value = on
        repo.savePref("dev_use_unified_bit_perfect", "$on")
        if (playerStarted.value) player.dacController?.setUseUnifiedBitPerfect(on)
        else services.playback.dacController?.setUseUnifiedBitPerfect(on)
    }

    /** Developer option: Android 14+ MIXER_BEHAVIOR_BIT_PERFECT (off by default). */
    val devApi34Mixer = MutableStateFlow(repo.pref("dev_api34_bitperfect_mixer") == "true")
    fun setDevApi34Mixer(on: Boolean) {
        devApi34Mixer.value = on
        repo.savePref("dev_api34_bitperfect_mixer", "$on")
        if (playerStarted.value) player.dacController?.setDevApi34Mixer(on)
        else services.playback.dacController?.setDevApi34Mixer(on)
    }

    /** Developer option: Android audio sink chain ("full", "no_dsp", "plain"). */
    val sinkChain = MutableStateFlow(repo.pref("sink_chain") ?: io.max.paperplay.player.SinkChainMode.FULL.id)
    fun setSinkChain(mode: String) {
        val valid = io.max.paperplay.player.SinkChainMode.fromId(mode).id
        sinkChain.value = valid
        repo.savePref("sink_chain", valid)
        if (playerStarted.value) player.dacController?.setSinkChain(valid)
        else services.playback.dacController?.setSinkChain(valid)
    }

    suspend fun runUsbProbe(): String = services.playback.dacController?.runUsbProbe() ?: "USB probe is only supported on Android."
    suspend fun runUsbPlaybackTest(): String = services.playback.dacController?.runUsbPlaybackTest() ?: "USB playback test is only supported on Android."
    fun requestUsbPermission() { services.playback.dacController?.requestUsbPermission() }
    suspend fun exportUsbDebugLog(): String = services.playback.dacController?.exportUsbDebugLog() ?: "USB debug log is only supported on Android."
    fun triggerUsbPcmDump(enable: Boolean = true): String = services.playback.dacController?.triggerUsbPcmDump(enable) ?: "USB PCM dump is only supported on Android."
    fun getUsbPcmDumpStatus(): String = services.playback.dacController?.getUsbPcmDumpStatus() ?: "Off"
    fun getUsbPcmDumpPath(): String? = services.playback.dacController?.getUsbPcmDumpPath()
    fun getLastUsbFallbackLogPath(): String? = services.playback.dacController?.getLastUsbFallbackLogPath()

    /** PC only (mpv engine): an earphone correction curve in AutoEq GraphicEQ text, empty for none. */
    val correctionProfile = MutableStateFlow(repo.pref("pc_profile").orEmpty())

    fun setCorrectionProfile(text: String) {
        correctionProfile.value = text
        repo.savePref("pc_profile", text)
        if (playerStarted.value) player.setCorrectionProfile(text.takeIf { it.isNotBlank() && !bitPerfect.value })
    }

    /** Phone engine: true plays the drawn curve exactly (everything lowered by its peak), false keeps the music loud. */
    override val eqExact = MutableStateFlow(repo.pref("eq_exact") == "true")

    override fun setEqExact(on: Boolean) {
        eqExact.value = on
        repo.savePref("eq_exact", "$on")
        saveForOutput()
        if (playerStarted.value) player.setExactLevel(on)
    }

    override val eqOptions = MutableStateFlow(repo.pref("eq_options")?.toIntOrNull() ?: 0)

    override fun setEqOption(bit: Int, on: Boolean) {
        eqOptions.value = if (on) eqOptions.value or bit else eqOptions.value and bit.inv()
        repo.savePref("eq_options", "${eqOptions.value}")
        pushBass()
    }

    override val eqOutput = MutableStateFlow<String?>(null)

    /** The equalizer settings as one line, kept per output under `eq_out:<name>`. */
    private fun eqSnapshot(): String = listOf(
        "on=${eqOn.value}", "gains=${eqGains.value.joinToString(",")}", "bass=${eqBass.value}", "width=${eqWidth.value}",
        "earphone=${eqEarphone.value}", "exact=${eqExact.value}", "options=${eqOptions.value}",
    ).joinToString(";")

    private fun saveForOutput() { eqOutput.value?.let { repo.savePref("eq_out:$it", eqSnapshot()) } }

    /** Output device changed (earbuds, BT, USB DAC, wired, speaker, or desktop output). Applies any saved per-device mapping. */
    private fun onOutput(info: io.max.paperplay.player.OutputInfo) {
        val name = info.device ?: return
        val key = info.deviceKey ?: "out:$name"
        val keyChanged = key != eqDeviceKey.value
        val nameChanged = name != eqOutput.value
        if (!keyChanged && !nameChanged) return
        eqOutput.value = name
        eqDeviceKey.value = key

        val mapped = runCatching { services.eqRepo.assignmentForDevice(key) }.getOrNull()
        eqDeviceAssigned.value = mapped != null
        if (mapped != null) {
            peqProfile.value = mapped.profile
            eqOn.value = mapped.enabled
            repo.savePref("eq_on", "${mapped.enabled}")
            repo.savePref("peq_active_json", io.max.paperplay.player.ParametricEqCodec.exportPowerampJson(mapped.profile, includePaperPlayMeta = true))
            pushParametricToPlayer()
            pushBass()
            return
        }

        if (!io.max.paperplay.ui.isPhone) return
        val saved = repo.pref("eq_out:$name")
        if (saved == null) { saveForOutput(); return }
        val m = saved.split(';').mapNotNull { kv -> kv.split('=', limit = 2).takeIf { it.size == 2 }?.let { it[0] to it[1] } }.toMap()
        m["on"]?.let { eqOn.value = it == "true"; repo.savePref("eq_on", it) }
        m["gains"]?.split(',')?.mapNotNull { it.toFloatOrNull() }?.takeIf { it.size == eqGains.value.size }?.let {
            eqGains.value = it
            repo.savePref("eq_gains", it.joinToString(",", "[", "]"))
        }
        m["bass"]?.toFloatOrNull()?.let { eqBass.value = it; repo.savePref("eq_bass", "$it") }
        m["width"]?.toFloatOrNull()?.let { eqWidth.value = it; repo.savePref("eq_width", "$it") }
        m["earphone"]?.let { eqEarphone.value = it; repo.savePref("eq_earphone", it) }
        m["exact"]?.let { eqExact.value = it == "true"; repo.savePref("eq_exact", it) }
        m["options"]?.toIntOrNull()?.let { eqOptions.value = it; repo.savePref("eq_options", "$it") }
        if (playerStarted.value) {
            pushParametricToPlayer()
            player.setExactLevel(eqExact.value)
        }
        pushBass()
    }

    /** Phone engine: stereo width above the bass, 0.5 to 1.6 (1 = as recorded). Applies while the equalizer is on. */
    override val eqWidth = MutableStateFlow(repo.pref("eq_width")?.toFloatOrNull() ?: 1f)

    override fun setEqWidth(width: Float) {
        eqWidth.value = width
        repo.savePref("eq_width", "$width")
        pushBass()
    }

    override val eqEarphone = MutableStateFlow(repo.pref("eq_earphone").orEmpty())

    override fun setEqEarphone(name: String) {
        eqEarphone.value = name
        repo.savePref("eq_earphone", name)
        pushBass()
    }

    /** Phone engine A/B: plays the original at the processed level while held on. Not saved. */
    override val eqDry = MutableStateFlow(false)

    override fun setEqDry(on: Boolean) {
        eqDry.value = on
        if (playerStarted.value) player.setDryCompare(on)
    }

    override val eqBass = MutableStateFlow(repo.pref("eq_bass")?.toFloatOrNull() ?: 0f)

    override fun setEqBass(db: Float) {
        eqBass.value = db
        repo.savePref("eq_bass", "$db")
        pushBass()
    }

    private fun pushBass() {
        saveForOutput()
        if (!playerStarted.value) return
        val on = eqOn.value && !bitPerfect.value
        player.setBass(if (on) eqBass.value else 0f)
        player.setStereoWidth(if (on) eqWidth.value else 1f)
        player.setEarphoneCorrection(if (on) io.max.paperplay.player.CorrectionProfile.EARPHONES[eqEarphone.value] else null)
        player.setEngineOptions(if (on) eqOptions.value else 0)
    }

    override fun setEqualizer(on: Boolean, gains: List<Float>) {
        eqOn.value = on
        eqGains.value = gains
        repo.savePref("eq_on", "$on")
        repo.savePref("eq_gains", gains.joinToString(",", "[", "]"))
        if (playerStarted.value) player.setEqualizer(if (on && !bitPerfect.value) gains else null)
        pushBass()
    }

    // ListenBrainz: the token lives in the secret store, never in a plain preference.
    private val listenBrainz = ListenBrainz(http)
    val lbUser = MutableStateFlow(
        if (services.platform.secrets.get(io.max.paperplay.core.backup.SecretKeys.LISTENBRAINZ_TOKEN) == null) null
        else repo.pref("listenbrainz_user")?.takeIf { it.isNotEmpty() } ?: "your account",
    )


    /** Checks the token with ListenBrainz and keeps it. Returns a problem as text, or null when it worked. */
    suspend fun connectListenBrainz(token: String): String? {
        val t = token.trim()
        if (t.isEmpty()) return "Paste your ListenBrainz user token."
        val user = try { listenBrainz.validate(t) } catch (e: Exception) { return "ListenBrainz could not be reached." }
            ?: return "ListenBrainz does not accept that token."
        services.platform.secrets.put(io.max.paperplay.core.backup.SecretKeys.LISTENBRAINZ_TOKEN, t)
        repo.savePref("listenbrainz_user", user)
        repo.savePref("listenbrainz_on", "true")
        lbUser.value = user
        return null
    }

    fun disconnectListenBrainz() {
        services.platform.secrets.remove(io.max.paperplay.core.backup.SecretKeys.LISTENBRAINZ_TOKEN)
        repo.savePref("listenbrainz_user", "")
        repo.savePref("listenbrainz_on", "false")
        lbUser.value = null
    }


    /** What the app has been doing, newest last. Kept in memory; bot tokens are blanked out. */
    val log = MutableStateFlow<List<LogLine>>(emptyList())
    private var lastScanLog = 0L

    /** Running background jobs and their history; features call tasks.start/update/finish. */
    val tasks = io.max.paperplay.core.app.TaskQueue(scope, load = { repo.pref("task_history") }, save = { repo.savePref("task_history", it) }).also { q -> scope.launch(Dispatchers.Default) { q.watchServices(services) } }

    /** Every playback event and every activity line, on disk and kept across restarts, so a whole listening session can be shared. */
    val playLog = io.max.paperplay.core.app.PlayLogFile(services.platform.dataDir, scope) { at ->
        io.max.paperplay.ui.localTimeLabel(at) + "." + (at % 1000).toString().padStart(3, '0')
    }.also { f ->
        io.max.paperplay.player.PlayLog.nowMs = { nowMoment().epochMs }
        io.max.paperplay.player.PlayLog.sink = { at, tag, m -> f.add(at, tag, m) }
    }

    init {
        io.max.paperplay.core.app.MemoryProbe.start(scope) { "Jobs: ${tasks.running.value.size}" }
        // Clean up legacy volume limit and calibration preferences
        repo.savePref("usb_max_vol_limit_db", "")
    }

    fun addLog(source: String, message: String, error: Boolean = false) {
        val clean = message.replace(Regex("\\b\\d{5,}:[A-Za-z0-9_-]{20,}\\b"), "<bot token>")
        io.max.paperplay.player.PlayLog.log("app/$source", clean + if (error) "  [error]" else "")
        log.value = (log.value + LogLine(nowMoment().epochMs, source, clean, error)).takeLast(3000)
    }

    fun clearLog() { log.value = emptyList() }

    init {
        services.activityLog = { source, line -> addLog(source, line) }
        scope.launch { services.auth.collect { if (it.isNotEmpty()) addLog("Telegram", it.removePrefix("authorizationState")) } }
        scope.launch {
            services.scanner.report.collect {
                if (it != null) {
                    addLog("Scan", it)
                    // New songs from other chats are filed into the main chat's topics when the owner switched that on.
                    if (services.autoFiler.enabled()) services.autoFiler.start()
                }
            }
        }
        scope.launch { services.error.collect { if (it != null) addLog("Telegram", it, error = true) } }
        scope.launch {
            services.scanner.progress.collect { p ->
                val t = nowMoment().epochMs
                if (p != null && t - lastScanLog > 10_000) { lastScanLog = t; addLog("Scan", p.text) }
            }
        }
    }

    private class HomePlanState(val plan: HomeMix? = null, val mixes: List<DailyMix> = emptyList())

    /**
     * The Home page plan: quick tiles, shelves and daily mixes. Replanned when the library, the favorites or the
     * day changes, not on every play or cover update, so rows stay put while cover art pops in live.
     */
    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    @Volatile private var homePlanned = false

    /** The daily mixes last shown: a plan that comes back empty (a partly loaded library, a failed build) must not take them away. */
    @Volatile private var lastMixes: List<DailyMix> = emptyList()
    private fun sizeBucket(n: Int) = if (n < 200) n else 200 + n / 100
    private fun saveHome(plan: io.max.paperplay.core.recs.HomeMix, mixes: List<DailyMix>) {
        runCatching { repo.savePref(HomeSnapshot.PREF, HomeSnapshot.encode(plan, mixes)) }
    }

    private val homePlan: Flow<HomePlanState> = combine(
        repo.allSongs(), repo.recents(30), repo.favorites(), repo.playlistSummaries(),
        combine(taste, weather, services.scanner.progress.map { it != null }, services.covers.queued.map { it > 0 }) { t, w, scanning, covering ->
            Triple(t, w, scanning || covering)
        },
    ) { songs, recent, fav, lists, tw ->
        // Only the playlist count is needed, so the plan no longer waits for the whole library (all songs, albums, artists) to be built.
        HomeInput(songs, recent, fav, minOf(lists.size, 3) + if (fav.isEmpty()) 0 else 1, tw.first, tw.second, tw.third)
    }
        .distinctUntilChangedBy {
            "${it.favorites.size}:${it.reserved}:${if (homePlanned) it.taste.at.toString() else "-"}:${it.taste.showMixes}:${if (homePlanned) "${it.weather}:${it.busy}" else "-"}:${sizeBucket(it.songs.size)}:${nowMoment().dayKey}"
        }
        .transformLatest { input ->
            if (input.songs.isEmpty()) { emit(HomePlanState()); return@transformLatest }
            // Replanning waits two quiet seconds (a newer input cancels this one); the first plan is not delayed.
            if (homePlanned) delay(2_000L)
            val now = nowMoment()
            val plan = HomeShelves.plan(input.songs, input.recent, input.favorites, now, tileCount = 6 - input.reserved)
            val leadSongs = buildList {
                plan.tiles.forEach { add(it.cover); addAll(it.songs.take(1)) }
                plan.shelves.forEach { s ->
                    addAll(s.songs.take(8))
                    s.groups.take(8).forEach { add(it.cover) }
                }
            }.distinctBy { it.unique_id }
            if (leadSongs.isNotEmpty()) services.covers.prioritize(leadSongs)
            // Covers already on disk are decoded now, so Home shows its art as soon as it is drawn instead of a moment later.
            // The first screen waits up to 0.7 s for its lead covers, so it is drawn with them and they do not pop in one by one.
            kotlinx.coroutines.coroutineScope {
                launch { SharedCovers.loader.preloadAndWait(plan.tiles.mapNotNull { it.cover.cover_path }, 160, 700) }
                launch { SharedCovers.loader.preloadAndWait(leadSongs.mapNotNull { it.cover_path }, 512, 700) }
            }
            // Only now does the next plan wait: a first plan cut short by the scan or the covers starting used to delay its own redo by 2 s.
            homePlanned = true
            // Tiles and shelves show at once; the slower daily mixes join when they are ready.
            if (!input.taste.showMixes) { emit(HomePlanState(plan = plan)); saveHome(plan, emptyList()); return@transformLatest }
            // Saved mixes show at once, even from an older day or library; fresh ones replace them when computed.
            // Rebuilt every three hours (the hour matters), and as listens and measured songs come in.
            val mixKey = "${now.dayKey}:${now.hour / 3}:${sizeBucket(input.songs.size)}:${input.favorites.size}:${input.taste.at}:" +
                "${runCatching { services.playEvents.count() / 10 }.getOrDefault(0)}:${runCatching { services.audioFeatures.count() / 50 }.getOrDefault(0)}"
            val cached = runCatching { DailyMixCache.decode(repo.pref(DailyMixCache.PREF), input.songs.associateBy { it.unique_id }) }.getOrNull()
            val shown = cached?.second.orEmpty().ifEmpty { lastMixes }
            if (shown.isNotEmpty()) lastMixes = shown
            emit(HomePlanState(plan = plan, mixes = shown))
            saveHome(plan, shown)
            if (cached != null && cached.first == mixKey && cached.second.isNotEmpty()) return@transformLatest
            // Building mixes is heavy: not while the library is scanning or covers are loading.
            if (input.busy) return@transformLatest
            val daily = runCatching {
                io.max.paperplay.core.recs.RecMixes.build(
                    input.songs, services.audioFeatures.all(),
                    services.playEvents.all().let { ev -> if (input.taste.useListens) ev else ev.filter { it.heardMs == 0L } }, tasteLists(input.favorites, input.taste), now,
                )
            }.getOrDefault(emptyList())
            val mixLead = daily.flatMap { it.songs.take(4) }.distinctBy { it.unique_id }
            if (mixLead.isNotEmpty()) services.covers.prioritize(mixLead)
            if (daily.isNotEmpty()) runCatching { repo.savePref(DailyMixCache.PREF, DailyMixCache.encode(mixKey, daily)) }
            // An empty build keeps what is on screen instead of making the mixes disappear.
            val mixes = daily.ifEmpty { shown }
            if (mixes.isNotEmpty()) lastMixes = mixes
            emit(HomePlanState(plan = plan, mixes = mixes))
            saveHome(plan, mixes)
        }

    private val homeLive: Flow<HomeUi> = combine(repo.allSongs(), homePlan) { songs, state ->
        val plan = state.plan ?: return@combine HomeUi()
        val freshById = songs.associateBy { it.unique_id }
        buildHomeUi(plan, state.mixes) { freshById[it.unique_id] ?: it }
    }

    /** The saved page being loaded since the services started (see [loadSavedHome]); set by the app before the screen asks for [home]. */
    @Volatile var preloadedHome: kotlinx.coroutines.Deferred<HomeUi?>? = null

    /** Set once the real plan has produced a page, so a saved page that is still loading never replaces it. */
    @Volatile private var homeIsLive = false

    val home: StateFlow<HomeUi> = kotlinx.coroutines.flow.channelFlow {
        // Last launch's page first (in parallel with the real plan), unless the real one got there before it.
        launch { runCatching { (preloadedHome?.await() ?: loadSavedHome(services)) }.getOrNull()?.let { if (!homeIsLive) send(it) } }
        homeLive.collect { homeIsLive = true; send(it) }
    }
        .catch { emit(HomeUi()) }
        .flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.WhileSubscribed(5_000), HomeUi())

    /**
     * Starts building what Home shows while the shell is still being drawn for the first time. The lists are only built while something
     * collects them, so without this the page waited for its first frame before the library was even read. The shared flows stay alive
     * five seconds after the last collector leaves, which is when the screen takes over.
     */
    fun warmUp() {
        scope.launch {
            try {
                kotlinx.coroutines.withTimeoutOrNull(12_000) {
                    kotlinx.coroutines.coroutineScope {
                        launch { home.first { it.shelves.isNotEmpty() || it.tiles.isNotEmpty() } }
                        launch { library.first { it.songs !is Load.Loading } }
                        launch { favorites.first(); recents.first() }
                        launch { telegram.first() }
                    }
                }
            } finally {
                homeWarm.value = true
            }
        }
    }

    /** True once everything Home shows has arrived, so Home draws once, complete, instead of changing under its own animation. */
    val homeWarm = kotlinx.coroutines.flow.MutableStateFlow(false)

    /** Records "does not fit" for [song] in the mix [moodId]; the next mix leaves it out. */
    fun rejectFromMix(song: SongUi, moodId: String) = voteMix(song, moodId, -1)

    fun undoRejectFromMix(song: SongUi, moodId: String) = voteMix(song, moodId, 0)

    private fun voteMix(song: SongUi, @Suppress("UNUSED_PARAMETER") moodId: String, vote: Int) {
        val s = repo.songByUniqueId(song.id) ?: return
        if (vote < 0) services.playEvents.reject(s.unique_id, nowMoment().epochMs, s.duration_sec * 1000L) else services.playEvents.unreject(s.unique_id)
    }

    private var queueCache: Triple<List<Song>, Long, List<SongUi>> = Triple(emptyList(), -1L, emptyList())
    private var currentCache: Pair<Song?, SongUi?> = null to null

    /** The player is created here on first use, on a background thread, so startup does not wait for it. */
    /**
     * Output volume, 0 to 1. Where the system offers a media volume (Android, Windows) this follows it and the bar changes it,
     * so the app has no second volume; elsewhere it is the app's own volume, kept here since the engines do not report it.
     */
    override val volume = kotlinx.coroutines.flow.MutableStateFlow(repo.pref("player_volume")?.toFloatOrNull()?.coerceIn(0f, 1f) ?: 1f)
    @Volatile private var systemVolume = false


    override val speed = MutableStateFlow(repo.pref("player_speed")?.toFloatOrNull()?.coerceIn(0.5f, 2f) ?: 1f)

    override fun setSpeed(speed: Float) {
        val v = speed.coerceIn(0.5f, 2f)
        this.speed.value = v
        repo.savePref("player_speed", v.toString())
        if (playerStarted.value) player.setSpeed(v)
    }

    /** Evens out loud and quiet songs; see the Listening settings. */
    val normalizeOn = MutableStateFlow(repo.pref("normalize") == "true")

    fun setNormalize(on: Boolean) {
        normalizeOn.value = on
        repo.savePref("normalize", "$on")
        if (playerStarted.value) player.setNormalize(on && !bitPerfect.value)
    }

    override fun removeFromQueue(index: Int) { withPlayer { it.removeAt(index) } }
    override fun moveInQueue(from: Int, to: Int) { withPlayer { it.moveInQueue(from, to) } }

    /** False until something plays; the audio stack is not created before that. */
    private val playerStarted = MutableStateFlow(false)

    private val player: io.max.paperplay.core.app.PlaybackController get() {
        playerStarted.value = true
        return playerLazy.value
    }

    /** Runs [block] on the player; the first call creates it off the calling thread. */
    private fun withPlayer(block: (io.max.paperplay.core.app.PlaybackController) -> Unit) {
        if (playerLazy.isInitialized()) block(player) else scope.launch(Dispatchers.Default) { block(player) }
    }

    private val playerLazy = lazy {
        services.playback.also { p ->
            scope.launch { p.outputInfo.collect { _outputInfo.value = it; if (it != null) onOutput(it) } }
            val bp = bitPerfect.value
            val allowDirectEq = io.max.paperplay.ui.isPhone && allowEqInUsbExclusive.value
            p.setAllowEqInUsbExclusive(allowEqInUsbExclusive.value)
            if (eqOn.value && (!bp || allowDirectEq)) {
                val prof = peqProfile.value
                if (prof.hasActiveShaping()) {
                    p.setParametricEq(prof, true)
                } else if (!bp) {
                    p.setEqualizer(eqGains.value)
                }
                if (!bp) p.setBass(eqBass.value)
            }
            p.setExactLevel(eqExact.value)
            if (eqOn.value && !bp) {
                p.setStereoWidth(eqWidth.value)
                p.setEarphoneCorrection(io.max.paperplay.player.CorrectionProfile.EARPHONES[eqEarphone.value])
                p.setEngineOptions(eqOptions.value)
            }
            if (io.max.paperplay.ui.isPhone) p.dacController?.setUsbExclusive(bp) else p.setBitPerfect(bp)
            p.dacController?.setSinkChain(sinkChain.value)
            if (!bp) correctionProfile.value.takeIf { it.isNotBlank() }?.let { p.setCorrectionProfile(it) }
            if (!systemVolume && volume.value != 1f) p.setVolume(volume.value)
            if (speed.value != 1f) p.setSpeed(speed.value)
            if (normalizeOn.value && !bp) p.setNormalize(true)
            p.suggestNext = { queue -> suggestAfter(queue) }
            p.privateSession = privateSession.value
            // A listen counts after half the song or four minutes, whichever comes first.
            p.onListened = { song, ms ->
                val token = services.platform.secrets.get(io.max.paperplay.core.backup.SecretKeys.LISTENBRAINZ_TOKEN)
                val full = song.duration_sec * 1000L
                val counts = if (full > 0) ms >= minOf(full / 2, 240_000L) else ms >= 30_000L
                if (token != null && repo.pref("listenbrainz_on") == "true" && counts) scope.launch {
                    val ok = runCatching { listenBrainz.submit(token, song, (nowMoment().epochMs - ms) / 1000) }.getOrDefault(false)
                    // Kept for later (no network, a busy service): when, and which song; sent again after the next one that goes through.
                    listenQueueLock.lock()
                    try {
                        val queue = repo.pref("listenbrainz_queue").orEmpty().lines().filter { it.contains('\t') }
                        if (!ok) {
                            addLog("ListenBrainz", "Could not send \"${song.title}\" now; it is sent later.", error = true)
                            repo.setPref("listenbrainz_queue", (queue + "${(nowMoment().epochMs - ms) / 1000}\t${song.unique_id}").takeLast(500).joinToString("\n"))
                        } else if (queue.isNotEmpty()) {
                            val left = queue.toMutableList()
                            for (line in queue.take(50)) {
                                val s = repo.songByUniqueId(line.substringAfter('\t'))
                                if (s != null && !runCatching { listenBrainz.submit(token, s, line.substringBefore('\t').toLong()) }.getOrDefault(false)) break
                                left.remove(line)
                                kotlinx.coroutines.delay(500)
                            }
                            repo.setPref("listenbrainz_queue", left.joinToString("\n"))
                        }
                    } finally {
                        listenQueueLock.unlock()
                    }
                }
            }
        }
    }

    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    /** Puts the last queue back, paused, once the connection is up (or after 20 seconds) and nothing has been played. */
    val sessionRestore: Boolean get() = repo.pref("restore_session") != "false"

    fun setSessionRestore(on: Boolean) = repo.savePref("restore_session", "$on")

    init {
        scope.launch(Dispatchers.Default) {
            if (!sessionRestore) return@launch
            kotlinx.coroutines.withTimeoutOrNull(20_000) { services.ready.first { it } }
            if (!playerStarted.value && sessionRestore) withPlayer { it.restoreSession() }
        }
    }

    /** Lyrics are fetched for every song in the background so opening one shows them at once. On unless turned off. */
    val lyricsAuto: Boolean get() = repo.pref("lyrics_auto") != "false"

    fun setLyricsAuto(on: Boolean) = repo.savePref("lyrics_auto", "$on")

    init {
        scope.launch(Dispatchers.Default) {
            kotlinx.coroutines.withTimeoutOrNull(60_000) { services.ready.first { it } }
            // Once after start, when the catch-up has settled: lyrics for songs that have none yet. Song info and covers are not
            // asked again here; what could not be found stays as it is until a scan from the Scan library page starts them.
            kotlinx.coroutines.delay(30_000)
            if (lyricsAuto && taste.value.lookups && !lyricsRunning.value) startLyricsRun()
        }
    }

    private val localNowPlaying: Flow<NowPlaying> = playerStarted
        .transformLatest { started -> if (started) emitAll(playerLazy.value.nowPlaying) }
        .flowOn(Dispatchers.Default)

    /** The device the player controls: null is this one, else the id of a linked device. */
    val activeOutput: StateFlow<String?> get() = services.activeOutput

    /** What a tap on a remote control just changed, shown until the other device's own state is newer. */
    private val remoteGuess = MutableStateFlow<Pair<String, io.max.paperplay.core.sync.RemoteNow>?>(null)

    /** The linked device's playing state as a [NowPlaying], moved on every half second while it plays so the seek bar runs without polling. */
    private fun remoteNowPlaying(id: String): Flow<NowPlaying?> = flow {
        val lan = services.lanSync
        if (lan == null) { emit(null); return@flow }
        while (true) {
            val reported = lan.remoteNow.value[id]
            val guess = remoteGuess.value?.takeIf { it.first == id }?.second
            val now = if (guess != null && (reported == null || guess.at >= reported.at)) guess else reported
            val song = now?.uniqueId?.let { byId[it] ?: repo.songByUniqueId(it) }
            emit(
                if (now == null || song == null || !now.fresh(System.currentTimeMillis())) null
                else NowPlaying(song, now.positionAt(System.currentTimeMillis()), now.durationMs, now.playing, 0, listOf(song)),
            )
            kotlinx.coroutines.delay(500)
        }
    }

    @OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
    private val nowPlayingFlow: Flow<NowPlaying> = combine(
        localNowPlaying.onStart { emit(NowPlaying()) },
        services.activeOutput.flatMapLatest { id -> if (id == null) flowOf(null) else remoteNowPlaying(id) },
    ) { local, remote -> remote ?: local }
        .flowOn(Dispatchers.Default)

    /** The cover file of a song by unique id, for another device's now playing. */
    fun songCover(uniqueId: String): String? = (byId[uniqueId] ?: repo.songByUniqueId(uniqueId))?.cover_path

    /** Moves playback to [deviceId] (null: this device). Tells the user when it cannot be done. */
    fun switchOutput(deviceId: String?, move: Boolean = false, notice: (String) -> Unit = {}) {
        scope.launch {
            if (!services.switchOutput(deviceId, move)) notice(if (deviceId == null) "Could not take playback back" else "Could not reach that device")
        }
    }

    /** Sends [action] to the active remote device and shows its effect at once. False when playback is on this device. */
    private fun remote(action: String, guess: (io.max.paperplay.core.sync.RemoteNow) -> io.max.paperplay.core.sync.RemoteNow): Boolean {
        val id = services.activeOutput.value ?: return false
        val lan = services.lanSync ?: return false
        val now = System.currentTimeMillis()
        val last = remoteGuess.value?.takeIf { it.first == id }?.second ?: lan.remoteNow.value[id]
        if (last != null) remoteGuess.value = id to guess(last.copy(positionMs = last.positionAt(now), at = now))
        scope.launch { lan.sendControl(id, action) }
        return true
    }

    /** Everything about playback except the position: it changes on a song, queue or button, not every tick. */
    val playbackMeta: StateFlow<PlaybackUiState> = combine(
        nowPlayingFlow.distinctUntilChanged { a, b ->
            a.song?.unique_id == b.song?.unique_id && a.index == b.index && a.isPlaying == b.isPlaying &&
                a.durationMs == b.durationMs && a.shuffle == b.shuffle && a.repeat == b.repeat &&
                (a.queue === b.queue || a.queue == b.queue)
        }.onEach { np -> prioritizeNowPlaying(np) },
        repo.changes,
        songsVersion,
    ) { np, changes, version -> np.toUi(changes * 1_000_003L + version) }
        .distinctUntilChanged()
        .flowOn(Dispatchers.Default).stateIn(scope, SharingStarted.Eagerly, PlaybackUiState())

    /** Same as [playbackMeta]; kept for callers that only need the song or the play state. */
    val playback: StateFlow<PlaybackUiState> get() = playbackMeta

    /** Position and buffered time. Only the seek bar, mini progress and lyrics should read this. */
    override val position: StateFlow<PositionUi> = nowPlayingFlow.map { PositionUi(it.positionMs, it.bufferedMs) }
        .distinctUntilChanged()
        .stateIn(scope, SharingStarted.WhileSubscribed(5_000), PositionUi())

    private var lastPriority: Pair<String?, Int> = null to -2

    private fun prioritizeNowPlaying(np: NowPlaying) {
        val key = np.song?.unique_id to np.index
        if (key == lastPriority) return
        lastPriority = key
        val idx = np.index.coerceAtLeast(0)
        val upcoming = if (idx < np.queue.size) np.queue.subList(idx, minOf(idx + 3, np.queue.size)) else emptyList()
        val priority = (listOfNotNull(np.song) + upcoming).distinctBy { it.unique_id }
        if (priority.isNotEmpty()) services.covers.prioritize(priority)
    }

    private fun NowPlaying.toUi(changes: Long): PlaybackUiState {
        // The queue is mapped once per queue or library cover update, not per tick.
        val ui = if (queueCache.first === queue && queueCache.second == changes) {
            queueCache.third
        } else {
            queue.map { (byId[it.unique_id] ?: it).toUi() }.also { queueCache = Triple(queue, changes, it) }
        }
        val currentSong = song?.let { byId[it.unique_id] ?: it }
        val currentUi = if (currentCache.first === currentSong) currentCache.second
        else currentSong?.toUi().also { currentCache = currentSong to it }
        return PlaybackUiState(
            current = currentUi,
            playing = isPlaying,
            durationMs = durationMs,
            shuffle = shuffle,
            repeat = when (repeat) { Repeat.OFF -> RepeatUi.Off; Repeat.ALL -> RepeatUi.All; Repeat.ONE -> RepeatUi.One },
            queue = ui,
            queueIndex = index,
        )
    }

    /** Text of the last failure to start a track. */
    val playbackError: StateFlow<String?> = nowPlayingFlow.map { it.error }.distinctUntilChanged()
        .stateIn(scope, SharingStarted.Eagerly, null)

    val connection: StateFlow<ConnectionUi> = combine(
        services.auth, services.ready, services.error, repo.chats(),
    ) { auth, ready, error, chats ->
        ConnectionUi(services.hasCredentials, auth, ready, error, chats)
    }.stateIn(scope, SharingStarted.Eagerly, ConnectionUi(hasCredentials = services.hasCredentials))

    /** The running scan, read only by the status chip, the task row and the task page. */
    val scan: StateFlow<ScanUi?> = services.scanner.progress.map { p -> p?.let { ScanUi(it.text, it.fraction) } }
        .stateIn(scope, SharingStarted.Eagerly, null)

    /** True while a scan runs; changes twice per scan, unlike [scan]. */
    val scanning: StateFlow<Boolean> = services.scanner.progress.map { it != null }.distinctUntilChanged()
        .stateIn(scope, SharingStarted.Eagerly, false)

    // Reading
    fun album(name: String, owner: String? = null): Flow<List<SongUi>> = repo.album(name).map { list ->
        if (owner == null) list
        else io.max.paperplay.core.library.splitAlbum(list) { it.artist }.firstOrNull { it.first == owner }?.second ?: list
    }
        .onEach { if (it.isNotEmpty()) services.covers.prioritize(it.take(30)) }
        .map { it.map(Song::toUi) }.flowOn(Dispatchers.Default)
    fun artist(name: String): Flow<List<SongUi>> = repo.artist(name)
        .onEach { if (it.isNotEmpty()) services.covers.prioritize(it.take(30)) }
        .map { it.map(Song::toUi) }.flowOn(Dispatchers.Default)
    fun playlist(id: Long): Flow<List<SongUi>> = repo.playlistSongs(id)
        .onEach { if (it.isNotEmpty()) services.covers.prioritize(it.take(30)) }
        .map { songs ->
            // Spotify's added date, when the import has it, so "Date added" sorts like Spotify.
            val dates = io.max.paperplay.core.integrations.ImportStore(services.library.repo, services.driver).entries(id)
                .filter { it.removed_at == null && it.source_added_at != null }.associate { (it.chat_id to it.message_id) to it.source_added_at!! }
            songs.map { s -> s.toUi().let { u -> dates[s.chat_id to s.message_id]?.let { u.copy(addedAt = it) } ?: u } }
        }.flowOn(Dispatchers.Default)
    fun search(query: String): Flow<List<SongUi>> = repo.search(query)
        .onEach { if (it.isNotEmpty()) services.covers.prioritize(it.take(20)) }
        .map { it.map(Song::toUi) }.flowOn(Dispatchers.Default)

    // Playing
    fun play(songs: List<SongUi>, index: Int) {
        val list = songs.mapNotNull { byId[it.id] }
        if (list.isEmpty()) return
        val start = list.indexOfFirst { it.unique_id == songs.getOrNull(index)?.id }.coerceAtLeast(0)
        // While another device is chosen, the song plays there; this device keeps what it plays.
        val target = services.activeOutput.value
        val lan = services.lanSync
        if (target != null && lan != null) { scope.launch { services.sendQueue(lan, target, list, start, 0) }; return }
        withPlayer { it.setQueue(list, start) }
    }

    /** Plays an indexed post on its own without adding it to the library; see [io.max.paperplay.core.app.IndexPreview]. */
    fun previewPost(post: io.max.paperplay.core.account.ChatPost) {
        scope.launch(Dispatchers.Default) {
            val full = if (post.thumb == null) post.copy(thumb = postThumb(post.chatId, post.messageId)) else post
            val song = services.indexPreview.song(full)
            withPlayer { it.setQueue(listOf(song), 0) }
        }
    }

    private val liveThumbs = object : LinkedHashMap<Long, ByteArray?>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Long, ByteArray?>?) = size > 150
    }

    /** A post's tiny cover: the saved index first, else asked from Telegram and kept in memory only (never saved). Call off the main thread. */
    fun postThumb(chatId: Long, messageId: Long): ByteArray? {
        chatIndex.thumb(chatId, messageId)?.let { return it }
        val key = chatId * 1_000_003L + messageId
        synchronized(liveThumbs) { if (liveThumbs.containsKey(key)) return liveThumbs[key] }
        val bytes = kotlinx.coroutines.runBlocking { account.postThumb(chatId, messageId) }
        synchronized(liveThumbs) { liveThumbs[key] = bytes }
        return bytes
    }

    fun isPreview(id: String): Boolean = services.indexPreview.isPreview(id)

    /** Copies the song playing from the index to the main chat. Returns the message for the user. */
    suspend fun copyPreview(id: String): String = withContext(Dispatchers.Default) {
        val s = services.playback.nowPlaying.value.song?.takeIf { it.unique_id == id } ?: return@withContext "Nothing to copy"
        val post = services.chatIndex.postsByIds(s.chat_id, listOf(s.message_id)).firstOrNull() ?: return@withContext "Not in the index"
        runCatching { services.chatIndex.copyToMain(post) }.fold({ "Copying ${s.title} to your main chat" }, { "Could not copy: ${it.message}" })
    }

    fun shuffleAll(songs: List<SongUi>) {
        val list = songs.mapNotNull { byId[it.id] }.shuffled()
        if (list.isEmpty()) return
        withPlayer { it.setQueue(list, 0) }
    }

    override fun togglePlay() {
        val playing = playbackMeta.value.playing
        if (remote(if (playing) "pause" else "play") { it.copy(playing = !playing) }) return
        if (playing) player.pause() else player.play()
    }
    override fun next() { if (!remote("next") { it }) player.next() }
    override fun previous() { if (!remote("previous") { it }) player.previous() }
    override fun seekTo(fraction: Float) {
        val ms = (fraction * playbackMeta.value.durationMs).toLong()
        if (!remote("seek:$ms") { it.copy(positionMs = ms) }) player.seek(ms)
    }
    override fun setVolume(v: Float) {
        volume.value = v.coerceIn(0f, 1f)
        val isUsb = usbExclusiveMode.value && (usbExclusiveStatus.value?.isConnected == true)
        if (systemVolume && !isUsb) {
            scope.launch(Dispatchers.Default) { io.max.paperplay.player.SystemVolume.set(volume.value) }
            return
        }
        if (systemVolume && isUsb) {
            scope.launch(Dispatchers.Default) { io.max.paperplay.player.SystemVolume.set(volume.value) }
            repo.savePref("player_volume", volume.value.toString())
            return
        }
        if (playerStarted.value) player.setVolume(volume.value)
        repo.savePref("player_volume", volume.value.toString())
    }

    override fun toggleShuffle() { player.setShuffle(!playbackMeta.value.shuffle) }
    override fun cycleRepeat() { player.setRepeat(
        when (playbackMeta.value.repeat) { RepeatUi.Off -> Repeat.ALL; RepeatUi.All -> Repeat.ONE; RepeatUi.One -> Repeat.OFF },
    ) }
    override fun playQueueIndex(index: Int) {
        // A song picked from the queue plays in place; the queue is not rebuilt (that reshuffled it while shuffle was on).
        player.playIndex(index)
    }

    // Editing
    fun setFavorite(id: String, favorite: Boolean) {
        val s = byId[id] ?: return
        if (s.favorite != favorite) scope.launch(Dispatchers.IO) { repo.toggleFavorite(s) }
    }

    fun setPinned(id: String, pinned: Boolean) = services.setPinned(listOf(id), pinned)

    /** Deletes the song's post from Telegram (main chat only) and from the library; [say] gets the outcome. */
    fun deleteSong(id: String, say: (String) -> Unit) {
        val s = byId[id] ?: return
        scope.launch(Dispatchers.IO) {
            val queue = services.deleteQueue
            val msg = try {
                if (queue.deleteSongs(listOf(s)) > 0) {
                    val kept = queue.keptElsewhere
                    if (kept > 0) "Deleted \"${s.title}\" from the main chat; $kept ${if (kept == 1) "copy stays" else "copies stay"} in other chats" else "Deleted \"${s.title}\" from Telegram"
                }
                else queue.jobs.value.firstOrNull()?.error?.let { "Could not delete: $it" } ?: "Could not delete the song"
            } catch (e: kotlin.coroutines.cancellation.CancellationException) {
                throw e
            } catch (e: Exception) {
                "Could not delete: ${e.message ?: e::class.simpleName}"
            }
            say(msg)
        }
    }

    /** Reads the indexed chats for newer posts (or goes on with a stopped read). Runs on the app's scope, so it carries on when the page is left. */
    fun refreshIndex(onError: (String) -> Unit = {}) {
        scope.launch(Dispatchers.IO) { runCatching { chatIndex.refresh() }.onFailure { onError(it.message ?: "Indexing failed") } }
    }

    /** Indexes [chat] (only what is new when it is indexed already). Also keeps going when the page is left. */
    fun indexChat(chat: io.max.paperplay.core.account.ChatInfo, onError: (String) -> Unit = {}) {
        scope.launch(Dispatchers.IO) { runCatching { chatIndex.indexChat(chat) }.onFailure { onError(it.message ?: "Indexing failed") } }
    }

    /** Copying songs that are only in the library to Telegram: null when idle. Goes on when the page is left. */
    class LibraryCopy(val paused: Boolean = false)
    val libraryCopy = MutableStateFlow<LibraryCopy?>(null)
    val libraryCopyStatus = MutableStateFlow<String?>(null)

    fun copyLibraryOnly() {
        if (!libraryCopy.compareAndSet(null, LibraryCopy())) return
        scope.launch(Dispatchers.IO) {
            try {
                val rate = (pref("copy_rate")?.toIntOrNull() ?: 20).coerceIn(5, 120)
                chatIndex.copyLibraryOnly(60_000L / rate, { libraryCopy.value?.paused == true }) { ok, bad, total, why ->
                    libraryCopyStatus.value = (if (libraryCopy.value?.paused == true) "Paused: " else "") + "$ok of $total copied" + if (bad > 0) ", $bad failed. ${why.orEmpty()}" else ""
                }
            } catch (e: kotlin.coroutines.cancellation.CancellationException) {
                throw e
            } catch (e: Exception) {
                libraryCopyStatus.value = "Could not copy: ${e.message ?: e::class.simpleName}"
            } finally {
                libraryCopy.value = null
            }
        }
    }

    fun pauseLibraryCopy() { libraryCopy.value?.let { libraryCopy.value = LibraryCopy(!it.paused) } }

    /** Removes library-only songs whose post was deleted from Telegram (checked with your account); the rest stay. */
    fun clearDeletedLibraryOnly(say: (String) -> Unit) {
        scope.launch(Dispatchers.IO) {
            say("Checking songs the bot can't reach")
            val (removed, kept, unchecked) = runCatching { chatIndex.clearDeletedLibraryOnly() }.getOrElse { say("Could not check: ${it.message}"); return@launch }
            say(buildString {
                append("Removed $removed deleted songs")
                if (kept > 0) append(", $kept still exist in Telegram and stay")
                if (unchecked > 0) append(", $unchecked could not be checked (log in your account and try again)")
            })
        }
    }

    /** Copies songs into the main chat so the bots can read them. Songs already there are skipped; a failed copy leaves the song as it was. */
    fun copySongsToChat(ids: Collection<String>, say: (String) -> Unit) {
        val list = ids.mapNotNull { byId[it] }
        if (list.isEmpty()) return
        scope.launch(Dispatchers.IO) {
            val rate = (repo.pref("copy_rate")?.toIntOrNull() ?: 20).coerceIn(5, 120)
            say("Copying ${list.size} songs to your main chat")
            var last = Triple(0, 0, null as String?)
            var total = 0
            try {
                chatIndex.copySongsToMain(list, 60_000L / rate, { false }) { ok, bad, all, why -> last = Triple(ok, bad, why); total = all }
                say(when {
                    total == 0 -> "Nothing to copy: these songs are already in your main chat and readable"
                    last.second == 0 -> "Copied ${last.first} to your main chat"
                    else -> "Copied ${last.first}, ${last.second} failed. ${last.third.orEmpty()}"
                })
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                say("Could not copy: ${e.message}")
            }
        }
    }

    /** Deletes several songs from Telegram (main chat only) and the library, one by one; progress shows on the Tasks page. */
    fun deleteSongs(ids: Collection<String>, say: (String) -> Unit) {
        val list = ids.mapNotNull { byId[it] }
        if (list.isEmpty()) return
        scope.launch(Dispatchers.IO) {
            val queue = services.deleteQueue
            val msg = try {
                val done = queue.deleteSongs(list)
                val failed = list.size - done
                val why = queue.jobs.value.firstOrNull { it.error != null }?.error
                when {
                    failed == 0 -> "Deleted $done ${if (done == 1) "song" else "songs"}"
                    done == 0 -> "Could not delete: ${why ?: "nothing was removed"}"
                    else -> "Deleted $done, $failed failed${why?.let { ": $it" }.orEmpty()}"
                }
            } catch (e: kotlin.coroutines.cancellation.CancellationException) {
                throw e
            } catch (e: Exception) {
                "Could not delete: ${e.message ?: e::class.simpleName}"
            }
            say(msg)
        }
    }

    /** Pins every song of a playlist, or unpins them all when they are already pinned. Returns the new state. */
    fun togglePinAll(ids: Collection<String>): Boolean {
        val all = ids.mapNotNull { byId[it] }
        val pin = all.any { !it.pinned }
        services.setPinned(all.map { it.unique_id }, pin)
        return pin
    }

    fun createPlaylist(name: String, thenAdd: Collection<String> = emptyList()) {
        scope.launch(Dispatchers.IO) {
            val id = repo.createPlaylist(name.trim().ifEmpty { "New playlist" })
            thenAdd.mapNotNull { byId[it] }.forEach { repo.addToPlaylist(id, it) }
        }
    }

    fun addToPlaylist(playlistId: String, songIds: Collection<String>) {
        val id = playlistId.toLongOrNull() ?: return
        scope.launch(Dispatchers.IO) { songIds.mapNotNull { byId[it] }.forEach { repo.addToPlaylist(id, it) } }
    }

    fun setPlaylistOrder(playlistId: String, songIds: List<String>) {
        val id = playlistId.toLongOrNull() ?: return
        val songs = songIds.mapNotNull { byId[it] }
        scope.launch(Dispatchers.IO) { repo.repo.setPlaylistOrder(id, songs) }
    }

    fun removeFromPlaylist(playlistId: String, songId: String) {
        val id = playlistId.toLongOrNull() ?: return
        val s = byId[songId] ?: return
        scope.launch(Dispatchers.IO) { repo.removeFromPlaylist(id, s) }
    }

    fun renamePlaylist(playlistId: String, name: String) {
        val id = playlistId.toLongOrNull() ?: return
        val n = name.trim().ifEmpty { return }
        scope.launch(Dispatchers.IO) { repo.renamePlaylist(id, n) }
    }

    fun deletePlaylist(playlistId: String) {
        val id = playlistId.toLongOrNull() ?: return
        scope.launch(Dispatchers.IO) { repo.deletePlaylist(id) }
    }

    // Connection
    /** Returns an error text, or null when the credentials were saved and the login started. */
    fun saveCredentials(apiId: String, apiHash: String, botToken: String): String? {
        val id = apiId.trim().toIntOrNull() ?: return "The API id is a number."
        if (apiHash.isBlank()) return "Enter the API hash."
        if (botToken.isBlank()) return "Enter the bot token."
        services.saveCredentials(id, apiHash.trim(), botToken.trim())
        hasCredentials.value = true
        services.connect()
        return null
    }

    /** True while the bot's credentials are stored; false after [logOutBot], which shows setup again. */
    val hasCredentials = kotlinx.coroutines.flow.MutableStateFlow(services.hasCredentials)

    fun logOutBot() {
        scope.launch { services.logOutBot(); hasCredentials.value = false }
    }

    /** Logs the account out and tells [done] how it went, so a logout is never silent. */
    fun logOutAccount(done: (String) -> Unit = {}) {
        scope.launch {
            if (!account.loggedIn.value) { done("Your account was not logged in"); return@launch }
            val failed = runCatching { services.logOutAccount() }.exceptionOrNull()
            val out = failed == null && kotlinx.coroutines.withTimeoutOrNull(5_000) { account.loggedIn.first { !it } } != null
            done(if (out) "Logged out of your account" else "Could not log out: ${failed?.message ?: "the account still shows as logged in"}")
        }
    }

    fun logOutAll() {
        scope.launch { services.logOutAll(); hasCredentials.value = false }
    }

    fun connect() = services.connect()

    /** Local network sync; null until it has been turned on once or "lan_on" was set at launch. */
    val lanSync: io.max.paperplay.core.sync.LanSync? get() = services.lanSync

    /** Turns local network sync on (creates it first if needed) or off. It saves "lan_on" itself. */
    fun setLanOn(on: Boolean) {
        scope.launch(Dispatchers.Default) {
            if (on) services.enableLanSync(!io.max.paperplay.ui.isPhone).start() else services.lanSync?.stop()
        }
    }

    init {
        // The core starts itself when "lan_on" is "1"; it only has to be built.
        if (repo.pref("lan_on") == "1") services.enableLanSync(!io.max.paperplay.ui.isPhone)
    }

    fun pref(key: String): String? = repo.pref(key)
    fun setPref(key: String, value: String) = repo.savePref(key, value)

    fun mainChatId(): Long? = parseMainChat(repo.pref(MAIN_CHAT_KEY))

    /**
     * Songs whose album was found online as a compilation ("Bravo Hits 95", "Top 100") get their album, cover and info cleared so the next
     * scan looks them up again; songs edited by hand, with a hand-picked cover or an album from the file's own tags stay as they are.
     * Returns how many were reset.
     */
    fun resetCompilationInfo(): Int {
        val list = repo.repo.db.allSongsNow()
            .filter { !it.user_edited && it.cover_at == 0L && it.metadata_source != "File tags" && io.max.paperplay.core.metadata.isCompilationAlbum(it.album) }
        repo.replaceSongs(
            list.map { it.copy(album = "", release_id = null, cover_url = null, cover_path = null, metadata_source = null, enrich_state = io.max.paperplay.core.library.EnrichState.PENDING) },
        )
        return list.size
    }

    /** Forgets which songs were deleted, so they are no longer removed from or kept out of the other devices. Returns how many entries went. */
    fun clearDeletionRecord(): Int {
        val n = runCatching { (kotlinx.serialization.json.Json.parseToJsonElement(repo.pref(io.max.paperplay.core.filing.GONE_KEY) ?: "{}") as kotlinx.serialization.json.JsonObject).size }.getOrDefault(0)
        repo.setPref(io.max.paperplay.core.filing.GONE_KEY, "{}")
        return n
    }

    /** A Telegram topic or starred channel shown as a playlist. [key] is stable across refreshes. */
    data class TelegramList(val key: String, val name: String, val songs: List<SongUi>)

    fun isChannelStarred(chatId: Long) = repo.pref("channel_star:$chatId") == "true"

    fun setChannelStarred(chatId: Long, on: Boolean) = repo.savePref("channel_star:$chatId", "$on")

    /**
     * Lists to show beside the playlists: the main chat's topics, only when Telegram gave it any (a chat without topics
     * adds nothing), then every starred channel. Empty when there is nothing to show.
     */
    fun telegramLists(): List<TelegramList> {
        val main = mainChatId() ?: return emptyList()
        val all = byId.values
        val out = ArrayList<TelegramList>()
        val topics = runCatching { repo.repo.db.miscQueries.topics().executeAsList() }.getOrDefault(emptyList())
        // A topic Telegram never named still has songs filed in it, so it is listed too.
        val named = io.max.paperplay.core.filing.topicChoices(topics, main, taste.value.topicNames)
        val seen = named.map { it.id }.toSet()
        val unnamed = if (named.isEmpty() && all.none { it.chat_id == main && it.topic_id != null && it.topic_id != io.max.paperplay.core.filing.GENERAL_TOPIC_ID }) emptyList()
        else all.filter { it.chat_id == main }.mapNotNull { it.topic_id }.filter { it != io.max.paperplay.core.filing.GENERAL_TOPIC_ID && it !in seen }.distinct().sorted()
            .map { io.max.paperplay.core.filing.TopicChoice(it, "Unnamed topic $it") }
        val general = if (named.isEmpty() && unnamed.isNotEmpty()) listOf(io.max.paperplay.core.filing.TopicChoice(io.max.paperplay.core.filing.GENERAL_TOPIC_ID, "General")) else emptyList()
        for (t in general + named + unnamed) {
            val songs = all.filter { it.chat_id == main && (it.topic_id ?: io.max.paperplay.core.filing.GENERAL_TOPIC_ID) == t.id }
            if (songs.isNotEmpty()) out += TelegramList("topic:$main:${t.id}", t.name, songs.sortedByDescending { it.date }.map { it.toUi() })
        }
        for (c in runCatching { repo.chatList() }.getOrDefault(emptyList())) {
            if (c.id == main || !isChannelStarred(c.id)) continue
            val songs = all.filter { it.chat_id == c.id }
            if (songs.isNotEmpty()) out += TelegramList("chat:${c.id}", c.title, songs.sortedByDescending { it.date }.map { it.toUi() })
        }
        return out
    }

    fun setMainChat(chatId: Long) {
        repo.setPref(MAIN_CHAT_KEY, """{"id":$chatId,"at":${nowMoment().epochMs}}""")
    }

    /** Adds a chat to read songs from. [id] is Telegram's chat id, for example -1001234567890. */
    fun addChat(id: String, title: String): String? {
        val chatId = id.trim().toLongOrNull() ?: return "The chat id is a number, like -1001234567890."
        services.addChat(chatId, title.trim().ifEmpty { chatId.toString() })
        return null
    }

    // Last in the class on purpose: the coroutine reads playbackMeta, playerStarted and the player, and one started before they are assigned reaches them as null (it crashed the app).
    init {
        // The desktop's mini player and tray menu go on while the main window is hidden.
        if (!io.max.paperplay.ui.isPhone) {
            DesktopMini.controls.value = this
            scope.launch { playbackMeta.collect { DesktopMini.state.value = it } }
        }
        scope.launch(Dispatchers.Default) {
            var first = true
            val activeFlow = combine(
                io.max.paperplay.ui.AppForegroundState.isVisibleFlow,
                io.max.paperplay.ui.AppForegroundState.isMiniVisibleFlow,
                playbackMeta.map { it.playing },
            ) { visible, miniVisible, playing ->
                (visible || miniVisible) && playing
            }
            while (isActive) {
                val level = io.max.paperplay.player.SystemVolume.get()
                if (level == null) { if (first) return@launch else { delay(2500); continue } }
                if (first) {
                    first = false
                    systemVolume = true
                    // The engine plays at full level; the system volume is the only one (except when USB exclusive is active).
                    val isUsb = usbExclusiveMode.value && (usbExclusiveStatus.value?.isConnected == true)
                    if (playerStarted.value && !isUsb) player.setVolume(1f)
                }
                if (kotlin.math.abs(level - volume.value) > 0.004f) {
                    volume.value = level
                    val isUsb = usbExclusiveMode.value && (usbExclusiveStatus.value?.isConnected == true)
                    if (playerStarted.value && isUsb) {
                        player.setVolume(level)
                    }
                }
                if ((!io.max.paperplay.ui.AppForegroundState.isVisible && !io.max.paperplay.ui.AppForegroundState.isMiniVisible) || !playbackMeta.value.playing) {
                    activeFlow.first { it }
                } else {
                    delay(2500)
                }
            }
        }
    }
}

private fun <T> groups(songs: List<Song>, key: (Song) -> String, make: (String, List<Song>) -> T): List<T> =
    songs.filter { key(it).isNotBlank() }.groupBy { key(it) }.entries
        .sortedBy { it.key.lowercase() }.map { make(it.key, it.value) }

/** One group per artist: a song credited to several artists is in each of their groups. */
/**
 * The library's songs as a list whose items are turned into UI objects the first time they are read, so a long list costs only
 * what is on screen (plus whatever a search or sort touches). Two lists are equal only if they are the same object, so comparing
 * one library with the next never reads every song.
 */
internal class LazySongs(private val rows: List<Song>, private val extra: List<SongUi>) : AbstractList<SongUi>(), RandomAccess {
    private val made = arrayOfNulls<SongUi>(rows.size)
    override val size get() = rows.size + extra.size
    override fun get(index: Int): SongUi {
        if (index >= rows.size) return extra[index - rows.size]
        return made[index] ?: rows[index].toUi().also { made[index] = it }
    }
    override fun equals(other: Any?) = this === other
    override fun hashCode() = System.identityHashCode(this)
}

private fun artistGroups(songs: List<Song>): List<GroupUi> {
    val byName = LinkedHashMap<String, Pair<String, MutableList<Song>>>()
    for (s in songs) {
        val names = io.max.paperplay.core.metadata.splitArtists(s.artist).ifEmpty { listOf(s.artist) }.filter { it.isNotBlank() }
        for (n in names) byName.getOrPut(n.lowercase()) { n to mutableListOf() }.second += s
    }
    return byName.values.sortedBy { it.first.lowercase() }.map { (name, list) -> GroupUi(name, name, "${list.size} songs", covers(list)) }
}

private fun covers(songs: List<Song>): List<String?> = songs.mapNotNull { it.cover_path }.distinct().take(4)

private fun albumSubtitle(list: List<Song>): String {
    val artists = list.map { it.artist }.distinct()
    return (if (artists.size == 1) artists[0] else "Various artists") + " · ${list.size} songs"
}

private val LOSSLESS = setOf("flac", "alac", "wav", "aiff", "aif", "ape", "wv")

/** Every other post of a file the library lists once, as its own row, so the Songs list shows each post of the chat. */
private fun CoreBackend.repeatPosts(byId: Map<String, Song>): List<SongUi> =
    services.library.repo.db.filingQueries.allPostCopies().executeAsList().mapNotNull { c ->
        byId[c.unique_id]?.toUi()?.copy(copyKey = "${c.chat_id}:${c.message_id}", addedAt = c.date)
    }

internal fun Song.toUi(): SongUi {
    val ext = (codec ?: file_name.substringAfterLast('.', "")).lowercase().trim()
    val lossless = ext in LOSSLESS
    val kbps = if (duration_sec > 0) size * 8 / duration_sec / 1000 else 0L
    val label = buildString {
        if (ext.isNotEmpty()) append(ext.uppercase())
        if (lossless && bit_depth != null && sample_rate != null) append(" $bit_depth/${sample_rate!! / 1000.0}".replace(".0", ""))
        else if (!lossless && kbps > 0) append(" ${kbps}k")
    }.trim().ifEmpty { null }
    return SongUi(
        id = unique_id, title = title, artist = artist, album = album, genre = genre, coverUri = cover_path,
        durationSec = duration_sec.toInt(), sizeBytes = size, year = year?.toInt(), plays = plays.toInt(),
        languages = io.max.paperplay.core.metadata.languagesOfText(title, artist, album),
        addedAt = date, qualityLabel = label, qualityRank = if (lossless) 100_000 + (bit_depth ?: 16).toInt() * 1000 else kbps.toInt(),
        lossless = lossless, favorite = favorite, pinned = pinned, offline = size > 0 && cached_bytes >= size,
        botCantReach = remote_id == io.max.paperplay.core.app.ACCOUNT_REMOTE,
    )
}

internal fun buildHomeUi(plan: io.max.paperplay.core.recs.HomeMix, mixList: List<DailyMix>, fresh: (Song) -> Song): HomeUi {
    fun coverOf(lead: Song, groupSongs: List<Song>): String? {
        val f = fresh(lead)
        return f.cover_path
            ?: groupSongs.firstNotNullOfOrNull { it.cover_path }
    }
    return HomeUi(
        tiles = plan.tiles.map { t ->
            val ts = t.songs.map(fresh)
            CollectionUi(t.title, t.title, "${ts.size} songs", coverOf(t.cover, ts), ts.map(Song::toUi))
        },
        shelves = plan.shelves.map { s ->
            val kind = when (s.kind) { ShelfKind.SONGS -> ShelfKindUi.Songs; ShelfKind.ALBUMS -> ShelfKindUi.Albums; ShelfKind.ARTISTS -> ShelfKindUi.Artists }
            val ss = s.songs.map(fresh)
            ShelfUi(s.title, kind, ss.map(Song::toUi), s.groups.map { g ->
                val gs = g.songs.map(fresh)
                val sub = if (kind == ShelfKindUi.Albums) fresh(g.cover).artist else "${gs.size} songs"
                CollectionUi(g.name, g.name, sub, coverOf(g.cover, gs), gs.map(Song::toUi))
            })
        },
        mixes = mixList.map { m ->
            val ms = m.songs.map(fresh)
            CollectionUi(m.id, m.title, ms.take(3).joinToString(", ") { it.artist }, null, ms.map(Song::toUi), covers(ms))
        },
    )
}

/**
 * The page saved at the last launch, with its first covers decoded so it is drawn complete. Needs only the database, so the app starts
 * it as soon as the services exist, beside the building of the backend. Null when none is saved.
 */
internal suspend fun loadSavedHome(services: AppServices): HomeUi? {
    val repo = services.library
    val raw = repo.pref(HomeSnapshot.PREF) ?: return null
    val rows = repo.songsByUniqueIds(HomeSnapshot.idsIn(raw)).associateBy { it.unique_id }
    val (plan, mixes) = HomeSnapshot.decode(raw) { rows[it] } ?: return null
    // Only what is on screen at first is waited for; the rest is decoded as it is scrolled to.
    val firstShelf = plan.shelves.firstOrNull { it.kind == ShelfKind.SONGS }?.songs.orEmpty().take(6)
    val mixLead = mixes.flatMap { it.songs.take(4) }
    val lead = (plan.tiles.flatMap { listOf(it.cover) + it.songs.take(1) } + firstShelf + mixLead).distinctBy { it.unique_id }
    services.covers.prioritize(lead)
    kotlinx.coroutines.coroutineScope {
        launch { SharedCovers.loader.preloadAndWait(plan.tiles.mapNotNull { it.cover.cover_path }, 160, 350) }
        launch { SharedCovers.loader.preloadAndWait((firstShelf + mixLead).mapNotNull { it.cover_path }, 512, 350) }
    }
    return buildHomeUi(plan, mixes) { it }
}

private const val MAX_SUGGEST_EVENTS = 4_000
