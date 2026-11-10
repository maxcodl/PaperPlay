import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../library/audio_info.dart';
import '../library/db.dart';
import '../library/task_history.dart' show ItemState;
import '../library/upload.dart' show retryAfterOf;
import '../log.dart';
import '../metadata/enricher.dart' show cleanTitle, comparableText, firstArtist, searchTitle;
import '../pace.dart';
import '../telegram/td_client.dart';
import '../telegram/user_session.dart';
import 'widgets.dart';

/// How a song in one of your chats relates to your library.
enum PostKind {
  isNew('New'),
  better('Better than yours'),
  have('Already have');

  const PostKind(this.label);
  final String label;
}

class ReviewItem {
  ReviewItem(this.post, this.kind, {this.yours, this.playlists = const []});
  final ChatPost post;
  final PostKind kind;

  /// Your copy of the same song, when there is one.
  final Song? yours;

  /// Your Spotify-imported playlists still waiting for this song.
  final List<String> playlists;
}

class ChatRead {
  ChatRead(this.title);
  final String title;
  var reading = true;
  var found = 0;
  String? error;
  List<ReviewItem> items = const [];

  // Copying lives here, not on the page, so it carries on and shows again when reopened.
  var copying = false;
  var stop = false;
  String? copyText;

  /// The songs of the current or last copy, with how each went, for the Tasks page.
  List<ReviewItem> copyItems = const [];
  List<ItemState> copyStates = const [];
  final copyNotes = <int, String>{};
}

/// Reads your chats with your account, in the background, so a big channel can be
/// reviewed once it's all in. A toast with "Review" says when one is ready.
class ChatReads {
  ChatReads._();
  static final instance = ChatReads._();

  final reads = <int, ChatRead>{};
  final changed = ValueNotifier(0);

  void read(int chatId, String title) {
    if (reads[chatId]?.reading ?? false) return;
    final r = reads[chatId] = ChatRead(title);
    changed.value++;
    () async {
      try {
        final posts = await app.userSession.songsIn(chatId, onProgress: (n) {
          r.found = n;
          changed.value++;
        });
        r.items = await _classify(posts);
        final news = r.items.where((i) => i.kind == PostKind.isNew).length;
        unawaited(app.background.copyNotify(
          'Read $title',
          '${posts.length} songs, $news new to you. Tap to review.',
          open: 'copy:$chatId:$title',
        ));
        appMessenger.currentState?.showSnackBar(
          SnackBar(
            content: Text('Read $title: ${posts.length} songs, $news new to you'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Review',
              onPressed: () => appNavigator.currentState?.push(
                MaterialPageRoute<void>(builder: (_) => ChatReviewScreen(chatId: chatId, title: title)),
              ),
            ),
          ),
        );
      } on TdError catch (e) {
        r.error = e.message;
      } finally {
        r.reading = false;
        changed.value++;
      }
    }();
  }

  static (String, String, int) _key(String title, String artist, int duration) => (
        comparableText(searchTitle(cleanTitle(title, artist))),
        comparableText(firstArtist(artist)),
        duration,
      );

  static bool _same((String, String, int) a, (String, String, int) b) =>
      a.$1.isNotEmpty && a.$1 == b.$1 && a.$2 == b.$2 && (a.$3 == 0 || b.$3 == 0 || (a.$3 - b.$3).abs() <= 3);

  Future<List<ReviewItem>> _classify(List<ChatPost> posts) async {
    final songs = await app.db.select(app.db.songs).get();
    final copies = await app.db.select(app.db.postCopies).get();
    final files = {for (final s in songs) s.uniqueId, for (final c in copies) c.uniqueId};
    final names = {for (final p in await app.db.select(app.db.playlists).get()) p.id: p.name};
    final missing = [
      for (final m in await app.db.select(app.db.missingTracks).get())
        (key: _key(m.title, m.artist, m.durationSec), playlist: names[m.playlistId] ?? ''),
    ];
    final keyed = [for (final s in songs) (key: _key(s.title, s.artist, s.durationSec), song: s)];
    return [
      for (final p in posts) () {
        final key = _key(p.title, p.artist, p.duration);
        final wanted = [for (final m in missing) if (_same(m.key, key)) m.playlist];
        if (files.contains(p.uniqueId)) return ReviewItem(p, PostKind.have);
        final yours = keyed.where((k) => _same(k.key, key)).firstOrNull?.song;
        if (yours == null) return ReviewItem(p, PostKind.isNew, playlists: wanted);
        // Better: lossless against lossy, or the same kind at a third larger or more.
        final theirsLossless = isLossless(audioFormat(p.mime, p.fileName));
        final mineLossless = isLossless(songFormat(yours));
        final better = (theirsLossless && !mineLossless) ||
            (theirsLossless == mineLossless && p.size > yours.size * 1.3);
        return ReviewItem(p, better ? PostKind.better : PostKind.have, yours: yours, playlists: wanted);
      }(),
    ];
  }

