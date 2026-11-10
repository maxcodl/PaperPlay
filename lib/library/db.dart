import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'taste.dart';

part 'db.g.dart';

abstract final class EnrichState {
  static const pending = 0, done = 1, noMatch = 2;
}

class LibraryStats {
  const LibraryStats({
    required this.total,
    required this.waiting,
    required this.matched,
    required this.noMatch,
    required this.covers,
  });
  final int total, waiting, matched, noMatch, covers;
}

class Songs extends Table {
  IntColumn get chatId => integer()();
  IntColumn get messageId => integer()();

  /// Same file posted twice keeps one row, first seen wins.
  TextColumn get uniqueId => text()();
  TextColumn get remoteId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text().withDefault(const Constant(''))();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get size => integer()();
  TextColumn get mime => text()();
  TextColumn get fileName => text()();
  IntColumn get date => integer()();
  TextColumn get coverPath => text().nullable()();

  /// MusicBrainz release, for fetching the cover when a song is first shown.
  TextColumn get releaseId => text().nullable()();

  /// Cover found on Deezer or iTunes, fetched when the song is first shown.
  TextColumn get coverUrl => text().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get year => integer().nullable()();

  /// Which service the tags came from.
  TextColumn get metadataSource => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// [coverPath] is full size, not a small thumbnail from the Telegram file.
  BoolColumn get coverHiRes => boolean().withDefault(const Constant(false))();
  BoolColumn get userEdited => boolean().withDefault(const Constant(false))();
  IntColumn get enrichState => integer().withDefault(const Constant(EnrichState.pending))();
  TextColumn get lyrics => text().nullable()();
  IntColumn get cachedBytes => integer().withDefault(const Constant(0))();
  IntColumn get lastPlayedAt => integer().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// When tags last changed here; newest wins between devices. 0 means never.
  IntColumn get tagsAt => integer().withDefault(const Constant(0))();

  /// When [favorite] last changed, kept apart so a tag match can't undo it.
  IntColumn get favoriteAt => integer().withDefault(const Constant(0))();

  /// When someone chose this cover. Above 0, automatic covers leave it alone,
  /// and other devices fetch its image, since cover files aren't otherwise shared.
  IntColumn get coverAt => integer().withDefault(const Constant(0))();

  /// The lyrics service says this song has no words.
  BoolColumn get instrumental => boolean().withDefault(const Constant(false))();

  /// When its lyrics and genre were looked up for mood mixes. 0 means not yet.
  IntColumn get moodScannedAt => integer().withDefault(const Constant(0))();

  /// Times finished and skipped, which teach the mixes what's liked.
  IntColumn get plays => integer().withDefault(const Constant(0))();
  IntColumn get skips => integer().withDefault(const Constant(0))();

  /// The forum topic it was posted in, if the chat has topics.
  IntColumn get topicId => integer().nullable()();

  /// Read from the file's header once some of it is on a device. Null until then:
  /// never estimated. [codec] is set only where the file name can't tell, like
  /// ALAC inside an .m4a.
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  TextColumn get codec => text().nullable()();

  @override
  Set<Column> get primaryKey => {chatId, messageId};

  @override
  List<Set<Column>> get uniqueKeys => [
        {uniqueId},
      ];
}

class LibraryChats extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  IntColumn get lastScannedMessageId => integer().nullable()();

  /// Left over from when a user login could also read chats. No longer used.
  BoolColumn get useBot => boolean().withDefault(const Constant(false))();

  /// The bot has read this chat through to its end at least once.
  BoolColumn get walkDone => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Same on every device; [id] is local to this one.
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get modifiedAt => integer().withDefault(const Constant(0))();

  /// Kept after deleting, so another device can't bring the playlist back.
  IntColumn get deletedAt => integer().nullable()();

  /// Where it was imported from, for refreshing it.
  TextColumn get sourceUrl => text().nullable()();
}

class PlaylistSongs extends Table {
  IntColumn get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get chatId => integer()();
  IntColumn get messageId => integer()();
  IntColumn get addedAt => integer()();

  /// When the source service says it was added there (Spotify's `added_at`), if known.
  IntColumn get sourceAddedAt => integer().nullable()();

  /// Kept after removing, so another device can't add the song back.
  IntColumn get removedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {playlistId, chatId, messageId};
}

/// A track of an imported playlist with no matching song in the library yet.
class MissingTracks extends Table {
  IntColumn get playlistId => integer().references(Playlists, #id, onDelete: KeyAction.cascade)();

  /// The source's id for the track, such as a Spotify URI.
  TextColumn get trackKey => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get sourceAddedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {playlistId, trackKey};
}

/// Someone's verdict that a song does or doesn't suit a mood.
class MoodVotes extends Table {
  IntColumn get chatId => integer()();
  IntColumn get messageId => integer()();
  TextColumn get mood => text()();

  /// 1 fits, -1 doesn't, 0 means the verdict was undone.
  IntColumn get vote => integer()();
  IntColumn get at => integer()();

