import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teleplayer/telegram/bot_api.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/library/scanner.dart';
import 'package:teleplayer/library/taste.dart';
import 'package:teleplayer/library/topic_mover.dart';
import 'package:teleplayer/library/topic_sort.dart';
import 'package:teleplayer/library/upload.dart';
import 'package:teleplayer/telegram/td_client.dart';

const _bolly = 100, _calm = 200, _sad = 300, _japanese = 400, _tolly = 500, _phonk = 600;
const _topics = [
  TopicChoice(generalTopicId, 'General'),
  TopicChoice(_bolly, 'Bollywood'),
  TopicChoice(_calm, 'Calm'),
  TopicChoice(_sad, 'Sad Songs'),
  TopicChoice(_japanese, 'Japanese'),
  TopicChoice(_tolly, 'Tollywood'),
  TopicChoice(_phonk, 'Phonk'),
];

Song _song(int id, {String title = 'T', String artist = 'A', int? topic = generalTopicId, String? genre, String? lyrics}) => Song(
      chatId: 1,
      messageId: id,
      uniqueId: 'u$id',
      remoteId: 'r$id',
      title: title,
      artist: artist,
      album: '',
      durationSec: 200,
      size: 100,
      mime: 'audio/mpeg',
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

TopicSuggestion _one(Song s, [List<Song> filed = const []]) =>
    suggestTopics(songs: [s, ...filed], topics: _topics).single;

Json _message(int id, {int? topic = generalTopicId, String unique = 'u1', String type = 'messageAudio'}) => {
      'id': id,
      'chat_id': 1,
      'date': id,
      'topic_id': ?(topic == null ? null : {'@type': 'messageTopicForum', 'forum_topic_id': topic}),
      'content': {
        '@type': type,
        'caption': {'@type': 'formattedText', 'text': 'cap', 'entities': <Object>[]},
        if (type == 'messageAudio')
          'audio': {
            'title': 'Song',
            'performer': 'Artist',
            'file_name': 'song.mp3',
            'duration': 100,
            'mime_type': 'audio/mpeg',
            'audio': {'size': 50, 'expected_size': 50, 'remote': {'unique_id': unique, 'id': 'remote$id'}},
          }
        else
          'document': {
            'file_name': 'song.flac',
            'mime_type': 'audio/flac',
            'document': {'size': 50, 'expected_size': 50, 'remote': {'unique_id': unique, 'id': 'remote$id'}},
          },
      },
    };

void main() {
  group('choosing a topic', () {
    test('a name given in the app beats Telegram\'s, and General comes first', () {
      const rows = [
        ForumTopic(chatId: 1, topicId: 7, name: 'Work Playlist'),
        ForumTopic(chatId: 1, topicId: 8, name: 'Calm'),
        ForumTopic(chatId: 2, topicId: 9, name: 'Other chat'),
      ];
      final choices = topicChoices(rows, 1, {TasteSettings.topicKey(1, 7): 'Hollywood Favourites'});
      expect(choices.map((t) => t.name), ['General', 'Calm', 'Hollywood Favourites']);
      expect(choices.first.id, generalTopicId);
    });

    test('a chat with no topics, or only General, offers no choice', () {
      expect(topicChoices(const [], 1, const {}), isEmpty);
      expect(topicChoices(const [ForumTopic(chatId: 1, topicId: generalTopicId, name: 'General')], 1, const {}), isEmpty);
    });

    test('sendMessage gets message_thread_id, and nothing for General or no topic', () {
      expect(topicField(77), {'message_thread_id': 77});
      expect(topicField(generalTopicId), isEmpty);
      expect(topicField(null), isEmpty);
    });
  });

  group('suggesting a topic', () {
    test('an artist filed three times in one topic is high confidence', () {
      final r = _one(_song(1, artist: 'Ann'), [
        for (var i = 10; i < 13; i++) _song(i, artist: 'Ann', topic: _calm),
      ]);
      expect(r.topic?.id, _calm);
      expect(r.confidence, TopicConfidence.high);
      expect(r.reason, contains('Ann'));
    });

    test('an artist with one song elsewhere is only medium', () {
      final r = _one(_song(1, artist: 'Ann'), [_song(10, artist: 'Ann', topic: _calm)]);
      expect(r.topic?.id, _calm);
      expect(r.confidence, TopicConfidence.medium);
    });

    test('an artist split across topics says nothing', () {
      final r = _one(_song(1, artist: 'Ann'), [
        _song(10, artist: 'Ann', topic: _calm),
        _song(11, artist: 'Ann', topic: _bolly),
      ]);
      expect(r.topic, isNull);
    });

    test('Japanese and Devanagari lyrics point at the topics named for them', () {
      final japanese = _one(_song(1, lyrics: 'きみのことがすきだよ' * 5));
      expect(japanese.topic?.id, _japanese);
      expect(japanese.confidence, TopicConfidence.medium);
      final hindi = _one(_song(2, lyrics: 'तेरे बिना जिंदगी से कोई शिकवा नहीं' * 3));
      expect(hindi.topic?.id, _bolly);
    });

    test('Chinese characters alone aren\'t taken for Japanese', () {
      expect(_one(_song(1, lyrics: '我爱你中国人民' * 8)).topic, isNull);
    });

    test('Tamil lyrics are not assumed to be Tollywood', () {
      expect(_one(_song(1, lyrics: 'உன்னை நான் பார்த்த நாள் முதல்' * 3)).topic, isNull);
    });

    test('Tamil lyrics follow other Tamil songs once a topic holds them', () {
      final tamil = 'உன்னை நான் பார்த்த நாள் முதல்' * 3;
      final r = _one(_song(1, lyrics: tamil), [
        for (var i = 10; i < 13; i++) _song(i, artist: 'A$i', lyrics: tamil, topic: _tolly),
      ]);
      expect(r.topic?.id, _tolly);
    });

    test('a genre naming a topic is medium', () {
      final r = _one(_song(1, genre: 'Phonk'));
      expect(r.topic?.id, _phonk);
      expect(r.confidence, TopicConfidence.medium);
    });

    test('mood alone never picks a topic named for a sound', () {
      final loud = _song(1, genre: 'Metal', lyrics: 'run fast ' * 100);
      expect(_one(loud).topic?.id, isNot(_phonk));
    });

    test('clearly sad lyrics and genre can suggest Sad Songs', () {
      final r = _one(_song(1, genre: 'Blues', lyrics: 'I cry alone with tears and pain, lonely and broken ' * 8));
      expect(r.topic?.id, _sad);
      expect(r.confidence, TopicConfidence.medium);
    });

    test('nothing known means no suggestion', () {
      final r = _one(_song(1, artist: 'Nobody'));
      expect(r.topic, isNull);
      expect(r.confidence, isNull);
      expect(r.reason, 'Not enough to go on');
    });

    test('two close topics give no suggestion, and name both', () {
      final r = _one(_song(1, artist: 'Ann', genre: 'Phonk'), [_song(10, artist: 'Ann', topic: _calm)]);
      expect(r.topic, isNull);
      expect(r.reason, contains('Could be'));
    });

    test('only songs in General are listed', () {
      final rows = suggestTopics(
        songs: [_song(1), _song(2, topic: _calm), _song(3, topic: 999), _song(4, topic: null)],
        topics: _topics,
      );
      expect(rows.map((r) => r.song.messageId), [1]);
    });

    test('a song also posted in another topic can\'t be moved from here', () {
      final s = _song(1);
      final r = suggestTopics(
        songs: [s],
        topics: _topics,
        copies: [PostCopy(chatId: 1, messageId: 9, uniqueId: s.uniqueId, fileName: 'f', size: 1, topicId: _calm, date: 1)],
      ).single;
      expect(r.blocked, isTrue);
      expect(r.topic, isNull);
      expect(r.reason, contains('Calm'));
    });

    test('a chat without other topics lists nothing: it isn\'t a sorted forum', () {
      expect(suggestTopics(songs: [_song(1)], topics: const [TopicChoice(generalTopicId, 'General')]), isEmpty);
    });
  });

  group('the repost request', () {
    test('audio is sent by remote id into the topic, silently, with its caption', () {
      final r = repostRequest(_message(1), _calm);
      expect(r['@type'], 'sendMessage');
      expect(r['message_thread_id'], _calm);
      expect(r.containsKey('topic_id'), isFalse);
      expect((r['options'] as Json)['disable_notification'], isTrue);
      final content = r['input_message_content'] as Json;
      expect(content['@type'], 'inputMessageAudio');
      expect(content['audio'], {'@type': 'inputFileRemote', 'id': 'remote1'});
      expect(content['title'], 'Song');
      expect((content['caption'] as Json)['text'], 'cap');
    });

    test('a file posted as a document stays a document', () {
      final content = repostRequest(_message(1, type: 'messageDocument'), _calm)['input_message_content'] as Json;
      expect(content['@type'], 'inputMessageDocument');
      expect(content['document'], {'@type': 'inputFileRemote', 'id': 'remote1'});
      expect(content['disable_content_type_detection'], isTrue);
    });

    test('a repost only counts if it\'s the same file in the right topic', () {
      expect(repostFits(_message(2, topic: _calm), 'u1', _calm), isTrue);
      expect(repostFits(_message(2), 'u1', _calm), isFalse);
      expect(repostFits(_message(2, topic: null), 'u1', _calm), isFalse);
      expect(repostFits(_message(2, topic: _calm, unique: 'other'), 'u1', _calm), isFalse);
    });
  });

  group('moving a post', () {
    late AppDb db;
    late StreamController<Json> updates;
    late List<Json> calls;
    late Song song;
    late Json Function(Json) sendResult;
    late Object? Function(Json) refuse;
    late void Function() onSent;
    late List<Duration> slept;
    late TopicMover mover;

    /// What Telegram says about the new post, 50 being its real id and -1 its temporary one.
    void confirmSent(Json message) => updates.add({
          '@type': 'updateMessageSendSucceeded',
          'old_message_id': -1,
          'message': message,
        });

    Future<void> settle() async {
      for (var i = 0; i < 40 && (mover.active && !mover.paused.value); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    // The permission lookup is local, so it isn't one of the calls these tests are about.
    Iterable<String> kinds() => calls.map((c) => c['@type'] as String).where((k) => k != 'getMessageProperties');

    setUp(() async {
      db = AppDb(NativeDatabase.memory());
      updates = StreamController<Json>.broadcast();
      calls = [];
      slept = [];
      refuse = (_) => null;
      onSent = () => confirmSent(_message(50, topic: _calm));
      sendResult = (_) => {'id': -1, 'sending_state': {'@type': 'messageSendingStatePending'}};
      await db.into(db.libraryChats).insert(LibraryChatsCompanion.insert(id: const Value(1), title: 'Chat'));
      await db.upsertBotSong(songFromMessage(_message(1))!);
      song = (await db.song(1, 1))!;
      mover = TopicMover(
        (request) async {
          calls.add(request);
          final refusal = refuse(request);
          if (refusal != null) throw refusal;
          switch (request['@type']) {
            case 'getMessage':
              return _message(1);
            case 'sendMessage':
              scheduleMicrotask(onSent);
              return sendResult(request);
          }
          return {'@type': 'ok'};
        },
        updates.stream,
        db,
        sleep: (d) async => slept.add(d),
        random: Random(1),
      );
    });

    tearDown(() async {
      await updates.close();
      await db.close();
    });

    test('reposts, then deletes, and the one row carries on with what it had', () async {
      await db.updateSong(song, const SongsCompanion(
        favorite: Value(true),
        lyrics: Value('words'),
        coverPath: Value('/cover.jpg'),
        title: Value('Edited'),
      ));
      await db.setMoodVote(song, 'sad', 1);
      final list = await db.createPlaylist('Mix');
      await db.upsertBotSong(songFromMessage(_message(9, unique: 'other'))!);
      await db.addToPlaylist(list, song);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await db.addToPlaylist(list, (await db.song(1, 9))!);

      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();

      expect(kinds(), ['getMessage', 'sendMessage', 'deleteMessages']);
      expect(calls.last['message_ids'], [1]);
      expect(await db.song(1, 1), isNull);
      final moved = (await db.song(1, 50))!;
      expect(moved.topicId, _calm);
      expect(moved.remoteId, 'remote50');
      expect(moved.favorite, isTrue);
      expect(moved.lyrics, 'words');
      expect(moved.coverPath, '/cover.jpg');
      expect(moved.title, 'Edited');
      expect((await db.select(db.moodVotes).getSingle()).messageId, 50);
      expect(await db.select(db.postCopies).get(), isEmpty);
      // Still first in the playlist, not sent to the end.
      expect((await db.watchPlaylistSongs(list).first).map((s) => s.messageId), [50, 9]);
      expect(mover.jobs.value.single.status, MoveStatus.done);
    });

    test('the scanner hearing about the repost first doesn\'t leave a duplicate row', () async {
      onSent = () async {
        await db.upsertBotSong(songFromMessage(_message(50, topic: _calm))!);
        confirmSent(_message(50, topic: _calm));
      };
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect((await db.select(db.songs).getSingle()).messageId, 50);
      expect(await db.select(db.postCopies).get(), isEmpty);
      // And hearing again afterwards only refreshes it.
      await db.upsertBotSong(songFromMessage(_message(50, topic: _calm))!);
      await db.removePost(1, 1);
      expect((await db.select(db.songs).getSingle()).messageId, 50);
      expect(await db.select(db.postCopies).get(), isEmpty);
    });

    test('a failed repost keeps the original and stops the queue', () async {
      onSent = () => updates.add({
            '@type': 'updateMessageSendFailed',
            'old_message_id': -1,
            'error': {'code': 400, 'message': 'CHAT_WRITE_FORBIDDEN'},
          });
      await db.upsertBotSong(songFromMessage(_message(2, unique: 'u2'))!);
      mover.start([MoveJob(song, _calm, 'Calm'), MoveJob((await db.song(1, 2))!, _calm, 'Calm')]);
      await settle();

      expect(kinds(), isNot(contains('deleteMessages')));
      expect(kinds().where((k) => k == 'sendMessage').length, 1);
      final row = (await db.song(1, 1))!;
      expect(row.topicId, generalTopicId);
      expect(mover.jobs.value.first.status, MoveStatus.failed);
      expect(mover.jobs.value.last.status, MoveStatus.queued);
      expect(mover.problem.value, contains('Original kept'));
      expect(mover.paused.value, isTrue);
    });

    test('a repost landing in the wrong topic deletes nothing', () async {
      onSent = () => confirmSent(_message(50));
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect(kinds(), isNot(contains('deleteMessages')));
      expect((await db.song(1, 1))!.topicId, generalTopicId);
      expect(mover.jobs.value.single.status, MoveStatus.failed);
      expect((await db.select(db.postCopies).getSingle()).messageId, 50);
    });

    test('a refused delete leaves both posts known, and the song moved', () async {
      refuse = (r) => r['@type'] == 'deleteMessages' ? TdError(400, 'MESSAGE_DELETE_FORBIDDEN') : null;
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect((await db.song(1, 50))!.topicId, _calm);
      expect((await db.select(db.postCopies).getSingle()).messageId, 1);
      expect(mover.jobs.value.single.status, MoveStatus.failed);
      expect(mover.problem.value, contains('couldn\'t be deleted'));
      expect(mover.deleteBlocked.value, isFalse, reason: 'one refused post blocks only itself');
    });

    test('a refused delete holds back only that post, and the next one is still tried', () async {
      refuse = (r) => r['@type'] == 'deleteMessages' ? TdError(400, 'MESSAGE_DELETE_FORBIDDEN') : null;
      await db.upsertBotSong(songFromMessage(_message(2, unique: 'u2'))!);
      mover.start([
        MoveJob(song, _calm, 'Calm'),
        MoveJob((await db.song(1, 2))!, _calm, 'Calm'),
      ]);
      await settle();
      expect(kinds().where((k) => k == 'sendMessage').length, 2);
      expect(mover.jobs.value.last.status, isNot(MoveStatus.skipped));
    });

    // Telegram's own answers, standing in for the HTTP Bot API.
    BotApi telegram({bool canDelete = true, String? deleteError, List<Uri>? seen}) => BotApi(
          () async => 'TOKEN',
          client: MockClient((req) async {
            seen?.add(req.url);
            final method = req.url.pathSegments.last;
            final body = switch (method) {
              'getMe' => {'ok': true, 'result': {'id': 99}},
              'getChatMember' => {
                  'ok': true,
                  'result': {'status': 'administrator', 'can_delete_messages': canDelete},
                },
              _ => deleteError == null ? {'ok': true, 'result': true} : {'ok': false, 'description': deleteError},
            };
            return http.Response(jsonEncode(body), 200);
          }),
        );

    TopicMover moverWith(BotApi? api, {required bool tdlibRefusesDelete, bool saysUndeletable = false}) => TopicMover(
          (r) async {
            calls.add(r);
            switch (r['@type']) {
              case 'getMessage':
                return {..._message(1), if (saysUndeletable) 'can_be_deleted_for_all_users': false};
              case 'sendMessage':
                scheduleMicrotask(onSent);
                return sendResult(r);
              case 'deleteMessages' when tdlibRefusesDelete:
                throw TdError(400, 'Message can\'t be deleted');
            }
            return {'@type': 'ok'};
          },
          updates.stream,
          db,
          sleep: (d) async {},
          botApi: api,
        );

    test('when TDLib refuses a delete from its cache, Telegram deleting it directly counts', () async {
      final seen = <Uri>[];
      final m = moverWith(telegram(seen: seen), tdlibRefusesDelete: true);
      m.start([MoveJob(song, _calm, 'Calm')]);
      for (var i = 0; i < 40 && m.active; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(m.jobs.value.single.status, MoveStatus.done);
      expect(m.deleteBlocked.value, isFalse);
      expect(seen.last.pathSegments.last, 'deleteMessage');
    });

    test('a post TDLib thinks is undeletable is still moved when Telegram says the bot may delete', () async {
      final m = moverWith(telegram(), tdlibRefusesDelete: false, saysUndeletable: true);
      m.start([MoveJob(song, _calm, 'Calm')]);
      for (var i = 0; i < 40 && m.active; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(m.jobs.value.single.status, MoveStatus.done);
    });

    test('if Telegram says no too, nothing is reposted and the reason is kept', () async {
      final m = moverWith(telegram(canDelete: false), tdlibRefusesDelete: false, saysUndeletable: true);
      m.start([MoveJob(song, _calm, 'Calm')]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(kinds(), ['getMessage']);
      expect(m.jobs.value.single.status, MoveStatus.skipped);
      expect(m.deleteBlocked.value, isTrue);
    });

    test('Telegram refusing the delete after the repost is reported with its own reason', () async {
      final m = moverWith(telegram(deleteError: 'Bad Request: not enough rights'), tdlibRefusesDelete: true);
      m.start([MoveJob(song, _calm, 'Calm')]);
      for (var i = 0; i < 40 && m.active; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(m.jobs.value.single.status, MoveStatus.failed);
      expect(m.problem.value, contains('not enough rights'));
    });

    test('the Bot API converts TDLib ids, and a failed request reveals nothing', () async {
      final seen = <Uri>[];
      final api = telegram(seen: seen);
      expect(await api.deleteMessage(-100, 755 << 20), isNull);
      expect(seen.single.path, contains('deleteMessage'));
      final broken = BotApi(() async => 'TOKEN', client: MockClient((_) async => throw http.ClientException('failed for https://x/botTOKEN/y')));
      final why = await broken.deleteMessage(-100, 1 << 20);
      expect(why, isNot(contains('TOKEN')));
    });

    test('a post Telegram says can\'t be deleted is never reposted', () async {
      final locked = TopicMover(
        (r) async {
          calls.add(r);
          return r['@type'] == 'getMessage'
              ? {..._message(1), 'can_be_deleted_for_all_users': false}
              : {'@type': 'ok'};
        },
        updates.stream,
        db,
        sleep: (d) async {},
      );
      locked.start([MoveJob(song, _calm, 'Calm')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(kinds(), ['getMessage']);
      expect(locked.jobs.value.single.status, MoveStatus.skipped);
      expect(locked.deleteBlocked.value, isTrue);
    });

    test('permission asked by property when the message doesn\'t say', () async {
      final locked = TopicMover(
        (r) async {
          calls.add(r);
          return switch (r['@type']) {
            'getMessage' => _message(1),
            'getMessageProperties' => {'@type': 'messageProperties', 'can_be_deleted_for_all_users': false},
            _ => {'@type': 'ok'},
          };
        },
        updates.stream,
        db,
        sleep: (d) async {},
      );
      locked.start([MoveJob(song, _calm, 'Calm')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(kinds(), ['getMessage']);
      expect(locked.jobs.value.single.status, MoveStatus.skipped);
    });

    test('a restored song is posted back, and the library keeps listing it where it was', () async {
      // The song is listed under its main chat post (chat 1). Its old post in chat 2 is gone.
      mover.start([MoveJob(song, _calm, 'where it was', toChat: 2, restore: true)]);
      await settle();
      expect(kinds(), ['getMessage', 'sendMessage']);
      expect(calls.last['chat_id'], 2);
      final row = (await db.songByUniqueId(song.uniqueId))!;
      expect([row.chatId, row.messageId], [1, 1], reason: 'still listed in the main chat');
      expect(mover.jobs.value.single.status, MoveStatus.done);
    });

    test('a song from another chat is copied there, its original stays, and nothing is deleted', () async {
      mover.start([MoveJob(song, _calm, 'Calm', toChat: 2)]);
      await settle();
      expect(kinds(), ['getMessage', 'sendMessage']);
      expect(calls.last['chat_id'], 2);
      final row = (await db.songByUniqueId(song.uniqueId))!;
      expect([row.chatId, row.messageId, row.topicId], [2, 50, _calm]);
      expect((await db.select(db.postCopies).getSingle()).messageId, 1, reason: 'the old post is remembered');
      expect(mover.jobs.value.single.status, MoveStatus.done);
    });

    test('a rate limit on the delete waits, then deletes without posting again', () async {
      var limited = false;
      refuse = (r) {
        if (r['@type'] != 'deleteMessages' || limited) return null;
        limited = true;
        return TdError(429, 'Too Many Requests: retry after 30');
      };
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect(kinds(), ['getMessage', 'sendMessage', 'deleteMessages', 'deleteMessages']);
      expect(slept.single.inSeconds, greaterThanOrEqualTo(35));
      expect(mover.jobs.value.single.status, MoveStatus.done);
    });

    test('a rate limit on the repost waits, then reposts once', () async {
      var limited = false;
      refuse = (r) {
        if (r['@type'] != 'sendMessage' || limited) return null;
        limited = true;
        return TdError(429, 'Too Many Requests: retry after 10');
      };
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect(slept.first.inSeconds, greaterThanOrEqualTo(15));
      expect(kinds().where((k) => k == 'deleteMessages').length, 1);
      expect(mover.jobs.value.single.status, MoveStatus.done);
    });

    test('a rate limit reported as a failed send waits, then reposts once', () async {
      var sends = 0;
      onSent = () {
        if (++sends == 1) {
          updates.add({
            '@type': 'updateMessageSendFailed',
            'old_message_id': -1,
            'error': {'code': 429, 'message': 'Too Many Requests: retry after 20'},
          });
        } else {
          confirmSent(_message(50, topic: _calm));
        }
      };
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect(slept.first.inSeconds, greaterThanOrEqualTo(25));
      expect(kinds().where((k) => k == 'sendMessage').length, 2);
      expect(kinds().where((k) => k == 'deleteMessages').length, 1);
      expect(mover.jobs.value.single.status, MoveStatus.done);
    });

    test('a song no longer in General is left alone, whatever the library says', () async {
      await db.upsertBotSong(songFromMessage(_message(1, topic: _sad))!);
      mover.start([MoveJob(song, _calm, 'Calm')]);
      await settle();
      expect(calls, isEmpty);
      expect((await db.song(1, 1))!.topicId, _sad);
      expect(mover.jobs.value.single.status, MoveStatus.skipped);
    });

    test('Telegram saying it\'s elsewhere beats the library', () async {
      final elsewhere = TopicMover(
        (r) async {
          calls.add(r);
          return _message(1, topic: _sad);
        },
        updates.stream,
        db,
        sleep: (d) async {},
      );
      elsewhere.start([MoveJob(song, _calm, 'Calm')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(kinds(), ['getMessage']);
      expect(elsewhere.jobs.value.single.status, MoveStatus.skipped);
    });

    test('the song playing now is left in General', () async {
      final busy = TopicMover(
        (r) async {
          calls.add(r);
          return {};
        },
        updates.stream,
        db,
        sleep: (d) async {},
        isPlaying: (_) => true,
      );
      busy.start([MoveJob(song, _calm, 'Calm')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, isEmpty);
      expect(busy.jobs.value.single.status, MoveStatus.skipped);
    });

    test('pausing waits at the next song, and cancelling drops the rest', () async {
      await db.upsertBotSong(songFromMessage(_message(2, unique: 'u2'))!);
      await db.upsertBotSong(songFromMessage(_message(3, unique: 'u3'))!);
      final jobs = [
        MoveJob(song, _calm, 'Calm'),
        MoveJob((await db.song(1, 2))!, _calm, 'Calm'),
        MoveJob((await db.song(1, 3))!, _calm, 'Calm'),
      ];
      mover.start(jobs);
      mover.setPaused(true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(jobs.first.status, MoveStatus.done);
      expect(jobs[1].status, MoveStatus.queued);
      mover.cancel();
      expect(mover.jobs.value, [jobs.first]);
      expect(mover.active, isFalse);
      expect(calls.where((c) => c['@type'] == 'sendMessage').length, 1);
    });
  });

  group('a queue holding an old copy of a moved song', () {
    test('finds the row under its new post', () async {
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      await db.upsertBotSong(songFromMessage(_message(1))!);
      final old = (await db.song(1, 1))!;
      await db.movePostTo(old, messageId: 50, remoteId: 'r', topicId: _calm);
      await db.removePost(1, 1);
      expect((await db.songByUniqueId(old.uniqueId))?.messageId, 50);
    });
  });
}
