import 'dart:convert';

import 'package:drift/drift.dart';

import '../library/db.dart';
import '../library/task_history.dart';
import '../library/taste.dart';

/// What [mergeSnapshot] changed, so the app can follow up.
class MergeResult {
  const MergeResult({this.changed = false, this.newChats = const [], this.coversWanted = const []});
  final bool changed;
  final List<LibraryChat> newChats;

  /// Songs whose cover was chosen on the other device more recently than here.
  /// Their images have to be asked for, since a snapshot holds only text.
  final List<Song> coversWanted;
}

const _goneKey = AppDb.goneKey;
const _topicsDeletedKey = 'topics_deleted';

/// Files deleted on purpose, by unique id with when, so a device that still lists one
/// doesn't bring it back and the others drop it too.
Future<Map<String, int>> goneSongs(AppDb db) async {
  final raw = await db.pref(_goneKey);
  return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, int>();
}

Future<void> markSongGone(AppDb db, String uniqueId) async {
  final gone = await goneSongs(db);
  gone[uniqueId] = DateTime.now().millisecondsSinceEpoch;
  await db.setPref(_goneKey, jsonEncode(gone));
}

/// Also remembers the song itself (title, artist, length), so other versions of it in
/// other channels aren't copied back into the main chat by the filer.
Future<void> markSongKeyGone(AppDb db, String key) async {
  final gone = await goneSongs(db);
  gone[key] = DateTime.now().millisecondsSinceEpoch;
  await db.setPref(_goneKey, jsonEncode(gone));
}

/// This device's library as JSON for another device: tags, favorites, playlists,
/// channels, deleted files and task history. Never the cache, pins or settings.
/// Cover images travel separately.
/// With [since], songs are limited to those changed after that time.
Future<Map<String, dynamic>> librarySnapshot(AppDb db, {int since = 0, int afterRowId = 0}) async {
  final query = db.select(db.songs);
  // In full, even songs nothing has touched yet: a new device has none of them.
  if (since > 0) {
    query.where((s) =>
        // Songs added since the last push carry no timestamp, so they're found by row number.
        // The first row number is 1, so 0 means "not asked for".
        CustomExpression<bool>(afterRowId > 0 ? 'songs.rowid > $afterRowId' : '0') |
        s.tagsAt.isBiggerThanValue(since) |
        s.favoriteAt.isBiggerThanValue(since) |
        s.lastPlayedAt.isBiggerThanValue(since) |
        s.coverAt.isBiggerThanValue(since) |
        s.moodScannedAt.isBiggerThanValue(since));
  }
  final songs = await query.get();
  final playlists = await db.select(db.playlists).get();
  final items = await db.select(db.playlistSongs).get();
  final missing = await db.select(db.missingTracks).get();
  return {
    'taste': (await db.tasteSettings()).toJson(),
    'votes': [
      for (final v in await db.select(db.moodVotes).get()) [v.chatId, v.messageId, v.mood, v.vote, v.at],
    ],
    'chats': [
      for (final c in await db.select(db.libraryChats).get())
        {'id': c.id, 'title': c.title, 'scanned': c.lastScannedMessageId, 'walkDone': c.walkDone},
    ],
    'main': await db.pref(AppDb.mainChatKey),
    'gone': await goneSongs(db),
    'tasks': await taskSnapshot(db),
    'topicsDeleted': await db.pref(_topicsDeletedKey),
    'marks': {
      for (final e in (await db.chatMarks()).entries) '${e.key}': {'gone': e.value.gone, 'at': e.value.at},
    },
    'topics': [
      for (final t in await db.select(db.forumTopics).get()) [t.chatId, t.topicId, t.name],
    ],
    if (since == 0) ...{
      'copies': [
        for (final c in await db.select(db.postCopies).get())
          [c.chatId, c.messageId, c.uniqueId, c.fileName, c.size, c.topicId, c.date],
      ],
    },
    'songs': [for (final s in songs) _songJson(s)],
    'playlists': [
      for (final p in playlists)
        {
          'uuid': p.uuid,
          'name': p.name,
          'modifiedAt': p.modifiedAt,
          'deletedAt': p.deletedAt,
          'sourceUrl': p.sourceUrl,
          'items': [
            for (final i in items.where((i) => i.playlistId == p.id))
              [i.chatId, i.messageId, i.addedAt, i.removedAt, i.sourceAddedAt],
          ],
          'missing': [
            for (final m in missing.where((m) => m.playlistId == p.id))
              {
                'key': m.trackKey,
                'title': m.title,
                'artist': m.artist,
                'durationSec': m.durationSec,
                'position': m.position,
                'sourceAt': m.sourceAddedAt,
              },
          ],
        },
    ],
  };
}