  /// Copies [items] into the main chat. With [replace], a better copy takes over from your
  /// old one: playlists and favorites move to it, then the old post is deleted.
  Future<({int copied, int failed})> copy(int chatId, String title, List<ReviewItem> items, {required bool replace}) async {
    final main = app.mainChat.value!;
    final r = reads[chatId]!;
    final open = 'copy:$chatId:$title';
    void show(String text, {int? done}) {
      r.copyText = text;
      changed.value++;
      unawaited(app.background.copyNotify('Copying from $title', text, progress: done, max: done == null ? null : items.length, open: open));
    }

    r
      ..copying = true
      ..stop = false
      ..copyItems = items
      ..copyStates = List.filled(items.length, ItemState.waiting)
      ..copyNotes.clear();
    var copied = 0, failed = 0, slowdown = 1;
    for (final (i, item) in items.indexed) {
      if (r.stop) break;
      r.copyStates[i] = ItemState.active;
      show('${i + 1} of ${items.length}', done: i);
      try {
        await app.userSession.copyPost(chatId, item.post.id, main);
        copied++;
        r.copyStates[i] = ItemState.done;
        if (replace && item.kind == PostKind.better && item.yours != null) {
          await _swap(item.yours!, item.post.uniqueId);
        }
      } on TdError catch (e) {
        final wait = retryAfterOf(e.message);
        r.copyStates[i] = ItemState.failed;
        r.copyNotes[i] = e.message;
        if (wait == null) {
          failed++;
          logEvent('filing', 'Couldn\'t copy a post: ${e.message}', level: LogLevel.warning);
        } else {
          slowdown *= 2;
          show('Telegram asked to wait ${wait.inSeconds}s; going slower after that', done: i);
          await Future<void>.delayed(wait);
        }
      }
      await Future<void>.delayed(gap(Work.accountCopy) * slowdown);
    }
    r.copying = false;
    changed.value++;
    show('${r.stop ? 'Stopped' : 'Done'}: $copied copied${failed > 0 ? ', $failed failed' : ''}. Tap to review.');
    return (copied: copied, failed: failed);
  }

