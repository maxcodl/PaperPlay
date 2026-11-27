package io.max.paperplay.player

import com.sun.jna.Pointer
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.abs

/**
 * libmpv engine for the desktop: any format FFmpeg reads, a real equalizer and bass ([MpvFilters]), correction profiles
 * (an exact response through `firequalizer`) and optional exclusive WASAPI output for bit-perfect playback.
 *
 * mpv runs the queue as a two-entry playlist: the song that plays and, once it has started, the next one appended, so
 * the change from one song to the next has no gap. All decisions run on one thread ([cmd]); the event thread only reads
 * mpv's events and posts work. [options] are extra mpv options set before start (tests pass `ao=null`).
 */
internal class MpvPlayerEngine(private val lib: MpvLib, options: Map<String, String> = emptyMap()) : PlayerEngine {
    private val _state = MutableStateFlow(PlayerState.Idle)
    private val _positionMs = MutableStateFlow(0L)
    private val _durationMs = MutableStateFlow(0L)
    private val _bufferedMs = MutableStateFlow(0L)
    private val _currentIndex = MutableStateFlow(-1)
    private val _info = MutableStateFlow<OutputInfo?>(null)
    private val _bitPerfectStatus = MutableStateFlow<BitPerfectStatus>(BitPerfectStatus.Off)
    override val state: StateFlow<PlayerState> = _state
    override val positionMs: StateFlow<Long> = _positionMs
    override val durationMs: StateFlow<Long> = _durationMs
    override val bufferedMs: StateFlow<Long> = _bufferedMs
    override val currentIndex: StateFlow<Int> = _currentIndex
    override val outputInfo: StateFlow<OutputInfo?> = _info
    override val supportsBitPerfect: Boolean = true
    override val bitPerfectStatus: StateFlow<BitPerfectStatus> = _bitPerfectStatus

    private val ctx: Pointer = lib.mpv_create() ?: error("mpv_create failed")
    private val io = Executors.newSingleThreadExecutor { r -> Thread(r, "mpv-cmd").apply { isDaemon = true } }
    private val http = lazy { StreamHttpServer() }
    @Volatile private var closed = false

    private var queue = emptyList<QueueItem>()
    /** Queue indices in the order mpv holds them: the song that plays, then the one appended after it. */
    private val playlist = ArrayList<Int>()
    private var loaded = false
    @Volatile private var paused = false
    private val tapFeeder = DesktopAudioTapFeeder("desktop-mpv")

    // After a seek the data for the new position may not be there yet (a song still downloading), and the stream can end early.
    // That is not the end of the song: it is opened again at the place that was asked for, twice at most.
    @Volatile private var resumeAtMs = 0L
    private var prematureRetries = 0
    @Volatile private var seekTarget = -1L
    @Volatile private var seekAt = 0L
    @Volatile private var startedAt = 0L
    private var lastPos = -1L

    @Volatile private var eqGains: List<Float>? = null
    @Volatile private var parametricEq: ParametricEqProfile? = null
    @Volatile private var parametricEnabled: Boolean = false
    @Volatile private var bass = 0f
    @Volatile private var normalize = false
    @Volatile private var width = 1f
    @Volatile private var crossfeed = false
    @Volatile private var volume = 1f
    @Volatile private var speed = 1f
    @Volatile private var exclusive = false
    @Volatile private var profile: List<Pair<Double, Double>>? = null
    @Volatile private var plan: MpvFilters.Plan? = null
    @Volatile private var graph: String? = null
    /** Windows' default output while mpv follows it (audio-device=auto). */
    @Volatile private var windowsOutput: WindowsOutputDevice? = null
    /** The output picked in the app, or null to follow Windows' default. */
    @Volatile private var chosenOutput: WindowsOutputDevice? = null
    /** What mpv answered when the filter graph was last set (negative is an error), and the graph; for tests and the log. */
    @Volatile internal var filterResult = 0
    @Volatile internal var lastGraph: String? = null

    private val events: Thread

