package io.max.paperplay.player

import io.max.paperplay.player.usb.UsbDacController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Defers creation of an underlying [PlayerEngine] until active playback, seek, or navigation is requested.
 * Restoring a session or adjusting settings before playback does not initialize the real engine.
 */
class LazyPlayerEngine(
    override val supportsBitPerfect: Boolean = false,
    override val dacController: UsbDacController? = null,
    private val onPendingBitPerfect: ((Boolean) -> Unit)? = null,
    private val factory: () -> PlayerEngine,
) : PlayerEngine {
    @kotlin.concurrent.Volatile
    private var real: PlayerEngine? = null

    private val scope = CoroutineScope(Dispatchers.Default + Job())

    private val _state = MutableStateFlow(PlayerState.Idle)
    private val _positionMs = MutableStateFlow(0L)
    private val _durationMs = MutableStateFlow(0L)
    private val _bufferedMs = MutableStateFlow(0L)
    private val _currentIndex = MutableStateFlow(-1)
    private val _outputInfo = MutableStateFlow<OutputInfo?>(null)
    private val _bitPerfectStatus = MutableStateFlow<BitPerfectStatus>(
        if (supportsBitPerfect) BitPerfectStatus.Off else BitPerfectStatus.Unsupported("Bit-perfect mode is not supported on this engine")
    )

    override val state: StateFlow<PlayerState> get() = _state
    override val positionMs: StateFlow<Long> get() = _positionMs
    override val durationMs: StateFlow<Long> get() = _durationMs
    override val bufferedMs: StateFlow<Long> get() = _bufferedMs
    override val currentIndex: StateFlow<Int> get() = _currentIndex
    override val outputInfo: StateFlow<OutputInfo?> get() = _outputInfo
    override val bitPerfectStatus: StateFlow<BitPerfectStatus> get() = _bitPerfectStatus

    val isCreated: Boolean get() = real != null

    private var pendingQueue: List<QueueItem>? = null
    private var pendingIndex: Int = 0
    private var pendingSeekMs: Long = 0L
    private var pendingVolume: Float? = null
    private var pendingEq: List<Float>? = null
    private var pendingParametricEq: Pair<ParametricEqProfile?, Boolean>? = null
    private var pendingAllowEqInUsbExclusive: Boolean? = null
    private var pendingBass: Float? = null
    private var pendingExact: Boolean? = null
    private var pendingDry: Boolean? = null
    private var pendingWidth: Float? = null
    private var pendingEarphone: String? = null
    private var earphoneSet = false
    private var pendingOptions: Int? = null
    private var pendingBitPerfect: Boolean? = null
    private var pendingExclusive: Boolean? = null
    private var outputSet = false
    private var pendingOutput: String? = null
    private var pendingProfile: String? = null
    private var profileSet = false
    private var pendingSpeed: Float? = null
    private var pendingNormalize: Boolean? = null

    override fun restoreQueue(items: List<QueueItem>, startIndex: Int, positionMs: Long) {
        val safePos = positionMs.coerceAtLeast(0L)
        val r = real
        if (r != null) {
            r.restoreQueue(items, startIndex, safePos)
            return
        }
        pendingQueue = items
        pendingIndex = startIndex
        pendingSeekMs = safePos
        _currentIndex.value = startIndex
        _positionMs.value = safePos
        _state.value = PlayerState.Paused
    }

    private fun ensureReal(): PlayerEngine {
        real?.let { return it }
        return synchronized(this) {
            real?.let { return it }
            val engine = factory()
            pendingVolume?.let { engine.setVolume(it) }
            pendingEq?.let { engine.setEqualizer(it) }
            pendingAllowEqInUsbExclusive?.let { engine.setAllowEqInUsbExclusive(it) }
            pendingParametricEq?.let { (p, on) -> engine.setParametricEq(p, on) }
            pendingBass?.let { engine.setBass(it) }
            pendingExact?.let { engine.setExactLevel(it) }
            pendingDry?.let { engine.setDryCompare(it) }
            pendingWidth?.let { engine.setStereoWidth(it) }
            if (earphoneSet) engine.setEarphoneCorrection(pendingEarphone)
            pendingOptions?.let { engine.setEngineOptions(it) }
            pendingBitPerfect?.let { engine.setBitPerfect(it) }
            pendingExclusive?.let { engine.setExclusiveOutput(it) }
            if (outputSet) engine.setOutputDevice(pendingOutput)
            if (profileSet) engine.setCorrectionProfile(pendingProfile)
            pendingSpeed?.let { engine.setSpeed(it) }
            pendingNormalize?.let { engine.setNormalize(it) }

            val q = pendingQueue
            val idx = pendingIndex
            val seek = pendingSeekMs.coerceAtLeast(0L)
            pendingQueue = null
            pendingSeekMs = 0L

            if (q != null && q.isNotEmpty()) {
                engine.setQueue(q, idx, seek)
            }

            scope.launch { engine.state.collect { _state.value = it } }
            scope.launch {
                engine.positionMs.collect { pos ->
                    if (seek > 0L && pos == 0L && _positionMs.value == seek &&
                        (engine.state.value == PlayerState.Idle || engine.state.value == PlayerState.Loading)
                    ) {
                        return@collect
                    }
                    _positionMs.value = pos
                }
            }
            scope.launch { engine.durationMs.collect { _durationMs.value = it } }
            scope.launch { engine.bufferedMs.collect { _bufferedMs.value = it } }
            scope.launch { engine.currentIndex.collect { _currentIndex.value = it } }
            scope.launch { engine.outputInfo.collect { _outputInfo.value = it } }
            scope.launch { engine.bitPerfectStatus.collect { _bitPerfectStatus.value = it } }

            real = engine
            engine
        }
    }

    override fun setQueue(items: List<QueueItem>, startIndex: Int) = setQueue(items, startIndex, 0L)

    override fun setQueue(items: List<QueueItem>, startIndex: Int, startPositionMs: Long) {
        val safePos = startPositionMs.coerceAtLeast(0L)
        val r = real
        if (r == null) {
            if (items.isEmpty()) {
                pendingQueue = null
                pendingSeekMs = 0L
                _currentIndex.value = -1
                _positionMs.value = 0L
                _state.value = PlayerState.Idle
                return
            }
            pendingQueue = null
            pendingSeekMs = 0L
            ensureReal().setQueue(items, startIndex, safePos)
        } else {
            r.setQueue(items, startIndex, safePos)
        }
    }

    override fun play() {
        val r = real
        if (r == null) {
            val q = pendingQueue
            if (q == null || q.isEmpty()) return
        }
        ensureReal().play()
    }

    override fun pause() {
        val r = real
        if (r == null) {
            if (_state.value == PlayerState.Playing || _state.value == PlayerState.Paused) {
                _state.value = PlayerState.Paused
            }
            return
        }
        r.pause()
    }

    override fun next() = ensureReal().next()
    override fun previous() = ensureReal().previous()

    override fun seek(positionMs: Long) {
        val safePos = positionMs.coerceAtLeast(0L)
        val r = real
        if (r == null) {
            if (pendingQueue == null) return
            pendingSeekMs = safePos
            _positionMs.value = safePos
            if (_state.value == PlayerState.Paused || _state.value == PlayerState.Idle) {
                return
            }
            ensureReal().seek(safePos)
        } else {
            r.seek(safePos)
        }
    }

    override fun setVolume(volume: Float) {
        pendingVolume = volume
        real?.setVolume(volume)
    }

    override val bypassSoftwareFade: Boolean
        get() = real?.bypassSoftwareFade ?: false

    override fun setBitPerfect(on: Boolean) {
        pendingBitPerfect = on
        val r = real
        if (r != null) {
            r.setBitPerfect(on)
        } else {
            _bitPerfectStatus.value = when {
                !supportsBitPerfect -> BitPerfectStatus.Unsupported("Bit-perfect mode is not supported on this engine")
                on -> BitPerfectStatus.Standby()
                else -> BitPerfectStatus.Off
            }
            onPendingBitPerfect?.invoke(on)
        }
    }

    override fun setExclusiveOutput(on: Boolean) {
        pendingExclusive = on
        real?.setExclusiveOutput(on)
    }

    override fun setOutputDevice(id: String?) {
        outputSet = true; pendingOutput = id
        real?.setOutputDevice(id)
    }

    override fun setCorrectionProfile(text: String?) {
        pendingProfile = text
        profileSet = true
        real?.setCorrectionProfile(text)
    }

    override fun setBass(db: Float) {
        pendingBass = db
        real?.setBass(db)
    }

    override fun setExactLevel(on: Boolean) {
        pendingExact = on
        real?.setExactLevel(on)
    }

    override fun setDryCompare(on: Boolean) {
        pendingDry = on
        real?.setDryCompare(on)
    }

    override fun setEngineOptions(bits: Int) {
        pendingOptions = bits
        real?.setEngineOptions(bits)
    }

    override fun setEarphoneCorrection(text: String?) {
        pendingEarphone = text
        earphoneSet = true
        real?.setEarphoneCorrection(text)
    }

    override fun setStereoWidth(width: Float) {
        pendingWidth = width
        real?.setStereoWidth(width)
    }

    override fun setEqualizer(gainsDb: List<Float>?) {
        pendingEq = gainsDb
        real?.setEqualizer(gainsDb)
    }

    override fun setParametricEq(profile: ParametricEqProfile?, enabled: Boolean) {
        pendingParametricEq = profile to enabled
        real?.setParametricEq(profile, enabled)
    }

    override fun setAllowEqInUsbExclusive(allow: Boolean) {
        pendingAllowEqInUsbExclusive = allow
        real?.setAllowEqInUsbExclusive(allow)
    }

    override fun setSpeed(speed: Float) {
        pendingSpeed = speed
        real?.setSpeed(speed)
    }

    override fun setNormalize(on: Boolean) {
        pendingNormalize = on
        real?.setNormalize(on)
    }

    override fun release() {
        scope.cancel()
        real?.release()
        real = null
    }
}
