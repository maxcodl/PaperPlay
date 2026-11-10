import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../metadata/enricher.dart';
import 'audio_info.dart';
import 'db.dart';
import 'taste.dart';
import 'topic_mover.dart';
import 'topic_sort.dart';

/// Whether a song's info is in, from a lookup here or from another device: filed by what's
/// known, since genre and lyrics decide the topic. With lookups off it only waits for the
/// tags.
bool infoSettled(Song s, {required bool lookupsOn}) =>
    s.enrichState != EnrichState.pending && (!lookupsOn || s.moodScannedAt > 0);

Map<String, int> jsonDecodeGone(String? raw) =>
    raw == null ? {} : (jsonDecode(raw) as Map).cast<String, int>();

/// Title, first artist and length, to tell versions of one song apart from other songs.
(String, String, int) songKey(Song s) => (
      comparableText(searchTitle(cleanTitle(s.title, s.artist))),
      comparableText(firstArtist(s.artist)),
      s.durationSec,
    );

/// A deleted song's identity as a key in the synced deletion record, since a deleted file
/// has other versions in other channels that would otherwise be copied back in.
String goneKeyOf(Song s) {
  final k = songKey(s);
  return 'song:${k.$1}${k.$2}${k.$3}';
}

/// The songs deleted on purpose, with when, from the deletion record.
List<((String, String, int), int)> deletedSongKeys(Map<String, int> gone) => [
      for (final e in gone.entries)
        if (e.key.startsWith('song:') && e.key.split('').length == 3)
          (
            (e.key.substring(5).split('')[0], e.key.split('')[1], int.tryParse(e.key.split('')[2]) ?? 0),
            e.value,
          ),
    ];

bool sameSong((String, String, int) a, (String, String, int) b) =>
    a.$1.isNotEmpty && a.$1 == b.$1 && a.$2 == b.$2 && (a.$3 - b.$3).abs() <= 3;

bool betterVersion(Song a, Song b) {
  final q = compareQuality(a, b);
  return q != 0 ? q < 0 : a.date > b.date;
}

/// One row per song for lists: versions of the same song collapse to the one in
/// [mainChat] if there is one, else the best.
List<Song> oneVersionEach(List<Song> songs, int? mainChat) {
  final byName = <(String, String), List<(int, Song)>>{};
  final keep = List<Song?>.of(songs);
  for (final (i, s) in songs.indexed) {
    final k = songKey(s);
    if (k.$1.isEmpty) continue;
    final group = byName.putIfAbsent((k.$1, k.$2), () => []);
    final twin = group.where((e) => (songs[e.$1].durationSec - s.durationSec).abs() <= 3).firstOrNull;
    if (twin == null) {
      group.add((i, s));
      continue;
    }
    final other = twin.$2;
    final mine = s.chatId == mainChat, theirs = other.chatId == mainChat;
    final wins = mine != theirs ? mine : betterVersion(s, other);
    if (wins) {
      keep[twin.$1] = null;
      group[group.indexOf(twin)] = (i, s);
    } else {
      keep[i] = null;
    }
  }
  return keep.nonNulls.toList();
}

/// For songs not yet in a topic of [mainChat], the name of the topic they're in, or
/// were copied from, in another channel. Keyed by file. General doesn't count.
Map<String, String> originTopics(int mainChat, List<Song> songs, List<PostCopy> copies, List<ForumTopic> topics) {
  final names = {for (final t in topics) if (t.topicId != generalTopicId) (t.chatId, t.topicId): t.name};
  final out = <String, String>{};
  void note(int chat, int? topic, String uniqueId) {
    if (chat == mainChat || topic == null) return;
    final name = names[(chat, topic)];
    if (name != null && name.toLowerCase() != 'general') out.putIfAbsent(uniqueId, () => name);
  }

  for (final s in songs) {
    note(s.chatId, s.topicId, s.uniqueId);
  }
  for (final c in copies) {
    note(c.chatId, c.topicId, c.uniqueId);
  }
  // Only songs still to be placed: from other channels, or sitting in the main chat's General.
  final placed = {
    for (final s in songs)
      if (s.chatId == mainChat && s.topicId != null && s.topicId != generalTopicId) s.uniqueId,
  };
  out.removeWhere((k, _) => placed.contains(k));
  return out;
}