    init {
        // No window, no config files or scripts; the player is audio only.
        val base = mapOf(
            "vo" to "null", "video" to "no", "audio-display" to "no", "idle" to "yes", "keep-open" to "no",
            "gapless-audio" to "yes", "audio-pitch-correction" to "yes", "replaygain" to "no", "volume-max" to "100",
            "audio-client-name" to "PaperPlay", "ytdl" to "no", "terminal" to "no", "input-default-bindings" to "no", "load-scripts" to "no",
            "cache-secs" to "30", "network-timeout" to "30",
        )
        (base + options).forEach { (k, v) -> val rc = lib.mpv_set_option_string(ctx, k, v); if (rc < 0) PlayLog.log("mpv", "option $k=$v: ${lib.mpv_error_string(rc)}") }
        val rc = lib.mpv_initialize(ctx)
        if (rc < 0) {
            lib.mpv_terminate_destroy(ctx)
            error("mpv_initialize failed: ${lib.mpv_error_string(rc)}")
        }
        lib.mpv_request_log_messages(ctx, "warn")
        lib.mpv_observe_property(ctx, 1, "time-pos", MpvC.FORMAT_DOUBLE)
        lib.mpv_observe_property(ctx, 2, "duration", MpvC.FORMAT_DOUBLE)
        lib.mpv_observe_property(ctx, 3, "pause", MpvC.FORMAT_FLAG)
        lib.mpv_observe_property(ctx, 4, "demuxer-cache-time", MpvC.FORMAT_DOUBLE)
        events = Thread({ eventLoop() }, "mpv-events").apply { isDaemon = true; start() }
        // Windows' default output, looked at every few seconds: the output info and the per-device settings follow a switch made in Windows.
        Thread({
            while (!closed) {
                val now = WindowsOutputDevice.current()
                if (now?.id != windowsOutput?.id) { windowsOutput = now; cmd { publishInfo() } }
                try { Thread.sleep(3_000) } catch (_: InterruptedException) { return@Thread }
            }
        }, "mpv-output-watch").apply { isDaemon = true; start() }
    }

    // ---- mpv access

    private fun command(vararg args: String): Boolean {
        val rc = lib.mpv_command(ctx, arrayOf<String?>(*args, null))
        if (rc < 0) PlayLog.log("mpv", "command ${args.firstOrNull()}: ${lib.mpv_error_string(rc)}")
        return rc >= 0
    }

    private fun setProp(name: String, value: String) {
        val rc = lib.mpv_set_property_string(ctx, name, value)
        if (rc < 0) PlayLog.log("mpv", "property $name=$value: ${lib.mpv_error_string(rc)}")
    }

    private fun str(name: String): String? {
        val p = lib.mpv_get_property_string(ctx, name) ?: return null
        return try { p.getString(0, "UTF-8") } finally { lib.mpv_free(p) }
    }

    private fun int(name: String): Int? = str(name)?.toIntOrNull()
    private fun audioDelayMs(): Long = ((str("audio-delay")?.toDoubleOrNull() ?: 0.0) * 1000.0).toLong()

    private fun cmd(block: () -> Unit) {
        if (closed || io.isShutdown) return
        try {
            io.execute { runCatching(block).onFailure { PlayLog.log("mpv", "error: $it") } }
        } catch (_: java.util.concurrent.RejectedExecutionException) {
        }
    }

    // ---- events

    private fun eventLoop() {
        while (!closed) {
            val ev = lib.mpv_wait_event(ctx, -1.0)
            when (ev.getInt(0)) {
                MpvC.EVENT_NONE -> {}
                MpvC.EVENT_SHUTDOWN -> return
                MpvC.EVENT_LOG_MESSAGE -> ev.getPointer(16)?.let { onLog(it) }
                MpvC.EVENT_PROPERTY_CHANGE -> ev.getPointer(16)?.let { onProperty(it) }
                MpvC.EVENT_START_FILE -> cmd { onStartFile() }
                MpvC.EVENT_FILE_LOADED -> cmd { onFileLoaded() }
                MpvC.EVENT_AUDIO_RECONFIG -> cmd { onAudioReconfig() }
                MpvC.EVENT_PLAYBACK_RESTART -> cmd {
                    // Fast seeking can leave the exclusive buffer corrupt without any under-run being logged (static until pause and play,
                    // which reopens it). Reopen it here, while still muted, once the burst has settled.
                    // The stream was paused across the seek, so the device is not left corrupt and needs no reopening (that took a second of noise).
                    // The seek is done while still paused and muted: open the device afresh (a clean buffer), then resume.
                    if (seekPaused) reloadOutput("seek")
                    endSeekMute(); publishInfo()
                }
                MpvC.EVENT_END_FILE -> { val reason = ev.getPointer(16)?.getInt(0) ?: MpvC.END_EOF; cmd { onEndFile(reason) } }
            }
        }
    }

    private val underruns = UnderrunWatch()
    private var lastFormat: String? = null

