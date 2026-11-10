import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../library/topic_mover.dart';
import '../library/topic_sort.dart';
import 'topic_picker.dart';
import 'widgets.dart';

/// Lists songs in General with a suggested topic. Nothing moves until the owner has
/// ticked songs and confirmed.
class SortGeneralScreen extends StatefulWidget {
  const SortGeneralScreen({super.key});

  @override
  State<SortGeneralScreen> createState() => _SortGeneralScreenState();
}

typedef _Key = (int, int);

class _SortGeneralScreenState extends State<SortGeneralScreen> {
  List<TopicSuggestion>? _rows;
  Map<int, List<TopicChoice>> _topics = const {};
  final _chosen = <_Key, TopicChoice>{};
  final _ticked = <_Key>{};
  bool? _allowed;
  var _finished = 0;

  _Key _keyOf(TopicSuggestion r) => (r.song.chatId, r.song.messageId);

  @override
  void initState() {
    super.initState();
    app.mover.jobs.addListener(_onJobs);
    _load();
  }

  @override
  void dispose() {
    app.mover.jobs.removeListener(_onJobs);
    super.dispose();
  }

  void _onJobs() {
    final finished = app.mover.jobs.value.where((j) => j.status == MoveStatus.done).length;
    if (finished != _finished) {
      _finished = finished;
      _load();
    }
  }

  Future<void> _load() async {
    final songs = await app.db.select(app.db.songs).get();
    final copies = await app.db.select(app.db.postCopies).get();
    final rows = <TopicSuggestion>[];
    final topics = <int, List<TopicChoice>>{};
    for (final chat in {for (final s in songs) s.chatId}) {
      final choices = await chatTopics(chat);
      final found = suggestTopics(
        songs: songs.where((s) => s.chatId == chat).toList(),
        topics: choices,
        copies: copies.where((c) => c.chatId == chat).toList(),
      );
      if (found.isEmpty) continue;
      topics[chat] = choices;
      rows.addAll(found);
    }
    int rank(TopicSuggestion r) => r.blocked ? 3 : (r.confidence?.index ?? 2);
    rows.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.song.title.compareTo(b.song.title);
    });
    final allowed = _allowed ?? await _checkAllowed(topics.keys);
    if (!mounted) return;
    final keys = rows.map(_keyOf).toSet();
    setState(() {
      _rows = rows;
      _topics = topics;
      _allowed = allowed;
      _ticked.retainAll(keys);
      _chosen.removeWhere((k, _) => !keys.contains(k));
      for (final r in rows) {
        if (r.topic != null) _chosen.putIfAbsent(_keyOf(r), () => r.topic!);
      }
    });
  }

  Future<bool> _checkAllowed(Iterable<int> chats) async {
    for (final c in chats) {
      if (!await app.uploader.canPost(c) || !await app.canDeleteIn(c)) return false;
    }
    return chats.isNotEmpty;
  }

  Future<void> _change(TopicSuggestion r) async {
    final choices = _topics[r.song.chatId]!.where((t) => !t.isGeneral).toList();
    final picked = await pickTopic(context, choices, 'Move "${r.song.title}" to');
    if (picked == null || !mounted) return;
    setState(() {
      _chosen[_keyOf(r)] = picked;
      _ticked.add(_keyOf(r));
    });
  }

  void _tickHigh() => setState(() {
        for (final r in _rows!) {
          if (r.confidence == TopicConfidence.high && !r.blocked) _ticked.add(_keyOf(r));
        }
      });

  Future<void> _move() async {
    final moves = <MoveJob>[
      for (final r in _rows!)
        if (_ticked.contains(_keyOf(r)) && _chosen[_keyOf(r)] != null)
          MoveJob(r.song, _chosen[_keyOf(r)]!.id, _chosen[_keyOf(r)]!.name),
    ];
    final perTopic = <String, int>{};
    for (final m in moves) {
      perTopic[m.topicName] = (perTopic[m.topicName] ?? 0) + 1;
    }
    final breakdown = perTopic.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    final ok = await confirm(
      context,
      'Move ${moves.length} song${moves.length == 1 ? '' : 's'}?',
      '$breakdown\n\n'
          "Telegram can't move posts, so each song gets reposted in its new topic (no re-upload) and the General post is deleted for good. If a repost fails, the original stays and the queue stops.\n\nPlaylists, favorites, tags, covers and lyrics stay with the song. It's slow on purpose so the bot doesn't get limited. Keep Paper Play open.",
      'Move',
    );
    if (!ok || !mounted) return;
    setState(_ticked.clear);
    app.mover.start(moves);
  }

  Widget _row(TopicSuggestion r, Set<_Key> queued) {
    final key = _keyOf(r);
    final topic = _chosen[key];
    final busy = queued.contains(key);
    final level = switch (r.confidence) {
      TopicConfidence.high => 'High',
      TopicConfidence.medium => 'Medium',
      null => null,
    };
    final changed = topic != null && topic.id != r.topic?.id;
    final detail = [
      ?level,
      r.reason,
      if (changed) 'You chose ${topic.name}',
    ].join(' · ');
    final canTick = !r.blocked && topic != null && _allowed == true && !busy;
    return ListTile(
      leading: Checkbox(
        value: _ticked.contains(key),
        onChanged: canTick
            ? (v) => setState(() => v == true ? _ticked.add(key) : _ticked.remove(key))
            : null,
      ),
      title: Text('${r.song.title} – ${r.song.artist}', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(busy ? 'Queued to move' : detail, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: r.blocked || busy
          ? null
          : TextButton(onPressed: () => _change(r), child: Text(topic?.name ?? 'Choose')),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: app.mover.jobs,
        builder: (context, jobs, _) {
          final rows = _rows;
          final waiting = {
            for (final j in jobs)
              if (j.status == MoveStatus.queued || j.status == MoveStatus.moving) (j.song.chatId, j.song.messageId),
          };
          final high = rows?.where((r) => r.confidence == TopicConfidence.high && !r.blocked).length ?? 0;
          return Scaffold(
            appBar: AppBar(title: const Text('Sort General')),
            floatingActionButton: _ticked.isEmpty || app.mover.active
                ? null
                : FloatingActionButton.extended(
                    icon: const Icon(Icons.drive_file_move_rounded),
                    label: Text('Move ${_ticked.length}'),
                    onPressed: _move,
                  ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: rows == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 96),
                        children: [
                          if (jobs.isNotEmpty) _MoveProgress(jobs: jobs),
                          if (rows.isEmpty) const ListTile(title: Text('No songs to sort in General.')),
                          if (_allowed == false)
                            const ListTile(
                              leading: Icon(Icons.info_outline_rounded),
                              title: Text('Moving needs the bot to be an admin that can post and delete messages.'),
                            ),
                          if (rows.isNotEmpty)
                            ListTile(
                              subtitle: Text(
                                '${rows.length} songs in General. Nothing is ticked for you: tick what\'s right, '
                                'change a topic if it\'s wrong, then confirm once.',
                              ),
                              trailing: high == 0 || _allowed != true
                                  ? null
                                  : TextButton(onPressed: _tickHigh, child: Text('Tick $high high')),
                            ),
                          for (final r in rows) _row(r, waiting),
                        ],
                      ),
              ),
            ),
          );
        },
      );
}