/// What to do now to file songs into [mainChat]. Songs from other channels are copied
/// and stay where they are; those in its General move only to a topic that clearly
/// fits. A song the app can't place is left alone, wherever it is. If the chat has no
/// topics there's nothing to place, so every song from elsewhere is copied into it.
List<MoveJob> planFiling({
  required int mainChat,
  required List<Song> songs,
  required List<PostCopy> copies,
  required List<TopicChoice> topics,
  required bool Function(Song) ready,
  bool canDelete = true,
  Map<String, String> origin = const {},
  List<((String, String, int), int)> deleted = const [],
}) {
  TopicChoice? named(String? name) => name == null
      ? null
      : topics.where((t) => !t.isGeneral && t.name.toLowerCase() == name.toLowerCase()).firstOrNull;
  final inMain = [for (final s in songs) if (s.chatId == mainChat) s];
  final mainCopies = [for (final c in copies) if (c.chatId == mainChat) c];
  final alreadyThere = {for (final c in mainCopies) c.uniqueId};
  // One version of a song is enough. Another channel can hold the same song in several
  // files; copying each would fill the main chat with repeats, and deleting them there
  // would only bring them back. So a song already in the main chat isn't copied again,
  // and of several versions elsewhere only the best (then largest, then newest) comes.
  final present = {for (final s in inMain) songKey(s)};
  final best = <(String, String, int), Song>{};
  for (final s in songs) {
    if (s.chatId == mainChat || alreadyThere.contains(s.uniqueId) || !ready(s)) continue;
    final key = songKey(s);
    if (present.any((k) => sameSong(k, key))) continue;
    // Deleted on purpose: not brought back from another channel (a file posted after is new).
    if (deleted.any((d) => sameSong(d.$1, key) && s.date * 1000 <= d.$2)) continue;
    final match = best.keys.where((k) => sameSong(k, key)).firstOrNull;
    if (match == null) {
      best[key] = s;
    } else if (betterVersion(s, best[match]!)) {
      best[match] = s;
    }
  }
  // Oldest first, so the main chat keeps the order they were posted in.
  final incoming = best.values.toList()..sort((a, b) => a.date.compareTo(b.date));

  final jobs = <MoveJob>[];
  final generalName = topics.where((t) => t.isGeneral).firstOrNull?.name ?? 'General';
  final copiedInto = {
    for (final r in suggestTopics(songs: inMain, topics: topics, copies: mainCopies, incoming: incoming))
      if (r.topic != null) r.song.uniqueId: r.topic!,
  };
  // Every song comes over (owner's choice, 2026-11-08): into the topic that fits, else
  // General, where sorting General can move it later.
  for (final s in incoming) {
    // The topic it had in its old channel comes first; then the one that fits.
    final topic = named(origin[s.uniqueId]) ?? copiedInto[s.uniqueId];
    jobs.add(MoveJob(s, topic?.id ?? generalTopicId, topic?.name ?? generalName, toChat: mainChat));
  }
  if (canDelete) {
    final waiting = [for (final s in inMain) if (s.topicId == generalTopicId && ready(s)) s];
    for (final r in suggestTopics(songs: inMain, topics: topics, copies: mainCopies, incoming: waiting)) {
      // A song that came from a topic in another channel goes back under that name.
      final home = named(origin[r.song.uniqueId]);
      if (home != null) {
        jobs.add(MoveJob(r.song, home.id, home.name));
      } else if (r.topic != null && !r.blocked) {
        jobs.add(MoveJob(r.song, r.topic!.id, r.topic!.name));
      }
    }
  }
  return jobs;
}

/// Keeps the main chat filed in the background. Only the device set to do the posting
/// runs this, or two devices would post every song twice.
class AutoFiler {
  AutoFiler(
    this._db,
    this.mover, {
    required this.mainChat,
    required this.topicNames,
    required this.lookupsOn,
    required this.canDelete,
    required this.createTopic,
    required this.canWrite,
  });

  /// Whether the bot may post in a chat at all. Filing never writes anywhere else.
  final Future<bool> Function(int chat) canWrite;

