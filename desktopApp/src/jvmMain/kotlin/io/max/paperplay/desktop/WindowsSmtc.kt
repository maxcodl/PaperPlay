package io.max.paperplay.desktop

import com.sun.jna.CallbackThreadInitializer
import com.sun.jna.Function
import com.sun.jna.Memory
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.WString
import com.sun.jna.ptr.PointerByReference
import com.sun.jna.win32.StdCallLibrary
import io.max.paperplay.player.PlayLog
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Windows' media controls (System Media Transport Controls) for the main window: the media flyout shows the song and its
 * buttons, and Windows sends the keyboard media keys to whichever app played or paused last, this one or a browser.
 * WinRT is called through its COM method tables with JNA; the ButtonPressed handler is a small COM object built here.
 * Every WinRT call runs on one thread that joined the multithreaded apartment.
 */
internal object WindowsSmtc {
    private interface Combase : StdCallLibrary {
        fun RoInitialize(type: Int): Int
        fun RoGetActivationFactory(classId: Pointer, iid: Pointer, factory: PointerByReference): Int
        fun WindowsCreateString(text: WString, length: Int, out: PointerByReference): Int
        fun WindowsDeleteString(s: Pointer?): Int
    }

    private interface QueryInterfaceFn : StdCallLibrary.StdCallCallback { fun callback(self: Pointer, iid: Pointer, out: Pointer): Int }
    private interface RefFn : StdCallLibrary.StdCallCallback { fun callback(self: Pointer): Int }
    private interface InvokeFn : StdCallLibrary.StdCallCallback { fun callback(self: Pointer, sender: Pointer?, args: Pointer?): Int }

    private val thread = Executors.newSingleThreadExecutor { r -> Thread(r, "media-controls").apply { isDaemon = true } }
    private lateinit var rt: Combase
    private var controls: Pointer? = null
    private var onAction: (String) -> Unit = {}

    /** True once Windows' media controls are set up; the app's own media-key hot keys stand down then. */
    @Volatile var active = false
        private set

    // The handler object: one pointer to a method table of four functions. Kept here so they are never collected.
    private val qi = object : QueryInterfaceFn {
        override fun callback(self: Pointer, iid: Pointer, out: Pointer): Int {
            if (!answers(iid)) { out.setPointer(0, null); return E_NOINTERFACE }
            out.setPointer(0, self)
            return 0
        }
    }
    private val addRefFn = object : RefFn { override fun callback(self: Pointer): Int = 1 }
    private val releaseFn = object : RefFn { override fun callback(self: Pointer): Int = 1 }
    private val invoke = object : InvokeFn {
        override fun callback(self: Pointer, sender: Pointer?, args: Pointer?): Int {
            runCatching {
                val a = args ?: return 0
                val button = Memory(4).also { it.setInt(0, -1) }
                if (call(a, 6, button) < 0) return 0 // get_Button
                when (button.getInt(0)) {
                    0, 1 -> "playpause" // Play, Pause: the app knows which it is doing
                    2 -> "stop"
                    6 -> "next"
                    7 -> "previous"
                    else -> null
                }?.let(onAction)
            }.onFailure { PlayLog.log("media", "button handler failed: $it") }
            return 0
        }
    }
    private val vtable = Memory(4L * Native.POINTER_SIZE).also { t ->
        listOf(qi, addRefFn, releaseFn, invoke).forEachIndexed { i, cb ->
            t.setPointer(i.toLong() * Native.POINTER_SIZE, com.sun.jna.CallbackReference.getFunctionPointer(cb))
        }
    }
    private val handler = Memory(Native.POINTER_SIZE.toLong()).also { it.setPointer(0, vtable) }

