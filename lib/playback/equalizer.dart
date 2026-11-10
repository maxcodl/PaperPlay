import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart';

import '../library/db.dart';

/// Centre frequencies of the five bands every device offers here.
const eqFreqs = [60.0, 230.0, 910.0, 3600.0, 14000.0];
const eqRange = 12.0;

const eqPresets = <String, List<double>>{
  'Flat': [0, 0, 0, 0, 0],
  'Bass boost': [6, 4, 0, 0, 0],
  'Treble boost': [0, 0, 0, 3, 6],
  'Vocal': [-2, 0, 3, 3, 0],
  'Rock': [4, 2, -1, 2, 4],
  'Loudness': [5, 2, 0, 2, 5],
};

bool isFlat(List<double> g) => g.every((v) => v.abs() < 0.05);

/// mpv's `af` value: input gain to leave room for the boost, a peaking filter per band,
/// and a limiter at -0.5 dBFS. Empty when flat, so a flat setting adds no processing.
String mpvFilter(List<double> gains) {
  if (isFlat(gains)) return '';
  final boost = gains.fold<double>(0, max);
  return 'lavfi=[volume=${(-boost).toStringAsFixed(1)}dB,'
      '${[for (var i = 0; i < gains.length; i++) 'equalizer=f=${eqFreqs[i].round()}:t=q:w=1:g=${gains[i].toStringAsFixed(1)}'].join(',')}'
      ',alimiter=limit=0.944]';
}

/// Gain for a device band centred on [freq]: that of the nearest of our bands, by pitch.
double gainAtFreq(List<double> gains, double freq) {
  var best = 0;
  for (var i = 1; i < eqFreqs.length; i++) {
    if ((log(freq / eqFreqs[i])).abs() < (log(freq / eqFreqs[best])).abs()) best = i;
  }
  return gains[best];
}

/// Per-device equalizer (never synced). Windows sets mpv's filter chain, Android uses
/// the system equalizer.
class Equalizer {
  Equalizer(this._db, this.android);

  final AppDb _db;
  final AndroidEqualizer? android;
  static const _onKey = 'eq_on', _gainsKey = 'eq_gains';

  final enabled = ValueNotifier<bool>(false);
  final gains = ValueNotifier<List<double>>(List.filled(5, 0));
  Player? _mpv;

  Future<void> load() async {
    enabled.value = await _db.pref(_onKey) == 'true';
    final raw = await _db.pref(_gainsKey);
    if (raw != null) {
      final v = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
      if (v.length == 5) gains.value = v;
    }
    // Not awaited: on Android the system equalizer only answers once a song is loaded, so
    // waiting here would stop the app starting at all (a black screen).
    unawaited(apply());
  }

  void attachMpv(Player p) {
    _mpv = p;
    unawaited(apply());
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    await _db.setPref(_onKey, '$on');
    await apply();
  }

  Future<void> setGains(List<double> g) async {
    gains.value = [for (final v in g) v.clamp(-eqRange, eqRange)];
    await _db.setPref(_gainsKey, jsonEncode(gains.value));
    await apply();
  }

  /// Pushes the setting to the engine. Safe to call again, e.g. once a song is loaded.
  Future<void> apply() async {
    final g = enabled.value ? gains.value : List.filled(5, 0.0);
    try {
      final mpv = _mpv;
      if (mpv != null && mpv.platform is NativePlayer) {
        await (mpv.platform as NativePlayer).setProperty('af', mpvFilter(g));
      }
      final a = android;
      if (a != null) {
        await a.setEnabled(enabled.value && !isFlat(g));
        final params = await a.parameters;
        for (final b in params.bands) {
          await b.setGain(gainAtFreq(g, b.centerFrequency).clamp(params.minDecibels, params.maxDecibels));
        }
      }
    } catch (_) {
      // The engine may not exist before the first song; apply runs again then.
    }
  }
}