    /** Opens the sound output again. The `ao-reload` command if this mpv has it, otherwise the exclusive switch off and on. */
    private fun reloadOutput(reason: String) {
        if (!command("ao-reload")) { setProp("audio-exclusive", "no"); setProp("audio-exclusive", "yes") }
        PlayLog.log("mpv", "output reloaded ($reason)")
    }

    /** The output was (re)configured. Records what it is, and in exclusive mode opens it afresh once when the song's format changed. */
    private fun onAudioReconfig() {
        publishInfo()
        val fmt = "${str("audio-params/samplerate")}/${str("audio-params/format")}/${str("audio-params/hr-channels")}"
        PlayLog.log(
            "mpv",
            "output: file $fmt, device ${str("audio-out-params/samplerate")}/${str("audio-out-params/format")}, ao=${str("current-ao")}, " +
                "exclusive=${str("audio-exclusive")}, speed=${str("speed")}",
        )
        val previous = lastFormat
        lastFormat = fmt
        // A different rate or sample format means the exclusive stream was opened for another song: start it clean, once.
        if (exclusive && previous != null && previous != fmt) reloadOutput("format changed from $previous to $fmt")
    }

    private var logWindowStart = 0L
    private var logInWindow = 0
    private var lastLog = ""

    /** mpv_event_log_message: prefix at 0, level at 8, text at 16. Decoder and output warnings go to the activity log, at most a few a second. */
    private fun onLog(p: Pointer) {
        val prefix = p.getPointer(0)?.getString(0, "UTF-8") ?: return
        val text = p.getPointer(16)?.getString(0, "UTF-8")?.trim() ?: return
        // The output has fallen behind for good (heard as static and slow sound): open it again, the way switching bit-perfect off and on does.
        // Under-runs while a seek has the stream paused are expected and do not count.
        if (exclusive && prefix.startsWith("ao") && text.startsWith("Under-run") && !seekPaused && underruns.hit()) {
            cmd { reloadOutput("under-runs"); endSeekMute() }
        }
        val line = "$prefix: $text"
        if (line == lastLog) return
        lastLog = line
        val now = System.currentTimeMillis()
        if (now - logWindowStart > 1_000) { logWindowStart = now; logInWindow = 0 }
        if (++logInWindow <= 4) PlayLog.log("mpv", line.take(200))
    }

    /** mpv_event_property: name at 0, format at 8, data at 16. */
    private fun onProperty(p: Pointer) {
        val name = p.getPointer(0)?.getString(0, "UTF-8") ?: return
        val format = p.getInt(8)
        val data = p.getPointer(16) ?: return
        when (name) {
            "time-pos" -> if (format == MpvC.FORMAT_DOUBLE) {
                val ms = (data.getDouble(0) * 1000).toLong().coerceAtLeast(0)
                if (abs(ms - lastPos) >= 100 || paused) { lastPos = ms; _positionMs.value = ms }
                if (!paused && !seekPaused && loaded) tapFeeder.onPosition(ms, speed)
            }
            "duration" -> if (format == MpvC.FORMAT_DOUBLE) _durationMs.value = (data.getDouble(0) * 1000).toLong().coerceAtLeast(0)
            "demuxer-cache-time" -> if (format == MpvC.FORMAT_DOUBLE) _bufferedMs.value = (data.getDouble(0) * 1000).toLong().coerceAtLeast(0)
            "pause" -> if (format == MpvC.FORMAT_FLAG) {
                paused = data.getInt(0) != 0
                if (loaded && !seekPaused && (_state.value == PlayerState.Playing || _state.value == PlayerState.Paused)) {
                    _state.value = if (paused) PlayerState.Paused else PlayerState.Playing
                    if (paused) tapFeeder.onPause()
                    else tapFeeder.onPlaying(true, _positionMs.value, speed, 0L)
                }
            }
        }
    }

    private fun onStartFile() {
        endSeekMute()
        val pos = int("playlist-playing-pos") ?: 0
        // mpv moved on to the appended song by itself: drop what already played from its list.
        if (pos > 0 && pos < playlist.size) repeat(pos) { playlist.removeAt(0); command("playlist-remove", "0") }
        val first = playlist.firstOrNull() ?: return
        if (_currentIndex.value != first) {
            prematureRetries = 0; seekTarget = -1; resumeAtMs = 0
            _positionMs.value = 0; _durationMs.value = 0; lastPos = -1
            startedAt = System.currentTimeMillis()
        } else if (resumeAtMs > 0L) {
            _positionMs.value = resumeAtMs
        }
        _currentIndex.value = first
        loaded = false
        _state.value = PlayerState.Loading
        tapFeeder.onTrack(str("path") ?: if (first in queue.indices) mrlFor(first) else null)
    }