Map<String, dynamic> _songJson(Song s) => {
      'chatId': s.chatId,
      'messageId': s.messageId,
      'uniqueId': s.uniqueId,
      'remoteId': s.remoteId,
      'size': s.size,
      'mime': s.mime,
      'fileName': s.fileName,
      'date': s.date,
      'topicId': s.topicId,
      'sampleRate': s.sampleRate,
      'bitDepth': s.bitDepth,
      'codec': s.codec,
      'hasCover': s.coverPath != null,
      'title': s.title,
      'artist': s.artist,
      'album': s.album,
      'durationSec': s.durationSec,
      'releaseId': s.releaseId,
      'coverUrl': s.coverUrl,
      'genre': s.genre,
      'year': s.year,
      'metadataSource': s.metadataSource,
      'userEdited': s.userEdited,
      'enrichState': s.enrichState,
      'lyrics': s.lyrics,
      'tagsAt': s.tagsAt,
      'favorite': s.favorite,
      'favoriteAt': s.favoriteAt,
      'lastPlayedAt': s.lastPlayedAt,
      'coverAt': s.coverAt,
      'instrumental': s.instrumental,
      'moodScannedAt': s.moodScannedAt,
      'plays': s.plays,
      'skips': s.skips,
    };

/// Whether a device's tags replace this device's: a person's edit beats an
/// automatic match, then the newest wins.
bool remoteTagsWin(Song local, Map<String, dynamic> remote) {
  final edited = remote['userEdited'] as bool;
  if (edited != local.userEdited) return edited;
  return (remote['tagsAt'] as int) > local.tagsAt;
}

/// A song only the other device knows, as that device has it.
SongsCompanion _newSong(Map<String, dynamic> r, String uniqueId) => SongsCompanion.insert(
      chatId: r['chatId'] as int,
      messageId: r['messageId'] as int,
      uniqueId: uniqueId,
      remoteId: r['remoteId'] as String,
      title: r['title'] as String,
      artist: r['artist'] as String,
      album: Value(r['album'] as String),
      durationSec: Value(r['durationSec'] as int),
      size: r['size'] as int,
      mime: r['mime'] as String,
      fileName: r['fileName'] as String,
      date: r['date'] as int,
      topicId: Value(r['topicId'] as int?),
      sampleRate: Value(r['sampleRate'] as int?),
      bitDepth: Value(r['bitDepth'] as int?),
      codec: Value(r['codec'] as String?),
      releaseId: Value(r['releaseId'] as String?),
      coverUrl: Value(r['coverUrl'] as String?),
      genre: Value(r['genre'] as String?),
      year: Value(r['year'] as int?),
      metadataSource: Value(r['metadataSource'] as String?),
      userEdited: Value(r['userEdited'] as bool),
      enrichState: Value(r['enrichState'] as int),
      lyrics: Value(r['lyrics'] as String?),
      tagsAt: Value(r['tagsAt'] as int),
      favorite: Value(r['favorite'] as bool),
      favoriteAt: Value(r['favoriteAt'] as int),
      lastPlayedAt: Value(r['lastPlayedAt'] as int?),
      instrumental: Value(r['instrumental'] as bool? ?? false),
      moodScannedAt: Value(r['moodScannedAt'] as int? ?? 0),
      plays: Value(r['plays'] as int? ?? 0),
      skips: Value(r['skips'] as int? ?? 0),
    );

