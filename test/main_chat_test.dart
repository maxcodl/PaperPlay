import 'dart:typed_data';

import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teleplayer/activity.dart';
import 'package:teleplayer/library/audio_info.dart';
import 'package:teleplayer/metadata/cover_sources.dart';
import 'package:teleplayer/library/auto_filer.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/duplicates.dart';
import 'package:teleplayer/library/missing_info.dart';
import 'package:teleplayer/library/restore.dart';
import 'package:teleplayer/library/taste.dart';
import 'package:teleplayer/library/topic_sort.dart';
import 'package:teleplayer/log.dart';
import 'package:teleplayer/playback/player.dart' show sameToShow;
import 'package:teleplayer/sync/library_sync.dart';
import 'package:teleplayer/telegram/td_client.dart';

const _main = 100, _other = 200, _rock = 7;

Song _song(
  int chat,
  int id, {
  String? unique,
  String? title,
  String artist = 'Artist',
  int? topic,
  int moodScannedAt = 1,
  String fileName = 'a.mp3',
  int size = 1000,
  int durationSec = 100,
}) =>
    Song(
      chatId: chat,
      messageId: id,
      uniqueId: unique ?? 'u$chat-$id',
      remoteId: 'r',
      title: title ?? 'Song $chat-$id',
      artist: artist,
      album: '',
      durationSec: durationSec,
      size: size,
      mime: 'audio/mpeg',
      fileName: fileName,
      date: 0,
      favorite: false,
      coverHiRes: false,
      userEdited: false,
      enrichState: EnrichState.done,
      cachedBytes: 0,
      pinned: false,
      tagsAt: 0,
      favoriteAt: 0,
      coverAt: 0,
      instrumental: false,
      moodScannedAt: moodScannedAt,
      plays: 0,
      skips: 0,
      topicId: topic,
    );

SongsCompanion _row(int chat, int id, String unique, {int tagsAt = 0, bool edited = false, String? lyrics}) =>
    SongsCompanion.insert(
      chatId: chat,
      messageId: id,
      uniqueId: unique,
      remoteId: 'r',
      title: 'Title $unique',
      artist: 'Artist',
      size: 1,
      mime: 'audio/mpeg',
      fileName: 'a.mp3',
      date: 0,
      tagsAt: Value(tagsAt),
      userEdited: Value(edited),
      lyrics: Value(lyrics),
    );

