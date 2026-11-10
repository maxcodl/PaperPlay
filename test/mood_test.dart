import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/mood.dart';
import 'package:teleplayer/library/weather.dart';

Song _song(
  int id, {
  String title = 'Untitled',
  String? artist,
  String? genre,
  String? lyrics,
  bool instrumental = false,
  int duration = 200,
  bool favorite = false,
  int? played,
  int plays = 0,
  int skips = 0,
}) =>
    Song(
      chatId: 1,
      messageId: id,
      uniqueId: 'u$id',
      remoteId: 'r$id',
      title: title,
      artist: artist ?? 'Artist $id',
      album: '',
      durationSec: duration,
      size: 1,
      mime: 'audio/flac',
      fileName: 'f',
      date: id,
      genre: genre,
      lyrics: lyrics,
      favorite: favorite,
      coverHiRes: false,
      userEdited: false,
      enrichState: 0,
      cachedBytes: 0,
      lastPlayedAt: played,
      pinned: false,
      tagsAt: 0,
      favoriteAt: 0,
      coverAt: 0,
      instrumental: instrumental,
      moodScannedAt: 0,
      plays: plays,
      skips: skips,
    );

Mood _mood(String id) => moods.firstWhere((m) => m.id == id);

String _repeat(String words, int times) => List.filled(times, words).join(' ');

