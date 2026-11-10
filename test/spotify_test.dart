import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/playlist_import.dart';
import 'package:teleplayer/library/spotify_account.dart';
import 'package:teleplayer/metadata/enricher.dart';

const _link = 'https://open.spotify.com/playlist/5Zvz5JZqysHQsDN9w97bkk';

String _page(int count) => '<script id="__NEXT_DATA__" type="application/json">${jsonEncode({
      'entity': {
        'name': 'List',
        'trackList': [
          for (var i = 0; i < count; i++) {'uri': 'spotify:track:$i', 'title': 'T$i', 'subtitle': 'A', 'duration': 200000},
        ],
      },
    })}</script>';

void main() {
  test('the PKCE challenge matches the standard\'s own example', () async {
    expect(
      await pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('reads Spotify\'s playlist items, in the current and the older shape', () {
    final tracks = parseSpotifyItems([
      {
        'item': {
          'uri': 'spotify:track:a',
          'name': 'Back In Black',
          'duration_ms': 255000,
          'artists': [
            {'name': 'AC/DC'},
            {'name': 'Guest'},
          ],
        },
      },
      {
        'track': {'uri': 'spotify:track:b', 'name': 'Old', 'duration_ms': 1000, 'artists': []},
      },
      {'item': null},
      {
        'item': {'uri': 'spotify:episode:c', 'name': 'A podcast'},
      },
      {
        'item': {'uri': 'spotify:local:d', 'name': 'A local file'},
      },
    ]);
    expect(tracks.map((t) => t.key), ['spotify:track:a', 'spotify:track:b']);
    expect(tracks.first.artist, 'AC/DC, Guest');
    expect(tracks.first.durationSec, 255);
  });

  group('importing', () {
    late AppDb db;
    setUp(() => db = AppDb(NativeDatabase.memory()));
    tearDown(() => db.close());

    http.Client serving(String html) => MockClient((_) async => http.Response.bytes(utf8.encode(html), 200));

    test('uses the whole list when the login can read it', () async {
      final r = await importPlaylist(
        db,
        _link,
        serving(_page(100)),
        official: (_) async => (
          name: 'Full',
          tracks: [for (var i = 0; i < 572; i++) ImportedTrack('spotify:track:$i', 'T$i', 'A', 200)],
        ),
      );
      expect(r.name, 'Full');
      expect(r.missing, 572);
      expect(r.limited, isFalse);
    });

    test('a list at the public page\'s limit says it may be cut short', () async {
      final r = await importPlaylist(db, _link, serving(_page(100)));
      expect(r.limited, isTrue);
    });

    test('a shorter public list is known to be complete', () async {
      final r = await importPlaylist(db, _link, serving(_page(57)));
      expect(r.limited, isFalse);
    });

    test('when the login can\'t read it, the public page is the fallback', () async {
      final r = await importPlaylist(db, _link, serving(_page(57)), official: (_) async => null);
      expect(r.missing, 57);
    });
  });

  test('a typed search can\'t break MusicBrainz\'s query syntax', () {
    expect(musicBrainzQuery('Love: (feat. X) [Live]!'), 'Love feat X Live');
    expect(musicBrainzQuery('  AC/DC  '), 'AC DC');
    expect(musicBrainzQuery('"quoted"'), 'quoted');
  });
}
