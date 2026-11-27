package io.max.paperplay.core.metadata

import kotlin.test.Test
import kotlin.test.assertEquals

class NameCleanupTest {
    @Test fun voiceCreditsSplitWithoutTearingBrackets() {
        assertEquals(
            listOf("Ruka", "Rie", "Miki", "Laala Manaka", "Mirei Minami", "Sophy Hojo"),
            splitArtistsClean("Ruka, Rie, Miki, Laala Manaka (CV: Himika Akaneya), Mirei Minami (CV: Yu Serizawa), Sophy Hojo (CV: Miyu Kubota)"),
        )
    }

    @Test fun usualSeparatorsAndRepeats() {
        assertEquals(listOf("Billie Eilish", "FINNEAS"), splitArtistsClean("Billie Eilish & FINNEAS"))
        assertEquals(listOf("G-Eazy", "Halsey"), splitArtistsClean("G-Eazy feat. Halsey"))
        assertEquals(listOf("Anirudh Ravichander", "Arijit Singh"), splitArtistsClean("Anirudh Ravichander x Arijit Singh"))
        assertEquals(listOf("A", "B"), splitArtistsClean("A, B, a"))
    }

    @Test fun bandNamesStayWhole() {
        assertEquals(listOf("Simon and Garfunkel"), splitArtistsClean("Simon and Garfunkel"))
        assertEquals(listOf("Florence and the Machine"), splitArtistsClean("Florence and the Machine"))
        assertEquals(listOf("Lil Nas X"), splitArtistsClean("Lil Nas X"))
    }

    @Test fun symbolNamesAreKept() {
        for (n in listOf("\$uicideboy\$", "*NSYNC", "(G)I-DLE", "!!!", "\$NOT", "10-FEET")) assertEquals(n, cleanArtistName(n))
    }

    @Test fun junkIsTakenOff() {
        assertEquals("Barney Sku", cleanArtistName("Barney Sku - Topic"))
        assertEquals("Aikatsu! Pripara THE MOVIE", cleanAlbumName("\"Aikatsu! Pripara THE MOVIE"))
        assertEquals("You and Idol Precure", cleanAlbumName("\"You and Idol Precure\""))
        assertEquals("-", cleanAlbumName("- (Deluxe)")) // Ed Sheeran's album "-"
        assertEquals("&burn", cleanAlbumName("&burn - Single"))
        assertEquals("00:00", cleanAlbumName("00:00 - EP"))
        assertEquals("...Baby One More Time", cleanAlbumName("...Baby One More Time"))
        assertEquals("-", cleanAlbumName("-"))
        assertEquals("Aavesham", cleanAlbumName("Aavesham (Original Motion Picture Soundtrack)"))
        assertEquals("Jailer", cleanAlbumName("Jailer [OST]"))
        assertEquals("Interstellar", cleanAlbumName("Interstellar - Original Motion Picture Soundtrack"))
        assertEquals("Lost", cleanAlbumName("Lost (Deluxe)"))
        assertEquals("Megalithic Symphony", cleanAlbumName("Megalithic Symphony (10th Anniversary Deluxe Edition)"))
        assertEquals("WHEN WE ALL FALL ASLEEP, WHERE DO WE GO?", cleanAlbumName("WHEN WE ALL FALL ASLEEP, WHERE DO WE GO? (Re-Pack)"))
        assertEquals("Without Me", cleanAlbumName("Without Me (feat. Juice WRLD)"))
        assertEquals("Abbey Road", cleanAlbumName("Abbey Road (Remastered 2019)"))
        assertEquals("Fighting Demons", cleanAlbumName("Fighting Demons (lyric video version)"))
        assertEquals("AURA (Remixes)", cleanAlbumName("AURA (Remixes)"))
        assertEquals("Red (Taylor's Version)", cleanAlbumName("Red (Taylor's Version)"))
        assertEquals("Ocean Eyes (live from The Hi Hat)", cleanAlbumName("Ocean Eyes (live from The Hi Hat)"))
        assertEquals(albumKey("WAKE UP!"), albumKey("Wake Up!"))
        assertEquals(albumKey("Your Name"), albumKey("Your Name."))
        assertEquals(albumKey("Soulful Melodies - Flute Version (Instrumental)"), albumKey("Soulful Melodies - Flute Version Instrumental"))
        assertEquals("Ghost Stories", cleanAlbumName("Ghost Stories"))
        assertEquals("Future Nostalgia", cleanAlbumName("Future Nostalgia(Bonus Edition)"))
        assertEquals("Believe", cleanAlbumName("Believe - Japan Tour Edition"))
        assertEquals("Summer Dance Party", cleanAlbumName("Summer Dance Party (Clean)"))
        assertEquals("Greatest Hits", cleanAlbumName("Greatest Hits (2008)"))
        assertEquals("SOUR", cleanAlbumName("SOUR (Video Version)"))
        assertEquals("Hurry Up Tomorrow", cleanAlbumName("Hurry Up Tomorrow (Original Motion Picture Score)"))
        assertEquals("Ranam", cleanAlbumName("Ranam (From \"Ranam\")"))
        assertEquals(albumKey("Barbie The Album"), albumKey("Barbie: The Album (Best Weekend Ever edition)"))
        assertEquals("Jhol (Acoustic)", cleanAlbumName("Jhol (Acoustic)"))
        assertEquals("HEROES & VILLAINS (Heroes Version)", cleanAlbumName("HEROES & VILLAINS (Heroes Version)"))
    }

    @Test fun filmAlbumWithManySingersStaysWhole() {
        val r = io.max.paperplay.core.library.splitAlbum(
            listOf("Sushin Shyam", "Sushin Shyam, Vidhu", "Sushin Shyam & Dabzee", "Sushin Shyam", "Hanumankind, Sushin Shyam", "Sushin Shyam, Vinayak"),
        ) { it }
        assertEquals(1, r.size)
    }

    @Test fun unrelatedArtistsStillSplit() {
        val r = io.max.paperplay.core.library.splitAlbum(listOf("Queen", "Queen", "ABBA", "ABBA")) { it }
        assertEquals(listOf("ABBA", "Queen"), r.map { it.first })
    }

    @Test fun sortingIgnoresLeadingSymbolsAndThe() {
        assertEquals("uicideboy\$", nameSortKey("\$uicideboy\$"))
        assertEquals("weeknd", nameSortKey("The Weeknd"))
        assertEquals('U', nameIndexLetter("\$uicideboy\$"))
        assertEquals('#', nameIndexLetter("21 Savage"))
        assertEquals('#', nameIndexLetter("!!!"))
    }
}
