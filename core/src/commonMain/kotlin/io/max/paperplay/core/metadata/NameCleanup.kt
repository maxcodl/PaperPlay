package io.max.paperplay.core.metadata

/*
 * Display names for albums and artists. The tags in the library are never changed: these only decide what the Albums and
 * Artists pages show, how they group and how they sort. Real names that use symbols ($uicideboy$, *NSYNC, (G)I-DLE, !!!,
 * ...Baby One More Time) are kept; only junk that uploaders and tag tools add is taken off.
 */

private val voiceCredit = Regex("\\s*[(（\\[]\\s*(?:CV|C\\.V\\.|VO|Voice)\\s*[:：.]?[^)）\\]]*[)）\\]]?", RegexOption.IGNORE_CASE)
private val topicSuffix = Regex("\\s+-\\s+Topic$", RegexOption.IGNORE_CASE)
private val releaseSuffix = Regex("\\s+-\\s+(?:Single|EP)$", RegexOption.IGNORE_CASE)
private val qualityTag = Regex("\\s*[\\[(](?:flac|mp3|m4a|aac|wav|alac|hi-?res|lossless|\\d+\\s*kbps|explicit|clean|\\d{4})[\\])]", RegexOption.IGNORE_CASE)
/** "(Original Motion Picture Soundtrack)", "[OST]", " - Original Score" and the like: the same album as the bare film name. */
private val soundtrackTag = Regex(
    "\\s*[(\\[][^)\\]]*\\b(?:sound\\s?track|ost|score)\\b[^)\\]]*[)\\]]" +
        "|\\s+-\\s+(?:original\\s+)?(?:motion\\s+picture\\s+)?(?:sound\\s?track|score)\\b.*$",
    RegexOption.IGNORE_CASE,
)
/**
 * Edition labels, the same album with more songs or a new master: "(Deluxe Edition)", "(Digital Deluxe)", "(Re-Pack)",
 * "(10th Anniversary Deluxe Edition)", "(Remastered 2011)", "(Bonus Edition)", " - Japan Tour Edition", "(Video Version)",
 * a "(feat. X)" on a single's album and a "(From "Film")" on a film song's album.
 * Not "(Remixes)", "(Acoustic)", "(Instrumental)", "(Live ...)" or "(Taylor's Version)": those are different music.
 */
private val editionTag = Regex(
    "\\s*[(\\[](?:[^)\\]]*\\b(?:deluxe|expanded|special|extended|collector'?s|anniversary|bonus\\s+tracks?|re-?pack|remaster(?:ed)?|digital|edition)\\b[^)\\]]*" +
        "|(?:feat\\.?|ft\\.?|featuring)\\s[^)\\]]*|(?:lyric\\s+)?video\\s+version|from\\s[^)\\]]*)[)\\]]" +
        "|\\s+-\\s+(?:\\d{4}\\s+)?(?:deluxe|expanded|special|extended|anniversary|remaster(?:ed)?|\\w+(?:\\s+\\w+)?\\s+edition)\\b.*$",
    RegexOption.IGNORE_CASE,
)
private val spaces = Regex("\\s+")
private val letterOrDigit = Regex("[\\p{L}\\p{N}]")
private val quotes = "\"“”„«»「」『』"

/** Takes off a quote mark that has no partner (`"Aikatsu! Pripara` -> `Aikatsu! Pripara`), and quotes that wrap the whole name. */
private fun unquote(s: String): String {
    var t = s
    if (t.length >= 2 && t.first() in quotes && t.last() in quotes) t = t.substring(1, t.length - 1).trim()
    if (t.count { it in quotes } == 1) t = t.filterNot { it in quotes }.trim()
    return t
}

/** Takes off a dangling dash, comma or colon at either end ("- (Deluxe)" -> "(Deluxe)", "Title -" -> "Title"), never the whole name. */
private fun trimJoiners(s: String): String {
    val t = s.trim().trimStart('-', '–', '—', ',', ';', ':', '|', ' ').trimEnd('-', '–', '—', ',', ';', ':', '|', ' ')
    return if (letterOrDigit.containsMatchIn(t)) t else s.trim()
}

