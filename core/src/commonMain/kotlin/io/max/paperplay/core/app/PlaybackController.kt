package io.max.paperplay.core.app

import io.max.paperplay.core.library.Song
import io.max.paperplay.core.telegram.TdError
import io.max.paperplay.player.PlayerEngine
import io.max.paperplay.player.PlayerState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

enum class Repeat { OFF, ALL, ONE }

private const val SESSION_QUEUE = "session_queue"
private const val SESSION_INDEX = "session_index"
private const val SESSION_POS = "session_pos"

/** The largest step between two position updates that is playing; a bigger forward jump is a seek, not listening. */
private const val MAX_LISTEN_STEP_MS = 5_000L

/** A song goes on Recently played once this much of it was heard, from any screen or source. */
const val RECENT_AFTER_MS = 30_000L

/** A second rewind press within this long goes to the song before; one press only plays the song again from the start. */
const val PREVIOUS_AGAIN_MS = 2_500L

private const val FADE_MS = 200L
private const val FADE_STEPS = 10

/** What the player UI shows. [index] is into [queue], which is in play order (shuffled when [shuffle]). */
data class NowPlaying(
    val song: Song? = null,
    val positionMs: Long = 0,
    val durationMs: Long = 0,
    val isPlaying: Boolean = false,
    val index: Int = -1,
    val queue: List<Song> = emptyList(),
    val shuffle: Boolean = false,
    val repeat: Repeat = Repeat.OFF,
    /** Text of the last failure to start a track; null otherwise. */
    val error: String? = null,
    val bufferedMs: Long = 0,
)

/**
 * Plays lists of songs on a [PlayerEngine]. Commands that change the queue or track are
 * last-tap-wins: a newer one cancels an older one that has not reached the engine yet.
 */
