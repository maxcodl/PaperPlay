import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/audio_info.dart';
import 'package:teleplayer/library/scanner.dart';
import 'package:teleplayer/library/throttle.dart';
import 'package:teleplayer/metadata/enricher.dart';
import 'package:teleplayer/playback/cache.dart';
import 'package:teleplayer/telegram/channels.dart';
import 'package:teleplayer/telegram/td_client.dart';

void main() {
  group('parseApiKeys', () {
    final hash = 'a1' * 16;
    test('accepts valid keys and trims pasted whitespace', () {
      final r = parseApiKeys(' 12345 ', ' $hash\n');
      expect(r?.id, 12345);
      expect(r?.hash, hash);
    });
    test('rejects bad id', () {
      expect(parseApiKeys('abc', hash), isNull);
      expect(parseApiKeys('0', hash), isNull);
    });
    test('rejects bad hash', () {
      expect(parseApiKeys('12345', 'short'), isNull);
      expect(parseApiKeys('12345', 'z' * 32), isNull);
    });
  });

  group('parseFileName', () {
    test('artist and title', () {
      final r = parseFileName('Daft Punk - One More Time.mp3');
      expect(r.artist, 'Daft Punk');
      expect(r.title, 'One More Time');
    });
    test('strips track number and underscores', () {
      final r = parseFileName('07. Some_Artist - A_Song.flac');
      expect(r.artist, 'Some Artist');
      expect(r.title, 'A Song');
    });
    test('title only', () {
      final r = parseFileName('Untitled.m4a');
      expect(r.artist, '');
      expect(r.title, 'Untitled');
    });
  });

  group('audioPayload', () {
    Map<String, dynamic> doc(String name, String mime) => {
          'content': {
            '@type': 'messageDocument',
            'document': {'file_name': name, 'mime_type': mime},
          },
        };
    test('accepts FLAC sent as generic document', () {
      expect(audioPayload(doc('a.flac', 'application/octet-stream')), isNotNull);
    });
    test('rejects non-audio document', () {
      expect(audioPayload(doc('a.pdf', 'application/pdf')), isNull);
    });
  });

  group('selectEvictions', () {
    test('evicts oldest first and stops under limit', () {
      final r = selectEvictions(
        const [
          CacheEntry('new', 40, 300),
          CacheEntry('old', 40, 100),
          CacheEntry('mid', 40, 200),
        ],
        80,
        <String>{},
      );
      expect(r, ['old']);
    });
    test('never played goes first', () {
      final r = selectEvictions(
        const [CacheEntry('played', 50, 100), CacheEntry('never', 50, null)],
        50,
        <String>{},
      );
      expect(r, ['never']);
    });
    test('pinned never evicted and not counted against limit', () {
      final r = selectEvictions(
        const [CacheEntry('pin', 500, 1, pinned: true), CacheEntry('a', 10, 2)],
        50,
        <String>{},
      );
      expect(r, isEmpty);
    });
    test('protected skipped, next oldest evicted instead', () {
      final r = selectEvictions(
        const [CacheEntry('current', 50, 1), CacheEntry('a', 50, 2)],
        50,
        {'current'},
      );
      expect(r, ['a']);
    });
    test('limit zero with only protected left evicts nothing', () {
      final r = selectEvictions(const [CacheEntry('current', 50, 1)], 0, {'current'});
      expect(r, isEmpty);
    });
  });

  group('pickMatch', () {
    MbMatch m(int score, int? length) => MbMatch(
          score: score,
          title: 't',
          artist: 'a',
          album: '',
          releaseId: null,
          lengthSec: length,
        );
    test('accepts high score within 5s', () {
      expect(pickMatch([m(95, 205)], 200), isNotNull);
    });
    test('rejects low score', () {
      expect(pickMatch([m(89, 200)], 200), isNull);
    });
    test('rejects length mismatch, takes later valid one', () {
      final good = m(90, 199);
      expect(pickMatch([m(100, 300), good], 200), same(good));
    });
    test('rejects when duration unknown', () {
      expect(pickMatch([m(100, 200)], 0), isNull);
    });
  });

  group('throttled', () {
    test('passes the first event, drops middle ones, ends on the latest', () async {
      final source = StreamController<int>();
      final seen = <int>[];
      final sub = throttled(source.stream, const Duration(milliseconds: 50)).listen(seen.add);
      source
        ..add(1)
        ..add(2)
        ..add(3);
      await Future<void>.delayed(Duration.zero);
      expect(seen, [1], reason: 'the gap has not passed yet');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(seen, [1, 3], reason: '2 was replaced by a newer value');
      await sub.cancel();
      await source.close();
    });
  });

  test('lossless formats', () {
    expect(isLossless('FLAC'), isTrue);
    expect(isLossless('MP3'), isFalse);
  });

  group('audio info', () {
    test('format from extension, else MIME type', () {
      expect(audioFormat('application/octet-stream', 'Song.flac'), 'FLAC');
      expect(audioFormat('audio/mpeg', ''), 'MP3');
      expect(audioFormat('audio/x-unknown', 'no extension'), 'Audio');
    });
    test('average bitrate', () {
      expect(averageKbps(1000000, 8), 1000);
      expect(averageKbps(1000000, 0), isNull);
    });
  });

  group('pickExternal', () {
    ExternalMatch m(String title, String artist, int length) => ExternalMatch(
          source: 'iTunes',
          title: title,
          artist: artist,
          album: 'A',
          lengthSec: length,
        );
    test('matches despite credits and joint artists', () {
      final hit = m('São Paulo', 'The Weeknd & Anitta', 301);
      expect(pickExternal([hit], 'São Paulo (feat. Anitta)', 'The Weeknd', 303), same(hit));
    });
    test('rejects a different song, artist or length', () {
      expect(pickExternal([m('Other', 'The Weeknd', 300)], 'Song', 'The Weeknd', 300), isNull);
      expect(pickExternal([m('Song', 'Someone', 300)], 'Song', 'The Weeknd', 300), isNull);
      expect(pickExternal([m('Song', 'The Weeknd', 400)], 'Song', 'The Weeknd', 300), isNull);
    });
    test('without a length, matches on title and a known artist', () {
      final hit = m('Blinding Lights', 'The Weeknd', 200);
      expect(pickExternal([hit], 'Blinding Lights', 'The Weeknd', 0), same(hit));
      expect(pickExternal([m('Other', 'The Weeknd', 200)], 'Blinding Lights', 'The Weeknd', 0), isNull);
      expect(pickExternal([hit], 'Blinding Lights', 'Unknown artist', 0), isNull);
    });
    test('reads iTunes fields and asks for larger art', () {
      final r = ExternalMatch.fromItunes({
        'trackName': 'T',
        'artistName': 'A',
        'collectionName': 'C',
        'trackTimeMillis': 301623,
        'artworkUrl100': 'https://x/100x100bb.jpg',
        'primaryGenreName': 'Pop',
        'releaseDate': '2024-10-30T07:00:00Z',
      });
      expect([r.lengthSec, r.year, r.genre, r.coverUrl], [301, 2024, 'Pop', 'https://x/600x600bb.jpg']);
    });
    test('reads Deezer fields', () {
      final r = ExternalMatch.fromDeezer({
        'title': 'T',
        'duration': 200,
        'artist': {'name': 'A'},
        'album': {'title': 'C', 'cover_xl': 'https://x/c.jpg'},
      });
      expect([r.artist, r.album, r.lengthSec, r.coverUrl], ['A', 'C', 200, 'https://x/c.jpg']);
    });
  });

  group('parseChannelRef', () {
    test('channel ids, with or without the -100 prefix', () {
      expect(parseChannelRef('-1001234567890')?.chatId, -1001234567890);
      expect(parseChannelRef(' 1234567890 ')?.chatId, -1001234567890);
    });
    test('private post link gives the channel and where it ends', () {
      final r = parseChannelRef('https://t.me/c/1234567890/5678');
      expect(r?.chatId, -1001234567890);
      expect(r?.endMessage, 5678);
    });
    test('private link inside a topic uses the last number', () {
      final r = parseChannelRef('https://t.me/c/1234567890/12/5678');
      expect(r?.chatId, -1001234567890);
      expect(r?.endMessage, 5678);
    });
    test('private link with no post still gives the channel', () {
      final r = parseChannelRef('t.me/c/1234567890');
      expect(r?.chatId, -1001234567890);
      expect(r?.endMessage, isNull);
    });
    test('public names and links', () {
      expect(parseChannelRef('@mymusic')?.username, 'mymusic');
      expect(parseChannelRef('t.me/mymusic')?.username, 'mymusic');
      final r = parseChannelRef('https://t.me/mymusic/42');
      expect(r?.username, 'mymusic');
      expect(r?.endMessage, 42);
    });
    test('rubbish is rejected', () {
      expect(parseChannelRef('hello there'), isNull);
      expect(parseChannelRef(''), isNull);
      expect(parseChannelRef('-4123456'), isNull);
    });
  });

  group('bot helpers', () {
    test('token format', () {
      final token = '123456:${'a' * 35}';
      expect(parseBotToken(' $token\n'), token);
      expect(parseBotToken('123456'), isNull);
      expect(parseBotToken('abc:${'a' * 35}'), isNull);
    });
    test('supergroup id only for channels and supergroups', () {
      expect(supergroupIdOf(-1001234567890), 1234567890);
      expect(supergroupIdOf(-4123456), isNull);
      expect(supergroupIdOf(123456), isNull);
    });
    test('read progress is real only when the total is known', () {
      final end = 1000 * messageIdStep;
      expect(walkShare(100 * messageIdStep, end, full: true), 0.1);
      expect(walkShare(end, end, full: true), 1);
      expect(walkShare(end + messageIdStep, end, full: true), isNull, reason: 'past known end');
      expect(walkShare(100 * messageIdStep, end, full: false), isNull, reason: 'partial read');
      expect(walkShare(messageIdStep, 0, full: true), isNull, reason: 'nothing known yet');
    });
    test('walks forward by server message ids', () {
      expect(idsFrom(messageIdStep, 3), [messageIdStep, 2 * messageIdStep, 3 * messageIdStep]);
    });
  });

  test('activity counts network requests and ignores local lookups', () {
    final a = TdActivity()
      ..record('getMessages')
      ..record('downloadFile')
      ..record('getMessage')
      ..recordRateLimit();
    expect([a.reads, a.downloads, a.uploads, a.rateLimits], [1, 1, 0, 1]);
  });

  group('title cleanup', () {
    test('strips track prefix, quality tag and repeated artist', () {
      expect(cleanTitle('1|1 - Sapphire - Ed Sheeran (FLAC)', 'Ed Sheeran'), 'Sapphire');
      expect(cleanTitle('1|1 - Die With A Smile - Lady Gaga and Bruno Mars', 'Lady Gaga'),
          'Die With A Smile');
      expect(cleanTitle('Daft Punk - One More Time', 'Daft Punk'), 'One More Time');
    });
    test('keeps ordinary titles, including ones with a dash', () {
      expect(cleanTitle('Pal Pal', 'Afusic'), 'Pal Pal');
      expect(cleanTitle('Song - Live Version', 'Someone'), 'Song - Live Version');
    });
    test('never returns empty', () {
      expect(cleanTitle('(FLAC)', 'A'), '(FLAC)');
      expect(searchTitle('(Explicit)'), '(Explicit)');
    });
    test('search title drops credits but keeps remix', () {
      expect(searchTitle('São Paulo (feat. Anitta)'), 'São Paulo');
      expect(searchTitle('End of Line (From "TRON: Legacy")'), 'End of Line');
      expect(searchTitle('Jhol [Explicit]'), 'Jhol');
      expect(searchTitle('Song (Tiesto Remix)'), 'Song (Tiesto Remix)');
    });
    test('first artist of a list', () {
      expect(firstArtist('Post Malone, Ozzy Osbourne, Travis Scott'), 'Post Malone');
      expect(firstArtist('Maanu & Annural Khalid'), 'Maanu');
      expect(firstArtist('The Weeknd'), 'The Weeknd');
    });
  });

  test('busy delay grows and caps at a minute', () {
    expect([1, 2, 3, 4, 5, 6].map((a) => busyDelay(a).inSeconds), [4, 8, 16, 32, 60, 60]);
  });

  group('parseLrc', () {
    test('parses and sorts, including repeated stamps', () {
      final r = parseLrc('[00:10.50]b\n[00:01.00][00:20.00]a\nno stamp');
      expect(r.map((l) => l.text), ['a', 'b', 'a']);
      expect(r[1].time, const Duration(seconds: 10, milliseconds: 500));
    });
    test('plain lyrics yield no lines', () {
      expect(parseLrc('just\nwords'), isEmpty);
    });
  });
}
