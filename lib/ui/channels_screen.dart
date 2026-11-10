import 'package:flutter/material.dart';

import '../app.dart';
import '../library/db.dart';
import '../library/topic_mover.dart';
import '../telegram/channels.dart';
import '../telegram/td_client.dart';
import 'bot_setup.dart';
import 'widgets.dart';
import 'copy_chats_screen.dart';

/// The main chat first, the rest in the order given.
List<LibraryChat> mainFirst(List<LibraryChat> chats, int? main) =>
    [...chats.where((c) => c.id == main), ...chats.where((c) => c.id != main)];

/// The channels in the library, and which one songs get filed into.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  var _here = false;
  Map<int, bool> _canPost = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final here = await app.filer.runsHere();
    final canPost = <int, bool>{};
    for (final c in await app.db.select(app.db.libraryChats).get()) {
      canPost[c.id] = await _botCanPost(c.id);
    }
    if (mounted) {
      setState(() {
        _here = here;
        _canPost = canPost;
      });
    }
  }

  Future<bool> _botCanPost(int chatId) async {
    final group = supergroupIdOf(chatId);
    if (group == null) return false;
    try {
      final info = await app.td.call({'@type': 'getSupergroup', 'supergroup_id': group});
      final status = info['status'] as Json;
      if (status['@type'] == 'chatMemberStatusCreator') return true;
      if (status['@type'] != 'chatMemberStatusAdministrator') return false;
      if (info['is_channel'] != true) return true; // Group admins can always post.
      return (status['rights'] as Json)['can_post_messages'] == true;
    } on TdError {
      return false;
    }
  }

  Future<void> _choose(LibraryChat chat) async {
    final isMain = app.mainChat.value == chat.id;
    final ok = await confirm(
      context,
      isMain ? 'Stop using ${chat.title} as the main chat?' : 'Make ${chat.title} the main chat?',
      isMain
          ? 'Songs stop being filed. Nothing already posted changes.'
          : 'The bot copies songs from your other channels here, into the topic that fits, and those '
              'originals stay. Songs in this chat\'s General move to a fitting topic: reposted, checked, '
              'then the General post is deleted. A song it can\'t place is left where it is. Duplicates '
              'are only removed from this chat.',
      isMain ? 'Stop' : 'Make main',
    );
    if (!ok) return;
    if (!isMain && !await app.botIsAdminIn(chat.id)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your bot isn't an admin there, so it can only read it. Make it an admin to use it as the main chat.")),
      );
      return;
    }
    await app.setMainChat(isMain ? null : chat.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final mover = app.filer.mover;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          // Only with your own account logged in: it's the one that can see your chats.
          ValueListenableBuilder(
            valueListenable: app.userSession.loggedIn,
            builder: (context, on, _) => on
                ? IconButton(
                    tooltip: 'Copy from your chats',
                    icon: const Icon(Icons.move_down_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const CopyChatsScreen()),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Add channels',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const BotSetupScreen()));
              await _load();
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: StreamBuilder<List<LibraryChat>>(
            stream: app.db.select(app.db.libraryChats).watch(),
            builder: (context, chats) => StreamBuilder<List<ForumTopic>>(
              stream: app.db.select(app.db.forumTopics).watch(),
              builder: (context, topics) => StreamBuilder<List<PostCopy>>(
                stream: app.db.select(app.db.postCopies).watch(),
                builder: (context, copies) => ListenableBuilder(
                listenable: Listenable.merge([
                  app.mainChat,
                  app.liveSongs,
                  mover.jobs,
                  mover.paused,
                  mover.problem,
                  mover.nextAt,
                  mover.deleteBlocked,
                  app.filer.waitingForInfo,
                ]),
                builder: (context, _) => ListView(
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
                  children: [
                    SectionCard(
                      title: 'Added channels',
                      children: [
                        for (final c in mainFirst(chats.data ?? const <LibraryChat>[], app.mainChat.value))
                          _tile(c, topics.data ?? const [], copies.data ?? const []),
                        if (chats.data?.isEmpty ?? false) const ListTile(title: Text('No channels yet')),
                      ],
                    ),
                    if (app.mainChat.value != null) _filing(mover),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(LibraryChat c, List<ForumTopic> topics, List<PostCopy> copies) {
    final scheme = Theme.of(context).colorScheme;
    final main = app.mainChat.value;
    final isMain = main == c.id;
    final here = app.liveSongs.value.values.where((s) => s.chatId == c.id).toList();
    // Songs already copied to the main chat are listed there now, but their posts are still here.
    final posts = isMain ? 0 : copies.where((x) => x.chatId == c.id).length;
    final count = topics.where((t) => t.chatId == c.id).length;
    final canPost = _canPost[c.id];
    // A song counts as safe once the main chat has a post of the same file.
    final inMain = {for (final x in copies) if (x.chatId == main) x.uniqueId};
    final notInMain = here.where((s) => !inMain.contains(s.uniqueId)).length;
    return ListTile(
      leading: Icon(isMain ? Icons.star_rounded : Icons.star_outline_rounded, color: isMain ? scheme.primary : null),
      title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          '${here.length + posts} songs',
          if (count > 0) '$count topics',
          if (isMain) 'Main chat',
          if (!isMain && main != null) notInMain == 0 ? 'All in the main chat' : '$notInMain not in the main chat yet',
          if (canPost == false) 'The bot can\'t post here',
        ].join(' · '),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'remove' ? _remove(c, notInMain) : _choose(c),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'main', child: Text(isMain ? 'Stop using as main chat' : 'Make main chat')),
          if (!isMain) const PopupMenuItem(value: 'remove', child: Text('Remove from Paper Play')),
        ],
      ),
      onTap: () => _choose(c),
    );
  }



  Future<void> _remove(LibraryChat c, int notInMain) async {
    final ok = await confirm(
      context,
      'Remove ${c.title}?',
      notInMain == 0
          ? "It's all in your main chat already. This only removes it from Paper Play, on all your devices. Telegram isn't touched, and you can add it back anytime."
          : "$notInMain songs from it aren't in your main chat yet, so they'll vanish from your library (they stay in Telegram). Better to wait for copying to finish.",
      notInMain == 0 ? 'Remove' : 'Remove anyway',
    );
    if (!ok) return;
    await app.removeChannel(c.id);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${c.title}.')));
    await _load();
  }

  Widget _filing(TopicMover mover) {
    final jobs = mover.jobs.value;
    final waiting = jobs.where((j) => j.status == MoveStatus.queued || j.status == MoveStatus.moving).length;
    final done = jobs.where((j) => j.status == MoveStatus.done).length;
    final problem = mover.problem.value;
    return SectionCard(
      title: 'Filing',
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.devices_rounded),
          title: Row(children: [Flexible(child: Text('File songs from this device')), const SizedBox(width: 4), InfoText("Turn this on for one device only, or songs get posted twice.")]),
          value: _here,
          onChanged: (v) async {
            await app.filer.setRunsHere(v);
            await _load();
          },
        ),
        if (app.filer.waitingForInfo.value > 0)
          ListTile(
            leading: const Icon(Icons.hourglass_top_rounded),
            title: Row(children: [Flexible(child: Text('Getting info for ${app.filer.waitingForInfo.value} songs first')), const SizedBox(width: 4), InfoText("Comes from your other device or online lookups, so each song lands in the right topic.")]),
          ),
        if (mover.deleteBlocked.value)
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('The bot can\'t delete posts here'),
            subtitle: const Text(
              'Songs in General aren\'t moved, so nothing is posted twice. Copying from other channels carries on. '
              'Give the bot the "Delete messages" right, then try again.',
            ),
            trailing: TextButton(
              onPressed: () {
                mover.allowDeletesAgain();
                app.filer.kick();
              },
              child: const Text('Try again'),
            ),
          ),
        if (waiting > 0 || done > 0)
          ListTile(
            leading: const Icon(Icons.drive_file_move_rounded),
            title: Text('$done filed, $waiting waiting'),
            subtitle: Text(problem ?? (mover.paused.value ? 'Paused' : 'Running')),
            trailing: TextButton(
              onPressed: () => mover.setPaused(!mover.paused.value),
              child: Text(mover.paused.value ? 'Resume' : 'Pause'),
            ),
          ),
      ],
    );
  }
}
