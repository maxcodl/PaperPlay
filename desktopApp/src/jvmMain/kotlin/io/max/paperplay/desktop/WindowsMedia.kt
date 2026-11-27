package io.max.paperplay.desktop

import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.Structure
import com.sun.jna.win32.StdCallLibrary

/**
 * Makes Windows treat the app as a music player: its own app id (taskbar grouping, volume mixer name) and the
 * keyboard media keys (play/pause, next, previous, stop), which work whether or not the window has focus.
 *
 * The keys are held only while they are this app's to answer: while it plays, and while it is paused until another app
 * (a browser video, another player) starts playing. Then they are let go so that app gets them, and taken back when this
 * app plays again.
 */
internal object WindowsMedia {
    @Structure.FieldOrder("hwnd", "message", "wParam", "lParam", "time", "x", "y", "priv")
    class Msg : Structure() {
        @JvmField var hwnd: Pointer? = null
        @JvmField var message = 0
        @JvmField var wParam = 0L
        @JvmField var lParam = 0L
        @JvmField var time = 0
        @JvmField var x = 0
        @JvmField var y = 0
        @JvmField var priv = 0
    }

    private interface User32 : StdCallLibrary {
        fun RegisterHotKey(hwnd: Pointer?, id: Int, mods: Int, vk: Int): Boolean
        fun UnregisterHotKey(hwnd: Pointer?, id: Int): Boolean
        fun SetTimer(hwnd: Pointer?, id: Long, ms: Int, fn: Pointer?): Long
        fun GetMessageW(msg: Msg, hwnd: Pointer?, min: Int, max: Int): Int
    }

    private interface Shell32 : StdCallLibrary {
        fun SetCurrentProcessExplicitAppUserModelID(id: com.sun.jna.WString): Int
    }

    private interface Advapi32 : StdCallLibrary {
        fun RegSetKeyValueW(key: Pointer, subKey: com.sun.jna.WString, valueName: com.sun.jna.WString, type: Int, data: Pointer, bytes: Int): Int
    }

    private const val APP_ID = "io.max.paperplay"

    /**
     * Gives the app id a name and an icon (HKCU\Software\Classes\AppUserModelId\<id>), so the Windows media flyout and the
     * volume mixer say "PaperPlay" instead of "Unknown app". The icon is copied out of the app to the data folder.
     */
    private fun registerAppName() {
        val dir = java.io.File(System.getenv("APPDATA") ?: return, "PaperPlay").apply { mkdirs() }
        val icon = java.io.File(dir, "app-icon.png")
        if (!icon.isFile) WindowsMedia::class.java.classLoader.getResourceAsStream("icon.png")?.use { input -> icon.outputStream().use { input.copyTo(it) } }
        val reg = Native.load("advapi32", Advapi32::class.java)
        val hkcu = Pointer(0x80000001L)
        val key = com.sun.jna.WString("Software\\Classes\\AppUserModelId\\$APP_ID")
        fun put(name: String, value: String) {
            val bytes = (value.length + 1) * 2
            val data = com.sun.jna.Memory(bytes.toLong()).apply { clear(); setWideString(0, value) }
            reg.RegSetKeyValueW(hkcu, key, com.sun.jna.WString(name), 1 /* REG_SZ */, data, bytes)
        }
        put("DisplayName", "PaperPlay")
        if (icon.isFile) put("IconUri", icon.absolutePath)
    }

    private interface Ole32 : StdCallLibrary {
        fun CoInitializeEx(reserved: Pointer?, coInit: Int): Int
        fun CoUninitialize()
        fun CoCreateInstance(clsid: Pointer, outer: Pointer?, context: Int, iid: Pointer, out: com.sun.jna.ptr.PointerByReference): Int
        fun PropVariantClear(pv: Pointer): Int
    }

