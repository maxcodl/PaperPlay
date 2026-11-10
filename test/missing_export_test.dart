import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/missing_export.dart';

MissingTrack _track(String key, String title, String artist, int seconds) =>
    MissingTrack(playlistId: 1, trackKey: key, title: title, artist: artist, durationSec: seconds, position: 0);

void main() {
  test('Spotify links come straight from the track id', () {
    expect(spotifyLinkOf('spotify:track:abc123'), 'https://open.spotify.com/track/abc123');
    expect(spotifyLinkOf('something-else'), isNull);
    expect(spotifyLinkOf('spotify:track:'), isNull);
  });

  test('an Apple Music link needs the same title, the artist and a length within 5 seconds', () async {
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      return http.Response(
        jsonEncode({
          'results': [
            {'trackName': 'Numb', 'artistName': 'Someone Else', 'trackTimeMillis': 185000, 'trackViewUrl': 'https://music.apple.com/wrong'},
            {'trackName': 'Numb', 'artistName': 'Linkin Park', 'trackTimeMillis': 187000, 'trackViewUrl': 'https://music.apple.com/right'},
            {'trackName': 'Numb', 'artistName': 'Linkin Park', 'trackTimeMillis': 300000, 'trackViewUrl': 'https://music.apple.com/long'},
          ],
        }),
        200,
      );
    });
    final url = await appleLinkFor(client, title: 'Numb', artist: 'Linkin Park', durationSec: 186, pause: Duration.zero);
    expect(url, 'https://music.apple.com/right');
    expect(seen.length, 1, reason: 'the second storefront is only asked when the first has nothing');
  });

  test('nothing fitting asks the India catalogue too, then gives up', () async {
    final countries = <String?>[];
    final client = MockClient((request) async {
      countries.add(request.url.queryParameters['country']);
      return http.Response(jsonEncode({'results': []}), 200);
    });
    expect(await appleLinkFor(client, title: 'Unknown', artist: 'Nobody', durationSec: 100, pause: Duration.zero), isNull);
    expect(countries, [null, 'IN']);
  });

  test('a list keeps going when Apple is unreachable, stops when told, and tells how far it is', () async {
    final client = MockClient((request) async => throw http.ClientException('offline'));
    final tracks = [for (var i = 0; i < 5; i++) _track('spotify:track:t$i', 'Song $i', 'A', 100)];
    final progress = <int>[];
    var stop = false;
    final list = await buildExportList(
      tracks,
      'test',
      client: client,
      pause: Duration.zero,
      onProgress: (done, total) {
        progress.add(done);
        if (done == 3) stop = true;
      },
      cancelled: () => stop,
    );
    expect(list.rows.length, 3, reason: 'stopped after three, keeping them');
    expect(progress, [1, 2, 3]);
    expect(list.rows.first.spotifyUrl, 'https://open.spotify.com/track/t0');
    expect(list.rows.first.appleUrl, isNull);
  });

  test('csv and link exports, and lists survive being saved and deleted', () async {
    const list = ExportList(id: 'a', name: 'n', createdAt: 1, rows: [
      ExportRow(title: 'He said "hi"', artist: 'A, B', durationSec: 10, spotifyUrl: 's1', appleUrl: 'a1'),
      ExportRow(title: 'T2', artist: 'C', durationSec: 20, spotifyUrl: 's2'),
    ]);
    expect(exportCsv(list).split('\n')[1], '"He said ""hi""","A, B",10,"s1","a1"');
    expect(exportLinks(list), 's1\na1\ns2');
    expect(exportLinks(list, spotify: false), 'a1');

    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await saveExportLists(db, [list]);
    final back = await loadExportLists(db);
    expect(back.single.rows.length, 2);
    expect(back.single.withApple, 1);
    await deleteExportList(db, 'a');
    expect(await loadExportLists(db), isEmpty);
    // Temporary lists are not carried by a backup.
    expect(AppDb.devicePrefs, contains('export_lists'));
    await db.setPref('export_lists', 'not json');
    expect(await loadExportLists(db), isEmpty);
  });
}
