import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:teleplayer/library/backup.dart';
import 'package:teleplayer/library/db.dart';

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('teleplayer_backup'));
  tearDown(() => temp.delete(recursive: true));

  test('restoring keeps this device\'s id and addresses, not the backup\'s', () async {
    final source = AppDb(NativeDatabase.memory());
    addTearDown(source.close);
    await source.setPref('device_id', 'phone');
    await source.setPref('lan_addresses', '[]');
    await source.setPref('cache_limit', '5');
    await source.setPref('theme_accent', 'rose');
    await source.setPref('theme_amoled', 'false');
    final zip = await createBackup(source, temp);

    final target = AppDb(NativeDatabase.memory());
    addTearDown(target.close);
    await target.setPref('device_id', 'pc');
    await target.setPref('theme_accent', 'mint');
    await restoreBackup(target, zip.path, Directory(p.join(temp.path, 'covers')));
    expect(await target.pref('device_id'), 'pc');
    expect(await target.pref('lan_addresses'), isNull);
    expect(await target.pref('theme_accent'), 'mint', reason: 'themes stay per device');
    expect(await target.pref('theme_amoled'), isNull);
    expect(await target.pref('cache_limit'), '5', reason: 'ordinary settings still restore');
  });

  test('a backup from before device sync still restores, ready to sync', () async {
    final manifest = jsonEncode({
      'version': 1,
      'chats': [
        {'id': 1, 'title': 'C', 'lastScannedMessageId': null, 'useBot': false, 'walkDone': true},
      ],
      'songs': [
        {
          'chatId': 1, 'messageId': 2, 'uniqueId': 'u', 'remoteId': 'r', 'title': 'T', 'artist': 'A',
          'album': '', 'durationSec': 9, 'size': 1, 'mime': 'audio/mpeg', 'fileName': 'f', 'date': 0,
          'favorite': true, 'coverHiRes': false, 'userEdited': false, 'enrichState': 1, 'cachedBytes': 0,
          'pinned': false,
        },
      ],
      'playlists': [
        {'id': 3, 'name': 'Mix'},
      ],
      'playlistSongs': [
        {'playlistId': 3, 'chatId': 1, 'messageId': 2, 'addedAt': 5},
      ],
      'prefs': [],
    });
    final zipPath = p.join(temp.path, 'old.zip');
    final archive = Archive()..addFile(ArchiveFile.bytes('library.json', utf8.encode(manifest)));
    await File(zipPath).writeAsBytes(ZipEncoder().encode(archive));

    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await restoreBackup(db, zipPath, Directory(p.join(temp.path, 'covers')));

    final song = (await db.song(1, 2))!;
    expect(song.favorite, isTrue);
    expect(song.favoriteAt, 1, reason: 'so it reaches a device that has no favorites');
    expect(song.tagsAt, 1);
    final list = (await db.livePlaylists()).single;
    expect(list.uuid, legacyPlaylistUuid(3, 'Mix'));
    expect((await db.watchPlaylistSongs(list.id).first).single.messageId, 2);
  });

  SongsCompanion song(int id, {String? cover}) => SongsCompanion.insert(
        chatId: 1,
        messageId: id,
        uniqueId: 'u$id',
        remoteId: 'r$id',
        title: 'Song $id',
        artist: 'Artist',
        size: 100,
        mime: 'audio/mpeg',
        fileName: 'f.mp3',
        date: 0,
        coverPath: Value(cover),
        favorite: const Value(true),
        cachedBytes: const Value(100),
        enrichState: const Value(EnrichState.done),
      );

  Future<AppDb> sourceLibrary() async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final cover = File(p.join(temp.path, 'old_install_cover.jpg'))..writeAsBytesSync([1, 2, 3]);
    await db.into(db.libraryChats).insert(LibraryChatsCompanion.insert(
          id: const Value(1),
          title: 'Channel',
          lastScannedMessageId: const Value(9),
          walkDone: const Value(true),
        ));
    await db.into(db.songs).insert(song(1, cover: cover.path));
    await db.into(db.songs).insert(song(2));
    final list = await db.into(db.playlists).insert(PlaylistsCompanion.insert(name: 'Mix'));
    await db.addToPlaylist(list, (await db.song(1, 1))!);
    await db.setCacheLimit(123);
    return db;
  }

  test('a backup restores songs, covers, playlists and settings into a new install', () async {
    final source = await sourceLibrary();
    final zip = await createBackup(source, temp);

    final target = AppDb(NativeDatabase.memory());
    addTearDown(target.close);
    final covers = Directory(p.join(temp.path, 'new_install', 'covers'));
    final result = await restoreBackup(target, zip.path, covers);

    expect(result.songs, 2);
    expect(result.sealedCredentials, isNull);
    final restored = (await target.song(1, 1))!;
    expect(restored.title, 'Song 1');
    expect(restored.favorite, isTrue);
    expect(restored.enrichState, EnrichState.done);
    expect(restored.coverPath, p.join(covers.path, 'old_install_cover.jpg'), reason: 'path moves');
    expect(File(restored.coverPath!).readAsBytesSync(), [1, 2, 3]);
    expect(restored.cachedBytes, 0, reason: 'the music itself is not in a backup');
    expect((await target.song(1, 2))!.coverPath, isNull);

    final chat = await target.select(target.libraryChats).getSingle();
    expect(chat.walkDone, isTrue, reason: 'no need to read the channel again');
    expect(chat.lastScannedMessageId, 9);
    expect((await target.select(target.playlists).getSingle()).name, 'Mix');
    expect(await target.select(target.playlistSongs).get(), hasLength(1));
    expect(await target.cacheLimit(), 123);
  });

  group('credentials', () {
    const token = '123456:SECRET-BOT-TOKEN-VALUE-abcdefghijkl';
    const hash = '0123456789abcdef0123456789abcdef';
    const creds = Credentials(apiId: 4242, apiHash: hash, botToken: token);

    test('come back with the right password', () async {
      final opened = await openCredentials(await sealCredentials(creds, 'correct horse'), 'correct horse');
      expect([opened.apiId, opened.apiHash, opened.botToken], [4242, hash, token]);
    });

    test('are refused with the wrong password', () async {
      final sealed = await sealCredentials(creds, 'correct horse');
      await expectLater(openCredentials(sealed, 'wrong horse'), throwsA(isA<WrongPassword>()));
    });

    test('travel through a backup, and never appear in the file as plain text', () async {
      final source = await sourceLibrary();
      final sealed = await sealCredentials(creds, 'correct horse');
      final zip = await createBackup(source, temp, sealedCredentials: sealed);

      final raw = String.fromCharCodes(zip.readAsBytesSync());
      expect(raw.contains(token), isFalse);
      expect(raw.contains(hash), isFalse);
      final input = InputFileStream(zip.path);
      final archive = ZipDecoder().decodeStream(input);
      for (final f in archive) {
        final text = String.fromCharCodes(f.readBytes()!);
        expect(text.contains(token), isFalse, reason: f.name);
        expect(text.contains(hash), isFalse, reason: f.name);
      }
      await input.close();

      final target = AppDb(NativeDatabase.memory());
      addTearDown(target.close);
      final result = await restoreBackup(target, zip.path, Directory(p.join(temp.path, 'c')));
      final opened = await openCredentials(result.sealedCredentials!, 'correct horse');
      expect(opened.botToken, token);
    });
  });

  Future<AppDb> untouchedTarget() async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.songs).insert(song(7));
    return db;
  }

  Future<String> zipWith(Map<String, String> files) async {
    final path = p.join(temp.path, 'test.zip');
    final encoder = ZipFileEncoder()..create(path);
    for (final e in files.entries) {
      final f = File(p.join(temp.path, 'entry'))..writeAsStringSync(e.value);
      await encoder.addFile(f, e.key);
    }
    await encoder.close();
    return path;
  }

  test('a file that is not a backup changes nothing', () async {
    final db = await untouchedTarget();
    final zip = await zipWith({'other.txt': 'hello'});
    await expectLater(
      restoreBackup(db, zip, Directory(p.join(temp.path, 'c'))),
      throwsFormatException,
    );
    expect(await db.song(1, 7), isNotNull);
  });

  test('a damaged backup changes nothing and skips the replace step', () async {
    final db = await untouchedTarget();
    final zip = await zipWith({'library.json': '{"version":1,"songs":[{"nope":1}]}'});
    var replaced = false;
    await expectLater(
      restoreBackup(
        db,
        zip,
        Directory(p.join(temp.path, 'c')),
        beforeReplace: () async => replaced = true,
      ),
      throwsFormatException,
    );
    expect(replaced, isFalse);
    expect(await db.song(1, 7), isNotNull);
  });

  test('a backup from a newer version is refused', () async {
    final db = await untouchedTarget();
    final zip = await zipWith({'library.json': '{"version":99}'});
    await expectLater(
      restoreBackup(db, zip, Directory(p.join(temp.path, 'c'))),
      throwsFormatException,
    );
    expect(await db.song(1, 7), isNotNull);
  });

  test('a cover name cannot escape the covers folder', () async {
    final source = await sourceLibrary();
    final good = await createBackup(source, temp);
    final input = InputFileStream(good.path);
    final manifest = ZipDecoder().decodeStream(input).findFile('library.json')!;
    final json = String.fromCharCodes(manifest.readBytes()!);
    await input.close();

    final evil = await zipWith({'library.json': json, 'covers/../../escaped.jpg': 'x'});
    final target = AppDb(NativeDatabase.memory());
    addTearDown(target.close);
    final covers = Directory(p.join(temp.path, 'deep', 'er', 'covers'));
    await restoreBackup(target, evil, covers);

    expect(File(p.join(temp.path, 'deep', 'escaped.jpg')).existsSync(), isFalse);
    expect(covers.listSync(), isEmpty);
  });

  test('the app layout comes back only when asked for, never the device id', () async {
    final source = AppDb(NativeDatabase.memory());
    addTearDown(source.close);
    await source.setPref('device_id', 'phone');
    await source.setPref('file_here', 'true');
    await source.setPref('nav_style', '{"layout":"dock"}');
    await source.setPref('theme_accent', 'rose');
    await source.setPref('sort_songs', 'title');
    final zip = await createBackup(source, temp);

    final off = AppDb(NativeDatabase.memory());
    addTearDown(off.close);
    await off.setPref('theme_accent', 'mint');
    final stages = <String>[];
    var last = 0.0;
    await restoreBackup(off, zip.path, Directory(p.join(temp.path, 'c1')), onProgress: (s, f) {
      stages.add(s);
      if (f != null) {
        expect(f, greaterThanOrEqualTo(last));
        last = f;
      }
    });
    expect(await off.pref('theme_accent'), 'mint');
    expect(stages, contains('Done'));
    expect(last, 1.0);

    final on = AppDb(NativeDatabase.memory());
    addTearDown(on.close);
    await on.setPref('device_id', 'pc');
    await on.setPref('file_here', 'false');
    await on.setPref('theme_accent', 'mint');
    final result = await restoreBackup(on, zip.path, Directory(p.join(temp.path, 'c2')), applyLayout: true);
    expect(result.layoutApplied, isTrue);
    expect(await on.pref('theme_accent'), 'rose');
    expect(await on.pref('nav_style'), '{"layout":"dock"}');
    expect(await on.pref('sort_songs'), 'title');
    expect(await on.pref('device_id'), 'pc', reason: 'the device id is never restored');
    expect(await on.pref('file_here'), 'false', reason: 'what this device files is its own');
  });

  test('bots, Spotify, ListenBrainz and the account session are sealed, and open with the password', () async {
    const c = Credentials(
      apiId: 1,
      apiHash: 'h',
      botToken: '1:a',
      extraBots: ['2:b', '3:c'],
      spotifyClientId: 'cid',
      spotifyRefreshToken: 'rt',
      listenBrainzToken: 'lb',
    );
    final sealed = await sealCredentials(c, 'password1');
    for (final secret in ['1:a', '2:b', 'rt', 'lb']) {
      expect(sealed.contains(secret), isFalse, reason: 'nothing readable in the file');
    }
    final back = await openCredentials(sealed, 'password1');
    expect(back.extraBots, ['2:b', '3:c']);
    expect([back.spotifyClientId, back.spotifyRefreshToken, back.listenBrainzToken], ['cid', 'rt', 'lb']);
    await expectLater(openCredentials(sealed, 'wrong'), throwsA(isA<WrongPassword>()));

    final bytes = await sealBytes([1, 2, 3, 4], 'password1');
    expect(await openBytes(bytes, 'password1'), [1, 2, 3, 4]);
    await expectLater(openBytes(bytes, 'nope'), throwsA(isA<WrongPassword>()));
  });

  test('a backup with an account session carries it as an entry, and credentials from older backups still open', () async {
    final source = AppDb(NativeDatabase.memory());
    addTearDown(source.close);
    final session = await sealBytes([9, 9, 9], 'password1');
    final zip = await createBackup(source, temp, sealedUserSession: session);
    final target = AppDb(NativeDatabase.memory());
    addTearDown(target.close);
    final result = await restoreBackup(target, zip.path, Directory(p.join(temp.path, 'c3')));
    expect(result.sealedUserSession, session);
  });
}