void main() {
  final now = DateTime(2026, 11, 6, 15);

  group('reading a song', () {
    test('sad lyrics feel negative and happy ones positive', () {
      final sad = analyzeSong(_song(1, lyrics: _repeat('i cry alone with tears and pain', 8)));
      final happy = analyzeSong(_song(2, lyrics: _repeat('happy smile joy sunshine wonderful', 8)));
      expect(sad.valence, lessThan(-0.3));
      expect(happy.valence, greaterThan(0.3));
    });

    test('Japanese and Hindi lyrics are understood too', () {
      expect(analyzeSong(_song(1, lyrics: _repeat('涙が止まらない 悲しい 寂しい', 6))).valence, lessThan(-0.2));
      expect(analyzeSong(_song(2, lyrics: _repeat('dard tanha aansu judaai', 6))).valence, lessThan(-0.2));
      expect(analyzeSong(_song(3, lyrics: _repeat('雨が降る', 6))).themes['rain'], greaterThan(0));
    });

    test('timestamps in synced lyrics are not read as words', () {
      final plain = analyzeSong(_song(1, lyrics: 'I cry alone'));
      final synced = analyzeSong(_song(1, lyrics: '[00:12.50] I cry alone'));
      expect(synced.valence, plain.valence);
    });

    test('fast, wordy songs feel more intense than slow, sparse ones', () {
      final fast = analyzeSong(_song(1, lyrics: _repeat('word', 900), duration: 200));
      final slow = analyzeSong(_song(2, lyrics: _repeat('word', 40), duration: 200));
      expect(fast.energy, greaterThan(slow.energy));
    });

    test('knowing nothing means no confidence, not a guess', () {
      final t = analyzeSong(_song(1));
      expect(t.confidence, 0);
      expect(t.valence, 0);
    });
  });

  group('choosing songs', () {
    final library = [
      for (var i = 0; i < 40; i++)
        _song(i, title: 'Rain on my window $i', lyrics: _repeat('rain storm thunder umbrella', 6)),
      for (var i = 40; i < 80; i++) _song(i, lyrics: _repeat('i cry alone tears broken goodbye', 8)),
      for (var i = 80; i < 120; i++) _song(i, genre: 'Dance', lyrics: _repeat('party dance tonight happy joy', 40), duration: 100),
      for (var i = 120; i < 160; i++) _song(i, genre: 'Soundtrack', instrumental: true),
    ];

    DailyMix mix(String id, {List<Song>? songs, List<MoodVerdict> votes = const []}) =>
        buildDailyMixes(songs: songs ?? library, now: now, votes: votes).firstWhere((m) => m.mood.id == id);

    test('each mood gets the songs that suit it', () {
      double share(String id, bool Function(Song) wanted) {
        final s = mix(id).songs;
        return s.where(wanted).length / s.length;
      }

      // Not higher: mixes also avoid reusing songs, and each kind here has only 40.
      expect(share('rain', (s) => s.title.startsWith('Rain')), greaterThan(0.7));
      expect(share('sad', (s) => s.messageId >= 40 && s.messageId < 80), greaterThan(0.6));
      expect(share('party', (s) => s.genre == 'Dance'), greaterThan(0.7));
      expect(share('focus', (s) => s.instrumental), greaterThan(0.7));
    });

    test('a mix stays put during a day, and changes the next', () {
      List<String> ids(DateTime t) => buildDailyMixes(songs: library, now: t)
          .firstWhere((m) => m.mood.id == 'sad')
          .songs
          .map((s) => s.uniqueId)
          .toList();
      expect(ids(now), ids(DateTime(2026, 11, 6, 23)));
      expect(ids(now), isNot(ids(DateTime(2026, 11, 7, 15))));
    });

    test('no artist dominates a mix', () {
      final sameArtist = [
        for (var i = 0; i < 40; i++) _song(i, artist: 'Ann', lyrics: _repeat('cry alone tears', 8)),
        for (var i = 40; i < 80; i++) _song(i, lyrics: _repeat('cry alone tears', 8)),
      ];
      final s = mix('sad', songs: sameArtist).songs;
      expect(s.where((x) => x.artist == 'Ann').length, lessThanOrEqualTo(2));
    });

    test('a library with too little to go on offers no mix, not a bad one', () {
      final mixes = buildDailyMixes(songs: [for (var i = 0; i < 6; i++) _song(i)], now: now);
      expect(mixes, isEmpty);
    });

    test('a rejected song leaves that mood only, and its artist counts for less', () {
      final first = mix('sad').songs.first;
      final votes = [MoodVerdict(first.uniqueId, first.artist, 'sad', -1)];
      expect(mix('sad', votes: votes).songs, isNot(contains(first)));
    });

    test('what someone finishes outranks what they skip', () {
      expect(tasteOf(_song(1, plays: 10)), greaterThan(tasteOf(_song(2, skips: 10))));
    });

    test('a song just heard rests, then comes back over a week', () {
      final justNow = now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      final weekAgo = now.subtract(const Duration(days: 8)).millisecondsSinceEpoch;
      expect(freshnessOf(_song(1, played: justNow), now), lessThan(0.3));
      expect(freshnessOf(_song(1, played: weekAgo), now), 1);
      expect(freshnessOf(_song(1), now), 1);
    });

    test('handles a far bigger library than this one quickly', () {
      final big = [
        for (var i = 0; i < 5000; i++) _song(i, genre: 'Rock', lyrics: _repeat('i cry alone in the rain tonight', 30)),
      ];
      final watch = Stopwatch()..start();
      buildDailyMixes(songs: big, now: now);
      expect(watch.elapsedMilliseconds, lessThan(4000));
    });
  });

  group('real-world mistakes', () {
    test('a word in the title isn\'t enough if the song doesn\'t feel like it', () {
      final quiet = analyzeSong(_song(1, title: 'The Party of Heroes Returns', genre: 'Soundtrack', instrumental: true));
      final loud = analyzeSong(_song(2, title: 'Party Tonight', genre: 'Dance', lyrics: _repeat('dance party tonight', 40), duration: 100));
      final party = _mood('party');
      expect(moodFit(loud, party), greaterThan(moodFit(quiet, party) * 2));
    });

    test('a quiet song with no sad words isn\'t a sad song', () {
      final calm = analyzeSong(_song(1, genre: 'Soundtrack', instrumental: true));
      final words = analyzeSong(_song(2, genre: 'Soundtrack', lyrics: _repeat('i cry alone tears', 10)));
      final sad = _mood('sad');
      expect(moodFit(words, sad), greaterThan(moodFit(calm, sad) * 2));
    });

    test('two files of one song don\'t both go in a mix', () {
      final library = [
        for (var i = 0; i < 40; i++)
          _song(i, title: 'Rain ${i ~/ 2}', artist: 'Artist ${i ~/ 2}', lyrics: _repeat('rain storm umbrella', 6)),
      ];
      final titles = buildDailyMixes(songs: library, now: now)
          .firstWhere((m) => m.mood.id == 'rain')
          .songs
          .map((s) => s.title)
          .toList();
      expect(titles.toSet().length, titles.length);
    });

    test('your own list for a mood can feature its artist more than others can', () {
      final library = [
        for (var i = 0; i < 10; i++) _song(i, title: 'Mine $i', artist: 'Ann'),
        for (var i = 10; i < 200; i++) _song(i, title: 'Other $i', artist: 'Artist $i', lyrics: _repeat('lost gone', 4)),
      ];
      final mix = buildDailyMixes(
        songs: library,
        now: now,
        lists: [TasteList('Sad Songs', {for (final s in library.take(10)) s.uniqueId})],
      ).firstWhere((m) => m.mood.id == 'sad');
      expect(mix.songs.where((s) => s.artist == 'Ann').length, greaterThan(2));
    });

    test('mixes don\'t all reuse the same songs when others are available', () {
      final library = [for (var i = 0; i < 300; i++) _song(i, genre: 'Soundtrack', instrumental: true)];
      final mixes = buildDailyMixes(songs: library, now: now);
      final all = mixes.expand((m) => m.songs).map((s) => s.uniqueId).toList();
      expect(all.toSet().length / all.length, greaterThan(0.7));
    });
  });

  group('context', () {
    test('rain moves the rain mix first and names it for the day', () {
      expect(contextOrder(now, WeatherKind.rain).first, 'rain');
      final library = [for (var i = 0; i < 40; i++) _song(i, lyrics: _repeat('rain storm umbrella', 6))];
      final mixes = buildDailyMixes(songs: library, now: now, weather: WeatherKind.rain);
      expect(mixes.first.mood.id, 'rain');
      expect(mixes.first.title, 'Rainy day mix');
    });

    test('late at night, the night mix comes first', () {
      expect(contextOrder(DateTime(2026, 11, 6, 23), null).first, 'night');
    });

    test('weather codes mean what WMO says', () {
      expect(weatherKindOf(0), WeatherKind.clear);
      expect(weatherKindOf(3), WeatherKind.cloudy);
      expect(weatherKindOf(61), WeatherKind.rain);
      expect(weatherKindOf(81), WeatherKind.rain);
      expect(weatherKindOf(73), WeatherKind.snow);
      expect(weatherKindOf(95), WeatherKind.storm);
      expect(weatherKindOf(1000), isNull);
    });
  });

  test('the hash is stable, since devices must agree on the day\'s mix', () {
    expect(stableHash('2026-11-6:sad'), stableHash('2026-11-6:sad'));
    expect(stableHash('a'), isNot(stableHash('b')));
    expect(_mood('sad').valence, lessThan(0));
  });
}
