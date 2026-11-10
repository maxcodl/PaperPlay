import 'package:flutter/foundation.dart';

import 'library/db.dart';

/// Background work whose speed can be set, each as how many per minute (1-500).
/// Faster finishes sooner but makes Telegram more likely to slow the bot down for a
/// while. Per device.
enum Work {
  filing('Copying, moving and deleting songs', 12),
  uploads('Uploads', 6),
  reading('Reading channels (pages of 50-100 posts)', 20),
  lookups('Song info, lyrics and genre', 50),
  covers('Covers', 40),
  accountCopy('Copying from your chats (your account)', 20);

  const Work(this.label, this.defaultRate);
  final String label;
  final int defaultRate;

  String get _key => 'rate_$name';
}

const minRate = 1, maxRate = 500;

final rates = {for (final w in Work.values) w: ValueNotifier(w.defaultRate)};

/// The pause between two of [w] at the chosen rate.
Duration gap(Work w) => Duration(milliseconds: 60000 ~/ rates[w]!.value);

Future<void> loadRates(AppDb db) async {
  for (final w in Work.values) {
    final v = int.tryParse(await db.pref(w._key) ?? '');
    if (v != null) rates[w]!.value = v.clamp(minRate, maxRate);
  }
}

Future<void> setRate(AppDb db, Work w, int perMinute) async {
  rates[w]!.value = perMinute.clamp(minRate, maxRate);
  await db.setPref(w._key, '${rates[w]!.value}');
}
