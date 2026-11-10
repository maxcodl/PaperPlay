import 'dart:convert';

import 'db.dart';

enum ItemState { waiting, active, done, failed, cancelled }

/// One file in a task.
class TaskItem {
  TaskItem(this.key, this.title, this.sub, this.state);

  factory TaskItem.fromJson(List<dynamic> j) =>
      TaskItem(j[0] as String, j[1] as String, j[2] as String, ItemState.values[(j[3] as int).clamp(0, ItemState.values.length - 1)]);

  final String key, title;
  String sub;
  ItemState state;

  List<dynamic> toJson() => [key, title, sub, state.index];
}

/// One run of a kind of work: copying, filing, deleting and so on. Running while
/// [endedAt] is 0, then kept as history.
class TaskRun {
  TaskRun({required this.id, required this.kind, required this.title, required this.device, required this.startedAt});

  factory TaskRun.fromJson(Map<String, dynamic> j) => TaskRun(
        id: j['id'] as String,
        kind: j['kind'] as String,
        title: j['title'] as String,
        device: j['device'] as String,
        startedAt: j['startedAt'] as int,
      )
        ..endedAt = j['endedAt'] as int? ?? 0
        ..stopped = j['stopped'] as bool? ?? false
        ..done = j['done'] as int? ?? 0
        ..total = j['total'] as int? ?? 0
        ..failed = j['failed'] as int? ?? 0
        ..note = j['note'] as String?
        ..items = [for (final i in j['items'] as List? ?? const []) TaskItem.fromJson(i as List)];

  final String id, kind, device;
  String title;
  final int startedAt;
  int endedAt = 0, done = 0, total = 0, failed = 0;
  bool stopped = false;
  String? note;
  List<TaskItem> items = [];

  bool get running => endedAt == 0;

  /// The files worth keeping first: active, failed, waiting, then the rest.
  List<TaskItem> itemsByImportance() {
    const order = [ItemState.active, ItemState.failed, ItemState.waiting, ItemState.cancelled, ItemState.done];
    return [...items]..sort((a, b) => order.indexOf(a.state).compareTo(order.indexOf(b.state)));
  }

  Map<String, dynamic> toJson({int maxItems = 150}) => {
        'id': id,
        'kind': kind,
        'title': title,
        'device': device,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'stopped': stopped,
        'done': done,
        'total': total,
        'failed': failed,
        'note': note,
        'items': [for (final i in itemsByImportance().take(maxItems)) i.toJson()],
      };
}

const _historyKey = 'task_history';
const _clearedKey = 'task_cleared';
const maxHistory = 60;
const _maxCleared = 500;

Future<List<TaskRun>> loadTaskHistory(AppDb db) async {
  final raw = await db.pref(_historyKey);
  if (raw == null) return [];
  try {
    return [for (final j in jsonDecode(raw) as List) TaskRun.fromJson(j as Map<String, dynamic>)];
  } on Object {
    return [];
  }
}

Future<void> saveTaskHistory(AppDb db, List<TaskRun> runs) =>
    db.setPref(_historyKey, jsonEncode([for (final r in runs.take(maxHistory)) r.toJson()]));

/// Runs that were deleted or cleared, by id, so another device doesn't bring them back.
Future<Map<String, int>> loadClearedTasks(AppDb db) async {
  final raw = await db.pref(_clearedKey);
  if (raw == null) return {};
  return (jsonDecode(raw) as Map).cast<String, int>();
}

Future<void> saveClearedTasks(AppDb db, Map<String, int> cleared) {
  var keep = cleared;
  if (cleared.length > _maxCleared) {
    final newest = cleared.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    keep = {for (final e in newest.take(_maxCleared)) e.key: e.value};
  }
  return db.setPref(_clearedKey, jsonEncode(keep));
}

Future<Map<String, dynamic>> taskSnapshot(AppDb db) async => {
      'history': (jsonDecode(await db.pref(_historyKey) ?? '[]') as List),
      'cleared': await loadClearedTasks(db),
    };

/// Merges another device's history in. Returns whether anything here changed.
Future<bool> mergeTasks(AppDb db, Map<String, dynamic>? snapshot) async {
  if (snapshot == null) return false;
  var changed = false;
  final cleared = await loadClearedTasks(db);
  for (final e in ((snapshot['cleared'] as Map?) ?? const {}).entries) {
    final at = e.value as int;
    if ((cleared[e.key] ?? 0) < at) {
      cleared[e.key as String] = at;
      changed = true;
    }
  }
  final mine = {for (final r in await loadTaskHistory(db)) r.id: r};
  final before = mine.length;
  mine.removeWhere((id, _) => cleared.containsKey(id));
  if (mine.length != before) changed = true;
  for (final j in (snapshot['history'] as List? ?? const [])) {
    final run = TaskRun.fromJson(j as Map<String, dynamic>);
    if (cleared.containsKey(run.id) || run.running) continue;
    if (mine.containsKey(run.id)) continue;
    mine[run.id] = run;
    changed = true;
  }
  if (!changed) return false;
  await saveClearedTasks(db, cleared);
  final all = mine.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  await saveTaskHistory(db, all);
  return true;
}
