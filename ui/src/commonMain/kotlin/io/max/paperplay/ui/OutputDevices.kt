package io.max.paperplay.ui

/** The sound outputs the app can play through (id to name): every switched-on Windows output on the PC, none on the phone. */
expect fun listOutputDevices(): List<Pair<String, String>>