    /** Connects [window] to Windows' media controls. [action] gets "playpause", "next", "previous" or "stop". False when it could not. */
    fun install(window: java.awt.Window, action: (String) -> Unit): Boolean {
        if (!System.getProperty("os.name").orEmpty().startsWith("Windows")) return false
        onAction = action
        return onThread {
            val hwnd = Native.getComponentPointer(window) ?: error("no window handle")
            rt = Native.load("combase", Combase::class.java)
            rt.RoInitialize(1) // multithreaded; an "already initialised" answer is fine
            listOf(qi, addRefFn, releaseFn, invoke).forEach { Native.setCallbackThreadInitializer(it, CallbackThreadInitializer(true, false, "media-controls-event")) }
            val interop = factory("Windows.Media.SystemMediaTransportControls", "DDB0472D-C911-4A1F-86D9-DC3D71A95F5A")
            try {
                val out = PointerByReference()
                check(call(interop, 6, hwnd, guid("99FA3FF4-1742-42A6-902E-087D41F965EC"), out) >= 0) { "GetForWindow failed" }
                val c = out.value ?: error("no media controls")
                for (slot in listOf(11, 13, 15, 17, 25, 27)) call(c, slot, 1) // IsEnabled, Play, Stop, Pause, Previous, Next
                val token = Memory(8)
                val hrAdd = call(c, 32, handler, token)
                check(hrAdd >= 0) { "add_ButtonPressed failed 0x${Integer.toHexString(hrAdd)}" }
                call(c, 7, 2) // PlaybackStatus Stopped until something plays
                controls = c
            } finally { release(interop) }
            active = true
            PlayLog.log("media", "Windows media controls connected")
            true
        } == true
    }

    /** Playing, paused, or nothing loaded. */
    fun setPlaying(playing: Boolean, hasSong: Boolean) {
        onThread { controls?.let { call(it, 7, if (!hasSong) 2 else if (playing) 3 else 4) } } // put_PlaybackStatus
    }

    /** The song in the media flyout. [cover] is a local file path or an http address, or null. */
    fun setSong(title: String, artist: String, album: String, cover: String?) {
        onThread {
            val c = controls ?: return@onThread
            val updOut = PointerByReference()
            if (call(c, 8, updOut) < 0) return@onThread // get_DisplayUpdater
            val updater = updOut.value ?: return@onThread
            try {
                call(updater, 7, 1) // put_Type Music
                val musicOut = PointerByReference()
                if (call(updater, 12, musicOut) >= 0) musicOut.value?.let { music -> // get_MusicProperties
                    try {
                        withString(title) { call(music, 7, it) }
                        withString(artist) { call(music, 11, it) }
                        val m2 = PointerByReference()
                        if (call(music, 0, guid("00368462-97D3-44B9-B00F-008AFCEFAF18"), m2) >= 0) m2.value?.let { p ->
                            try { withString(album) { call(p, 7, it) } } finally { release(p) } // put_AlbumTitle
                        }
                    } finally { release(music) }
                }
                val thumb = thumbnail(cover)
                try { call(updater, 11, thumb) } finally { release(thumb) } // put_Thumbnail (null clears it)
                call(updater, 17) // Update
            } finally { release(updater) }
        }
    }

    private interface StreamApi : StdCallLibrary {
        fun SHCreateStreamOnFileEx(file: WString, mode: Int, attributes: Int, create: Boolean, template: Pointer?, out: PointerByReference): Int
    }
    private interface ShcoreApi : StdCallLibrary {
        fun CreateRandomAccessStreamOverStream(stream: Pointer, options: Int, iid: Pointer, out: PointerByReference): Int
    }

    private fun thumbnail(cover: String?): Pointer? = runCatching {
        when {
            cover.isNullOrBlank() -> null
            cover.startsWith("http://") || cover.startsWith("https://") -> thumbnailFromUri(cover)
            // A desktop app cannot hand Windows a file:// address for this; a stream over the file works.
            java.io.File(cover).isFile -> thumbnailFromFile(java.io.File(cover).absolutePath)
            else -> null
        }
    }.getOrNull()

    private fun streamReference(slot: Int, arg: Pointer): Pointer? {
        val statics = factory("Windows.Storage.Streams.RandomAccessStreamReference", "857309DC-3FBF-4E7D-986F-EF3B1A07A964")
        try {
            val o = PointerByReference()
            return if (call(statics, slot, arg, o) < 0) null else o.value // 7 CreateFromUri, 8 CreateFromStream
        } finally { release(statics) }
    }