    private fun onFileLoaded() {
        loaded = true
        _state.value = if (paused) PlayerState.Paused else PlayerState.Playing
        val resume = resumeAtMs
        if (resume > 0) {
            resumeAtMs = 0
            _positionMs.value = resume
            command("seek", "%.3f".format(java.util.Locale.ROOT, resume / 1000.0), "absolute+exact")
        }
        publishInfo()
        prepareNext()
        tapFeeder.onPlaying(!paused, _positionMs.value, speed, audioDelayMs())
        PlayLog.log("mpv", "playing after ${System.currentTimeMillis() - startedAt}ms ${_info.value?.let { "codec=${it.codec} rate=${it.sampleRateHz}Hz" } ?: ""}")
    }

    private fun prepareNext() {
        val next = (playlist.firstOrNull() ?: return) + 1
        if (next !in queue.indices || playlist.size > 1) return
        command("loadfile", mrlFor(next), "append")
        playlist.add(next)
    }

    private fun onEndFile(reason: Int) {
        when (reason) {
            MpvC.END_STOP, MpvC.END_QUIT, MpvC.END_REDIRECT -> return
            MpvC.END_ERROR -> { _state.value = PlayerState.Error; tapFeeder.onStop(); return }
        }
        val now = System.currentTimeMillis()
        val dur = _durationMs.value
        val at = if (seekTarget >= 0 && now - seekAt < 8_000) seekTarget else _positionMs.value
        val cur = playlist.firstOrNull() ?: _currentIndex.value
        if (dur > 10_000 && at < dur - 5_000 && prematureRetries < 2 && cur in queue.indices) {
            prematureRetries++
            resumeAtMs = at
            start(cur, retry = true)
            return
        }
        // With a next song appended mpv carries on by itself. Without one, the end of the queue (or a song that did not get appended).
        if (playlist.size > 1) return
        if (cur + 1 in queue.indices) start(cur + 1) else { loaded = false; _positionMs.value = _durationMs.value; _state.value = PlayerState.Ended; tapFeeder.onStop() }
    }

    // ---- playback

    private fun mrlFor(index: Int): String {
        val item = queue[index]
        return item.source?.let { http.value.register(item.uri, it) } ?: item.uri
    }

    private fun start(index: Int, retry: Boolean = false, startPositionMs: Long = 0L, startPaused: Boolean = false) {
        val safePos = startPositionMs.coerceAtLeast(0L)
        playlist.clear(); playlist.add(index)
        if (!retry) { prematureRetries = 0; resumeAtMs = safePos; seekTarget = if (safePos > 0L) safePos else -1L }
        _currentIndex.value = index
        startedAt = System.currentTimeMillis()
        _state.value = if (startPaused) PlayerState.Paused else PlayerState.Loading
        loaded = false
        if (!retry) { _positionMs.value = safePos; _durationMs.value = 0; lastPos = if (safePos > 0L) safePos else -1L }
        if (exclusive && !startPaused) setProp("audio-exclusive", "yes")
        paused = startPaused
        setProp("pause", if (startPaused) "yes" else "no")
        command("loadfile", mrlFor(index), "replace")
    }

    override fun setQueue(items: List<QueueItem>, startIndex: Int) = setQueue(items, startIndex, 0L)

    override fun setQueue(items: List<QueueItem>, startIndex: Int, startPositionMs: Long) {
        val safePos = startPositionMs.coerceAtLeast(0L)
        if (items.isNotEmpty()) {
            _currentIndex.value = startIndex.coerceIn(items.indices)
            _positionMs.value = safePos
        }
        cmd {
            queue = items
            if (items.isEmpty()) {
                command("stop")
                playlist.clear()
                _currentIndex.value = -1
                _positionMs.value = 0L
                _state.value = PlayerState.Idle
                tapFeeder.onStop()
            } else start(startIndex.coerceIn(items.indices), startPositionMs = safePos)
        }
    }

    override fun restoreQueue(items: List<QueueItem>, startIndex: Int, positionMs: Long) {
        val safePos = positionMs.coerceAtLeast(0L)
        if (items.isNotEmpty()) {
            _currentIndex.value = startIndex.coerceIn(items.indices)
            _positionMs.value = safePos
            _state.value = PlayerState.Paused
        }
        cmd {
            queue = items
            if (items.isEmpty()) {
                command("stop")
                playlist.clear()
                _currentIndex.value = -1
                _positionMs.value = 0L
                _state.value = PlayerState.Idle
            } else start(startIndex.coerceIn(items.indices), startPositionMs = safePos, startPaused = true)
        }
    }

