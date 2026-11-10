import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/duplicates.dart';
import 'package:teleplayer/library/mood.dart';
import 'package:teleplayer/library/scanner.dart';
import 'package:teleplayer/library/taste.dart';
import 'package:teleplayer/sync/library_sync.dart';

Song _song(int id, {String title = 'T', String artist = 'A', String? genre, int duration = 200, int size = 100, String mime = 'audio/mpeg', int? topic, String? lyrics, String? unique}) => Song(
      chatId: 1,
      messageId: id,
      uniqueId: unique ?? 'u$id',
      remoteId: 'r$id',
      title: title,
      artist: artist,
      album: '',
      durationSec: duration,
      size: size,
      mime: mime,
      fileName: 'f$id',
      date: id,
      genre: genre,
      lyrics: lyrics,
      favorite: false,
      coverHiRes: false,
      userEdited: false,
      enrichState: 1,
      cachedBytes: 0,
      pinned: false,
      tagsAt: 0,
      favoriteAt: 0,
      coverAt: 0,
      instrumental: false,
      moodScannedAt: 0,
      plays: 0,
      skips: 0,
      topicId: topic,
    );

Map<String, dynamic> _message(int id, {int topic = 777, String unique = 'same'}) => {
      'id': id,
      'chat_id': 1,
      'date': id,
      'topic_id': {'@type': 'messageTopicForum', 'forum_topic_id': topic},
      'content': {
        '@type': 'messageAudio',
        'audio': {
          'title': 'Song',
          'performer': 'Artist',
          'file_name': 'song.flac',
          'duration': 100,
          'mime_type': 'audio/flac',
          'audio': {
            'size': 50,
            'expected_size': 50,
            'remote': {'unique_id': unique, 'id': 'remote$id'},
          },
        },
      },
    };

