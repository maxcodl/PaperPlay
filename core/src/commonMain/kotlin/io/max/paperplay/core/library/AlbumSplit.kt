package io.max.paperplay.core.library

import io.max.paperplay.core.metadata.cleanArtistName
import io.max.paperplay.core.metadata.splitArtistsClean

/**
 * Splits the songs that share one album name by artist, so a generic name such as "Greatest Hits"
 * does not merge unrelated artists. The owner is null when the album stays whole.
 *
 * Songs whose credits share an artist belong together (a film album where every song has other singers but the same
 * composer stays one album). Only groups with no artist in common are split, and the album still stays whole when one
 * group has at least 60% of the songs (the rest are guests) or there are four or more groups (a compilation).
 * The owner of a part is its most credited artist.
 */
fun <T> splitAlbum(items: List<T>, artistOf: (T) -> String): List<Pair<String?, List<T>>> {
    if (items.size < 2) return listOf(null to items)
    val names = items.map { item -> splitArtistsClean(artistOf(item)).ifEmpty { listOf(cleanArtistName(artistOf(item))) }.map { it.lowercase() } }
    // Joins songs that share any artist (union-find over song indexes).
    val parent = IntArray(items.size) { it }
    fun root(i: Int): Int { var r = i; while (parent[r] != r) r = parent[r]; parent[i] = r; return r }
    val firstWith = HashMap<String, Int>()
    names.forEachIndexed { i, list -> list.forEach { n -> firstWith[n]?.let { j -> parent[root(i)] = root(j) } ?: run { firstWith[n] = i } } }
    val groups = items.indices.groupBy { root(it) }.values.toList()
    if (groups.size <= 1) return listOf(null to items)
    val top = groups.maxOf { it.size }
    if (top * 5 >= items.size * 3 || groups.size >= 4) return listOf(null to items)
    return groups.map { idx ->
        val counts = idx.flatMap { i -> splitArtistsClean(artistOf(items[i])).ifEmpty { listOf(cleanArtistName(artistOf(items[i]))) } }
            .groupingBy { it }.eachCount()
        val owner = counts.entries.sortedWith(compareByDescending<Map.Entry<String, Int>> { it.value }.thenBy { it.key.lowercase() }).first().key
        owner to idx.map { items[it] }
    }.sortedBy { it.first.lowercase() }
}