    // Exclusive output holds the sound device for this app alone, so it is given back while paused and taken again on play.
    override fun play() = cmd {
        if (exclusive) setProp("audio-exclusive", "yes")
        if (_state.value == PlayerState.Ended) start(_currentIndex.value) else {
            setProp("pause", "no")
            tapFeeder.onPlaying(true, _positionMs.value, speed, audioDelayMs())
        }
    }
    override fun pause() = cmd {
        // A pause during a seek's own pause sets nothing new in mpv, so the state is set here.
        if (seekPaused) { seekPaused = false; if (loaded) _state.value = PlayerState.Paused }
        setProp("pause", "yes")
        tapFeeder.onPause()
        if (exclusive) { setProp("audio-exclusive", "no"); publishInfo() }
    }
    override fun next() = cmd { val i = _currentIndex.value; if (i + 1 in queue.indices) start(i + 1) }
    override fun previous() = cmd {
        val i = _currentIndex.value
        if (i > 0 && _positionMs.value <= RESTART_THRESHOLD_MS) start(i - 1)
        else if (i >= 0) command("seek", "0", "absolute+exact")
    }
    @Volatile private var pendingSeek = Long.MIN_VALUE
    @Volatile private var seekMuted = false

    override fun seek(positionMs: Long) {
        pendingSeek = positionMs
        cmd {
            // A burst of seeks (dragging, tapping lyrics) is cut to the last one: each seek in exclusive output restarts the device
            // buffer, and restarting it again and again is heard as static.
            if (pendingSeek != positionMs) return@cmd
            if (loaded && exclusive) Thread.sleep(SEEK_SETTLE_MS)
            if (pendingSeek != positionMs) return@cmd
            seekTarget = positionMs; seekAt = System.currentTimeMillis()
            // Nothing loaded yet (a session being restored): remember the place, the song is opened there once it has loaded.
            if (!loaded) { resumeAtMs = positionMs.coerceAtLeast(0); return@cmd }
            // Exclusive output has no mixer to hide the jump: mute across it, and unmute when playback has restarted.
            // The stream is also paused, so the device is not left starved while the seek decodes (that was the static).
            if (exclusive && !seekMuted) {
                setProp("mute", "yes"); seekMuted = true
                if (!paused) { seekPaused = true; setProp("pause", "yes") }
            }
            if (exclusive) {
                // Safety: never stay paused or muted if the restart event does not come.
                val at = seekAt
                Thread { Thread.sleep(SEEK_RESUME_LIMIT_MS); cmd { if (seekAt == at) endSeekMute() } }.apply { isDaemon = true; name = "seek-resume" }.start()
            }
            command("seek", "%.3f".format(java.util.Locale.ROOT, positionMs.coerceAtLeast(0) / 1000.0), "absolute+exact")
            tapFeeder.onSeek(positionMs.coerceAtLeast(0L))
        }
    }

    /** Paused only for the seek, so the player state shows no pause and the stream resumes when the seek is done. */
    @Volatile private var seekPaused = false

    private fun endSeekMute() {
        if (seekPaused) { seekPaused = false; setProp("pause", "no") }
        if (seekMuted) { seekMuted = false; setProp("mute", "no") }
    }

    // ---- sound settings

    override fun setVolume(volume: Float) {
        this.volume = volume.coerceIn(0f, 1f)
        cmd { setProp("volume", "%.1f".format(java.util.Locale.ROOT, this.volume * 100)); publishInfo() }
    }

    override fun setSpeed(speed: Float) {
        this.speed = speed.coerceIn(0.5f, 2f)
        tapFeeder.onSpeed(this.speed)
        cmd { setProp("speed", "%.3f".format(java.util.Locale.ROOT, this.speed)); publishInfo() }
    }

