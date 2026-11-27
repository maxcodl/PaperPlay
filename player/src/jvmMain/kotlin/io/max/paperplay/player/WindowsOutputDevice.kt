package io.max.paperplay.player

import com.sun.jna.Function
import com.sun.jna.Memory
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.ptr.PointerByReference
import com.sun.jna.win32.StdCallLibrary

/** Windows' default sound output: its endpoint id, its name, whether it is headphones and whether it is a Bluetooth device. */
class WindowsOutputDevice(val id: String, val name: String, val headphones: Boolean, val bluetooth: Boolean) {
    companion object {
        private val windows = System.getProperty("os.name").orEmpty().startsWith("Windows", ignoreCase = true)

        /**
         * The default playback endpoint, as Windows names it ("Speakers (Realtek(R) Audio)", "Headphones (realme Buds)").
         * Null off Windows or when Windows cannot say. Calls the Core Audio COM interfaces by their method tables; safe from any thread.
         */
        fun current(): WindowsOutputDevice? = if (windows) runCatching { read() }.getOrNull() else null

        /** True while another app (not this process, not Windows' own sounds) is making sound on the default output. */
        fun otherAppPlaying(): Boolean = windows && runCatching { otherSessionActive() }.getOrDefault(false)

        private fun otherSessionActive(): Boolean {
            val initialised = ole32.CoInitializeEx(null, 0) >= 0
            val held = ArrayList<Pointer>()
            fun keep(p: Pointer?): Pointer? = p?.also { held.add(it) }
            try {
                val ppv = PointerByReference()
                if (ole32.CoCreateInstance(guid("BCDE0395-E52F-467C-8E3D-C4579291692E"), null, 1, guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), ppv) < 0) return false
                val enumerator = keep(ppv.value) ?: return false
                val dev = PointerByReference()
                if (call(enumerator, 4, 0, 1, dev) < 0) return false // GetDefaultAudioEndpoint(eRender, eMultimedia)
                val device = keep(dev.value) ?: return false
                val mgrOut = PointerByReference()
                if (call(device, 3, guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), 23, null, mgrOut) < 0) return false // Activate IAudioSessionManager2
                val manager = keep(mgrOut.value) ?: return false
                val enumOut = PointerByReference()
                if (call(manager, 5, enumOut) < 0) return false // GetSessionEnumerator
                val sessions = keep(enumOut.value) ?: return false
                val count = Memory(4)
                if (call(sessions, 3, count) < 0) return false // GetCount
                val me = ProcessHandle.current().pid().toInt()
                val iid2 = guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D")
                val iidMeter = guid("C02216F6-8C67-4B5B-9D00-D008E73E0064")
                val out = Memory(4)
                for (i in 0 until count.getInt(0)) {
                    val sOut = PointerByReference()
                    if (call(sessions, 4, i, sOut) < 0) continue // GetSession
                    val control = keep(sOut.value) ?: continue
                    if (call(control, 3, out) < 0 || out.getInt(0) != 1) continue // GetState: 1 = AudioSessionStateActive
                    val c2Out = PointerByReference()
                    if (call(control, 0, iid2, c2Out) < 0) continue // QueryInterface IAudioSessionControl2
                    val control2 = keep(c2Out.value) ?: continue
                    if (call(control2, 15) == 0) continue // IsSystemSoundsSession: S_OK means it is
                    if (call(control2, 14, out) < 0) continue // GetProcessId
                    val pid = out.getInt(0)
                    if (pid == 0 || pid == me) continue
                    // A browser keeps its session active for a while after a video is paused: only real sound counts.
                    val meterOut = PointerByReference()
                    if (call(control, 0, iidMeter, meterOut) < 0) continue // QueryInterface IAudioMeterInformation
                    val meter = keep(meterOut.value) ?: continue
                    val peak = Memory(4)
                    if (call(meter, 3, peak) >= 0 && peak.getFloat(0) > 0.001f) return true // GetPeakValue
                }
                return false
            } finally {
                held.asReversed().forEach { release(it) }
                if (initialised) ole32.CoUninitialize()
            }
        }

        private interface Ole32 : StdCallLibrary {
            fun CoInitializeEx(reserved: Pointer?, coInit: Int): Int
            fun CoUninitialize()
            fun CoCreateInstance(clsid: Pointer, outer: Pointer?, context: Int, iid: Pointer, out: PointerByReference): Int
            fun CoTaskMemFree(p: Pointer?)
            fun PropVariantClear(pv: Pointer): Int
        }

        private val ole32: Ole32 by lazy { Native.load("ole32", Ole32::class.java) }

        /** A GUID in COM's memory layout: three little-endian numbers, then eight bytes. [extra] bytes follow it (a property id). */
        private fun guid(text: String, extra: Int = 0): Memory {
            val h = text.replace("-", "")
            return Memory(16L + extra).also { m ->
                m.setInt(0, h.substring(0, 8).toLong(16).toInt())
                m.setShort(4, h.substring(8, 12).toInt(16).toShort())
                m.setShort(6, h.substring(12, 16).toInt(16).toShort())
                for (i in 0 until 8) m.setByte(8L + i, h.substring(16 + 2 * i, 18 + 2 * i).toInt(16).toByte())
            }
        }

        private fun key(fmtid: String, pid: Int): Memory = guid(fmtid, 4).also { it.setInt(16, pid) }

        private fun call(obj: Pointer, index: Int, vararg args: Any?): Int {
            val table = obj.getPointer(0)
            val fn = Function.getFunction(table.getPointer(index.toLong() * Native.POINTER_SIZE), Function.ALT_CONVENTION)
            return fn.invokeInt(arrayOf<Any?>(obj, *args))
        }

        private fun release(p: Pointer?) { if (p != null) call(p, 2) }

        /** Runs [block] with a device enumerator, COM set up for the call. */
        private fun <T> withEnumerator(block: (Pointer) -> T?): T? {
            val initialised = ole32.CoInitializeEx(null, 0) >= 0
            var enumerator: Pointer? = null
            try {
                val ppv = PointerByReference()
                if (ole32.CoCreateInstance(guid("BCDE0395-E52F-467C-8E3D-C4579291692E"), null, 1 /* CLSCTX_INPROC_SERVER */, guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), ppv) < 0) return null
                enumerator = ppv.value ?: return null
                return block(enumerator)
            } finally {
                release(enumerator)
                if (initialised) ole32.CoUninitialize()
            }
        }

        private fun read(): WindowsOutputDevice? = withEnumerator { en ->
            val dev = PointerByReference()
            if (call(en, 4, 0, 1, dev) < 0) return@withEnumerator null // GetDefaultAudioEndpoint(eRender, eMultimedia)
            val device = dev.value ?: return@withEnumerator null
            try { describe(device) } finally { release(device) }
        }

        /** Every output Windows has switched on (unplugged and disabled ones left out), in Windows' order. */
        fun all(): List<WindowsOutputDevice> = if (!windows) emptyList() else runCatching {
            withEnumerator { en ->
                val col = PointerByReference()
                if (call(en, 3, 0, 1, col) < 0) return@withEnumerator null // EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE)
                val collection = col.value ?: return@withEnumerator null
                try {
                    val count = Memory(4)
                    if (call(collection, 3, count) < 0) return@withEnumerator null // GetCount
                    (0 until count.getInt(0)).mapNotNull { i ->
                        val item = PointerByReference()
                        if (call(collection, 4, i, item) < 0) null // Item
                        else item.value?.let { d -> try { describe(d) } finally { release(d) } }
                    }
                } finally { release(collection) }
            }
        }.getOrNull().orEmpty()

        /** Id, name, form and bus of one endpoint. */
        private fun describe(device: Pointer): WindowsOutputDevice? {
            val idOut = PointerByReference()
            if (call(device, 5, idOut) < 0) return null // GetId
            val id = idOut.value?.let { p -> try { p.getWideString(0) } finally { ole32.CoTaskMemFree(p) } } ?: return null
            val ps = PointerByReference()
            if (call(device, 4, 0, ps) < 0) return null // OpenPropertyStore(STGM_READ)
            val store = ps.value ?: return null
            try {
                val value = Memory(24)
                fun string(k: Memory): String? {
                    value.clear()
                    if (call(store, 5, k, value) < 0) return null
                    return (if (value.getShort(0).toInt() == 31) value.getPointer(8)?.getWideString(0) else null).also { ole32.PropVariantClear(value) }
                }
                fun uint(k: Memory): Int {
                    value.clear()
                    if (call(store, 5, k, value) < 0) return -1
                    return (if (value.getShort(0).toInt() == 19) value.getInt(8) else -1).also { ole32.PropVariantClear(value) }
                }
                val name = string(key("A45C254E-DF1C-4EFD-8020-67D146A850E0", 14))
                if (name.isNullOrBlank()) return null
                // PKEY_Device_EnumeratorName: BTHENUM (A2DP) or BTHHFENUM (hands-free) for Bluetooth, USB, HDAUDIO and so on otherwise.
                val bus = string(key("A45C254E-DF1C-4EFD-8020-67D146A850E0", 24)).orEmpty()
                // PKEY_AudioEndpoint_FormFactor: 3 = headphones, 5 = headset.
                val form = uint(key("1DA5D803-D492-4EDD-8C23-E0C0FFEE7F0E", 0))
                return WindowsOutputDevice(id, name, form == 3 || form == 5, bus.startsWith("BTH", ignoreCase = true))
            } finally { release(store) }
        }
    }
}