class _MoveProgress extends StatefulWidget {
  const _MoveProgress({required this.jobs});
  final List<MoveJob> jobs;

  @override
  State<_MoveProgress> createState() => _MoveProgressState();
}

class _MoveProgressState extends State<_MoveProgress> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && app.mover.nextAt.value != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = widget.jobs;
    final settled = jobs.where((j) => j.status != MoveStatus.queued && j.status != MoveStatus.moving).length;
    final moved = jobs.where((j) => j.status == MoveStatus.done).length;
    final next = app.mover.nextAt.value;
    final seconds = next?.difference(DateTime.now()).inSeconds.clamp(0, 99999);
    return ValueListenableBuilder(
      valueListenable: app.mover.paused,
      builder: (context, paused, _) => ValueListenableBuilder(
        valueListenable: app.mover.problem,
        builder: (context, problem, _) => SectionCard(
          title: 'Moved $moved · $settled of ${jobs.length} finished',
          children: [
            if (app.mover.active) LinearProgressIndicator(value: jobs.isEmpty ? 0 : settled / jobs.length),
            if (paused && problem == null) const ListTile(dense: true, title: Text('Paused')),
            if (!paused && seconds != null) ListTile(dense: true, title: Text('Next in ${seconds}s')),
            if (problem != null)
              ListTile(
                leading: Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
                title: Text(problem),
                subtitle: const Text('Stopped. Resume carries on with the next song.'),
              ),
            for (final j in jobs.where((j) => j.status == MoveStatus.skipped))
              ListTile(dense: true, title: Text(j.song.title), subtitle: Text(j.note ?? 'Skipped')),
            if (app.mover.active || paused)
              OverflowBar(
                children: [
                  TextButton(
                    onPressed: () => app.mover.setPaused(!paused),
                    child: Text(paused ? 'Resume' : 'Pause after this song'),
                  ),
                  TextButton(onPressed: app.mover.cancel, child: const Text('Cancel the rest')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
