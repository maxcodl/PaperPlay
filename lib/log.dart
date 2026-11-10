import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:path/path.dart' as p;

enum LogLevel { info, warning, error }

class LogEntry {
  const LogEntry(this.time, this.level, this.source, this.message);
  final DateTime time;
  final LogLevel level;
  final String source, message;

  String get line => '${time.toIso8601String()}\t${level.name}\t$source\t${message.replaceAll('\n', ' ')}';

  /// Null if [line] isn't one this app wrote.
  static LogEntry? parse(String line) {
    final parts = line.split('\t');
    if (parts.length < 4) return null;
    final time = DateTime.tryParse(parts[0]);
    final level = LogLevel.values.where((l) => l.name == parts[1]).firstOrNull;
    if (time == null || level == null) return null;
    return LogEntry(time, level, parts[2], parts.sublist(3).join('\t'));
  }
}

final _botToken = RegExp(r'\b\d{5,}:[A-Za-z0-9_-]{20,}\b');

/// Removes anything shaped like a bot token, whatever an error message quotes.
String redactSecrets(String text) => text.replaceAll(_botToken, '<bot token>');

/// What the app has been doing, in memory and in a small file that survives restarts.
class AppLog {
  AppLog({this.capacity = 5000, this.maxFileBytes = 2 * 1024 * 1024});

  final int capacity, maxFileBytes;
  final _entries = ListQueue<LogEntry>();
  final _unwritten = <String>[];
  File? _file;
  Timer? _flushTimer;

  /// Changes with every entry, so a screen can tell when to redraw.
  var version = 0;

  List<LogEntry> get entries => _entries.toList();

  void add(String source, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(DateTime.now(), level, source, redactSecrets(message));
    _keep(entry);
    version++;
    if (_file == null) return;
    _unwritten.add(entry.line);
    _flushTimer ??= Timer(const Duration(seconds: 2), flush);
  }

  void _keep(LogEntry e) {
    _entries.addLast(e);
    if (_entries.length > capacity) _entries.removeFirst();
  }

  /// Loads what the last run wrote, then keeps writing to [dir].
  Future<void> attach(Directory dir) async {
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'teleplayer.log'));
    _crashFile = File(p.join(dir.path, 'crashes.log'));
    final unsaved = _entries.toList();
    if (await file.exists()) {
      _entries.clear();
      for (final l in await file.readAsLines()) {
        final e = LogEntry.parse(l);
        if (e != null) _keep(e);
      }
      unsaved.forEach(_keep);
    }
    _unwritten.addAll(unsaved.map((e) => e.line));
    _file = file;
    version++;
  }

  File? _crashFile;
  static const _crashFileMax = 512 * 1024;

  /// Writes a crash, with the lines just before it, to a file that "Clear the log" leaves
  /// alone. Done synchronously so it lands even if the app dies right after.
  void recordCrash(String summary) {
    final file = _crashFile;
    if (file == null) return;
    final recent = _entries.toList();
    final before = recent.sublist(recent.length > 60 ? recent.length - 60 : 0).map((e) => e.line).join('\n');
    try {
      if (file.existsSync() && file.lengthSync() > _crashFileMax) file.writeAsStringSync('');
      file.writeAsStringSync(
        '=== ${DateTime.now().toIso8601String()}\n${redactSecrets(summary)}\n--- the lines before it\n$before\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException {
      // Logging must never take the app down.
    }
  }

  Future<String> crashText() async {
    final file = _crashFile;
    return file != null && await file.exists() ? file.readAsString() : '';
  }

  Future<void> clearCrashes() async {
    final file = _crashFile;
    if (file != null && await file.exists()) await file.delete();
  }

  /// Everything kept, oldest first, as plain text.
  String get allText => _entries.map((e) => e.line).join('\n');

  Future<void> flush() async {
    _flushTimer = null;
    final file = _file;
    if (file == null || _unwritten.isEmpty) return;
    final batch = _unwritten.join('\n');
    _unwritten.clear();
    try {
      if (await file.exists() && await file.length() > maxFileBytes) {
        await file.rename('${file.path}.1');
      }
      await file.writeAsString('$batch\n', mode: FileMode.append, flush: true);
    } on FileSystemException {
      // Logging must never take the app down. The entries are still on screen.
    }
  }

  Future<void> clear() async {
    _entries.clear();
    _unwritten.clear();
    version++;
    try {
      final file = _file;
      if (file != null && await file.exists()) await file.delete();
    } on FileSystemException {
      // Nothing to clear.
    }
  }
}

final appLog = AppLog();

void logEvent(String source, String message, {LogLevel level = LogLevel.info}) {
  appLog.add(source, message, level: level);
  final plain = plainFailure(source, message, level);
  if (plain == null) return;
  // The same failure repeats in bursts; once a minute is enough to notice it.
  final now = DateTime.now();
  final last = _shownAt[plain];
  if (last != null && now.difference(last) < const Duration(minutes: 1)) return;
  _shownAt[plain] = now;
  failureToast.add(plain);
}

/// Short, plain messages for failures the person should know about, shown as a toast.
final failureToast = StreamController<String>.broadcast();
final _shownAt = <String, DateTime>{};

/// Set by the app: whether the person's own account is logged in.
bool Function() accountLoggedIn = () => false;

/// What a failure means in everyday words, or null when it isn't worth a toast.
/// Raw Telegram replies aren't shown: the step that made them reports instead.
String? plainFailure(String source, String message, LogLevel level) {
  if (message.isEmpty) return null;
  if (source == 'filing' && message.startsWith("Your account couldn't delete")) {
    return "Couldn't delete an old post, even with your account.";
  }
  if (level != LogLevel.error) return null;
  // A layout slip when Android reopens the app; logged, and the page is rebuilt.
  if (message.contains('RenderBox was not laid out')) return null;
  return switch (source) {
    'filing' || 'sorting' when message.contains('deleted') && accountLoggedIn() =>
      "Couldn't delete the old post in General, even with your account logged in. "
          'The reason is in Settings, Log, on the line "Your account couldn\'t delete it either".',
    'filing' || 'sorting' when message.contains('deleted') =>
      "Couldn't delete the old post in General. Telegram stops bots deleting posts older than 48 hours. "
          'Log in your account in Settings to allow it.',
    'filing' || 'sorting' => "Couldn't move a song into its topic.",
    'playback' => "Couldn't play this song.",
    'login' => "Couldn't log in to Telegram. Check the connection and the bot token.",
    'sync' => "Couldn't sync with your other device.",
    'app' => 'Something went wrong. Details are in Settings, Log.',
    _ => null,
  };
}
