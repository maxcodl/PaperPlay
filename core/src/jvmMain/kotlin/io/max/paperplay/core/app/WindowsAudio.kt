package io.max.paperplay.core.app

/** Windows' default sound output: its name and whether it is headphones. */
class WindowsOutput(val name: String, val headphones: Boolean)

/** The default playback endpoint ("Speakers (Realtek(R) Audio)", "Headphones (realme Buds)"). Null off Windows or when Windows cannot say. */
fun windowsOutput(): WindowsOutput? = io.max.paperplay.player.WindowsOutputDevice.current()?.let { WindowsOutput(it.name, it.headphones) }