/// Merges another device's [snapshot] in. Only writes real differences, so
/// devices stop exchanging changes once they agree.
// chisle: newest-wins uses each device's clock, so a badly wrong clock can win.
Future<MergeResult> mergeSnapshot(
  AppDb db,
  Map<String, dynamic> snapshot, {
  Future<Set<(int, int)>> Function(List<(int, int)> posts)? existing,
}) async {
  var changed = false;
  final newChats = <LibraryChat>[];
  final coversWanted = <Song>[];

  // A song only the other device lists may have been deleted here before deletions were
  // recorded. Telegram knows: only posts that still exist are taken. Done before the
  // transaction, since it waits on the network.
  Set<(int, int)>? alive;
  if (existing != null) {
    final missing = <(int, int)>[];
    for (final r in (snapshot['songs'] as List).cast<Map<String, dynamic>>()) {
      final chatId = r['chatId'] as int, messageId = r['messageId'] as int;
      final uid = r['uniqueId'] as String?;
      if (await db.song(chatId, messageId) == null && (uid == null || await db.songByUniqueId(uid) == null)) {
        missing.add((chatId, messageId));
      }
    }
    alive = missing.isEmpty ? <(int, int)>{} : await existing(missing);
  }

  await db.transaction(() async {
    final mine = await db.tasteSettings();
    final raw = snapshot['taste'] as Map<String, dynamic>?;
    final theirs = raw == null ? null : TasteSettings.fromJson(raw);
    if (theirs != null) {
      // Newer settings win, and a newer clearing applies here too.
      if (theirs.resetAt > mine.resetAt) {
        await db.clearLearnedRows();
        changed = true;
      }
      if (theirs.at > mine.at) {
        await db.setPref('taste_settings', theirs.encode());
        changed = true;
      }
    }
    // Sent before that device heard of a clearing here, so its counts are out of date.
    final ignoreCounts = (theirs?.resetAt ?? 0) < mine.resetAt;

    // Removals and re-adds first, so a removed channel isn't added back from this snapshot.
    var marks = await db.chatMarks();
    for (final e in ((snapshot['marks'] as Map<String, dynamic>?) ?? const {}).entries) {
      final id = int.parse(e.key);
      final gone = (e.value as Map)['gone'] as bool, at = (e.value as Map)['at'] as int;
      if ((marks[id]?.at ?? 0) >= at) continue;
      await db.markChat(id, gone: gone, at: at);
      if (gone) await db.removeChat(id, preferChat: await db.mainChatId());
      changed = true;
    }
    marks = await db.chatMarks();

    final chats = {for (final c in await db.select(db.libraryChats).get()) c.id: c};
    for (final c in (snapshot['chats'] as List).cast<Map<String, dynamic>>()) {
      final id = c['id'] as int;
      if (marks[id]?.gone ?? false) continue;
      final scanned = c['scanned'] as int?;
      final walked = c['walkDone'] as bool? ?? false;
      final mine = chats[id];
      if (mine == null) {
        final title = c['title'] as String;
        await db.into(db.libraryChats).insert(
              LibraryChatsCompanion.insert(
                id: Value(id),
                title: title,
                lastScannedMessageId: Value(scanned),
                walkDone: Value(walked),
              ),
            );
        newChats.add(LibraryChat(id: id, title: title, lastScannedMessageId: scanned, useBot: false, walkDone: walked));
        changed = true;
      } else if (mine.lastScannedMessageId == null && scanned != null) {
        // Added by hand here too, but not read yet: no need to read it all again.
        await (db.update(db.libraryChats)..where((r) => r.id.equals(id)))
            .write(LibraryChatsCompanion(lastScannedMessageId: Value(scanned), walkDone: Value(walked)));
      } else {
        continue;
      }
      // The other device has already read the topics, so the once-per-install reread can go.
      if (scanned != null) await db.setPref('topics_read', '1');
    }

    for (final t in snapshot['topics'] as List? ?? const []) {
      final v = t as List;
      await db.into(db.forumTopics).insert(
            ForumTopicsCompanion.insert(chatId: v[0] as int, topicId: v[1] as int, name: v[2] as String),
            mode: InsertMode.insertOrIgnore,
          );
    }

    final main = snapshot['main'] as String?;
    if (main != null && mainChatAt(main) > mainChatAt(await db.pref(AppDb.mainChatKey))) {
      await db.setPref(AppDb.mainChatKey, main);
      changed = true;
    }

    // Deleted files: remembered here, and dropped if this device still lists them.
    final gone = await goneSongs(db);
    var goneChanged = false;
    for (final e in ((snapshot['gone'] as Map?) ?? const {}).entries) {
      final uid = e.key as String, at = e.value as int;
      if ((gone[uid] ?? 0) >= at) continue;
      gone[uid] = at;
      goneChanged = true;
      final row = await db.songByUniqueId(uid);
      // A file posted again after the deletion is a new one.
      if (row == null || row.date * 1000 > at) continue;
      for (final c in await (db.select(db.postCopies)..where((c) => c.uniqueId.equals(uid))).get()) {
        await db.removePost(c.chatId, c.messageId);
      }
      await db.removePost(row.chatId, row.messageId);
      changed = true;
    }
    if (goneChanged) await db.setPref(_goneKey, jsonEncode(gone));
    bool deleted(String uid, int date) => (gone[uid] ?? 0) >= date * 1000 && gone.containsKey(uid);

    // Topic names removed on purpose stay removed everywhere.
    final theirTopics = snapshot['topicsDeleted'] as String?;
    if (theirTopics != null) {
      final mineTopics = {...?(jsonDecode(await db.pref(_topicsDeletedKey) ?? '[]') as List?)?.cast<String>()};
      final all = {...mineTopics, ...(jsonDecode(theirTopics) as List).cast<String>()};
      if (all.length != mineTopics.length) {
        await db.setPref(_topicsDeletedKey, jsonEncode(all.toList()));
        changed = true;
      }
    }

    if (await mergeTasks(db, snapshot['tasks'] as Map<String, dynamic>?)) changed = true;

    for (final r in (snapshot['songs'] as List).cast<Map<String, dynamic>>()) {
      final chatId = r['chatId'] as int, messageId = r['messageId'] as int;
      final uniqueId = r['uniqueId'] as String?;
      // A file's post can differ between devices while one hasn't heard of a move.
      final local = await db.song(chatId, messageId) ?? (uniqueId == null ? null : await db.songByUniqueId(uniqueId));
      if (local == null) {
        // Anything the other device lists that was not deleted on purpose comes here.
        if (uniqueId == null || (marks[chatId]?.gone ?? false) || deleted(uniqueId, r['date'] as int)) continue;
        if (alive != null && !alive.contains((chatId, messageId))) continue;
        await db.into(db.songs).insert(_newSong(r, uniqueId), mode: InsertMode.insertOrIgnore);
        if (r['hasCover'] == true) {
          final added = await db.song(chatId, messageId);
          if (added != null) coversWanted.add(added);
        }
        changed = true;
        continue;
      }
      final remoteCoverAt = r['coverAt'] as int? ?? 0;
      if (remoteCoverAt > local.coverAt || (local.coverPath == null && r['hasCover'] == true)) coversWanted.add(local);
      var changes = const SongsCompanion();
      if (remoteTagsWin(local, r)) {
        // An automatic result with a gap doesn't erase what's known here. A person's
        // edit is taken as it is.
        final edited = r['userEdited'] as bool;
        changes = changes.copyWith(
          title: Value(r['title'] as String),
          artist: Value(r['artist'] as String),
          album: Value(r['album'] as String),
          durationSec: Value(r['durationSec'] as int),
          releaseId: Value(r['releaseId'] as String?),
          coverUrl: Value(r['coverUrl'] as String?),
          genre: Value(r['genre'] as String? ?? (edited ? null : local.genre)),
          year: Value(r['year'] as int? ?? (edited ? null : local.year)),
          metadataSource: Value(r['metadataSource'] as String?),
          userEdited: Value(edited),
          enrichState: Value(r['enrichState'] as int),
          lyrics: Value(r['lyrics'] as String? ?? (edited ? null : local.lyrics)),
          tagsAt: Value(r['tagsAt'] as int),
        );
      } else {
        // These tags stay, but they can still gain what only the other device looked up.
        if (local.lyrics == null && r['lyrics'] != null) changes = changes.copyWith(lyrics: Value(r['lyrics'] as String));
        if (local.genre == null && r['genre'] != null) changes = changes.copyWith(genre: Value(r['genre'] as String));
        if (local.year == null && r['year'] != null) changes = changes.copyWith(year: Value(r['year'] as int));
      }
      if (local.sampleRate == null && r['sampleRate'] != null) {
        changes = changes.copyWith(
          sampleRate: Value(r['sampleRate'] as int),
          bitDepth: Value(r['bitDepth'] as int?),
          codec: Value(r['codec'] as String?),
        );
      }
      if ((r['favoriteAt'] as int) > local.favoriteAt) {
        changes = changes.copyWith(
          favorite: Value(r['favorite'] as bool),
          favoriteAt: Value(r['favoriteAt'] as int),
        );
      }
      // Saves the other device looking up what this one already has.
      final scanned = r['moodScannedAt'] as int? ?? 0;
      if (scanned > local.moodScannedAt) {
        changes = changes.copyWith(
          moodScannedAt: Value(scanned),
          instrumental: Value(r['instrumental'] as bool? ?? false),
        );
      }
      // Each device counts its own, so the higher is closest without double counting.
      if (!ignoreCounts) {
        final plays = r['plays'] as int? ?? 0, skips = r['skips'] as int? ?? 0;
        if (plays > local.plays) changes = changes.copyWith(plays: Value(plays));
        if (skips > local.skips) changes = changes.copyWith(skips: Value(skips));
      }
      final played = r['lastPlayedAt'] as int?;
      if (played != null && played > (local.lastPlayedAt ?? 0)) {
        changes = changes.copyWith(lastPlayedAt: Value(played));
      }
      if (changes.toColumns(false).isEmpty) continue;
      // Not updateSong: it would stamp this device's clock and re-announce.
      await (db.update(db.songs)
            ..where((s) => s.chatId.equals(local.chatId) & s.messageId.equals(local.messageId)))
          .write(changes);
      changed = true;
    }

    for (final c in snapshot['copies'] as List? ?? const []) {
      final v = c as List;
      if ((marks[v[0] as int]?.gone ?? false) || deleted(v[2] as String, v[6] as int)) continue;
      // The row itself may be this post here; it isn't also a copy of itself.
      if (await db.song(v[0] as int, v[1] as int) != null) continue;
      await db.into(db.postCopies).insert(
            PostCopiesCompanion.insert(
              chatId: v[0] as int,
              messageId: v[1] as int,
              uniqueId: v[2] as String,
              fileName: v[3] as String,
              size: v[4] as int,
              topicId: Value(v[5] as int?),
              date: v[6] as int,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    final myVotes = {
      for (final v in await db.select(db.moodVotes).get()) (v.chatId, v.messageId, v.mood): v.at,
    };
    for (final vote in ignoreCounts ? const [] : snapshot['votes'] as List? ?? const []) {
      final v = vote as List;
      final key = (v[0] as int, v[1] as int, v[2] as String);
      if ((v[4] as int) <= (myVotes[key] ?? -1)) continue;
      await db.into(db.moodVotes).insertOnConflictUpdate(
            MoodVotesCompanion.insert(chatId: key.$1, messageId: key.$2, mood: key.$3, vote: v[3] as int, at: v[4] as int),
          );
      changed = true;
    }

    for (final p in (snapshot['playlists'] as List).cast<Map<String, dynamic>>()) {
      final uuid = p['uuid'] as String;
      final modifiedAt = p['modifiedAt'] as int;
      final local = await (db.select(db.playlists)..where((r) => r.uuid.equals(uuid))).getSingleOrNull();
      final int id;
      if (local == null) {
        id = await db.into(db.playlists).insert(
              PlaylistsCompanion.insert(
                name: p['name'] as String,
                uuid: Value(uuid),
                modifiedAt: Value(modifiedAt),
                deletedAt: Value(p['deletedAt'] as int?),
                sourceUrl: Value(p['sourceUrl'] as String?),
              ),
            );
        changed = true;
      } else {
        id = local.id;
        if (modifiedAt > local.modifiedAt) {
          await (db.update(db.playlists)..where((r) => r.id.equals(id))).write(
            PlaylistsCompanion(
              name: Value(p['name'] as String),
              modifiedAt: Value(modifiedAt),
              deletedAt: Value(p['deletedAt'] as int?),
              sourceUrl: Value(p['sourceUrl'] as String?),
            ),
          );
          changed = true;
        }
      }

      final items = {
        for (final i in await (db.select(db.playlistSongs)..where((r) => r.playlistId.equals(id))).get())
          (i.chatId, i.messageId): i,
      };
      for (final raw in p['items'] as List) {
        final i = raw as List;
        final key = (i[0] as int, i[1] as int);
        final addedAt = i[2] as int;
        final removedAt = i[3] as int?;
        final mine = items[key];
        final dated = i.length > 4 ? i[4] as int? : null;
        if (mine != null && _lastChange(addedAt, removedAt) <= _lastChange(mine.addedAt, mine.removedAt)) {
          if (dated != null && mine.sourceAddedAt == null) {
            await (db.update(db.playlistSongs)
                  ..where((r) => r.playlistId.equals(id) & r.chatId.equals(key.$1) & r.messageId.equals(key.$2)))
                .write(PlaylistSongsCompanion(sourceAddedAt: Value(dated)));
            changed = true;
          }
          continue;
        }
        await db.into(db.playlistSongs).insertOnConflictUpdate(
              PlaylistSongsCompanion.insert(
                playlistId: id,
                chatId: key.$1,
                messageId: key.$2,
                addedAt: addedAt,
                sourceAddedAt: Value(dated),
                removedAt: Value(removedAt),
              ),
            );
        changed = true;
      }

      final missing = {
        for (final m in await (db.select(db.missingTracks)..where((r) => r.playlistId.equals(id))).get())
          m.trackKey,
      };
      for (final m in (p['missing'] as List).cast<Map<String, dynamic>>()) {
        if (missing.contains(m['key'])) continue;
        await db.into(db.missingTracks).insert(
              MissingTracksCompanion.insert(
                playlistId: id,
                trackKey: m['key'] as String,
                title: m['title'] as String,
                artist: m['artist'] as String,
                durationSec: Value(m['durationSec'] as int),
                position: Value(m['position'] as int),
                sourceAddedAt: Value(m['sourceAt'] as int?),
              ),
            );
        changed = true;
      }
    }
  });
  return MergeResult(changed: changed, newChats: newChats, coversWanted: coversWanted);
}

int _lastChange(int addedAt, int? removedAt) => removedAt != null && removedAt > addedAt ? removedAt : addedAt;