  /// Waits for the bot to list the new copy, moves what pointed at the old one to it,
  /// then deletes the old post from the main chat.
  Future<void> _swap(Song old, String newFile) async {
    for (var tries = 0; tries < 45; tries++) {
      final fresh = await app.db.songByUniqueId(newFile);
      if (fresh != null) {
        await app.db.moveReferences(old, fresh);
        await app.deleteSong(old);
        logEvent('filing', 'Replaced ${old.title} with a better copy');
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    logEvent('filing', 'Kept ${old.title}: the better copy didn\'t show up in time', level: LogLevel.warning);
  }
}

/// One chat's songs, sorted by how they relate to your library, to copy all or some.
class ChatReviewScreen extends StatefulWidget {
  const ChatReviewScreen({super.key, required this.chatId, required this.title});
  final int chatId;
  final String title;

  @override
  State<ChatReviewScreen> createState() => _ChatReviewScreenState();
}

class _ChatReviewScreenState extends State<ChatReviewScreen> {
  final _reads = ChatReads.instance;
  PostKind? _show = PostKind.isNew;
  var _spotifyOnly = false;
  final _picked = <int>{};

  ChatRead? get _read => _reads.reads[widget.chatId];
  bool get _copying => _read?.copying ?? false;

  @override
  void initState() {
    super.initState();
    if (_reads.reads[widget.chatId] == null) _reads.read(widget.chatId, widget.title);
  }

  List<ReviewItem> _shown(List<ReviewItem> all) => [
        for (final i in all)
          if ((_show == null || i.kind == _show) && (!_spotifyOnly || i.playlists.isNotEmpty)) i,
      ];

  Future<void> _copy(List<ReviewItem> items) async {
    if (items.isEmpty) return;
    final better = items.where((i) => i.kind == PostKind.better).length;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Copy ${items.length} songs?'),
        content: Text(
          'From ${widget.title} into your main chat\'s General, then they\'re filed into topics.'
          '${better > 0 ? '\n\n$better are better than the copy you have. Replace yours with them? '
              'Playlists and favorites move over, then your old post is deleted.' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          if (better > 0) TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Copy, keep mine')),
          FilledButton(
            onPressed: () => Navigator.pop(context, better > 0),
            child: Text(better > 0 ? 'Copy and replace' : 'Copy'),
          ),
        ],
      ),
    );
    if (replace == null) return;
    setState(_picked.clear);
    await _reads.copy(widget.chatId, widget.title, items, replace: replace);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Read again',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _copying ? null : () => _reads.read(widget.chatId, widget.title),
            ),
          ],
        ),
        body: ValueListenableBuilder(
          valueListenable: _reads.changed,
          builder: (context, _, _) {
            final r = _reads.reads[widget.chatId];
            if (r == null || r.reading) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Reading ${widget.title}… ${r?.found ?? 0} songs so far.\n\n'
                    "You can leave this page; you'll get a message when it's ready.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (r.error != null) return Center(child: Text(r.error!));
            final all = r.items;
            final shown = _shown(all);
            int count(PostKind k) => all.where((i) => i.kind == k).length;
            final spotify = all.where((i) => i.playlists.isNotEmpty && i.kind != PostKind.have).length;
            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      for (final k in [null, ...PostKind.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(k == null ? 'All ${all.length}' : '${k.label} ${count(k)}'),
                            selected: _show == k,
                            onSelected: (_) => setState(() {
                              _show = k;
                              _picked.clear();
                            }),
                          ),
                        ),
                      FilterChip(
                        label: Text('In your Spotify playlists $spotify'),
                        selected: _spotifyOnly,
                        onSelected: (v) => setState(() {
                          _spotifyOnly = v;
                          _picked.clear();
                        }),
                      ),
                    ],
                  ),
                ),
                if (r.copyText != null) Padding(padding: const EdgeInsets.all(12), child: Text(r.copyText!)),
                Expanded(
                  child: ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      final p = item.post;
                      return CheckboxListTile(
                        value: _picked.contains(p.id),
                        onChanged: _copying || item.kind == PostKind.have
                            ? null
                            : (v) => setState(() => v! ? _picked.add(p.id) : _picked.remove(p.id)),
                        title: Text(p.title.isEmpty ? p.fileName : p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (p.artist.isNotEmpty) p.artist,
                            audioFormat(p.mime, p.fileName),
                            formatBytes(p.size),
                            item.kind.label,
                            if (item.yours != null && item.kind == PostKind.better)
                              'yours: ${songFormat(item.yours!)} ${formatBytes(item.yours!.size)}',
                            if (item.playlists.isNotEmpty) 'in ${item.playlists.join(', ')}',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _copying
                        ? SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(onPressed: () => _read?.stop = true, child: const Text('Stop')),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: shown.where((i) => i.kind != PostKind.have).isEmpty
                                      ? null
                                      : () => setState(() => _picked
                                        ..clear()
                                        ..addAll([for (final i in shown) if (i.kind != PostKind.have) i.post.id])),
                                  child: const Text('Select all'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: app.mainChat.value == null
                                      ? null
                                      : () => _copy([
                                            for (final i in (_picked.isEmpty ? shown : all))
                                              if (i.kind != PostKind.have && (_picked.isEmpty || _picked.contains(i.post.id))) i,
                                          ]),
                                  child: Text(_picked.isEmpty ? 'Copy all shown' : 'Copy ${_picked.length}'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
