package io.max.paperplay.player

import kotlin.test.Test
import kotlin.test.assertTrue

class WindowsOutputDeviceTest {
    @Test fun readsTheDefaultOutputWithItsIdAndBus() {
        if (!System.getProperty("os.name").orEmpty().startsWith("Windows")) return
        val out = WindowsOutputDevice.current()
        println("default output: ${out?.name} id=${out?.id} headphones=${out?.headphones} bluetooth=${out?.bluetooth}")
        assertTrue(out == null || (out.name.isNotBlank() && out.id.startsWith("{")))
        println("other app playing: ${WindowsOutputDevice.otherAppPlaying()}")
    }
}
