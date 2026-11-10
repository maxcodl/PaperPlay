import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'activity.dart' show thousands;
import 'library/db.dart';
import 'library/delete_job.dart';
import 'library/task_history.dart';
import 'library/topic_mover.dart';
import 'library/upload.dart';
import 'metadata/enricher.dart';
import 'ui/chat_review.dart' show ChatReads;

/// What a kind of work looks like right now.
class _Built {
  const _Built(this.title, this.items, {this.total, this.done, this.note, this.running = true});
  final String title;
  final List<TaskItem> items;
  final int? total, done;
  final String? note;
  final bool running;
}

/// Kinds that can be stopped. Checking channels can't. `from:<chat>` is copying a
/// channel's songs into the main chat.
const stoppableKinds = {'copy', 'filing', 'upload', 'delete', 'info', 'covers'};
bool canStop(String kind) => stoppableKinds.contains(kind) || kind.startsWith('from:');

/// Follows everything the app is busy with as runs: live here, live on other devices,
/// and history kept on both. A run starts when work appears and ends when it's done.
class TaskCenter {
  TaskCenter(this._s);
  final Services _s;

  static const _maxLocalItems = 500;
  static const _wireItems = 150;

  /// Running here.
  final live = ValueNotifier<List<TaskRun>>([]);

  /// Running on other devices, by device id.
  final remote = ValueNotifier<Map<String, List<TaskRun>>>({});

  /// Finished here or on another device, newest first.
  final history = ValueNotifier<List<TaskRun>>([]);