/** One artist's name as the app shows it: no `(CV: ...)` voice credit, no ` - Topic`, no stray quote marks or edge dashes. */
fun cleanArtistName(raw: String): String {
    var t = raw.replace(voiceCredit, "").replace(topicSuffix, "").replace(spaces, " ").trim()
    t = trimJoiners(unquote(t))
    return t.ifEmpty { raw.trim() }
}

/** An album's name as the app shows it: no ` - Single` / ` - EP`, no soundtrack label, no `(FLAC)`-style tags, no stray quote marks or edge dashes. */
fun cleanAlbumName(raw: String): String {
    var t = raw.replace(qualityTag, "").replace(soundtrackTag, "").replace(editionTag, "").replace(releaseSuffix, "").replace(spaces, " ").trim()
    t = trimJoiners(unquote(t))
    return t.ifEmpty { raw.trim() }
}

private val separators = listOf(",", "&", ";", " / ", " feat. ", " feat ", " ft. ", " ft ", " x ", " × ", " vs. ", " vs ")

/**
 * Each artist of a credit, cleaned, in order and without repeats. Splits on `,` `&` `;` ` / ` `feat.` `ft.` `x` `×` `vs`, but
 * never inside brackets, so `Laala Manaka (CV: Himika Akaneya), Mirei Minami` gives two names, not four pieces. "x" and "vs"
 * split only between two capitalised names (`Anirudh x Arijit Singh`). "and" and "with" never split: too many bands use them
 * (`Simon and Garfunkel`, `Florence and the Machine`).
 */
fun splitArtistsClean(credit: String): List<String> {
    val parts = ArrayList<String>()
    val buf = StringBuilder()
    var depth = 0
    var i = 0
    val lower = credit.lowercase()
    fun flush() { buf.toString().let { if (it.isNotBlank()) parts += it }; buf.setLength(0) }
    while (i < credit.length) {
        val c = credit[i]
        if (c in "([（【{") depth++
        if (c in ")]）】}" && depth > 0) depth--
        if (depth == 0) {
            val sep = separators.firstOrNull { lower.startsWith(it, i) }
            if (sep != null && (sep !in wordSeparators || splitsCleanly(credit, buf.toString(), i + sep.length))) {
                flush(); i += sep.length; continue
            }
        }
        buf.append(c); i++
    }
    flush()
    val seen = HashSet<String>()
    return parts.map { cleanArtistName(it) }.filter { it.isNotBlank() && seen.add(it.lowercase()) }
}

private val wordSeparators = setOf(" x ", " vs ", " vs. ")

/** "x" and "vs" split only between two names that both start with a capital. */
private fun splitsCleanly(all: String, before: String, afterStart: Int): Boolean {
    val after = all.substring(afterStart).takeWhile { it != ',' && it != '&' && it != ';' }.trim()
    val b = before.trim()
    if (b.isEmpty() || after.isEmpty()) return false
    return b.first().isUpperCase() && after.first().isUpperCase()
}

/** The words a name sorts by: lowercase, without leading symbols or "The ", so "$uicideboy$" sorts under U and "The Beatles" under B. */
fun nameSortKey(name: String): String {
    val t = name.lowercase().dropWhile { !it.isLetterOrDigit() }.removePrefix("the ").trim()
    return t.ifEmpty { name.lowercase() }
}

/** The letter a name is filed under in an A-Z index: its first letter, "#" for digits and names with no letters. */
fun nameIndexLetter(name: String): Char {
    val c = nameSortKey(name).firstOrNull() ?: return '#'
    return if (c.isLetter()) c.uppercaseChar() else '#'
}

/** What albums group by: the cleaned name without capitals, spaces or punctuation ("WAKE UP!" = "Wake Up!", "Your Name." = "Your Name"). */
fun albumKey(raw: String): String {
    val clean = cleanAlbumName(raw)
    return comparableText(clean).ifEmpty { clean.lowercase() }
}