void main() {
  group('filing into the main chat', () {
    const topics = [TopicChoice(generalTopicId, 'General'), TopicChoice(_rock, 'Rock')];

    List<MoveJobView> plan(List<Song> songs, {List<PostCopy> copies = const [], bool canDelete = true}) => [
          for (final j in planFiling(
            mainChat: _main,
            songs: songs,
            copies: copies,
            topics: topics,
            ready: (s) => s.moodScannedAt > 0,
            canDelete: canDelete,
          ))
            MoveJobView(j.song.uniqueId, j.topicId, j.toChat),
        ];

    // Three songs by this artist in Rock make any more of theirs clearly Rock.
    final filed = [for (var i = 1; i <= 3; i++) _song(_main, i, artist: 'Band', topic: _rock)];

    test('a song keeps the topic name it had in its old channel', () {
      final jobs = planFiling(
        mainChat: _main,
        songs: [...filed, _song(_other, 9, artist: 'Nobody', unique: 'x')],
        copies: const [],
        topics: topics,
        ready: (_) => true,
        origin: const {'x': 'rock'},
      );
      expect([for (final j in jobs) MoveJobView(j.song.uniqueId, j.topicId, j.toChat)], [
        const MoveJobView('x', _rock, _main),
      ]);
    });

    test('a song from another channel is copied to the topic that fits', () {
      final jobs = plan([...filed, _song(_other, 9, artist: 'Band', unique: 'x')]);
      expect(jobs, [const MoveJobView('x', _rock, _main)]);
    });

    test('a song already in the main chat in another file is not copied again', () {
      final there = _song(_main, 4, title: 'Husn', artist: 'Band', topic: _rock);
      expect(plan([...filed, there, _song(_other, 9, title: 'Husn', artist: 'Band', unique: 'x')]), isEmpty);
    });

    test('of several versions in another channel, only the largest is copied', () {
      final jobs = plan([
        ...filed,
        _song(_other, 9, title: 'Husn', artist: 'Band', unique: 'x', size: 1000),
        _song(_other, 10, title: 'Husn', artist: 'Band', unique: 'y', size: 5000),
      ]);
      expect(jobs, [const MoveJobView('y', _rock, _main)]);
    });

    test('a song it can\'t place stays in its own channel, not General', () {
      expect(plan([...filed, _song(_other, 9, artist: 'Nobody', unique: 'x')]),
          [const MoveJobView('x', generalTopicId, _main)]);
    });

    test('a chat without topics gets every song from the other channels', () {
      final jobs = planFiling(
        mainChat: _main,
        songs: [_song(_other, 9, artist: 'Nobody', unique: 'x'), _song(_other, 10, unique: 'y')],
        copies: const [],
        topics: const [TopicChoice(generalTopicId, 'General')],
        ready: (_) => true,
      );
      expect([for (final j in jobs) MoveJobView(j.song.uniqueId, j.topicId, j.toChat)], [
        const MoveJobView('x', generalTopicId, _main),
        const MoveJobView('y', generalTopicId, _main),
      ]);
    });

    test('a song already in the main chat as a copy isn\'t posted again', () {
      final copy = const PostCopy(chatId: _main, messageId: 50, uniqueId: 'x', fileName: 'a.mp3', size: 1, date: 0);
      expect(plan([...filed, _song(_other, 9, artist: 'Band', unique: 'x')], copies: [copy]), isEmpty);
    });

    test('a song in General moves only to a clear topic, and is left when unclear', () {
      final jobs = plan([
        ...filed,
        _song(_main, 10, artist: 'Band', unique: 'clear', topic: generalTopicId),
        _song(_main, 11, artist: 'Nobody', unique: 'unclear', topic: generalTopicId),
      ]);
      expect(jobs, [const MoveJobView('clear', _rock, null)]);
    });

    test('without the right to delete, General songs stay rather than repeat', () {
      final jobs = plan([...filed, _song(_main, 10, artist: 'Band', topic: generalTopicId)], canDelete: false);
      expect(jobs, isEmpty);
    });

    test('a song still waiting on lookups isn\'t filed yet', () {
      expect(plan([...filed, _song(_other, 9, artist: 'Band', moodScannedAt: 0)]), isEmpty);
    });
  });

  group('fallback sources for covers and info', () {
    test('a busy server is asked again, a missing file isn\'t', () async {
      var calls = 0;
      final busy = MockClient((_) async => ++calls < 3 ? http.Response('', 500) : http.Response('art', 200));
      final got = await fetchWithRetry(busy, Uri.parse('https://x/y'), delays: const [Duration.zero, Duration.zero]);
      expect(got, isNotNull);
      expect(calls, 3);

      calls = 0;
      int? last;
      final gone = MockClient((_) async {
        calls++;
        return http.Response('', 404);
      });
      expect(await fetchWithRetry(gone, Uri.parse('https://x/y'), onFailure: (s) => last = s), isNull);
      expect([calls, last], [1, 404], reason: '404 means it isn\'t there, so no retry');

      calls = 0;
      final down = MockClient((_) async {
        calls++;
        return http.Response('', 503);
      });
      expect(await fetchWithRetry(down, Uri.parse('https://x/y'), delays: const [Duration.zero]), isNull);
      expect(calls, 2, reason: 'one retry, then it gives up');
    });

    test('finds the album behind a release', () {
      expect(releaseGroupOf({'id': 'r', 'release-group': {'id': 'g'}}), 'g');
      expect(releaseGroupOf({'id': 'r'}), isNull);
    });

    test('other iTunes countries are tried, Japan first for Japanese songs', () {
      expect(extraStorefronts('Sajni', 'Arijit Singh'), ['IN']);
      expect(extraStorefronts('紅蓮華', 'LiSA'), ['IN'], reason: 'kanji alone could be Chinese, so Japan isn\'t assumed');
      expect(extraStorefronts('残酷な天使のテーゼ', '高橋洋子'), ['JP', 'IN']);
    });

    test('a file\'s own tags fill gaps only, and never touch an edited song', () {
      const tags = EmbeddedTags(artist: 'Real Artist', album: 'Real Album', year: 2019, genre: 'Pop');
      final bare = _song(_main, 1, artist: 'Unknown artist');
      final fill = fillFromTags(bare, tags)!;
      expect(fill.album.value, 'Real Album');
      expect(fill.year.value, 2019);
      expect(fill.genre.value, 'Pop');
      expect(fill.artist.value, 'Real Artist');
      expect(fill.metadataSource.value, 'File tags');

      // What an online match already found stays.
      final matched = bare.copyWith(album: 'Online Album', genre: const Value('Rock'), artist: 'Online Artist');
      final partial = fillFromTags(matched, tags)!;
      expect(partial.album.present, isFalse);
      expect(partial.genre.present, isFalse);
      expect(partial.artist.present, isFalse);
      expect(partial.year.value, 2019);

      expect(fillFromTags(bare.copyWith(userEdited: true), tags), isNull);
      expect(fillFromTags(matched.copyWith(year: const Value(2000), genre: const Value('Rock')), tags), isNull);
      expect(fillFromTags(bare, const EmbeddedTags(year: 1066)), isNull, reason: 'an impossible year is ignored');
    });
  });

  group('reading a chat', () {
    late AppDb db;
    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      await db.into(db.libraryChats).insert(
            LibraryChatsCompanion.insert(
              id: const Value(_main),
              title: 'Main',
              lastScannedMessageId: const Value(100),
              walkDone: const Value(true),
            ),
          );
    });
    tearDown(() => db.close());

    SongsCompanion post(int chat, int id, String unique) => SongsCompanion.insert(
          chatId: chat,
          messageId: id,
          uniqueId: unique,
          remoteId: 'r',
          title: 'T',
          artist: 'A',
          size: 1,
          mime: 'audio/mpeg',
          fileName: 'a.mp3',
          date: 0,
        );

    test('only a song the library didn\'t have counts as new', () async {
      expect(await db.upsertBotSong(post(_other, 1, 'a')), isTrue);
      expect(await db.upsertBotSong(post(_other, 1, 'a')), isFalse, reason: 'the same post again');
      expect(await db.upsertBotSong(post(_main, 9, 'a')), isFalse, reason: 'the bot\'s own copy of a listed file');
      expect((await db.select(db.songs).get()).length, 1);
      expect((await db.select(db.postCopies).getSingle()).messageId, 9);
    });

    test('a post heard live moves the mark forward, never back, and not before a full read', () async {
      await db.advanceScanned(_main, 150);
      expect((await db.select(db.libraryChats).getSingle()).lastScannedMessageId, 150);
      await db.advanceScanned(_main, 120);
      expect((await db.select(db.libraryChats).getSingle()).lastScannedMessageId, 150);

      await (db.update(db.libraryChats)).write(const LibraryChatsCompanion(walkDone: Value(false)));
      await db.advanceScanned(_main, 500);
      expect((await db.select(db.libraryChats).getSingle()).lastScannedMessageId, 150,
          reason: 'a chat not fully read yet would skip what\'s between');
    });
  });

  group('what the app says it is doing', () {
    test('idle says so', () {
      final a = summarizeActivity(const ActivityInputs());
      expect([a.busy, a.title], [false, 'Paper Play is running']);
    });

    test('covers read as left of total, with a progress to draw', () {
      final a = summarizeActivity(const ActivityInputs(coversLeft: 22, coversBatch: 1300));
      expect(a.title, 'Loading covers: 22 left of 1,300');
      expect([a.done, a.total], [1278, 1300]);
    });

    test('the sync comes first, and everything else is listed under it', () {
      final a = summarizeActivity(
        const ActivityInputs(
          sync: 'Syncing Somg: 400 of 1200 messages, 12 songs added',
          syncFraction: 0.33,
          movesDone: 3,
          movesTotal: 20,
          infoLeft: 100,
          infoTotal: 740,
          infoRunning: true,
          coversLeft: 5,
          coversBatch: 9,
        ),
      );
      expect(a.title, startsWith('Syncing Somg'));
      expect([a.done, a.total], [330, 1000]);
      expect(a.detail.split('\n'), [
        'Filing songs: 3 of 20',
        'Finding song info: 640 of 740, about 5 minutes left',
        'Loading covers: 5 left of 9',
      ]);
    });

    test('paused work says so, and finished work isn\'t listed', () {
      final a = summarizeActivity(
        const ActivityInputs(movesDone: 4, movesTotal: 10, movesPaused: true, uploadsDone: 3, uploadsTotal: 3),
      );
      expect(a.title, 'Filing songs: 4 of 10 (paused)');
      expect(a.detail, isEmpty);
      expect(summarizeActivity(const ActivityInputs(infoLeft: 5, infoTotal: 10, infoPaused: true)).title, startsWith('Song info paused'));
    });

    test('numbers get thousands separators', () {
      expect([thousands(7), thousands(1234), thousands(1234567)], ['7', '1,234', '1,234,567']);
    });

    test('the key changes only when what\'s shown does', () {
      final a = summarizeActivity(const ActivityInputs(coversLeft: 22, coversBatch: 30));
      expect(a.key, summarizeActivity(const ActivityInputs(coversLeft: 22, coversBatch: 30)).key);
      expect(a.key, isNot(summarizeActivity(const ActivityInputs(coversLeft: 21, coversBatch: 30)).key));
    });
  });

  group('what a song still lacks', () {
    Song base() => _song(_main, 1).copyWith(
          album: 'Album',
          year: const Value(2020),
          genre: const Value('Pop'),
          coverPath: const Value('/c.jpg'),
          coverHiRes: true,
          moodScannedAt: 5,
        );

    test('a complete song lacks nothing', () {
      expect(missingOf(base(), lookupsOn: true), isEmpty);
    });

    test('work not done yet is told apart from nothing found', () {
      final fresh = base().copyWith(enrichState: EnrichState.pending, moodScannedAt: 0, coverPath: const Value(null));
      expect(missingOf(fresh, lookupsOn: true), {Missing.waiting, Missing.scanPending, Missing.noCover});
      expect(Missing.values.where((m) => m.todo), [Missing.waiting, Missing.scanPending, Missing.noCover]);

      final searched = base().copyWith(enrichState: EnrichState.noMatch, album: '', year: const Value(null));
      expect(missingOf(searched, lookupsOn: true), {Missing.noMatch, Missing.noAlbum, Missing.noYear});
    });

    test('a song still waiting isn\'t blamed for a missing album or genre', () {
      final pending = base().copyWith(enrichState: EnrichState.pending, album: '', genre: const Value(null));
      expect(missingOf(pending, lookupsOn: true), {Missing.waiting});
    });

    test('with lookups off the lyrics scan isn\'t work that\'s left', () {
      final unscanned = base().copyWith(moodScannedAt: 0);
      expect(missingOf(unscanned, lookupsOn: false), isEmpty);
      expect(missingOf(unscanned, lookupsOn: true), {Missing.scanPending});
    });

    test('a thumbnail only is a small cover, and an unknown artist is flagged', () {
      final thin = base().copyWith(coverHiRes: false, artist: 'Unknown artist');
      expect(missingOf(thin, lookupsOn: true), {Missing.smallCover, Missing.unknownArtist});
      expect(missingOf(thin.copyWith(coverAt: 9), lookupsOn: true), {Missing.unknownArtist}, reason: 'a chosen cover is final');
    });

    test('looking up again queues songs with no match, but not edited ones', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.songs).insert(_row(_main, 1, 'a'));
      await db.into(db.songs).insert(_row(_main, 2, 'b', edited: true));
      for (final id in [1, 2]) {
        await db.customStatement('UPDATE songs SET enrich_state = ${EnrichState.noMatch} WHERE message_id = $id');
      }
      final changed = await (db.update(db.songs)
            ..where((s) => s.enrichState.equals(EnrichState.noMatch) & s.userEdited.equals(false)))
          .write(const SongsCompanion(enrichState: Value(EnrichState.pending)));
      expect(changed, 1);
      expect((await db.song(_main, 2))!.enrichState, EnrichState.noMatch);
    });
  });

  group('waiting for song info', () {
    Song withState(int state, int scanned) =>
        _song(_main, 1, moodScannedAt: scanned).copyWith(enrichState: state);

    test('filed only once the tags are in and, with lookups on, the lyrics and genre', () {
      expect(infoSettled(withState(EnrichState.pending, 0), lookupsOn: true), isFalse);
      expect(infoSettled(withState(EnrichState.done, 0), lookupsOn: true), isFalse);
      expect(infoSettled(withState(EnrichState.done, 5), lookupsOn: true), isTrue);
      expect(infoSettled(withState(EnrichState.noMatch, 5), lookupsOn: true), isTrue, reason: 'nothing found is still an answer');
    });

    test('with lookups off, only the tags are waited for', () {
      expect(infoSettled(withState(EnrichState.pending, 0), lookupsOn: false), isFalse);
      expect(infoSettled(withState(EnrichState.done, 0), lookupsOn: false), isTrue);
    });
  });

  group('duplicates in the main chat only', () {
    test('repeats in other channels are neither shown nor offered', () {
      final groups = findDuplicates(
        [
          _song(_other, 1, unique: 'a', title: 'One'),
          _song(_other, 2, title: 'Two'),
          _song(_other, 3, title: 'Two'),
        ],
        [const PostCopy(chatId: _other, messageId: 4, uniqueId: 'a', fileName: 'a.mp3', size: 1, date: 0)],
        onlyChat: _main,
      );
      expect(groups, isEmpty);
    });

    test('a General copy left behind by a move is offered for removal, one in another topic isn\'t', () {
      final groups = findDuplicates(
        [_song(_main, 1, unique: 'a', topic: _rock)],
        [
          const PostCopy(chatId: _main, messageId: 4, uniqueId: 'a', fileName: 'a.mp3', size: 1, topicId: generalTopicId, date: 0),
          const PostCopy(chatId: _main, messageId: 5, uniqueId: 'a', fileName: 'a.mp3', size: 1, topicId: 99, date: 0),
        ],
        onlyChat: _main,
      );
      expect(groups.single.suggested, {4}, reason: 'the topic copy may be on purpose');
    });

    test('a copy elsewhere of a main chat song isn\'t a repeat', () {
      final groups = findDuplicates(
        [_song(_main, 1, unique: 'a')],
        [const PostCopy(chatId: _other, messageId: 4, uniqueId: 'a', fileName: 'a.mp3', size: 1, date: 0)],
        onlyChat: _main,
      );
      expect(groups, isEmpty);
    });

    test('two main chat posts of a file listed elsewhere keep one of them', () {
      final groups = findDuplicates(
        [_song(_other, 1, unique: 'a')],
        [
          const PostCopy(chatId: _main, messageId: 4, uniqueId: 'a', fileName: 'a.mp3', size: 1, date: 0),
          const PostCopy(chatId: _main, messageId: 5, uniqueId: 'a', fileName: 'a.mp3', size: 1, date: 0),
        ],
        onlyChat: _main,
      );
      final g = groups.single;
      expect([g.keep.chatId, ...g.others.map((o) => o.chatId)], [_main, _main]);
    });
  });

  group('formats and quality', () {
    test('names every common format', () {
      expect(audioFormat('audio/mp4', 'a.m4a'), 'AAC');
      expect(audioFormat('audio/mp4', 'no extension'), 'AAC');
      expect(audioFormat('', 'a.aac'), 'AAC');
      expect(audioFormat('', 'a.OPUS'), 'OPUS');
      expect(audioFormat('', 'a.wv'), 'WV');
      expect(audioFormat('', 'a.xyz'), 'XYZ');
      expect(isLossless('WV'), isTrue);
      expect(isLossless('AAC'), isFalse);
    });

    test('tiers need known values, and Hi-Res is never guessed', () {
      expect(qualityTier('FLAC'), QualityTier.lossless);
      expect(qualityTier('FLAC', sampleRate: 44100, bitDepth: 16), QualityTier.lossless);
      expect(qualityTier('FLAC', sampleRate: 96000), QualityTier.lossless);
      expect(qualityTier('FLAC', sampleRate: 96000, bitDepth: 24), QualityTier.hiRes);
      expect(qualityTier('AAC', kbps: 320), QualityTier.high);
      expect(qualityTier('MP3', kbps: 128), QualityTier.standard);
    });

    test('reads a FLAC header', () {
      // 96000 Hz, 24 bits: 20 bits of rate, 3 of channels, 5 of bits minus one.
      final b = Uint8List(26);
      b.setRange(0, 4, 'fLaC'.codeUnits);
      const rate = 96000;
      b[18] = (rate >> 12) & 0xFF;
      b[19] = (rate >> 4) & 0xFF;
      b[20] = ((rate & 0xF) << 4) | (1 << 1) | ((23 >> 4) & 1);
      b[21] = (23 & 0xF) << 4;
      final h = parseAudioHeader(b)!;
      expect([h.sampleRate, h.bitDepth], [96000, 24]);
    });

    test('reads a WAV header', () {
      final b = Uint8List(44);
      final d = ByteData.sublistView(b);
      b.setRange(0, 4, 'RIFF'.codeUnits);
      b.setRange(8, 12, 'WAVE'.codeUnits);
      b.setRange(12, 16, 'fmt '.codeUnits);
      d.setUint32(16, 16, Endian.little);
      d.setUint32(24, 48000, Endian.little);
      d.setUint16(34, 16, Endian.little);
      final h = parseAudioHeader(b)!;
      expect([h.sampleRate, h.bitDepth], [48000, 16]);
    });

    test('tells ALAC from AAC inside an MP4', () {
      Uint8List mp4(String codec) {
        final b = Uint8List(120);
        b.setRange(10, 14, 'stsd'.codeUnits);
        b.setRange(26, 30, codec.codeUnits);
        ByteData.sublistView(b).setUint16(26 + 22, 16);
        ByteData.sublistView(b).setUint16(26 + 28, 44100);
        return b;
      }

      expect(parseAudioHeader(mp4('alac'))!.codec, 'ALAC');
      expect(parseAudioHeader(mp4('mp4a'))!.codec, isNull);
      expect(parseAudioHeader(mp4('mp4a'))!.sampleRate, 44100);
    });
  });

  group('new device sync', () {
    late AppDb from, to;
    setUp(() {
      from = AppDb(NativeDatabase.memory());
      to = AppDb(NativeDatabase.memory());
    });
    tearDown(() async {
      await from.close();
      await to.close();
    });

    Future<void> addChat(AppDb db, {int? scanned}) => db.into(db.libraryChats).insert(
          LibraryChatsCompanion.insert(id: const Value(_main), title: 'Main', lastScannedMessageId: Value(scanned)),
        );

    test('an empty device gets every song, with tags, topics and how far was read', () async {
      await addChat(from, scanned: 50);
      await from.into(from.songs).insert(_row(_main, 5, 'a', tagsAt: 9, edited: true, lyrics: 'words'));
      // Never touched by anything, so it has no timestamps at all.
      await from.into(from.songs).insert(_row(_main, 6, 'b'));
      await from.saveTopic(_main, _rock, 'Rock');
      await from.setMainChat(_main);

      await mergeSnapshot(to, await librarySnapshot(from));

      final a = (await to.song(_main, 5))!;
      expect([a.userEdited, a.lyrics, a.tagsAt], [true, 'words', 9]);
      expect(await to.song(_main, 6), isNotNull);
      expect((await to.select(to.forumTopics).get()).single.name, 'Rock');
      expect((await to.select(to.libraryChats).getSingle()).lastScannedMessageId, 50);
      expect(await to.mainChatId(), _main);
    });

    test('a song deleted on purpose here doesn\'t come back, others do', () async {
      await addChat(from, scanned: 50);
      await addChat(to, scanned: 50);
      await from.into(from.songs).insert(_row(_main, 5, 'gone'));
      await from.into(from.songs).insert(_row(_main, 60, 'newer'));
      await markSongGone(to, 'gone');

      await mergeSnapshot(to, await librarySnapshot(from));

      expect(await to.song(_main, 5), isNull);
      expect(await to.song(_main, 60), isNotNull);
    });

    test('a song older than what this device read still arrives', () async {
      await addChat(from, scanned: 50);
      await addChat(to, scanned: 50);
      await from.into(from.songs).insert(_row(_main, 5, 'old'));

      await mergeSnapshot(to, await librarySnapshot(from));

      expect(await to.song(_main, 5), isNotNull);
    });

    test('a song whose post no longer exists in Telegram is not taken', () async {
      await addChat(from, scanned: 50);
      await addChat(to, scanned: 50);
      await from.into(from.songs).insert(_row(_main, 5, 'deleted-before'));
      await from.into(from.songs).insert(_row(_main, 6, 'still-there'));

      await mergeSnapshot(to, await librarySnapshot(from), existing: (posts) async => {(_main, 6)});

      expect(await to.song(_main, 5), isNull);
      expect(await to.song(_main, 6), isNotNull);
    });

    test('a deletion made on one device removes the song on the other', () async {
      await addChat(from, scanned: 50);
      await addChat(to, scanned: 50);
      await to.into(to.songs).insert(_row(_main, 5, 'bye'));
      await markSongGone(from, 'bye');

      await mergeSnapshot(to, await librarySnapshot(from));

      expect(await to.song(_main, 5), isNull);
    });

    test('a song listed under a different post here still gets its edits', () async {
      await addChat(from, scanned: 50);
      await addChat(to, scanned: 50);
      await from.into(from.songs).insert(_row(_main, 5, 'same', tagsAt: 9, edited: true));
      await to.into(to.songs).insert(_row(_main, 8, 'same'));

      await mergeSnapshot(to, await librarySnapshot(from));

      expect((await to.song(_main, 8))!.userEdited, isTrue);
      expect(await to.song(_main, 5), isNull);
    });

    test('an automatic write doesn\'t make an old edit beat a newer one', () async {
      await to.into(to.songs).insert(_row(_main, 5, 'a', tagsAt: 1000, edited: true));
      final row = (await to.song(_main, 5))!;
      await to.updateSong(row, const SongsCompanion(lyrics: Value('found later'), moodScannedAt: Value(5)));
      final after = (await to.song(_main, 5))!;
      expect(after.tagsAt, 1000);
      expect(after.lyrics, 'found later');
      await to.updateSong(after, const SongsCompanion(title: Value('New'), userEdited: Value(true)));
      expect((await to.song(_main, 5))!.tagsAt, greaterThan(1000), reason: 'a real edit still counts');
    });

    test('a newer automatic result with a gap doesn\'t erase what\'s known', () async {
      await addChat(from, scanned: 1);
      await addChat(to, scanned: 1);
      await from.into(from.songs).insert(_row(_main, 5, 'a', tagsAt: 20));
      await to.into(to.songs).insert(_row(_main, 5, 'a', tagsAt: 10, lyrics: 'keep me'));

      await mergeSnapshot(to, await librarySnapshot(from));

      final row = (await to.song(_main, 5))!;
      expect(row.tagsAt, 20);
      expect(row.lyrics, 'keep me');
    });
  });

  group('finding songs missing from their channels', () {
    PostCopy copy(int chat, int id) =>
        PostCopy(chatId: chat, messageId: id, uniqueId: 'u$id', fileName: 'a.mp3', size: 1, date: 0);

    test('asks Telegram, and reports only the posts it no longer has', () async {
      final asked = <Map<String, dynamic>>[];
      final result = await missingPosts(
        (r) async {
          asked.add(r);
          final ids = r['message_ids'] as List;
          // Message 2 is gone: Telegram answers null for it.
          return {'messages': [for (final id in ids) id == 2 ? null : <String, dynamic>{'id': id}]};
        },
        [copy(_other, 1), copy(_other, 2), copy(_other, 3), copy(_main, 4)],
        mainChat: _main,
      );
      expect(result.checked, 3, reason: 'the main chat\'s own posts aren\'t asked about');
      expect(result.missing.map((c) => c.messageId), [2]);
      expect(asked.single['chat_id'], _other);
    });

    test('a long list is asked in batches', () async {
      var calls = 0;
      final result = await missingPosts(
        (r) async {
          calls++;
          return {'messages': [for (final id in r['message_ids'] as List) <String, dynamic>{'id': id}]};
        },
        [for (var i = 1; i <= 120; i++) copy(_other, i)],
        mainChat: _main,
      );
      expect(calls, 3);
      expect(result.missing, isEmpty);
      expect(result.checked, 120);
    });
  });

  group('removing a channel', () {
    late AppDb db;
    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      for (final id in [_main, _other]) {
        await db.into(db.libraryChats).insert(LibraryChatsCompanion.insert(id: Value(id), title: 'Chat $id'));
      }
    });
    tearDown(() => db.close());

    Future<List<int>> chatIds(AppDb d) async => [for (final c in await d.select(d.libraryChats).get()) c.id];

    test('songs also in the main chat carry on from it, the rest go, and nothing is left behind', () async {
      await db.into(db.songs).insert(_row(_other, 1, 'both', tagsAt: 5, edited: true));
      await db.into(db.songs).insert(_row(_other, 2, 'only'));
      await db.into(db.postCopies).insert(
            PostCopiesCompanion.insert(chatId: _main, messageId: 9, uniqueId: 'both', fileName: 'a.mp3', size: 1, date: 0),
          );
      await db.saveTopic(_other, 7, 'Rock');
      final list = await db.createPlaylist('Mix');
      await db.addToPlaylist(list, (await db.song(_other, 1))!);

      final gone = await db.removeChat(_other, preferChat: _main);

      expect(gone, 1);
      final both = (await db.songByUniqueId('both'))!;
      expect([both.chatId, both.messageId, both.userEdited], [_main, 9, true]);
      expect(await db.songByUniqueId('only'), isNull);
      expect((await db.watchPlaylistSongs(list).first).single.messageId, 9);
      expect(await chatIds(db), [_main]);
      expect(await db.select(db.forumTopics).get(), isEmpty);
      expect(await db.select(db.postCopies).get(), isEmpty);
    });

    test('a removal reaches other devices, and a later re-add reaches them too', () async {
      final other = AppDb(NativeDatabase.memory());
      addTearDown(other.close);
      for (final id in [_main, _other]) {
        await other.into(other.libraryChats).insert(LibraryChatsCompanion.insert(id: Value(id), title: 'Chat $id'));
      }

      await db.removeChat(_other);
      await db.markChat(_other, gone: true, at: 100);
      await mergeSnapshot(other, await librarySnapshot(db));
      expect(await chatIds(other), [_main]);

      // Added back on the other device later, and the old removal doesn't undo it.
      await other.into(other.libraryChats).insert(LibraryChatsCompanion.insert(id: const Value(_other), title: 'Back'));
      await other.markChat(_other, gone: false, at: 200);
      await mergeSnapshot(db, await librarySnapshot(other));
      expect(await chatIds(db), containsAll([_main, _other]));
      await mergeSnapshot(other, await librarySnapshot(db));
      expect(await chatIds(other), containsAll([_main, _other]));
    });

    test('a removed channel isn\'t added back by a device that hadn\'t heard', () async {
      final stale = AppDb(NativeDatabase.memory());
      addTearDown(stale.close);
      for (final id in [_main, _other]) {
        await stale.into(stale.libraryChats).insert(LibraryChatsCompanion.insert(id: Value(id), title: 'Chat $id'));
      }
      await db.removeChat(_other);
      await db.markChat(_other, gone: true, at: 100);
      await mergeSnapshot(db, await librarySnapshot(stale));
      expect(await chatIds(db), [_main]);
    });
  });

  test('the player ignores download progress but not a new cover', () {
    final a = _song(_main, 1);
    expect(sameToShow(a, a.copyWith(cachedBytes: 500, plays: 3)), isTrue);
    expect(sameToShow(a, a.copyWith(coverPath: const Value('/new.jpg'))), isFalse);
  });

  group('log', () {
    const token = '123456789:AAFakeTokenForTestingOnly_abcdefghijk';

    test('requests log their type and ids, never secrets', () {
      final lines = [
        describeRequest({'@type': 'checkAuthenticationBotToken', 'token': token}),
        describeRequest({
          '@type': 'setTdlibParameters',
          'api_hash': 'secret-hash',
          'database_encryption_key': 'secret-key',
        }),
        describeRequest({'@type': 'getMessage', 'chat_id': 5, 'message_id': 6}),
      ];
      expect(lines.join(), isNot(contains(token)));
      expect(lines.join(), isNot(contains('secret')));
      expect(lines.last, 'getMessage chat_id=5 message_id=6');
    });

    test('a token in any other message is removed', () {
      final log = AppLog()..add('x', 'Failed for $token today');
      expect(log.entries.single.message, 'Failed for <bot token> today');
    });

    test('keeps only the newest entries', () {
      final log = AppLog(capacity: 2)
        ..add('x', '1')
        ..add('x', '2')
        ..add('x', '3');
      expect(log.entries.map((e) => e.message), ['2', '3']);
    });

    test('a saved line reads back as it was', () {
      final e = LogEntry(DateTime(2026), LogLevel.error, 'sync', 'tab\tinside');
      final back = LogEntry.parse(e.line)!;
      expect([back.level, back.source, back.message], [LogLevel.error, 'sync', 'tab\tinside']);
    });
  });
}

class MoveJobView {
  const MoveJobView(this.uniqueId, this.topicId, this.toChat);
  final String uniqueId;
  final int topicId;
  final int? toChat;

  @override
  bool operator ==(Object other) =>
      other is MoveJobView && other.uniqueId == uniqueId && other.topicId == topicId && other.toChat == toChat;

  @override
  int get hashCode => Object.hash(uniqueId, topicId, toChat);

  @override
  String toString() => '$uniqueId → $topicId in $toChat';
}
