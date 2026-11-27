package io.max.paperplay.ui

actual fun listOutputDevices(): List<Pair<String, String>> = io.max.paperplay.player.WindowsOutputDevice.all().map { it.id to it.name }
