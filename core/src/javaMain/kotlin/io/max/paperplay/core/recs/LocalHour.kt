package io.max.paperplay.core.recs

actual fun localHourOf(epochMs: Long): Int =
    java.time.Instant.ofEpochMilli(epochMs).atZone(java.time.ZoneId.systemDefault()).hour

actual fun localTimezoneOffsetMs(epochMs: Long): Long =
    java.time.ZoneId.systemDefault().rules.getOffset(java.time.Instant.ofEpochMilli(epochMs)).totalSeconds * 1000L
