import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import 'db.dart';

const _version = 1;
const _manifest = 'library.json';
const _coversFolder = 'covers';
const _profileFolder = 'profile';
const _credentialsEntry = 'credentials.enc';
const _userSessionEntry = 'usersession.enc';
const _kdfIterations = 200000;

/// Nothing legitimate comes close: covers are at most a few MB each.
const _maxCoverBytes = 20 * 1024 * 1024;

/// Keeps a restored file inside the covers folder, whatever the ZIP claims.
final _safeName = RegExp(r'^[\w.-]+$');

/// API keys and bot token. Whoever has these controls the bot, so a backup only
/// ever holds them encrypted.
class Credentials {
  const Credentials({
    required this.apiId,
    required this.apiHash,
    required this.botToken,
    this.extraBots = const [],
    this.spotifyClientId,
    this.spotifyRefreshToken,
    this.listenBrainzToken,
  });
  final int apiId;
  final String apiHash, botToken;

  /// The other bots' tokens, and the Spotify sign-in (its Client ID and refresh token).
  /// Anyone with these can act as the bot or the Spotify account, so they are sealed too.
  final List<String> extraBots;
  final String? spotifyClientId, spotifyRefreshToken;

  /// The ListenBrainz user token, which lets anyone submit listens as the account.
  final String? listenBrainzToken;
}

/// How a backup or restore is going, for the progress bar: what it is doing, and how far
/// along it is when that can be told (null while it can't).
typedef BackupProgress = void Function(String stage, double? fraction);

/// The app layout and settings a backup carries: look, navigation bar, sort orders, sound
/// and speeds. Not what belongs to one device: its id, addresses, queues and what it files.
const layoutPrefs = [
  'theme_mode',
  'theme_amoled',
  'theme_accent',
  'cover_gradient',
  'now_playing_panel',
  'floating_nav',
  'nav_radius',
  'nav_style',
  'glass_style',
  'profile_name',
  'sort_songs',
  'sort_reverse',
  'sort_playlist',
  'norm_mode',
  'norm_preamp',
  'eq_on',
  'eq_gains',
  'rate_filing',
  'rate_uploads',
  'rate_reading',
  'rate_lookups',
  'rate_covers',
  'rate_accountCopy',
  'upload_slower',
  'upload_parallel',
  'upload_ask',
  'upload_skip_known',
  'keep_running',
  'listenbrainz_on',
  'weather_city',
  'weather_lat',
  'weather_lon',
];

/// Thrown when a password doesn't open the credentials in a backup.
class WrongPassword implements Exception {}

Pbkdf2 get _kdf => Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: 256,
    );

/// Encrypts [c] with a key derived from [password]. Slow by design, to make
/// guessing expensive, so it runs off the UI isolate.
Future<String> sealCredentials(Credentials c, String password) => Isolate.run(() async {
      final salt = SecretKeyData.random(length: 16).bytes;
      final key = await _kdf.deriveKeyFromPassword(password: password, nonce: salt);
      final box = await AesGcm.with256bits().encrypt(
        utf8.encode(jsonEncode({
          'apiId': c.apiId,
          'apiHash': c.apiHash,
          'botToken': c.botToken,
          if (c.extraBots.isNotEmpty) 'extraBots': c.extraBots,
          if (c.spotifyClientId != null) 'spotifyClientId': c.spotifyClientId,
          if (c.spotifyRefreshToken != null) 'spotifyRefreshToken': c.spotifyRefreshToken,
          if (c.listenBrainzToken != null) 'listenBrainzToken': c.listenBrainzToken,
        })),
        secretKey: key,
      );
      return jsonEncode({
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      });
    });

/// Encrypts bytes (a session database) the same way, with a key from [password].
Future<String> sealBytes(List<int> plain, String password) => Isolate.run(() async {
      final salt = SecretKeyData.random(length: 16).bytes;
      final key = await _kdf.deriveKeyFromPassword(password: password, nonce: salt);
      final box = await AesGcm.with256bits().encrypt(plain, secretKey: key);
      return jsonEncode({
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      });
    });

