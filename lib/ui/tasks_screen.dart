import 'package:flutter/material.dart';

import '../app.dart';
import '../library/task_history.dart';
import '../tasks.dart';
import 'widgets.dart' show showSongInfo;

IconData _icon(String kind) => switch (kind.split(':').first) {
      'copy' || 'from' => Icons.copy_rounded,
      'read' => Icons.travel_explore_rounded,
      'lyrics' => Icons.lyrics_rounded,
      'filing' => Icons.drive_file_move_rounded,
      'upload' => Icons.upload_rounded,
      'delete' => Icons.delete_rounded,
      'info' => Icons.manage_search_rounded,
      'covers' => Icons.image_rounded,
      _ => Icons.sync_rounded,
    };

String _when(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final ago = DateTime.now().difference(t);
  if (ago.inMinutes < 1) return 'just now';
  if (ago.inHours < 1) return '${ago.inMinutes} min ago';
  if (ago.inDays < 1) return '${ago.inHours} h ago';
  return '${t.day}/${t.month}/${t.year}';
}

String _summary(TaskRun r) {
  final parts = [
    if (r.running) '${r.done} of ${r.total}' else '${r.done} done',
    if (r.failed > 0) '${r.failed} failed',
    if (r.stopped) 'stopped',
  ];
  return parts.join(' · ');
}

/// Live tasks here and on other devices, and what was done before.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = app.tasks;
    return ListenableBuilder(
      listenable: Listenable.merge([tasks.live, tasks.remote, tasks.history]),
      builder: (context, _) {
        final remote = tasks.remote.value;
        final history = tasks.history.value;
        final idle = tasks.live.value.isEmpty && remote.isEmpty;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasks'),
            actions: [
              if (history.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  icon: const Icon(Icons.delete_sweep_rounded),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: const Text('Clear task history?'),
                        content: const Text('It is cleared on your other devices too. Running tasks are not affected.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Clear')),
                        ],
                      ),
                    );
                    if (ok ?? false) await tasks.clearHistory();
                  },
                ),
            ],
          ),
          body: ListView(
            children: [
              if (idle) const ListTile(leading: Icon(Icons.check_circle_outline_rounded), title: Text('Nothing running')),
              for (final r in tasks.live.value)
                _RunTile(
                  r,
                  where: null,
                  onStop: canStop(r.kind) && !r.stopped ? () => tasks.stop(r.kind) : null,
                  find: () => tasks.live.value.where((x) => x.id == r.id).firstOrNull,
                ),
              for (final e in remote.entries) ...[
                for (final r in e.value)
                  _RunTile(
                    r,
                    where: r.device,
                    onStop: canStop(r.kind) && !r.stopped ? () => tasks.stopRemote(e.key, r.kind) : null,
                    find: () => tasks.remote.value[e.key]?.where((x) => x.id == r.id).firstOrNull,
                  ),
              ],
              if (history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text('History', style: Theme.of(context).textTheme.titleSmall),
                ),
              for (final r in history)
                _RunTile(
                  r,
                  where: r.device,
                  onDelete: () => tasks.delete(r),
                  find: () => tasks.history.value.where((x) => x.id == r.id).firstOrNull,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile(this.run, {required this.where, required this.find, this.onStop, this.onDelete});
  final TaskRun run;

  /// The device it ran on, shown when it isn't this one.
  final String? where;
  final TaskRun? Function() find;
  final VoidCallback? onStop, onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(_icon(run.kind)),
      title: Text(run.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([
            ?where,
            if (run.note != null && run.running) run.note!,
            if (run.total > 0 || !run.running) _summary(run),
            if (!run.running) _when(run.endedAt),
          ].join(' · ')),
          if (run.running && run.total > 0) LinearProgressIndicator(value: run.done / run.total),
        ],
      ),
      trailing: onStop != null
          ? IconButton(tooltip: 'Stop', icon: Icon(Icons.stop_circle_outlined, color: theme.colorScheme.error), onPressed: onStop)
          : onDelete != null
              ? IconButton(tooltip: 'Delete', icon: const Icon(Icons.close_rounded), onPressed: onDelete)
              : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => _RunFiles(first: run, find: find)),
      ),
    );
  }
}

/// The files of one run, live while it runs.
class _RunFiles extends StatelessWidget {
  const _RunFiles({required this.first, required this.find});
  final TaskRun first;
  final TaskRun? Function() find;

  @override
  Widget build(BuildContext context) {
    final tasks = app.tasks;
    return ListenableBuilder(
      listenable: Listenable.merge([tasks.live, tasks.remote, tasks.history]),
      builder: (context, _) {
        final run = find() ?? first;
        final items = run.itemsByImportance();
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: Text(run.title), bottom: PreferredSize(
            preferredSize: const Size.fromHeight(28),
            child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_summary(run))),
          )),
          body: items.isEmpty
              ? Center(child: Text(run.note ?? 'No files to show.'))
              : ListView.builder(
                  itemCount: items.length + (run.total > items.length ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return ListTile(dense: true, title: Text('And ${run.total - items.length} more'));
                    }
                    final item = items[i];
                    // Items keyed by a song's id open that song, when it's in this library.
                    final song = app.liveSongs.value[item.key];
                    return ListTile(
                      dense: true,
                      onTap: song == null ? null : () => showSongInfo(context, song),
                      leading: switch (item.state) {
                        ItemState.active => const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ItemState.waiting => const Icon(Icons.schedule_rounded),
                        ItemState.done => Icon(Icons.check_circle_rounded, color: scheme.primary),
                        ItemState.failed => Icon(Icons.error_rounded, color: scheme.error),
                        ItemState.cancelled => const Icon(Icons.block_rounded),
                      },
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: item.sub.isEmpty ? null : Text(item.sub, maxLines: 2, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
        );
      },
    );
  }
}
