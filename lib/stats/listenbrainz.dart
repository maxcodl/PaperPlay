import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../library/db.dart';

const _storage = FlutterSecureStorage();
const _tokenKey = 'listenbrainz_token';
const _onKey = 'listenbrainz_on';
const _queueKey = 'listenbrainz_queue';
const _maxQueue = 500;

Map<String, dynamic> trackMeta(Song s) => {
      'artist_name': s.artist,
      'track_name': s.title,
      if (s.album.isNotEmpty) 'release_name': s.album,
    };

/// Sends listens to ListenBrainz. Offline listens wait in [_queueKey] (per device)
/// and go on the next try.
class ListenBrainz {
  ListenBrainz(this._db, {http.Client? client, this.base = 'https://api.listenbrainz.org'})
      : _client = client ?? http.Client();

  final AppDb _db;
  final http.Client _client;
  final String base;

  final enabled = ValueNotifier<bool>(false);
  final hasToken = ValueNotifier<bool>(false);
  Timer? _retry;

  Future<void> load() async {
    enabled.value = await _db.pref(_onKey) == 'true';
    hasToken.value = await _storage.read(key: _tokenKey) != null;
  }

  Future<void> setEnabled(bool on) async {
    enabled.value = on;
    await _db.setPref(_onKey, '$on');
    if (on) unawaited(flush());
  }

  /// The token, for a backup. Null if none is saved.
  Future<String?> token() => _storage.read(key: _tokenKey);

  Future<void> setToken(String? token) async {
    final t = token?.trim() ?? '';
    if (t.isEmpty) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: t);
    }
    hasToken.value = t.isNotEmpty;
    if (t.isNotEmpty) unawaited(flush());
  }

  bool get _active => enabled.value && hasToken.value;

  Future<void> nowPlaying(Song s) async {
    final token = _active ? await _storage.read(key: _tokenKey) : null;
    if (token == null) return;
    try {
      await _post(token, 'playing_now', [
        {'track_metadata': trackMeta(s)},
      ]);
    } catch (_) {}
  }

  Future<void> scrobble(Song s, DateTime startedAt) async {
    if (!_active) return;
    final q = await _queue();
    q.add({'listened_at': startedAt.millisecondsSinceEpoch ~/ 1000, 'track_metadata': trackMeta(s)});
    await _saveQueue(q.length > _maxQueue ? q.sublist(q.length - _maxQueue) : q);
    await flush();
  }

  var _sending = false;

  /// Sends what's queued. Network errors and server trouble keep it for later;
  /// a refusal of the listens themselves drops them, since retrying can't help.
  Future<void> flush() async {
    final token = _active ? await _storage.read(key: _tokenKey) : null;
    if (token == null || _sending) return;
    _sending = true;
    try {
      while (true) {
        final q = await _queue();
        if (q.isEmpty) return;
        final batch = q.take(100).toList();
        final code = await _post(token, batch.length == 1 ? 'single' : 'import', batch);
        if (code == 401) return;
        if (code == 429 || code >= 500) throw Exception('retry');
        await _saveQueue((await _queue()).sublist(batch.length));
      }
    } catch (_) {
      _retry?.cancel();
      _retry = Timer(const Duration(minutes: 5), flush);
    } finally {
      _sending = false;
    }
  }

  Future<int> _post(String token, String type, List<Map<String, dynamic>> payload) async {
    final r = await _client
        .post(
          Uri.parse('$base/1/submit-listens'),
          headers: {'Authorization': 'Token $token', 'Content-Type': 'application/json'},
          body: jsonEncode({'listen_type': type, 'payload': payload}),
        )
        .timeout(const Duration(seconds: 20));
    return r.statusCode;
  }

  Future<List<Map<String, dynamic>>> _queue() async {
    final raw = await _db.pref(_queueKey);
    return raw == null ? [] : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> q) => _db.setPref(_queueKey, jsonEncode(q));
}