/// Opens what [sealBytes] made. Throws [WrongPassword] if it can't.
Future<Uint8List> openBytes(String sealed, String password) => Isolate.run(() async {
      try {
        final s = jsonDecode(sealed) as Map<String, dynamic>;
        final key = await _kdf.deriveKeyFromPassword(password: password, nonce: base64Decode(s['salt'] as String));
        final plain = await AesGcm.with256bits().decrypt(
          SecretBox(
            base64Decode(s['data'] as String),
            nonce: base64Decode(s['nonce'] as String),
            mac: Mac(base64Decode(s['mac'] as String)),
          ),
          secretKey: key,
        );
        return Uint8List.fromList(plain);
      } on SecretBoxAuthenticationError {
        throw WrongPassword();
      }
    });

/// Opens what [sealCredentials] made. Throws [WrongPassword] if it can't.
Future<Credentials> openCredentials(String sealed, String password) => Isolate.run(() async {
      try {
        final s = jsonDecode(sealed) as Map<String, dynamic>;
        final key = await _kdf.deriveKeyFromPassword(
          password: password,
          nonce: base64Decode(s['salt'] as String),
        );
        final plain = await AesGcm.with256bits().decrypt(
          SecretBox(
            base64Decode(s['data'] as String),
            nonce: base64Decode(s['nonce'] as String),
            mac: Mac(base64Decode(s['mac'] as String)),
          ),
          secretKey: key,
        );
        final c = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
        return Credentials(
          apiId: c['apiId'] as int,
          apiHash: c['apiHash'] as String,
          botToken: c['botToken'] as String,
          extraBots: [for (final t in (c['extraBots'] as List?) ?? const []) t as String],
          spotifyClientId: c['spotifyClientId'] as String?,
          spotifyRefreshToken: c['spotifyRefreshToken'] as String?,
          listenBrainzToken: c['listenBrainzToken'] as String?,
        );
      } on SecretBoxAuthenticationError {
        throw WrongPassword();
      }
    });

/// Writes the library to a ZIP: song info, playlists, favorites, settings and
/// covers, plus [sealedCredentials] if given. Not the music.
Future<File> createBackup(
  AppDb db,
  Directory tempDir, {
  String? sealedCredentials,
  String? sealedUserSession,
  BackupProgress? onProgress,
}) async {
  onProgress?.call('Reading your library', 0.02);
  final songs = await db.select(db.songs).get();
  final allPrefs = await db.select(db.prefs).get();
  final manifest = File(p.join(tempDir.path, _manifest));
  await manifest.writeAsString(jsonEncode({
    'version': _version,
    'createdAt': DateTime.now().toIso8601String(),
    'chats': (await db.select(db.libraryChats).get()).map((r) => r.toJson()).toList(),
    'songs': songs.map((r) => r.toJson()).toList(),
    'playlists': (await db.select(db.playlists).get()).map((r) => r.toJson()).toList(),
    'playlistSongs': (await db.select(db.playlistSongs).get()).map((r) => r.toJson()).toList(),
    'missingTracks': (await db.select(db.missingTracks).get()).map((r) => r.toJson()).toList(),
    'moodVotes': (await db.select(db.moodVotes).get()).map((r) => r.toJson()).toList(),
    'prefs': allPrefs.map((r) => r.toJson()).toList(),
    // The app's layout and settings, kept apart from 'prefs' so a restore can leave them out.
    'layout': {for (final r in allPrefs) if (layoutPrefs.contains(r.key)) r.key: r.value},
  }));
  onProgress?.call('Packing', 0.08);

  final out = File(p.join(tempDir.path, 'teleplayer-backup.zip'));
  final zip = ZipFileEncoder()..create(out.path);
  await zip.addFile(manifest, _manifest);
  File? sealedFile;
  if (sealedCredentials != null) {
    sealedFile = File(p.join(tempDir.path, _credentialsEntry));
    await sealedFile.writeAsString(sealedCredentials);
    await zip.addFile(sealedFile, _credentialsEntry);
  }
  // The profile picture is a file on this device, so it goes in as itself.
  final photoPath = allPrefs.where((r) => r.key == 'profile_photo').map((r) => r.value).firstOrNull;
  if (photoPath != null && photoPath.isNotEmpty && await File(photoPath).exists()) {
    await zip.addFile(File(photoPath), '$_profileFolder/${p.basename(photoPath)}');
  }
  File? sessionFile;
  if (sealedUserSession != null) {
    sessionFile = File(p.join(tempDir.path, _userSessionEntry));
    await sessionFile.writeAsString(sealedUserSession);
    await zip.addFile(sessionFile, _userSessionEntry);
  }
  final added = <String>{};
  final withCover = songs.where((s) => s.coverPath != null).toList();
  var done = 0;
  for (final s in withCover) {
    done++;
    final path = s.coverPath!;
    if (done % 25 == 0) onProgress?.call('Adding covers: $done of ${withCover.length}', 0.1 + 0.82 * done / withCover.length);
    if (!added.add(p.basename(path))) continue;
    final cover = File(path);
    if (await cover.exists()) await zip.addFile(cover, '$_coversFolder/${p.basename(path)}');
  }
  onProgress?.call('Finishing the file', 0.95);
  await zip.close();
  await manifest.delete();
  await sealedFile?.delete();
  await sessionFile?.delete();
  onProgress?.call('Done', 1);
  return out;
}

