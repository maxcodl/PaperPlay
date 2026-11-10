import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleplayer/library/db.dart';
import 'package:teleplayer/ui/glass/glass_style.dart';
import 'package:teleplayer/ui/glass/nav_style.dart';
import 'package:teleplayer/ui/ui_prefs.dart';

/// Schema 1 as shipped: an existing library must survive the upgrade.
const _v1Songs = '''
CREATE TABLE songs (
  chat_id INTEGER NOT NULL, message_id INTEGER NOT NULL,
  unique_id TEXT NOT NULL, remote_id TEXT NOT NULL,
  title TEXT NOT NULL, artist TEXT NOT NULL, album TEXT NOT NULL DEFAULT '',
  duration_sec INTEGER NOT NULL DEFAULT 0, size INTEGER NOT NULL,
  mime TEXT NOT NULL, file_name TEXT NOT NULL, date INTEGER NOT NULL,
  cover_path TEXT NULL,
  user_edited INTEGER NOT NULL DEFAULT 0,
  enrich_state INTEGER NOT NULL DEFAULT 0,
  lyrics TEXT NULL, cached_bytes INTEGER NOT NULL DEFAULT 0,
  last_played_at INTEGER NULL, pinned INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (chat_id, message_id), UNIQUE (unique_id)
)''';

void main() {
  test('stats count enrichment states and covers, and handle an empty library', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    expect((await db.watchStats().first).total, 0);

    SongsCompanion row(int id, int state, {String? cover}) => SongsCompanion.insert(
          chatId: 1,
          messageId: id,
          uniqueId: 'u$id',
          remoteId: 'r$id',
          title: 't',
          artist: 'a',
          size: 1,
          mime: 'audio/mpeg',
          fileName: 'f',
          date: 0,
          enrichState: Value(state),
          coverPath: Value(cover),
        );
    await db.into(db.songs).insert(row(1, EnrichState.pending));
    await db.into(db.songs).insert(row(2, EnrichState.done, cover: '/c.jpg'));
    await db.into(db.songs).insert(row(3, EnrichState.noMatch));

    final s = await db.watchStats().first;
    expect([s.total, s.waiting, s.matched, s.noMatch, s.covers], [3, 1, 1, 1, 1]);
  });

  test('navigation bar and glass choices persist, and stay in range', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    final first = UiPrefs(db);
    await first.load();
    expect(first.floatingNav.value, isTrue, reason: 'floating by default');
    expect(first.navStyle.value, const NavStyle());
    expect(first.glass.value, const GlassStyle());

    await first.setFloating(false);
    first.setNavStyle(first.navStyle.value.copyWith(layout: NavLayout.dock, barRadius: 500, look: SelectionLook.ring));
    first.setGlass(first.glass.value.copyWith(blur: 999, tint: 0.4));
    // Saved once the sliders settle.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final reopened = UiPrefs(db);
    await reopened.load();
    expect(reopened.floatingNav.value, isFalse);
    final nav = reopened.navStyle.value;
    expect([nav.layout, nav.barRadius, nav.look], [NavLayout.dock, 100.0, SelectionLook.ring]);
    expect([reopened.glass.value.blur, reopened.glass.value.tint], [GlassStyle.blurRange.$2, 0.4]);
  });

  test('bot upsert keeps tags, takes the remote id, and adds new songs', () async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    SongsCompanion row(String title, String remote) => SongsCompanion.insert(
          chatId: 1,
          messageId: 2,
          uniqueId: 'u',
          remoteId: remote,
          title: title,
          artist: 'a',
          size: 1,
          mime: 'audio/mpeg',
          fileName: 'f',
          date: 0,
        );
    await db.upsertBotSong(row('Edited', 'user-id'));
    await db.upsertBotSong(row('From Telegram', 'bot-id'));
    final song = await db.song(1, 2);
    expect(song?.title, 'Edited');
    expect(song?.remoteId, 'bot-id');
  });

  test('upgrading from schema 1 keeps songs, adds releaseId, retries non-matches', () async {
    final db = AppDb(NativeDatabase.memory(setup: (raw) {
      raw.execute(_v1Songs);
      raw.execute('CREATE TABLE library_chats (id INTEGER NOT NULL PRIMARY KEY, '
          'title TEXT NOT NULL, last_scanned_message_id INTEGER NULL)');
      raw.execute("INSERT INTO library_chats (id, title, last_scanned_message_id) VALUES (1, 'Chat', 5)");
      raw.execute('CREATE TABLE playlists (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
      raw.execute('CREATE TABLE playlist_songs (playlist_id INTEGER NOT NULL REFERENCES playlists (id) '
          'ON DELETE CASCADE, chat_id INTEGER NOT NULL, message_id INTEGER NOT NULL, added_at INTEGER NOT NULL, '
          'PRIMARY KEY (playlist_id, chat_id, message_id))');
      raw.execute('CREATE TABLE prefs (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)');
      raw.execute("INSERT INTO playlists (id, name) VALUES (3, 'Mix')");
      raw.execute('INSERT INTO playlist_songs (playlist_id, chat_id, message_id, added_at) VALUES (3, 1, 2, 9)');
      raw.execute('''
        INSERT INTO songs (chat_id, message_id, unique_id, remote_id, title, artist, size, mime,
          file_name, date, cover_path, enrich_state)
        VALUES (1, 2, 'u', 'r', 'Song', 'Artist', 10, 'audio/mpeg', 'a.mp3', 5, '/c.jpg', 2)
      ''');
      raw.execute('PRAGMA user_version = 1');
    }));
    addTearDown(db.close);

    final song = await db.song(1, 2);
    expect(song?.title, 'Song');
    expect(song?.coverPath, '/c.jpg');
    expect(song?.releaseId, isNull);
    expect(song?.enrichState, EnrichState.pending, reason: 'non-matches get another try');
    expect(
      await db.customSelect('PRAGMA user_version').getSingle().then((r) => r.read<int>('user_version')),
      14,
    );
    expect([song?.sampleRate, song?.bitDepth, song?.codec], [null, null, null], reason: 'read later, never guessed');
    final list = (await db.livePlaylists()).single;
    expect(list.uuid, legacyPlaylistUuid(3, 'Mix'), reason: 'two devices must agree on it');
    expect((await db.watchPlaylistSongs(list.id).first).single.messageId, 2);
    final upgraded = (await db.song(1, 2))!;
    expect((await db.tasteSettings()).resetAt, greaterThan(0), reason: 'learning starts over once');
    expect([upgraded.plays, upgraded.skips], [0, 0]);
    expect(upgraded.tagsAt, 0, reason: 'a retried non-match has nothing to share yet');
    expect(upgraded.favoriteAt, 0);
    expect((await db.song(1, 2))?.favorite, isFalse);
    final chat = await db.select(db.libraryChats).getSingle();
    expect(chat.useBot, isFalse, reason: 'existing chats stay on the user login');
    expect(chat.walkDone, isTrue, reason: 'already scanned, so not read again');
  });
}
