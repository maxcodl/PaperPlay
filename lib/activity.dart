/// Everything the app is busy with, as plain numbers, so the notification, the tray and
/// the banner in the app all say the same thing.
class ActivityInputs {
  const ActivityInputs({
    this.sync,
    this.syncFraction,
    this.movesDone = 0,
    this.movesTotal = 0,
    this.movesPaused = false,
    this.uploadsDone = 0,
    this.uploadsTotal = 0,
    this.uploadsPaused = false,
    this.infoLeft = 0,
    this.infoTotal = 0,
    this.infoRunning = false,
    this.infoPaused = false,
    this.coversLeft = 0,
    this.coversBatch = 0,
    this.scanLeft = 0,
    this.scanTotal = 0,
  });

  /// What the library scan or a sync from another device says it's doing, if anything.
  final String? sync;
  final double? syncFraction;

  /// Songs being filed or sorted into topics.
  final int movesDone, movesTotal;
  final bool movesPaused;
  final int uploadsDone, uploadsTotal;
  final bool uploadsPaused;

  /// Songs still waiting for song info, out of all songs.
  final int infoLeft, infoTotal;
  final bool infoRunning, infoPaused;

  /// Covers still to load in this batch, out of all asked for since the queue was empty.
  final int coversLeft, coversBatch;

  /// Songs whose lyrics and genre haven't been looked up, out of all songs.
  final int scanLeft, scanTotal;
}

/// The most important thing first, and the rest below it. [done] and [total] are for a
/// progress bar, and are null when there's nothing to measure.
class ActivitySummary {
  const ActivitySummary(this.title, this.detail, {this.done, this.total, this.busy = true});
  final String title, detail;
  final int? done, total;
  final bool busy;

  /// Changes whenever what's shown does, so a notification is only redrawn when it must.
  String get key => '$title|$detail|$done|$total';
}

/// 1234 as `1,234`.
String thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _minutes(int songs) {
  final minutes = (songs * 2.5 / 60).ceil();
  return minutes <= 1 ? 'about a minute' : 'about $minutes minutes';
}

ActivitySummary summarizeActivity(ActivityInputs i) {
  final tasks = <({String text, int? done, int? total})>[
    if (i.sync != null)
      (
        text: i.sync!,
        done: i.syncFraction == null ? null : (i.syncFraction! * 1000).round(),
        total: i.syncFraction == null ? null : 1000,
      ),
    if (i.movesTotal > i.movesDone)
      (
        text: 'Filing songs: ${thousands(i.movesDone)} of ${thousands(i.movesTotal)}${i.movesPaused ? ' (paused)' : ''}',
        done: i.movesDone,
        total: i.movesTotal,
      ),
    if (i.uploadsTotal > i.uploadsDone)
      (
        text: 'Uploading: ${thousands(i.uploadsDone)} of ${thousands(i.uploadsTotal)}${i.uploadsPaused ? ' (paused)' : ''}',
        done: i.uploadsDone,
        total: i.uploadsTotal,
      ),
    if (i.infoLeft > 0 && i.infoPaused)
      (text: 'Song info paused, a source is busy or unreachable. Trying again soon', done: null, total: null)
    else if (i.infoLeft > 0 && i.infoRunning)
      (
        text: 'Finding song info: ${thousands(i.infoTotal - i.infoLeft)} of ${thousands(i.infoTotal)}, '
            '${_minutes(i.infoLeft)} left',
        done: i.infoTotal - i.infoLeft,
        total: i.infoTotal,
      ),
    if (i.coversBatch > 0)
      (
        text: 'Loading covers: ${thousands(i.coversLeft)} left of ${thousands(i.coversBatch)}',
        done: i.coversBatch - i.coversLeft,
        total: i.coversBatch,
      ),
    if (i.scanLeft > 0)
      (
        text: 'Lyrics and genre: ${thousands(i.scanTotal - i.scanLeft)} of ${thousands(i.scanTotal)}',
        done: i.scanTotal - i.scanLeft,
        total: i.scanTotal,
      ),
  ];
  if (tasks.isEmpty) return const ActivitySummary('Paper Play is running', 'Everything is up to date', busy: false);
  final first = tasks.first;
  return ActivitySummary(
    first.text,
    tasks.skip(1).map((t) => t.text).join('\n'),
    done: first.done,
    total: first.total,
  );
}