class PlaybackController(
    private val engine: PlayerEngine,
    private val resolver: TrackResolver,
    private val repo: LibraryRepository,
    private val scope: CoroutineScope,
    private val clock: () -> Long = { kotlin.time.Clock.System.now().toEpochMilliseconds() },
) {
    private class Meta(val queue: List<Song>, val shuffle: Boolean, val repeat: Repeat, val error: String?)

    /** Counts queues that start at the index that was playing already. */
    private val queueChanges = MutableStateFlow(0L)
    private val meta = MutableStateFlow(Meta(emptyList(), false, Repeat.OFF, null))
    private var original: List<Song> = emptyList()
    private var job: Job? = null
    private var neighborJob: Job? = null
    private val gate = Mutex()

    // Listen counting for the song that is currently playing.
    private var listening: Song? = null
    private var listenedMs = 0L
    private var markedFor: String? = null
    private var prefetchedFor: String? = null

    /** Everything in [NowPlaying] except the ticking position and buffer; does not change on position ticks. */
    val nowPlayingStatic: StateFlow<NowPlaying> = combine(
        engine.state, engine.durationMs, engine.currentIndex, meta,
    ) { state, dur, idx, m ->
        val song = m.queue.getOrNull(idx)
        NowPlaying(
            song, 0, if (dur > 0) dur else (song?.duration_sec ?: 0) * 1000, state == PlayerState.Playing,
            idx, m.queue, m.shuffle, m.repeat, m.error, 0,
        )
    }.stateIn(scope, SharingStarted.Eagerly, NowPlaying())

    /** Position and buffered ms, for views that tick. */
    val positionMs: StateFlow<Long> get() = engine.positionMs
    val bufferedMs: StateFlow<Long> get() = engine.bufferedMs

    val nowPlaying: StateFlow<NowPlaying> = combine(
        nowPlayingStatic, engine.positionMs, engine.bufferedMs,
    ) { base, pos, buf -> base.copy(positionMs = pos, bufferedMs = buf) }
        .stateIn(scope, SharingStarted.Eagerly, NowPlaying())

    init {
        // The queue is saved when it changes; position and index are saved every few seconds while playing.
        scope.launch {
            var saved: List<Song>? = null
            meta.collect { m ->
                if (m.queue.isNotEmpty() && m.queue !== saved) {
                    saved = m.queue
                    runCatching { repo.setPref(SESSION_QUEUE, m.queue.joinToString(",") { it.unique_id }) }
                }
            }
        }
        scope.launch {
            while (true) {
                delay(5_000)
                if (engine.state.value == PlayerState.Playing) saveSession()
            }
        }
        scope.launch { engine.state.collect { if (it == PlayerState.Paused || it == PlayerState.Ended) saveSession() } }
        scope.launch {
            // The index alone does not tell: a new queue that starts at the place the old one was at changes the song but not the index, and
            // what was heard next was counted for the old song.
            combine(engine.currentIndex, queueChanges) { i, _ -> i }.collect { idx ->
                val song = meta.value.queue.getOrNull(idx)
                io.max.paperplay.player.PlayLog.log(
                    "controller",
                    "now playing #$idx of ${meta.value.queue.size}: \"${song?.title}\" by ${song?.artist} size=${song?.size} duration=${song?.duration_sec}s id=${song?.unique_id?.take(12)} " +
                        "chat=${song?.chat_id} remote=${song?.remote_id?.take(10)} pinned=${song?.pinned}",
                )
                if (song?.unique_id != listening?.unique_id) {
                    // The song that was playing goes on the history, so rewinding returns to it even in a shuffled queue.
                    val before = listening
                    if (before != null && song != null) {
                        if (goingBack) goingBack = false else synchronized(history) { history.addLast(before); while (history.size > 200) history.removeFirst() }
                    }
                    finishListening()
                    listening = song
                    markedFor = null
                    saveSession()
                }
                prefetchedFor = null
                val q = meta.value.queue
                val next = q.getOrNull(idx + 1)
                val prev = q.getOrNull(idx - 1)
                neighborJob?.cancel()
                neighborJob = launch {
                    // Engines apply play() asynchronously, so a skip from pause may not show as Playing yet; the intent counts.
                    val intent = playIntent
                    playIntent = false
                    val active = intent || engine.state.value == PlayerState.Playing || engine.state.value == PlayerState.Loading
                    runCatching { resolver.window(song, next, playing = active, previous = prev) }
                    // The song and the next two come down in full, so seeking in them never waits for Telegram.
                    if (song != null) launch { runCatching { resolver.fullyDownload(listOf(song) + q.drop(idx + 1).take(2)) } }
                    if (active) {
                        if (next != null) launch { runCatching { resolver.prefetch(next) } }
                        if (prev != null) {
                            delay(1_500)
                            runCatching { resolver.prefetch(prev) }
                        }
                    }
                }
                if (song != null) launch { learnAudioDetails(song) }
            }
        }
        scope.launch {
            var lastPos = 0L
            engine.positionMs.collect { pos ->
                val step = pos - lastPos
                if (step in 1..MAX_LISTEN_STEP_MS) listenedMs += step
                val l = listening
                if (l != null && listenedMs >= RECENT_AFTER_MS && markedFor != l.unique_id && l.remote_id != NETPLAY_REMOTE && !privateSession) {
                    markedFor = l.unique_id
                    runCatching { repo.markPlayedNow(l) }
                }
                lastPos = pos
                if (engine.state.value != PlayerState.Playing) return@collect
                val idx = engine.currentIndex.value
                val cur = meta.value.queue.getOrNull(idx) ?: return@collect
                val next = meta.value.queue.getOrNull(idx + 1) ?: return@collect
                if (prefetchedFor == cur.unique_id) return@collect
                val dur = engine.durationMs.value.takeIf { it > 0 } ?: (cur.duration_sec * 1000L)
                if (dur > 0 && pos > 0 && dur - pos <= resolver.windowSeconds * 1000L) {
                    prefetchedFor = cur.unique_id
                    launch { runCatching { resolver.prefetch(next) } }
                }
            }
        }
        scope.launch {
            engine.state.collect { state ->
                val cs = meta.value.queue.getOrNull(engine.currentIndex.value)
                io.max.paperplay.player.PlayLog.log(
                    "controller",
                    "state $state position=${engine.positionMs.value}ms engineDuration=${engine.durationMs.value}ms songDuration=${(cs?.duration_sec ?: 0) * 1000}ms song=\"${cs?.title}\" repeat=${meta.value.repeat}" +
                        if (state == PlayerState.Ended) "  <- the player says the song ended; compare position with the durations" else "",
                )
                if (state == PlayerState.Paused || state == PlayerState.Idle || state == PlayerState.Ended || state == PlayerState.Error) {
                    launch { runCatching { resolver.pauseAll() } }
                }
                if (state == PlayerState.Error && cs != null) launch { if (runCatching { isDeleted?.invoke(cs) }.getOrNull() == true) dropDeleted(cs) }
                if (state != PlayerState.Ended) return@collect
                // The last song of the queue has no song change after it, so its listen is closed here.
                finishListening()
                when (meta.value.repeat) {
                    Repeat.ONE -> engine.play()
                    Repeat.ALL -> restart()
                    Repeat.OFF -> launch { continueWithSuggestion() }
                }
            }
        }
    }

    /**
     * Reads a song's real codec, bit depth and sample rate from the start of its file, once playback has fetched
     * that. Costs no download of its own. Tries for about half a minute, then gives up until the song plays again.
     */
    private suspend fun learnAudioDetails(song: Song) {
        if (repo.songByUniqueId(song.unique_id)?.sample_rate != null) return
        repeat(6) {
            delay(4_000)
            if (engine.currentIndex.value < 0 || meta.value.queue.getOrNull(engine.currentIndex.value)?.unique_id != song.unique_id) return
            val head = runCatching { resolver.headOf(song) }.getOrNull() ?: return@repeat
            val h = parseAudioHeader(head)
            // TODO: use the non-notifying (notify=false) variant once LibraryRepository has it.
            if (h != null) repo.setAudioDetails(song.unique_id, h)
            return
        }
    }

    /**
     * Picks the song that should follow a queue that ran out, given the queue so far; null for none. Set by the owner,
     * from the recommender. Left null, a finished queue just ends.
     */
    @kotlin.concurrent.Volatile
    var suggestNext: (suspend (List<Song>) -> Song?)? = null

    private suspend fun continueWithSuggestion() {
        val q = meta.value.queue
        if (q.isEmpty()) return
        val pick = runCatching { suggestNext?.invoke(q) }.getOrNull() ?: return
        // The user may have started something else while the suggestion was worked out.
        if (engine.state.value != PlayerState.Ended || meta.value.queue !== q) return
        command {
            original = original + pick
            apply(q + pick, q.size, 0)
            engine.play()
        }
    }

    /** Called when a song stops, with how long it was heard. Set by the owner, for scrobbling. */
    @kotlin.concurrent.Volatile
    var onListened: ((Song, Long) -> Unit)? = null

    /** A private session: what is played is not recorded anywhere (Recently played, listening history, the recommender). */
    @kotlin.concurrent.Volatile
    var privateSession = false

    private fun finishListening() {
        val song = listening ?: return
        if (song.remote_id == NETPLAY_REMOTE || privateSession) { listenedMs = 0; return }
        val ms = listenedMs
        listenedMs = 0
        if (ms <= 0) return
        val full = song.duration_sec * 1000
        val finished = if (full > 0 && ms >= full * 9 / 10) true else if (ms >= 5_000) false else null
        runCatching { repo.recordListen(song, ms, finished) }
        runCatching { onListened?.invoke(song, ms) }
    }

    /** Replaces the queue with [songs] and plays [startIndex]. */
    fun setQueue(songs: List<Song>, startIndex: Int = 0) = command {
        if (songs.isEmpty()) return@command
        pausedByHand = false
        val start = startIndex.coerceIn(songs.indices)
        original = songs
        val order = if (meta.value.shuffle) {
            listOf(songs[start]) + songs.toMutableList().also { it.removeAt(start) }.shuffled()
        } else songs
        apply(order, if (meta.value.shuffle) 0 else start, 0)
    }

    // The volume the listener set; a fade moves the player's volume between 0 and this.
    @kotlin.concurrent.Volatile private var baseVolume = 1f
    private var fadeJob: Job? = null

    private fun fade(to: Float, from: Float, then: () -> Unit = {}) {
        fadeJob?.cancel()
        fadeJob = scope.launch {
            for (i in 1..FADE_STEPS) {
                engine.setVolume(from + (to - from) * i / FADE_STEPS)
                delay(FADE_MS / FADE_STEPS)
            }
            then()
        }
    }

    /** Resuming a paused song fades in over a fifth of a second; a song starting fresh does not. */
    /**
     * Plays the song at [index] of the queue as it is now: the order stays exactly as shown (also when shuffle is on, where setQueue
     * would shuffle the rest again) and the list the queue was made from is not replaced by the shuffled one.
     */
    fun playIndex(index: Int) = command {
        val m = meta.value
        if (index !in m.queue.indices) return@command
        playIntent = true
        pausedByHand = false
        apply(m.queue, index, 0)
        engine.play()
    }

    fun play() {
        pausedByHand = false
        if (!engine.bypassSoftwareFade && engine.state.value == PlayerState.Paused && baseVolume > 0f) {
            fadeJob?.cancel()
            engine.setVolume(0f)
            engine.play()
            fade(baseVolume, 0f)
        } else {
            fadeJob?.cancel()
            if (!engine.bypassSoftwareFade) {
                engine.setVolume(baseVolume)
            }
            engine.play()
        }
    }

    /** Pausing a playing song fades out over a fifth of a second, then pauses. */
    fun pause() {
        pausedByHand = true
        saveSession()
        if (!engine.bypassSoftwareFade && engine.state.value == PlayerState.Playing && baseVolume > 0f) {
            fade(0f, baseVolume) { engine.pause(); engine.setVolume(baseVolume) }
        } else {
            fadeJob?.cancel()
            engine.pause()
            if (!engine.bypassSoftwareFade) {
                engine.setVolume(baseVolume)
            }
        }
        scope.launch { runCatching { resolver.pauseAll() } }
    }
    fun seek(positionMs: Long) {
        engine.seek(positionMs)
        saveSession(positionOverrideMs = positionMs)
    }
    fun setVolume(volume: Float) { baseVolume = volume; if (fadeJob?.isActive != true) engine.setVolume(volume) }
    val outputInfo get() = engine.outputInfo
    val supportsBitPerfect: Boolean get() = engine.supportsBitPerfect
    val bitPerfectStatus get() = engine.bitPerfectStatus
    val dacController get() = engine.dacController
    fun setBitPerfect(on: Boolean) = engine.setBitPerfect(on)
    fun setEqualizer(gainsDb: List<Float>?) = engine.setEqualizer(gainsDb)
    fun setParametricEq(profile: io.max.paperplay.player.ParametricEqProfile?, enabled: Boolean) = engine.setParametricEq(profile, enabled)
    fun setAllowEqInUsbExclusive(allow: Boolean) = engine.setAllowEqInUsbExclusive(allow)
    fun setBass(db: Float) = engine.setBass(db)
    fun setExactLevel(on: Boolean) = engine.setExactLevel(on)
    fun setDryCompare(on: Boolean) = engine.setDryCompare(on)
    fun setStereoWidth(width: Float) = engine.setStereoWidth(width)
    fun setEarphoneCorrection(text: String?) = engine.setEarphoneCorrection(text)
    fun setEngineOptions(bits: Int) = engine.setEngineOptions(bits)
    fun setExclusiveOutput(on: Boolean) = engine.setExclusiveOutput(on)
    fun setOutputDevice(id: String?) = engine.setOutputDevice(id)
    fun setCorrectionProfile(text: String?) = engine.setCorrectionProfile(text)
    fun setSpeed(speed: Float) = engine.setSpeed(speed)
    fun setNormalize(on: Boolean) = engine.setNormalize(on)

    /** Asked when a song could not be played: true when its post is deleted in Telegram, and then it leaves the queue. Set by the owner. */
    @kotlin.concurrent.Volatile
    var isDeleted: (suspend (Song) -> Boolean)? = null

    /** The listener paused; a song that then turns out to be deleted must not start the next one. */
    @kotlin.concurrent.Volatile private var pausedByHand = false

    /** Takes [song], which cannot be played any more, out of the queue and plays the one after it. */
    private fun dropDeleted(song: Song) {
        val idx = engine.currentIndex.value
        // The user may have moved on while Telegram was asked.
        if (meta.value.queue.getOrNull(idx)?.unique_id != song.unique_id || engine.state.value != PlayerState.Error) return
        command {
            val order = meta.value.queue.toMutableList().also { it.removeAt(idx) }
            original = original.filter { it.unique_id != song.unique_id }
            if (order.isEmpty()) return@command
            apply(order, idx.coerceAtMost(order.lastIndex), 0)
            // When the last song of the queue failed nothing comes after it: the one before is shown but not started.
            if (idx <= order.lastIndex && !pausedByHand) engine.play() else engine.pause()
        }
    }

    /** Takes the song at [index] out of the queue. The last song cannot be removed. Playing on keeps the position. */
    fun removeAt(index: Int) = command {
        val m = meta.value
        val idx = engine.currentIndex.value
        if (index !in m.queue.indices || m.queue.size < 2) return@command
        val wasPlaying = engine.state.value == PlayerState.Playing
        val gone = m.queue[index]
        val order = m.queue.toMutableList().also { it.removeAt(index) }
        original = original.toMutableList().also { o -> o.indexOfFirst { it.unique_id == gone.unique_id }.takeIf { it >= 0 }?.let(o::removeAt) }
        val removedCurrent = index == idx
        val newIdx = when {
            removedCurrent -> idx.coerceAtMost(order.lastIndex)
            index < idx -> idx - 1
            else -> idx
        }
        apply(order, newIdx, if (removedCurrent) 0 else engine.positionMs.value)
        if (!wasPlaying) engine.pause()
    }

    /** Moves the song at [from] to [to] in the queue, without restarting what is playing from the start. */
    fun moveInQueue(from: Int, to: Int) = command {
        val m = meta.value
        val idx = engine.currentIndex.value
        if (from !in m.queue.indices || to !in m.queue.indices || from == to) return@command
        val wasPlaying = engine.state.value == PlayerState.Playing
        val order = m.queue.toMutableList().also { it.add(to, it.removeAt(from)) }
        if (!m.shuffle) original = order
        val newIdx = when {
            idx == from -> to
            from < idx && to >= idx -> idx - 1
            from > idx && to <= idx -> idx + 1
            else -> idx
        }
        apply(order, newIdx, engine.positionMs.value)
        if (!wasPlaying) engine.pause()
    }

    /** Puts back the queue, song and position from the last time, paused. Does nothing when something already plays. */
    fun restoreSession() = command {
        if (meta.value.queue.isNotEmpty()) return@command
        val ids = repo.pref(SESSION_QUEUE)?.split(',')?.filter { it.isNotEmpty() }.orEmpty()
        val songs = ids.mapNotNull { repo.songByUniqueId(it) }
        if (songs.isEmpty()) return@command
        val idx = (repo.pref(SESSION_INDEX)?.toIntOrNull() ?: 0).coerceIn(songs.indices)
        val song = songs[idx]
        val rawPos = repo.pref(SESSION_POS)?.toLongOrNull() ?: 0L
        val pos = clampSessionPosition(rawPos, song.duration_sec * 1000L)
        original = songs
        gate.withLock {
            resolver.retain(songs)
            meta.value = Meta(songs, false, Repeat.OFF, null)
            engine.restoreQueue(songs.map(resolver::resolve), idx, pos)
        }
        scope.launch { runCatching { resolver.warm(song) } }
    }

    /** Persists the current queue index and clamped playback position immediately (e.g. on pause, track switch, or app backgrounding). */
    fun saveSession(positionOverrideMs: Long? = null) {
        val q = meta.value.queue
        if (q.isEmpty()) return
        val idx = engine.currentIndex.value.coerceIn(q.indices)
        val song = q.getOrNull(idx)
        val durMs = engine.durationMs.value.takeIf { it > 0L } ?: ((song?.duration_sec ?: 0L) * 1000L)
        val rawPos = positionOverrideMs ?: engine.positionMs.value
        val clampedPos = clampSessionPosition(rawPos, durMs)
        runCatching {
            repo.setPref(SESSION_INDEX, idx.toString())
            repo.setPref(SESSION_POS, clampedPos.toString())
        }
    }

    private fun clampSessionPosition(posMs: Long, durationMs: Long): Long {
        val nonNeg = posMs.coerceAtLeast(0L)
        if (durationMs <= 2_000L) return nonNeg
        return if (nonNeg >= durationMs - 2_000L) 0L else nonNeg
    }

    @kotlin.concurrent.Volatile private var playIntent = false

    fun next() = command {
        playIntent = true
        pausedByHand = false
        val m = meta.value
        if (m.repeat == Repeat.ALL && engine.currentIndex.value == m.queue.lastIndex) apply(m.queue, 0, 0)
        else engine.next()
        // Skipping from a paused song starts the next one.
        engine.play()
    }

    @kotlin.concurrent.Volatile private var lastPreviousAt = 0L

    // The songs played before this one, oldest first: rewinding goes back along it, not along the (possibly shuffled) queue.
    private val history = ArrayDeque<Song>()
    @kotlin.concurrent.Volatile private var goingBack = false

    /** The queue index of the song played last, taken off the history; songs no longer in the queue are skipped. Null when none is left. */
    private fun takeFromHistory(): Int? {
        val q = meta.value.queue
        val cur = q.getOrNull(engine.currentIndex.value)?.unique_id
        synchronized(history) {
            while (history.isNotEmpty()) {
                val s = history.removeLast()
                if (s.unique_id == cur) continue
                val i = q.indexOfFirst { it.unique_id == s.unique_id }
                if (i >= 0) return i
            }
        }
        return null
    }

    /**
     * Rewind. One press always plays this song again from the start. A second press within [PREVIOUS_AGAIN_MS] goes to the song before it;
     * with no song before it (the first one of the list) every press just plays the song again from the start.
     */
    fun previous() = command {
        playIntent = true
        pausedByHand = false
        val now = clock()
        val again = lastPreviousAt != 0L && now - lastPreviousAt in 0..PREVIOUS_AGAIN_MS
        lastPreviousAt = now
        val back = if (again) takeFromHistory() else null
        if (back != null) {
            lastPreviousAt = 0L
            goingBack = true
            apply(meta.value.queue, back, 0)
        } else if (again && engine.currentIndex.value > 0) {
            lastPreviousAt = 0L
            goingBack = true
            engine.seek(0)
            engine.previous()
        } else {
            engine.seek(0)
        }
        engine.play()
    }

    /** Reorders the rest of the queue around the song now playing, without restarting it. */
    fun setShuffle(on: Boolean) = command {
        val m = meta.value
        if (m.shuffle == on) return@command
        val idx = engine.currentIndex.value
        val song = m.queue.getOrNull(idx)
        if (song == null) {
            meta.update { Meta(it.queue, on, it.repeat, it.error) }
            return@command
        }
        val order = if (on) {
            val rest = original.toMutableList()
            val at = rest.indexOfFirst { it.unique_id == song.unique_id }
            if (at >= 0) rest.removeAt(at)
            listOf(song) + rest.shuffled()
        } else original
        apply(order, order.indexOfFirst { it.unique_id == song.unique_id }, engine.positionMs.value, shuffle = on)
    }

    /** Puts [song] right after the one playing, or starts it when nothing is. Keeps the position and pause state. */
    fun playNext(song: Song) = command {
        val m = meta.value
        val idx = engine.currentIndex.value
        val cur = m.queue.getOrNull(idx)
        if (cur == null) {
            original = listOf(song)
            apply(listOf(song), 0, 0)
            return@command
        }
        val wasPlaying = engine.state.value == PlayerState.Playing
        val order = m.queue.toMutableList().also { it.add(idx + 1, song) }
        original = original.toMutableList().also {
            val at = it.indexOfFirst { s -> s.unique_id == cur.unique_id }
            it.add(if (at >= 0) at + 1 else it.size, song)
        }
        apply(order, idx, engine.positionMs.value)
        if (!wasPlaying) engine.pause()
    }

    fun setRepeat(repeat: Repeat) = meta.update { Meta(it.queue, it.shuffle, repeat, it.error) }

    private fun restart() = command { apply(meta.value.queue, 0, 0) }

    private fun command(block: suspend () -> Unit) {
        job?.cancel()
        job = scope.launch { block() }
    }

    private suspend fun apply(order: List<Song>, index: Int, seekMs: Long, shuffle: Boolean = meta.value.shuffle) {
        val song = order[index]
        coroutineScope {
            // The file lookup runs while the queue is handed to the engine; its error text is surfaced afterwards.
            val warm = async { try { resolver.warm(song); null } catch (e: TdError) { e.message } }
            gate.withLock {
                // A newer command arrived: it wins.
                currentCoroutineContext().ensureActive()
                resolver.retain(order)
                meta.value = Meta(order, shuffle, meta.value.repeat, null)
                engine.setQueue(order.map(resolver::resolve), index, seekMs.coerceAtLeast(0L))
                // Any other index comes through the engine once it has taken the queue; until then the old one means nothing in the new queue.
                if (engine.currentIndex.value == index) queueChanges.update { it + 1 }
            }
            scope.launch { runCatching { resolver.fullyDownload(order.drop(index).take(3)) } }
            warm.await()?.let { err ->
                // The look-up can fail early (the chat is still loading) and succeed when the player asks again. Show the
                // error only if the song does not start; a banner over a song that plays is wrong.
                val played = kotlinx.coroutines.withTimeoutOrNull(8_000) { engine.state.first { it == PlayerState.Playing } } != null
                if (!played) meta.update { Meta(it.queue, it.shuffle, it.repeat, err) }
            }
        }
    }

    /** Stops playback and releases the player. */
    suspend fun release() {
        saveSession()
        finishListening()
        engine.release()
        resolver.retain(emptyList())
    }
}
