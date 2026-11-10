import 'package:flutter/material.dart';

import '../app.dart';
import '../library/db.dart';
import '../library/mood.dart' show TasteList;
import '../library/taste.dart';
import 'widgets.dart';
import 'playlists.dart' show mainChatTopics;

/// What daily mixes learn from and how they behave. Applies on all devices.
class MixSettingsScreen extends StatelessWidget {
  const MixSettingsScreen({super.key});

  void _update(TasteSettings Function(TasteSettings) change) => app.setTaste(change(app.taste.value));

  Future<void> _clear(BuildContext context) async {
    final ok = await confirm(
      context,
      'Clear what mixes have learned?',
      'This clears play and skip counts and your "Doesn\'t fit this mix" choices, on all your '
          'devices. Lyrics and genres stay, and so does Recently played. It can\'t be undone.',
      'Clear',
    );
    if (!ok) return;
    final songs = app.liveSongs.value.values;
    final plays = songs.fold<int>(0, (a, s) => a + s.plays);
    final skips = songs.fold<int>(0, (a, s) => a + s.skips);
    final choices = (await app.db.select(app.db.moodVotes).get()).length;
    await app.clearLearning();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cleared $plays play${plays == 1 ? '' : 's'}, $skips skip${skips == 1 ? '' : 's'} '
            'and $choices "Doesn\'t fit" choice${choices == 1 ? '' : 's'}.'),
      ));
    }
  }

  Future<void> _rename(BuildContext context, ForumTopic topic, String key, TasteSettings taste) async {
    final name = await askText(
      context,
      'Rename topic',
      label: 'Name in Paper Play',
      hint: topic.name,
      initial: taste.topicNames[key] ?? topic.name,
    );
    if (name == null) return;
    final names = {...taste.topicNames};
    name.trim().isEmpty ? names.remove(key) : names[key] = name.trim();
    _update((t) => t.copyWith(topicNames: names));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily mixes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ValueListenableBuilder(
            valueListenable: app.taste,
            builder: (context, taste, _) => StreamBuilder<List<Playlist>>(
              stream: app.db.watchPlaylists(),
              builder: (context, playlists) => StreamBuilder<List<ForumTopic>>(
                stream: app.db.watchTopics(),
                builder: (context, topics) => ListView(
                  padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
                  children: [
                    SectionCard(
                      title: 'Mixes',
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.auto_awesome_rounded),
                          title: const Text('Show daily mixes on Home'),
                          value: taste.showMixes,
                          onChanged: (v) => _update((t) => t.copyWith(showMixes: v)),
                        ),
                        SwitchListTile(
                          secondary: const Icon(Icons.filter_alt_rounded),
                          title: Row(children: [Flexible(child: Text('Only use songs from the lists below')), const SizedBox(width: 4), InfoText("When off, mixes can also bring in other songs you might like.")]),
                          value: taste.onlyFromLists,
                          onChanged: (v) => _update((t) => t.copyWith(onlyFromLists: v)),
                        ),
                        SwitchListTile(
                          secondary: const Icon(Icons.bedtime_rounded),
                          title: const Text('Rest songs you just heard'),
                          subtitle: const Text('They come back over about a week.'),
                          value: taste.restRecent,
                          onChanged: (v) => _update((t) => t.copyWith(restRecent: v)),
                        ),
                      ],
                    ),
                    SectionCard(
                      title: 'Learn your taste from',
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.favorite_rounded),
                          title: const Text('Favorites'),
                          value: taste.learnsFrom(TasteSettings.favoritesKey),
                          onChanged: (v) => app.setTasteSource(TasteSettings.favoritesKey, v),
                        ),
                        for (final p in playlists.data ?? const <Playlist>[])
                          SwitchListTile(
                            secondary: const Icon(Icons.queue_music_rounded),
                            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            value: taste.learnsFrom(TasteSettings.playlistKey(p.uuid)),
                            onChanged: (v) => app.setTasteSource(TasteSettings.playlistKey(p.uuid), v),
                          ),
                        for (final topic in mainChatTopics(topics.data))
                          _TopicSwitch(topic: topic, taste: taste, onRename: _rename),
                        SwitchListTile(
                          secondary: const Icon(Icons.play_circle_rounded),
                          title: Row(children: [Flexible(child: Text('What I play and skip')), const SizedBox(width: 4), InfoText("Off by default, so mixes only learn from your lists.")]),
                          value: taste.learnFromPlays,
                          onChanged: (v) => _update((t) => t.copyWith(learnFromPlays: v)),
                        ),
                      ],
                    ),
                    SectionCard(
                      title: 'Song information',
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.travel_explore_rounded),
                          title: Row(children: [Flexible(child: Text('Look up lyrics and genres')), const SizedBox(width: 4), InfoText("Looks up about one song a second in the background (LRCLIB and iTunes). Mixes are a lot worse without it.")]),
                          value: taste.lookups,
                          onChanged: (v) => _update((t) => t.copyWith(lookups: v)),
                        ),
                        StreamBuilder<int>(
                          stream: app.db.watchMoodScanned(),
                          builder: (context, scanned) => ListTile(
                            leading: const Icon(Icons.analytics_outlined),
                            title: Text('${scanned.data ?? 0} of ${app.liveSongs.value.length} songs looked up'),
                          ),
                        ),
                      ],
                    ),
                    SectionCard(
                      title: 'Learned data',
                      children: [
                        const _LearnedNow(),
                        ListTile(
                          leading: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error),
                          title: const Text('Clear what mixes have learned'),
                          subtitle: const Text('Play and skip counts, and "Doesn\'t fit this mix" choices.'),
                          onTap: () => _clear(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the mixes know right now: how many plays, skips and choices, which lists they learn
/// from, and when it was last cleared, so a clear can be seen to have worked.
class _LearnedNow extends StatelessWidget {
  const _LearnedNow();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([app.liveSongs, app.taste]),
        builder: (context, _) => StreamBuilder<List<MoodVote>>(
          stream: app.db.watchMoodVotes(),
          builder: (context, votes) => FutureBuilder<List<TasteList>>(
            future: app.tasteLists(),
            builder: (context, lists) {
              final songs = app.liveSongs.value.values;
              final played = songs.where((s) => s.plays > 0).length;
              final plays = songs.fold<int>(0, (a, s) => a + s.plays);
              final skipped = songs.where((s) => s.skips > 0).length;
              final skips = songs.fold<int>(0, (a, s) => a + s.skips);
              final choices = votes.data?.where((v) => v.vote != 0).length ?? 0;
              final reset = app.taste.value.resetAt;
              final names = lists.data?.map((l) => l.name).toList() ?? const <String>[];
              String when() {
                if (reset <= 0) return 'Never cleared';
                final d = DateTime.fromMillisecondsSinceEpoch(reset);
                return 'Last cleared ${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
              }

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_circle_outline_rounded),
                    title: Text('$plays play${plays == 1 ? '' : 's'} across $played song${played == 1 ? '' : 's'}'),
                    subtitle: const Text('Songs you listened to most of the way'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.skip_next_rounded),
                    title: Text('$skips skip${skips == 1 ? '' : 's'} across $skipped song${skipped == 1 ? '' : 's'}'),
                    subtitle: const Text('Songs you left within seconds'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.thumb_down_alt_outlined),
                    title: Text('$choices "Doesn\'t fit this mix" choice${choices == 1 ? '' : 's'}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(names.isEmpty ? 'Not learning from any list' : 'Learning from ${names.length} list${names.length == 1 ? '' : 's'}'),
                    subtitle: names.isEmpty ? null : Text(names.join(', '), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(when()),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _TopicSwitch extends StatelessWidget {
  const _TopicSwitch({required this.topic, required this.taste, required this.onRename});
  final ForumTopic topic;
  final TasteSettings taste;
  final Future<void> Function(BuildContext, ForumTopic, String, TasteSettings) onRename;

  @override
  Widget build(BuildContext context) {
    final key = TasteSettings.topicKey(topic.chatId, topic.topicId);
    return ListTile(
      leading: const Icon(Icons.tag_rounded),
      title: Text(taste.topicNames[key] ?? topic.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: const Text('Telegram topic'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: () => onRename(context, topic, key, taste),
          ),
          Switch(
            value: taste.learnsFrom(key),
            onChanged: (v) => app.setTasteSource(key, v),
          ),
        ],
      ),
    );
  }
}
