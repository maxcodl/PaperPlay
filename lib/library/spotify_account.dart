import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'db.dart';
import 'playlist_import.dart';

/// Must be added to the app in Spotify's developer dashboard, exactly like this.
const spotifyRedirectUri = 'http://127.0.0.1:8888/callback';

const _storage = FlutterSecureStorage();
const _refreshKey = 'spotify_refresh_token';
const _clientKey = 'spotify_client_id';
const _scopes = 'playlist-read-private playlist-read-collaborative';
const _pageSize = 100;

class SpotifyLoginError implements Exception {
  const SpotifyLoginError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The S256 challenge for a PKCE [verifier].
Future<String> pkceChallenge(String verifier) async {
  final hash = await Sha256().hash(ascii.encode(verifier));
  return base64Url.encode(hash.bytes).replaceAll('=', '');
}

String _randomText(int length) {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final r = Random.secure();
  return List.generate(length, (_) => letters[r.nextInt(letters.length)]).join();
}

/// Tracks from one page of Spotify's playlist items. Local files and podcast
/// episodes aren't tracks to match, so they're left out.
List<ImportedTrack> parseSpotifyItems(List<dynamic> items) {
  final tracks = <ImportedTrack>[];
  for (final raw in items) {
    final entry = raw as Map<String, dynamic>;
    final t = (entry['item'] ?? entry['track']) as Map<String, dynamic>?;
    final uri = t?['uri'] as String?;
    if (t == null || uri == null || !uri.startsWith('spotify:track:')) continue;
    final artists = (t['artists'] as List? ?? const [])
        .map((a) => (a as Map<String, dynamic>)['name'] as String?)
        .whereType<String>()
        .join(', ');
    final ms = t['duration_ms'];
    final added = DateTime.tryParse(entry['added_at'] as String? ?? '')?.millisecondsSinceEpoch;
    tracks.add(ImportedTrack(uri, t['name'] as String? ?? '', artists, ms is int ? (ms / 1000).round() : 0, added));
  }
  return tracks;
}

/// The owner's own Spotify login, using a Client ID they made. The official route
/// to a whole playlist: the public page stops at about 100 tracks. Reads track
/// details only, and only for playlists they own or collaborate on.
class SpotifyAccount {
  SpotifyAccount(this._db, [http.Client? client]) : _http = client ?? http.Client();

  final AppDb _db;
  final http.Client _http;

  final clientId = ValueNotifier<String?>(null);
  final connected = ValueNotifier(false);
  String? _accessToken;
  DateTime? _expires;

  Future<void> load() async {
    clientId.value = await _db.pref(_clientKey);
    connected.value = await _storage.read(key: _refreshKey) != null;
  }

  Future<void> setClientId(String id) async {
    clientId.value = id.trim();
    await _db.setPref(_clientKey, id.trim());
  }

  /// The refresh token, for a backup. Null if not signed in.
  Future<String?> refreshToken() => _storage.read(key: _refreshKey);

  /// Takes a sign-in from a backup: the app's Client ID and its refresh token.
  Future<void> restore(String id, String refresh) async {
    await setClientId(id);
    await _storage.write(key: _refreshKey, value: refresh);
    _accessToken = null;
    connected.value = true;
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _refreshKey);
    _accessToken = null;
    connected.value = false;
  }