    override fun setEqualizer(gainsDb: List<Float>?) { eqGains = gainsDb; cmd { applyFilters() } }
    override fun setParametricEq(profile: ParametricEqProfile?, enabled: Boolean) {
        parametricEq = profile
        parametricEnabled = enabled
        cmd { applyFilters() }
    }
    override fun setBass(db: Float) { bass = db; cmd { applyFilters() } }
    override fun setNormalize(on: Boolean) { normalize = on; cmd { applyFilters() } }
    override fun setStereoWidth(width: Float) { this.width = width.coerceIn(0.5f, 1.6f); cmd { applyFilters() } }
    /** Only the crossfeed bit (4) means anything here; dynamic bass and the de-esser are phone engine options. */
    override fun setEngineOptions(bits: Int) { crossfeed = bits and 4 != 0; cmd { applyFilters() } }
    override fun setCorrectionProfile(text: String?) { profile = text?.let { CorrectionProfile.parse(it) }; cmd { applyFilters() } }

    override fun setOutputDevice(id: String?) {
        cmd {
            chosenOutput = id?.let { want -> WindowsOutputDevice.all().firstOrNull { it.id == want } }
            // A device that is gone (unpaired, unplugged) falls back to Windows' default rather than to silence.
            setProp("audio-device", chosenOutput?.let { "wasapi/${it.id}" } ?: "auto")
            PlayLog.log("mpv", "output device: ${chosenOutput?.name ?: "Windows default"}")
            publishInfo()
        }
    }

    override fun setBitPerfect(on: Boolean) {
        setExclusiveOutput(on)
    }

    override fun setExclusiveOutput(on: Boolean) {
        exclusive = on
        _bitPerfectStatus.value = if (on) BitPerfectStatus.Standby(reason = "Exclusive output requested") else BitPerfectStatus.Off
        // Bit-perfect needs the device opened at each song's own rate. "yes" would keep the first song's rate and convert every later song to it.
        cmd {
            setProp("gapless-audio", if (on) "weak" else "yes")
            setProp("audio-exclusive", if (on) "yes" else "no")
            applyFilters()
        }
    }

    private fun buildParametricAf(profile: ParametricEqProfile): String? {
        if (!profile.hasActiveShaping()) return null
        val parts = ArrayList<String>()
        val effPreamp = NativeEqMath.evalResponse(48000, profile, floatArrayOf(1000f)).effectivePreampDb
        if (abs(effPreamp) >= 0.05f) {
            parts.add("volume=${"%.3f".format(java.util.Locale.ROOT, effPreamp)}dB")
        }
        for (raw in profile.bands.take(ParametricEqProfile.MAX_PEQ_BANDS)) {
            val b = raw.clamped()
            if (!b.enabled) continue
            if (b.type.usesGain && abs(b.gainDb) < 0.05f) continue
            val f = "%.2f".format(java.util.Locale.ROOT, b.freqHz)
            val q = "%.3f".format(java.util.Locale.ROOT, b.q)
            val g = "%.3f".format(java.util.Locale.ROOT, b.gainDb)
            val filter = when (b.type) {
                PeqFilterType.PK -> "equalizer=f=$f:t=q:w=$q:g=$g"
                PeqFilterType.LSC -> "lowshelf=f=$f:t=q:w=$q:g=$g"
                PeqFilterType.HSC -> "highshelf=f=$f:t=q:w=$q:g=$g"
                PeqFilterType.LP -> "lowpass=f=$f:t=q:w=$q:p=2"
                PeqFilterType.HP -> "highpass=f=$f:t=q:w=$q:p=2"
                PeqFilterType.BP -> "bandpass=f=$f:t=q:w=$q"
            }
            parts.add(filter)
        }
        if (parts.isEmpty()) return null
        if (profile.limiterEnabled) parts.add("alimiter=limit=0.944:attack=1:release=50:level=0")
        return parts.joinToString(",")
    }

    private fun applyFilters() {
        val g = if (exclusive) {
            plan = null
            null
        } else {
            val peq = parametricEq
            val peqActive = parametricEnabled && peq != null && peq.hasActiveShaping()
            if (peqActive && peq != null) {
                plan = null
                buildParametricAf(peq)
            } else {
                val p = MpvFilters.plan(eqGains, bass)
                plan = p
                MpvFilters.graph(p, normalize, profile, width, crossfeed)
            }
        }
        graph = g
        val rc = lib.mpv_set_property_string(ctx, "af", MpvFilters.afValue(g))
        filterResult = rc; lastGraph = g
        if (rc < 0) PlayLog.log("mpv", "audio filters refused (${lib.mpv_error_string(rc)}): $g")
        publishInfo()
    }

    // ---- output info

