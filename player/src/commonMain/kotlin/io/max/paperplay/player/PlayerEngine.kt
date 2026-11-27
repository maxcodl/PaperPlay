package io.max.paperplay.player

import kotlinx.coroutines.flow.StateFlow

enum class PlayerState { Idle, Loading, Playing, Paused, Ended, Error }

/** Developer option selecting the Android audio sink chain for delegate-path diagnostics. */
enum class SinkChainMode(val id: String, val label: String) {
    FULL("full", "Full"),
    NO_DSP_FLOAT_ON("no_dsp_float_on", "No DSP (float on)"),
    NO_DSP_FLOAT_OFF("no_dsp_float_off", "No DSP (float off)"),
    PLAIN_FLOAT_OFF("plain_float_off", "Plain (float off)"),
    PLAIN_FLOAT_ON("plain_float_on", "Plain (float on)");

    val isPlain: Boolean get() = this == PLAIN_FLOAT_OFF || this == PLAIN_FLOAT_ON
    val isNoDsp: Boolean get() = this == NO_DSP_FLOAT_ON || this == NO_DSP_FLOAT_OFF
    val sinkFloatOutput: Boolean get() = this == FULL || this == NO_DSP_FLOAT_ON || this == PLAIN_FLOAT_ON

    companion object {
        fun fromId(id: String?): SinkChainMode = when (id) {
            "no_dsp" -> NO_DSP_FLOAT_ON
            "plain" -> PLAIN_FLOAT_OFF
            else -> entries.firstOrNull { it.id == id } ?: FULL
        }
    }
}

/** Random-access byte source, e.g. a partially downloaded Telegram file. */
interface StreamSource {
    /** Total size in bytes. */
    val size: Long

    /**
     * Reads up to [length] bytes at [offset]. May block until the range is available.
     * Returns fewer bytes only at end of data; an empty array means offset >= size.
     */
    fun read(offset: Long, length: Int): ByteArray
}

/**
 * [uri] is played directly unless a stream source is supplied; then [uri] is only a unique key
 * (URL-safe, e.g. "tg-123") and bytes come from [source]. [sourceFactory] resolves the stream lazily
 * on first access so large queues do not allocate sources for unplayed tracks.
 */
class QueueItem(
    val uri: String,
    val title: String = "",
    val artist: String = "",
    val artworkUri: String? = null,
    source: StreamSource? = null,
    private val sourceFactory: (() -> StreamSource)? = null,
) {
    private val given: StreamSource? = source

    /**
     * Not kept here: the factory (the track resolver) holds the sources it needs and drops the ones it does not. Caching one per
     * queue item kept the read buffer of every song ever played alive for as long as the queue lived.
     */
    val source: StreamSource? get() = given ?: sourceFactory?.invoke()
}

/** Centre frequencies of the ten equalizer bands, one octave apart. Devices with fewer bands read the curve between them. */
val EQ_BANDS_HZ = listOf(32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)

private val OLD_EQ_BANDS_HZ = listOf(60, 230, 910, 3600, 14000)

private fun curveAt(centres: List<Int>, gains: List<Float>, hz: Double): Float {
    val x = kotlin.math.ln(hz.coerceIn(centres.first().toDouble(), centres.last().toDouble()))
    val i = centres.indices.last { it == 0 || kotlin.math.ln(centres[it].toDouble()) <= x }.coerceAtMost(centres.size - 2)
    val a = kotlin.math.ln(centres[i].toDouble()); val b = kotlin.math.ln(centres[i + 1].toDouble())
    return gains[i] + (gains[i + 1] - gains[i]) * ((x - a) / (b - a)).toFloat()
}

/** The gain of the curve through [gains] (one per [EQ_BANDS_HZ]) at [hz], interpolated on a log frequency axis. */
fun eqGainAt(gains: List<Float>, hz: Double): Float = if (gains.size != EQ_BANDS_HZ.size) 0f else curveAt(EQ_BANDS_HZ, gains, hz)

/** Gains saved by an older build (five bands) become ten by following their curve; anything else not of ten values is flat. */
fun migrateEqGains(saved: List<Float>?): List<Float> = when (saved?.size) {
    EQ_BANDS_HZ.size -> saved
    OLD_EQ_BANDS_HZ.size -> EQ_BANDS_HZ.map { curveAt(OLD_EQ_BANDS_HZ, saved, it.toDouble()) }
    else -> List(EQ_BANDS_HZ.size) { 0f }
}

/** What is being played and how it reaches the speakers, for the output info screen. Null fields are unknown on this platform. */
data class OutputInfo(
    val codec: String? = null,
    val sampleRateHz: Int? = null,
    val channels: Int? = null,
    val bitrateKbps: Int? = null,
    val bitDepth: Int? = null,
    /** Where the sound goes: a device name, or the engine's description of the output. */
    val device: String? = null,
    /** Sample rate the output runs at, when the platform says. */
    val outputRateHz: Int? = null,
    /** Everything in the path that changes the sound: equalizer, normalise, speed, volume. */
    val effects: List<String> = emptyList(),
    /** True only when nothing alters the samples between the file and the output. */
    val bitPerfect: Boolean = false,
    val note: String? = null,
    /** Further label and value rows the engine can state truthfully (formats, meters). */
    val details: List<Pair<String, String>> = emptyList(),
    /** Verified transport telemetry when available. */
    val transport: TransportInfo? = null,
    /** Stable per-device key for EQ auto-assignment (e.g. `usb:1234:5678`, `bt:AA:BB`, `wired:3.5mm`, `speaker:internal`, `desktop:id`). */
    val deviceKey: String? = null,
    /** The output is a Bluetooth device, which always re-encodes the sound, so it can never be bit-perfect. */
    val bluetooth: Boolean = false,
)