    /**
     * The media flyout names an app by the Start menu shortcut that carries its app id. Stamps the id on the app's own
     * shortcut (made by the installer, which leaves the id out), or makes that shortcut when there is none. Only for the
     * installed app (PaperPlay.exe), never for a development run.
     */
    private fun stampShortcut() {
        val exe = ProcessHandle.current().info().command().orElse("")
        if (!exe.endsWith("PaperPlay.exe", ignoreCase = true)) return
        val lnk = java.io.File(System.getenv("APPDATA") ?: return, "Microsoft\\Windows\\Start Menu\\Programs\\PaperPlay.lnk")
        val ole = Native.load("ole32", Ole32::class.java)
        val initialised = ole.CoInitializeEx(null, 2) >= 0
        val held = ArrayList<Pointer>()
        fun keep(p: Pointer?) = p?.also { held.add(it) }
        try {
            val out = com.sun.jna.ptr.PointerByReference()
            if (ole.CoCreateInstance(comGuid("00021401-0000-0000-C000-000000000046"), null, 1, comGuid("000214F9-0000-0000-C000-000000000046"), out) < 0) return
            val link = keep(out.value) ?: return // IShellLinkW
            val pf = com.sun.jna.ptr.PointerByReference()
            if (comCall(link, 0, comGuid("0000010B-0000-0000-C000-000000000046"), pf) < 0) return
            val file = keep(pf.value) ?: return // IPersistFile
            if (lnk.isFile) { if (comCall(file, 5, com.sun.jna.WString(lnk.path), 2) < 0) return } // Load, read and write
            else comCall(link, 20, com.sun.jna.WString(exe)) // SetPath
            val ps = com.sun.jna.ptr.PointerByReference()
            if (comCall(link, 0, comGuid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), ps) < 0) return
            val store = keep(ps.value) ?: return // IPropertyStore
            val key = comGuid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3", 4).also { it.setInt(16, 5) } // PKEY_AppUserModel_ID
            val value = com.sun.jna.Memory(24).apply { clear() }
            if (comCall(store, 5, key, value) >= 0) {
                val now = if (value.getShort(0).toInt() == 31) value.getPointer(8)?.getWideString(0) else null
                ole.PropVariantClear(value)
                if (now == APP_ID) return
            }
            val text = com.sun.jna.Memory((APP_ID.length + 1) * 2L).apply { setWideString(0, APP_ID) }
            value.clear(); value.setShort(0, 31); value.setPointer(8, text) // VT_LPWSTR
            if (comCall(store, 6, key, value) < 0 || comCall(store, 7) < 0) return // SetValue, Commit
            comCall(file, 6, com.sun.jna.WString(lnk.path), 1) // Save
        } finally {
            held.asReversed().forEach { comCall(it, 2) }
            if (initialised) ole.CoUninitialize()
        }
    }

    private fun comGuid(text: String, extra: Int = 0): com.sun.jna.Memory {
        val h = text.replace("-", "")
        return com.sun.jna.Memory(16L + extra).also { m ->
            m.setInt(0, h.substring(0, 8).toLong(16).toInt())
            m.setShort(4, h.substring(8, 12).toInt(16).toShort())
            m.setShort(6, h.substring(12, 16).toInt(16).toShort())
            for (i in 0 until 8) m.setByte(8L + i, h.substring(16 + 2 * i, 18 + 2 * i).toInt(16).toByte())
        }
    }

    private fun comCall(obj: Pointer, index: Int, vararg args: Any?): Int {
        val fn = com.sun.jna.Function.getFunction(obj.getPointer(0).getPointer(index.toLong() * Native.POINTER_SIZE), com.sun.jna.Function.ALT_CONVENTION)
        return fn.invokeInt(arrayOf<Any?>(obj, *args))
    }

    /** [onKey] gets "playpause", "next", "previous" or "stop" on a background thread. [isPlaying] says whether this app plays now. */
    fun start(isPlaying: () -> Boolean, onKey: (String) -> Unit) {
        if (!System.getProperty("os.name").orEmpty().startsWith("Windows")) return
        runCatching { registerAppName() }
        Thread({ runCatching { stampShortcut() }.onFailure { io.max.paperplay.player.PlayLog.log("media", "shortcut not updated: $it") } }, "app-shortcut")
            .apply { isDaemon = true; start() }
        runCatching { Native.load("shell32", Shell32::class.java).SetCurrentProcessExplicitAppUserModelID(com.sun.jna.WString(APP_ID)) }
        val thread = Thread({
            runCatching {
                val u = Native.load("user32", User32::class.java)
                val keys = listOf(0xB3 to "playpause", 0xB0 to "next", 0xB1 to "previous", 0xB2 to "stop")
                var held = false
                fun hold(on: Boolean) {
                    if (on == held) return
                    keys.forEachIndexed { i, (vk, _) -> if (on) u.RegisterHotKey(null, i + 1, 0x4000, vk) else u.UnregisterHotKey(null, i + 1) } // MOD_NOREPEAT
                    held = on
                }
                hold(true)
                // Hot keys belong to the thread that registered them, so the check runs here, on this thread's timer.
                u.SetTimer(null, 0, 1_500, null)
                val msg = Msg()
                while (u.GetMessageW(msg, null, 0, 0) > 0) {
                    when (msg.message) {
                        0x0312 -> keys.getOrNull(msg.wParam.toInt() - 1)?.let { onKey(it.second) } // WM_HOTKEY
                        0x0113 -> when { // WM_TIMER
                            // Windows' media controls route the keys themselves, to whichever app played or paused last.
                            WindowsSmtc.active -> hold(false)
                            isPlaying() -> hold(true)
                            held && io.max.paperplay.player.WindowsOutputDevice.otherAppPlaying() -> hold(false)
                        }
                    }
                }
            }
        }, "media-keys").apply { isDaemon = true }
        thread.start()
    }
}