    private fun deviceName(): String {
        val id = str("audio-device")
        if (id == null || id == "auto") return windowsOutput?.name ?: "System default output"
        chosenOutput?.takeIf { id == "wasapi/${it.id}" }?.let { return it.name }
        val json = str("audio-device-list") ?: return id
        val m = Regex("\"name\":\"((?:[^\"\\\\]|\\\\.)*)\",\"description\":\"((?:[^\"\\\\]|\\\\.)*)\"").findAll(json)
            .firstOrNull { it.groupValues[1].replace("\\\\", "\\") == id }
        return m?.groupValues?.get(2)?.takeIf { it.isNotBlank() } ?: if (id == "auto") "System default output" else id
    }

    private fun publishInfo() {
        val srcFmt = str("audio-params/format"); val srcRate = int("audio-params/samplerate"); val srcCh = int("audio-params/channel-count")
        val outFmt = str("audio-out-params/format"); val outRate = int("audio-out-params/samplerate"); val outCh = int("audio-out-params/channel-count")
        val ao = str("current-ao")
        // What mpv really has set, not what this class last asked for.
        val exclusiveNow = str("audio-exclusive") == "yes"
        val effects = buildList {
            val peq = parametricEq
            if (!exclusiveNow && parametricEnabled && peq != null && peq.hasActiveShaping()) {
                add("Parametric EQ (${peq.bands.count { it.enabled }} bands)")
            }
            val p = plan
            if (p != null && p.bands.any { abs(it) >= 0.05 }) add("Equalizer")
            if (p != null && p.bassDb >= 0.05) add("Bass +${"%.1f".format(java.util.Locale.ROOT, p.bassDb)} dB")
            if (profile != null) add("Correction profile")
            if (normalize) add("Normalise")
            if (crossfeed) add("Crossfeed")
            if (abs(width - 1f) >= 0.02f) add("Stereo width ${(width * 100).toInt()}%")
            if (speed != 1f) add("Speed ${speed}x")
            if (volume < 0.995f) add("Volume ${(volume * 100).toInt()}%")
        }
        val devName = deviceName()
        val evaluated = MpvBitPerfectBridge.evaluate(
            codec = str("audio-codec-name")?.takeIf { it.isNotBlank() }?.uppercase(),
            bitrateKbps = str("audio-bitrate")?.toDoubleOrNull()?.takeIf { it > 0 }?.let { (it / 1000).toInt() },
            srcFmt = srcFmt,
            srcRate = srcRate,
            srcCh = srcCh,
            outFmt = outFmt,
            outRate = outRate,
            outCh = outCh,
            ao = ao,
            exclusiveNow = exclusiveNow,
            exclusiveRequested = exclusive,
            deviceName = devName,
            effects = effects,
            curvePeakDb = plan?.peakDb,
            lowTrimDb = plan?.lowTrimDb,
            highTrimDb = plan?.highTrimDb,
        )
        val rawDevId = str("audio-device")?.takeIf { it.isNotBlank() } ?: "auto"
        val win = if (rawDevId == "auto") windowsOutput else chosenOutput?.takeIf { rawDevId == "wasapi/${it.id}" }
        _info.value = evaluated.outputInfo.copy(deviceKey = "desktop:${win?.id ?: rawDevId}", bluetooth = win?.bluetooth == true)
        _bitPerfectStatus.value = evaluated.status
    }

    override fun release() {
        if (closed) return
        closed = true
        tapFeeder.release()
        lib.mpv_wakeup(ctx)
        events.join(2000)
        io.shutdown()
        io.awaitTermination(2, TimeUnit.SECONDS)
        lib.mpv_terminate_destroy(ctx)
        if (http.isInitialized()) http.value.close()
    }

    private companion object {
        const val RESTART_THRESHOLD_MS = 3000L
        /** Seeks closer together than this are one seek, to the last place. */
        const val SEEK_SETTLE_MS = 80L
        /** A seek never keeps the stream paused longer than this, even if the restart event does not come. */
        const val SEEK_RESUME_LIMIT_MS = 1_500L
    }
}

/** Pure JVM helper computing desktop [OutputInfo] + [BitPerfectStatus] via [BitPerfectEvaluator]. */
internal object MpvBitPerfectBridge {
    data class Result(val outputInfo: OutputInfo, val status: BitPerfectStatus)