void main() {
  group('settings', () {
    test('survive being saved, and bad text gives the defaults', () {
      const t = TasteSettings(at: 5, resetAt: 3, sources: {'a': false}, topicNames: {'b': 'B'}, learnFromPlays: true);
      final back = TasteSettings.parse(t.encode());
      expect(back.at, 5);
      expect(back.resetAt, 3);
      expect(back.learnsFrom('a'), isFalse);
      expect(back.topicNames['b'], 'B');
      expect(back.learnFromPlays, isTrue);
      expect(TasteSettings.parse('not json').showMixes, isTrue);
    });

    test('everything is learned from by default, except the General topic', () {
      const t = TasteSettings();
      expect(t.learnsFrom(TasteSettings.topicKey(1, 777)), isTrue);
      expect(t.learnsFrom(TasteSettings.topicKey(1, generalTopicId)), isFalse);
      expect(t.learnsFrom(TasteSettings.favoritesKey), isTrue);
    });

    test('plays and skips don\'t teach anything unless turned on', () {
      expect(const TasteSettings().learnFromPlays, isFalse);
    });

    test('a list\'s name says what it\'s for, in your own words', () {
      expect(moodsForListName('Sad Songs'), {'sad'});
      expect(moodsForListName('Calm'), {'chill'});
      expect(moodsForListName('Anime Lofi'), {'chill', 'focus'});
      expect(moodsForListName('Phonk'), {'workout', 'drive'});
      expect(moodsForListName('Im feeling good'), {'happy'});
      expect(moodsForListName('Bollywood'), isEmpty);
      expect(moodsForListName('Work Playlist'), isEmpty, reason: 'often a leftover name');
    });
  });

  group('learning from lists', () {
    final now = DateTime(2026, 11, 6, 15);
    final library = [for (var i = 0; i < 200; i++) _song(i, artist: 'Artist $i', genre: i < 100 ? 'Rock' : 'Jazz')];

    test('a song in someone\'s Sad list goes in the Sad mix, whatever its lyrics say', () {
      final mine = library.sublist(0, 25);
      final mixes = buildDailyMixes(
        songs: library,
        now: now,
        lists: [TasteList('Sad Songs', {for (final s in mine) s.uniqueId})],
      );
      final sad = mixes.firstWhere((m) => m.mood.id == 'sad').songs;
      final ids = {for (final s in mine) s.uniqueId};
      expect(sad.where((s) => ids.contains(s.uniqueId)).length / sad.length, greaterThan(0.7));
    });

    test('play counts change nothing while learning from them is off', () {
      List<String> ids(List<Song> songs, {bool learn = false}) =>
          buildDailyMixes(songs: songs, now: now, options: TasteSettings(learnFromPlays: learn), lists: [
            TasteList('Rock', {for (final s in songs.take(30)) s.uniqueId}),
          ]).first.songs.map((s) => s.uniqueId).toList();
      final played = [
        for (final s in library) s.copyWith(skips: s.messageId.isEven ? 50 : 0),
      ];
      expect(ids(played), ids(library));
      expect(ids(played, learn: true), isNot(ids(library)));
    });

    test('can be limited to songs from the lists', () {
      final mine = {for (final s in library.take(40)) s.uniqueId};
      final mixes = buildDailyMixes(
        songs: library,
        now: now,
        options: const TasteSettings(onlyFromLists: true),
        lists: [TasteList('Mine', mine)],
      );
      expect(mixes, isNotEmpty);
      expect(mixes.expand((m) => m.songs).every((s) => mine.contains(s.uniqueId)), isTrue);
    });

    test('an artist from your lists is likelier than a stranger, even in other songs', () {
      final model = TasteModel.build(
        [TasteList('Mine', {'u0', 'u1', 'u2'})],
        [_song(0, artist: 'Ann'), _song(1, artist: 'Ann'), _song(2, artist: 'Ann'), _song(3, artist: 'Ann'), _song(4, artist: 'Bob')],
      );
      expect(model.scoreOf(_song(3, artist: 'Ann')), greaterThan(model.scoreOf(_song(4, artist: 'Bob'))));
      expect(model.scoreOf(_song(0, artist: 'Ann')), greaterThan(model.scoreOf(_song(3, artist: 'Ann'))));
    });

    test('with no lists, nobody is favoured', () {
      final model = TasteModel.build(const [], [_song(1)]);
      expect(model.scoreOf(_song(1)), model.scoreOf(_song(2, artist: 'Other')));
    });
  });

  group('clearing what was learned', () {
    late AppDb a, b;
    SongsCompanion row(int id) => SongsCompanion.insert(
          chatId: 1,
          messageId: id,
          uniqueId: 'u$id',
          remoteId: 'r$id',
          title: 't',
          artist: 'a',
          size: 1,
          mime: 'audio/mpeg',
          fileName: 'f',
          date: 0,
        );

    setUp(() async {
      a = AppDb(NativeDatabase.memory());
      b = AppDb(NativeDatabase.memory());
      await a.into(a.songs).insert(row(1));
      await b.into(b.songs).insert(row(1));
      for (final db in [a, b]) {
        final s = (await db.song(1, 1))!;
        await db.countPlay(s, finished: true);
        await db.countPlay(s, finished: false);
        await db.setMoodVote(s, 'sad', -1);
      }
    });
    tearDown(() async {
      await a.close();
      await b.close();
    });

    test('removes counts and verdicts here, but keeps looked-up facts', () async {
      await a.updateSong((await a.song(1, 1))!, const SongsCompanion(lyrics: Value('words'), moodScannedAt: Value(9)));
      await a.clearLearnedData(100);
      final s = (await a.song(1, 1))!;
      expect([s.plays, s.skips], [0, 0]);
      expect(await a.select(a.moodVotes).get(), isEmpty);
      expect(s.lyrics, 'words');
      expect(s.moodScannedAt, 9);
      expect(TasteSettings.parse(await a.pref('taste_settings')).resetAt, 100);
    });

    test('reaches the other device, and its older counts can\'t come back', () async {
      await a.clearLearnedData(100);
      // The other device's snapshot left before it heard about the clearing.
      final stale = await librarySnapshot(b);
      await mergeSnapshot(a, stale);
      final onA = (await a.song(1, 1))!;
      expect([onA.plays, onA.skips], [0, 0], reason: 'older counts are ignored');
      expect(await a.select(a.moodVotes).get(), isEmpty);

      await mergeSnapshot(b, await librarySnapshot(a));
      final onB = (await b.song(1, 1))!;
      expect([onB.plays, onB.skips], [0, 0]);
      expect(await b.select(b.moodVotes).get(), isEmpty);
    });
  });

  group('scanning posts', () {
    late AppDb db;
    setUp(() => db = AppDb(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a song\'s topic is read from its message', () {
      expect(topicIdOf(_message(1)), 777);
      expect(topicIdOf({'id': 2}), isNull);
    });

    test('a repeat post is remembered, not dropped, and only once', () async {
      await db.upsertBotSong(songFromMessage(_message(1, topic: 5))!);
      await db.upsertBotSong(songFromMessage(_message(2, topic: 6))!);
      await db.upsertBotSong(songFromMessage(_message(2, topic: 6))!);
      expect((await db.select(db.songs).get()).single.messageId, 1);
      final copy = (await db.select(db.postCopies).get()).single;
      expect(copy.messageId, 2);
      expect(copy.topicId, 6);
    });

    test('when the listed post goes, a copy takes over with its playlists', () async {
      await db.upsertBotSong(songFromMessage(_message(1))!);
      await db.upsertBotSong(songFromMessage(_message(2))!);
      final id = await db.createPlaylist('Mix');
      await db.addToPlaylist(id, (await db.song(1, 1))!);
      await db.removePost(1, 1);
      expect((await db.select(db.songs).getSingle()).messageId, 2);
      expect(await db.select(db.postCopies).get(), isEmpty);
      expect((await db.watchPlaylistSongs(id).first).single.messageId, 2);
    });

    test('when a repeat goes, only its record does', () async {
      await db.upsertBotSong(songFromMessage(_message(1))!);
      await db.upsertBotSong(songFromMessage(_message(2))!);
      await db.removePost(1, 2);
      expect((await db.select(db.songs).getSingle()).messageId, 1);
      expect(await db.select(db.postCopies).get(), isEmpty);
    });

    test('moving a deleted song hands its playlists and favorite to the keeper', () async {
      await db.upsertBotSong(songFromMessage(_message(1, unique: 'x'))!);
      await db.upsertBotSong(songFromMessage(_message(2, unique: 'y'))!);
      final loser = (await db.song(1, 1))!, keeper = (await db.song(1, 2))!;
      await db.updateSong(loser, const SongsCompanion(favorite: Value(true)));
      final id = await db.createPlaylist('Mix');
      await db.addToPlaylist(id, loser);
      await db.moveReferences(loser, keeper);
      expect((await db.song(1, 2))!.favorite, isTrue);
      expect((await db.watchPlaylistSongs(id).first).single.messageId, 2);
    });
  });

  group('finding duplicates', () {
    PostCopy copy(int id, String unique, {int? topic}) =>
        PostCopy(chatId: 1, messageId: id, uniqueId: unique, fileName: 'f$id', size: 100, topicId: topic, date: id);

    test('the same file twice in one topic is suggested for deletion', () {
      final g = findDuplicates([_song(1, topic: 5)], [copy(2, 'u1', topic: 5)]).single;
      expect(g.kind, DuplicateKind.sameFile);
      expect(g.keep.messageId, 1);
      expect(g.suggested, {2});
    });

    test('the same file in another topic is flagged, but not suggested', () {
      final g = findDuplicates([_song(1, topic: 5)], [copy(2, 'u1', topic: 6)]).single;
      expect(g.others.single.messageId, 2);
      expect(g.suggested, isEmpty);
    });

    test('a FLAC and an MP3 of one song: keep the FLAC, suggest the MP3', () {
      final g = findDuplicates([
        _song(1, title: 'Song', artist: 'Ann', mime: 'audio/mpeg', size: 10, topic: 5),
        _song(2, title: 'Song', artist: 'Ann', mime: 'audio/flac', size: 90, topic: 5),
      ], const []).single;
      expect(g.kind, DuplicateKind.likelySameSong);
      expect(g.keep.messageId, 2);
      expect(g.suggested, {1});
    });

    test('two similar copies are flagged, but neither is suggested', () {
      final g = findDuplicates([
        _song(1, title: 'Song', artist: 'Ann', size: 100),
        _song(2, title: 'Song', artist: 'Ann', size: 95),
      ], const []).single;
      expect(g.suggested, isEmpty);
    });

    test('different versions and lengths aren\'t duplicates', () {
      expect(
        findDuplicates([
          _song(1, title: 'Song', artist: 'Ann', duration: 200),
          _song(2, title: 'Song (Remix)', artist: 'Ann', duration: 200),
          _song(3, title: 'Song', artist: 'Bob', duration: 200),
          _song(4, title: 'Song', artist: 'Ann', duration: 400),
        ], const []),
        isEmpty,
      );
    });

    test('songs of unknown length are never matched by name alone', () {
      expect(
        findDuplicates([_song(1, title: 'Song', duration: 0), _song(2, title: 'Song', duration: 0)], const []),
        isEmpty,
      );
    });
  });
}