class _Backup {
  _Backup(Map<String, dynamic> json)
      : chats = _rows(json, 'chats', LibraryChat.fromJson),
        songs = _rows(json, 'songs', Song.fromJson, const {'tagsAt': 0, 'favoriteAt': 0, 'coverAt': 0, 'instrumental': false, 'moodScannedAt': 0, 'plays': 0, 'skips': 0}),
        playlists = _rows(json, 'playlists', Playlist.fromJson, const {'uuid': '', 'modifiedAt': 0}),
        playlistSongs = _rows(json, 'playlistSongs', PlaylistSong.fromJson),
        missingTracks = json['missingTracks'] == null
            ? const []
            : _rows(json, 'missingTracks', MissingTrack.fromJson),
        moodVotes = json['moodVotes'] == null ? const [] : _rows(json, 'moodVotes', MoodVote.fromJson),
        prefs = _rows(json, 'prefs', Pref.fromJson),
        layout = {for (final e in ((json['layout'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'};

  /// The layout and settings the backup carries (empty for backups from older versions).
  final Map<String, String> layout;
  final List<LibraryChat> chats;
  final List<Song> songs;
  final List<Playlist> playlists;
  final List<PlaylistSong> playlistSongs;
  final List<MissingTrack> missingTracks;
  final List<MoodVote> moodVotes;
  final List<Pref> prefs;

  /// [defaults] fill columns that backups from older versions don't have.
  static List<T> _rows<T>(
    Map<String, dynamic> json,
    String key,
    T Function(Map<String, dynamic>, {ValueSerializer? serializer}) fromJson, [
    Map<String, dynamic> defaults = const {},
  ]) =>
      (json[key] as List)
          .cast<Map<String, dynamic>>()
          .map((r) => fromJson({...defaults, ...r}))
          .toList();
}

/// Replaces the library with a backup. Everything is read and checked first, so
/// a bad file changes nothing. Saved copies of songs aren't in a backup, so all
/// songs restore as not downloaded. [beforeReplace] runs once the file is known
/// to be good. Returns how many songs came back, and the encrypted credentials
/// if the backup has them.
Future<({int songs, String? sealedCredentials, String? sealedUserSession, bool layoutApplied})> restoreBackup(
  AppDb db,
  String zipPath,
  Directory coversDir, {
  Directory? profileDir,
  Future<void> Function()? beforeReplace,
  bool applyLayout = false,
  BackupProgress? onProgress,
}) async {
  onProgress?.call('Reading the backup', 0.02);
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final entry = archive.findFile(_manifest);
    if (entry == null) throw const FormatException('This isn\'t a Paper Play backup.');

    final _Backup backup;
    try {
      final json = jsonDecode(utf8.decode(entry.readBytes()!)) as Map<String, dynamic>;
      if (json['version'] != _version) {
        throw const FormatException('This backup is from a different version of Paper Play.');
      }
      backup = _Backup(json);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This backup is damaged.');
    }

    onProgress?.call('Stopping playback', 0.06);
    await beforeReplace?.call();
    if (await coversDir.exists()) await coversDir.delete(recursive: true);
    await coversDir.create(recursive: true);
    final restored = <String>{};
    final coverFiles = archive.where((f) => f.isFile && f.name.startsWith('$_coversFolder/')).length;
    var coversDone = 0;
    for (final file in archive) {
      final parts = file.name.split('/');
      if (!file.isFile || parts.length != 2 || parts.first != _coversFolder) continue;
      coversDone++;
      if (coversDone % 25 == 0) onProgress?.call('Restoring covers: $coversDone of $coverFiles', 0.1 + 0.4 * coversDone / coverFiles);
      if (!_safeName.hasMatch(parts.last) || file.size > _maxCoverBytes) continue;
      await File(p.join(coversDir.path, parts.last)).writeAsBytes(file.readBytes()!);
      restored.add(parts.last);
    }

    await db.transaction(() async {
      // These belong to this device. A device id copied from the backup's device
      // would make the two look like one, and they'd refuse to connect.
      final own = await (db.select(db.prefs)..where((r) => r.key.isIn(AppDb.devicePrefs))).get();
      for (final t in db.allTables) {
        await db.delete(t).go();
      }
      for (final r in backup.prefs.where((r) => !AppDb.devicePrefs.contains(r.key))) {
        await db.into(db.prefs).insert(r.toCompanion(false));
      }
      for (final r in own) {
        // This device's own layout gives way to the backup's when that was asked for.
        if (applyLayout && backup.layout.containsKey(r.key)) continue;
        await db.into(db.prefs).insert(r.toCompanion(false));
      }
      if (applyLayout) {
        for (final e in backup.layout.entries) {
          if (!layoutPrefs.contains(e.key)) continue; // Nothing but known settings, whatever the file says.
          await db.into(db.prefs).insert(PrefsCompanion.insert(key: e.key, value: e.value));
        }
      }
      onProgress?.call('Restoring songs', 0.52);
      for (final r in backup.chats) {
        await db.into(db.libraryChats).insert(r.toCompanion(false));
      }
      var songsDone = 0;
      for (final s in backup.songs) {
        songsDone++;
        if (songsDone % 100 == 0) onProgress?.call('Restoring songs: $songsDone of ${backup.songs.length}', 0.52 + 0.4 * songsDone / backup.songs.length);
        // Cover paths include the old install's folder, so only the name is kept.
        final name = s.coverPath == null ? null : p.basename(s.coverPath!);
        final row = s.copyWith(
          cachedBytes: 0,
          coverPath: Value(restored.contains(name) ? p.join(coversDir.path, name) : null),
        );
        await db.into(db.songs).insert(row.toCompanion(false));
      }
      for (final r in backup.playlists) {
        await db.into(db.playlists).insert(r.toCompanion(false));
      }
      for (final r in backup.playlistSongs) {
        await db.into(db.playlistSongs).insert(r.toCompanion(false));
      }
      for (final r in backup.missingTracks) {
        await db.into(db.missingTracks).insert(r.toCompanion(false));
      }
      for (final r in backup.moodVotes) {
        await db.into(db.moodVotes).insert(r.toCompanion(false));
      }
      // The profile picture, written next to the covers' folder, and pointed at.
      if (applyLayout && profileDir != null) {
        for (final file in archive) {
          final parts = file.name.split('/');
          if (!file.isFile || parts.length != 2 || parts.first != _profileFolder || !_safeName.hasMatch(parts.last)) continue;
          if (file.size > _maxCoverBytes) continue;
          await profileDir.create(recursive: true);
          final saved = File(p.join(profileDir.path, parts.last));
          await saved.writeAsBytes(file.readBytes()!);
          await db.into(db.prefs).insertOnConflictUpdate(PrefsCompanion.insert(key: 'profile_photo', value: saved.path));
        }
      }
      onProgress?.call('Finishing', 0.95);
      await db.prepareOlderRows();
      // Topics and copies aren't in a backup, so they have to be read again.
      await db.customStatement("DELETE FROM prefs WHERE key = 'topics_read'");
    });
    final sealed = archive.findFile(_credentialsEntry)?.readBytes();
    onProgress?.call('Done', 1);
    return (
      songs: backup.songs.length,
      sealedCredentials: sealed == null ? null : utf8.decode(sealed),
      sealedUserSession: (() {
        final s = archive.findFile(_userSessionEntry)?.readBytes();
        return s == null ? null : utf8.decode(s);
      })(),
      layoutApplied: applyLayout && backup.layout.isNotEmpty,
    );
  } finally {
    await input.close();
  }
}
