import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../library/audio_info.dart';
import '../library/delete_job.dart';
import '../library/duplicates.dart';
import '../library/taste.dart';
import 'channels_screen.dart';
import 'quality_badge.dart';
import 'widgets.dart';

/// Lists repeated songs, and deletes the chosen posts from Telegram after asking.
class DuplicatesScreen extends StatefulWidget {
  const DuplicatesScreen({super.key});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  List<DuplicateGroup>? _groups;
  Map<(int, int), String> _topics = const {};
  final _ticked = <(int, int)>{};
  bool? _canDelete;
  String? _progress;

  @override
  void initState() {
    super.initState();
    app.deletions.addListener(_onDeletions);
    _onDeletions();
    _load();
  }

  Future<void> _load() async {
    final songs = await app.db.select(app.db.songs).get();
    final copies = await app.db.select(app.db.postCopies).get();
    final topics = await app.db.select(app.db.forumTopics).get();
    final names = app.taste.value.topicNames;
    final main = app.mainChat.value;
    final canDelete = main != null && await app.canDeleteIn(main);
    var groups = main == null ? const <DuplicateGroup>[] : findDuplicates(songs, copies, onlyChat: main);
    // A post Telegram no longer has would be listed as a repeat forever, and its copies couldn't
    // be deleted. Ask once, drop what is gone, and list again.
    if (main != null && groups.isNotEmpty) {
      final dropped = await app.dropGonePosts([
        for (final g in groups)
          for (final p in [g.keep, ...g.others]) (p.chatId, p.messageId),
      ]);
      if (dropped > 0) {
        groups = findDuplicates(
          await app.db.select(app.db.songs).get(),
          await app.db.select(app.db.postCopies).get(),
          onlyChat: main,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _canDelete = canDelete;
      _topics = {
        for (final t in topics)
          (t.chatId, t.topicId): names[TasteSettings.topicKey(t.chatId, t.topicId)] ?? t.name,
      };
      _ticked.clear();
    });
  }

  (int, int) _keyOf(DuplicatePost p) => (p.chatId, p.messageId);

  /// The delete job for [p], if it was sent for deletion: its state shows on the row at once.
  DeleteJob? _jobOf(DuplicatePost p) =>
      app.deletions.value.where((j) => j.isDuplicate && j.postChat == p.chatId && j.postMessage == p.messageId).lastOrNull;

  /// Being deleted right now: not to be ticked again until it has finished.
  bool _busy(DuplicatePost p) {
    final s = _jobOf(p)?.status;
    return s == DeleteStatus.queued || s == DeleteStatus.deleting;
  }

  bool _isTicked(DuplicatePost p) => _ticked.contains(_keyOf(p));

  String? _topicOf(DuplicatePost p) {
    final id = p.topicId;
    if (id == null) return null;
    return _topics[(p.chatId, id)] ?? (id == generalTopicId ? 'General' : 'Unnamed topic');
  }

  Future<void> _delete() async {
    final groups = _groups!;
    final count = _ticked.length;
    final ok = await confirm(
      context,
      'Delete $count post${count == 1 ? '' : 's'} from Telegram?',
      'Each ticked post is removed from the channel for everyone, and this can\'t be undone. '
          'Every song keeps at least one post, and its playlists and favorites follow that post.',
      'Delete',
    );
    if (!ok || !mounted) return;
    final pairs = <(DuplicatePost, DuplicatePost)>[];
    for (final g in groups) {
      final keep = survivorOf(g, _isTicked);
      if (keep == null) continue;
      for (final post in [g.keep, ...g.others].where(_isTicked)) {
        pairs.add((post, keep));
      }
    }
    // Runs in the app, not here: leaving the page doesn't stop it, and Tasks shows it. The rows
    // show "Waiting to delete" straight away, since the jobs are listed before anything is sent.
    app.deleteDuplicates(pairs);
    setState(_ticked.clear);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleting $count post${count == 1 ? '' : 's'} in the background. See Tasks.')),
    );
  }

  Timer? _reload;
  var _doneSeen = 0;
  var _reported = false;