  /// Makes a topic in the main chat and lists it. False if Telegram refused.
  final Future<bool> Function(int chat, String name) createTopic;

  final AppDb _db;
  final TopicMover mover;
  final int? Function() mainChat;
  final Map<String, String> Function() topicNames;
  final bool Function() lookupsOn;
  final Future<bool> Function(int chat) canDelete;

  static const _hereKey = 'file_here', _existingKey = 'file_existing';

  /// A song waits for its info, but not forever if the lookups can't finish.
  static const _lookupWait = Duration(hours: 1);

  /// How many songs are waiting for their info before they can be filed.
  final waitingForInfo = ValueNotifier(0);
  static const _checkEvery = Duration(minutes: 5);
  static const _settle = Duration(seconds: 30);

  final _firstSeen = <String, DateTime>{};
  Timer? _soon, _regular;
  var _planning = false;

  /// True on a phone while a PC is connected: the PC does the filing then, and posting from
  /// both would post every song twice. Set where the app is wired up.
  bool Function() deferToPc = () => false;

  Future<bool> runsHere() async => !deferToPc() && await _db.pref(_hereKey) == 'true';
  Future<void> setRunsHere(bool on) async {
    await _db.setPref(_hereKey, '$on');
    kick();
  }

  /// False files only songs posted after the main chat was chosen.
  Future<bool> includesExisting() async => await _db.pref(_existingKey) != 'false';
  Future<void> setIncludesExisting(bool on) async {
    await _db.setPref(_existingKey, '$on');
    kick();
  }

  void start() {
    _regular ??= Timer.periodic(_checkEvery, (_) => kick());
    kick();
  }

  /// Songs tend to arrive in bursts, so this waits for a pause.
  void kick() {
    _soon?.cancel();
    _soon = Timer(_settle, () => unawaited(_plan()));
  }

  Future<void> _plan() async {
    final main = mainChat();
    // A failure stays stopped until someone has seen it and resumes.
    if (main == null || _planning || mover.active || mover.paused.value) return;
    if (!await runsHere()) return;
    if (!await canWrite(main)) return;
    _planning = true;
    try {
      final existing = await includesExisting();
      final chosenAt = mainChatAt(await _db.pref(AppDb.mainChatKey));
      final now = DateTime.now();
      var waiting = 0;
      bool ready(Song s) {
        if (!existing && s.date * 1000 < chosenAt) return false;
        if (infoSettled(s, lookupsOn: lookupsOn())) return true;
        final seen = _firstSeen.putIfAbsent(s.uniqueId, () => now);
        if (now.difference(seen) >= _lookupWait) return true;
        waiting++;
        return false;
      }

      // Songs are only copied out of chats where this bot is an admin too. A chat it
      // can only read (someone else's, say) is played from, never copied.
      final readOnly = <int>{};
      for (final c in await _db.select(_db.libraryChats).get()) {
        if (c.id != main && !await canWrite(c.id)) readOnly.add(c.id);
      }
      final songs = [
        for (final s in await _db.select(_db.songs).get())
          if (!readOnly.contains(s.chatId)) s,
      ];
      final copies = await _db.select(_db.postCopies).get();
      var topics = await _db.select(_db.forumTopics).get();
      final origin = originTopics(main, songs, copies, topics);
      // A topic a song had in its old channel is made in the main chat if it's missing.
      final have = {for (final t in topics) if (t.chatId == main) t.name.toLowerCase()};
      var made = false;
      for (final name in {...origin.values}) {
        if (have.contains(name.toLowerCase())) continue;
        if (await createTopic(main, name)) made = true;
        have.add(name.toLowerCase());
      }
      if (made) topics = await _db.select(_db.forumTopics).get();
      final jobs = planFiling(
        mainChat: main,
        songs: songs,
        copies: copies,
        topics: topicChoices(topics, main, topicNames()),
        ready: ready,
        canDelete: !mover.deleteBlocked.value && await canDelete(main),
        origin: origin,
        deleted: deletedSongKeys(jsonDecodeGone(await _db.pref(AppDb.goneKey))),
      );
      waitingForInfo.value = waiting;
      if (jobs.isNotEmpty) mover.start(jobs);
    } finally {
      _planning = false;
    }
  }
}