    fun parsePcmFormat(fmt: String?, rateHz: Int?, ch: Int?): PcmFormat? {
        if (fmt.isNullOrBlank() || rateHz == null || rateHz <= 0 || ch == null || ch <= 0) return null
        val norm = fmt.lowercase()
        return when {
            norm == "u8" || norm == "u8p" -> PcmFormat(rateHz, 8, 8, 8, SampleEncoding.PCM_INT, ch)
            norm == "s16" || norm == "s16p" -> PcmFormat(rateHz, 16, 16, 16, SampleEncoding.PCM_INT, ch)
            norm == "s24" || norm == "s24p" -> PcmFormat(rateHz, 24, 24, 24, SampleEncoding.PCM_INT, ch)
            norm == "s32" || norm == "s32p" -> PcmFormat(rateHz, 32, 32, 32, SampleEncoding.PCM_INT, ch)
            norm == "float" || norm == "floatp" || norm == "flt" || norm == "fltp" ->
                PcmFormat(rateHz, 32, 32, 32, SampleEncoding.PCM_FLOAT, ch)
            norm == "double" || norm == "dblp" || norm == "dbl" ->
                PcmFormat(rateHz, 64, 64, 64, SampleEncoding.PCM_FLOAT, ch)
            else -> null
        }
    }

    fun evaluate(
        codec: String?,
        bitrateKbps: Int?,
        srcFmt: String?,
        srcRate: Int?,
        srcCh: Int?,
        outFmt: String?,
        outRate: Int?,
        outCh: Int?,
        ao: String?,
        exclusiveNow: Boolean,
        exclusiveRequested: Boolean,
        deviceName: String,
        effects: List<String>,
        curvePeakDb: Double? = null,
        lowTrimDb: Double? = null,
        highTrimDb: Double? = null,
    ): Result {
        val srcPcm = parsePcmFormat(srcFmt, srcRate, srcCh)
        val outPcm = parsePcmFormat(outFmt, outRate, outCh)
        val isWasapi = ao?.startsWith("wasapi") == true
        val wasapiExclusive = exclusiveNow && isWasapi
        val transport = TransportInfo(
            kind = if (wasapiExclusive) TransportKind.WASAPI_EXCLUSIVE else TransportKind.NONE,
            verified = wasapiExclusive,
            deviceName = deviceName,
            protocolVersion = ao,
            confirmedRateHz = outRate?.takeIf { it > 0 },
            confirmedBitDepth = outPcm?.wireBitDepth,
            confirmedContainerBits = outPcm?.containerBits,
            unverifiedReason = when {
                !exclusiveNow -> "Windows mixes sound at the format set in Sound settings. Turn on exclusive output for bit-perfect playback."
                !isWasapi && ao != null -> "Output driver ($ao) is not WASAPI exclusive."
                else -> null
            },
        )
        val verdict = BitPerfectEvaluator.evaluate(
            transport = transport,
            source = srcPcm,
            output = outPcm,
            effects = effects,
            requestedOn = exclusiveRequested,
        )
        val details = buildList {
            if (srcFmt != null) add("Decoder output" to "$srcFmt, ${srcRate ?: "?"} Hz, ${srcCh ?: "?"} ch")
            if (outFmt != null) add("Device format" to "$outFmt, ${outRate ?: "?"} Hz, ${outCh ?: "?"} ch" + if (ao != null) " (${if (wasapiExclusive) "WASAPI exclusive" else ao})" else "")
            if (curvePeakDb != null && lowTrimDb != null && highTrimDb != null) {
                add("Curve peak" to "%+.1f dB".format(java.util.Locale.ROOT, curvePeakDb))
                add("Level trim" to "bass %+.1f dB, rest %+.1f dB".format(java.util.Locale.ROOT, lowTrimDb, highTrimDb))
            }
        }
        val info = OutputInfo(
            codec = codec,
            sampleRateHz = srcRate?.takeIf { it > 0 },
            channels = srcCh?.takeIf { it > 0 },
            bitrateKbps = bitrateKbps,
            bitDepth = srcPcm?.sourceBitDepth,
            device = deviceName,
            outputRateHz = outRate?.takeIf { it > 0 },
            effects = effects,
            bitPerfect = verdict.bitPerfect,
            note = verdict.note,
            details = details,
            transport = transport,
        )
        val status = when {
            !exclusiveRequested -> BitPerfectStatus.Off
            verdict.bitPerfect && outRate != null && outPcm != null -> BitPerfectStatus.Active(
                transportLabel = "WASAPI exclusive",
                sampleRateHz = outRate,
                bitDepth = outPcm.wireBitDepth,
                deviceName = deviceName,
            )
            effects.isNotEmpty() -> BitPerfectStatus.Bypassed(verdict.note)
            else -> BitPerfectStatus.Fallback(verdict.note)
        }
        return Result(info, status)
    }
}