  @override
  Set<Column> get primaryKey => {chatId, messageId, mood};
}

/// A topic in a forum chat. A bot can't list these: names come from each topic's
/// creation message, and from later updates when Telegram sends them.
class ForumTopics extends Table {
  IntColumn get chatId => integer()();
  IntColumn get topicId => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {chatId, topicId};
}

/// A post of a file the library already lists under another post. The library keeps
/// one row per file, so these are remembered here to be flagged as duplicates.
class PostCopies extends Table {
  IntColumn get chatId => integer()();
  IntColumn get messageId => integer()();
  TextColumn get uniqueId => text()();
  TextColumn get fileName => text()();
  IntColumn get size => integer()();
  IntColumn get topicId => integer().nullable()();
  IntColumn get date => integer()();

  @override
  Set<Column> get primaryKey => {chatId, messageId};
}

/// Listening time per device, day and song. Rows only grow, so devices merge by taking the larger.
class ListenStats extends Table {
  TextColumn get origin => text()();
  TextColumn get day => text()();
  TextColumn get trackKey => text()();
  IntColumn get ms => integer().withDefault(const Constant(0))();
  IntColumn get plays => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {origin, day, trackKey};
}

class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class ListenTotal {
  const ListenTotal(this.key, this.ms, this.plays, this.title, this.artist);
  final String key;
  final int ms, plays;
  final String? title, artist;
}

int? parseMainChat(String? json) => json == null ? null : (jsonDecode(json) as Map<String, dynamic>)['id'] as int?;

/// Edit stamp: the clock, but always after [previous] so a local edit beats the version it replaces.
int laterStamp(int now, int previous) => now > previous ? now : previous + 1;

int mainChatAt(String? json) => json == null ? 0 : (jsonDecode(json) as Map<String, dynamic>)['at'] as int? ?? 0;

/// Random id for a new playlist or device.
String newUuid() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Id for a playlist from before sync. Derived rather than random, so two
/// devices restored from one backup agree on it and don't duplicate the list.
String legacyPlaylistUuid(int id, String name) => 'legacy-$id-$name';

@DriftDatabase(tables: [Songs, LibraryChats, Playlists, PlaylistSongs, Prefs, MissingTracks, MoodVotes, ForumTopics, PostCopies, ListenStats])
class AppDb extends _$AppDb {
  AppDb([QueryExecutor? executor])
      : super(executor ??
            LazyDatabase(() async {
              final dir = await getApplicationSupportDirectory();
              return NativeDatabase.createInBackground(File(p.join(dir.path, 'library.sqlite')));
            }));

  @override
  int get schemaVersion => 14;

  final _synced = StreamController<void>.broadcast();

  /// Fires when something other devices should hear about changes here.
  Stream<void> get syncableChanges => _synced.stream;

  void _markChanged() => _synced.add(null);