  final _runs = <String, TaskRun>{};
  Timer? _debounce;
  var _lastSent = '[]';
  var _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    history.value = await loadTaskHistory(_s.db);
    _s.link.liveTasks = _wire;
    Listenable.merge([
      _s.scanner.progress,
      _s.mover.jobs,
      _s.mover.paused,
      _s.filer.mover.jobs,
      _s.filer.mover.paused,
      _s.uploader.jobs,
      _s.deletions,
      _s.enricher.run,
      _s.enricher.coversQueued,
      _s.enricher.coversBatch,
      _s.stats,
      ChatReads.instance.changed,
      _s.moodScanned,
      _s.taste,
      _s.lengthWork,
    ]).addListener(_schedule);
    _schedule();
  }

  Future<void> reloadHistory() async => history.value = await loadTaskHistory(_s.db);

  void _schedule() {
    _debounce ??= Timer(const Duration(milliseconds: 500), () {
      _debounce = null;
      _refresh();
    });
  }

  List<Map<String, dynamic>> _wire() => [for (final r in _runs.values) r.toJson(maxItems: _wireItems)];

  void _refresh() {
    final built = _build();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final e in built.entries) {
      var run = _runs[e.key];
      if (run == null) {
        if (!e.value.running) continue;
        run = _runs[e.key] = TaskRun(
          id: '${newUuid().substring(0, 8)}-${e.key}-$now',
          kind: e.key,
          title: e.value.title,
          device: _s.link.deviceName,
          startedAt: now,
        );
      }
      _merge(run, e.value);
      if (!e.value.running) _finish(e.key, now);
    }
    // Work that vanished since the last look, such as a queue that was emptied.
    for (final kind in _runs.keys.toList()) {
      if (!built.containsKey(kind)) _finish(kind, now);
    }
    live.value = _runs.values.toList();
    final wire = jsonEncode(_wire());
    if (wire != _lastSent) {
      _lastSent = wire;
      _s.link.sendTasks(_wire());
    }
  }

  void _merge(TaskRun run, _Built b) {
    run.title = b.title;
    run.note = b.note;
    final byKey = {for (final i in run.items) i.key: i};
    final seen = <String>{};
    for (final i in b.items) {
      seen.add(i.key);
      final have = byKey[i.key];
      if (have != null) {
        have
          ..state = i.state
          ..sub = i.sub;
      } else if (run.items.length < _maxLocalItems) {
        run.items.add(i);
        byKey[i.key] = i;
      }
    }
    // Gone from the queue: finished, or dropped by a stop.
    for (final i in run.items) {
      if (!seen.contains(i.key) && (i.state == ItemState.waiting || i.state == ItemState.active)) {
        i.state = run.stopped ? ItemState.cancelled : ItemState.done;
      }
    }
    run.failed = run.items.where((i) => i.state == ItemState.failed).length;
    final finished = run.items.where((i) => i.state == ItemState.done || i.state == ItemState.failed).length;
    run.total = b.total ?? run.items.length;
    run.done = b.done ?? finished;
  }

  void _finish(String kind, int now) {
    final run = _runs.remove(kind);
    if (run == null) return;
    run.endedAt = now;
    for (final i in run.items) {
      if (i.state == ItemState.waiting || i.state == ItemState.active) {
        i.state = run.stopped ? ItemState.cancelled : ItemState.done;
      }
    }
    run.items = run.itemsByImportance().take(_wireItems).toList();
    // Checking channels is a status line, not a record worth keeping.
    if (kind == 'scan' || run.total == 0) return;
    history.value = [run, ...history.value].take(maxHistory).toList();
    unawaited(saveTaskHistory(_s.db, history.value).then((_) => _s.db.announceChange()));
  }

  /// Stops a kind of work here. A file being handled right now finishes first.
  void stop(String kind) {
    _runs[kind]?.stopped = true;
    void dropQueued(TopicMover m, {required bool copies}) {
      m.jobs.value = m.jobs.value.where((j) => j.status != MoveStatus.queued || (j.toChat != null) != copies).toList();
    }

    switch (kind) {
      case 'copy' || 'filing':
        for (final m in [_s.mover, _s.filer.mover]) {
          dropQueued(m, copies: kind == 'copy');
        }
      case 'upload':
        _s.uploader.cancelWaiting();
      case 'delete':
        _s.cancelDeletes();
      case 'info':
        _s.enricher.stop();
      case 'covers':
        _s.enricher.resetCovers();
      case final k when k.startsWith('from:'):
        ChatReads.instance.reads[int.tryParse(k.substring(5))]?.stop = true;
    }
    _schedule();
  }

  void stopRemote(String peerId, String kind) => _s.link.stopRemoteTask(peerId, kind);

  void onRemote(String peerId, String name, List<Map<String, dynamic>> runs) {
    final next = {...remote.value};
    if (runs.isEmpty) {
      next.remove(peerId);
    } else {
      next[peerId] = [for (final r in runs) TaskRun.fromJson(r)];
    }
    remote.value = next;
  }

  Future<void> delete(TaskRun run) async {
    history.value = history.value.where((r) => r.id != run.id).toList();
    await _forget([run.id]);
  }

  Future<void> clearHistory() async {
    final ids = [for (final r in history.value) r.id];
    history.value = [];
    await _forget(ids);
  }

  Future<void> _forget(List<String> ids) async {
    final cleared = await loadClearedTasks(_s.db);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      cleared[id] = now;
    }
    await saveClearedTasks(_s.db, cleared);
    await saveTaskHistory(_s.db, history.value);
    _s.db.announceChange();
  }

  String _song(Song s) => s.artist.isEmpty ? s.title : '${s.title} · ${s.artist}';

  Map<String, _Built> _build() {
    ItemState move(MoveStatus s) => switch (s) {
          MoveStatus.queued => ItemState.waiting,
          MoveStatus.moving => ItemState.active,
          MoveStatus.done || MoveStatus.skipped => ItemState.done,
          MoveStatus.failed => ItemState.failed,
        };
    TaskItem moveItem(MoveJob j) => TaskItem(
          '${j.song.uniqueId}|${j.toChat}|${j.topicId}',
          _song(j.song),
          j.note ?? (j.toChat != null ? 'Copy to another chat' : 'To ${j.topicName}'),
          move(j.status),
        );
    bool open(Iterable<TaskItem> items) => items.any((i) => i.state == ItemState.waiting || i.state == ItemState.active);

    final paused = _s.mover.paused.value || _s.filer.mover.paused.value;
    final moves = [..._s.mover.jobs.value, ..._s.filer.mover.jobs.value];
    final copies = [for (final j in moves) if (j.toChat != null) moveItem(j)];
    final filing = [for (final j in moves) if (j.toChat == null) moveItem(j)];

    final uploads = [
      for (final j in _s.uploader.jobs.value)
        TaskItem(
          j.path,
          p.basename(j.path),
          j.error ?? 'To ${j.chatTitle}${j.topicName == null ? '' : ' · ${j.topicName}'}',
          switch (j.status) {
            UploadStatus.queued => ItemState.waiting,
            UploadStatus.uploading => ItemState.active,
            UploadStatus.done || UploadStatus.skipped => ItemState.done,
            UploadStatus.failed => ItemState.failed,
          },
        ),
    ];

    final deletes = [
      for (final j in _s.deletions.value)
        TaskItem(
          j.key,
          _song(j.song),
          j.error ?? (j.isDuplicate ? 'Repeated post' : ''),
          switch (j.status) {
            DeleteStatus.queued => ItemState.waiting,
            DeleteStatus.deleting => ItemState.active,
            DeleteStatus.done => ItemState.done,
            DeleteStatus.failed => ItemState.failed,
          },
        ),
    ];

    final stats = _s.stats.value;
    final infoOn = _s.enricher.run.value != EnrichRun.idle && (stats?.waiting ?? 0) > 0;
    final info = <TaskItem>[];
    if (infoOn) {
      for (final s in _s.liveSongs.value.values) {
        if (s.enrichState == EnrichState.pending && !s.userEdited) {
          info.add(TaskItem(s.uniqueId, _song(s), 'Waiting for song info', ItemState.waiting));
          if (info.length >= _maxLocalItems) break;
        }
      }
    }

    final batch = _s.enricher.coversBatch.value;
    final covers = [
      for (final s in _s.enricher.queuedCovers) TaskItem(s.uniqueId, _song(s), 'Waiting for cover', ItemState.waiting),
    ];

    // Copying a channel's songs into the main chat, with your account.
    final fromChats = <String, _Built>{
      for (final e in ChatReads.instance.reads.entries)
        if (e.value.copyItems.isNotEmpty)
          'from:${e.key}': () {
            final r = e.value;
            final items = [
              for (final (i, it) in r.copyItems.indexed)
                TaskItem(it.post.uniqueId, '${it.post.title} · ${it.post.artist}', r.copyNotes[i] ?? 'To the main chat', r.copyStates[i]),
            ];
            return _Built(
              'Copying from ${r.title}',
              items,
              running: r.copying,
              note: r.copyText,
            );
          }(),
    };

    // Lyrics and genre lookups for mood mixes.
    final libraryTotal = stats?.total ?? 0;
    final lyricsLeft = _s.taste.value.lookups ? libraryTotal - _s.moodScanned.value : 0;
    final lyrics = <TaskItem>[];
    if (lyricsLeft > 0) {
      for (final s in _s.liveSongs.value.values) {
        if (s.moodScannedAt == 0) {
          lyrics.add(TaskItem(s.uniqueId, _song(s), 'Waiting for lyrics and genre', ItemState.waiting));
          if (lyrics.length >= _maxLocalItems) break;
        }
      }
    }

    // Reading a channel with your account, before it can be reviewed.
    final reads = <String, _Built>{
      for (final e in ChatReads.instance.reads.entries)
        'read:${e.key}': _Built(
          'Reading ${e.value.title}',
          const [],
          running: e.value.reading,
          total: e.value.reading ? 0 : e.value.found,
          done: e.value.reading ? 0 : e.value.found,
          note: e.value.error ?? '${thousands(e.value.found)} songs found',
        ),
    };

    final scan = _s.scanner.progress.value;
    return {
      ...fromChats,
      ...reads,
      if (lyricsLeft > 0)
        'lyrics': _Built('Lyrics and genre', lyrics, total: libraryTotal, done: libraryTotal - lyricsLeft),
      if (scan != null) 'scan': _Built('Checking channels', const [], note: scan),
      if (_s.lengthWork.value case final w?)
        'lengths': _Built(
          'Reading song lengths',
          [
            TaskItem(
              'length',
              w.title,
              w.fraction == null ? w.stage : '${w.stage} ${(w.fraction! * 100).round()}%',
              ItemState.active,
            ),
          ],
          total: w.total,
          done: w.done,
        ),
      if (copies.isNotEmpty)
        'copy': _Built('Copying songs', copies, running: open(copies), note: paused ? 'Paused' : null),
      if (filing.isNotEmpty)
        'filing': _Built('Filing songs', filing, running: open(filing), note: paused ? 'Paused' : null),
      if (uploads.isNotEmpty)
        'upload': _Built('Uploading', uploads, running: open(uploads), note: _s.uploader.paused.value ? 'Paused' : null),
      if (deletes.isNotEmpty) 'delete': _Built('Deleting songs', deletes, running: open(deletes)),
      if (infoOn)
        'info': _Built(
          'Finding song info',
          info,
          total: stats?.total,
          done: (stats?.total ?? 0) - (stats?.waiting ?? 0),
          note: _s.enricher.run.value == EnrichRun.paused ? 'Paused, a source is busy. Trying again soon' : null,
        ),
      if (batch > 0)
        'covers': _Built('Loading covers', covers, total: batch, done: batch - _s.enricher.coversQueued.value),
    };
  }
}