  /// Signs in through the browser. [open] shows the page; Spotify then returns to a
  /// short-lived local server. Throws [SpotifyLoginError] saying what went wrong.
  Future<void> connect(Future<bool> Function(Uri) open) async {
    final id = clientId.value;
    if (id == null || id.isEmpty) throw const SpotifyLoginError('Enter your Client ID first.');
    final verifier = _randomText(64);
    final state = _randomText(16);
    final redirect = Uri.parse(spotifyRedirectUri);
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, redirect.port);
    } on SocketException {
      throw const SpotifyLoginError('Port 8888 is in use by another program. Close it and try again.');
    }
    try {
      final authorize = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': id,
        'response_type': 'code',
        'redirect_uri': spotifyRedirectUri,
        'scope': _scopes,
        'state': state,
        'code_challenge_method': 'S256',
        'code_challenge': await pkceChallenge(verifier),
      });
      if (!await open(authorize)) throw const SpotifyLoginError('Couldn\'t open the browser.');
      final String code;
      try {
        code = await _awaitCode(server, redirect.path, state).timeout(const Duration(minutes: 5));
      } on TimeoutException {
        throw const SpotifyLoginError('Timed out waiting for Spotify. Try again.');
      }
      await _token({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': spotifyRedirectUri,
        'client_id': id,
        'code_verifier': verifier,
      });
      connected.value = true;
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> _awaitCode(HttpServer server, String path, String state) async {
    await for (final request in server) {
      if (request.uri.path != path) {
        request.response.statusCode = 404;
        await request.response.close();
        continue;
      }
      final q = request.uri.queryParameters;
      final ok = q['state'] == state && q['code'] != null;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><meta charset="utf-8"><title>Paper Play</title>'
        '<body style="font-family:sans-serif;padding:3em">'
        '<h2>${ok ? 'Connected to Paper Play' : 'Spotify didn\'t connect'}</h2>'
        '<p>You can close this tab and go back to the app.</p>',
      );
      await request.response.close();
      if (q['state'] != state) throw const SpotifyLoginError('Spotify\'s reply didn\'t match. Try again.');
      final code = q['code'];
      if (code != null) return code;
      throw SpotifyLoginError('Spotify refused: ${q['error'] ?? 'unknown reason'}.');
    }
    throw const SpotifyLoginError('The sign-in was interrupted.');
  }

  Future<void> _token(Map<String, String> body) async {
    final res = await _http.post(Uri.https('accounts.spotify.com', '/api/token'), body: body);
    if (res.statusCode != 200) {
      throw SpotifyLoginError('Spotify refused the sign-in (${res.statusCode}). Check your Client ID.');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = json['access_token'] as String;
    _expires = DateTime.now().add(Duration(seconds: (json['expires_in'] as int? ?? 3600) - 60));
    final refresh = json['refresh_token'] as String?;
    if (refresh != null) await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<String?> _validToken() async {
    final expires = _expires;
    if (_accessToken != null && expires != null && DateTime.now().isBefore(expires)) return _accessToken;
    final refresh = await _storage.read(key: _refreshKey);
    final id = clientId.value;
    if (refresh == null || id == null) return null;
    await _token({'grant_type': 'refresh_token', 'refresh_token': refresh, 'client_id': id});
    return _accessToken;
  }

  /// A whole playlist, or null if this login can't read it: not signed in, or not
  /// the owner's, which Spotify only lets its owner and collaborators list.
  Future<({String name, List<ImportedTrack> tracks})?> fetchPlaylist(String id) async {
    if (!connected.value) return null;
    Future<http.Response> get(Uri uri) async {
      while (true) {
        final token = await _validToken();
        if (token == null) throw const SpotifyLoginError('Sign in to Spotify again in Settings.');
        final res = await _http.get(uri, headers: {'Authorization': 'Bearer $token'});
        if (res.statusCode != 429) return res;
        // Told how long to wait, so this is the only pace needed.
        await Future<void>.delayed(Duration(seconds: int.tryParse(res.headers['retry-after'] ?? '') ?? 5));
      }
    }

    final about = await get(Uri.https('api.spotify.com', '/v1/playlists/$id', {'fields': 'name'}));
    if (about.statusCode != 200) return null;
    final name = (jsonDecode(about.body) as Map<String, dynamic>)['name'] as String? ?? 'Imported playlist';
    final tracks = <ImportedTrack>[];
    Uri? next = Uri.https('api.spotify.com', '/v1/playlists/$id/items', {'limit': '$_pageSize'});
    while (next != null) {
      final res = await get(next);
      if (res.statusCode == 403 || res.statusCode == 404) return null;
      if (res.statusCode != 200) throw ImportError('Spotify answered with error ${res.statusCode}.');
      final page = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      tracks.addAll(parseSpotifyItems(page['items'] as List? ?? const []));
      final link = page['next'] as String?;
      next = link == null ? null : Uri.parse(link);
    }
    return (name: name, tracks: tracks);
  }
}
