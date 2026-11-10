import 'dart:convert';

import 'package:flutter/material.dart';

import '../app.dart';
import '../library/auto_filer.dart';
import '../metadata/enricher.dart' show cleanTitle, comparableText, firstArtist, searchTitle;
import '../library/upload.dart' show retryAfterOf;
import '../log.dart';
import '../pace.dart';
import '../telegram/channels.dart' show BotCheck;
import '../telegram/td_client.dart';
import 'chat_review.dart';
import 'widgets.dart';

/// With your own account logged in: pick any of your groups and channels and copy their
/// songs into the main chat's General, where filing sorts them into topics. The
/// originals stay where they are.
class CopyChatsScreen extends StatefulWidget {
  const CopyChatsScreen({super.key});

  @override
  State<CopyChatsScreen> createState() => _CopyChatsScreenState();
}

class _CopyChatsScreenState extends State<CopyChatsScreen> {
  List<({int id, String title, bool channel})>? _chats;
  String? _error;
  final _picked = <int>{};
  String? _progress;
  var _running = false, _stop = false;
  var _query = '';

  /// Chats already in the library as channels.
  var _added = <int>{};

  /// What was copied from each chat before: songs copied, songs skipped, when.
  var _done = <String, dynamic>{};
  static const _doneKey = 'copied_chats';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _chats = null;
      _error = null;
    });
    try {
      final main = app.mainChat.value;
      final all = await app.userSession.groupsAndChannels();
      final added = {for (final c in await app.db.select(app.db.libraryChats).get()) c.id};
      final done = jsonDecode(await app.db.pref(_doneKey) ?? '{}') as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _chats = [for (final c in all) if (c.id != main) c];
          _added = added;
          _done = done;
        });
      }
    } on TdError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Adds a chat to the library's channels, so the bot reads it like the others. The bot
  /// has to be in the chat; if it isn't, your account can add it there first.
  Future<void> _addChannel(int id, String title) async {
    final messenger = ScaffoldMessenger.of(context);
    final token = await loadBotToken();
    if (token == null) return;
    Future<BotCheck?> tryAdd() async {
      BotCheck? last;
      await for (final check in app.addChannels(token, [ChannelRef(chatId: id)])) {
        last = check;
        if (check.added) return check;
      }
      return last;
    }

    var result = await tryAdd();
    if (result?.added != true && mounted) {
      final invite = await confirm(
        context,
        'Add your bot to $title?',
        "Your bot isn't in that chat, so it can't read it. Your account can add it as a member, "
            "which is enough to read and play. It can't post there unless you make it an admin.",
        'Add bot',
      );
      if (!invite) return;
      try {
        final bot = await app.td.call({'@type': 'getMe'});
        await app.userSession.td.call({'@type': 'addChatMember', 'chat_id': id, 'user_id': bot['id'], 'forward_limit': 0});
        result = await tryAdd();
      } on TdError catch (e) {
        messenger.showSnackBar(SnackBar(content: Text("Couldn't add the bot: ${e.message}")));
        return;
      }
    }
    messenger.showSnackBar(SnackBar(
      content: Text(result?.added == true ? 'Added $title. The bot reads it now.' : 'Not added: ${result?.detail ?? 'unknown reason'}'),
    ));
    await _load();
  }

  /// Reads the picked chats in the background; each says when it's ready to review.
  void _readPicked() {
    for (final c in _chats!.where((c) => _picked.contains(c.id))) {
      ChatReads.instance.read(c.id, c.title);
    }
    setState(() {
      _picked.clear();
      _progress = "Reading in the background. You'll get a message with a Review button for each.";
    });
  }

  // ignore: unused_element
  Future<void> _copy() async {
    final main = app.mainChat.value;
    if (main == null || _picked.isEmpty) return;
    setState(() {
      _running = true;
      _stop = false;
    });
    // What the library already has: the same file, or the same song in another file.
    final songs = await app.db.select(app.db.songs).get();
    final copies = await app.db.select(app.db.postCopies).get();
    final files = {for (final s in songs) s.uniqueId, for (final c in copies) c.uniqueId};
    final keys = [for (final s in songs) songKey(s)];
    var copied = 0, skipped = 0;
    // Halved each time Telegram asks this account to wait, for the rest of the run.
    var slowdown = 1;
    for (final chat in _chats!.where((c) => _picked.contains(c.id))) {
      if (_stop) break;
      setState(() => _progress = 'Reading ${chat.title}…');
      final posts = await app.userSession.songsIn(chat.id);
      final copiedBefore = copied, skippedBefore = skipped;
      for (final (i, post) in posts.indexed) {
        if (_stop) break;
        // Matched the same way filing does (cleaned title, first artist, length).
        final key = (
          comparableText(searchTitle(cleanTitle(post.title, post.artist))),
          comparableText(firstArtist(post.artist)),
          post.duration,
        );
        final known = files.contains(post.uniqueId) ||
            (post.duration > 0 && keys.any((k) => k.$1 == key.$1 && k.$2 == key.$2 && (k.$3 - key.$3).abs() <= 3));
        if (known) {
          skipped++;
          continue;
        }
        if (mounted) setState(() => _progress = '${chat.title}: ${i + 1} of ${posts.length} · $copied copied, $skipped already there');
        try {
          await app.userSession.copyPost(chat.id, post.id, main);
          files.add(post.uniqueId);
          copied++;
        } on TdError catch (e) {
          final wait = retryAfterOf(e.message);
          if (wait == null) {
            logEvent('filing', 'Couldn\'t copy a post from ${chat.title}: ${e.message}', level: LogLevel.warning);
            continue;
          }
          slowdown *= 2;
          if (mounted) setState(() => _progress = 'Telegram asked to wait ${wait.inSeconds}s; going slower after that.');
          await Future<void>.delayed(wait);
        }
        await Future<void>.delayed(gap(Work.accountCopy) * slowdown);
      }
      // Remembered, so the list can say what's already been done.
      _done['${chat.id}'] = {
        'copied': copied - copiedBefore,
        'skipped': skipped - skippedBefore,
        'total': posts.length,
        'finished': !_stop,
        'at': DateTime.now().millisecondsSinceEpoch,
      };
      await app.db.setPref(_doneKey, jsonEncode(_done));
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _progress = '${_stop ? 'Stopped' : 'Done'}: $copied copied, $skipped were already in your library. '
          'They land in General, then get filed into topics.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Flexible(child: Text('Copy from your chats')),
            SizedBox(width: 4),
            InfoText(
              "Your account copies the songs from the chats you pick into your main chat's General, oldest first, "
              "at the speed set in Settings, Telegram. If Telegram asks to wait, it waits and goes slower. Filing then sorts them into topics. Songs you already have are skipped, "
              "and the originals stay where they are.",
            ),
          ]),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _running ? null : _load,
            ),
          ],
        ),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : _chats == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search your chats',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                        ),
                      ),
                      if (_progress != null)
                        Padding(padding: const EdgeInsets.all(16), child: Text(_progress!)),
                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: ChatReads.instance.changed,
                          builder: (context, _, _) => ListView(
                          children: [
                            for (final c in _chats!.where((c) => c.title.toLowerCase().contains(_query)))
                              ListTile(
                                leading: Checkbox(
                                  value: _picked.contains(c.id),
                                  onChanged: _running
                                      ? null
                                      : (v) => setState(() => v! ? _picked.add(c.id) : _picked.remove(c.id)),
                                ),
                                title: Text(c.title),
                                subtitle: _status(c.id),
                                trailing: _added.contains(c.id)
                                    ? Icon(c.channel ? Icons.campaign_rounded : Icons.groups_rounded)
                                    : IconButton(
                                        tooltip: 'Add to my channels',
                                        icon: const Icon(Icons.playlist_add_rounded),
                                        onPressed: _running ? null : () => _addChannel(c.id, c.title),
                                      ),
                                // Opens the chat's songs, to copy all or only some.
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(builder: (_) => ChatReviewScreen(chatId: c.id, title: c.title)),
                                ),
                              ),
                          ],
                        ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: _running
                                ? OutlinedButton(onPressed: () => _stop = true, child: const Text('Stop'))
                                : FilledButton(
                                    onPressed: _picked.isEmpty || app.mainChat.value == null ? null : _readPicked,
                                    child: Text(app.mainChat.value == null
                                        ? 'Choose a main chat first'
                                        : 'Read ${_picked.length} chats, then review'),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
      );

  /// What's already true of a chat: in the library, copied before, and how much.
  Widget? _status(int id) {
    final read = ChatReads.instance.reads[id];
    final parts = <String>[
      if (_added.contains(id)) 'Added as a channel',
      if (read != null && read.reading) 'Reading… ${read.found} songs',
      if (read != null && !read.reading && read.error == null)
        'Read: ${read.items.length} songs, ${read.items.where((i) => i.kind == PostKind.isNew).length} new',
      if (_done['$id'] case final Map d)
        '${d['finished'] == true ? 'Copied' : 'Partly copied'} ${_ago(d['at'] as int)}: '
            '${d['copied']} new, ${d['skipped']} already had, of ${d['total']}',
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }

  static String _ago(int at) {
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} days ago';
  }
}
