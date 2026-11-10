import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/sync/device_link.dart';
import 'package:teleplayer/sync/lan.dart';
import 'package:teleplayer/sync/library_sync.dart';

AppDb _db() => AppDb(NativeDatabase.memory());

SongsCompanion _song(int id, {String title = 't'}) => SongsCompanion.insert(
      chatId: 1,
      messageId: id,
      uniqueId: 'u$id',
      remoteId: 'r$id',
      title: title,
      artist: 'a',
      size: 1,
      mime: 'audio/mpeg',
      fileName: 'f',
      date: 0,
    );

Future<void> _exchange(AppDb a, AppDb b) async {
  await mergeSnapshot(b, await librarySnapshot(a));
  await mergeSnapshot(a, await librarySnapshot(b));
}

void main() {
  group('library merge', () {
    late AppDb a, b;
    setUp(() async {
      a = _db();
      b = _db();
      await a.into(a.songs).insert(_song(1));
      await b.into(b.songs).insert(_song(1));
    });
    tearDown(() async {
      await a.close();
      await b.close();
    });

    test('a favorite reaches the other device, and removing it does too', () async {
      final song = (await a.song(1, 1))!;
      await a.updateSong(song, const SongsCompanion(favorite: Value(true)));
      await _exchange(a, b);
      expect((await b.song(1, 1))!.favorite, true);

      await Future<void>.delayed(const Duration(milliseconds: 2));
      await b.updateSong((await b.song(1, 1))!, const SongsCompanion(favorite: Value(false)));
      await _exchange(a, b);
      expect((await a.song(1, 1))!.favorite, false);
    });

    test('a song deleted in Telegram by hand does not come back from a device that still lists it', () async {
      await a.postDeleted(1, 1);
      expect(await a.song(1, 1), isNull);
      await _exchange(a, b);
      expect(await a.song(1, 1), isNull, reason: 'it came back from the other device');
      expect(await b.song(1, 1), isNull, reason: 'the other device should forget it too');
    });

    test('a post deleted while another post of the song remains is not marked as deleted', () async {
      await a.into(a.postCopies).insert(PostCopiesCompanion.insert(
          chatId: 1, messageId: 99, uniqueId: 'u1', fileName: 'f', size: 1, date: 5));
      await a.postDeleted(1, 1);
      expect((await a.song(1, 99)), isNotNull, reason: 'the copy takes over');
      await _exchange(a, b);
      expect(await a.song(1, 99), isNotNull);
    });

    test('a person\'s tag edit beats a newer automatic match', () async {
      await a.updateSong(
        (await a.song(1, 1))!,
        const SongsCompanion(title: Value('edited'), userEdited: Value(true)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await b.updateSong((await b.song(1, 1))!, const SongsCompanion(title: Value('matched')));
      await _exchange(a, b);
      expect((await a.song(1, 1))!.title, 'edited');
      expect((await b.song(1, 1))!.title, 'edited');
    });

    test('a cover chosen on one device is asked for by the other, once', () async {
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(coverPath: Value('/a.jpg'), coverAt: Value(500)));
      final first = await mergeSnapshot(b, await librarySnapshot(a));
      expect(first.coversWanted.single.messageId, 1);
      expect((await b.song(1, 1))!.coverPath, isNull, reason: 'a path from another device means nothing here');

      await b.updateSong((await b.song(1, 1))!, const SongsCompanion(coverPath: Value('/b.jpg'), coverAt: Value(500)));
      expect((await mergeSnapshot(b, await librarySnapshot(a))).coversWanted, isEmpty);
    });

    test('the newer chosen cover wins, in either direction', () async {
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(coverAt: Value(900)));
      await b.updateSong((await b.song(1, 1))!, const SongsCompanion(coverAt: Value(100)));
      expect((await mergeSnapshot(a, await librarySnapshot(b))).coversWanted, isEmpty);
      expect((await mergeSnapshot(b, await librarySnapshot(a))).coversWanted, hasLength(1));
    });

    test('a chosen cover is part of a delta', () async {
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(coverAt: Value(5000)));
      final delta = await librarySnapshot(a, since: 4000);
      expect((delta['songs'] as List).single['coverAt'], 5000);
    });

    test('an album means the same album and lead artist, not just the same name', () async {
      SongsCompanion on(int id, String album, String artist) => SongsCompanion.insert(
            chatId: 1,
            messageId: id,
            uniqueId: 'a$id',
            remoteId: 'r$id',
            title: 't',
            artist: artist,
            album: Value(album),
            size: 1,
            mime: 'audio/mpeg',
            fileName: 'f',
            date: 0,
          );
      await a.into(a.songs).insert(on(10, 'Hits', 'Ann'));
      await a.into(a.songs).insert(on(11, 'Hits', 'Ann'));
      await a.into(a.songs).insert(on(12, 'Hits', 'Bob'));
      await a.into(a.songs).insert(on(13, 'Other', 'Ann'));
      final found = await a.albumOf((await a.song(1, 10))!, (x, y) => x.artist == y.artist);
      expect(found.map((s) => s.messageId).toSet(), {10, 11});
      expect(await a.albumOf((await a.song(1, 1))!, (x, y) => true), isEmpty, reason: 'no album');
    });

    test('a mood verdict reaches the other device, and undoing it does too', () async {
      await a.setMoodVote((await a.song(1, 1))!, 'sad', -1);
      await _exchange(a, b);
      expect((await b.select(b.moodVotes).getSingle()).vote, -1);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await b.setMoodVote((await b.song(1, 1))!, 'sad', 0);
      await _exchange(a, b);
      expect((await a.select(a.moodVotes).getSingle()).vote, 0);
    });

    test('lookups done on one device save the other repeating them', () async {
      await a.updateSong(
        (await a.song(1, 1))!,
        const SongsCompanion(moodScannedAt: Value(77), instrumental: Value(true)),
      );
      await _exchange(a, b);
      final row = (await b.song(1, 1))!;
      expect(row.moodScannedAt, 77);
      expect(row.instrumental, isTrue);
      expect(await b.nextForMoodScan(), isNull);
    });

    test('play counts take the higher value, so exchanges never inflate them', () async {
      final song = (await a.song(1, 1))!;
      await a.countPlay(song, finished: true);
      await a.countPlay(song, finished: true);
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(favorite: Value(true)));
      await _exchange(a, b);
      await _exchange(a, b);
      expect((await b.song(1, 1))!.plays, 2);
      expect((await a.song(1, 1))!.plays, 2);
    });

    test('the cache and pins stay per device', () async {
      await a.setCachedBytes('u1', 999);
      await a.updateSong(
        (await a.song(1, 1))!,
        const SongsCompanion(pinned: Value(true), favorite: Value(true)),
      );
      await _exchange(a, b);
      final row = (await b.song(1, 1))!;
      expect(row.favorite, true);
      expect(row.cachedBytes, 0);
      expect(row.pinned, false);
    });

    test('a deleted playlist and a removed song stay gone', () async {
      final id = await a.createPlaylist('Mix');
      await a.addToPlaylist(id, (await a.song(1, 1))!);
      await _exchange(a, b);
      final onB = (await b.livePlaylists()).single;
      expect((await b.watchPlaylistSongs(onB.id).first).length, 1);

      await Future<void>.delayed(const Duration(milliseconds: 2));
      await b.removeFromPlaylist(onB.id, (await b.song(1, 1))!);
      await _exchange(a, b);
      expect(await a.watchPlaylistSongs(id).first, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 2));
      await a.deletePlaylist(id);
      await _exchange(a, b);
      await _exchange(a, b);
      expect(await b.livePlaylists(), isEmpty);
      expect(await a.livePlaylists(), isEmpty);
    });

    test('one backup restored on two devices doesn\'t duplicate its playlists', () async {
      expect(legacyPlaylistUuid(3, 'Mix'), legacyPlaylistUuid(3, 'Mix'));
      for (final db in [a, b]) {
        await db.into(db.playlists).insert(
              PlaylistsCompanion.insert(name: 'Mix', uuid: Value(legacyPlaylistUuid(3, 'Mix'))),
            );
      }
      await _exchange(a, b);
      expect((await a.livePlaylists()).length, 1);
      expect((await b.livePlaylists()).length, 1);
    });

    test('agreeing devices write nothing, so exchanges stop', () async {
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(favorite: Value(true)));
      final id = await a.createPlaylist('Mix');
      await a.addToPlaylist(id, (await a.song(1, 1))!);
      await _exchange(a, b);
      expect((await mergeSnapshot(b, await librarySnapshot(a))).changed, false);
      expect((await mergeSnapshot(a, await librarySnapshot(b))).changed, false);
    });

    test('a channel added on one device is reported to the other', () async {
      await a.into(a.libraryChats).insert(LibraryChatsCompanion.insert(id: const Value(-1005), title: 'Music'));
      final r = await mergeSnapshot(b, await librarySnapshot(a));
      expect(r.newChats.single.id, -1005);
    });

    test('a delta also holds songs added since, without sending the whole library', () async {
      await a.into(a.songs).insert(_song(2));
      final top = (await a.customSelect('SELECT MAX(rowid) AS m FROM songs').getSingle()).read<int>('m');
      await a.into(a.songs).insert(_song(3));
      final delta = await librarySnapshot(a, since: DateTime.now().millisecondsSinceEpoch + 10000, afterRowId: top);
      expect((delta['songs'] as List).map((s) => s['messageId']), [3]);
    });

    test('a delta holds only later changes', () async {
      await a.into(a.songs).insert(_song(2));
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(favorite: Value(true)));
      final since = (await a.song(1, 1))!.favoriteAt;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await a.updateSong((await a.song(1, 2))!, const SongsCompanion(favorite: Value(true)));
      final delta = await librarySnapshot(a, since: since);
      expect((delta['songs'] as List).map((s) => s['messageId']), [2]);
    });
  });

  group('LAN connection', () {
    Future<(LanHub, LanHub)> pair(String tokenA, String tokenB) async {
      final a = LanHub(secret: tokenA, deviceId: 'device-a', deviceName: 'A', discoveryPort: 47990, listenPort: 0);
      final b = LanHub(secret: tokenB, deviceId: 'device-b', deviceName: 'B', discoveryPort: 47991, listenPort: 0);
      await a.start();
      await b.start();
      addTearDown(a.stop);
      addTearDown(b.stop);
      return (a, b);
    }

    Future<void> until(bool Function() ok) async {
      for (var i = 0; i < 200 && !ok(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }

    test('devices with one token connect and exchange messages both ways', () async {
      final (a, b) = await pair('123:token', '123:token');
      final atB = <Map<String, dynamic>>[], atA = <Map<String, dynamic>>[];
      b.onMessage = (_, m) => atB.add(m);
      a.onMessage = (_, m) => atA.add(m);
      await a.connect('127.0.0.1', b.port!);
      await until(() => a.peers.value.isNotEmpty && b.peers.value.isNotEmpty);
      expect(a.peers.value.single.name, 'B');
      expect(b.peers.value.single.name, 'A');

      final big = 'x' * 200000;
      a.broadcast({'t': 'one'});
      a.broadcast({'t': 'two', 'big': big});
      b.broadcast({'t': 'three'});
      await until(() => atB.length == 2 && atA.length == 1);
      expect(atB.map((m) => m['t']), ['one', 'two']);
      expect(atB[1]['big'], big);
      expect(atA.single['t'], 'three');
    });

    test('a device learns the other\'s listening port, not the connection\'s', () async {
      final (a, b) = await pair('t', 't');
      await a.connect('127.0.0.1', b.port!);
      await until(() => b.peers.value.isNotEmpty && a.peers.value.isNotEmpty);
      expect(a.peers.value.single.port, b.port);
      expect(b.peers.value.single.port, a.port);
      expect(b.peers.value.single.host, '127.0.0.1');
    });

    test('nothing is reachable at a closed port, and it says so', () async {
      final (a, _) = await pair('t', 't');
      expect(
        await a.connect('127.0.0.1', 1, timeout: const Duration(seconds: 1)),
        ConnectFailure.unreachable,
      );
    });

    test('with pairing required, a device waits until the right PIN is entered', () async {
      final (a, b) = await pair('t', 't');
      a.requirePairing = true;
      await b.connect('127.0.0.1', a.port!);
      await until(() => a.pending.value.isNotEmpty && b.pending.value.isNotEmpty);
      expect(a.peers.value, isEmpty);
      expect(b.peers.value, isEmpty);

      final w = a.openPairing();
      final wrong = w.pin == '000000' ? '111111' : '000000';
      expect(await b.pairWith(b.pending.value.single, wrong), isFalse);
      expect(b.peers.value, isEmpty);
      expect(await b.pairWith(b.pending.value.single, w.pin), isTrue);
      await until(() => a.peers.value.isNotEmpty && b.peers.value.isNotEmpty);
      expect(a.trusted.value.keys, ['device-b']);
      expect(b.trusted.value.keys, ['device-a']);
      expect(a.window.value, isNull);

      // Trusted now: a fresh connection links without a PIN.
      a.revoke('device-b');
      await until(() => a.peers.value.isEmpty);
      await b.connect('127.0.0.1', a.port!);
      await until(() => a.pending.value.isNotEmpty);
      expect(a.peers.value, isEmpty);
    });

    test('five wrong PINs close the pairing window', () async {
      final (a, b) = await pair('t', 't');
      a.requirePairing = true;
      await b.connect('127.0.0.1', a.port!);
      await until(() => b.pending.value.isNotEmpty);
      final w = a.openPairing();
      final wrong = w.pin == '000000' ? '111111' : '000000';
      for (var i = 0; i < 5; i++) {
        await b.pairWith(b.pending.value.single, wrong);
      }
      expect(a.window.value, isNull);
      expect(await b.pairWith(b.pending.value.single, w.pin), isFalse);
    });

    test('a device with another token is refused', () async {
      final (a, b) = await pair('123:token', '456:other');
      expect(await a.connect('127.0.0.1', b.port!), ConnectFailure.refused);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(a.peers.value, isEmpty);
      expect(b.peers.value, isEmpty);
    });

    test('a peer that leaves is removed', () async {
      final (a, b) = await pair('t', 't');
      final gone = Completer<void>();
      a.onDisconnected = (_) => gone.complete();
      await a.connect('127.0.0.1', b.port!);
      await until(() => a.peers.value.isNotEmpty);
      await b.stop();
      await gone.future.timeout(const Duration(seconds: 5));
      expect(a.peers.value, isEmpty);
    });

    test('connecting twice keeps one connection, on both ends', () async {
      final (a, b) = await pair('t', 't');
      await Future.wait([
        a.connect('127.0.0.1', b.port!),
        b.connect('127.0.0.1', a.port!),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(a.peers.value.length, 1);
      expect(b.peers.value.length, 1);
      final got = <String>[];
      b.onMessage = (_, m) => got.add(m['t'] as String);
      a.broadcast({'t': 'still works'});
      await until(() => got.isNotEmpty);
      expect(got, ['still works']);
    });
  });

  group('saved addresses', () {
    test('reads an address with or without a port, and refuses nonsense', () {
      expect(parseAddress('192.168.1.5')?.key, '192.168.1.5:$lanPort');
      expect(parseAddress(' 192.168.1.5:9000 ')?.key, '192.168.1.5:9000');
      expect(parseAddress('home-pc.local')?.host, 'home-pc.local');
      expect(parseAddress('192.168.1.5', label: ' PC ')?.label, 'PC');
      expect(parseAddress('192.168.1.5', label: '  ')?.label, isNull);
      for (final bad in ['', 'http://x', '1.2.3.4:99999', '1.2.3.4:abc', 'a b']) {
        expect(parseAddress(bad), isNull, reason: bad);
      }
    });

    test('a device keeps only its newest address', () {
      SavedAddress at(int i) => SavedAddress(host: '10.0.0.$i', deviceId: 'phone');
      var list = <SavedAddress>[const SavedAddress(host: '10.9.9.9', label: 'Manual')];
      for (var i = 1; i <= 7; i++) {
        list = rememberAddress(list, at(i));
      }
      expect(list.first.host, '10.0.0.7');
      expect(list.where((a) => a.deviceId == 'phone').length, 1);
      expect(list.any((a) => a.label == 'Manual'), isTrue, reason: 'a typed address is never dropped');
    });

    test('addresses saved by older versions collapse to one per device', () {
      final list = onePerDevice(const [
        SavedAddress(host: '192.168.1.3', label: 'Dell', deviceId: 'dell'),
        SavedAddress(host: '192.168.1.51', label: 'Dell', deviceId: 'dell'),
        SavedAddress(host: '10.9.9.9', label: 'Manual'),
      ]);
      expect(list.map((a) => a.host), ['192.168.1.3', '10.9.9.9']);
    });
  });
}