internal val NoOutputInfo: StateFlow<OutputInfo?> = kotlinx.coroutines.flow.MutableStateFlow(null)
internal val NoBitPerfectStatus: StateFlow<BitPerfectStatus> = kotlinx.coroutines.flow.MutableStateFlow(
    BitPerfectStatus.Unsupported("Bit-perfect mode is not supported on this engine")
)

interface PlayerEngine {
    val state: StateFlow<PlayerState>
    val positionMs: StateFlow<Long>
    val durationMs: StateFlow<Long>
    val bufferedMs: StateFlow<Long>
    /** Index into the current queue, -1 when empty. */
    val currentIndex: StateFlow<Int>

    /** Replaces the queue and starts playing at [startIndex] from [startPositionMs]. */
    fun setQueue(items: List<QueueItem>, startIndex: Int = 0, startPositionMs: Long = 0L) {
        setQueue(items, startIndex)
        if (startPositionMs > 0L) seek(startPositionMs)
    }
    /** Replaces the queue and starts playing at [startIndex]. */
    fun setQueue(items: List<QueueItem>, startIndex: Int = 0)
    /** Restores a previously saved queue in paused state without starting playback. */
    fun restoreQueue(items: List<QueueItem>, startIndex: Int = 0, positionMs: Long = 0L) {
        setQueue(items, startIndex, positionMs.coerceAtLeast(0L))
        pause()
    }
    fun play()
    fun pause()
    fun next()
    fun previous()
    fun seek(positionMs: Long)
    /** 0 to 1. */
    fun setVolume(volume: Float)
    /** Whether the active audio output bypasses software fades (e.g. exclusive USB mode with native hardware gain ramps). */
    val bypassSoftwareFade: Boolean get() = false
    /** Describes the current track's source format and output path; null until known. */
    val outputInfo: StateFlow<OutputInfo?> get() = NoOutputInfo
    /** True when this engine can run in verified bit-perfect mode. */
    val supportsBitPerfect: Boolean get() = false
    /** Live bit-perfect status for UI & settings. */
    val bitPerfectStatus: StateFlow<BitPerfectStatus> get() = NoBitPerfectStatus
    /** Enables or disables unified bit-perfect playback. */
    fun setBitPerfect(on: Boolean) {}
    /** Android-only USB DAC & diagnostic controller; null on desktop and non-USB engines. */
    val dacController: io.max.paperplay.player.usb.UsbDacController? get() = null
    /** Gains in dB for the bands of [EQ_BANDS_HZ], or null to turn the equalizer off. */
    fun setEqualizer(gainsDb: List<Float>?) {}
    /** 31-band parametric equalizer profile and master toggle; runs in-place on USB Exclusive when allowed. */
    fun setParametricEq(profile: ParametricEqProfile?, enabled: Boolean) {}
    /** Policy toggle: when true, parametric EQ runs at native rate/bit-depth in USB Exclusive mode; when false, strict Bit-Perfect bypasses EQ. */
    fun setAllowEqInUsbExclusive(allow: Boolean) {}
    /** Extra bass in dB (0 to 12) on top of the equalizer; only engines with a DSP stage use it. */
    fun setBass(db: Float) {}
    /** Exact level: everything is lowered by the curve's peak so the heard balance is the drawn curve; off keeps it loud. */
    fun setExactLevel(on: Boolean) {}
    /** A/B check: plays the untouched sound at the processed level, where the engine can. */
    fun setDryCompare(on: Boolean) {}
    /** Stereo width above the bass, 0.5 to 1.6 (1 = as recorded), where the engine can. */
    fun setStereoWidth(width: Float) {}
    /** Earphone correction in AutoEq ParametricEQ text (see [CorrectionProfile.EARPHONES]), or null; phone engine only. */
    fun setEarphoneCorrection(text: String?) {}
    /** Engine options as bits: 1 dynamic bass, 2 de-esser, 4 crossfeed; phone engine only. */
    fun setEngineOptions(bits: Int) {}
    /** Exclusive output for bit-perfect playback, where the engine supports it (the mpv engine on Windows). */
    fun setExclusiveOutput(on: Boolean) {}
    /** An earphone correction curve in AutoEq GraphicEQ text (see [CorrectionProfile]), or null; engines with a filter chain apply it. */
    fun setCorrectionProfile(text: String?) {}
    /** Playback speed, 1 is normal. */
    fun setSpeed(speed: Float) {}
    /** Evens out loud and quiet songs. */
    fun setNormalize(on: Boolean) {}
    fun release()

    fun play(uri: String) = setQueue(listOf(QueueItem(uri)))
}

expect fun createPlayerEngine(): PlayerEngine