  /// Follows the delete queue: progress line now, and the list refreshed as posts go.
  void _onDeletions() {
    final jobs = app.deletions.value.where((j) => j.isDuplicate).toList();
    final waiting = jobs.where((j) => j.status == DeleteStatus.queued || j.status == DeleteStatus.deleting).length;
    final done = jobs.where((j) => j.status == DeleteStatus.done || j.status == DeleteStatus.skipped).length;
    final failed = jobs.where((j) => j.status == DeleteStatus.failed).length;
    if (!mounted) return;
    setState(() => _progress = waiting == 0 ? null : 'Deleting ${done + failed + 1} of ${jobs.length}');
    if (waiting == 0 && failed > 0 && !_reported) {
      _reported = true;
      final reasons = {for (final j in jobs) if (j.status == DeleteStatus.failed) j.error ?? 'Failed'};
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('$done deleted, $failed not: ${reasons.take(2).join(' ')}'),
      ));
    }
    if (waiting > 0) _reported = false;
    if (done != _doneSeen || waiting == 0) {
      _doneSeen = done;
      _reload ??= Timer(const Duration(milliseconds: 800), () {
        _reload = null;
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    app.deletions.removeListener(_onDeletions);
    _reload?.cancel();
    super.dispose();
  }

  /// One post of a song: where it is, and what happens to it.
  Widget _post(DuplicateGroup g, DuplicatePost post) {
    final colors = Theme.of(context).colorScheme;
    final ticked = _isTicked(post);
    // Ticking the last unticked post would delete the song itself.
    final isLast = !ticked && survivorOf(g, (p) => p == post || _isTicked(p)) == null;
    final best = post == g.keep && g.kind == DuplicateKind.likelySameSong && g.suggested.isNotEmpty;
    final posted = DateTime.fromMillisecondsSinceEpoch(post.date * 1000);
    final known = post.song ?? g.keep.song;
    final where = [
      ?_topicOf(post),
      known == null ? post.format : qualityLine(known),
      formatBytes(post.size),
      '${posted.day}/${posted.month}/${posted.year}',
    ].join(' · ');
    final job = _jobOf(post);
    final fate = job != null
        ? switch (job.status) {
            DeleteStatus.queued => 'Waiting to delete',
            DeleteStatus.deleting => 'Deleting…',
            DeleteStatus.done => 'Deleted',
            DeleteStatus.skipped => job.error ?? 'Stays',
            DeleteStatus.failed => 'Not deleted: ${job.error ?? 'failed'}',
          }
        : ticked
        ? 'Will be deleted'
        : isLast
            ? 'Stays: a song always keeps one post'
            : best
                ? 'Stays · best quality'
                : 'Stays';
    return CheckboxListTile(
      controlAffinity: ListTileControlAffinity.leading,
      secondary: known == null ? null : QualityGlyph(songTier(known), size: 20, color: colors.onSurfaceVariant),
      value: ticked,
      enabled: _canDelete == true && _progress == null && !isLast && !_busy(post),
      title: Text(where, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (job != null && (job.status == DeleteStatus.queued || job.status == DeleteStatus.deleting))
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Flexible(child: Text(fate, style: TextStyle(color: ticked || job?.status == DeleteStatus.failed ? colors.error : colors.primary))),
          ]),
          if (post.fileName.isNotEmpty) Text(post.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      onChanged: (v) => setState(() => v == true ? _ticked.add(_keyOf(post)) : _ticked.remove(_keyOf(post))),
    );
  }

  Widget _card(DuplicateGroup g) => SectionCard(
        title: '${g.title} – ${g.artist}',
        children: [
          ListTile(
            leading: Cover(g.keep.song, size: 48),
            title: Text(describeDuplicate(g, _topicOf)),
          ),
          _post(g, g.keep),
          for (final o in g.others) _post(g, o),
        ],
      );

  /// Ticks every post in General that isn't the best copy of its song. A General post that is the
  /// best stays, so each song keeps its highest quality file.
  void _tickGeneral(List<DuplicateGroup> groups) => setState(() {
        for (final g in groups) {
          for (final p in [g.keep, ...g.others]) {
            final inGeneral = p.topicId == null || p.topicId == generalTopicId;
            if (inGeneral && p != g.keep && !_busy(p)) _ticked.add(_keyOf(p));
          }
        }
      });

  void _tickExtras(List<DuplicateGroup> groups) => setState(() {
        for (final g in groups) {
          _ticked.addAll([
            for (final o in g.others)
              if (g.suggested.contains(o.messageId)) _keyOf(o),
          ]);
        }
      });

  /// A kind of repeat: what it means, then the songs.
  List<Widget> _section(DuplicateSection section, List<DuplicateGroup> all) {
    final groups = all.where((g) => sectionOf(g) == section).toList();
    if (groups.isEmpty) return const [];
    final (title, meaning) = switch (section) {
      DuplicateSection.extras => (
          'Extra copies',
          'Repeats in the same topic, or a clearly lower quality copy. Usually safe to remove.',
        ),
      DuplicateSection.otherTopics => (
          'Same file in different topics',
          'You may have filed these on purpose. Remove one only if the song shouldn\'t be in that topic.',
        ),
      DuplicateSection.maybe => (
          'Might be the same song',
          'These only look alike, so listen before removing one.',
        ),
    };
    return [
      ListTile(
        title: Text('$title (${groups.length})', style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(meaning),
        trailing: section == DuplicateSection.extras && _canDelete == true && _progress == null
            ? TextButton(onPressed: () => _tickExtras(groups), child: const Text('Tick extras'))
            : null,
      ),
      ...groups.map(_card),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicates')),
      floatingActionButton: _ticked.isEmpty || _canDelete != true || _progress != null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('Delete ${_ticked.length}'),
              onPressed: _delete,
            ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: groups == null
              ? const Center(child: CircularProgressIndicator())
              : app.mainChat.value == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Duplicates are only removed from your main chat.'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(builder: (_) => const ChannelsScreen()),
                              );
                              await _load();
                            },
                            child: const Text('Choose a main chat'),
                          ),
                        ],
                      ),
                    )
                  : groups.isEmpty
                  ? const Center(child: Text('No duplicates in your main chat.'))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: [
                        if (_progress != null) ListTile(title: Text(_progress!), subtitle: const LinearProgressIndicator()),
                        if (_canDelete == false)
                          const ListTile(
                            leading: Icon(Icons.info_outline_rounded),
                            title: Text('The bot can\'t delete here. Make it an admin with the "Delete messages" right.'),
                          ),
                        ListTile(
                          trailing: _canDelete == true && _progress == null
                              ? TextButton(onPressed: () => _tickGeneral(groups), child: const Text('Tick General'))
                              : null,
                          title: Text('${groups.length} song${groups.length == 1 ? ' is' : 's are'} posted more than once in your main chat'),
                          subtitle: const Text(
                            'Other channels aren\'t touched. Each song below lists its posts. Tick the ones to '
                            'remove, and the rest stay. Nothing is deleted until you confirm.',
                          ),
                        ),
                        for (final section in DuplicateSection.values) ..._section(section, groups),
                      ],
                    ),
        ),
      ),
    );
  }
}