    private fun thumbnailFromFile(path: String): Pointer? {
        val ist = PointerByReference()
        if (Native.load("shlwapi", StreamApi::class.java).SHCreateStreamOnFileEx(WString(path), 0x40 /* read, share */, 0x80, false, null, ist) < 0) return null
        val istream = ist.value ?: return null
        try {
            val ras = PointerByReference()
            if (Native.load("shcore", ShcoreApi::class.java).CreateRandomAccessStreamOverStream(istream, 0, guid("905A0FE1-BC53-11DF-8C49-001E4FC686DA"), ras) < 0) return null
            val stream = ras.value ?: return null
            try { return streamReference(8, stream) } finally { release(stream) }
        } finally { release(istream) }
    }

    private fun thumbnailFromUri(uriText: String): Pointer? {
        val uriFactory = factory("Windows.Foundation.Uri", "44A9796F-723E-4FDF-A218-033E75B0C084")
        val uri = try {
            val o = PointerByReference()
            withString(uriText) { call(uriFactory, 6, it, o) } // CreateUri
            o.value
        } finally { release(uriFactory) } ?: return null
        try { return streamReference(7, uri) } finally { release(uri) }
    }

    private fun factory(className: String, iid: String): Pointer {
        val out = PointerByReference()
        val hr = withString(className) { rt.RoGetActivationFactory(it, guid(iid), out) }
        check(hr >= 0) { "no factory for $className (0x${Integer.toHexString(hr)})" }
        return out.value ?: error("no factory for $className")
    }

    private fun <T> withString(text: String, block: (Pointer) -> T): T {
        val out = PointerByReference()
        check(rt.WindowsCreateString(WString(text), text.length, out) >= 0) { "string failed" }
        val h = out.value
        try { return block(h ?: Pointer.NULL) } finally { if (h != null) rt.WindowsDeleteString(h) }
    }

    /**
     * Interfaces the handler answers to: IUnknown, IAgileObject (it may be called from any thread) and its own delegate type,
     * TypedEventHandler<SystemMediaTransportControls, SystemMediaTransportControlsButtonPressedEventArgs>. Anything else
     * (INoMarshal, IMarshal, IInspectable) is refused: answering INoMarshal makes Windows refuse the handler.
     */
    private fun answers(iid: Pointer): Boolean =
        "%08X-%04X-%04X".format(iid.getInt(0), iid.getShort(4).toInt() and 0xFFFF, iid.getShort(6).toInt() and 0xFFFF) in setOf(
            "00000000-0000-0000", // IUnknown
            "94EA2B94-E9CC-49E0", // IAgileObject
            "0557E996-7B23-5BAE", // the ButtonPressed delegate
        )

    private fun guid(text: String): Memory {
        val h = text.replace("-", "")
        return Memory(16).also { m ->
            m.setInt(0, h.substring(0, 8).toLong(16).toInt())
            m.setShort(4, h.substring(8, 12).toInt(16).toShort())
            m.setShort(6, h.substring(12, 16).toInt(16).toShort())
            for (i in 0 until 8) m.setByte(8L + i, h.substring(16 + 2 * i, 18 + 2 * i).toInt(16).toByte())
        }
    }

    private fun call(obj: Pointer, index: Int, vararg args: Any?): Int {
        val fn = Function.getFunction(obj.getPointer(0).getPointer(index.toLong() * Native.POINTER_SIZE), Function.ALT_CONVENTION)
        return fn.invokeInt(arrayOf<Any?>(obj, *args))
    }

    private fun release(p: Pointer?) { if (p != null) call(p, 2) }

    private fun <T> onThread(block: () -> T?): T? = runCatching {
        thread.submit<T?> { runCatching(block).onFailure { PlayLog.log("media", "media controls: $it") }.getOrNull() }.get(5, TimeUnit.SECONDS)
    }.getOrNull()

    private const val E_NOINTERFACE = 0x80004002.toInt()
}