  /// For changes made directly to tables that other devices should hear about.
  void announceChange() => _markChanged();

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(songs, songs.releaseId);
          if (from < 3) {
            // Title cleanup improves search, so earlier non-matches get another try.
            await customStatement(
              'UPDATE songs SET enrich_state = ${EnrichState.pending} '
              'WHERE enrich_state = ${EnrichState.noMatch} AND user_edited = 0',
            );
          }
          if (from < 4) await m.addColumn(libraryChats, libraryChats.useBot);
          if (from < 5) {
            await m.addColumn(songs, songs.coverUrl);
            await m.addColumn(songs, songs.genre);
            await m.addColumn(songs, songs.year);
            await m.addColumn(songs, songs.metadataSource);
            await m.addColumn(libraryChats, libraryChats.walkDone);
            // Chats already scanned to the end count as done, so they aren't re-read.
            await customStatement(
              'UPDATE library_chats SET walk_done = 1 WHERE last_scanned_message_id IS NOT NULL',
            );
            // New sources may find what MusicBrainz couldn't.
            await customStatement(
              'UPDATE songs SET enrich_state = ${EnrichState.pending} '
              'WHERE enrich_state = ${EnrichState.noMatch} AND user_edited = 0',
            );
          }
          if (from < 6) {
            await m.addColumn(songs, songs.favorite);
            await m.addColumn(songs, songs.coverHiRes);
          }
          if (from < 7) {
            await m.addColumn(songs, songs.tagsAt);
            await m.addColumn(songs, songs.favoriteAt);
            await m.addColumn(playlists, playlists.uuid);
            await m.addColumn(playlists, playlists.modifiedAt);
            await m.addColumn(playlists, playlists.deletedAt);
            await m.addColumn(playlists, playlists.sourceUrl);
            await m.addColumn(playlistSongs, playlistSongs.removedAt);
            await m.createTable(missingTracks);
            // 1 rather than now: existing work should reach a device that has
            // none, without beating anything changed after this upgrade.
            await prepareOlderRows();
          }
          if (from < 8) await m.addColumn(songs, songs.coverAt);
          if (from < 9) {
            await m.addColumn(songs, songs.instrumental);
            await m.addColumn(songs, songs.moodScannedAt);
            await m.addColumn(songs, songs.plays);
            await m.addColumn(songs, songs.skips);
            await m.createTable(moodVotes);
          }
          if (from < 10) {
            await m.addColumn(songs, songs.topicId);
            await m.createTable(forumTopics);
            await m.createTable(postCopies);
            // The owner asked to start over: taste now comes from their lists, not
            // from how the whole library was played. Looked-up song facts stay.
            await clearLearnedRows();
            await setPref(
              _tasteKey,
              TasteSettings(resetAt: DateTime.now().millisecondsSinceEpoch).encode(),
            );
          }
          if (from < 11) {
            await m.addColumn(songs, songs.sampleRate);
            await m.addColumn(songs, songs.bitDepth);
            await m.addColumn(songs, songs.codec);
          }
          if (from < 12) {
            // Files with no length used to match nothing online, so they had no cover.
            await customStatement(
              'UPDATE songs SET enrich_state = ${EnrichState.pending} '
              'WHERE enrich_state = ${EnrichState.noMatch} AND user_edited = 0 AND duration_sec <= 0',
            );
            await customStatement("DELETE FROM prefs WHERE key = 'covers_none_found'");
          }
          if (from < 13) await m.createTable(listenStats);
          if (from < 14) {
            await m.addColumn(playlistSongs, playlistSongs.sourceAddedAt);
            // Created with the column by the step for version 7 when upgrading from older.
            if (from >= 7) await m.addColumn(missingTracks, missingTracks.sourceAddedAt);
          }
        },
        beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
      );

  /// Settings tied to this device, which a backup must not move to another.
  static const devicePrefs = [
    'device_id',
    'listenbrainz_on',
    'last_session',
    'sort_songs',
    'sort_reverse',
    'sort_playlist',
    'norm_mode',
    'norm_preamp',
    'eq_on',
    'eq_gains',
    'listenbrainz_queue',
    'rate_filing',
    'rate_uploads',
    'rate_reading',
    'rate_lookups',
    'rate_covers',
    'rate_accountCopy',
    'lan_addresses',
    'lan_discovery',
    'theme_mode',
    'theme_amoled',
    'theme_accent',
    'now_playing_panel',
    'audio_device',
    'weather_city',
    'weather_lat',
    'weather_lon',
    'spotify_client_id',
    'upload_slower',
    'upload_parallel',
    'uploaded_files',
    'upload_skip_known',
    'topics_read',
    'floating_nav',
    'nav_radius',
    'nav_style',
    'glass_style',
    'profile_name',
    'profile_photo',
    'profile_name_at',
    'profile_photo_at',
    'file_here',
    'file_existing',
    'upload_ask',
    'keep_running',
    'export_lists',
  ];

  static const defaultCacheLimit = 2 * 1024 * 1024 * 1024;
  static const _cacheLimitKey = 'cache_limit';

  Stream<List<Song>> watchSongs() =>
      (select(songs)..orderBy([(s) => OrderingTerm.desc(s.date)])).watch();

  Stream<Song?> watchSong(int chatId, int messageId) => (select(songs)
        ..where((s) => s.chatId.equals(chatId) & s.messageId.equals(messageId)))
      .watchSingleOrNull();

  Stream<List<Song>> watchFavorites() => (select(songs)
        ..where((s) => s.favorite.equals(true))
        ..orderBy([(s) => OrderingTerm.asc(s.title)]))
      .watch();

  Stream<List<Song>> watchRecent({int limit = 50}) => (select(songs)
        ..where((s) => s.lastPlayedAt.isNotNull())
        ..orderBy([(s) => OrderingTerm.desc(s.lastPlayedAt)])
        ..limit(limit))
      .watch();

  Stream<LibraryStats> watchStats() => customSelect(
        'SELECT COUNT(*) AS total, '
        'COALESCE(SUM(enrich_state = ${EnrichState.pending}), 0) AS waiting, '
        'COALESCE(SUM(enrich_state = ${EnrichState.done}), 0) AS matched, '
        'COALESCE(SUM(enrich_state = ${EnrichState.noMatch}), 0) AS no_match, '
        'COALESCE(SUM(cover_path IS NOT NULL), 0) AS covers '
        'FROM songs',
        readsFrom: {songs},
      ).watchSingle().map(
            (r) => LibraryStats(
              total: r.read<int>('total'),
              waiting: r.read<int>('waiting'),
              matched: r.read<int>('matched'),
              noMatch: r.read<int>('no_match'),
              covers: r.read<int>('covers'),
            ),
          );

  Stream<List<LibraryChat>> watchChats() => select(libraryChats).watch();

  /// Readies rows from before sync, after an upgrade or an older backup's restore.
  Future<void> prepareOlderRows() async {
    await customStatement(
      'UPDATE songs SET tags_at = 1 WHERE tags_at = 0 '
      'AND (user_edited = 1 OR enrich_state <> ${EnrichState.pending})',
    );
    await customStatement('UPDATE songs SET favorite_at = 1 WHERE favorite_at = 0 AND favorite = 1');
    final rows = await customSelect('SELECT id, name FROM playlists WHERE uuid = \'\'').get();
    for (final r in rows) {
      final id = r.read<int>('id');
      await customUpdate(
        'UPDATE playlists SET uuid = ? WHERE id = ?',
        variables: [Variable(legacyPlaylistUuid(id, r.read<String>('name'))), Variable(id)],
        updates: {playlists},
      );
    }
  }

  Stream<List<Playlist>> watchPlaylists() =>
      (select(playlists)..where((p) => p.deletedAt.isNull())).watch();

  Future<List<Playlist>> livePlaylists() =>
      (select(playlists)..where((p) => p.deletedAt.isNull())).get();

  Future<int> createPlaylist(String name, {String? sourceUrl}) async {
    final id = await into(playlists).insert(
      PlaylistsCompanion.insert(
        name: name,
        uuid: Value(newUuid()),
        modifiedAt: Value(DateTime.now().millisecondsSinceEpoch),
        sourceUrl: Value(sourceUrl),
      ),
    );
    _markChanged();
    return id;
  }

  Future<void> deletePlaylist(int id) async {
    final prev = await (select(playlists)..where((p) => p.id.equals(id))).getSingleOrNull();
    final now = laterStamp(DateTime.now().millisecondsSinceEpoch, prev?.modifiedAt ?? 0);
    await (update(playlists)..where((p) => p.id.equals(id)))
        .write(PlaylistsCompanion(deletedAt: Value(now), modifiedAt: Value(now)));
    _markChanged();
  }

  Stream<List<MissingTrack>> watchMissing(int playlistId) => (select(missingTracks)
        ..where((t) => t.playlistId.equals(playlistId))
        ..orderBy([(t) => OrderingTerm.asc(t.position)]))
      .watch();

  Stream<List<Song>> watchPlaylistSongs(int id) {
    final q = select(songs).join([
      innerJoin(
        playlistSongs,
        playlistSongs.chatId.equalsExp(songs.chatId) &
            playlistSongs.messageId.equalsExp(songs.messageId),
      ),
    ])
      ..where(playlistSongs.playlistId.equals(id) & playlistSongs.removedAt.isNull())
      ..orderBy([OrderingTerm.asc(playlistSongs.addedAt)]);
    return q.watch().map((rows) => rows.map((r) => r.readTable(songs)).toList());
  }

  /// When each song of a playlist was added at its source, by `chatId:messageId`. Songs with no date are left out.
  Future<Map<String, int>> sourceDates(int playlistId) async => {
        for (final r in await (select(playlistSongs)
              ..where((t) => t.playlistId.equals(playlistId) & t.removedAt.isNull() & t.sourceAddedAt.isNotNull()))
            .get())
          '${r.chatId}:${r.messageId}': r.sourceAddedAt!,
      };

  Future<void> addToPlaylist(int id, Song s) async {
    await into(playlistSongs).insertOnConflictUpdate(
      PlaylistSongsCompanion.insert(
        playlistId: id,
        chatId: s.chatId,
        messageId: s.messageId,
        addedAt: DateTime.now().millisecondsSinceEpoch,
        removedAt: const Value(null),
      ),
    );
    _markChanged();
  }

  Future<void> removeFromPlaylist(int id, Song s) async {
    await (update(playlistSongs)
          ..where((r) =>
              r.playlistId.equals(id) & r.chatId.equals(s.chatId) & r.messageId.equals(s.messageId)))
        .write(PlaylistSongsCompanion(removedAt: Value(DateTime.now().millisecondsSinceEpoch)));
    _markChanged();
  }

  Future<Song?> song(int chatId, int messageId) => (select(songs)
        ..where((s) => s.chatId.equals(chatId) & s.messageId.equals(messageId)))
      .getSingleOrNull();

  Future<void> updateSong(Song s, SongsCompanion changes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final touched = changes.title.present ||
        changes.artist.present ||
        changes.album.present ||
        changes.genre.present ||
        changes.year.present ||
        changes.lyrics.present ||
        changes.releaseId.present ||
        changes.coverUrl.present ||
        changes.metadataSource.present ||
        changes.userEdited.present ||
        changes.enrichState.present ||
        changes.durationSec.present;
    // tagsAt says how recent a person's edit is. A lookup filling in a gap on an edited
    // song mustn't make an older edit look newer than one on another device.
    final tags = touched && (!s.userEdited || changes.userEdited.present);
    final favorite = changes.favorite.present;
    // A local edit is always stamped later than the version it replaces, so a peer with a
    // fast clock (whose stamp we stored on merge) can't make our edit lose.
    await (update(songs)
          ..where((r) => r.chatId.equals(s.chatId) & r.messageId.equals(s.messageId)))
        .write(changes.copyWith(
      tagsAt: tags ? Value(laterStamp(now, s.tagsAt)) : const Value.absent(),
      favoriteAt: favorite ? Value(laterStamp(now, s.favoriteAt)) : const Value.absent(),
    ));
    if (touched || favorite || changes.moodScannedAt.present || changes.lastPlayedAt.present || changes.coverAt.present) {
      _markChanged();
    }
  }

  /// `{"id": chatId or null, "at": when it was chosen}`, newest wins between devices.
  static const mainChatKey = 'main_chat';

  Future<int?> mainChatId() async => parseMainChat(await pref(mainChatKey));

  Future<void> setMainChat(int? id) async {
    await setPref(mainChatKey, jsonEncode({'id': id, 'at': DateTime.now().millisecondsSinceEpoch}));
    _markChanged();
  }

  Future<void> deleteSong(int chatId, int messageId) => (delete(songs)
        ..where((s) => s.chatId.equals(chatId) & s.messageId.equals(messageId)))
      .go();

  /// Songs on the same album by the same lead artist, including [s]. Empty if it
  /// has no album. The artist matters: many artists have a "Greatest Hits".
  Future<List<Song>> albumOf(Song s, bool Function(Song a, Song b) sameArtist) async {
    if (s.album.isEmpty) return const [];
    final rows = await (select(songs)..where((r) => r.album.equals(s.album))).get();
    return rows.where((r) => sameArtist(r, s)).toList();
  }

  Future<void> setMoodVote(Song s, String mood, int vote) async {
    await into(moodVotes).insertOnConflictUpdate(
      MoodVotesCompanion.insert(
        chatId: s.chatId,
        messageId: s.messageId,
        mood: mood,
        vote: vote,
        at: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _markChanged();
  }

  Stream<List<MoodVote>> watchMoodVotes() => select(moodVotes).watch();

  /// The next song whose lyrics and genre haven't been looked up.
  Future<Song?> nextForMoodScan() => (select(songs)
        ..where((s) => s.moodScannedAt.equals(0))
        ..limit(1))
      .getSingleOrNull();

  /// How many songs have been looked up, for the Home page to know it's learning.
  Stream<int> watchMoodScanned() {
    final count = countAll(filter: songs.moodScannedAt.isBiggerThanValue(0));
    return (selectOnly(songs)..addColumns([count])).watchSingle().map((r) => r.read(count) ?? 0);
  }

  /// Counts a song as finished or skipped. Local only: other devices take the higher count.
  Future<void> countPlay(Song s, {required bool finished}) => customUpdate(
        finished
            ? 'UPDATE songs SET plays = plays + 1 WHERE chat_id = ? AND message_id = ?'
            : 'UPDATE songs SET skips = skips + 1 WHERE chat_id = ? AND message_id = ?',
        variables: [Variable(s.chatId), Variable(s.messageId)],
        updates: {songs},
      );

  /// Adds listening growth for this device.
  Future<void> addListen(String origin, String day, String key, int ms, int plays) => customInsert(
        'INSERT INTO listen_stats (origin, day, track_key, ms, plays) VALUES (?, ?, ?, ?, ?) '
        'ON CONFLICT(origin, day, track_key) DO UPDATE SET ms = ms + excluded.ms, plays = plays + excluded.plays',
        variables: [Variable(origin), Variable(day), Variable(key), Variable(ms), Variable(plays)],
        updates: {listenStats},
      );

  /// Rows from another device: totals only grow, so the larger value wins and re-sending is harmless.
  Future<void> mergeListen(List<Map<String, dynamic>> rows, {required String self}) => transaction(() async {
        for (final r in rows) {
          if (r['o'] == self) continue;
          await customInsert(
            'INSERT INTO listen_stats (origin, day, track_key, ms, plays) VALUES (?, ?, ?, ?, ?) '
            'ON CONFLICT(origin, day, track_key) DO UPDATE SET '
            'ms = MAX(ms, excluded.ms), plays = MAX(plays, excluded.plays)',
            variables: [Variable(r['o']), Variable(r['d']), Variable(r['k']), Variable(r['ms']), Variable(r['p'])],
            updates: {listenStats},
          );
        }
      });

  Future<List<Map<String, dynamic>>> listenRows({String? origin}) async {
    final q = select(listenStats);
    if (origin != null) q.where((t) => t.origin.equals(origin));
    return [
      for (final r in await q.get()) {'o': r.origin, 'd': r.day, 'k': r.trackKey, 'ms': r.ms, 'p': r.plays},
    ];
  }

  /// Per song since [fromDay] (inclusive, `YYYY-MM-DD`), merged over devices, most listened first.
  Future<List<ListenTotal>> listenTotals({String fromDay = '0000-00-00'}) async {
    final rows = await customSelect(
      'SELECT l.track_key AS k, SUM(l.ms) AS ms, SUM(l.plays) AS plays, s.title AS title, s.artist AS artist '
      'FROM listen_stats l LEFT JOIN songs s ON s.unique_id = l.track_key '
      'WHERE l.day >= ? GROUP BY l.track_key ORDER BY ms DESC',
      variables: [Variable(fromDay)],
      readsFrom: {listenStats, songs},
    ).get();
    return [
      for (final r in rows)
        ListenTotal(r.read<String>('k'), r.read<int>('ms'), r.read<int>('plays'), r.readNullable<String>('title'),
            r.readNullable<String>('artist')),
    ];
  }

  Future<Map<String, int>> listenPerDay({String fromDay = '0000-00-00'}) async {
    final rows = await customSelect(
      'SELECT day, SUM(ms) AS ms FROM listen_stats WHERE day >= ? GROUP BY day ORDER BY day',
      variables: [Variable(fromDay)],
      readsFrom: {listenStats},
    ).get();
    return {for (final r in rows) r.read<String>('day'): r.read<int>('ms')};
  }

  Future<void> setCachedBytes(String uniqueId, int bytes) =>
      (update(songs)..where((s) => s.uniqueId.equals(uniqueId)))
          .write(SongsCompanion(cachedBytes: Value(bytes)));

  /// Facts about the file, the same on every device, so nothing is stamped.
  Future<void> setAudioDetails(String uniqueId, {int? sampleRate, int? bitDepth, String? codec}) =>
      (update(songs)..where((s) => s.uniqueId.equals(uniqueId))).write(
        SongsCompanion(sampleRate: Value(sampleRate), bitDepth: Value(bitDepth), codec: Value(codec)),
      );

  Future<List<Song>> cachedSongs() =>
      (select(songs)..where((s) => s.cachedBytes.isBiggerThanValue(0))).get();

  /// Saves a song the bot has seen. An existing row keeps its tags and only
  /// refreshes its remote id and topic. A repeat of a file already listed under
  /// another post is remembered as a copy.
  ///
  /// A transaction, so a post being moved can't be seen half way and recorded as a
  /// copy of itself.
  ///
  /// True only when this made a song the library didn't have. A post of a song it already
  /// lists, as the bot's own copies are, returns false.
  Future<bool> upsertBotSong(SongsCompanion s) => transaction(() async {
        final updated = await (update(songs)
              ..where((r) => r.chatId.equals(s.chatId.value) & r.messageId.equals(s.messageId.value)))
            .write(SongsCompanion(remoteId: s.remoteId, topicId: s.topicId));
        if (updated > 0) return false;
        final listed = await songByUniqueId(s.uniqueId.value);
        if (listed == null) {
          await into(songs).insert(s, mode: InsertMode.insertOrIgnore);
          return true;
        }
        await into(postCopies).insertOnConflictUpdate(
          PostCopiesCompanion.insert(
            chatId: s.chatId.value,
            messageId: s.messageId.value,
            uniqueId: s.uniqueId.value,
            fileName: s.fileName.value,
            size: s.size.value,
            topicId: s.topicId,
            date: s.date.value,
          ),
        );
        return false;
      });

  /// Moves a chat's "read up to here" mark forward, never back, and only once a whole read
  /// of it has finished: before that, jumping ahead would skip posts nobody has read.
  Future<void> advanceScanned(int chatId, int messageId) => customUpdate(
        'UPDATE library_chats SET last_scanned_message_id = ? '
        'WHERE id = ? AND walk_done = 1 AND COALESCE(last_scanned_message_id, 0) < ?',
        variables: [Variable(messageId), Variable(chatId), Variable(messageId)],
        updates: {libraryChats},
      );

  Future<Song?> songByUniqueId(String uniqueId) =>
      (select(songs)..where((r) => r.uniqueId.equals(uniqueId))).getSingleOrNull();

  /// [s]'s file has been posted again, as [messageId]. The file is the same, so its
  /// one row carries on under the new post with its tags, cover, favorite and counts.
  /// Playlists keep their order, and the new post stops counting as a duplicate.
  Future<void> movePostTo(Song s, {required int messageId, required String remoteId, required int topicId}) async {
    await transaction(() async {
      await (delete(postCopies)..where((c) => c.chatId.equals(s.chatId) & c.messageId.equals(messageId))).go();
      await (update(songs)..where((r) => r.chatId.equals(s.chatId) & r.messageId.equals(s.messageId))).write(
        SongsCompanion(messageId: Value(messageId), remoteId: Value(remoteId), topicId: Value(topicId)),
      );
      await (update(moodVotes)..where((v) => v.chatId.equals(s.chatId) & v.messageId.equals(s.messageId)))
          .write(MoodVotesCompanion(messageId: Value(messageId)));
      await _moveEntries(s.chatId, s.messageId, s.chatId, messageId, keepOrder: true);
    });
    _markChanged();
  }

  /// Lists [s] under its new post in another chat. Its old post is still there, so it
  /// becomes a repeat of the file. Playlists, votes and tags follow.
  Future<void> listAtCopy(
    Song s, {
    required int chatId,
    required int messageId,
    required String remoteId,
    required int? topicId,
  }) async {
    await transaction(() async {
      await (delete(postCopies)..where((c) => c.chatId.equals(chatId) & c.messageId.equals(messageId))).go();
      await into(postCopies).insertOnConflictUpdate(
        PostCopiesCompanion.insert(
          chatId: s.chatId,
          messageId: s.messageId,
          uniqueId: s.uniqueId,
          fileName: s.fileName,
          size: s.size,
          topicId: Value(s.topicId),
          date: s.date,
        ),
      );
      await (update(songs)..where((r) => r.chatId.equals(s.chatId) & r.messageId.equals(s.messageId))).write(
        SongsCompanion(
          chatId: Value(chatId),
          messageId: Value(messageId),
          remoteId: Value(remoteId),
          topicId: Value(topicId),
        ),
      );
      await (update(moodVotes)..where((v) => v.chatId.equals(s.chatId) & v.messageId.equals(s.messageId)))
          .write(MoodVotesCompanion(chatId: Value(chatId), messageId: Value(messageId)));
      await _moveEntries(s.chatId, s.messageId, chatId, messageId, keepOrder: true);
    });
    _markChanged();
  }

  static const _extraPostsKey = 'extra_bot_posts';

  /// Posts an extra bot made as `chat:message`. The main bot can't read those, so a scan
  /// that doesn't see one proves nothing about it.
  Future<Set<String>> extraBotPosts() async {
    final raw = await pref(_extraPostsKey);
    return raw == null ? {} : {...(jsonDecode(raw) as List).cast<String>()};
  }

  Future<void> markExtraBotPost(int chatId, int messageId) async {
    final posts = await extraBotPosts();
    if (posts.add('$chatId:$messageId')) await setPref(_extraPostsKey, jsonEncode(posts.toList()));
  }

  /// Songs deleted on purpose, by unique id with when. Devices share it, so a song deleted
  /// on one doesn't come back from another that still lists it.
  static const goneKey = 'deleted_songs';

  /// A post was deleted in Telegram, by hand or by anything outside this app. Like
  /// [removePost], and when no post of the song remains it is remembered as deleted on
  /// purpose: otherwise a device that was offline still lists it and brings it back.
  Future<void> postDeleted(int chatId, int messageId) async {
    final row = await song(chatId, messageId);
    await removePost(chatId, messageId);
    if (row == null || await songByUniqueId(row.uniqueId) != null) return;
    final raw = await pref(goneKey);
    final gone = raw == null ? <String, int>{} : (jsonDecode(raw) as Map).cast<String, int>();
    gone[row.uniqueId] = DateTime.now().millisecondsSinceEpoch;
    await setPref(goneKey, jsonEncode(gone));
    _markChanged();
  }

  /// A post is gone from Telegram. If it was the listed one and a copy remains,
  /// the copy takes its place, so the song and its playlists survive.
  Future<void> removePost(int chatId, int messageId, {int? preferChat}) => transaction(() async {
        await (delete(postCopies)..where((c) => c.chatId.equals(chatId) & c.messageId.equals(messageId))).go();
        final row = await song(chatId, messageId);
        if (row == null) return;
        final copies = await (select(postCopies)
              ..where((c) => c.uniqueId.equals(row.uniqueId))
              ..orderBy([(c) => OrderingTerm.asc(c.date)]))
            .get();
        // A post in [preferChat] takes over first, then the oldest.
        final copy = copies.where((c) => c.chatId == preferChat).firstOrNull ?? copies.firstOrNull;
        if (copy == null) {
          await deleteSong(chatId, messageId);
          return;
        }
        await (delete(postCopies)..where((c) => c.chatId.equals(copy.chatId) & c.messageId.equals(copy.messageId))).go();
        await (update(songs)..where((r) => r.chatId.equals(chatId) & r.messageId.equals(messageId))).write(
          SongsCompanion(chatId: Value(copy.chatId), messageId: Value(copy.messageId), topicId: Value(copy.topicId)),
        );
        await _moveEntries(chatId, messageId, copy.chatId, copy.messageId);
      });

  /// Forgets a channel here. Nothing changes in Telegram. A song also posted elsewhere
  /// carries on from that post, preferably the one in [preferChat], keeping its tags and
  /// playlists. Returns how many songs were only in this channel and went with it.
  Future<int> removeChat(int chatId, {int? preferChat}) => transaction(() async {
        // Other songs' posts that sit in this channel.
        await (delete(postCopies)..where((c) => c.chatId.equals(chatId))).go();
        var gone = 0;
        for (final s in await songsInChat(chatId)) {
          final elsewhere = await (select(postCopies)..where((c) => c.uniqueId.equals(s.uniqueId))).get();
          if (elsewhere.isEmpty) gone++;
          await removePost(chatId, s.messageId, preferChat: preferChat);
        }
        await (delete(forumTopics)..where((t) => t.chatId.equals(chatId))).go();
        await (delete(libraryChats)..where((c) => c.id.equals(chatId))).go();
        return gone;
      });

  static const chatMarksKey = 'removed_chats';

  /// Which channels were removed, or added back, and when. Devices keep the newest, so a
  /// removal reaches the others and doesn't come back from one that hadn't heard of it.
  Future<Map<int, ({bool gone, int at})>> chatMarks() async {
    final raw = await pref(chatMarksKey);
    if (raw == null) return {};
    return {
      for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
        int.parse(e.key): (gone: (e.value as Map)['gone'] as bool, at: (e.value as Map)['at'] as int),
    };
  }

  Future<void> markChat(int chatId, {required bool gone, int? at}) async {
    final marks = await chatMarks();
    marks[chatId] = (gone: gone, at: at ?? DateTime.now().millisecondsSinceEpoch);
    await setPref(
      chatMarksKey,
      jsonEncode({for (final e in marks.entries) '${e.key}': {'gone': e.value.gone, 'at': e.value.at}}),
    );
    _markChanged();
  }

  /// A channel added again after being removed, so the removal no longer applies.
  Future<void> markChatAdded(int chatId) async {
    if ((await chatMarks())[chatId]?.gone ?? false) await markChat(chatId, gone: false);
  }

  /// Hands [from]'s playlists and favorite to [to], before [from] is deleted.
  Future<void> moveReferences(Song from, Song to) async {
    await transaction(() => _moveEntries(from.chatId, from.messageId, to.chatId, to.messageId));
    // The rows as they are now: the ones passed in may have been read a while ago.
    final loser = await song(from.chatId, from.messageId);
    final keeper = await song(to.chatId, to.messageId);
    if (loser != null && keeper != null && loser.favorite && !keeper.favorite) {
      await updateSong(keeper, const SongsCompanion(favorite: Value(true)));
    }
    if (loser != null && keeper != null) {
      // What a person chose for the song must outlive its post being replaced: a cover
      // picked by hand, and tags edited by hand.
      var carry = const SongsCompanion();
      if (loser.coverPath != null && loser.coverAt > keeper.coverAt) {
        carry = carry.copyWith(
          coverPath: Value(loser.coverPath),
          coverAt: Value(loser.coverAt),
          coverHiRes: Value(loser.coverHiRes),
        );
      }
      if (loser.userEdited && !keeper.userEdited) {
        carry = carry.copyWith(
          title: Value(loser.title),
          artist: Value(loser.artist),
          album: Value(loser.album),
          genre: Value(loser.genre),
          year: Value(loser.year),
          lyrics: Value(loser.lyrics),
          userEdited: const Value(true),
          enrichState: const Value(EnrichState.done),
          tagsAt: Value(DateTime.now().millisecondsSinceEpoch),
        );
      }
      if (carry.toColumns(false).isNotEmpty) {
        await (update(songs)..where((s) => s.chatId.equals(keeper.chatId) & s.messageId.equals(keeper.messageId))).write(carry);
      }
    }
    _markChanged();
  }

  Future<void> _moveEntries(int fromChat, int fromMessage, int toChat, int toMessage, {bool keepOrder = false}) async {
    final entries = await (select(playlistSongs)
          ..where((r) => r.chatId.equals(fromChat) & r.messageId.equals(fromMessage) & r.removedAt.isNull()))
        .get();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in entries) {
      await into(playlistSongs).insertOnConflictUpdate(
        PlaylistSongsCompanion.insert(
          playlistId: e.playlistId,
          chatId: toChat,
          messageId: toMessage,
          addedAt: keepOrder || e.addedAt > now ? e.addedAt : now,
          removedAt: const Value(null),
        ),
      );
      await (update(playlistSongs)
            ..where((r) => r.playlistId.equals(e.playlistId) & r.chatId.equals(fromChat) & r.messageId.equals(fromMessage)))
          .write(PlaylistSongsCompanion(removedAt: Value(now)));
    }
  }

  Stream<List<ForumTopic>> watchTopics() => (select(forumTopics)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .watch();

  Stream<List<Song>> watchTopicSongs(int chatId, int topicId) => (select(songs)
        ..where((s) => s.chatId.equals(chatId) & s.topicId.equals(topicId))
        ..orderBy([(s) => OrderingTerm.desc(s.date)]))
      .watch();

  Future<void> saveTopic(int chatId, int topicId, String name) => into(forumTopics).insertOnConflictUpdate(
        ForumTopicsCompanion.insert(chatId: chatId, topicId: topicId, name: name),
      );

  /// Forgets what mixes learned from listening. Looked-up lyrics and genres are
  /// song facts, so they stay, and Recently played stays as history.
  Future<void> clearLearnedData(int at) async {
    await transaction(() async {
      await clearLearnedRows();
      final current = TasteSettings.parse(await pref(_tasteKey));
      await setPref(_tasteKey, current.copyWith(resetAt: at, at: at).encode());
    });
    _markChanged();
  }

  Future<void> clearLearnedRows() async {
    await customStatement('UPDATE songs SET plays = 0, skips = 0 WHERE plays <> 0 OR skips <> 0');
    await delete(moodVotes).go();
  }

  static const _tasteKey = 'taste_settings';

  Future<TasteSettings> tasteSettings() async => TasteSettings.parse(await pref(_tasteKey));

  Future<void> saveTasteSettings(TasteSettings t) async {
    await setPref(_tasteKey, t.encode());
    _markChanged();
  }

  Future<String?> chatTitle(int chatId) async =>
      (await (select(libraryChats)..where((c) => c.id.equals(chatId))).getSingleOrNull())?.title;

  Future<List<Song>> songsInChat(int chatId) => (select(songs)
        ..where((s) => s.chatId.equals(chatId))
        ..orderBy([(s) => OrderingTerm.asc(s.messageId)]))
      .get();

  Future<List<Song>> cachedSongsIn(int chatId) => (select(songs)
        ..where((s) => s.chatId.equals(chatId) & s.cachedBytes.isBiggerThanValue(0)))
      .get();

  Future<List<Song>> incompletePins() => (select(songs)
        ..where((s) => s.pinned.equals(true) & s.cachedBytes.isSmallerThan(s.size)))
      .get();

  /// A page of songs still waiting for song info, for picking the ones this device owns.
  Future<List<Song>> pendingToEnrich(int offset) => (select(songs)
        ..where((s) => s.enrichState.equals(EnrichState.pending))
        ..limit(100, offset: offset))
      .get();

  /// A page of songs whose lyrics and genre haven't been looked up.
  Future<List<Song>> moodPending(int offset) => (select(songs)
        ..where((s) => s.moodScannedAt.equals(0))
        ..limit(100, offset: offset))
      .get();

  Future<Song?> nextToEnrich() => (select(songs)
        ..where((s) => s.enrichState.equals(EnrichState.pending))
        ..limit(1))
      .getSingleOrNull();

  Future<String?> pref(String key) async =>
      (await (select(prefs)..where((r) => r.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setPref(String key, String value) =>
      into(prefs).insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));

  Future<int> cacheLimit() async => int.tryParse(await pref(_cacheLimitKey) ?? '') ?? defaultCacheLimit;

  Future<void> setCacheLimit(int bytes) => setPref(_cacheLimitKey, '$bytes');

  Future<void> wipe() => transaction(() async {
        for (final t in allTables) {
          await delete(t).go();
        }
      });
}
