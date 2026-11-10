import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'db.dart';
import 'mood.dart';

/// A place to get the weather for.
class WeatherPlace {
  const WeatherPlace(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude, longitude;
}

/// What a WMO weather code means for a mix.
WeatherKind? weatherKindOf(int code) => switch (code) {
      0 || 1 => WeatherKind.clear,
      2 || 3 || 45 || 48 => WeatherKind.cloudy,
      >= 51 && <= 67 || >= 80 && <= 82 => WeatherKind.rain,
      >= 71 && <= 77 || 85 || 86 => WeatherKind.snow,
      >= 95 && <= 99 => WeatherKind.storm,
      _ => null,
    };

/// Weather from Open-Meteo, which needs no key. Off until a city is chosen, and
/// only then is anything sent: that city's coordinates, at most once an hour.
class WeatherService {
  WeatherService(this._db, [http.Client? client]) : _http = client ?? http.Client();

  final AppDb _db;
  final http.Client _http;
  static const _nameKey = 'weather_city', _latKey = 'weather_lat', _lonKey = 'weather_lon';
  static const _refreshEvery = Duration(hours: 1);

  final place = ValueNotifier<WeatherPlace?>(null);
  final kind = ValueNotifier<WeatherKind?>(null);
  DateTime? _fetched;

  Future<void> load() async {
    final name = await _db.pref(_nameKey);
    final lat = double.tryParse(await _db.pref(_latKey) ?? '');
    final lon = double.tryParse(await _db.pref(_lonKey) ?? '');
    if (name != null && lat != null && lon != null) {
      place.value = WeatherPlace(name, lat, lon);
      await refresh();
    }
  }

  /// Open-Meteo only matches a bare place name, so "Cochin Kerala" or "Kochi, India"
  /// finds nothing as typed. Each word is tried on its own, and places whose state or
  /// country matches the other words come first.
  Future<List<WeatherPlace>> searchPlaces(String query) async {
    final whole = await _search(query);
    if (whole.isNotEmpty) return whole;
    final words = query.split(RegExp(r'[,\s]+')).where((w) => w.length > 1).toList();
    for (final w in words) {
      final found = await _search(w);
      if (found.isEmpty) continue;
      final rest = [for (final o in words) if (o != w) o.toLowerCase()];
      int score(WeatherPlace p) => rest.where((o) => p.name.toLowerCase().contains(o)).length;
      return found..sort((a, b) => score(b).compareTo(score(a)));
    }
    return const [];
  }

  Future<List<WeatherPlace>> _search(String name) async {
    final res = await _http.get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': name, 'count': '6', 'format': 'json'}),
    );
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final r in (body['results'] as List? ?? const []).cast<Map<String, dynamic>>())
        WeatherPlace(
          [r['name'], r['admin1'], r['country']].whereType<String>().join(', '),
          (r['latitude'] as num).toDouble(),
          (r['longitude'] as num).toDouble(),
        ),
    ];
  }

  /// Chooses where to get the weather for, or turns it off with null.
  Future<void> setPlace(WeatherPlace? p) async {
    place.value = p;
    kind.value = null;
    _fetched = null;
    await _db.setPref(_nameKey, p?.name ?? '');
    await _db.setPref(_latKey, '${p?.latitude ?? ''}');
    await _db.setPref(_lonKey, '${p?.longitude ?? ''}');
    if (p != null) await refresh();
  }

  /// Updates the weather if it's stale. Failing just means no weather for now.
  Future<void> refresh() async {
    final p = place.value;
    final last = _fetched;
    if (p == null || (last != null && DateTime.now().difference(last) < _refreshEvery)) return;
    try {
      final res = await _http.get(
        Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '${p.latitude}',
          'longitude': '${p.longitude}',
          'current': 'weather_code',
        }),
      );
      if (res.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final code = (body['current'] as Map<String, dynamic>?)?['weather_code'] as int?;
      if (code != null) {
        kind.value = weatherKindOf(code);
        _fetched = DateTime.now();
      }
    } on http.ClientException {
      // Offline.
    } on FormatException {
      // Not worth failing over.
    } on Exception {
      // Offline, in a form specific to the platform.
    }
  }
}
